extends RefCounted

var effects: Array = []
var completed: Array = []
var deaths = 0
var knockdowns = 0
var recoveries = 0


func _effect() -> bool:
    effects.append(true)
    return true


func _reset(actor: Node3D, combat: RefCounted, reaction: RefCounted, armed: bool = false) -> void:
    actor.motion_paused = false
    assert(reaction.reset())
    combat.set_armed(armed)
    effects.clear()
    completed.clear()
    deaths = 0
    knockdowns = 0
    recoveries = 0


func run(actor: Node3D, action: RefCounted, combat: RefCounted, reaction: RefCounted, target: StaticBody3D) -> void:
    reaction.finished.connect(func(id: String): completed.append(id))
    reaction.died.connect(func(): deaths += 1)
    reaction.knocked_down.connect(func(): knockdowns += 1)
    reaction.stood_up.connect(func(): recoveries += 1)
    var cases: Array = []
    var gaps = {"shoulder": 0.0, "elbow": 0.0, "wrist": 0.0}
    var neutral: Dictionary = {}
    _reset(actor, combat, reaction)
    for index in actor.skeleton.get_bone_count():
        var name: String = actor.skeleton.get_bone_name(index)
        if name.begins_with("Root") or name.begins_with("Hips") or name.begins_with("UpperArm") or name.begins_with("Forearm.") or name.begins_with("Hand."):
            neutral[index] = actor.skeleton.get_bone_pose(index)
    for fps in [30, 60, 120]:
        for clip in reaction.definitions:
            if clip == "down":
                continue
            var armed: bool = str(clip).ends_with("_armed")
            var kind: String = str(clip).trim_suffix("_armed")
            _reset(actor, combat, reaction, armed)
            for index in neutral:
                var pose = actor.skeleton.get_bone_pose(index)
                assert(pose.origin.distance_to(neutral[index].origin) < .00001, "reset %s after %s position %s vs %s" % [actor.skeleton.get_bone_name(index), clip, pose.origin, neutral[index].origin])
                assert(pose.basis.get_rotation_quaternion().angle_to(neutral[index].basis.get_rotation_quaternion()) < .002, "reset rotation")
            if kind == "get_up":
                assert(reaction.begin("fall"))
                reaction.advance(4)
                assert(reaction.state == "down")
                completed.clear()
            assert(reaction.begin(kind))
            assert(not combat.begin("push", _effect))
            assert(not combat.set_guard(true))
            assert(not combat.set_armed(not armed))
            assert(not action.begin(_effect, "drink"))
            assert(not action.cancel())
            var duration: float = actor.motion_transition_duration + reaction.definitions[clip].duration + .5
            for frame in ceili(duration * fps):
                if reaction.is_active():
                    reaction.advance(1.0 / fps)
                else:
                    action.advance(1.0 / fps)
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
                    if elbow_gap >= .025 or wrist_gap >= .015:
                        print("JOINT_FAIL ", clip, " frame=", frame, " fps=", fps, " state=", reaction.state, " blend=", actor.motion_blend, " elbow=", elbow_gap, " wrist=", wrist_gap)
                    assert(elbow_gap < .025 and wrist_gap < .015, "%s disconnected %s" % [clip, side])
                    var index = actor.skeleton.find_bone("UpperArm." + side)
                    var rest = actor.skeleton.get_bone_global_rest(index).origin
                    var parent = actor.skeleton.get_bone_parent(index)
                    var parent_skin: Transform3D = actor.skeleton.get_bone_global_pose(parent) * actor.skeleton.get_bone_global_rest(parent).affine_inverse()
                    var shoulder_gap = (parent_skin * rest).distance_to(upper * rest)
                    gaps.shoulder = maxf(gaps.shoulder, shoulder_gap)
                    assert(shoulder_gap < .001)
                    for transform in [upper, forearm, hand]:
                        assert(absf(transform.basis.determinant() - 1) < .001)
            var expected: String = {"fall": "down", "death": "dead"}.get(kind, "idle")
            assert(reaction.state == expected, clip)
            assert(completed == [kind])
            assert(deaths == (1 if kind == "death" else 0))
            assert(combat.control_locked == (expected != "idle"))
            if kind == "get_up":
                assert(recoveries == 1)
            cases.append({"clip": clip, "fps": fps, "terminal_state": expected, "finished_once": true})
    _reset(actor, combat, reaction)
    assert(not reaction.begin("invalid"))
    assert(not reaction.begin("get_up"))
    assert(reaction.begin("fall"))
    reaction.advance(.7)
    var clock: float = actor.motion_clock
    actor.motion_paused = true
    reaction.advance(10)
    assert(actor.motion_clock == clock and completed.is_empty())
    actor.motion_paused = false
    assert(reaction.begin("death"))
    assert(actor.motion_clock == clock)
    reaction.advance(8)
    assert(reaction.state == "dead" and deaths == 1)
    var terminal_pose: Transform3D = actor.skeleton.get_bone_pose(actor.skeleton.find_bone("Root"))
    reaction.advance(30)
    assert(actor.blink == 1)
    assert(actor.skeleton.get_bone_pose(actor.skeleton.find_bone("Root")).is_equal_approx(terminal_pose))
    assert(not reaction.begin("get_up") and not reaction.begin("hit_front"))
    _reset(actor, combat, reaction)
    assert(reaction.begin("fall"))
    reaction.advance(5)
    assert(reaction.begin("get_up"))
    reaction.advance(1.0)
    clock = actor.motion_clock
    assert(reaction.begin("death"))
    assert(actor.motion_clock == clock)
    reaction.advance(5)
    assert(reaction.state == "dead" and deaths == 1)
    for after_impact in [false, true]:
        _reset(actor, combat, reaction)
        assert(combat.begin("punch", _effect))
        combat.advance(actor.motion_transition_duration + (.5 if after_impact else .1))
        assert(reaction.begin("hit_front"))
        reaction.advance(5)
        assert(effects.size() == (1 if after_impact else 0))
        assert(combat.guarding and not combat.control_locked)
    _reset(actor, combat, reaction)
    assert(action.begin(_effect, "drink"))
    action.advance(.1)
    assert(reaction.begin("stagger"))
    reaction.advance(5)
    assert(effects.is_empty() and action.state == "idle")
    var original_appearance: Dictionary = actor.selection.duplicate(true)
    var support_cases: Array = []
    for shirt in ["none", "camiseta_oliva", "camisa_xadrez_vinho", "moletom_cinza", "paleto_carvao"]:
        for boots in ["none", "botas_escuras"]:
            _reset(actor, combat, reaction)
            assert(actor.set_appearance({"shirt_id": shirt, "boots_id": boots}))
            actor.set_motion("down")
            actor.motion_clock = 0
            actor.motion_blend = 1
            actor.advance(0)
            var animation = actor.player.get_animation(actor.clips.down)
            var path = NodePath(str(actor.get_path_to(actor.skeleton)) + ":Root")
            var track = animation.find_track(path, Animation.TYPE_POSITION_3D)
            var expected = animation.position_track_interpolate(track, 0)
            expected.y += actor._floor_offset("down", 0)
            var actual = actor.skeleton.get_bone_pose_position(actor.skeleton.find_bone("Root"))
            assert(actual.distance_to(expected) < .00001)
            support_cases.append({"shirt": shirt, "boots": boots, "root_y_m": actual.y})
    actor.set_appearance(original_appearance)
    _reset(actor, combat, reaction)
    await load(actor.base_dir + "verificar_combate.gd").new().run(actor, action, combat, target)
    assert(actor.arm_blend.maximum_attachment_error < .00001)
    var result = {"cases": cases, "support_appearance_cases": support_cases, "maximum_joint_gap_m": gaps, "maximum_blend_attachment_error_m": actor.arm_blend.maximum_attachment_error, "pause": true, "death_priority": true, "death_during_recovery_continuous": true, "dead_pose_held": true, "attack_interruption_before_after_effect": true, "consumption_interruption": true, "control_exclusion": true}
    FileAccess.open("res://qa/reacoes_runtime.json", FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
    print("R55_REACTIONS_QA_OK ", JSON.stringify(gaps))
