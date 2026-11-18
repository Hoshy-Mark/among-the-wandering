extends RefCounted

var calls: Array = []


func _effect() -> bool:
    calls.append(true)
    return true


func _reset(actor: Node3D, combat: RefCounted, armed: bool = false) -> void:
    actor.motion_paused = false
    combat.set_guard(false)
    combat.set_armed(armed)
    combat.set_guard(true)
    combat.advance(.3)
    calls.clear()


func run(actor: Node3D, action: RefCounted, combat: RefCounted, target: StaticBody3D) -> void:
    var cases: Array = []
    var gaps = {"elbow": 0.0, "wrist": 0.0}
    for fps in [30, 60, 120]:
        for kind in ["push", "push_armed", "punch", "strike_onehand"]:
            _reset(actor, combat, kind in ["push_armed", "strike_onehand"])
            assert(combat.begin("push" if kind == "push_armed" else kind, _effect))
            assert(not combat.begin("push", _effect))
            var definition: Dictionary = combat.definitions[kind]
            for frame in ceili((definition.duration + .7) * fps):
                combat.advance(1.0 / fps)
                for side in ["L", "R"]:
                    var values: Dictionary = actor.arm_articulation.joints[side]
                    var elbow = Vector3(values.elbow[0], values.elbow[1], values.elbow[2])
                    var wrist = Vector3(values.wrist[0], values.wrist[1], values.wrist[2])
                    var upper: Transform3D = actor.arm_articulation._skin("UpperArm." + side)
                    var forearm: Transform3D = actor.arm_articulation._skin("Forearm." + side)
                    var hand: Transform3D = actor.arm_articulation._skin("Hand." + side)
                    var elbow_gap = (upper * elbow).distance_to(forearm * elbow)
                    var wrist_gap = (forearm * wrist).distance_to(hand * wrist)
                    gaps.elbow = maxf(gaps.elbow, elbow_gap)
                    gaps.wrist = maxf(gaps.wrist, wrist_gap)
                    assert(elbow_gap < .025 and wrist_gap < .015, "%s disconnected %s" % [kind, side])
                    assert(absf(forearm.basis.determinant() - 1) < .001)
                    assert(absf(hand.basis.determinant() - 1) < .001)
            assert(calls.size() == 1 and combat.state == "guard")
            cases.append({"action": kind, "fps": fps, "effect_once": true})
    for kind in ["push", "punch", "strike_onehand"]:
        _reset(actor, combat, kind == "strike_onehand")
        assert(combat.begin(kind, _effect))
        var commit: float = actor.motion_transition_duration + combat.definitions[kind].impact_time
        combat.advance(commit - .02)
        actor.motion_paused = true
        var clock: float = actor.motion_clock
        combat.advance(5)
        assert(actor.motion_clock == clock and calls.is_empty())
        actor.motion_paused = false
        combat.cancel()
        combat.advance(5)
        assert(calls.is_empty())
        assert(combat.begin(kind, _effect))
        combat.advance(commit + .02)
        combat.cancel()
        combat.advance(5)
        assert(calls.size() == 1)
        _reset(actor, combat, kind == "strike_onehand")
        assert(combat.begin(kind, _effect))
        combat.advance(.1)
        actor.set_motion("run")
        combat.advance(5)
        assert(actor.motion == "run" and not combat.guarding and calls.is_empty())
    _reset(actor, combat)
    assert(not combat.begin("invalid", _effect))
    assert(not combat.begin("strike_onehand", _effect))
    assert(not combat.begin("push", Callable()))
    assert(combat.begin("push", func() -> bool:
        assert(not combat.begin("push", _effect))
        assert(not combat.set_guard(false))
        combat.cancel()
        return _effect()))
    combat.advance(5)
    assert(calls.size() == 1 and combat.state == "guard")
    _reset(actor, combat, true)
    assert(not combat.begin("punch", _effect))
    assert(combat.begin("strike_onehand", _effect))
    combat.set_armed(false)
    combat.advance(5)
    assert(calls.is_empty() and not combat.weapon.visible)
    var receiver = RefCounted.new()
    _reset(actor, combat)
    assert(combat.begin("push", Callable(receiver, "has_meta").bind("unused")))
    receiver = null
    combat.advance(5)
    assert(combat.effect_done and not combat.effect_succeeded)
    combat.set_guard(false)
    assert(action.begin(_effect, "drink"))
    action.advance(.1)
    combat.set_guard(true)
    combat.advance(5)
    assert(action.state == "idle" and calls.is_empty())
    var direction_cases = {"combat_forward": Vector2(0, 1), "combat_back": Vector2(0, -1), "combat_left": Vector2.RIGHT, "combat_right": Vector2.LEFT}
    for id in direction_cases:
        combat.advance(.3, direction_cases[id])
        assert(actor.motion == id)
    var saved: Vector3 = target.global_position
    target.global_position = actor.global_position + actor.global_basis.z * .70
    await actor.get_tree().physics_frame
    target.reset()
    assert(target.try_hit(actor, "push", combat.definitions.push))
    for offset in [Vector3(0, 0, 2), Vector3(0, 0, -.70), Vector3(0, 1, .70)]:
        target.global_position = actor.global_position + actor.global_basis * offset
        assert(not target.try_hit(actor, "push", combat.definitions.push))
    target.global_position = actor.global_position + actor.global_basis.z * .70
    var wall = StaticBody3D.new()
    var collision = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = Vector3(.5, 2, .05)
    collision.shape = box
    wall.add_child(collision)
    actor.get_parent().add_child(wall)
    wall.global_position = actor.global_position + actor.global_basis.z * .35 + Vector3.UP
    wall.global_rotation = actor.global_rotation
    await actor.get_tree().physics_frame
    assert(not target.try_hit(actor, "push", combat.definitions.push))
    wall.queue_free()
    target.global_position = saved
    var result = {"cases": cases, "maximum_joint_gap_m": gaps, "pause": true, "cancel_before_after": true, "invalid_freed_reentrant_callbacks": true, "external_motion_preserved": true, "disarm_cancels": true, "inventory_interruption": true, "four_guard_directions": true, "range_cone_height_wall": true}
    FileAccess.open("res://qa/combate_runtime.json", FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
    combat.set_guard(false)
    load(actor.base_dir + "verificar_consumo.gd").new().run(actor, action)
    print("R54_COMBAT_QA_OK ", JSON.stringify(gaps))
