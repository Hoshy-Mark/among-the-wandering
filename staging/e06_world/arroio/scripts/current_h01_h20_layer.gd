extends RefCounted

const DATA := "res://staging/e06_world/arroio/data/"

static func rules(world: Node3D = null) -> Dictionary:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "current_h01_h20_overrides.json"))
	if world != null and world.h02_variant == "A":
		document.lots.H02 = document.variants.H02_A
	return document

static func adjusted(world: Node3D, name: String, data: Variant) -> Variant:
	if not world.apply_lot_overrides or not world.apply_current_h01_h20_revisions:
		return data
	var definitions: Dictionary = rules(world).lots
	if name == "urban_dressing":
		for plot in data.plots:
			if not definitions.has(plot.building_id):
				continue
			var rule: Dictionary = definitions[plot.building_id]
			plot.gate.folded_open = true
			plot.gate.leaf_collision_height_m = .86
			plot.gate.leaf_length_m = minf(1.55, rule.gate_width_m / 2 - .12)
			plot.gate.mailbox_offset_m = -.14
			plot.access_path = rule.access_path
			plot.access_width_m = rule.access_width_m
			plot.entry.position = rule.door_xz
			plot.entry.approach = [rule.door_xz[0], rule.door_xz[1] + rule.front_direction * 1.3]
			plot.threshold_connector = [plot.entry.approach, rule.door_xz]
	elif name == "landscape":
		for zone in data.ground_zones:
			if not definitions.has(zone.get("building_id", "")):
				continue
			var rule: Dictionary = definitions[zone.building_id]
			if str(zone.id).begins_with("ACCESS_"):
				zone.points = rule.access_path
				zone.width_m = rule.access_width_m
		data.walks = data.walks.filter(func(walk): return not definitions.has(str(walk.id).trim_prefix("SERVICE_WALK_")))
	return data

func configure(city: Node3D) -> void:
	var helper = preload("res://staging/e06_world/arroio/scripts/master_lot_layer.gd").new()
	helper.city = city
	var definitions: Dictionary = rules(city).lots
	for lot in definitions:
		var rule: Dictionary = definitions[lot]
		var art: Node3D = city.get_node("Landscape/" + rule.sector + "/" + lot + "_MasterCandidate")
		for child in art.get_children():
			if str(child.name).begins_with(lot + "_ServicePath") or str(child.name).begins_with(lot + "_UtilityWalk"):
				child.visible = false
				child.queue_free()
		if rule.service_path.size() > 1:
			city._buffer(art, lot + "_CurrentServiceWalk", rule.service_path, rule.service_width_m * .75, .034, helper._material(rule, 2))
		for index in rule.service_branches.size():
			city._buffer(art, lot + "_CurrentServiceBranch_" + str(index), rule.service_branches[index], rule.service_width_m * .75, .034, helper._material(rule, 2))
		for feature in rule.site_features:
			if art.has_node(feature.id + "_Microarea"):
				continue
			var bounds: Array = feature.bounds
			var polygon := PackedVector2Array([Vector2(bounds[0], bounds[1]), Vector2(bounds[2], bounds[1]), Vector2(bounds[2], bounds[3]), Vector2(bounds[0], bounds[3])])
			city._surface(art, feature.id + "_Microarea", polygon, .033, helper._material(rule, feature.zone, polygon), 2)
		for item in city.catalog("yard_details").items:
			if item.building_id != lot or item.kind != "kitchen_garden":
				continue
			var garden: Node3D = city.get_node("UrbanDressing/" + rule.sector + "/" + item.id)
			for visual in garden.get_children():
				if visual is MultiMeshInstance3D and ("green" in str(visual.name) or "leaf" in str(visual.name)):
					visual.multimesh.visible_instance_count = maxi(1, visual.multimesh.instance_count / 3)
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
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA+"current_h01_h20_overgrowth.json")).lots
	var applied := 0
	for h in document:
		var r: Dictionary = rules(city).lots[h]
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
	city.set_meta("current_h01_h20_new_overgrowth_count",applied)
