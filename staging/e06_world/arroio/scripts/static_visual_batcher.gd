extends RefCounted
## Reversible runtime batching of static imported art. Never writes library files.
## Geometry, materials, normals, UVs and vertex colors are appended unchanged.
var cache: Dictionary = {}
var stats: Dictionary = {"models_batched":0,"source_meshes":0,"source_surfaces":0,"render_surfaces":0,"source_triangles":0,"render_triangles":0,"cache_hits":0,"geometry_checks":0}
const RENDER_NODE := "_StaticRender"
const LAYER_META := "e06_original_render_layers"

func batch_tree(node: Node) -> void:
	if _is_model(node):
		_batch_model(node)
		return
	for child in node.get_children(): batch_tree(child)

func restore_tree(node: Node) -> void:
	if _is_model(node):
		_restore_model(node)
		return
	for child in node.get_children(): restore_tree(child)

func _is_model(node: Node) -> bool:
	return node is Node3D and (node.scene_file_path.ends_with(".gltf") or node.scene_file_path.ends_with(".glb"))

func _collect(node: Node, root: Node3D, entries: Array) -> void:
	if node.has_meta("keep_individual_visual") or node.get_script() != null:
		return
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		var title := node.name.to_upper()
		if node.skin == null and node.mesh.get_blend_shape_count() == 0 and node.layers != 0 and node.visible and not ("PORTA" in title or "DOOR" in title or "FOLHA" in title):
			# Local chain avoids global floating-point round trips and shares cache
			# across instances with different urban positions, yaws and pivots.
			var transform := Transform3D.IDENTITY
			var cursor: Node = node
			while cursor != root:
				if cursor is Node3D: transform = cursor.transform * transform
				cursor = cursor.get_parent()
			var eligible := true
			for surface in node.mesh.get_surface_count():
				if node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: eligible = false
			if eligible: entries.append({"node":node,"transform":transform})
	for child in node.get_children(): _collect(child,root,entries)

func _batch_model(root: Node3D) -> void:
	if root.has_node(RENDER_NODE): return
	if not root.find_children("*","AnimationPlayer",true,false).is_empty() or not root.find_children("*","Skeleton3D",true,false).is_empty(): return
	var entries: Array = []
	_collect(root,root,entries)
	if entries.size() < 2: return
	var parts: PackedStringArray = [root.scene_file_path]
	for entry in entries:
		var source: MeshInstance3D = entry.node
		parts.append(str(source.mesh.get_instance_id())+str(entry.transform)+_settings(source))
		for surface in source.mesh.get_surface_count():
			var material := source.get_active_material(surface)
			parts.append(str(material.get_instance_id() if material != null else 0)+":"+str(source.mesh.surface_get_format(surface)))
	var signature := "|".join(parts)
	var prepared: Dictionary
	if cache.has(signature):
		prepared = cache[signature]
		stats.cache_hits += 1
	else:
		prepared = _prepare(entries)
		if prepared.is_empty(): return
		cache[signature] = prepared
	var container := Node3D.new()
	container.name = RENDER_NODE
	for bundle in prepared.bundles:
		var visual := MeshInstance3D.new()
		visual.name = "MaterialBatch_"+str(container.get_child_count())
		visual.mesh = bundle.mesh
		visual.layers = bundle.layers
		visual.cast_shadow = bundle.shadow
		visual.transparency = bundle.transparency
		container.add_child(visual)
	root.add_child(container)
	for entry in entries:
		var source: MeshInstance3D = entry.node
		source.set_meta(LAYER_META,source.layers)
		# Unlike hide(), layers=0 leaves child nodes and interaction anchors alone.
		source.layers = 0
	stats.models_batched += 1
	stats.source_meshes += entries.size()
	stats.source_surfaces += prepared.source_surfaces
	stats.render_surfaces += prepared.render_surfaces
	stats.source_triangles += prepared.triangles
	stats.render_triangles += prepared.triangles
	stats.geometry_checks += 1

func _settings(source: MeshInstance3D) -> String:
	return str(source.layers)+":"+str(source.cast_shadow)+":"+str(source.transparency)

func _prepare(entries: Array) -> Dictionary:
	var groups: Dictionary = {}
	var bundles: Dictionary = {}
	var expected_triangles := 0
	var expected_surfaces := 0
	var expected_box: AABB
	var has_box := false
	for entry in entries:
		var source: MeshInstance3D = entry.node
		var mesh: ArrayMesh = source.mesh
		var box: AABB = entry.transform * mesh.get_aabb()
		expected_box = expected_box.merge(box) if has_box else box
		has_box = true
		var settings := _settings(source)
		if not bundles.has(settings):
			bundles[settings] = {"mesh":ArrayMesh.new(),"layers":source.layers,"shadow":source.cast_shadow,"transparency":source.transparency}
		for surface in mesh.get_surface_count():
			var material := source.get_active_material(surface)
			var key := settings+":"+str(mesh.surface_get_format(surface))+":"+str(material.get_instance_id() if material != null else 0)
			if not groups.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(material)
				groups[key] = {"tool":tool,"settings":settings}
			var tool: SurfaceTool = groups[key].tool
			tool.append_from(mesh,surface,entry.transform)
			var count: int = mesh.surface_get_array_index_len(surface)
			if count == 0: count = mesh.surface_get_array_len(surface)
			expected_triangles += count/3
			expected_surfaces += 1
	var actual_triangles := 0
	var actual_surfaces := 0
	var actual_box: AABB
	has_box = false
	for group in groups.values():
		var tool: SurfaceTool = group.tool
		tool.commit(bundles[group.settings].mesh)
	for bundle in bundles.values():
		var mesh: ArrayMesh = bundle.mesh
		actual_triangles += mesh.get_faces().size()/3
		actual_surfaces += mesh.get_surface_count()
		actual_box = actual_box.merge(mesh.get_aabb()) if has_box else mesh.get_aabb()
		has_box = true
	if actual_triangles != expected_triangles or expected_box.position.distance_to(actual_box.position)>0.001 or expected_box.end.distance_to(actual_box.end)>0.001:
		push_error("Static batching geometry check failed; original model retained")
		return {}
	return {"bundles":bundles.values(),"triangles":actual_triangles,"source_surfaces":expected_surfaces,"render_surfaces":actual_surfaces}

func _restore_model(root: Node3D) -> void:
	var container := root.get_node_or_null(RENDER_NODE)
	if container == null: return
	_restore_layers(root,container)
	root.remove_child(container)
	container.queue_free()

func _restore_layers(node: Node, container: Node) -> void:
	if node == container: return
	if node is MeshInstance3D and node.has_meta(LAYER_META):
		node.layers = node.get_meta(LAYER_META)
		node.remove_meta(LAYER_META)
	for child in node.get_children(): _restore_layers(child,container)
