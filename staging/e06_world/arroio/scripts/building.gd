extends Node3D
## Urban anchors follow the active layout catalog; Visual keeps its metric size.
@export var building_id: String = ""
@export var generate_collision: bool = true

func _ready() -> void:
	var world: Node = get_parent()
	while world != null and not world.has_method("catalog"): world = world.get_parent()
	if world != null and world.apply_lot_overrides and FileAccess.file_exists("res://staging/e06_world/arroio/data/lot_overrides.json"):
		var rule: Dictionary = world.catalog("lot_overrides").lots.get(building_id,{})
		if rule.get("enabled",false) and has_node("Visual"):
			var old: Node3D = get_node("Visual")
			var replacement: Node3D = load(rule.visual_path).instantiate()
			replacement.name = "Visual"
			replacement.transform = old.transform
			if rule.has("visual_translation_world"):
				var shift: Array = rule.visual_translation_world
				replacement.position += global_basis.inverse()*Vector3(shift[0],shift[1],shift[2])
			remove_child(old)
			old.free()
			add_child(replacement)
			set_meta("lot_art_revision",rule.revision)
			if rule.get("master_candidate",false):_install_review_doors(replacement)
	add_to_group("urban_buildings")
	if not generate_collision or not has_node("Visual"):
		return
	var faces := PackedVector3Array()
	_collect_faces(get_node("Visual"), faces)
	if faces.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "BuildingCollision"
	body.collision_layer = 1
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _install_review_doors(visual: Node3D) -> void:
	for mesh in visual.find_children("*PORTA_FOLHA","MeshInstance3D",true,false):
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		var low := Vector3(INF,INF,INF)
		var high := Vector3(-INF,-INF,-INF)
		for vertex in faces:
			var point: Vector3 = mesh.global_transform*vertex
			low=low.min(point)
			high=high.max(point)
		var hinge := Node3D.new()
		hinge.name="ReviewDoor_"+str(mesh.name)
		add_child(hinge)
		hinge.global_position=Vector3(low.x,low.y,(low.z+high.z)/2) if high.x-low.x>high.z-low.z else Vector3((low.x+high.x)/2,low.y,low.z)
		hinge.set_meta("closed_basis",hinge.basis)
		hinge.set_meta("door_center_world",(low+high)/2)
		hinge.add_to_group("arroio_review_doors")
		mesh.reparent(hinge,true)
		mesh.set_meta("keep_individual_visual",true)
		var body := StaticBody3D.new()
		body.name="DoorCollision"
		hinge.add_child(body)
		var door_faces := PackedVector3Array()
		for vertex in faces:door_faces.append(hinge.global_transform.affine_inverse()*mesh.global_transform*vertex)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(door_faces)
		var collider := CollisionShape3D.new()
		collider.shape=shape
		body.add_child(collider)

func set_review_doors_open(opened: bool) -> void:
	# Review-only hinge pose, without adding player interaction or interior gameplay.
	for child in get_children():
		if child is Node3D and str(child.name).begins_with("ReviewDoor_"):
			child.basis=child.get_meta("closed_basis")
			if opened:child.global_basis=Basis(Vector3.UP,PI/2)*child.global_basis

func _collect_faces(node: Node, faces: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var transform_to_anchor: Transform3D = global_transform.affine_inverse() * node.global_transform
		for vertex in node.mesh.get_faces():
			faces.append(transform_to_anchor * vertex)
	for child in node.get_children():
		_collect_faces(child, faces)
