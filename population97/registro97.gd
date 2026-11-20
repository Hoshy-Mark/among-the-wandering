extends "res://population97/registro_base97.gd"
func reset() -> void:
    super.reset()
    for id in states:
        states[id].wait97=float(posmod(hash(id),31))*.1
        states[id].visits97=0;states[id].direction97=1
func valid(data: Variant) -> bool:
    if not super.valid(data):return false
    for s in data.individuals.values():
        if not _number(s.get("wait97"),0,4):return false
        if not _number(s.get("visits97"),0,1e12) or s.visits97!=floor(s.visits97):return false
        if not _number(s.get("direction97"),-1,1) or absf(s.direction97)!=1:return false
    return true
func schedule(delta: float) -> void:
    if is_finite(delta) and delta>0:clock+=delta
    # No scheduled march to town. Perception/target selection belongs to the
    # playable AI integration; this spatial study only wanders its habitats.
