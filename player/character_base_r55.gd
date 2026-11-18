extends "res://player/character_base_r54.gd"

var reaction: RefCounted
var reaction_message = ""


func _ready() -> void:
    super._ready()
    reaction = load("res://personagem/reacoes.gd").new()
    reaction.setup(avatar, action, combat)


func _clearance(shape: Shape3D, transform: Transform3D) -> bool:
    var query = PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = transform
    query.exclude = [get_rid()]
    query.collision_mask = 1
    return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func can_fall() -> bool:
    var box = BoxShape3D.new()
    box.size = Vector3(.90, 1.90, 2.30)
    var centre = global_position + avatar.global_basis * Vector3(0, .98, -.90)
    return _clearance(box, Transform3D(avatar.global_basis, centre))


func can_stand() -> bool:
    var shape = CapsuleShape3D.new()
    shape.radius = .23
    shape.height = 1.84
    return _clearance(shape, Transform3D(Basis.IDENTITY, global_position + Vector3(0, .94, 0)))


func request_reaction(id: String) -> bool:
    reaction_message = ""
    if paused:
        return false
    if id in ["fall", "death"] and not reaction.is_active() and not can_fall():
        reaction_message = "Sem espaço livre para a queda"
        return false
    if id == "get_up" and not can_stand():
        reaction_message = "Sem espaço livre para levantar"
        return false
    if not reaction.is_active() and not set_crouch(false):
        return false
    preview_motion = ""
    return reaction.begin(id)


func _prepare_action() -> bool:
    return not reaction.is_active() and super._prepare_action()


func toggle_guard() -> bool:
    return not reaction.is_active() and super.toggle_guard()


func request_attack(id: String = "") -> bool:
    return not reaction.is_active() and super.request_attack(id)


func set_preview(id: String) -> bool:
    if reaction != null and reaction.is_active():
        return false
    return super.set_preview(id)


func restore_collision() -> void:
    capsule.transform = Transform3D(Basis.IDENTITY, Vector3(0, .78 if crouched else .92, 0))


func _reaction_collision() -> void:
    var rig: Skeleton3D = avatar.skeleton
    var index = rig.find_bone("Root")
    var root_skin = rig.get_bone_global_pose(index) * rig.get_bone_global_rest(index).affine_inverse()
    var axis = (avatar.basis * root_skin.basis * Vector3.UP).normalized()
    var centre = avatar.basis * (root_skin * Vector3(0, .92, 0))
    centre.y = .23 + absf(axis.y) * (.92 - .23)
    capsule.transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)), centre)


func _physics_process(delta: float) -> void:
    if not reaction.is_active():
        restore_collision()
        super._physics_process(delta)
        return
    velocity.x = 0
    velocity.z = 0
    avatar.motion_paused = paused
    _reaction_collision()
    velocity.y = -.2 if is_on_floor() else velocity.y - 9.8 * delta
    move_and_slide()
    reaction.advance(delta)
    motion_id = avatar.motion


func _unhandled_key_input(event: InputEvent) -> void:
    if scripted or not event is InputEventKey or not event.pressed or event.echo:
        return
    var shortcuts = {KEY_H: "hit_front", KEY_J: "stagger", KEY_K: "fall", KEY_L: "get_up", KEY_M: "death"}
    if shortcuts.has(event.physical_keycode):
        request_reaction(shortcuts[event.physical_keycode])
        return
    if reaction.is_active():
        return
    super._unhandled_key_input(event)
