extends "res://personagem/slot63.gd"

func _can_drop_data(position: Vector2, data: Variant) -> bool:
    if not super._can_drop_data(position,data) or data.item_uid==uid:
        return false
    var model: RefCounted=hud.player.bag_inventory
    if not model.can_touch(data.item_uid):
        return false
    if not equipment and not uid.is_empty() and model.items.has(uid):
        var source: Dictionary=model.items[data.item_uid]
        var target: Dictionary=model.items[uid]
        if source.definition==target.definition and int(model.catalog[source.definition].stack)>1:
            return model.can_touch(uid) and target.count<model.catalog[target.definition].stack
    return true

func _drop_data(position: Vector2, data: Variant) -> void:
    var model: RefCounted=hud.player.bag_inventory
    if not equipment and not uid.is_empty() and model.items.has(uid) and model.items.has(data.get("item_uid","")):
        var source: Dictionary=model.items[data.item_uid]
        if source.definition==model.items[uid].definition and int(model.catalog[source.definition].stack)>1:
            hud.merge_uid(data.item_uid,uid,int(source.count))
            return
    super._drop_data(position,data)
