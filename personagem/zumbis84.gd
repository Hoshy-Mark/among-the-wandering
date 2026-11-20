extends "res://personagem/zumbis83.gd"
var navigation: Node3D
func setup(root_scene: Node3D) -> void:
    navigation=load("res://personagem/navegacao84.gd").new();add_child(navigation);navigation.setup(self)
    super.setup(root_scene)
func _make_actor() -> CharacterBody3D:
    return load("res://personagem/zumbi84.gd").new()
func valid(data: Variant) -> bool:
    if not super.valid(data):return false
    for entry in data.values():
        var remaining=entry.get("search_remaining84",minf(12,float(entry.memory)*3))
        if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or remaining<0 or remaining>12:return false
    return true
