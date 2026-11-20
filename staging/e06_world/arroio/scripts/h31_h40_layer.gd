extends RefCounted
## H31-H40 additions; existing H01-H30 contracts remain immutable.
const DATA := "res://staging/e06_world/arroio/data/"

static func rules() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA+"h31_h40_overrides.json"))

static func adjusted(world: Node3D,name: String,data: Variant) -> Variant:
	if not world.apply_lot_overrides or not world.apply_h31_h40_candidates:return data
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
			if r.has("inner_pedestrian_width_m"):plot.gate.inner_pedestrian_width_m=r.inner_pedestrian_width_m
			plot.additional_gates=r.vehicle_gates.duplicate(true)
			for gate in plot.additional_gates:gate.folded_open=true;gate.mailbox_offset_m=-.14
			plot.access_path=r.access_path.duplicate(true)
			plot.access_width_m=r.access_width_m
			plot.threshold_connector=[[r.door_xz[0]+r.front_vector[0]*1.3,r.door_xz[1]+r.front_vector[1]*1.3],r.door_xz]
			var road_end: Array = plot.road_connector[-1].duplicate()
			road_end[1-int(r.front_axis)]+=r.gate_center[1-int(r.front_axis)]-r.gate_original.center[1-int(r.front_axis)]
			plot.road_connector=[r.gate_center,road_end]
			var anchor := Vector3(r.building_position[0],r.building_position[1],r.building_position[2])
			var point: Vector3 = Basis(Vector3.UP,deg_to_rad(r.building_yaw)).inverse()*(Vector3(r.door_xz[0],r.floor_m,r.door_xz[1])-anchor)
			plot.entry.local_anchor_xyz=[point.x,point.y,point.z]
			plot.entry.position=r.door_xz
			plot.entry.mesh_name=r.revision+"_SOLEIRA"
			plot.entry.approach=[r.door_xz[0]+r.front_vector[0]*1.3,r.door_xz[1]+r.front_vector[1]*1.3]
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
	var axis: int = int(r.front_axis);var tangent: int = 1-axis
	for wall in data.shared_walls:
		if wall.id in r.front_walls_to_recompose:
			assert(wall.owners.size()==1 and wall.owners[0].building_id==plot.building_id)
			owners.append(wall)
	assert(owners.size()==2)
	var lo: float = minf(minf(owners[0].a[tangent],owners[0].b[tangent]),minf(owners[1].a[tangent],owners[1].b[tangent]))
	var hi: float = maxf(maxf(owners[0].a[tangent],owners[0].b[tangent]),maxf(owners[1].a[tangent],owners[1].b[tangent]))
	var openings: Array = [[r.gate_center[tangent]-r.gate_width_m/2,r.gate_center[tangent]+r.gate_width_m/2]]
	for gate in r.vehicle_gates:openings.append([gate.center[tangent]-gate.opening_width_m/2,gate.center[tangent]+gate.opening_width_m/2])
	openings.sort_custom(func(a,b):return a[0]<b[0])
	var segments: Array = [];var previous := lo
	for gap in openings:
		assert(gap[0]>previous and gap[1]<hi)
		var a: Array = r.gate_center.duplicate();var b: Array = a.duplicate();a[tangent]=previous;b[tangent]=gap[0]
		segments.append([a,b]);previous=gap[1]
	var a: Array = r.gate_center.duplicate();var b: Array = a.duplicate();a[tangent]=previous;b[tangent]=hi;segments.append([a,b])
	owners[0].a=segments[0][0];owners[0].b=segments[0][1];owners[1].a=segments[-1][0];owners[1].b=segments[-1][1]
	if segments.size()==3:
		var middle: Dictionary = owners[0].duplicate(true);middle.id="FRONT_"+plot.building_id+"_BETWEEN_GATES";middle.a=segments[1][0];middle.b=segments[1][1];middle.source_front_wall_ids=r.front_walls_to_recompose;data.shared_walls.append(middle)
	plot.segments=plot.segments.filter(func(part):return not (absf(part[0][axis]-r.gate_original.center[axis])<.001 and absf(part[1][axis]-r.gate_original.center[axis])<.001))
	plot.segments.append_array(segments)

func configure(city: Node3D) -> void:
	var helper=preload("res://staging/e06_world/arroio/scripts/master_lot_layer.gd").new()
	helper.city=city
	for h in rules().lots:
		var r: Dictionary = rules().lots[h]
		var art: Node3D = city.get_node("Landscape/"+r.sector+"/"+h+"_MasterCandidate")
		for node in art.get_children():
			if str(node.name).begins_with(h+"_ServicePath"):node.queue_free();node.visible=false
		city._buffer(art,h+"_UtilityWalk",r.service_path,r.service_width_m*.72,.033,helper._material(r,2))
		for i in r.service_branches.size():city._buffer(art,h+"_UtilityBranch_"+str(i),r.service_branches[i],r.service_width_m*.72,.033,helper._material(r,2))
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
			marker.set_meta("status","original measured reference retained; exclusive service door and projection offset recorded separately")
			art.add_child(marker)
		for object_id in r.get("raise_legacy_objects_m",{}):
			var owner: Node3D = city.get_node("UrbanDressing/"+r.sector+"/"+object_id)
			owner.position.y+=float(r.raise_legacy_objects_m[object_id])
		for item in city.catalog("yard_details").items:
			if item.building_id!=h or item.kind!="kitchen_garden":continue
			var garden: Node3D = city.get_node("UrbanDressing/"+r.sector+"/"+item.id)
			for visual in garden.get_children():
				if not visual is MultiMeshInstance3D:continue
				if not ("green" in str(visual.name) or "leaf" in str(visual.name)):continue
				visual.multimesh.visible_instance_count=maxi(1,visual.multimesh.instance_count/3)
				if visual.material_override is StandardMaterial3D:
					visual.material_override=visual.material_override.duplicate(false)
					visual.material_override.albedo_color=Color(.23,.29,.12)
			garden.set_meta("abandoned_crop_visual_refinement",true)

	_overgrowth(city)

