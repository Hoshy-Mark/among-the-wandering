extends RefCounted
## Shared Z2 landscape assets replace the civic models' provisional vegetation.
const DATA := "res://staging/e06_world/arroio/data/civic_vegetation.json"

static func adjusted(city: Node3D, name: String, data: Variant) -> Variant:
	if not city.apply_civic_vegetation or name not in ["landscape","ground_cover"]:
		return data
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if name=="landscape":
		for replacement in definitions.tree_overrides:
			var owner: String = replacement.tree.get("civic_owner","")
			if owner.is_empty() or _enabled(city,owner):
				data.trees[int(replacement.source_index)]=replacement.tree
	else:
		for item in definitions.ground_cover:
			if _enabled(city,item.civic_owner):data.items.append(item)
	return data

static func _enabled(city: Node3D, identifier: String) -> bool:
	return city.apply_est01_est03_models if identifier in ["EST01","EST02","EST03"] else city.apply_est04_est09_models

static func prepare(city: Node3D, identifier: String, visual: Node3D) -> void:
	if not city.apply_civic_vegetation:return
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var hidden: Array = definitions.sites[identifier].hidden_meshes
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name) in hidden:
			mesh.visible=false
			mesh.set_meta("keep_individual_visual",true)
			mesh.set_meta("vegetation_replaced",true)
