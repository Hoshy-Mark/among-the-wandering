extends "res://player/character_base_r53.gd"

var combat: RefCounted
var combat_target: StaticBody3D

func _ready() -> void:
    super._ready()
    combat = load("res://personagem/combate.gd").new()
    combat.setup(avatar, action)

func set_preview(id: String) -> bool:
    if combat != null:
        combat.set_guard(false)
    return super.set_preview(id)

func _prepare_action() -> bool:
    if combat.is_attacking():
        return false
    combat.set_guard(false)
    return super._prepare_action()

func toggle_guard() -> bool:
    if paused or not set_crouch(false):
        return false
    preview_motion = ""
    return combat.set_guard(not combat.guarding)

func request_attack(kind: String = "") -> bool:
    if paused or not is_instance_valid(combat_target) or not set_crouch(false):
        return false
    preview_motion = ""
    if kind.is_empty():
        kind = "strike_onehand" if combat.armed else "punch"
    var selected = "push_armed" if kind == "push" and combat.armed else kind
    return combat.begin(kind, Callable(combat_target, "try_hit").bind(avatar, kind, combat.definitions[selected]))

func _physics_process(delta: float) -> void:
    var input:=command
    var run:=command_run
    if not scripted:
        var right_pressed = Input.is_physical_key_pressed(KEY_D) or (not quick_slots_enabled and Input.is_physical_key_pressed(KEY_RIGHT))
        var left_pressed = Input.is_physical_key_pressed(KEY_A) or (not quick_slots_enabled and Input.is_physical_key_pressed(KEY_LEFT))
        var down_pressed = Input.is_physical_key_pressed(KEY_S) or (not quick_slots_enabled and Input.is_physical_key_pressed(KEY_DOWN))
        var up_pressed = Input.is_physical_key_pressed(KEY_W) or (not quick_slots_enabled and Input.is_physical_key_pressed(KEY_UP))
        input = Vector2(float(right_pressed) - float(left_pressed), float(down_pressed) - float(up_pressed))
        run=Input.is_physical_key_pressed(KEY_SHIFT)
    if not input.is_finite():
        input=Vector2.ZERO
    if paused:
        input=Vector2.ZERO
        velocity.x=0
        velocity.z=0
    var direction:=Vector3.ZERO
    if not input.is_zero_approx():
        preview_motion=""
        var right:=camera.global_basis.x
        var down:=camera.global_basis.z
        right.y=0
        down.y=0
        direction=(right.normalized()*input.x+down.normalized()*input.y).limit_length(1)
        if action.state!="idle":
            action.cancel("walk")
    var guarding: bool = combat.guarding
    if guarding and combat.is_attacking():
        direction = Vector3.ZERO
        velocity.x = 0
        velocity.z = 0
    var speed: float = _movement_speed(run, guarding)
    velocity.x=move_toward(velocity.x,direction.x*speed,delta*8)
    velocity.z=move_toward(velocity.z,direction.z*speed,delta*8)
    velocity.y=-.2 if is_on_floor() else velocity.y-9.8*delta
    move_and_slide()
    var moving:=Vector2(velocity.x,velocity.z).length()>.05
    motion_id = _movement_motion(moving, run)
    if not preview_motion.is_empty():
        motion_id=preview_motion
    if not paused and action.state=="idle" and not guarding:
        avatar.set_motion(motion_id)
    if guarding and is_instance_valid(combat_target) and not combat.is_attacking():
        var facing: Vector3 = combat_target.global_position - global_position
        avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(facing.x, facing.z), minf(1, delta * 12))
    elif moving and not guarding:
        avatar.rotation.y=lerp_angle(avatar.rotation.y,atan2(velocity.x,velocity.z),minf(1,delta*12))
    avatar.motion_paused=paused
    if guarding:
        var local_direction: Vector3 = avatar.global_basis.inverse() * direction
        combat.advance(delta, Vector2(local_direction.x, local_direction.z))
        motion_id = avatar.motion
    else:
        action.advance(delta)


func _movement_speed(running: bool, guarding: bool) -> float:
    return 3.0 if running and not crouched and not guarding else .65


func _movement_motion(moving: bool, running: bool) -> String:
    if crouched:
        return "crouch" if moving else "crouch_idle"
    return ("run" if running else "walk") if moving else "idle"

func _unhandled_key_input(event: InputEvent) -> void:
    if scripted or not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.physical_keycode:
        KEY_Q:
            toggle_guard()
        KEY_E:
            if not paused:
                combat.set_armed(not combat.armed)
        KEY_F:
            request_attack()
        KEY_SPACE:
            request_attack("push")
        KEY_ESCAPE:
            if combat.is_attacking():
                combat.cancel()
            else:
                combat.set_guard(false)
        KEY_C:
            if not paused:
                combat.set_guard(false)
    super._unhandled_key_input(event)
