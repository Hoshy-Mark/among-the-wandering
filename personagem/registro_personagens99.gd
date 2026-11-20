extends RefCounted
var definitions={}
var met={}
func configure(config: Dictionary) -> bool:
    var rows=config.get("characters")
    if config.get("version")!=1 or not rows is Dictionary or rows.size()!=9:return false
    for id in rows:
        if not id is String or not rows[id] is Dictionary or not rows[id].get("name") is String or not rows[id].get("role") is String:return false
    definitions=rows.duplicate(true);met.clear()
    for id in definitions:met[id]=false
    return true
func snapshot() -> Dictionary:return {"version":1,"met":met.duplicate(true)}
func validate(value: Variant) -> Dictionary:
    if value==null:
        var initial={}
        for id in definitions:initial[id]=false
        return {"version":1,"met":initial}
    if not value is Dictionary or value.get("version")!=1 or not value.get("met") is Dictionary or value.met.size()!=definitions.size():return {}
    for id in definitions:
        if not value.met.has(id) or not value.met[id] is bool:return {}
    return value.duplicate(true)
func restore(value: Dictionary) -> bool:
    var checked=validate(value)
    if checked.is_empty():return false
    met=checked.met.duplicate(true);return true
