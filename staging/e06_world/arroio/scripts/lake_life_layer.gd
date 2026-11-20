extends RefCounted
const BASE := "res://staging/e06_world/arroio/"
var geometry = preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new()

func configure(city: Node3D, lake: Node3D, data: Dictionary, field: ShaderMaterial, builder) -> void:
	var finish = preload("res://staging/e06_world/arroio/scripts/z2_finish.gd")
	var dirt: StandardMaterial3D = finish.soil(city,"dry").duplicate()
	dirt.albedo_color=Color(.5,.51,.45)
	city._buffer(city.get_node("Terrain/Pavements"),"WestLake_SouthConnection",data.secondary_connection,3.8,.037,dirt)
	city._buffer(city.get_node("Terrain/Pavements"),"WestLake_TrackRegrowth",data.road,.72,.041,field)
	for path in data.get("service_paths",[]):
		city._buffer(city.get_node("Terrain/Pavements"),path.id,path.points,1.1,.043,dirt)
	for spot in data.activity_spots:
		var node := Node3D.new()
		node.name=spot.id
		node.set_script(load(BASE+"scripts/rural_runtime.gd"))
		node.position=Vector3(spot.position[0],0,spot.position[1])
		node.rotation_degrees.y=spot.yaw
		node.add_to_group("z2_finish_owner")
		lake.add_child(node)
		city._buffer(city.get_node("Terrain/Pavements"),str(spot.id)+"_Footpath",spot.route,1.5,.042,dirt)
		if spot.dock:builder._dock(city,lake,spot,data,dirt)
	for placement in data.dressing_placements:
		var owner: Node3D = lake.get_node(placement.site)
		var visual: Node3D = load(data.dressing_assets[placement.asset].path).instantiate()
		visual.name="Yard_"+str(placement.asset)+"_"+str(owner.get_child_count())
		visual.position=Vector3(placement.position[0],placement.position[1],placement.position[2])
		visual.rotation_degrees.y=placement.yaw
		owner.add_child(visual)
		var faces := PackedVector3Array()
		var roofs: Array = []
		var zone := Rect2()
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			geometry._append_faces(mesh,owner,faces)
			var title := str(mesh.name).to_upper()
			var source: Material = mesh.get_active_material(0)
			if source is StandardMaterial3D and source.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:
				mesh.material_override=builder._cabin_material(source,0)
			if "TELHADO" in title or "COBERTURA" in title:
				var box: AABB = (owner.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
				var rect := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
				zone=rect if roofs.is_empty() else zone.merge(rect)
				mesh.set_meta("keep_individual_visual",true)
				roofs.append(mesh)
		for mesh in roofs:
			mesh.set_meta("roof_zone",zone)
			owner.roofs.append(mesh)
		geometry._collision(owner,faces,visual.name+"Collision")
	var index := 0
	for patch in data.dressing_surfaces:
		var owner: Node3D = lake.get_node(patch.site)
		var polygon: PackedVector2Array = city._points(patch.polygon)
		var boundary := PackedVector2Array()
		for p in polygon:
			var q: Vector3 = owner.to_global(Vector3(p.x,0,p.y))
			boundary.append(Vector2(q.x,q.z))
		var soil: ShaderMaterial = field.duplicate(false)
		soil.set_shader_parameter("surface_kind",float(patch.kind))
		soil.set_shader_parameter("surface_strength",float(patch.strength))
		soil.set_shader_parameter("boundary_count",boundary.size())
		soil.set_shader_parameter("boundary",boundary)
		soil.set_shader_parameter("dirt_texture",finish.soil(city,"dry").albedo_texture)
		city._surface(owner,"YardSoil_"+str(index),polygon,.023+index*.0003,soil,3)
		index+=1
	city.set_meta("lake_life_props",data.dressing_placements.size())
	city.set_meta("lake_life_soils",index)
