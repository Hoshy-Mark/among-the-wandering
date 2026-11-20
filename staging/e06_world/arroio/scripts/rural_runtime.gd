extends Node3D
var doors: Dictionary = {}
var roofs: Array[MeshInstance3D] = []
var geometry = preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new()

func install_door(mesh: MeshInstance3D) -> void:
	var box := mesh.mesh.get_aabb()
	var pivot := Node3D.new()
	pivot.name="Door_"+str(mesh.name)
	pivot.position=Vector3(box.position.x,box.position.y,box.get_center().z)
	pivot.set_meta("open",false)
	add_child(pivot)
	mesh.reparent(pivot,true)
	mesh.set_meta("keep_individual_visual",true)
	var faces := PackedVector3Array()
	geometry._append_faces(mesh,pivot,faces)
	geometry._collision(pivot,faces,"DoorCollision")
	doors[str(pivot.name)]=pivot

func set_door(identifier: String, opened: bool, animated: bool=false) -> void:
	var pivot: Node3D = doors[identifier]
	if pivot.has_meta("tween"):
		var previous: Tween = pivot.get_meta("tween")
		if previous.is_valid():previous.kill()
	pivot.set_meta("open",opened)
	var angle := -PI*.53 if opened else 0.0
	if animated:
		var tween := create_tween()
		tween.tween_property(pivot,"rotation:y",angle,.35)
		pivot.set_meta("tween",tween)
	else:pivot.rotation.y=angle

func _player() -> Node3D:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player==null:player=get_tree().get_first_node_in_group("arroio_inspection_walker")
	return player

func _process(_delta: float) -> void:
	var player := _player()
	for mesh in roofs:
		var hide_roof := false
		if is_instance_valid(player):
			var p := to_local(player.global_position)
			var box: AABB = mesh.mesh.get_aabb()
			# Source vertices are baked in compound coordinates.
			var zone: Rect2 = mesh.get_meta("roof_zone")
			hide_roof=zone.has_point(Vector2(p.x,p.z)) and p.y<box.end.y+.5
		mesh.visible=not hide_roof

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_E:return
	var player := _player()
	if not is_instance_valid(player):return
	var closest: Node3D
	var distance := 2.5
	for pivot in doors.values():
		var d: float = pivot.global_position.distance_to(player.global_position)
		if d<distance:distance=d;closest=pivot
	if closest!=null:
		set_door(str(closest.name),not closest.get_meta("open"),true)
		get_viewport().set_input_as_handled()
