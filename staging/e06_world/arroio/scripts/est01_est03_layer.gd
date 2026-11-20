extends RefCounted
## Supplied civic meshes, selective collision and reversible municipal placement.
const DATA := "res://staging/e06_world/arroio/data/est01_est03_part01.json"

static func adjusted(city: Node3D, name: String, data: Variant) -> Variant:
	if not city.apply_est01_est03_models or name not in ["landscape","civic_infrastructure","parcels"]:
		return data
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if name=="parcels":
		data.append_array(definitions.new_parcels)
	elif name=="civic_infrastructure":
		var replaced: Array = []
		for site in definitions.sites.values():
			if site.replaces!=null:replaced.append(site.replaces)
		data.buildings=data.buildings.filter(func(building):return building.id not in replaced)
	else:
		for move in definitions.relocated_trees:
			data.trees[int(move.source_index)].position=move.position
	return data

func configure(city: Node3D) -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for identifier in definitions.sites:
		var site: Dictionary = definitions.sites[identifier]
		var owner := Node3D.new()
		owner.name=identifier
		owner.position=Vector3(site.position[0],site.position[1],site.position[2])
		owner.rotation_degrees.y=site.yaw_degrees
		owner.set_meta("establishment",site)
		city.get_node("UrbanDressing/"+site.sector).add_child(owner)
		var visual: Node3D = load(site.visual_path).instantiate()
		visual.name="Visual"
		owner.add_child(visual)
		preload("res://staging/e06_world/arroio/scripts/civic_vegetation_layer.gd").prepare(city,identifier,visual)
		if identifier=="EST02":
			_install_gate(owner,visual,"PORTAO_L_",true)
			_install_gate(owner,visual,"PORTAO_R_",false)
		var faces := PackedVector3Array()
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			if mesh.has_meta("vegetation_replaced"):continue
			var title := str(mesh.name)
			if title.begins_with("EST_SOFT_") or "ESCADA_ENTRADA_DEGRAU" in title or "R05_DEGRAU_BOLEADO" in title or title=="EST03_DEGRAU_ENTRADA":
				continue
			_append_faces(mesh,owner,faces)
		_collision(owner,faces,"BuildingCollision")
		if identifier=="EST01":
			_ramp(owner,0,3.1,20.0,18.7,-.025,.09,"LotEntryRamp",city.material_cache.paving)
			_ramp(owner,0,3.1,18.7,17.0,.09,.09,"LotEntryLanding",city.material_cache.paving)
			_ramp(owner,0,3.42,15.7,14.20,.08,.36)
		if identifier=="EST03":
			_ramp(owner,-1,3,18.0,15.8,-.025,.17,"LotEntryRamp",city.material_cache.paving)
			_ramp(owner,-1,3,15.8,13.1,.17,.17,"LotEntryLanding",city.material_cache.paving)
			_ramp(owner,-1,3,13.3,10.50,.17,.205)
			var loading_access := Node3D.new()
			loading_access.name="LoadingDockAccess"
			loading_access.position=Vector3(6.10,0,-7.45)
			loading_access.rotation.y=PI
			owner.add_child(loading_access)
			_ramp(loading_access,0,1.2,3.05,0,-.025,.44,"LoadingDockRamp",city.material_cache.paving)
			var loading_link := NavigationLink3D.new()
			loading_link.name="LoadingDockNavigation"
			loading_link.start_position=Vector3(6.1,.1,-10.65)
			loading_link.end_position=Vector3(6.1,.55,-7.25)
			loading_link.bidirectional=true
			owner.add_child(loading_link)
		var route: Array = site.routes[0].points
		if site.has("access_road"):
			city._buffer(city.get_node("Terrain/Pavements"),identifier+"_RuralAccess",site.access_road.points,site.access_road.width_m,.022,city.material_cache.dirt)
			city._buffer(city.get_node("Terrain/Pavements"),identifier+"_MaintenanceWalk",site.maintenance_walk,1.8,.022,city.material_cache.dirt)
		else:
			city._buffer(city.get_node("Terrain/Pavements"),identifier+"_StreetConnection",route,2.1,.022,city.material_cache.paving)

func _append_faces(mesh: MeshInstance3D, owner: Node3D, output: PackedVector3Array) -> void:
	var local: Transform3D = owner.global_transform.affine_inverse()*mesh.global_transform
	for point in mesh.mesh.get_faces():output.append(local*point)

func _collision(owner: Node3D, faces: PackedVector3Array, title: String) -> void:
	var body := StaticBody3D.new()
	body.name=title
	body.collision_layer=1
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision=true
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	owner.add_child(body)

func _install_gate(owner: Node3D, visual: Node3D, prefix: String, left: bool) -> void:
	var members: Array = []
	var bounds := AABB()
	for mesh in visual.find_children(prefix+"*","MeshInstance3D",true,false):
		var local: Transform3D = owner.global_transform.affine_inverse()*mesh.global_transform
		var box: AABB = local*mesh.mesh.get_aabb()
		bounds=box if members.is_empty() else bounds.merge(box)
		members.append(mesh)
	var hinge := Node3D.new()
	hinge.name="GateLeft" if left else "GateRight"
	hinge.position=Vector3(bounds.position.x if left else bounds.end.x,0,bounds.get_center().z)
	hinge.set_meta("keep_individual_visual",true)
	owner.add_child(hinge)
	for mesh in members:mesh.reparent(hinge,true)
	var faces := PackedVector3Array()
	for mesh in members:_append_faces(mesh,hinge,faces)
	_collision(hinge,faces,"GateCollision")
	hinge.rotation.y=PI/2 if left else -PI/2
	hinge.set_meta("default_open_degrees",90)

func _ramp(owner: Node3D, x: float, width: float, front: float, back: float, low: float, high: float, title: String="EntranceRamp", material: Material=null) -> void:
	var points := PackedVector3Array()
	var bottom := minf(low,high)-.04
	for side in [-1,1]:
		points.append(Vector3(x+side*width/2,bottom,front))
		points.append(Vector3(x+side*width/2,low,front))
		points.append(Vector3(x+side*width/2,bottom,back))
		points.append(Vector3(x+side*width/2,high,back))
	var shape := ConvexPolygonShape3D.new()
	shape.points=points
	var collider := CollisionShape3D.new()
	collider.name=title+"Collision"
	collider.shape=shape
	var body := StaticBody3D.new()
	body.name=title
	body.add_child(collider)
	owner.add_child(body)
	if material!=null:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var corners := [Vector3(x-width/2,low,front),Vector3(x+width/2,low,front),Vector3(x+width/2,high,back),Vector3(x-width/2,high,back)]
		var uvs := [Vector2(0,0),Vector2(width,0),Vector2(width,front-back),Vector2(0,front-back)]
		for index in [0,2,1,0,3,2]:
			tool.set_uv(uvs[index]/1.4);tool.add_vertex(corners[index])
		tool.generate_normals();tool.generate_tangents()
		var surface := MeshInstance3D.new()
		surface.name=title+"Surface";surface.mesh=tool.commit();surface.material_override=material
		owner.add_child(surface)
