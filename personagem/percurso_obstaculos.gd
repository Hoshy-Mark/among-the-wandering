extends RefCounted
var definitions: Dictionary
func setup(data: Dictionary) -> void:
    definitions = data

func row(rows: Array, seconds: float) -> Array:
    var index = 0
    while index < rows.size() - 2 and seconds > rows[index + 1][0]:
        index += 1
    var first: Array = rows[index]
    var last: Array = rows[index + 1]
    var amount = smoothstep(first[0], last[0], seconds)
    var result: Array = [seconds]
    for column in range(1, first.size()):
        result.append(lerpf(first[column], last[column], amount))
    return result

func sample(id: String, seconds: float) -> Dictionary:
    var action: Dictionary = definitions.actions[id]
    if id == "open_window":
        return {"x":0.0,"z":action.entry_z,"lift":0.0,"crouch":0.0,"height":1.84,"centre":Vector3(0,.92,0)}
    var b = row(action.body, seconds)
    var r = row(action.feet_R, seconds)
    var l = row(action.feet_L, seconds)
    var compact = smoothstep(.30,.65,seconds) * (1 - smoothstep(2.65,3.8,seconds))
    var height = lerpf(1.84,.72,compact)
    var release_start = 1.95 if id=="vault_window" else 1.55
    var release_end = 2.35 if id=="vault_window" else 1.95
    var grip_R = smoothstep(.05,.40,seconds)*(1-smoothstep(.55,1.0,seconds))
    if id=="vault_window":
        grip_R += smoothstep(1.05,1.45,seconds)*(1-smoothstep(release_start,release_end,seconds))
    return {"x":b[1],"z":b[2],"lift":0.0,"crouch":0.0,"height":height,
        "hip_y":b[3]-.04*compact,"yaw":b[4],"hip_pitch":b[5],"spine_pitch":b[6] - (8 * compact if id == "vault_fence" else 0),
        "chest_pitch":b[7],"counter_yaw":b[8],
        "R":Vector3(r[1],r[2],r[3]),"L":Vector3(l[1],l[2],l[3]),"foot_yaw_R":r[5],"foot_yaw_L":l[5],
        "centre":Vector3(0,lerpf(.92,maxf(1.18,b[3]+.25),compact),.12*compact),
        "hand_R":grip_R,
        "hand_x_R":lerpf(-.32,.545 if id=="vault_window" else .15,smoothstep(.90,1.05,seconds)),
        "hand_L":smoothstep(.05,.40,seconds)*(1-smoothstep(2.30,2.85,seconds))}

func window_fraction(seconds: float) -> float:
    return smoothstep(.55,1.85,seconds)
