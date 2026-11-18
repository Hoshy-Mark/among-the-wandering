extends RefCounted

const STANDING_BONES = ["Root", "Hips", "Thigh.L", "Thigh.R", "Shin.L", "Shin.R", "Foot.L", "Foot.R"]


func _reset(actor: Node3D, action: RefCounted) -> void:
    actor.motion_paused = false
    action.cancel()
    action.clear_dressing()
    actor.set_motion("idle")
    actor.motion_clock = 0
    actor.motion_blend = 1
    actor.hand_layer.advance(.25)
    actor.advance(0)


func run(actor: Node3D, action: RefCounted) -> void:
    var supplies = load(actor.base_dir + "suprimentos_teste.gd").new()
    var cases: Array = []
    var standing: Dictionary = {}
    var maximum_joint_gaps = {"elbow": 0.0, "wrist": 0.0}
    _reset(actor, action)
    for name in STANDING_BONES:
        standing[name] = actor.skeleton.get_bone_pose(actor.skeleton.find_bone(name))
    for fps in [30, 60, 120]:
        for kind in action.definitions:
            _reset(actor, action)
            supplies.refill()
            var expected: int = supplies.stock[kind]
            assert(action.begin(func() -> bool: return supplies.apply(kind, expected), kind))
            assert(not action.begin(func() -> bool: return true, kind))
            var duration: float = actor.motion_transition_duration + action.definitions[kind].duration
            for frame in range(ceili((duration + .4) * fps)):
                action.advance(1.0 / fps)
                if action.state == "gesture" and actor.motion_blend >= 1:
                    for name in standing:
                        var pose = actor.skeleton.get_bone_pose(actor.skeleton.find_bone(name))
                        var position_error = pose.origin.distance_to(standing[name].origin)
                        var rotation_error = pose.basis.get_rotation_quaternion().angle_to(standing[name].basis.get_rotation_quaternion())
                        assert(position_error < .0001 and rotation_error < .003, "%s moved %s by %f m / %f rad" % [kind, name, position_error, rotation_error])
                    for side in ["L", "R"]:
                        var data: Dictionary = actor.arm_articulation.joints[side]
                        var elbow = Vector3(data.elbow[0], data.elbow[1], data.elbow[2])
                        var wrist = Vector3(data.wrist[0], data.wrist[1], data.wrist[2])
                        var upper: Transform3D = actor.arm_articulation._skin("UpperArm." + side)
                        var forearm: Transform3D = actor.arm_articulation._skin("Forearm." + side)
                        var hand: Transform3D = actor.arm_articulation._skin("Hand." + side)
                        var elbow_gap = (upper * elbow).distance_to(forearm * elbow)
                        var wrist_gap = (forearm * wrist).distance_to(hand * wrist)
                        assert(elbow_gap < .025 and wrist_gap < .015, "%s has disconnected %s joints" % [kind, side])
                        maximum_joint_gaps.elbow = maxf(maximum_joint_gaps.elbow, elbow_gap)
                        maximum_joint_gaps.wrist = maxf(maximum_joint_gaps.wrist, wrist_gap)
                        assert(absf(forearm.basis.determinant() - 1) < .001)
                        assert(absf(hand.basis.determinant() - 1) < .001)
            assert(supplies.stock[kind] == expected - 1 and supplies.effects[kind] == 1)
            assert(action.state == "idle" and action.visual_kind.is_empty())
            assert(actor.hand_layer.label == "Relaxed")
            assert(action.props.dressing.visible == (kind == "bandage"))
            cases.append({"action": kind, "fps": fps, "effect_once": true, "standing": true})
    for kind in action.definitions:
        _reset(actor, action)
        supplies.refill()
        var expected: int = supplies.stock[kind]
        assert(action.begin(func() -> bool: return supplies.apply(kind, expected), kind))
        var commit: float = actor.motion_transition_duration + action.definitions[kind].effect_time
        action.advance(commit - .02)
        assert(supplies.stock[kind] == expected)
        actor.motion_paused = true
        var clock: float = actor.motion_clock
        var object_pose: Transform3D = action.props.objects[kind].global_transform
        action.advance(3)
        assert(actor.motion_clock == clock and supplies.stock[kind] == expected)
        assert(action.props.objects[kind].global_transform.is_equal_approx(object_pose))
        actor.motion_paused = false
        action.cancel("walk")
        action.advance(2)
        assert(supplies.stock[kind] == expected and not action.effect_done)
        _reset(actor, action)
        assert(action.begin(func() -> bool: return supplies.apply(kind, expected), kind))
        action.advance(commit + .02)
        assert(supplies.stock[kind] == expected - 1)
        action.cancel("walk")
        action.advance(8)
        assert(supplies.stock[kind] == expected - 1 and supplies.effects[kind] == 1)
        _reset(actor, action)
        supplies.refill()
        assert(action.begin(func() -> bool: return supplies.apply(kind, expected), kind))
        supplies.stock[kind] = 0
        action.advance(10)
        assert(not action.effect_succeeded and supplies.effects[kind] == 0)
        assert(not action.props.dressing.visible)
        _reset(actor, action)
        supplies.refill()
        assert(action.begin(func() -> bool: return supplies.apply(kind, expected), kind))
        action.advance(.3)
        actor.set_motion("run")
        action.advance(2)
        assert(action.state == "idle" and supplies.effects[kind] == 0)
        assert(action.props.active_kind.is_empty())
    var saved_transform: Transform3D = actor.transform
    for heading in [0, 90, 180]:
        for scale_factor in [.85, 1.0]:
            _reset(actor, action)
            actor.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(heading)).scaled(Vector3.ONE * scale_factor), Vector3(2, 0, -3))
            assert(action.begin(func() -> bool: return true, "drink"))
            action.advance(actor.motion_transition_duration + action.definitions.drink.effect_time)
            var hand_pose: Transform3D = actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("Hand.R"))
            var expected_pose: Transform3D = hand_pose * action._grip_transform()
            assert(expected_pose.is_equal_approx(action.props.objects.drink.global_transform))
    actor.transform = saved_transform
    _reset(actor, action)
    var legacy_effects: Array = []
    assert(action.begin(func() -> bool:
        legacy_effects.append(true)
        return true, "equip"))
    action.advance(5)
    assert(legacy_effects.size() == 1)
    assert(not action.begin(Callable(), "eat"))
    assert(not action.begin(Callable(), "invalid"))
    _reset(actor, action)
    var result = {"cases": cases, "gesture": "full_actions_supported_joints", "maximum_joint_gaps_m": maximum_joint_gaps, "support_bones": 6, "effect_once": true, "cancel_before_after": true, "pause": true, "stale_stock_rejected": true, "external_motion_cancels": true, "standing_lower_body": true, "root_heading_scale": true, "legacy_inventory_action": true}
    FileAccess.open("res://qa/consumo_runtime.json", FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
    print("R53_CONSUMPTION_QA_OK")
