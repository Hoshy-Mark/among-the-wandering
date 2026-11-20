extends "res://personagem/partida101.gd"
var pending_map107={}
func snapshot() -> Dictionary:
    var value=super.snapshot();value.exploration107=_characters99().skills_ui.exploration.snapshot();return value
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    pending_map107={}
    if not value is Dictionary:return {}
    var checked=_characters99().skills_ui.exploration.validate(value.get("exploration107"))
    if checked.is_empty():reason="invalid";return {}
    var result=super.prepare(value,spatial)
    if not result.is_empty():pending_map107=checked
    return result
func load_game() -> bool:
    if not super.load_game():return false
    _characters99().skills_ui.exploration.data=pending_map107.duplicate(true);return true
