extends RefCounted

static func register(layer: RefCounted) -> void:
    if layer.poses.has("Obstacle_Support"):
        return
    var pose: Dictionary = layer.poses.Open.duplicate(true)
    var measured: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(layer.actor.base_dir+"apoios_maos.json"))
    for name in pose:
        if not str(name).contains(".01."):
            continue
        var values: Array = pose[name].rotation
        var basis = Basis(Quaternion(values[0],values[1],values[2],values[3]))
        var side = "R" if str(name).ends_with(".R") else "L"
        var data: Dictionary = measured[side]
        var forward = Vector3(data.forward[0],data.forward[1],data.forward[2])
        var normal = Vector3(data.back_normal[0],data.back_normal[1],data.back_normal[2])
        var direction = (forward+normal*.04).normalized()
        if str(name).begins_with("Thumb."):
            direction = (basis.y-normal*basis.y.dot(normal)+normal*.04).normalized()
        basis = Basis(Quaternion(basis.y.normalized(),direction))*basis
        var q = basis.get_rotation_quaternion().normalized()
        pose[name].rotation = [q.x,q.y,q.z,q.w]
    layer.poses.Obstacle_Support = pose
    var frame: Dictionary = pose.duplicate(true)
    for name in frame:
        if str(name).ends_with(".R"):
            frame[name] = layer.poses.Box[name].duplicate(true)
    layer.poses.Obstacle_RightFrame = frame

static func at(layer: RefCounted, id: String, seconds: float) -> Dictionary:
    register(layer)
    var relaxed: Dictionary = layer.decode(layer.poses.Relaxed)
    var support: Dictionary = layer.decode(layer.poses.Obstacle_Support)
    var grip: Dictionary = layer.decode(layer.poses.Box)
    var cylinder: Dictionary = layer.decode(layer.poses.Cylinder)
    var result: Dictionary = {}
    for name in support:
        if id=="open_window":
            var amount = smoothstep(.05,.45,seconds)*(1-smoothstep(1.90,2.40,seconds))
            result[name] = relaxed[name].interpolate_with(cylinder[name],amount)
        elif str(name).ends_with(".L"):
            result[name] = support[name].interpolate_with(relaxed[name],smoothstep(2.30,2.85,seconds))
        else:
            var pose: Transform3D = support[name].interpolate_with(relaxed[name],smoothstep(.55,1.0,seconds))
            if id=="vault_window":
                var amount = smoothstep(.95,1.30,seconds)*(1-smoothstep(2.35,2.70,seconds))
                pose = pose.interpolate_with(grip[name],amount)
            result[name] = pose
    return result

static func apply_at(layer: RefCounted, id: String, seconds: float) -> void:
    layer.current = at(layer,id,seconds)
    layer.apply()
