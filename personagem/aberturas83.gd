extends "res://personagem/aberturas77.gd"
func request(id: String) -> bool:
    if scene.player.map_traversals!=null:
        for obstacle in scene.player.map_traversals.obstacles:
            if obstacle.kind=="window" and obstacle.opening_id==id and obstacle.owner_ref!=null and is_instance_valid(obstacle.owner_ref.get_ref()):
                scene.game_ui.feedback.text="Aguarde a passagem pela janela"
                return false
    return super.request(id)
