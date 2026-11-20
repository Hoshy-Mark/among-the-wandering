extends Node3D
var doors: Dictionary = {}
var floor_meshes: Array[MeshInstance3D] = []
var roof_meshes: Array[MeshInstance3D] = []
var shown_floor := -1

func configure_doors(records: Array) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(.27,.34,.31)
	material.metallic=.55
	material.roughness=.78
	for kind in ["normal","roughness"]:
		var path := "res://main/world/structures/residential/materials/z2_shared/maps/"+("metal_normal_b04a6e15d899.png" if kind=="normal" else "metal_roughness_28a249d502f6.png")
		if kind=="normal":material.normal_enabled=true;material.normal_texture=load(path)
		else:material.roughness_texture=load(path)
	for record in records:
		var pivot := Node3D.new()
		pivot.name=record.id
		var p: Array = record.hinge_world
		pivot.position=Vector3(p[0],p[1],p[2])
		pivot.set_meta("record",record)
		pivot.set_meta("open",false)
		add_child(pivot)
		var body := StaticBody3D.new()
		body.name="DoorCollision"
		body.position=Vector3(0,record.door_height/2,-record.door_width/2)
		pivot.add_child(body)
		var shape := BoxShape3D.new()
		shape.size=Vector3(record.door_thickness,record.door_height,record.door_width)
		var collider := CollisionShape3D.new()
		collider.shape=shape
		body.add_child(collider)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size=shape.size
		mesh.mesh=box
		mesh.material_override=material
		mesh.set_meta("prison_floor",int(record.floor))
		body.add_child(mesh)
		doors[record.id]=pivot
	for mesh in find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("prison_floor"):floor_meshes.append(mesh)
		if mesh.has_meta("prison_roof"):roof_meshes.append(mesh)

func set_door(identifier: String, opened: bool, animated: bool=false) -> void:
	var pivot: Node3D = doors[identifier]
	if pivot.has_meta("tween"):
		var previous: Tween = pivot.get_meta("tween")
		if previous.is_valid():previous.kill()
	var angle := float(pivot.get_meta("record").swing_sign)*PI/2 if opened else 0.0
	pivot.set_meta("open",opened)
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
	var level := 4
	if is_instance_valid(player):
		var point := to_local(player.global_position)
		if absf(point.x)<120 and absf(point.z)<95:level=clampi(floori((point.y-.3)/4.05)+1,1,3)
	if level==shown_floor:return
	shown_floor=level
	for mesh in floor_meshes:mesh.visible=int(mesh.get_meta("prison_floor"))<=level
	for mesh in roof_meshes:mesh.visible=level==4

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_E:return
	var player := _player()
	if not is_instance_valid(player):return
	var nearest: Node3D
	var distance := 2.5
	for pivot in doors.values():
		var value: float = pivot.global_position.distance_to(player.global_position)
		if value<distance:nearest=pivot;distance=value
	if nearest!=null:
		set_door(str(nearest.name),not nearest.get_meta("open"),true)
		get_viewport().set_input_as_handled()
