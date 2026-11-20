extends "res://personagem/alvo_treino.gd"
var events={}
func _ready() -> void:
    super._ready()
    add_to_group("combat_receivers79")
func receive_combat_hit(event: Dictionary) -> bool:
    if events.has(event.id):return false
    events[event.id]=event.duplicate(true)
    impacts.append(event)
    flash=.16
    return true
