extends "res://personagem/condicao61.gd"

var forearm_injury=0.0
var forearm_dressed=false
var forearm_revision=0
var damage_events: Dictionary={}

func receive_damage(event_id: String, region: String, severity: float) -> bool:
    if event_id.strip_edges().is_empty() or event_id.length()>128 or damage_events.has(event_id):
        return false
    if region not in ["leg_left","leg_right","forearm_left"] or not is_finite(severity) or severity<=0 or severity>1:
        return false
    if region=="leg_left":
        left_injury=minf(1,left_injury+severity)
    elif region=="leg_right":
        right_injury=minf(1,right_injury+severity)
    else:
        forearm_injury=minf(1,forearm_injury+severity)
        forearm_dressed=false
        forearm_revision+=1
    damage_events[event_id]={"region":region,"severity":severity}
    changed.emit()
    return true

func can_dress(revision: int) -> bool:
    return revision==forearm_revision and forearm_injury>0 and not forearm_dressed

func dress(revision: int) -> bool:
    if not can_dress(revision):
        return false
    forearm_dressed=true
    changed.emit()
    return true

func snapshot() -> Dictionary:
    var data=super.snapshot()
    data.merge({"version":2,"forearm_injury":forearm_injury,"forearm_dressed":forearm_dressed,"forearm_revision":forearm_revision,"damage_events":damage_events.duplicate(true)},true)
    return data

func restore(data: Variant) -> bool:
    if not data is Dictionary or not (data.get("version") is int or data.get("version") is float):
        return false
    var version=float(data.version)
    if version!=1.0 and version!=2.0:
        return false
    var base=data.duplicate(true)
    base.version=1
    var shadow=load("res://personagem/condicao61.gd").new()
    if not shadow.restore(base):
        return false
    var injury=0.0
    var dressed=false
    var revision=0
    var events: Dictionary={}
    if data.version==2:
        if not (data.get("forearm_injury") is float or data.get("forearm_injury") is int):
            return false
        injury=float(data.forearm_injury)
        if not is_finite(injury) or injury<0 or injury>1 or not data.get("forearm_dressed") is bool:
            return false
        dressed=data.forearm_dressed
        if dressed and injury<=0:
            return false
        if not (data.get("forearm_revision") is float or data.get("forearm_revision") is int):
            return false
        var raw_revision=float(data.forearm_revision)
        if not is_finite(raw_revision) or raw_revision<0 or raw_revision>2147483647 or raw_revision!=floor(raw_revision):
            return false
        revision=int(raw_revision)
        if not data.get("damage_events") is Dictionary:
            return false
        for id in data.damage_events:
            var entry: Variant=data.damage_events[id]
            if not id is String or id.strip_edges().is_empty() or id.length()>128 or not entry is Dictionary:
                return false
            if entry.get("region") not in ["leg_left","leg_right","forearm_left"] or not (entry.get("severity") is float or entry.get("severity") is int):
                return false
            var amount=float(entry.severity)
            if not is_finite(amount) or amount<=0 or amount>1:
                return false
        events=data.damage_events.duplicate(true)
    stamina=shadow.stamina
    left_injury=shadow.left_injury
    right_injury=shadow.right_injury
    exhausted=shadow.exhausted
    forearm_injury=injury
    forearm_dressed=dressed
    forearm_revision=revision
    damage_events=events
    changed.emit()
    return true
