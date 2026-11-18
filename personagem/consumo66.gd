extends "res://personagem/consumo_cuidados.gd"

var access_speed=1.0

func begin(effect: Callable=Callable(), kind: String="access") -> bool:
    if not super.begin(effect,kind):
        return false
    if kind=="access":
        var duration=actor.motion_transition_duration+actor.player.get_animation(actor.clips[motion_id]).length
        access_speed=duration/.65
    return true

func advance(delta: float) -> void:
    super.advance(delta*access_speed if state!="idle" and action_id=="access" else delta)
