extends RefCounted

signal started(kind: String)
signal finished(kind: String)
signal knocked_down
signal stood_up
signal died

var actor: Node3D
var action: RefCounted
var combat: RefCounted
var definitions: Dictionary
var state = "idle"
var kind = ""
var clip = ""
var elapsed = 0.0
var resume_guard = false
var processing = false


func setup(npc: Node3D, inventory_action: RefCounted, combat_action: RefCounted) -> void:
    actor = npc
    action = inventory_action
    combat = combat_action
    definitions = JSON.parse_string(FileAccess.get_file_as_string(actor.base_dir + "reacoes.json"))


func is_active() -> bool:
    return state != "idle"


func begin(id: String) -> bool:
    if processing or action.executing_effect or combat.executing_effect or actor.motion_paused or state == "dead":
        return false
    if id == "get_up":
        if state != "down":
            return false
    elif id == "death" and state == "down":
        state = "dead"
        kind = "death"
        actor.motion_rate = 0
        died.emit()
        return true
    elif id == "death" and kind == "get_up" and is_active():
        kind = "death"
        state = "dying"
        elapsed = actor.motion_clock
        actor.motion_rate = -1
        started.emit(kind)
        return true
    elif id == "death" and kind == "fall" and is_active():
        kind = "death"
        clip = "death"
        var clock: float = actor.motion_clock
        actor.set_motion(clip)
        actor.motion_clock = clock
        if state == "playing":
            actor.motion_blend = 1
        started.emit(kind)
        return true
    elif state != "idle" and id != "death":
        return false
    if id not in ["hit_front", "hit_back", "hit_left", "hit_right", "stagger", "fall", "get_up", "death"]:
        return false
    var standing = id.begins_with("hit_") or id == "stagger"
    var selected = id + "_armed" if standing and combat.armed else id
    if not actor.clips.has(selected):
        return false
    if state == "idle":
        resume_guard = combat.guarding
    combat.control_locked = false
    action.control_locked = false
    combat.set_guard(false)
    action.cancel()
    combat.control_locked = true
    action.control_locked = true
    kind = id
    clip = selected
    elapsed = 0
    state = "prepare"
    actor.set_motion(clip)
    actor.motion_clock = 0
    actor.motion_rate = 0
    if standing:
        combat._hands("Cylinder" if combat.armed else "Fist", "Fist")
    else:
        actor.hand_layer.set_pose("Relaxed")
    combat.weapon.visible = standing and combat.armed
    started.emit(kind)
    return true


func reset() -> bool:
    if processing:
        return false
    state = "idle"
    kind = ""
    clip = ""
    elapsed = 0
    resume_guard = false
    combat.control_locked = false
    action.control_locked = false
    actor.motion_rate = 1
    actor.blink = 0
    combat.set_guard(false)
    action.cancel()
    actor.set_motion("idle")
    actor.motion_clock = 0
    actor.motion_blend = 1
    actor.hand_layer.set_pose("Relaxed")
    actor.hand_layer.advance(.2)
    actor.advance(0)
    combat.weapon.visible = false
    return true


func _present() -> void:
    var eyelids = 0.0
    if state == "dead":
        eyelids = 1
    elif kind == "death":
        eyelids = smoothstep(.65, 1.4, elapsed)
    if not is_equal_approx(actor.blink, eyelids):
        actor.blink = eyelids
        actor._apply_weights()
    combat.weapon.attach(actor)
    action._present()


func _complete() -> void:
    var completed = kind
    if kind == "fall":
        state = "down"
        actor.set_motion("down")
        actor.motion_clock = 0
        actor.motion_blend = 1
        actor.motion_rate = 1
        actor.advance(0)
        knocked_down.emit()
    elif kind == "death":
        state = "dead"
        actor.motion_clock = definitions[clip].duration
        actor.motion_rate = 0
        actor.advance(0)
        died.emit()
    else:
        state = "idle"
        combat.control_locked = false
        action.control_locked = false
        actor.motion_rate = 1
        actor.set_motion("idle")
        if resume_guard:
            combat.set_guard(true)
        else:
            actor.hand_layer.set_pose("Relaxed")
            combat.weapon.visible = false
        if completed == "get_up":
            stood_up.emit()
    finished.emit(completed)


func advance(delta: float) -> void:
    if not is_finite(delta) or delta < 0 or processing or not is_active():
        return
    processing = true
    if actor.motion_paused or state in ["down", "dead"]:
        actor.advance(delta)
        _present()
        processing = false
        return
    if state == "dying":
        var step = minf(delta, elapsed)
        actor.advance(step)
        elapsed -= step
        if elapsed <= .0000001:
            state = "dead"
            actor.motion_clock = 0
            actor.motion_rate = 0
            actor.advance(0)
            died.emit()
            finished.emit("death")
        _present()
        processing = false
        return
    var remaining = delta
    while state in ["prepare", "playing"]:
        var boundary: float = actor.motion_transition_duration if state == "prepare" else definitions[clip].duration
        var step = minf(remaining, maxf(0, boundary - elapsed))
        actor.advance(step)
        _present()
        elapsed += step
        remaining -= step
        if elapsed < boundary - .0000001:
            break
        if state == "prepare":
            state = "playing"
            elapsed = 0
            actor.motion_clock = 0
            actor.motion_rate = 1
            actor.motion_blend = 1
            actor.advance(0)
        else:
            _complete()
        if remaining <= 0:
            break
    if remaining > 0 and state not in ["prepare", "playing"]:
        if combat.guarding:
            combat.advance(remaining)
        else:
            actor.advance(remaining)
        _present()
    processing = false
