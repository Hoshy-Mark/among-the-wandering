extends "res://personagem/partida86.gd"
var pending_rounds={}
func snapshot() -> Dictionary:
    var data=super.snapshot()
    data.firearms87={"version":1,"loot_seeded":true,"rounds":scene.player.weapons.rounds.duplicate(true)}
    data.arsenal92={"version":1,"loot_seeded":true}
    return data
func _firearm(model: RefCounted,uid: String) -> Dictionary:
    if not model.items.has(uid):return {}
    var info=model.catalog[model.items[uid].definition].get("weapon",{})
    return info if info.get("type","")=="firearm" else {}
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    pending_rounds={}
    if not value is Dictionary:reason="invalid";return {}
    var data=value.duplicate(true);var rounds={}
    var shadow=scene.player.bag_inventory.get_script().new();shadow.house_anchors=scene.player.bag_inventory.house_anchors.duplicate(true)
    if not shadow.restore(data.get("inventory"),false):reason="invalid";return {}
    if data.has("firearms87"):
        var field=data.firearms87
        if not field is Dictionary or not (field.get("version") is int or field.get("version") is float) or field.version!=1 or not field.get("loot_seeded") is bool or not field.loot_seeded or not field.get("rounds") is Dictionary:reason="invalid";return {}
        rounds=field.rounds.duplicate(true)
        for uid in rounds:
            if not uid is String:reason="invalid";return {}
            var number=rounds[uid];var info=_firearm(shadow,uid)
            if info.is_empty() or not (number is int or number is float) or not is_finite(float(number)) or number!=floor(float(number)) or number<0 or number>int(info.capacity):reason="invalid";return {}
        for uid in shadow.items:
            if not _firearm(shadow,uid).is_empty() and not rounds.has(uid):reason="invalid";return {}
    else:
        if not scene.player.weapons.seed_firearms(shadow):reason="invalid";return {}
        for uid in shadow.items:
            if not _firearm(shadow,uid).is_empty():rounds[uid]=0
    if data.has("arsenal92"):
        var marker=data.arsenal92
        if not marker is Dictionary or not (marker.get("version") is int or marker.get("version") is float) or marker.version!=1 or not marker.get("loot_seeded") is bool or not marker.loot_seeded:reason="invalid";return {}
    else:
        if not scene.player.weapons.seed_extra(shadow):reason="invalid";return {}
        for uid in shadow.items:
            if not _firearm(shadow,uid).is_empty() and not rounds.has(uid):rounds[uid]=0
        data.arsenal92={"version":1,"loot_seeded":true}
    data.inventory=shadow.snapshot()
    var prepared=super.prepare(data,spatial)
    if prepared.is_empty():return {}
    pending_rounds=rounds
    return prepared
func load_game() -> bool:
    if not super.load_game():return false
    scene.player.weapons.rounds=pending_rounds.duplicate(true);scene.player.weapons.sync()
    return true