func _overgrowth(city: Node3D) -> void:
	var environment: Dictionary = city.catalog("environment")
	var sources := {}
	for key in ["capim","arbusto"]:
		var original: Node3D = load(environment.assets[key].path).instantiate()
		var visual: MeshInstance3D = original.find_children("*","MeshInstance3D",true,false)[0]
		var pose: Transform3D = visual.transform
		var cursor: Node3D = visual.get_parent()
		while cursor!=original:pose=cursor.transform*pose;cursor=cursor.get_parent()
		var bounds: AABB = pose*visual.mesh.get_aabb()
		var center: Vector3 = bounds.get_center();center.y=bounds.position.y
		var normalized := Transform3D(Basis.IDENTITY,-center)*pose
		var mesh := ArrayMesh.new()
		for surface in visual.mesh.get_surface_count():mesh.add_surface_from_arrays(visual.mesh.surface_get_primitive_type(surface),visual.mesh.surface_get_arrays(surface))
		var material: Material = visual.get_active_material(0)
		if material==null:
			material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.cull_mode=BaseMaterial3D.CULL_DISABLED
		else:material=material.duplicate(false)
		if material is StandardMaterial3D:
			material.vertex_color_use_as_albedo=true;material.roughness=.98;material.albedo_color=Color(.83,.86,.72)
		sources[key]={"mesh":mesh,"pose":normalized,"height":bounds.size.y,"width":maxf(bounds.size.x,bounds.size.z),"material":material}
		original.free()
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA+"h31_h40_overgrowth.json")).lots
	var applied := 0
	for h in document:
		var r: Dictionary = rules().lots[h]
		var art: Node3D = city.get_node("Landscape/"+r.sector+"/"+h+"_MasterCandidate")
		var clipped := 0
		var tall := 0
		for key in ["capim","arbusto"]:
			var items: Array = document[h].filter(func(p):return p.asset==key)
			var source: Dictionary = sources[key]
			var multi := MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.use_colors=true;multi.mesh=source.mesh;multi.instance_count=items.size()
			var effective: Array = []
			for i in items.size():
				var item: Dictionary = items[i];var p := Vector2(item.position[0],item.position[1]);var height: float = item.height_m
				var b: Array = r.body_bounds_xz
				var occupied: bool = p.x>b[0]-.12 and p.x<b[2]+.12 and p.y>b[1]-.12 and p.y<b[3]+.12
				for e in r.extra_structures:
					b=e.bounds
					occupied=occupied or (p.x>b[0]-.05 and p.x<b[2]+.05 and p.y>b[1]-.05 and p.y<b[3]+.05)
				var distance := Geometry2D.get_closest_point_to_segment(p,Vector2(r.gate_center[0],r.gate_center[1]),Vector2(r.door_xz[0],r.door_xz[1])).distance_to(p)
				var in_route: bool = distance<r.access_width_m/2+.15
				for route in [r.service_path]+r.service_branches+r.vehicle_gates.map(func(g):return g.driveway_points):
					for j in range(route.size()-1):
						if Geometry2D.get_closest_point_to_segment(p,Vector2(route[j][0],route[j][1]),Vector2(route[j+1][0],route[j+1][1])).distance_to(p)<.73:in_route=true
				if in_route:height=minf(height,.18+.15*absf(sin(i*2.1)))
				if occupied:height=.001;clipped+=1
				if height>.85:tall+=1
				var width: float = (.62 if key=="capim" else 1.05)*item.scale_xz
				var scale := Vector3(width/source.width,height/source.height,width/source.width)
				var pose: Transform3D = Transform3D(Basis(Vector3.UP,deg_to_rad(float(item.yaw))).scaled(scale),Vector3(p.x,.015,p.y))*source.pose
				multi.set_instance_transform(i,pose)
				multi.set_instance_color(i,Color(.82+.16*absf(sin(i*4.1)),.80+.16*absf(cos(i*2.7)),.66+.22*absf(sin(i))))
				effective.append({"id":item.id,"source_position":item.position,"height_m":height,"source_height_m":item.height_m,"under_structure":occupied,"in_route":in_route})
			var node := MultiMeshInstance3D.new();node.name=h+"_Matagal_"+key;node.multimesh=multi;node.material_override=source.material
			node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=650;node.visibility_range_end_margin=30
			node.set_meta("effective_instances",effective);node.set_meta("source_asset",environment.assets[key].path);node.set_meta("solid_colliders",false)
			art.add_child(node);applied+=items.size()
		art.set_meta("overgrowth_instances",document[h].size());art.set_meta("overgrowth_under_structure_suppressed",clipped);art.set_meta("overgrowth_taller_than_085m",tall)
	city.set_meta("h31_h40_new_overgrowth_count",applied)
