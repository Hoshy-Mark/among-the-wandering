extends RefCounted
const BASE := "res://staging/e06_world/arroio/"
var materials: Dictionary = {}

static func soil(city: Node3D, kind: String) -> StandardMaterial3D:
	var cache: Dictionary = city.get_meta("z2_soil_cache",{})
	if cache.has(kind):return cache[kind]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/rural_lrp03_lrp05.json"))
	var soil_definitions: Dictionary = data.soil_assets.duplicate()
	if FileAccess.file_exists(BASE+"data/civic_finish_review.json"):
		var civic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/civic_finish_review.json"))
		soil_definitions.merge(civic.soil_assets)
	var source: Node3D = load(soil_definitions[kind].path).instantiate()
	var material: StandardMaterial3D = city._find_material(source).duplicate()
	material.vertex_color_use_as_albedo=false
	material.normal_enabled=false
	material.metallic=0.0
	material.roughness=.97
	material.metallic_specular=.15
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.albedo_color=Color(.48,.49,.46) if kind=="gravel" else Color(.65,.63,.60) if kind=="dry" else Color(.72,.72,.70)
	cache[kind]=material
	city.set_meta("z2_soil_cache",cache)
	source.free()
	return material

func configure(city: Node3D) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/rural_lrp03_lrp05.json"))
	var civic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/civic_finish_review.json"))
	var floor_audit: Dictionary = {}
	var metal_template: StandardMaterial3D
	var roots: Array = []
	for key in ["LRP01","LRP02","LRP03","LRP04","LRP05","EST01","EST02","EST03","EST04","EST05","EST06","EST07","EST08","EST09"]:
		roots.append_array(city.find_children(key,"Node3D",true,false))
	roots.append_array(city.get_tree().get_nodes_in_group("z2_finish_owner"))
	var revised := 0
	for owner in roots:
		for mesh in owner.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh==null:continue
			var title := str(mesh.name).to_upper()
			var civic_site: Dictionary = civic.sites.get(str(owner.name),{})
			if not civic_site.is_empty():
				if str(mesh.name) in civic_site.preserved_meshes:
					if "QUADRA_LINHA" in title or "MARCA_PISO" in title:
						var paint: StandardMaterial3D = mesh.get_active_material(0).duplicate()
						paint.albedo_texture=null
						paint.normal_enabled=false
						paint.vertex_color_use_as_albedo=true
						paint.albedo_color=Color.WHITE
						paint.roughness=.97
						mesh.material_override=paint
					continue
				if civic_site.family_overrides.has(str(mesh.name)):
					if metal_template==null:
						var template: Node3D = load(data.props.reservatorio_elevado.path).instantiate()
						for sample in template.find_children("*","MeshInstance3D",true,false):
							if "TANQUE" in str(sample.name):metal_template=sample.get_active_material(0).duplicate();break
						metal_template.vertex_color_use_as_albedo=true
						metal_template.albedo_color=Color.WHITE
						template.free()
					mesh.material_override=metal_template
					revised+=1;continue
				if civic_site.rules.has(str(mesh.name)):
					var rule: Dictionary = civic_site.rules[str(mesh.name)]
					var floor_material: StandardMaterial3D = soil(city,rule.kind)
					if rule.painted:
						floor_material=mesh.get_active_material(0).duplicate()
						floor_material.vertex_color_use_as_albedo=true
						floor_material.normal_enabled=false
						floor_material.roughness=.97
					mesh.material_override=floor_material
					floor_audit[str(owner.name)]=int(floor_audit.get(str(owner.name),0))+1
					revised+=1;continue
			if owner.name=="LRP01":
				if ("MARGEM" in title or "SOLO_SATURADO" in title) and not "GALHO" in title:
					mesh.material_override=soil(city,"wet");revised+=1;continue
				if "TERRENO_PAMPA" in title and mesh.material_override is ShaderMaterial:
					mesh.material_override.set_shader_parameter("grass_texture",soil(city,"mosaic").albedo_texture)
					mesh.material_override.set_shader_parameter("dirt_texture",soil(city,"dry").albedo_texture)
			if mesh.material_override is ShaderMaterial:continue
			if "LETREIRO" in title or "PLACA" in title or "QUADRO" in title or "AVISO" in title:continue
			var source: Material = mesh.get_active_material(0)
			if not source is StandardMaterial3D:continue
			if owner.name=="LRP02" and mesh.mesh.get_aabb().end.y<.35 and ("PISO" in title or "PATIOS" in title or "ENTORNO" in title):
				mesh.material_override=soil(city,"paving")
				revised+=1;continue
			if ("CANTEIRO" in title or "ESTUFA" in title) and ("SOLO" in title or "SULCO" in title):
				mesh.material_override=soil(city,"wet");revised+=1;continue
			if source.albedo_texture==null or source.normal_texture==null or source.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
			var family := _family(source.resource_name)
			if family=="glass":continue
			var mean: float = data.surface_details.get(family,{"mean":.5}).mean
			var signature: String = str(owner.name)+family+str(source.albedo_texture.get_instance_id())+source.albedo_color.to_html()
			if not materials.has(signature):
				var material := ShaderMaterial.new()
				material.shader=load(BASE+"scripts/rural_surface.gdshader")
				material.set_shader_parameter("detail_texture",source.albedo_texture)
				material.set_shader_parameter("detail_mean",mean)
				material.set_shader_parameter("normal_texture",source.normal_texture)
				material.set_shader_parameter("roughness_texture",source.roughness_texture)
				material.set_shader_parameter("base_tint",source.albedo_color.srgb_to_linear())
				material.set_shader_parameter("metalness",source.metallic)
				material.set_shader_parameter("age_strength",float(civic_site.get("age_strength",.12)) if family in ["timber","plaster"] else .04)
				materials[signature]=material
			mesh.material_override=materials[signature]
			revised+=1
	city.set_meta("z2_civic_floor_audit",floor_audit)
	city.set_meta("z2_revised_meshes",revised)

func _family(title: String) -> String:
	var text := title.to_lower()
	for pair in [["plaster","plaster"],["concrete","concrete"],["stone","stone"],["reboco","plaster"],["concreto","concrete"],["timber","timber"],["fibro","fibro"],["ceramic","ceramic"],["pedra","stone"],["metal","metal"],["glass","glass"],["brick","brick"]]:
		if pair[0] in text:return pair[1]
	return "plaster"
