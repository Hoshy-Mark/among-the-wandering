extends "res://personagem/partida86.gd"
var pending_rounds={}
func snapshot() -> Dictionary:
    var data=super.snapshot()
    data.firearms87={"version":1,"loot_seeded":true,"rounds":scene.player.weapons.rounds.duplicate(true)}
    return data
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
            var number=rounds[uid]
            if not shadow.items.has(uid) or shadow.items[uid].definition!="pistol" or not (number is int or number is float) or not is_finite(float(number)) or number!=floor(float(number)) or number<0 or number>6:reason="invalid";return {}
        for uid in shadow.items:
            if shadow.items[uid].definition=="pistol" and not rounds.has(uid):reason="invalid";return {}
    else:
        if not scene.player.weapons.seed_firearms(shadow):reason="invalid";return {}
        data.inventory=shadow.snapshot()
        for uid in shadow.items:
            if shadow.items[uid].definition=="pistol":rounds[uid]=0
    var prepared=super.prepare(data,spatial)
    if prepared.is_empty():return {}
    pending_rounds=rounds
    return prepared
func load_game() -> bool:
    if not super.load_game():return false
    scene.player.weapons.rounds=pending_rounds.duplicate(true)
    scene.player.weapons.sync()
    return true
