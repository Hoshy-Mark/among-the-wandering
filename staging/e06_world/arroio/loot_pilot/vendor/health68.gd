extends "res://staging/e06_world/arroio/loot_pilot/vendor/hud66.gd"
var owner_hud: Control

func toggle(index: int) -> void:
    if owner_hud!=null:
        owner_hud.toggle(1)

func refresh() -> void:
    if player!=null:
        _refresh_body()
