extends RefCounted

signal changed

const VERSION=1
const EXHAUSTED_AT=15.0
const RECOVERED_AT=40.0
var stamina=100.0
var left_injury=0.0
var right_injury=0.0
var exhausted=false

func condition() -> String:
    if maxf(left_injury,right_injury)>.001:
        return "injured_left" if left_injury>=right_injury else "injured_right"
    return "tired" if exhausted else "normal"

func set_stamina(value: float) -> bool:
    if not is_finite(value) or value<0 or value>100:
        return false
    stamina=value
    if stamina<=EXHAUSTED_AT:
        exhausted=true
    elif stamina>=RECOVERED_AT:
        exhausted=false
    changed.emit()
    return true

func set_injury(side: String, severity: float) -> bool:
    if side not in ["L","R"] or not is_finite(severity) or severity<0 or severity>1:
        return false
    if side=="L":
        left_injury=severity
    else:
        right_injury=severity
    changed.emit()
    return true

func advance(delta: float, moving: bool, running: bool, sprinting: bool) -> void:
    if not is_finite(delta) or delta<=0:
        return
    var rate=8.0
    if moving:
        rate=-18.0 if sprinting else -10.0 if running else 2.0
    set_stamina(clampf(stamina+rate*delta,0,100))

func snapshot() -> Dictionary:
    return {"version":VERSION,"stamina":stamina,"left_injury":left_injury,"right_injury":right_injury,"exhausted":exhausted}

func restore(data: Variant) -> bool:
    if not data is Dictionary or data.get("version")!=VERSION:
        return false
    for key in ["stamina","left_injury","right_injury"]:
        if not data.has(key) or not (data[key] is float or data[key] is int):
            return false
        if not is_finite(float(data[key])) or float(data[key])<0:
            return false
    if data.stamina>100 or data.left_injury>1 or data.right_injury>1 or not data.get("exhausted") is bool:
        return false
    if (data.stamina<=EXHAUSTED_AT and not data.exhausted) or (data.stamina>=RECOVERED_AT and data.exhausted):
        return false
    stamina=data.stamina
    left_injury=data.left_injury
    right_injury=data.right_injury
    exhausted=data.exhausted
    changed.emit()
    return true
