extends "res://personagem/ferimentos62.gd"
var hunger=25.0
var thirst=25.0
var medicine_remaining=0.0
var pain_base=0.0
func pain() -> float:
    return pain_base*(.5 if medicine_remaining>0 else 1.0)
func tick_needs(delta: float) -> void:
    if not is_finite(delta) or delta<=0:return
    hunger=minf(100,hunger+delta*.015)
    thirst=minf(100,thirst+delta*.025)
    medicine_remaining=maxf(0,medicine_remaining-delta)
    changed.emit()
func recovery_factor() -> float:
    return (1-.6*maxf(hunger,thirst)/100)*(1-.3*pain()/100)
func advance(delta: float, moving: bool, running: bool, sprinting: bool) -> void:
    var recovering=not moving or (not running and not sprinting)
    super.advance(delta*recovery_factor() if recovering else delta,moving,running,sprinting)
func can_use(kind: String, revision: int) -> bool:
    match kind:
        "eat":return hunger>0
        "drink":return thirst>0
        "medicine":return pain_base>0 and medicine_remaining<=0
        "bandage":return can_dress(revision)
    return false
func apply_use(kind: String, revision: int) -> bool:
    if not can_use(kind,revision):return false
    match kind:
        "eat":hunger=maxf(0,hunger-30)
        "drink":thirst=maxf(0,thirst-35)
        "medicine":medicine_remaining=120.0
        "bandage":return dress(revision)
    changed.emit()
    return true
func snapshot() -> Dictionary:
    var result=super.snapshot()
    result.merge({"version":3,"hunger":hunger,"thirst":thirst,"medicine_remaining":medicine_remaining},true)
    return result
func restore(data: Variant) -> bool:
    if not data is Dictionary:return false
    var raw_version=data.get("version")
    if not (raw_version is int or raw_version is float):return false
    var version=float(raw_version)
    if version!=1.0 and version!=2.0 and version!=3.0:return false
    var incoming_hunger=25.0
    var incoming_thirst=25.0
    var medicine=0.0
    if version==3:
        for key in ["hunger","thirst","medicine_remaining"]:
            var value=data.get(key)
            if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>(120 if key=="medicine_remaining" else 100):return false
        incoming_hunger=data.hunger;incoming_thirst=data.thirst;medicine=data.medicine_remaining
    var base=data.duplicate(true)
    if version==3:base.version=2
    var shadow=load("res://personagem/ferimentos62.gd").new()
    if not shadow.restore(base):return false
    # Validate everything before publishing any of the new state to observers.
    hunger=incoming_hunger;thirst=incoming_thirst;medicine_remaining=medicine
    return super.restore(base)
