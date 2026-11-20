extends RefCounted
const BASE := "res://staging/e06_world/arroio/"
var geometry = preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new()
var materials: Dictionary = {}

static func adjusted(city: Node3D, name: String, data: Variant) -> Variant:
	if not city.apply_rural_models or name not in ["landscape","ground_cover"]:return data
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/rural_lrp03_lrp05.json"))
	if name=="landscape":data.trees.append_array(definition.trees)
	else:data.items.append_array(definition.ground_cover)
	return data

func configure(city: Node3D) -> void:
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/rural_lrp03_lrp05.json"))
	var finish = preload("res://staging/e06_world/arroio/scripts/z2_finish.gd")
	var road_material: StandardMaterial3D = finish.soil(city,"dry").duplicate()
	road_material.albedo_color=Color(.65,.63,.60)
	var ground: ShaderMaterial = city.get_node("Terrain/Ground/FlatSouthernGround").material_override
	city._buffer(city.get_node("Terrain/Pavements"),"RuralSecondaryRoad",definition.spine,4.8,.045,road_material)
	for key in definition.sites:
		var site: Dictionary = definition.sites[key]
		var owner := Node3D.new()
		owner.set_script(load(BASE+"scripts/rural_runtime.gd"))
		owner.name=key
		owner.position=Vector3(site.position[0],site.position[1],site.position[2])
		city.add_child(owner)
		var visual: Node3D = load(site.visual_path).instantiate()
		visual.name="Visual"
		owner.add_child(visual)
		var pad := PackedVector2Array()
		for p in site.expansion_ground:pad.append(Vector2(p[0],p[1]))
		city._surface(owner,"ExpandedWorkyard",pad,.018,finish.soil(city,"gravel"),3.0)
		var extension: Array = []
		for p in site.extension_path:extension.append([p[0]+site.position[0],p[1]+site.position[2]])
		city._buffer(city.get_node("Terrain/Pavements"),key+"_AnnexWalk",extension,1.8,.052,road_material)
		var faces := PackedVector3Array()
		var roof_zones: Dictionary = {}
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			var title := str(mesh.name)
			var family: String = site.families[title]
			if title in site.hidden_meshes:
				mesh.visible=false;mesh.set_meta("keep_individual_visual",true)
				continue
			var is_ground := title.begins_with("TERRENO_") or title.begins_with("LRP03_CAMINHO") or title.begins_with("LRP03_TERREIRO") or title.begins_with("ESTRADA_TERRA") or title.begins_with("TERREIRO_") or title.begins_with("SOLO_BARRO")
			if is_ground:
				var material: ShaderMaterial = ground.duplicate(false)
				material.set_shader_parameter("exclude_lake_terrain",false)
				material.set_shader_parameter("dirt_texture",finish.soil(city,"dry").albedo_texture)
				material.set_shader_parameter("grass_texture",finish.soil(city,"mosaic").albedo_texture)
				material.set_shader_parameter("surface_kind",3.0 if "BARRO" in title else 2.0 if "CAMINHO_CASA" in title else 4.0 if "PISO_ORDENHA" in title else 1.0)
				material.set_shader_parameter("surface_strength",.72 if "CURRAL" in title else .94)
				mesh.material_override=material
			elif family in definition.surface_details:
				mesh.material_override=_pbr(mesh,family,definition.surface_details[family])
			var roof := (family in ["ceramic","fibro"] and ("TELHADO" in title or "COBERTURA" in title or "AGUA_" in title or "CUMEEIRA" in title)) or "EMPENA" in title or "CUMEEIRA" in title
			if roof:
				var group := "CASA" if "CASA" in title else "FENO" if "FENO" in title else "LEITE" if "RESFRIAMENTO" in title else "GALPAO"
				var box: AABB = mesh.mesh.get_aabb()
				var zone := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
				roof_zones[group]=zone if not roof_zones.has(group) else roof_zones[group].merge(zone)
				mesh.set_meta("roof_group",group)
				mesh.set_meta("keep_individual_visual",true)
				owner.roofs.append(mesh)
			if title in site.doors:
				owner.install_door(mesh)
				continue
			if "ESCADA_ACESSO" in title or "DEGRAU" in title:continue
			geometry._append_faces(mesh,owner,faces)
		geometry._collision(owner,faces,"FarmCollision")
		for mesh in owner.roofs:mesh.set_meta("roof_zone",roof_zones[mesh.get_meta("roof_group")])
		city._buffer(city.get_node("Terrain/Pavements"),key+"_Road",site.branch,4.8,.046,road_material)
		city._buffer(city.get_node("Terrain/Pavements"),key+"_Footpath",site.pedestrian_path,1.5,.049,road_material)
		for placement in definition.placements:
			if placement.site!=key:continue
			var item: Node3D = load(definition.props[placement.asset].path).instantiate()
			item.name=placement.asset+str(owner.get_child_count())
			item.position=Vector3(placement.position[0],placement.position[1],placement.position[2])
			item.rotation_degrees.y=placement.yaw
			owner.add_child(item)
			var prop_faces := PackedVector3Array()
			for mesh in item.find_children("*","MeshInstance3D",true,false):geometry._append_faces(mesh,owner,prop_faces)
			geometry._collision(owner,prop_faces,item.name+"Collision")
		if key=="LRP03":
			geometry._ramp(owner,14.8,1.35,1,-1.7,-.02,.24,"PorchRamp")
			geometry._ramp(owner,14.8,1.35,-1.7,-2.8,.24,.24,"PorchLanding")
			geometry._ramp(owner,14.8,1.35,-2.8,-3,.24,.4,"HouseThreshold")
			geometry._ramp(owner,14.8,1.35,-3,-4.5,.4,.4,"HouseLanding")
			geometry._ramp(owner,-14,3,3,1.7,-.02,.34,"BarnThreshold")
			geometry._ramp(owner,-14,3,1.7,.6,.34,.34,"BarnLanding")
		if key=="LRP04":
			geometry._ramp(owner,-25,3,3,1.6,-.02,.16,"StableThreshold")
			geometry._ramp(owner,-25,3,1.6,-.5,.16,.16,"StableLanding")
			geometry._ramp(owner,14.9,1.5,26.5,25,-.02,.245,"PorchRamp")
			geometry._ramp(owner,14.9,1.5,25,23.5,.245,.245,"PorchLanding")
			geometry._ramp(owner,14.9,1.35,23.5,21.6,.245,.18,"HouseThreshold")
		if key=="LRP05":
			geometry._ramp(owner,-31,2,35,33.7,-.02,.29,"PorchRamp")
			geometry._ramp(owner,-31,2,33.7,31.8,.29,.29,"PorchLanding")
			geometry._ramp(owner,-31,1.65,31.8,28.7,.29,.25,"HouseThreshold")
			geometry._ramp(owner,17,2.5,2,-1.4,-.02,.29,"MilkingPlatformRamp")
			geometry._ramp(owner,17,2.5,-1.4,-3,.29,.29,"MilkingLanding")
			geometry._ramp(owner,40,2,2,.5,-.02,.25,"MilkRoomThreshold")
			geometry._ramp(owner,40,2,.5,-.5,.25,.25,"MilkRoomLanding")
			geometry._ramp(owner,-22,3,10,6.5,-.02,.24,"HayBarnThreshold")

func _pbr(mesh: MeshInstance3D, family: String, detail: Dictionary) -> ShaderMaterial:
	if materials.has(family):return materials[family]
	var source: StandardMaterial3D = mesh.get_active_material(0)
	var material := ShaderMaterial.new()
	material.shader=load(BASE+"scripts/rural_surface.gdshader")
	material.set_shader_parameter("detail_texture",source.albedo_texture)
	material.set_shader_parameter("detail_mean",detail.mean)
	material.set_shader_parameter("normal_texture",source.normal_texture)
	material.set_shader_parameter("roughness_texture",source.roughness_texture)
	material.set_shader_parameter("metalness",.55 if family=="metal" else 0.0)
	material.set_shader_parameter("age_strength",.1 if family in ["timber","plaster"] else .035)
	materials[family]=material
	return material
