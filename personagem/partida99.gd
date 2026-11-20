extends "res://personagem/partida98.gd"
var pending_characters99={}
func _characters99() -> Node:return scene.get_node_or_null("Characters99")
func _excluded(parts: Array) -> Array[RID]:
    var result=super._excluded(parts);var manager=_characters99()
    if manager!=null:
        for actor in manager.actors.values():result.append(actor.get_rid())
    return result
func snapshot() -> Dictionary:
    var data=super.snapshot();var manager=_characters99()
    if manager!=null:data.characters99=manager.registry.snapshot()
    return data
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    pending_characters99={}
    if not value is Dictionary:reason="invalid";return {}
    var manager=_characters99()
    if manager==null:reason="invalid";return {}
    var checked=manager.registry.validate(value.get("characters99"))
    if checked.is_empty():reason="invalid";return {}
    var result=super.prepare(value,spatial)
    if result.is_empty():return {}
    pending_characters99=checked;return result
func load_game() -> bool:
    if not super.load_game():return false
    var manager=_characters99();manager.close();manager.registry.restore(pending_characters99);manager.reconcile_anchors()
    return true
