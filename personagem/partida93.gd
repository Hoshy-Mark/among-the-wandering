extends "res://personagem/partida92.gd"
var pending_bindings={}
func snapshot() -> Dictionary:
    var data=super.snapshot();data.quick93={"version":1,"bindings":scene.player.get_node("Atalhos93").bindings.duplicate(true)};return data
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    pending_bindings={}
    if not value is Dictionary:reason="invalid";return {}
    var data=value.duplicate(true);var field=data.get("quick93",{"version":1,"bindings":{}})
    if not field is Dictionary or not (field.get("version") is int or field.get("version") is float) or field.version!=1 or not field.get("bindings") is Dictionary:reason="invalid";return {}
    var model=scene.player.bag_inventory.get_script().new();model.house_anchors=scene.player.bag_inventory.house_anchors.duplicate(true)
    if not model.restore(data.get("inventory"),false):reason="invalid";return {}
    var seen=[]
    for direction in field.bindings:
        var uid=field.bindings[direction]
        if direction not in ["left","up","right","down"] or not uid is String or uid in seen or not model.owned(uid) or model.quick_category(uid)!=direction:reason="invalid";return {}
        seen.append(uid)
    for uid in model.items:
        var location=str(model.items[uid].location)
        if location.begins_with("slot:quick_") and field.bindings.get(location.trim_prefix("slot:quick_"),"")!=uid:reason="invalid";return {}
    data.quick93=field.duplicate(true)
    var prepared=super.prepare(data,spatial)
    if prepared.is_empty():return {}
    pending_bindings=field.bindings.duplicate(true);return prepared
func load_game() -> bool:
    if not super.load_game():return false
    var quick=scene.player.get_node("Atalhos93");quick.bindings=pending_bindings.duplicate(true);quick.sync();return true
