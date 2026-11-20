extends "res://personagem/partida93.gd"
var pending_baseline=0.0
func _demo95() -> Node:return scene.player.get_node_or_null("Demo95")
func _idle() -> bool:
    var demo=_demo95()
    return (demo==null or demo.state=="alive") and super._idle()
func snapshot() -> Dictionary:
    var data=super.snapshot();var demo=_demo95()
    data.vitals95={"version":1,"baseline":demo.baseline if demo!=null else 0.0};return data
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    pending_baseline=0
    var prepared=super.prepare(value,spatial)
    if prepared.is_empty():return {}
    var raw=0.0
    for entry in value.body.records.values():raw+=float(entry.severity)
    var field=value.get("vitals95",{"version":1,"baseline":raw})
    if not field is Dictionary or not (field.get("version") is int or field.get("version") is float) or field.version!=1 or not (field.get("baseline") is int or field.get("baseline") is float):reason="invalid";return {}
    var start=float(field.baseline)
    if not is_finite(start) or start<0 or start>raw+.000001:reason="invalid";return {}
    var balance=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/demo_balance95.json"))
    if 1.0-(raw-start)*float(balance.damage_scale)<=.000001:reason="invalid";return {}
    if prepared.has("data"):prepared.data.vitals95=field.duplicate(true)
    pending_baseline=start;return prepared
func save() -> bool:
    var demo=_demo95()
    if demo!=null and (demo.state!="alive" or demo.integrity()<=0):scene.player.inventory_message="Tentativa encerrada; o último save foi preservado";return false
    return super.save()
func load_game() -> bool:
    if not super.load_game():return false
    var demo=_demo95()
    if demo!=null:demo.baseline=pending_baseline;demo.grace=0;demo.refresh()
    return true
