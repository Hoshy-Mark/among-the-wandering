extends RefCounted

func run(scene: Node3D, capture: bool=false, map_view: bool=false) -> void:
    var body: CharacterBody3D=scene.player
    body.scripted=true
    body.set_physics_process(false)
    body.command=Vector2.ZERO
    body.command_run=false
    body.command_sprint=false
    for fixture in scene.fixtures.values():
        fixture.position.x+=30
    if map_view:
        scene.training_target.position.x+=30
    await scene.get_tree().physics_frame
    var fresh=load("res://personagem/ferimentos62.gd").new().snapshot()
    var original_path: String=body.condition_path
    body.condition_path="user://qa_condition62.json"
    var trace: Array=[]
    var cases: Array=[]
    var rates=[24] if capture else [30,60,120]
    for fps in rates:
        body.action.cancel()
        body.reaction.reset()
        body.condition_state.restore(fresh)
        body.supplies.refill()
        assert(body.receive_damage("forearm","forearm_left",.45))
        assert(not body.receive_damage("forearm","forearm_left",.45))
        assert(is_equal_approx(body.condition_state.forearm_injury,.45))
        body.reaction.advance(2)
        assert(body.request_use("bandage"))
        if not capture:
            body.action.advance(.1)
            body.action.cancel()
            assert(body.supplies.stock.bandage==3 and not body.condition_state.forearm_dressed)
            assert(body.request_use("bandage"))
        for frame in ceili(6.0*fps):
            var time=frame/float(fps)
            body.command=(Vector2(.70710678,-.70710678) if map_view else Vector2(0,1)) if time>=4.8 and time<5.5 else Vector2.ZERO
            body._physics_process(1.0/fps)
            if body.condition_state.forearm_dressed:
                var rig: Skeleton3D=body.avatar.skeleton
                var expected=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("Forearm.L"))*Transform3D(Basis.from_scale(Vector3(1.4,1,.97)),body.action.props.forearm_center)
                assert(expected.origin.distance_to(body.action.props.dressing.global_position)<.0002,str(expected.origin.distance_to(body.action.props.dressing.global_position)))
            if capture:
                scene.hud.visible=false
                if map_view:
                    scene.zoom=4.5
                    scene.focus=body.global_position+Vector3.UP*.95
                    scene._update_camera()
                else:
                    scene.camera.size=2.7
                    scene.camera.position=body.global_position+Vector3(-4,1.5,4)
                    scene.camera.look_at(body.global_position+Vector3.UP*.95)
                await RenderingServer.frame_post_draw
                DirAccess.make_dir_recursive_absolute("res://previews/curativo62")
                scene.get_viewport().get_texture().get_image().save_png("res://previews/curativo62/%03d.png"%frame)
                trace.append({"time":frame/float(fps),"stock":body.supplies.stock.bandage,"dressed":body.condition_state.forearm_dressed,"motion":body.avatar.motion})
        assert(body.condition_state.forearm_dressed and body.supplies.stock.bandage==2)
        assert(body.action.props.dressing.visible)
        assert(is_equal_approx(body.condition_state.forearm_injury,.45))
        assert(not body.request_use("bandage"))
        assert(body.save_condition())
        assert(body.receive_damage("new_hit","forearm_left",.2))
        assert(not body.condition_state.forearm_dressed)
        body.reaction.advance(2)
        assert(body.load_condition(),str([body.condition_message,body.reaction.state,body.action.state,body.combat.guarding,FileAccess.get_file_as_string(body.condition_path)]))
        assert(body.condition_state.forearm_dressed)
        assert(not body.receive_damage("forearm","forearm_left",.45))
        var before: Dictionary=body.condition_state.snapshot()
        var invalid=before.duplicate(true)
        invalid.forearm_revision=-1
        assert(not body.condition_state.restore(invalid))
        assert(before==body.condition_state.snapshot())
        if not capture:
            body.condition_state.restore(fresh)
            body.supplies.refill()
            assert(body.receive_damage("cancel_hit","forearm_left",.3))
            body.reaction.advance(2)
            assert(body.request_use("bandage"))
            body.action.advance(.2)
            assert(body.receive_damage("interrupt","forearm_left",.2))
            body.reaction.advance(2)
            body.action.advance(10)
            assert(body.supplies.stock.bandage==3 and not body.condition_state.forearm_dressed)
            assert(body.request_use("bandage"))
            body.action.advance(.2)
            assert(body.condition_state.receive_damage("late_update","forearm_left",.1))
            body.action.advance(10)
            assert(body.supplies.stock.bandage==3 and not body.condition_state.forearm_dressed)
            assert(body.request_use("bandage"))
            var duration: float=body.avatar.player.get_animation(body.avatar.clips.bandage).length
            body.action.advance(body.avatar.motion_transition_duration+duration*.65)
            assert(body.condition_state.forearm_dressed and body.supplies.stock.bandage==2)
            body.action.cancel()
            assert(body.condition_state.forearm_dressed and body.supplies.stock.bandage==2)
            assert(body.receive_damage("leg","leg_right",.6))
            body.reaction.advance(2)
            body._physics_process(.1)
            assert(body.movement_condition=="injured_right",body.movement_condition)
            var old=load("res://personagem/condicao61.gd").new().snapshot()
            assert(body.condition_state.restore(old))
            assert(body.condition_state.forearm_injury==0 and not body.condition_state.forearm_dressed)
            var file=FileAccess.open(body.condition_path,FileAccess.WRITE)
            file.store_string(JSON.stringify(old))
            file.close()
            assert(body.load_condition())
            assert(body.condition_state.snapshot().version==2)
        var result={"fps":fps,"effect_once":true,"persistence":true}
        if not capture:
            result.merge({"cancel_preserves_stock":true,"damage_interrupts":true,"migration_v1":true})
        cases.append(result)
    body.condition_path=original_path
    FileAccess.open("res://qa/curativo62_captura.json" if capture else "res://qa/curativo62_runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"trace":trace},"  "))
    print("R62_WOUNDS_OK ",rates)
    scene.get_tree().quit()
