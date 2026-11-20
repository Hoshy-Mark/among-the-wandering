extends Button
var hud: Control
var uid=""
var destination=""
var equipment=false

func _get_drag_data(_position: Vector2) -> Variant:
    if uid.is_empty():
        return null
    var preview=Label.new()
    preview.text=text
    set_drag_preview(preview)
    return {"item_uid":uid}

func _can_drop_data(_position: Vector2,data: Variant) -> bool:
    return data is Dictionary and data.get("item_uid") is String and not destination.is_empty()

func _drop_data(_position: Vector2,data: Variant) -> void:
    if equipment:
        hud.equip_uid(data.item_uid,destination)
    else:
        hud.move_uid(data.item_uid,destination)
