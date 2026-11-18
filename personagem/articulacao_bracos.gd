extends RefCounted

var actor: Node3D
var rig: Skeleton3D
var joints: Dictionary
var indices: Dictionary = {}
var twist_fraction = .35


func setup(npc: Node3D) -> void:
    actor = npc
    rig = actor.skeleton
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(actor.base_dir + "articulacao_bracos.json"))
    joints = data.joints
    twist_fraction = data.twist_fraction
    for index in rig.get_bone_count():
        indices[rig.get_bone_name(index)] = index


func _skin(name: String) -> Transform3D:
    var index: int = indices[name]
    return rig.get_bone_global_pose(index) * rig.get_bone_global_rest(index).affine_inverse()


func _support(name: String, rotation: Quaternion, center: Vector3, width_scale: float = 1) -> void:
    var index: int = indices[name]
    var rest = rig.get_bone_global_rest(index)
    var basis = Basis(rotation) * rest.basis * Basis.from_scale(Vector3(width_scale, 1, width_scale))
    var target = Transform3D(basis, center)
    var parent = rig.get_bone_global_pose(rig.get_bone_parent(index))
    rig.set_bone_pose(index, parent.affine_inverse() * target)
    rig.force_update_all_bone_transforms()


func apply() -> void:
    for side in ["L", "R"]:
        var elbow_values: Array = joints[side].elbow
        var wrist_values: Array = joints[side].wrist
        var elbow = Vector3(elbow_values[0], elbow_values[1], elbow_values[2])
        var wrist = Vector3(wrist_values[0], wrist_values[1], wrist_values[2])
        var upper = _skin("UpperArm." + side)
        var forearm = _skin("Forearm." + side)
        var hand = _skin("Hand." + side)
        var upper_rotation = upper.basis.orthonormalized().get_rotation_quaternion()
        var forearm_rotation = forearm.basis.orthonormalized().get_rotation_quaternion()
        var hand_rotation = hand.basis.orthonormalized().get_rotation_quaternion()
        var bend = upper_rotation.angle_to(forearm_rotation)
        var elbow_scale = minf(1.08, 1 / maxf(.9, cos(bend * .25)))
        _support("ElbowSupport." + side, upper_rotation.slerp(forearm_rotation, .5), (upper * elbow).lerp(forearm * elbow, .5), elbow_scale)
        var axis = (forearm.basis * (wrist - elbow)).normalized()
        var difference = (hand_rotation * forearm_rotation.inverse()).normalized()
        if difference.w < 0:
            difference = Quaternion(-difference.x, -difference.y, -difference.z, -difference.w)
        var projected = axis * Vector3(difference.x, difference.y, difference.z).dot(axis)
        var twist = Quaternion(projected.x, projected.y, projected.z, difference.w)
        if twist.length_squared() < .000001:
            twist = Quaternion.IDENTITY
        else:
            twist = twist.normalized()
        var distributed = Quaternion.IDENTITY.slerp(twist, twist_fraction) * forearm_rotation
        # Spread palm extension across the two existing wrist support rings.
        # These leaves do not alter the forearm, hand or finger pivots.
        var support_blend = 0.0
        if actor.motion in ["vault_fence", "vault_window", "open_window"]:
            support_blend = smoothstep(0, 1, actor.motion_blend)
        distributed = distributed.slerp(hand_rotation, .35 * support_blend)
        var extension = smoothstep(0, deg_to_rad(60), forearm_rotation.angle_to(hand_rotation)) * support_blend
        _support("ForearmTwist." + side, distributed, forearm * elbow.lerp(wrist, .60), lerpf(1, 1.09, extension))
        var wrist_limit = lerpf(1.06, 1.09, support_blend)
        var wrist_scale = minf(wrist_limit, 1 / maxf(.90, cos(distributed.angle_to(hand_rotation) * lerpf(.25, .5, support_blend))))
        _support("WristSupport." + side, distributed.slerp(hand_rotation, .5), (forearm * wrist).lerp(hand * wrist, .5), wrist_scale)
