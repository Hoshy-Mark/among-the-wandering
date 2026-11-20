extends "res://personagem/partida99.gd"
var pending_social101={}
func snapshot() -> Dictionary:
    var result=super.snapshot();var manager=_characters99()
    if manager!=null:result.social101=manager.social.snapshot()
    return result
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    pending_social101={}
    if not value is Dictionary:reason="invalid";return {}
    var checked=_characters99().social.validate(value.get("social101"))
    if checked.is_empty():reason="invalid";return {}
    var result=super.prepare(value,spatial)
    if result.is_empty():return {}
    pending_social101=checked;return result
func load_game() -> bool:
    if not super.load_game():return false
    return _characters99().social.restore(pending_social101)
