extends "res://personagem/zumbi94.gd"
var population: Node3D
var ambient98=false
func setup(root_scene: Node3D,definition: Dictionary) -> void:
    var compatible=definition.duplicate(true)
    compatible.id="arroio82_01" if posmod(hash(definition.id),3)!=0 else "arroio82_02"
    super.setup(root_scene,compatible)
    identity=definition.id;name=identity
func step(delta: float) -> void:
    if not is_finite(delta) or delta<=0:return
    ambient98=state=="idle" and memory<=0 and search_remaining<=0 and not sees_player() and not hears_player()
    if ambient98:
        population.wander_live(self,delta);_present(delta)
    else:
        super.step(delta);population.sync_actor(self)
func _present(delta: float) -> void:
    var original=state
    if ambient98 and state=="idle":state="search"
    super._present(delta)
    if ambient98 and original=="idle":state="idle"
func walking_rate() -> float:
    if ambient98 and population!=null:return float(population.model.definitions[identity].get("wander_speed",.75))/.95*.62
    return super.walking_rate()
