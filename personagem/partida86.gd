extends "res://personagem/partida82.gd"
var migrated=false
func snapshot() -> Dictionary:
    var data=super.snapshot();data.weapons86={"version":1,"loot_seeded":true}
    return data
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    migrated=false
    if not value is Dictionary:reason="invalid";return {}
    var data=value.duplicate(true)
    if data.has("weapons86"):
        var marker=data.weapons86
        if not marker is Dictionary:reason="invalid";return {}
        var version=marker.get("version")
        if not (version is int or version is float) or version!=1 or not marker.get("loot_seeded") is bool or not marker.loot_seeded:reason="invalid";return {}
    else:
        var bag=scene.player.bag_inventory.get_script().new();bag.house_anchors=scene.player.bag_inventory.house_anchors.duplicate(true)
        if not bag.restore(data.get("inventory"),false) or not scene.player.weapons.seed(bag):reason="invalid";return {}
        data.inventory=bag.snapshot();data.weapons86={"version":1,"loot_seeded":true};migrated=true
    return super.prepare(data,spatial)
func load_game() -> bool:
    if not super.load_game():return false
    scene.player.weapons.sync()
    if migrated:scene.player.inventory_message+=" · Armas disponíveis no chão da entrada H01"
    return true
