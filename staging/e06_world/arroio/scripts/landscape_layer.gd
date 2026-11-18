extends Node3D
var canopy_material := ShaderMaterial.new()
var occlusion_target: Node3D
var reveal_enabled := true

func set_occlusion_target(target: Node3D) -> void:
	occlusion_target = target

func _process(_delta: float) -> void:
	if not is_instance_valid(occlusion_target):
		occlusion_target = get_tree().get_first_node_in_group("player") as Node3D
	var camera := get_viewport().get_camera_3d()
	canopy_material.set_shader_parameter("target_active",reveal_enabled and is_instance_valid(occlusion_target) and camera != null)
	if is_instance_valid(occlusion_target) and camera != null:
		canopy_material.set_shader_parameter("target_position",occlusion_target.global_position+Vector3.UP)
		canopy_material.set_shader_parameter("view_direction",-camera.global_basis.z)
## Shared tree geometry, trunk collisions and semantic ground surfaces.

func configure(city: Node3D) -> void:
	canopy_material.shader = load("res://staging/e06_world/arroio/scripts/canopy.gdshader")
	var data: Dictionary = city.catalog("landscape")
	for sector_id in ["S01","S02","S03","S04","S05","S06","Fields"]:
		var sector := Node3D.new()
		sector.name = sector_id
		add_child(sector)
	var gravel: Node3D = load(data.assets.gravel.path).instantiate()
	var gravel_material: Material = city._find_material(gravel)
	var base: ShaderMaterial = city.get_node("Terrain/Ground/FlatSouthernGround").material_override
	base.set_shader_parameter("gravel_texture",gravel_material.albedo_texture)
	gravel.free()
	for zone in data.get("ground_zones",[]):
		if zone.has("polygon"):
			_soil_patch(city,get_node(zone.sector),zone.id,city._points(zone.polygon),zone.material,0.013)
		else:
			for polygon in Geometry2D.offset_polyline(city._points(zone.points),zone.width_m/2,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
				_soil_patch(city,get_node(zone.sector),zone.id,polygon,zone.material,0.013)
	var courtyards := 0
	for surface in data.surfaces:
		if surface.sector != "Fields": courtyards += 1
		_soil_patch(city,get_node(surface.sector),surface.id,city._points(surface.polygon),surface.material)
	for walk in data.walks:
		for polygon in Geometry2D.offset_polyline(city._points(walk.points),walk.width_m/2,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
			_soil_patch(city,get_node(walk.sector),walk.id,polygon,"dirt")
	for road in city.catalog("roads"):
		var width: float = road.properties.road_width_m_proposed+2*road.properties.get("sidewalk_width_m_proposed",0)+2.5
		for polygon in Geometry2D.offset_polyline(city._points(road.geometry.coordinates),width/2,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND):
			_soil_patch(city,$Fields,"RoadShoulder_"+road.id,polygon,"dirt",0.007)
	var sources := {}
	for key in ["figueira","pitanga","araucaria"]:
		var source: Node3D = load(data.assets[key].path).instantiate()
		var groups := {}
		_collect(source,Transform3D.IDENTITY,groups)
		var bundles: Array = []
		for group in groups.values():
			bundles.append({"mesh":group.tool.commit(),"material":group.material})
		sources[key] = bundles
		source.free()
	var cells := {}
	for index in data.trees.size():
		var tree: Dictionary = data.trees[index]
		var key: String = tree.sector+"/"+tree.asset+"_"+str(floori(tree.position[0]/48))+"_"+str(floori(tree.position[1]/48))
		if not cells.has(key): cells[key] = {"sector":tree.sector,"asset":tree.asset,"items":[]}
		cells[key].items.append(tree)
		var body := StaticBody3D.new()
		body.name = "Trunk_"+str(index)
		body.position = Vector3(tree.position[0],0,tree.position[1])
		var collider := CollisionShape3D.new()
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.22*tree.scale
		trunk.height = 2.5*tree.scale
		collider.position.y = trunk.height/2
		collider.shape = trunk
		body.add_child(collider)
		get_node(tree.sector).add_child(body)
		if index%3 == 0:
			var polygon := PackedVector2Array()
			for corner in range(12):
				var angle := corner*TAU/12
				polygon.append(Vector2(tree.position[0],tree.position[1])+Vector2(cos(angle),sin(angle))*tree.radius_m*0.62)
			_soil_patch(city,get_node(tree.sector),"LeafLitter_"+str(index),polygon,"litter")
	for key in cells:
		var cell: Dictionary = cells[key]
		for bundle in sources[cell.asset]:
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = bundle.mesh
			multi.instance_count = cell.items.size()
			for index in cell.items.size():
				var tree: Dictionary = cell.items[index]
				var basis := Basis(Vector3.UP,deg_to_rad(tree.yaw)).scaled(Vector3.ONE*tree.scale)
				multi.set_instance_transform(index,Transform3D(basis,Vector3(tree.position[0],0,tree.position[1])))
			var visual := MultiMeshInstance3D.new()
			visual.name = "TreeCell_"+key.get_slice("/",1)+"_"+str(get_node(cell.sector).get_child_count())
			visual.multimesh = multi
			visual.material_override = bundle.material
			if cell.sector == "Fields": visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			get_node(cell.sector).add_child(visual)
	set_meta("tree_count",data.trees.size())
	set_meta("courtyard_count",courtyards)
	set_meta("clearing_count",data.surfaces.size()-courtyards)
	_bind_existing_canopies(city)

func _bind_existing_canopies(node: Node) -> void:
	if node is Node3D and node.scene_file_path.ends_with(".glb"):
		var path := node.scene_file_path.to_upper()
		if "FIGUEIRA" in path or "GUABIROBA" in path or "PITANGUEIRA" in path:
			for mesh in node.find_children("*","MeshInstance3D",true,false):
				if "leaf" in mesh.name.to_lower():
					mesh.material_override = canopy_material
					mesh.set_meta("keep_individual_visual",true)
	for child in node.get_children(): _bind_existing_canopies(child)

func _collect(node: Node3D,parent_transform: Transform3D,groups: Dictionary) -> void:
	var transform := parent_transform*node.transform
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			# These audited R2 sources encode their complete palette in vertices.
			var is_leaf := "leaf" in node.name.to_lower()
			var key := str(is_leaf)+"/"+str(node.mesh.surface_get_format(surface))
			if not groups.has(key):
				var material := StandardMaterial3D.new()
				material.vertex_color_use_as_albedo = true
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.roughness = 0.9
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"tool":tool,"material":canopy_material if is_leaf else material}
			if "leaf" in node.name.to_lower():
				# The Z2 source stores each blade face in both winding orders.
				# Double-sided shading renders it with one geometric copy.
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				# Each original blade is a disconnected component. Expand the blade
				# around its attachment, retaining the individual folded-leaf shape.
				var neighbors := {}
				for index in range(0,indices.size(),3):
					for vertex in [indices[index],indices[index+1],indices[index+2]]:
						if not neighbors.has(vertex): neighbors[vertex] = []
						neighbors[vertex].append_array([indices[index],indices[index+1],indices[index+2]])
				var visited := {}
				var blade_faces := PackedInt32Array()
				for vertex in range(vertices.size()):
					if visited.has(vertex): continue
					var pending := [vertex]
					var component: Array[int] = []
					while not pending.is_empty():
						var current: int = pending.pop_back()
						if visited.has(current): continue
						visited[current] = true
						component.append(current)
						pending.append_array(neighbors.get(current,[]))
					if component.size()>16: continue
					var anchor: Vector3 = vertices[component.min()]
					for current in component: vertices[current] = anchor+(vertices[current]-anchor)*2.4
					if component.size()==5:
						component.sort()
						blade_faces.append_array(PackedInt32Array([component[0],component[1],component[2],component[0],component[2],component[3]]))
				arrays[Mesh.ARRAY_VERTEX] = vertices
				var unique := PackedInt32Array()
				var seen := {}
				for index in range(0,indices.size(),3):
					var face := [indices[index],indices[index+1],indices[index+2]]
					var sorted_face := face.duplicate()
					sorted_face.sort()
					var signature := str(sorted_face)
					if seen.has(signature): continue
					seen[signature] = true
					unique.append_array(PackedInt32Array(face))
				arrays[Mesh.ARRAY_INDEX] = unique
				if blade_faces.size()*2 == unique.size(): arrays[Mesh.ARRAY_INDEX] = blade_faces
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				groups[key].tool.append_from(mesh,0,transform)
			else:
				groups[key].tool.append_from(node.mesh,surface,transform)
	for child in node.get_children():
		if child is Node3D: _collect(child,transform,groups)

func _soil_patch(city: Node3D,parent: Node3D,id: String,polygon: PackedVector2Array,kind: String,elevation: float = 0.011) -> void:
	var source: MeshInstance3D = city.get_node("Terrain/Ground/FlatSouthernGround")
	var material: ShaderMaterial = source.material_override.duplicate(false)
	if parent.name != "Fields":
		var center := Vector2.ZERO
		for point in polygon: center += point
		center /= polygon.size()
		for parcel in city.catalog("parcels"):
			if Geometry2D.is_point_in_polygon(center,city._points(parcel.geometry.coordinates[0])):
				var floor_kind: String = city.catalog("landscape").lot_surfaces.get(parcel.id,"grass")
				material.set_shader_parameter("underlay_kind",{"grass":0.0,"dirt":1.0,"gravel":2.0,"litter":3.0,"mixed":4.0}[floor_kind])
				break
	material.set_shader_parameter("surface_kind",{"gravel":2.0,"litter":3.0,"mixed":4.0}.get(kind,1.0))
	material.set_shader_parameter("boundary_count",mini(polygon.size(),32))
	var boundary := PackedVector2Array()
	for index in mini(polygon.size(),32): boundary.append(polygon[index*polygon.size()/mini(polygon.size(),32)])
	boundary.resize(32)
	material.set_shader_parameter("boundary",boundary)
	city._surface(parent,id,polygon,elevation,material,3.0)

func set_sector_enabled(id: String,enabled: bool) -> void:
	var sector: Node3D = get_node(id)
	sector.visible = enabled
	sector.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
