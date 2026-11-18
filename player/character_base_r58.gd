extends "res://player/character_base_r55.gd"

var traversal: RefCounted
var movement_condition = "normal"
var last_obstacle_key = 0
var last_obstacle_request = false


func _ready() -> void:
    super._ready()
    traversal = load("res://personagem/travessia.gd").new()
    traversal.setup(self)


func set_movement_condition(value: String) -> bool:
    if value not in ["normal", "injured_left", "injured_right", "tired"]:
        return false
    if paused or traversal.is_active() or reaction.is_active() or action.state != "idle" or combat.guarding:
        return false
    movement_condition = value
    preview_motion = ""
    return true


func _movement_speed(running: bool, guarding: bool) -> float:
    if crouched or guarding:
        return .65
    var id: String = avatar.state_motion.motion_for(movement_condition, true, running)
    if avatar.state_motion.definitions.has(id):
        return avatar.state_motion.definitions[id].speed
    return 3.0 if running else .65


func _movement_motion(moving: bool, running: bool) -> String:
    if crouched:
        return "crouch" if moving else "crouch_idle"
    return avatar.state_motion.motion_for(movement_condition,moving,running)


func nearest_obstacle(window_only: bool = false) -> Node3D:
    var nearest: Node3D
    var distance = 2.2
    for candidate in get_tree().get_nodes_in_group("obstacles_r57"):
        if window_only and candidate.kind != "window":
            continue
        var value: float = candidate.global_position.distance_to(global_position)
        if value < distance:
            nearest = candidate
            distance = value
    return nearest


func request_cross(obstacle: Node3D = null) -> bool:
    if obstacle == null:
        obstacle = nearest_obstacle()
    return is_instance_valid(obstacle) and traversal.begin(obstacle, "vault_fence" if obstacle.kind == "fence" else "vault_window")


func request_open(obstacle: Node3D = null) -> bool:
    if obstacle == null:
        obstacle = nearest_obstacle(true)
    return is_instance_valid(obstacle) and traversal.begin(obstacle, "open_window")


func _prepare_action() -> bool:
    return not traversal.is_active() and super._prepare_action()


func request_reaction(id: String) -> bool:
    return not traversal.is_active() and super.request_reaction(id)


func request_attack(id: String = "") -> bool:
    return not traversal.is_active() and super.request_attack(id)


func toggle_guard() -> bool:
    return not traversal.is_active() and super.toggle_guard()


func set_preview(id: String) -> bool:
    return (traversal == null or not traversal.is_active()) and super.set_preview(id)


func _physics_process(delta: float) -> void:
    if not traversal.is_active():
        super._physics_process(delta)
        return
    avatar.motion_paused = paused
    velocity = Vector3.ZERO
    traversal.advance(delta)
    motion_id = avatar.motion


func _unhandled_key_input(event: InputEvent) -> void:
    if scripted or not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.physical_keycode == KEY_V:
        last_obstacle_key = KEY_V
        last_obstacle_request = request_open()
        return
    if event.physical_keycode == KEY_B:
        last_obstacle_key = KEY_B
        last_obstacle_request = request_cross()
        return
    if traversal.is_active():
        if event.physical_keycode == KEY_ESCAPE:
            traversal.cancel()
        return
    super._unhandled_key_input(event)
