extends "res://personagem/mundo67.gd"

func close_interaction(hide_inventory: bool=true) -> void:
    super.close_interaction(false)
    if hide_inventory:
        ui.close_nearby(false)
    ui.sync_lock()
