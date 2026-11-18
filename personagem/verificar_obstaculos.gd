extends RefCounted

var completions: Array = []


func place(body: CharacterBody3D, fixture: Node3D, side: int = 1) -> void:
    body.traversal.reset_test()
    body.reaction.reset()
    body.paused = false
    body.avatar.motion_paused = false
    fixture.reset_test()
    body.global_position = fixture.global_position + fixture.global_basis * Vector3(0, .003, -.85 * side)
    body.avatar.rotation.y = fixture.global_rotation.y + (PI if side < 0 else 0)
    body.velocity = Vector3.ZERO
    completions.clear()
    await body.get_tree().physics_frame


func run(body: CharacterBody3D, fixtures: Dictionary) -> void:
    var controller: RefCounted = body.traversal
    controller.finished.connect(func(id: String, succeeded: bool): completions.append({"action": id, "success": succeeded}))
    var cases: Array = []
    var max_elbow = 0.0
    var max_wrist = 0.0
    for fps in [30, 60, 120]:
        for id in ["open_window", "vault_fence", "vault_window"]:
            var fixture: Node3D = fixtures.fence if id == "vault_fence" else fixtures.window
            await place(body, fixture)
            if id == "vault_window":
                assert(body.request_open(fixture), "opening precondition " + controller.message)
                controller.advance(6)
                assert(fixture.opened)
                completions.clear()
                await body.get_tree().physics_frame
            assert(body.request_open(fixture) if id == "open_window" else body.request_cross(fixture), id + " " + controller.message)
            assert(not body.request_use("drink") and not body.request_reaction("hit_front"))
            var duration: float = controller.definitions.actions[id].duration + 1
            for frame in ceili(duration * fps):
                controller.advance(1.0 / fps)
                var actor: Node3D = body.avatar
                for side in ["L", "R"]:
                    var values: Dictionary = actor.arm_articulation.joints[side]
                    var elbow = Vector3(values.elbow[0], values.elbow[1], values.elbow[2])
                    var wrist = Vector3(values.wrist[0], values.wrist[1], values.wrist[2])
                    var upper: Transform3D = actor.arm_articulation._skin("UpperArm." + side)
                    var forearm: Transform3D = actor.arm_articulation._skin("Forearm." + side)
                    var hand: Transform3D = actor.arm_articulation._skin("Hand." + side)
                    max_elbow = maxf(max_elbow, (upper * elbow).distance_to(forearm * elbow))
                    max_wrist = maxf(max_wrist, (forearm * wrist).distance_to(hand * wrist))
            assert(controller.state == "idle", id + " stopped in " + controller.state + " " + controller.message)
            assert(controller.effect_succeeded, id + " effect failed " + str(completions))
            assert(fixture.effects[id] == 1)
            assert(completions.size() == 1 and completions[0].success)
            assert(not body.action.control_locked and not body.combat.control_locked)
            assert(is_equal_approx(body.capsule.shape.height, 1.84))
            if id != "open_window":
                var local: Vector3 = fixture.to_local(body.global_position)
                assert(absf(local.z - .95) < .015 and absf(local.x) < .01)
            cases.append({"action": id, "fps": fps, "effect_once": true})
    assert(max_elbow < .025 and max_wrist < .015)
    await place(body, fixtures.window)
    assert(not body.request_cross(fixtures.window) and fixtures.window.effects.vault_window == 0)
    assert(body.request_open(fixtures.window))
    controller.advance(.90)
    assert(fixtures.window.fraction > .01)
    body.paused = true
    var cursor: float = controller.cursor
    var fraction: float = fixtures.window.fraction
    controller.advance(6)
    assert(controller.cursor == cursor and fixtures.window.fraction == fraction)
    body.paused = false
    assert(controller.cancel())
    controller.advance(2)
    assert(controller.state == "idle" and not fixtures.window.opened and fixtures.window.fraction == 0)
    assert(fixtures.window.effects.open_window == 0)
    await place(body, fixtures.fence)
    assert(body.request_cross(fixtures.fence))
    controller.advance(.65)
    assert(controller.cancel())
    controller.advance(6)
    assert(controller.state == "idle" and fixtures.fence.effects.vault_fence == 0)
    await place(body, fixtures.fence, -1)
    assert(body.request_cross(fixtures.fence))
    controller.advance(6)
    assert(controller.effect_succeeded)
    assert(fixtures.fence.to_local(body.global_position).z < -.94)
    await place(body, fixtures.window)
    assert(body.request_open(fixtures.window))
    controller.advance(6)
    body.global_position = fixtures.window.global_position + fixtures.window.global_basis * Vector3(0, .003, .85)
    body.avatar.rotation.y = fixtures.window.global_rotation.y + PI
    await body.get_tree().physics_frame
    assert(body.request_cross(fixtures.window))
    controller.advance(6)
    assert(controller.effect_succeeded and fixtures.window.to_local(body.global_position).z < -.94)
    await place(body, fixtures.fence)
    var blocker = StaticBody3D.new()
    var collision = CollisionShape3D.new()
    var box = BoxShape3D.new()
    box.size = Vector3(1.0, 2.5, .40)
    collision.shape = box
    blocker.add_child(collision)
    body.get_parent().add_child(blocker)
    blocker.global_position = fixtures.fence.global_position + fixtures.fence.global_basis * Vector3(0, 1.25, .95)
    await body.get_tree().physics_frame
    assert(not body.request_cross(fixtures.fence))
    blocker.queue_free()
    await body.get_tree().physics_frame
    await body.get_tree().physics_frame
    await place(body, fixtures.window)
    var leaf_blocker = StaticBody3D.new()
    var leaf_collision = CollisionShape3D.new()
    var leaf_shape = BoxShape3D.new()
    leaf_shape.size = Vector3(.15, .30, .15)
    leaf_collision.shape = leaf_shape
    leaf_blocker.add_child(leaf_collision)
    body.get_parent().add_child(leaf_blocker)
    leaf_blocker.global_position = fixtures.window.to_global(Vector3(.15, 2.10, .0))
    await body.get_tree().physics_frame
    assert(not body.request_open(fixtures.window))
    assert(not fixtures.window.opened and fixtures.window.effects.open_window == 0)
    leaf_blocker.queue_free()
    await body.get_tree().physics_frame
    await body.get_tree().physics_frame
    await place(body, fixtures.fence)
    var other = Node3D.new()
    body.get_parent().add_child(other)
    var token: int = fixtures.fence.reserve(other)
    assert(token > 0 and not body.request_cross(fixtures.fence))
    fixtures.fence.release(other, token)
    other.queue_free()
    var disappearing = load("res://personagem/obstaculo_teste.gd").new()
    disappearing.kind = "fence"
    body.get_parent().add_child(disappearing)
    disappearing.global_transform = fixtures.fence.global_transform
    await body.get_tree().physics_frame
    assert(body.request_cross(disappearing))
    controller.advance(1.05)
    disappearing.queue_free()
    await body.get_tree().physics_frame
    await body.get_tree().physics_frame
    controller.advance(6)
    assert(controller.state == "idle" and not controller.effect_succeeded)
    var result = {"cases": cases, "maximum_joint_gap_m": {"elbow": max_elbow, "wrist": max_wrist}, "closed_window_rejected": true, "pause": true, "opening_rollback": true, "cancel_before_takeoff": true, "both_obstacles_bidirectional": true, "blocked_landing": true, "blocked_leaf_sweep": true, "reservation_exclusion": true, "freed_target_safe_landing": true, "control_exclusion": true}
    FileAccess.open("res://qa/obstaculos_runtime.json", FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
    print("R57_OBSTACLES_QA_OK")
