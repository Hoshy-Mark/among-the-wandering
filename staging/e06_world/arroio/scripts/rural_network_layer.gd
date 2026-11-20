extends RefCounted
const DATA := "res://staging/e06_world/arroio/data/rural_network.json"
var geometry = preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new()

static func adjusted(city: Node3D, name: String, data: Variant) -> Variant:
	if not city.apply_rural_network or name not in ["city_master","landscape","ground_cover"]:
		return preload("res://staging/e06_world/arroio/scripts/lake_west_layer.gd").adjusted(city,name,data)
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if name=="city_master":data.extent_xz=definition.extent_xz
	elif name=="landscape":
		data.trees=data.trees.filter(func(tree):return not definition.removed_tree_keys.has("%s:%.3f:%.3f" % [tree.asset,tree.position[0],tree.position[1]]))
		data.trees.append_array(definition.trees)
	else:
		data.items=data.items.filter(func(item):return not definition.get("removed_cover_keys",{}).has("%s:%.3f:%.3f" % [item.asset,item.position[0],item.position[1]]))
		data.items.append_array(definition.ground_cover)
	return preload("res://staging/e06_world/arroio/scripts/lake_west_layer.gd").adjusted(city,name,data)

func configure(city: Node3D) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var finish = preload("res://staging/e06_world/arroio/scripts/z2_finish.gd")
	var material := finish.soil(city,"dry")
	for key in data.roads:city._buffer(city.get_node("Terrain/Pavements"),"RN_"+key,data.roads[key],4.8,.058,material)
	for key in data.sites:
		var site: Dictionary = data.sites[key]
		var owner := Node3D.new()
		owner.set_script(load("res://staging/e06_world/arroio/scripts/rural_runtime.gd"))
		owner.name=key
		owner.position=Vector3(site.position[0],site.position[1],site.position[2])
		owner.add_to_group("z2_finish_owner")
		city.add_child(owner)
		var ground: ShaderMaterial = city.get_node("Terrain/Ground/FlatSouthernGround").material_override
		var patch_index := 0
		for patch in site.get("surface_patches",[]):
			var polygon := PackedVector2Array()
			var boundary := PackedVector2Array()
			for point in patch.polygon:
				polygon.append(Vector2(point[0],point[1]))
				boundary.append(Vector2(point[0]+site.position[0],point[1]+site.position[2]))
			var soil_material: ShaderMaterial = ground.duplicate(false)
			soil_material.set_shader_parameter("exclude_lake_terrain",false)
			soil_material.set_shader_parameter("surface_kind",float(patch.kind))
			soil_material.set_shader_parameter("surface_strength",float(patch.strength))
			soil_material.set_shader_parameter("boundary_count",boundary.size())
			soil_material.set_shader_parameter("boundary",boundary)
			soil_material.set_shader_parameter("dirt_texture",finish.soil(city,"dry").albedo_texture)
			soil_material.set_shader_parameter("gravel_texture",finish.soil(city,"gravel").albedo_texture)
			city._surface(owner,"SoilPatch_"+str(patch_index),polygon,.021+patch_index*.0004,soil_material,3.0)
			patch_index+=1
		city._buffer(city.get_node("Terrain/Pavements"),key+"_Branch",site.branch,4,.06,material)
		for placement in data.placements:
			if placement.site!=key:continue
			var visual: Node3D = load(data.assets[placement.asset].path).instantiate()
			visual.name=placement.asset+str(owner.get_child_count())
			visual.position=Vector3(placement.position[0],placement.position[1],placement.position[2])
			visual.rotation_degrees.y=placement.yaw
			if placement.has("scale"):visual.scale=Vector3(placement.scale[0],placement.scale[1],placement.scale[2])
			owner.add_child(visual)
			var faces := PackedVector3Array()
			var roof_meshes: Array = []
			var roof_zone := Rect2()
			for mesh in visual.find_children("*","MeshInstance3D",true,false):
				geometry._append_faces(mesh,owner,faces)
				var title := str(mesh.name).to_upper()
				if "TELHADO" in title or "EMPENA" in title or "COBERTURA" in title:
					var transform: Transform3D = owner.global_transform.affine_inverse()*mesh.global_transform
					var box: AABB = transform*mesh.mesh.get_aabb()
					var zone := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
					roof_zone=zone if roof_meshes.is_empty() else roof_zone.merge(zone)
					roof_meshes.append(mesh)
					mesh.set_meta("keep_individual_visual",true)
			for mesh in roof_meshes:
				mesh.set_meta("roof_zone",roof_zone)
				owner.roofs.append(mesh)
			geometry._collision(owner,faces,visual.name+"Collision")
