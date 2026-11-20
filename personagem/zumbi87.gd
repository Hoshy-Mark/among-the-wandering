extends "res://personagem/zumbi85.gd"
func receive_combat_hit(event: Dictionary) -> bool:
    if event.get("action")!="firearm_shot":return super.receive_combat_hit(event)
    var compatible=event.duplicate(true);compatible.action="strike_onehand"
    return super.receive_combat_hit(compatible)
func hear_shot(point: Vector3,radius: float) -> void:
    if state in ["dying","dead"] or global_position.distance_to(point)>radius:return
    last_known=point;memory=12.0;search_remaining=12.0;clear_route()
    if state=="idle":state="search";elapsed=0
