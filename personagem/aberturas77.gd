extends "res://personagem/aberturas76.gd"
func busy() -> bool:
    return super.busy() or (scene!=null and scene.player!=null and scene.player.traversal.is_active())

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if scene!=null and scene.player.traversal.is_active():prompt.visible=false
