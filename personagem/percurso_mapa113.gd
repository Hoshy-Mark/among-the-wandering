extends "res://personagem/percurso_mapa77.gd"
var mirrored113=false
func configure(kind: String,height_delta: float,floor_delta: float) -> void:
    super.configure(kind,height_delta,floor_delta)
    if kind.is_empty():mirrored113=false
func sample(id: String,seconds: float) -> Dictionary:
    var s=super.sample(id,seconds)
    if not mirrored113 or id!="vault_window":return s
    s.x=-s.x;s.centre.x=-s.centre.x
    var right: Vector3=s.R;var left: Vector3=s.L
    s.R=Vector3(-left.x,left.y,left.z);s.L=Vector3(-right.x,right.y,right.z)
    var grip: float=s.hand_R;s.hand_R=s.hand_L;s.hand_L=grip
    return s
