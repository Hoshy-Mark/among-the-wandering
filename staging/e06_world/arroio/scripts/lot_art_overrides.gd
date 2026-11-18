extends RefCounted
## Authored candidate layers sit outside generated town catalogs.
var city: Node3D
var rule: Dictionary
var art: Node3D

func configure(world: Node3D) -> void:
	city = world
	rule = city.catalog("lot_overrides").lots.get("H01",{})
	if not rule.get("enabled",false): return
	art = Node3D.new()
	art.name = "H01_ArtRevision04"
	art.set_meta("decision_id",rule.decision_id)
	art.set_meta("visual_homologation",false)
	city.get_node("Landscape/S01").add_child(art)
	var surfaces: Array = []
	for path in ["Terrain/Pavements","Landscape/S01","UrbanDressing/S01/H01","UrbanDressing/S01/SEATING_H01","UrbanDressing/S01/RAIN_BARREL_H01","UrbanDressing/S01/FLOWER_BORDER_H01"]:
		var parent: Node = city.get_node_or_null(path)
		if parent!=null: surfaces.append_array(parent.find_children("*","MeshInstance3D",true,false))
	for node in surfaces:
		var kind := -1.0
		var title: String = node.name
		if title=="WornGround" or title=="LeafLitter_0":
			node.visible = false
			continue
		if title.begins_with("H01_Garden"): kind = 0
		if title.begins_with("APRON_H01"): kind = 1
		if title.begins_with("ACCESS_H01") or ("/H01/" in str(node.get_path()) and (title.begins_with("ThresholdRoute") or title.begins_with("ThresholdConnector"))): kind = 2
		if title.begins_with("COURTYARD_H01") or title=="WornGround": kind = 3
		if kind<0: continue
		var material := ShaderMaterial.new()
		material.shader = preload("res://staging/e06_world/arroio/scripts/h01_ground.gdshader")
		var original := node.material_override as ShaderMaterial
		var base: ShaderMaterial = city.get_node("Terrain/Ground/FlatSouthernGround").material_override
		for key in ["grass_texture","dirt_texture","paving_texture","gravel_texture"]: material.set_shader_parameter(key,base.get_shader_parameter(key))
		if original!=null:
			for key in ["boundary","boundary_count"]: material.set_shader_parameter(key,original.get_shader_parameter(key))
		material.set_shader_parameter("zone",kind)
		node.material_override = material
		art.set_meta("surface_overrides",int(art.get_meta("surface_overrides",0))+1)
	_fold_gate()
	_refine_objects()
	_refine_tree()
	_refine_cover()
	_add_litter()
	_add_shrubs()
	art.set_meta("status","executed candidate; director visual homologation pending")

func _fold_gate() -> void:
	var owner := city.get_node("UrbanDressing/S01/H01")
	var gate: Dictionary = rule.preserve.gate
	var center := Vector3(gate.center[0],0,gate.center[1])
	for side in [-1.0,1.0]:
		var pivot := center+Vector3(side*gate.opening_width_m/2,0,0)
		var rotation := Basis(Vector3.UP,side*PI/2)
		for node in owner.get_children():
			if node is MultiMeshInstance3D:
				for i in node.multimesh.instance_count:
					var transform: Transform3D = node.multimesh.get_instance_transform(i)
					var p := transform.origin
					if absf(p.x-pivot.x)<.02 and p.z>pivot.z+.01 and p.z<pivot.z+1.6 and (absf(p.y-.25)<.01 or absf(p.y-1.05)<.01 or absf(p.y-.65)<.01):
						transform.origin = pivot+rotation*(p-pivot)+Vector3(0,0,.125)
						transform.basis = rotation*transform.basis
						node.multimesh.set_instance_transform(i,transform)
			elif node is StaticBody3D:
				for shape in node.get_children():
					if absf(shape.position.x-pivot.x)<.02 and absf(shape.position.z-(pivot.z+.775))<.02:
						shape.position = pivot+rotation*(shape.position-pivot)+Vector3(0,0,.125)
						shape.basis = rotation*shape.basis
	art.set_meta("gate_pose","folded open; original hinge posts, center and opening unchanged")

func _refine_objects() -> void:
	for ident in ["SEATING_H01","RAIN_BARREL_H01","FLOWER_BORDER_H01"]:
		var owner := city.get_node_or_null("UrbanDressing/S01/"+ident)
		if owner==null:continue
		for node in owner.get_children():
			if node is MultiMeshInstance3D and node.material_override is StandardMaterial3D:
				var material: StandardMaterial3D = node.material_override.duplicate(false)
				material.roughness = .97
				if "wood" in node.name: material.albedo_color = Color(.84,.81,.76)
				node.material_override = material
				if ident=="FLOWER_BORDER_H01":
					if "blossom" in node.name: node.visible = false
					elif "leaf" in node.name:
						for i in node.multimesh.instance_count:
							var transform: Transform3D = node.multimesh.get_instance_transform(i)
							var variation := .70+.23*absf(sin(transform.origin.z*7.1+transform.origin.x*3.4))
							transform.basis = transform.basis.scaled(Vector3.ONE*variation)
							node.multimesh.set_instance_transform(i,transform)
			if ident=="RAIN_BARREL_H01" and (node is MultiMeshInstance3D or node is StaticBody3D): node.position.y += .035
	# A dry, stable footing; no downspout or damp halo is invented.
	var base := MeshInstance3D.new()
	base.name = "H01_BarrelFooting"
	var box := BoxMesh.new()
	box.size = Vector3(.96,.035,.91)
	base.mesh = box
	base.position = Vector3(34,.0175,162)
	base.material_override = city.get_node("UrbanDressing").palette.get("prop_yard_concrete",city.get_node("UrbanDressing").palette.yard_concrete)
	art.add_child(base)

