extends RefCounted

var rig: Skeleton3D
var joints: Dictionary
var indices: Dictionary = {}
var maximum_attachment_error = 0.0


func setup(actor: Node3D) -> void:
    rig = actor.skeleton
    joints = JSON.parse_string(FileAccess.get_file_as_string(actor.base_dir + "articulacao_bracos.json")).joints
    for index in rig.get_bone_count():
        indices[rig.get_bone_name(index)] = index


func _skin(name: String) -> Transform3D:
    var index: int = indices[name]
    return rig.get_bone_global_pose(index) * rig.get_bone_global_rest(index).affine_inverse()


func _point(side: String, name: String) -> Vector3:
    var values: Array = joints[side][name]
    return Vector3(values[0], values[1], values[2])


func capture() -> Dictionary:
    rig.force_update_all_bone_transforms()
    var result: Dictionary = {}
    for side in ["L", "R"]:
        var upper = _skin("UpperArm." + side)
        var forearm = _skin("Forearm." + side)
        var hand = _skin("Hand." + side)
        var elbow = _point(side, "elbow")
        var wrist = _point(side, "wrist")
        result[side] = {
            "elbow": upper.basis.inverse() * (upper * elbow - forearm * elbow),
            "wrist": forearm.basis.inverse() * (forearm * wrist - hand * wrist)
        }
    return result


func _translate(name: String, delta: Vector3) -> void:
    var index: int = indices[name]
    var parent = rig.get_bone_global_pose(rig.get_bone_parent(index))
    rig.set_bone_pose_position(index, rig.get_bone_pose_position(index) + parent.basis.inverse() * delta)
    rig.force_update_all_bone_transforms()


func correct(source: Dictionary, target: Dictionary, amount: float) -> void:
    rig.force_update_all_bone_transforms()
    for side in ["L", "R"]:
        var upper = _skin("UpperArm." + side)
        var forearm = _skin("Forearm." + side)
        var elbow = _point(side, "elbow")
        var elbow_gap: Vector3 = source[side].elbow.lerp(target[side].elbow, amount)
        _translate("Forearm." + side, upper * elbow - forearm * elbow - upper.basis * elbow_gap)
        forearm = _skin("Forearm." + side)
        var hand = _skin("Hand." + side)
        var wrist = _point(side, "wrist")
        var wrist_gap: Vector3 = source[side].wrist.lerp(target[side].wrist, amount)
        _translate("Hand." + side, forearm * wrist - hand * wrist - forearm.basis * wrist_gap)
        var elbow_error = upper * elbow - _skin("Forearm." + side) * elbow - upper.basis * elbow_gap
        var wrist_error = forearm * wrist - _skin("Hand." + side) * wrist - forearm.basis * wrist_gap
        maximum_attachment_error = maxf(maximum_attachment_error, maxf(elbow_error.length(), wrist_error.length()))
