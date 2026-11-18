extends "res://personagem/obstaculo_mapa77.gd"
var model: Dictionary
func can_cross(role: String) -> bool:
    return model.player_can_cross if role=="player" else model.zombies_can_cross if role=="zombie" else false
func prepare(actor: Node3D) -> bool:
    locate(actor)
    reason=""
    var direction=1 if to_local(actor.global_position).z<0 else -1
    var start=floor_at(base_center-normal*direction*.65)
    var finish=floor_at(base_center+normal*direction*.95)
    if start.is_empty() or finish.is_empty():reason="Falta piso seguro";return false
    landing=finish.position.y-start.position.y
    if absf(landing)>.015 or absf(ledge_y-start.position.y-float(model.height))>.02:
        reason="Piso ou altura fora da faixa validada"
        return false
    if scene.player.condition_state.stamina<float(model.stamina_cost):reason="Recupere o fôlego antes de subir";return false
    global_position.y=start.position.y
    rise=float(model.height)-.8
    variant=model.id
    return true
func commit(id: String, actor: Node3D, expected: int) -> bool:
    if not super.commit(id,actor,expected):return false
    actor.condition_state.set_stamina(maxf(0,actor.condition_state.stamina-float(model.stamina_cost)))
    return true
