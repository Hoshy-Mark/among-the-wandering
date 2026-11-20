extends "res://personagem/zumbi87.gd"
var bullet_regions=load("res://personagem/regioes_tiro91.gd").new()
var last_bullet_zone=""
var last_bullet_amount=0.0
func hear_shot(point: Vector3,radius: float) -> void:
    super.hear_shot(point,radius)
    memory=minf(memory,4.0) # Existing profile range; search_remaining retains the 12-second search.
func hit_regions91() -> Array:
    return [] if state in ["dying","dead"] else bullet_regions.volumes(avatar)
func receive_combat_hit(event: Dictionary) -> bool:
    if event.get("action")!="firearm_shot":return super.receive_combat_hit(event)
    if event.get("zone") not in ["head","chest","abdomen","upper_arm_left","upper_arm_right","forearm_left","forearm_right","thigh_left","thigh_right","calf_left","calf_right"]:return false
    if not super.receive_combat_hit(event):return false
    last_bullet_zone=event.zone;last_bullet_amount=float(event.amount);return true
func restore(data: Dictionary) -> void:
    super.restore(data);last_bullet_zone="";last_bullet_amount=0
