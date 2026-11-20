extends "res://personagem/partida81.gd"
var enemies: Node3D
var pending_enemies={}
func _signature() -> String:
    return super._signature()+FileAccess.get_sha256("res://personagem/zumbis82.json")
func _excluded(parts: Array) -> Array[RID]:
    var result=super._excluded(parts)
    if enemies!=null:
        for actor in enemies.actors.values():result.append(actor.get_rid())
    return result
func _idle() -> bool:
    return super._idle() and (enemies==null or enemies.settled())
func snapshot() -> Dictionary:
    var data=super.snapshot()
    data.enemies82=enemies.snapshot()
    return data
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    pending_enemies={}
    if not value is Dictionary:reason="invalid";return {}
    var data=value.duplicate(true)
    var states=data.get("enemies82",enemies.initial)
    if not enemies.valid(states):reason="invalid";return {}
    if not data.has("enemies82") and data.get("session81") is Dictionary and data.session81.get("world")==super._signature():data.session81.world=_signature()
    var prepared=super.prepare(data,spatial)
    if prepared.is_empty():return {}
    if spatial:
        var points=[]
        var player_point=Vector3(prepared.session.position[0],prepared.session.position[1],prepared.session.position[2])
        points.append(player_point)
        for id in states:
            var entry: Dictionary=states[id]
            var point=Vector3(entry.position[0],entry.position[1],entry.position[2])
            if not _space(point,false,prepared.parts):reason="occupied";return {}
            if entry.state=="dead":continue
            for other in points:
                if absf(point.y-other.y)<1.84 and Vector2(point.x-other.x,point.z-other.z).length()<.48:reason="occupied";return {}
            points.append(point)
    pending_enemies=states.duplicate(true)
    return prepared
func save() -> bool:
    if enemies!=null and not enemies.settled():scene.player.inventory_message="Aguarde as ações dos inimigos terminarem";return false
    return super.save()
func load_game() -> bool:
    if enemies!=null and not enemies.settled():scene.player.inventory_message="Aguarde as ações dos inimigos terminarem";return false
    if not super.load_game():return false
    enemies.restore(pending_enemies)
    return true
