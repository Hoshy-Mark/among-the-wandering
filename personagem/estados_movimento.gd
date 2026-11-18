extends RefCounted

var definitions: Dictionary


func setup(data: Dictionary) -> void:
    definitions = data


func source_time(id: String, seconds: float, source_length: float) -> float:
    var phase = fposmod(seconds / definitions[id].duration, 1.0)
    if id in ["limp_left", "limp_right"]:
        var sign = 1.0 if id == "limp_left" else -1.0
        phase += sign * .09 * (1-cos(TAU * phase))
    return phase * source_length


func motion_for(condition: String, moving: bool, running: bool) -> String:
    if condition in ["injured_left", "injured_right"]:
        return ("limp_left" if condition == "injured_left" else "limp_right") if moving else "injured_idle"
    if condition == "tired":
        return ("tired_run" if running else "tired_walk") if moving else "tired_idle"
    return ("run" if running else "walk") if moving else "idle"
