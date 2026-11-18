extends Node3D
## Reuse the imported Z2 mesh and vertex colors through local MultiMesh cells.

func configure(city: Node3D,environment: Dictionary) -> void:
	var sources := {}
	for key in ["capim","arbusto"]:
		var source: Node3D = load(environment.assets[key].path).instantiate()
		var meshes := source.find_children("*","MeshInstance3D",true,false)
		assert(meshes.size() == 1,"Ground-cover source must contain a single shared mesh")
		var visual: MeshInstance3D = meshes[0]
		var transform := visual.transform
		var cursor: Node3D = visual.get_parent()
		while cursor != source:
			transform = cursor.transform*transform
			cursor = cursor.get_parent()
		var material := visual.get_active_material(0)
		if material == null:
			var colored := StandardMaterial3D.new()
			colored.vertex_color_use_as_albedo = true
			colored.cull_mode = BaseMaterial3D.CULL_DISABLED
			colored.roughness = 0.95
			material = colored
		# Keep the source blades. Imported automatic LOD removes fine leaves.
		var full_mesh := ArrayMesh.new()
		for surface in visual.mesh.get_surface_count():
			full_mesh.add_surface_from_arrays(visual.mesh.surface_get_primitive_type(surface),visual.mesh.surface_get_arrays(surface))
		sources[key] = {"mesh":full_mesh,"transform":transform,"material":material}
		source.free()
	var cells := {}
	for item in city.catalog("ground_cover").items:
		var key: String = item.sector+"/"+item.asset+"_"+str(floori(item.position[0]/32))+"_"+str(floori(item.position[1]/32))
		if not cells.has(key): cells[key] = {"sector":item.sector,"asset":item.asset,"items":[]}
		cells[key].items.append(item)
	for key in cells:
		var cell: Dictionary = cells[key]
		if not has_node(cell.sector):
			var sector := Node3D.new()
			sector.name = cell.sector
			add_child(sector)
		var source: Dictionary = sources[cell.asset]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = source.mesh
		multi.instance_count = cell.items.size()
		for index in cell.items.size():
			var item: Dictionary = cell.items[index]
			var basis := Basis(Vector3.UP,deg_to_rad(item.yaw)).scaled(Vector3.ONE*item.scale)
			var placement := Transform3D(basis,Vector3(item.position[0],0.012,item.position[1]))
			multi.set_instance_transform(index,placement*source.transform)
		var visual := MultiMeshInstance3D.new()
		visual.name = key.get_slice("/",1)
		visual.multimesh = multi
		visual.set_meta("catalog_items",cell.items)
		visual.material_override = source.material
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		get_node(cell.sector).add_child(visual)
	set_meta("clump_count",city.catalog("ground_cover").items.size())
