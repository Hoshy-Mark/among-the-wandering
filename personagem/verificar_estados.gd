extends RefCounted


func run(body: CharacterBody3D, origin: Vector3) -> void:
    body.scripted = true
    body.set_physics_process(false)
    var samples: Array = []
    var cases = [["normal",false,"walk"],["normal",true,"run"],["injured_left",false,"limp_left"],["injured_left",true,"limp_left"],["injured_right",false,"limp_right"],["injured_right",true,"limp_right"],["tired",false,"tired_walk"],["tired",true,"tired_run"]]
    for entry in cases:
        body.traversal.reset_test()
        body.reaction.reset()
        body.combat.set_guard(false)
        body.action.cancel()
        body.paused = false
        body.global_position = origin
        body.velocity = Vector3.ZERO
        assert(body.set_movement_condition(entry[0]))
        body.command = Vector2(0,1)
        body.command_run = entry[1]
        body.set_physics_process(true)
        for frame in 24:
            await body.get_tree().physics_frame
        assert(body.avatar.motion == entry[2],str([entry,body.avatar.motion]))
        var expected: float = body._movement_speed(entry[1],false)
        var speed = Vector2(body.velocity.x,body.velocity.z).length()
        assert(absf(speed-expected)<.05,str([entry,speed,expected]))
        body.paused = true
        await body.get_tree().physics_frame
        var clock: float = body.avatar.motion_clock
        for frame in 6:
            await body.get_tree().physics_frame
        assert(is_equal_approx(body.avatar.motion_clock,clock))
        body.paused = false
        body.command = Vector2.ZERO
        for frame in 30:
            await body.get_tree().physics_frame
        var idle = "injured_idle" if entry[0].begins_with("injured") else "tired_idle" if entry[0]=="tired" else "idle"
        assert(body.avatar.motion == idle,str([entry,body.avatar.motion]))
        body.set_physics_process(false)
        samples.append({"condition":entry[0],"running_requested":entry[1],"motion":entry[2],"speed_m_s":speed,"idle":idle})
    assert(not body.set_movement_condition("invalid"))
    assert(body.set_movement_condition("normal"))
    assert(body.set_crouch(true))
    assert(body._movement_motion(true,true)=="crouch")
    assert(body.set_crouch(false))
    body.global_position=origin
    assert(body.request_use("drink"))
    assert(not body.set_movement_condition("tired"))
    body.action.cancel()
    assert(body.set_movement_condition("normal"))
    body.command=Vector2.ZERO
    body.command_run=false
    FileAccess.open("res://qa/estados_runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":samples,"pause":true,"invalid_rejected":true,"actions_exclude_state_change":true,"crouch_preserved":true},"  "))
    print("R58_STATES_QA_OK")


func run_speed(body: CharacterBody3D, fixtures: Dictionary) -> void:
    var cases: Array = []
    body.set_physics_process(false)
    var setup = load("res://personagem/verificar_obstaculos.gd").new()
    for fps in [30,60,120]:
        for id in ["open_window","vault_fence","vault_window"]:
            var fixture: Node3D = fixtures.fence if id == "vault_fence" else fixtures.window
            await setup.place(body,fixture)
            if id == "vault_window":
                assert(body.request_open(fixture))
                body.traversal.advance(3)
                await body.get_tree().physics_frame
            assert(body.request_open(fixture) if id=="open_window" else body.request_cross(fixture))
            var elapsed = 0.0
            while body.traversal.is_active() and elapsed<5:
                body.traversal.advance(1.0/fps)
                elapsed += 1.0/fps
            var authored: float = body.traversal.definitions.actions[id].duration
            var expected: float = .25+body.avatar.motion_transition_duration+authored/body.traversal.playback_rate
            assert(not body.traversal.is_active() and body.traversal.effect_succeeded)
            assert(absf(elapsed-expected)<.06,str([id,fps,elapsed,expected]))
            assert(fixture.effects[id]==1)
            cases.append({"action":id,"fps":fps,"authored_duration_s":authored,"playback_duration_s":authored/body.traversal.playback_rate,"total_elapsed_s":elapsed})
    FileAccess.open("res://qa/velocidade_travessias.json",FileAccess.WRITE).store_string(JSON.stringify({"rate":body.traversal.playback_rate,"cases":cases},"  "))
    print("R58_SPEED_QA_OK")
