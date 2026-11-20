extends "res://personagem/zumbis84.gd"
func _make_actor() -> CharacterBody3D:
    return load("res://personagem/zumbi85.gd").new()
func valid(data: Variant) -> bool:
    if not super.valid(data):return false
    for id in actors:
        var variant=data[id].get("variant85",actors[id].default_variant)
        if not variant is String or not actors[id].profiles.has(variant):return false
    return true