func _refine_tree() -> void:
	var tree := city.get_node("UrbanDressing/S01/SHADE_H01")
	var leaf_nodes := 0
	var components := 0
	for node in tree.find_children("*","MeshInstance3D",true,false):
		if not "leaf" in node.name.to_lower(): continue
		var mesh := ArrayMesh.new()
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var neighbors := {}
			for i in range(0,indices.size(),3):
				for vertex in [indices[i],indices[i+1],indices[i+2]]:
					if not neighbors.has(vertex): neighbors[vertex] = []
					neighbors[vertex].append_array([indices[i],indices[i+1],indices[i+2]])
			var seen := {}
			for vertex in vertices.size():
				if seen.has(vertex):continue
				var pending: Array = [vertex]
				var component: Array = []
				while not pending.is_empty():
					var index: int = pending.pop_back()
					if seen.has(index):continue
					seen[index] = true
					component.append(index)
					pending.append_array(neighbors.get(index,[]))
				if component.size()>16:continue
				var anchor: Vector3 = vertices[component.min()]
				for index in component: vertices[index] = anchor+(vertices[index]-anchor)*rule.leaf_fill_factor
				components += 1
			arrays[Mesh.ARRAY_VERTEX] = vertices
			# Rebuilt surface deliberately has no imported decimation LODs.
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var original_id: int = node.mesh.get_instance_id()
		node.mesh = mesh
		node.set_meta("h01_source_mesh_id",original_id)
		node.set_meta("keep_individual_visual",true)
		leaf_nodes += 1
	art.set_meta("leaf_nodes_refined",leaf_nodes)
	art.set_meta("leaf_components_refined",components)
	art.set_meta("leaf_fill_factor",rule.leaf_fill_factor)

func _refine_cover() -> void:
	var count := 0
	if not city.has_node("GroundCover/S01"): return
	for visual in city.get_node("GroundCover/S01").get_children():
		var items: Array = visual.get_meta("catalog_items",[])
		for i in items.size():
			var item: Dictionary = items[i]
			if item.get("building_id")!="H01":continue
			var point := Vector2(item.position[0],item.position[1])
			var shade := maxf(exp(-pow(point.distance_to(Vector2(36,180))/4.5,2)),exp(-pow(point.distance_to(Vector2(39,170))/3.0,2)))
			var transform: Transform3D = visual.multimesh.get_instance_transform(i)
			transform.basis = transform.basis.scaled(Vector3.ONE*(.97-.57*shade))
			visual.multimesh.set_instance_transform(i,transform)
			count += 1
	art.set_meta("existing_clumps_refined",count)

func _add_litter() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(-.06,0,0),Vector3(0,.003,-.024),Vector3(.06,0,0),Vector3(-.06,0,0),Vector3(.06,0,0),Vector3(0,.003,.024)]:
		tool.set_uv(Vector2(p.x*8+.5,p.z*18+.5))
		tool.add_vertex(p)
	tool.generate_normals()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = tool.commit()
	multi.instance_count = 160
	for index in multi.instance_count:
		var center := Vector2(36,180) if index<95 else Vector2(39,170)
		var x := sin(index*17.77)*3.8
		var z := cos(index*9.131)*3.1
		var p := center+Vector2(x,z)
		multi.set_instance_transform(index,Transform3D(Basis(Vector3.UP,index*2.41).scaled(Vector3.ONE*(.7+.6*absf(sin(index*1.3)))),Vector3(p.x,.018,p.y)))
	var visual := MultiMeshInstance3D.new()
	visual.name = "H01_DryLeafLitter"
	visual.multimesh = multi
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.27,.21,.12)
	material.roughness = 1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	art.add_child(visual)

func _add_shrubs() -> void:
	var source: String = city.catalog("environment").assets.arbusto.path
	for index in rule.low_shrub_positions.size():
		var p: Array = rule.low_shrub_positions[index]
		var shrub: Node3D = load(source).instantiate()
		shrub.name = "H01_LowShrub_"+str(index)
		shrub.position = Vector3(p[0],.012,p[1])
		shrub.scale = Vector3.ONE*(.28+index*.035)
		art.add_child(shrub)
