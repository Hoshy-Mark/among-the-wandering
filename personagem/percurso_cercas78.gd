extends "res://personagem/percurso_mapa77.gd"
var high=false
func source_time(seconds: float) -> float:
    if not high:return seconds
    return .65*smoothstep(.8,1.8,seconds) if seconds<1.8 else .65+seconds-1.8
func sample(id: String, seconds: float) -> Dictionary:
    var t=source_time(seconds)
    var s=super.sample(id,t)
    if high:
        var source_compact=smoothstep(.30,.65,t)*(1-smoothstep(2.65,3.8,t))
        var pull=smoothstep(.3,1.1,seconds)*(1-smoothstep(2.65,3.8,t))
        var extra=(rise+.06)*(pull-source_compact)
        extra-=.10*pull*(1-smoothstep(.15,.5,t))
        s.z+=.28*pull*(1-smoothstep(.25,.65,t))
        s.hip_y+=extra
        s.centre.y+=extra
        s.R.y+=extra
        s.L.y+=extra
        var collision=smoothstep(.4,1.1,seconds)*(1-smoothstep(2.65,3.8,t))
        s.height=lerpf(1.84,.72,collision)
        s.centre.y=lerpf(.92,1.18+rise,collision)
        var grip=smoothstep(.15,.65,seconds)
        s.hand_L=grip*(1-smoothstep(.25,.95,t))
        s.hand_R=grip*(1-smoothstep(.25,1.05,t))
    return s
