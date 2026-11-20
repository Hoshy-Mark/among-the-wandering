extends "res://personagem/mira_tiros91.gd"
func cone_degrees() -> float:
    var scale=float(scene.player.weapons.spec(scene.player.weapons.held_uid).get("accuracy_scale",1))
    return super.cone_degrees()*scale
func note_shot() -> void:
    var scale=float(scene.player.weapons.spec(scene.player.weapons.held_uid).get("bloom_scale",1))
    bloom=minf(float(accuracy.recoil_max),bloom+float(accuracy.recoil_step)*scale)
