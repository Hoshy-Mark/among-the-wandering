extends "res://personagem/percurso_obstaculos.gd"
var map_kind=""
var rise=0.0
var landing=0.0
func configure(kind: String, height_delta: float, floor_delta: float) -> void:
    map_kind=kind
    rise=height_delta
    landing=floor_delta
func sample(id: String, seconds: float) -> Dictionary:
    var s=super.sample(id,seconds)
    if id!=map_kind:return s
    var compact=smoothstep(.30,.65,seconds)*(1-smoothstep(2.65,3.8,seconds))
    var progress=smoothstep(2.65,3.8,seconds)
    s.lift=landing*progress
    s.hip_y+=(rise+.06)*compact
    s.centre.y+=rise*compact
    for side in ["R","L"]:
        var foot: Vector3=s[side]
        foot.y+=(rise+.06)*compact+s.lift
        s[side]=foot
    var collision_compact=smoothstep(.15,.4,seconds)*(1-smoothstep(2.65,3.8,seconds))
    s.height=lerpf(1.84,.72,collision_compact)
    s.centre.y=lerpf(.92,1.18+rise,collision_compact)-s.lift*collision_compact
    s.hand_L*=1-smoothstep(.85,1.3,seconds) if id=="vault_fence" else 1-smoothstep(1.5,2.4,seconds)
    s.hand_R=smoothstep(.05,.40,seconds)*(1-smoothstep(.55,1.4,seconds))
    s.hand_x_R=-.32
    return s
