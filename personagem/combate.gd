extends RefCounted

signal impact_applied(attack_id: String, succeeded: bool)
signal attack_cancelled(attack_id: String, effect_done: bool)

var actor: Node3D
var inventory_action: RefCounted
var definitions: Dictionary
var weapon: Node3D
var control_locked = false
var guarding = false
var armed = false
var state = "idle"
var attack_id = ""
var clip_id = ""
var elapsed = 0.0
var effect_done = false
var effect_succeeded = false
var effect: Callable
var executing_effect = false
var previous_hand_pose = "Relaxed"
var attack_number = 0


func setup(npc: Node3D, action: RefCounted) -> void:
    actor = npc
    actor.manual_update = true
    inventory_action = action
    definitions = JSON.parse_string(FileAccess.get_file_as_string(actor.base_dir + "combate.json"))
    for right in ["Fist", "Cylinder", "Open"]:
        for left in ["Fist", "Open"]:
            var data: Dictionary = actor.hand_layer.poses[left].duplicate(true)
            for name in actor.hand_layer.poses[right]:
                if str(name).ends_with(".R"):
                    data[name] = actor.hand_layer.poses[right][name].duplicate(true)
            actor.hand_layer.poses[_hand_label(right, left)] = data
    weapon = load(actor.base_dir + "bastao_teste.gd").new()
    weapon.name = "BastaoDeTreino"
    actor.add_child(weapon)


func _hand_label(right: String, left: String) -> String:
    return "Combat_" + right + "_" + left


func _hands(right: String, left: String) -> void:
    var label = _hand_label(right, left)
    if actor.hand_layer.label != label:
        actor.hand_layer.set_pose(label)


func guard_motion(direction: Vector2 = Vector2.ZERO) -> String:
    var suffix = "_armed" if armed else ""
    if direction.length() < .05:
        return "combat_idle" + suffix
    if absf(direction.x) > absf(direction.y):
        return ("combat_left" if direction.x > 0 else "combat_right") + suffix
    return ("combat_forward" if direction.y > 0 else "combat_back") + suffix


func set_guard(value: bool) -> bool:
    if control_locked:
        return false
    if executing_effect:
        return false
    if value == guarding:
        return true
    if value:
        inventory_action.cancel(guard_motion())
        previous_hand_pose = actor.hand_layer.label
        guarding = true
        state = "guard"
        actor.set_motion(guard_motion())
        _hands("Cylinder" if armed else "Fist", "Fist")
    else:
        cancel()
        guarding = false
        state = "idle"
        actor.set_motion("idle")
        actor.hand_layer.set_pose(previous_hand_pose)
    weapon.visible = guarding and armed
    return true


func set_armed(value: bool) -> bool:
    if control_locked:
        return false
    if executing_effect:
        return false
    cancel()
    armed = value
    if guarding:
        actor.set_motion(guard_motion())
        _hands("Cylinder" if armed else "Fist", "Fist")
    weapon.visible = guarding and armed
    return true


func is_attacking() -> bool:
    return state in ["prepare", "attack"]


func begin(kind: String, callback: Callable) -> bool:
    if control_locked:
        return false
    if executing_effect or actor.motion_paused or is_attacking() or not callback.is_valid():
        return false
    if kind not in ["push", "punch", "strike_onehand"]:
        return false
    if (kind == "strike_onehand" and not armed) or (kind == "punch" and armed):
        return false
    var selected = "push_armed" if kind == "push" and armed else kind
    if not actor.clips.has(selected) or not actor.player.has_animation(actor.clips[selected]):
        return false
    if not set_guard(true):
        return false
    attack_id = kind
    clip_id = selected
    effect = callback
    effect_done = false
    effect_succeeded = false
    elapsed = 0
    attack_number += 1
    actor.set_motion(clip_id)
    actor.motion_clock = 0
    actor.motion_rate = 0
    state = "prepare"
    _hands(definitions[clip_id].right_pose, definitions[clip_id].left_pose)
    return true


func cancel() -> void:
    if control_locked:
        return
    var active = is_attacking()
    effect = Callable()
    actor.motion_rate = 1
    elapsed = 0
    state = "guard" if guarding else "idle"
    if guarding:
        actor.set_motion(guard_motion())
        _hands("Cylinder" if armed else "Fist", "Fist")
    if active:
        attack_cancelled.emit(attack_id, effect_done)


func _impact() -> void:
    effect_done = true
    var callback = effect
    effect = Callable()
    executing_effect = true
    var result: Variant = false
    if callback.is_valid():
        result = callback.call()
    effect_succeeded = result is bool and result
    impact_applied.emit(attack_id, effect_succeeded)
    executing_effect = false


func _advance_actor(delta: float) -> void:
    actor.advance(delta)
    weapon.attach(actor)
    if inventory_action.has_method("_present"):
        inventory_action._present()


func advance(delta: float, direction: Vector2 = Vector2.ZERO) -> void:
    if not is_finite(delta) or delta < 0 or executing_effect:
        return
    if actor.motion_paused:
        _advance_actor(delta)
        return
    if is_attacking() and actor.motion != clip_id:
        var external_motion: String = actor.motion
        set_guard(false)
        actor.set_motion(external_motion)
        _advance_actor(delta)
        return
    var remaining = delta
    while is_attacking():
        var definition: Dictionary = definitions[clip_id]
        var boundary: float = actor.motion_transition_duration if state == "prepare" else definition.impact_time if not effect_done else definition.duration
        var step = minf(remaining, maxf(0, boundary - elapsed))
        _advance_actor(step)
        elapsed += step
        remaining -= step
        if elapsed < boundary - .0000001:
            return
        if state == "prepare":
            state = "attack"
            elapsed = 0
            actor.motion_clock = 0
            actor.motion_rate = 1
            actor.motion_blend = 1
            _advance_actor(0)
        elif not effect_done:
            _impact()
        else:
            state = "guard"
            elapsed = 0
            actor.set_motion(guard_motion(direction))
            _hands("Cylinder" if armed else "Fist", "Fist")
        if remaining <= 0:
            return
    if guarding:
        actor.set_motion(guard_motion(direction))
    weapon.visible = guarding and armed
    _advance_actor(remaining)
