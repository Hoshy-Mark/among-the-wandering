extends RefCounted
signal changed
const TYPES={"bruise":{"name":"Contusão","factor":.8},"scratch":{"name":"Arranhão","factor":.6},"cut":{"name":"Corte","factor":1.0},"bite":{"name":"Mordida","factor":1.2},"burn":{"name":"Queimadura","factor":1.1}}
var regions: Dictionary
var records: Dictionary={}
var condition: RefCounted

func _init() -> void:
    regions=JSON.parse_string(FileAccess.get_file_as_string("res://staging/e06_world/arroio/loot_pilot/vendor/regioes63.json"))

func hit(id: String, zone: String, kind: String, amount: float) -> bool:
    if id.is_empty() or id.length()>128 or records.has(id) or condition.damage_events.has(id) or not regions.has(zone) or not TYPES.has(kind) or not is_finite(amount) or amount<=0 or amount>1:
        return false
    var severity=clampf(amount*regions[zone].factor*TYPES[kind].factor,0,1)
    var legacy=""
    if zone in ["thigh_left","shin_left","foot_left"]:
        legacy="leg_left"
    elif zone in ["thigh_right","shin_right","foot_right"]:
        legacy="leg_right"
    elif zone=="forearm_left":
        legacy="forearm_left"
    if not legacy.is_empty() and not condition.receive_damage(id,legacy,severity):
        return false
    records[id]={"zone":zone,"kind":kind,"severity":severity}
    changed.emit()
    return true

func wounds(zone: String) -> Array:
    return records.values().filter(func(entry):return entry.zone==zone)

func severity(zone: String) -> float:
    var result=0.0
    for entry in wounds(zone):
        result+=entry.severity
    if zone=="forearm_left":
        result=maxf(result,condition.forearm_injury)
    if zone in ["thigh_left","thigh_right"]:
        var side="left" if zone=="thigh_left" else "right"
        var other=0.0
        for entry in records.values():
            if entry.zone in ["shin_"+side,"foot_"+side]:
                other+=entry.severity
        result=maxf(result,(condition.left_injury if side=="left" else condition.right_injury)-other)
    return minf(1,result)

func snapshot() -> Dictionary:
    return {"version":1,"records":records.duplicate(true)}

func restore(data: Variant, notify: bool=true) -> bool:
    if not data is Dictionary or data.get("version")!=1 or not data.get("records") is Dictionary:
        return false
    for id in data.records:
        var entry: Variant=data.records[id]
        if not id is String or id.is_empty() or id.length()>128 or not entry is Dictionary:
            return false
        if not regions.has(entry.get("zone","")) or not TYPES.has(entry.get("kind","")) or not (entry.get("severity") is int or entry.get("severity") is float):
            return false
        if not is_finite(float(entry.severity)) or entry.severity<=0 or entry.severity>1:
            return false
    records=data.records.duplicate(true)
    if notify:
        changed.emit()
    return true
