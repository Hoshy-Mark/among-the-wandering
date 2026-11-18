extends RefCounted

signal finished(id: String, succeeded: bool)

var body: CharacterBody3D
var actor: Node3D
var path: RefCounted
var definitions: Dictionary
var target: Node3D
var token = -1
var state = "idle"
var id = ""
var cursor = 0.0
var elapsed = 0.0
var basis = Basis.IDENTITY
var anchor = Vector3.ZERO
var align_start = Vector3.ZERO
var effect_done = false
var effect_succeeded = false
var resume_guard = false
var rollback_fraction = 0.0
var processing = false
var message = ""
var playback_rate = 2.0


func setup(player: CharacterBody3D) -> void:
    body = player
    actor = body.avatar
    path = actor.obstacle_path
    definitions = path.definitions
    load("res://personagem/maos_apoio.gd").register(actor.hand_layer)



func is_active() -> bool:
    return state != "idle"


func _volume(sample: Dictionary) -> Transform3D:
    return Transform3D(Basis.IDENTITY,basis * sample.centre + Vector3.UP * .022)


func _clear(position: Vector3, sample: Dictionary) -> bool:
    var shape = CapsuleShape3D.new()
    shape.radius = .23
    shape.height = sample.height
    var query = PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = _volume(sample)
    query.transform.origin += position
    query.exclude = [body.get_rid()]
    query.collision_mask = 1
    var hits = body.get_world_3d().direct_space_state.intersect_shape(query, 1)
    if not hits.is_empty():
        message = "A passagem está ocupada"
        return false
    if sample.has("R"):
        var foot = SphereShape3D.new()
        foot.radius = .07
        query.shape = foot
        for side in ["R","L"]:
            query.transform = Transform3D(Basis.IDENTITY,anchor+basis*sample[side]+Vector3.UP*.003)
            if not body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
                message = "O trajeto das pernas está ocupado"
                return false
    return true


func _position(time: float) -> Vector3:
    var sample: Dictionary = path.sample(id, time)
    return anchor + basis * Vector3(sample.x, sample.lift, sample.z)


func _floor(position: Vector3) -> bool:
    var query = PhysicsRayQueryParameters3D.create(position + Vector3.UP * .25, position - Vector3.UP * .25, 1)
    var hit = body.get_world_3d().direct_space_state.intersect_ray(query)
    return not hit.is_empty() and hit.normal.y > .9 and absf(hit.position.y - position.y) < .04


func _preflight() -> bool:
    var action: Dictionary = definitions.actions[id]
    if not _floor(_position(0)) or not _floor(_position(action.duration)):
        message = "Piso de entrada ou chegada incompatível"
        return false
    for frame in 61:
        var time: float = action.duration * frame / 60
        if not _clear(_position(time), path.sample(id, time)):
            return false
    return true


func begin(obstacle: Node3D, action_id: String) -> bool:
    message = ""
    if processing or is_active() or body.paused or body.reaction.is_active() or not is_instance_valid(obstacle):
        message = "Aguarde a ação atual terminar"
        return false
    if not definitions.actions.has(action_id) or obstacle.kind != definitions.actions[action_id].kind:
        return false
    if not obstacle.global_basis.get_scale().is_equal_approx(Vector3.ONE) or absf(obstacle.global_rotation.x) > .001 or absf(obstacle.global_rotation.z) > .001:
        return false
    if action_id == "vault_window" and not obstacle.opened:
        message = "Abra a janela antes de atravessar"
        return false
    if action_id == "open_window" and obstacle.opened:
        return false
    if action_id == "open_window" and not obstacle.swing_clear(body):
        message = "A folha da janela está bloqueada"
        return false
    if not body.set_crouch(false):
        return false
    var local: Vector3 = obstacle.to_local(body.global_position)
    var side = 1 if local.z < 0 else -1
    if action_id == "open_window" and side < 0:
        message = "Use o lado da maçaneta"
        return false
    id = action_id
    anchor = obstacle.global_position + Vector3.UP * .003
    basis = Basis(Vector3.UP, obstacle.global_rotation.y + (PI if side < 0 else 0))
    var entry = _position(0)
    if body.global_position.distance_to(entry) > 1.4 or not _preflight():
        message = "Entrada, passagem ou chegada bloqueada. " + message
        return false
    if body.test_move(body.global_transform, entry - body.global_position):
        message = "Aproximação bloqueada"
        return false
    token = obstacle.reserve(body)
    if token < 0:
        message = "Obstáculo em uso"
        return false
    target = obstacle
    resume_guard = body.combat.guarding
    body.combat.set_guard(false)
    body.action.cancel()
    body.combat.control_locked = true
    body.action.control_locked = true
    body.preview_motion = ""
    body.velocity = Vector3.ZERO
    actor.hand_layer.set_pose("Relaxed")
    actor.set_motion("idle")
    actor.motion_rate = 0
    align_start = body.global_position
    cursor = 0
    elapsed = 0
    effect_done = false
    effect_succeeded = false
    state = "align"
    return true


