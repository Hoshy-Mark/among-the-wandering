extends RefCounted
## H11-H20 derivatives are kept separate from the accepted H01-H10 package.
const DATA := "res://staging/e06_world/arroio/data/"

static func rules() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA+"h11_h20_overrides.json"))

static func adjusted(world: Node3D,name: String,data: Variant) -> Variant:
	if not world.apply_lot_overrides or not world.apply_h11_h20_candidates:return data
	if name not in ["urban_dressing","landscape","yard_details"]:return data
	var all_rules: Dictionary = rules().lots
	if name=="urban_dressing":
		for plot in data.plots:
			var r: Dictionary = all_rules.get(plot.building_id,{})
			if not r.get("enabled",false):continue
			plot.gate.center=r.gate_center.duplicate()
			plot.gate.opening_width_m=r.gate_width_m
			plot.gate.leaf_collision_height_m=.86
			plot.gate.leaf_length_m=minf(1.55,r.gate_width_m/2-.12)
			plot.gate.folded_open=true
			plot.gate.mailbox_offset_m=-.14
			plot.additional_gates=r.vehicle_gates.duplicate(true)
			for gate in plot.additional_gates:gate.folded_open=true;gate.mailbox_offset_m=-.14
			plot.access_path=r.access_path.duplicate(true)
			plot.access_width_m=r.access_width_m
			plot.threshold_connector=[[r.door_xz[0],r.door_xz[1]+r.front_direction*1.3],r.door_xz]
			var road_end: Array = plot.road_connector[-1].duplicate()
			road_end[0]+=r.gate_center[0]-r.gate_original.center[0]
			plot.road_connector=[r.gate_center,road_end]
			var anchor := Vector3(r.building_position[0],r.building_position[1],r.building_position[2])
			var point: Vector3 = Basis(Vector3.UP,deg_to_rad(r.building_yaw)).inverse()*(Vector3(r.door_xz[0],r.floor_m,r.door_xz[1])-anchor)
			plot.entry.local_anchor_xyz=[point.x,point.y,point.z]
			plot.entry.position=r.door_xz
			plot.entry.mesh_name=r.revision+"_SOLEIRA"
			plot.entry.approach=[r.door_xz[0],r.door_xz[1]+r.front_direction*1.3]
			if not r.front_walls_to_recompose.is_empty():_frontage(data,plot,r)
		for item in data.yards:_move(item,all_rules)
	elif name=="landscape":
		for zone in data.ground_zones:
			var r: Dictionary = all_rules.get(zone.get("building_id",""),{})
			if not r.get("enabled",false):continue
			if str(zone.id).begins_with("ACCESS_"):zone.points=r.access_path;zone.width_m=r.access_width_m
			elif str(zone.id).begins_with("APRON_"):
				var b: Array = r.body_bounds_xz
				zone.polygon=[[b[0]-.65,b[1]-.65],[b[2]+.65,b[1]-.65],[b[2]+.65,b[3]+.65],[b[0]-.65,b[3]+.65]]
		for item in data.props:_move(item,all_rules)
		data.walks=data.walks.filter(func(w):return not all_rules.has(str(w.id).trim_prefix("SERVICE_WALK_")))
	elif name=="yard_details":
		for item in data.items:_move(item,all_rules)
	return data

static func _move(item: Dictionary,all_rules: Dictionary) -> void:
	for move in all_rules.get(item.get("building_id",""),{}).get("object_moves",[]):
		if item.id==move.id:item.position=move.candidate_xz.duplicate();item.candidate_move=move

static func _frontage(data: Dictionary,plot: Dictionary,r: Dictionary) -> void:
	var owners: Array = []
	for wall in data.shared_walls:
		if wall.id in r.front_walls_to_recompose:
			assert(wall.owners.size()==1 and wall.owners[0].building_id==plot.building_id)
			owners.append(wall)
	assert(owners.size()==2)
	var lo: float = minf(minf(owners[0].a[0],owners[0].b[0]),minf(owners[1].a[0],owners[1].b[0]))
	var hi: float = maxf(maxf(owners[0].a[0],owners[0].b[0]),maxf(owners[1].a[0],owners[1].b[0]))
	var openings: Array = [[r.gate_center[0]-r.gate_width_m/2,r.gate_center[0]+r.gate_width_m/2]]
	for gate in r.vehicle_gates:openings.append([gate.center[0]-gate.opening_width_m/2,gate.center[0]+gate.opening_width_m/2])
	openings.sort_custom(func(a,b):return a[0]<b[0])
	var segments: Array = []
	var previous := lo
	for gap in openings:
		assert(gap[0]>previous and gap[1]<hi)
		segments.append([[previous,r.gate_center[1]],[gap[0],r.gate_center[1]]]);previous=gap[1]
	segments.append([[previous,r.gate_center[1]],[hi,r.gate_center[1]]])
	owners[0].a=segments[0][0];owners[0].b=segments[0][1]
	owners[1].a=segments[-1][0];owners[1].b=segments[-1][1]
	if segments.size()==3:
		var middle: Dictionary = owners[0].duplicate(true)
		middle.id="FRONT_"+plot.building_id+"_BETWEEN_GATES"
		middle.a=segments[1][0];middle.b=segments[1][1]
		middle.source_front_wall_ids=r.front_walls_to_recompose
		data.shared_walls.append(middle)
	plot.segments=plot.segments.filter(func(s):return not (absf(s[0][1]-r.gate_original.center[1])<.001 and absf(s[1][1]-r.gate_original.center[1])<.001))
	plot.segments.append_array(segments)

func configure(city: Node3D) -> void:
	var helper=preload("res://staging/e06_world/arroio/scripts/master_lot_layer.gd").new()
	helper.city=city
	for h in rules().lots:
		var r: Dictionary = rules().lots[h]
		var art: Node3D = city.get_node("Landscape/"+r.sector+"/"+h+"_MasterCandidate")
		for node in art.get_children():
			if str(node.name).begins_with(h+"_ServicePath"):node.queue_free();node.visible=false
		city._buffer(art,h+"_UtilityWalk",r.service_path,r.service_width_m,.033,helper._material(r,2))
		for gate in r.vehicle_gates:city._buffer(art,gate.id+"_Drive",gate.driveway_points,gate.driveway_width_m,.034,helper._material(r,1))
		for feature in r.site_features:
			var b: Array = feature.bounds
			var polygon := PackedVector2Array([Vector2(b[0],b[1]),Vector2(b[2],b[1]),Vector2(b[2],b[3]),Vector2(b[0],b[3])])
			city._surface(art,feature.id+"_Microarea",polygon,.032,helper._material(r,feature.zone,polygon),2)
		if r.has("replace_legacy_object"):
			var old: Node3D = city.get_node("UrbanDressing/"+r.sector+"/"+r.replace_legacy_object)
			old.set_meta("replaced_by_next_model",true)
			for node in old.get_children():
				if node is GeometryInstance3D:node.visible=false
				elif node is StaticBody3D:
					for shape in node.get_children():
						if shape is CollisionShape3D:shape.disabled=true
		if r.preserve_side_entry_reference:
			var marker := Marker3D.new()
			marker.name="OriginalSideThresholdReference"
			marker.position=Vector3(r.original_side_entry_reference.position[0],.28,r.original_side_entry_reference.position[1])
			marker.set_meta("status","original measured reference retained; no second gameplay entrance inferred")
			art.add_child(marker)
