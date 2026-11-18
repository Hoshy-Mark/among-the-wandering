extends RefCounted

signal started
signal finished
signal effect_applied(action_id: String,succeeded: bool)
signal cancelled(action_id: String,effect_was_applied: bool)

const MOTIONS: Dictionary = {"access": "inventory_access", "equip": "equip_item", "store": "store_item", "receive": "inventory_access", "drop": "store_item", "eat": "eat", "drink": "drink", "medicine": "medicine", "bandage": "bandage"}
const EFFECT_PHASES: Dictionary = {"eat": 0.45312499999999994, "drink": 0.5142857142857143, "medicine": 0.43333333333333335, "bandage": 0.5875}
var control_locked = false
var actor: Node3D
var state:="idle"
var state_time:=0.0
var action_id:="access"
var motion_id:="inventory_access"
var command: Callable
var effect_done:=false
var effect_succeeded:=false
var executing_effect:=false
var cancel_after_effect:=false

func setup(npc: Node3D) -> void:
    actor=npc
    actor.manual_update=true

func begin(effect: Callable=Callable(),kind: String="access") -> bool:
    if control_locked:
        return false
    if state!="idle" or executing_effect or actor.motion_paused or not MOTIONS.has(kind):
        return false
    if kind!="access" and not effect.is_valid():
        return false
    var motion: String=MOTIONS[kind]
    if not actor.clips.has(motion) or not actor.player.has_animation(actor.clips[motion]):
        return false
    if actor.player.get_animation(actor.clips[motion]).length<=0:
        return false
    if not actor.set_motion(motion):
        return false
    command=effect
    action_id=kind
    motion_id=motion
    effect_done=false
    effect_succeeded=false
    cancel_after_effect=false
    actor.motion_clock=0
    actor.motion_rate=0
    state="prepare"
    state_time=0
    started.emit()
    return true

func cancel(resume: String="idle") -> bool:
    if control_locked:
        return false
    if not actor.clips.has(resume) or not actor.player.has_animation(actor.clips[resume]):
        return false
    var active:=state!="idle"
    state="idle"
    state_time=0
    command=Callable()
    actor.motion_rate=1
    var accepted: bool=actor.set_motion(resume)
    if active:
        if executing_effect:
            cancel_after_effect=true
        else:
            cancelled.emit(action_id,effect_succeeded)
    return accepted

func _apply_effect() -> void:
    effect_done=true
    var effect:=command
    var kind:=action_id
    command=Callable()
    executing_effect=true
    var result: Variant=(kind=="access") if not effect.is_valid() else effect.call()
    effect_succeeded=result is bool and result
    effect_applied.emit(kind,effect_succeeded)
    executing_effect=false
    if cancel_after_effect:
        cancel_after_effect=false
        cancelled.emit(kind,effect_succeeded)

func advance(delta: float) -> void:
    if control_locked:
        return
    if not is_finite(delta) or delta<0:
        return
    if executing_effect:
        return
    if actor.motion_paused:
        actor.advance(delta)
        return
    if state!="idle" and actor.motion!=motion_id:
        state="idle"
        state_time=0
        command=Callable()
        actor.motion_rate=1
        cancelled.emit(action_id,effect_succeeded)
    var remaining:=delta
    while state!="idle":
        var duration: float=actor.motion_transition_duration if state=="prepare" else actor.player.get_animation(actor.clips[motion_id]).length
        var boundary: float=duration*float(EFFECT_PHASES.get(action_id,.5)) if state=="gesture" and not effect_done else duration
        var step:=minf(remaining,maxf(0,boundary-state_time))
        actor.advance(step)
        state_time+=step
        remaining-=step
        if state_time<boundary-.0000001:
            return
        if state=="prepare":
            state="gesture"
            state_time=0
            actor.motion_rate=1
            actor.motion_clock=0
            actor.motion_blend=1
            actor.advance(0)
        elif not effect_done:
            _apply_effect()
        else:
            state="idle"
            state_time=0
            actor.set_motion("idle")
            finished.emit()
        if remaining<=0:
            return
    actor.advance(remaining)

func report() -> Dictionary:
    return {"action":action_id,"state":state,"time":state_time,"effect_done":effect_done,"effect_succeeded":effect_succeeded}