func _height(height: float) -> void:
    body.capsule.transform = Transform3D(Basis.IDENTITY, Vector3(0, height * .5, 0))
    body.capsule.shape.height = height


func _present(delta: float) -> void:
    actor.advance(delta)
    if state in ["playing","retreat"]:
        load("res://personagem/maos_apoio.gd").apply_at(actor.hand_layer,id,cursor)
    body.action._present()


func _finish(success: bool) -> void:
    var completed = id
    if is_instance_valid(target):
        target.release(body, token)
    state = "idle"
    actor.motion_rate = 1
    actor.set_motion("idle")
    actor.hand_layer.set_pose("Relaxed")
    _height(1.84)
    body.combat.control_locked = false
    body.action.control_locked = false
    if resume_guard:
        body.combat.set_guard(true)
    finished.emit(completed, success)


func cancel() -> bool:
    if processing or not is_active():
        return false
    if state == "align":
        _finish(false)
        return true
    if id == "open_window":
        if effect_done:
            _finish(effect_succeeded)
        else:
            rollback_fraction = target.fraction if is_instance_valid(target) else 0.0
            elapsed = 0
            state = "closing"
            actor.set_motion("idle")
        return true
    if cursor <= definitions.actions[id].takeoff:
        state = "retreat"
        return true
    message = "Concluindo a travessia"
    return false


func reset_test() -> void:
    if is_instance_valid(target):
        if id == "open_window" and not effect_done:
            target.set_fraction(0, body, token)
        target.release(body, token)
    state = "idle"
    body.combat.control_locked = false
    body.action.control_locked = false
    actor.motion_rate = 1
    actor.set_motion("idle")
    actor.motion_clock = 0
    actor.motion_blend = 1
    actor.hand_layer.set_pose("Relaxed")
    actor.advance(0)
    _height(1.84)


func _step(delta: float) -> void:
    if state == "align":
        elapsed += delta
        var destination = align_start.lerp(_position(0), smoothstep(0, .25, elapsed))
        var collision = body.move_and_collide(destination - body.global_position)
        actor.rotation.y = lerp_angle(actor.rotation.y, basis.get_euler().y, minf(1, delta * 16))
        _present(delta)
        if collision != null:
            _finish(false)
        elif elapsed >= .25:
            actor.rotation.y = basis.get_euler().y
            actor.set_motion(id)
            actor.motion_clock = 0
            actor.hand_layer.set_pose("Cylinder" if id == "open_window" else "Obstacle_Support")
            elapsed = 0
            state = "prepare"
        return
    if state == "prepare":
        elapsed += delta
        _present(delta)
        if elapsed >= actor.motion_transition_duration:
            state = "playing"
            actor.motion_blend = 1
        return
    if state == "closing":
        elapsed += delta
        if is_instance_valid(target):
            target.set_fraction(rollback_fraction * (1 - smoothstep(0, .25, elapsed)), body, token)
        _present(delta)
        if elapsed >= .25:
            _finish(false)
        return
    var action: Dictionary = definitions.actions[id]
    var time = clampf(cursor + (-delta if state == "retreat" else delta) * playback_rate, 0, action.duration)
    var sample: Dictionary = path.sample(id, time)
    if id == "open_window":
        if is_instance_valid(target) and not target.swing_clear(body, target.fraction, path.window_fraction(time)):
            rollback_fraction = target.fraction
            elapsed = 0
            state = "closing"
            actor.set_motion("idle")
            message = "Abertura obstruída"
            return
        if not is_instance_valid(target) or not target.set_fraction(path.window_fraction(time), body, token):
            _finish(false)
            return
    else:
        var desired = _position(time)
        if not _clear(desired, sample):
            state = "retreat"
            message = "Passagem obstruída, retornando"
            return
        _height(sample.height)
        body.capsule.transform = _volume(sample)
        var previous = body.global_position
        var collision = body.move_and_collide(desired - previous)
        if collision != null and not (collision.get_normal().y > .8 and body.global_position.distance_to(desired) < .015):
            body.global_position = previous
            state = "retreat"
            return
    cursor = time
    actor.motion_clock = cursor
    if cursor > 2.95 and id != "open_window" and actor.hand_layer.label != "Relaxed":
        actor.hand_layer.set_pose("Relaxed")
    _present(delta)
    if state != "retreat" and not effect_done and cursor >= action.effect_time:
        effect_done = true
        effect_succeeded = is_instance_valid(target) and target.commit(id, body, token)
    if state == "retreat" and cursor <= 0:
        _finish(false)
    elif cursor >= action.duration:
        _finish(effect_succeeded)


func advance(delta: float) -> void:
    if processing or not is_active() or not is_finite(delta) or delta < 0:
        return
    if body.paused:
        _present(0)
        return
    processing = true
    var remaining = delta
    while remaining > .0000001 and is_active():
        var step = minf(remaining, 1.0 / 120)
        _step(step)
        remaining -= step
    processing = false
