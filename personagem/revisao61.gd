extends RefCounted

func run(scene: Node3D, capture: bool=false, map_view: bool=false) -> void:
    var body: CharacterBody3D=scene.player
    body.scripted=true
    body.set_physics_process(false)
    for fixture in scene.fixtures.values():
        fixture.position.x+=30
    if map_view:
        scene.training_target.position.x+=30
    await scene.get_tree().physics_frame
    var start=body.global_position
    var trace: Array=[]
    var poses: Array=[]
    var original_path: String=body.condition_path
    body.condition_path="user://qa_condition61.json"
    body.set_movement_condition("normal")
    assert(body.save_condition())
    body.condition_state.set_stamina(30)
    assert(body.save_condition())
    body.condition_state.set_injury("L",.7)
    assert(body.load_condition())
    assert(body.condition_state.left_injury==0 and is_equal_approx(body.condition_state.stamina,30))
    var before: Dictionary=body.condition_state.snapshot()
    assert(not body.condition_state.restore({"version":1,"stamina":-1}))
    assert(before==body.condition_state.snapshot())
    body.condition_state.set_stamina(10)
    body.condition_state.set_stamina(30)
    assert(body.condition_state.exhausted)
    assert(body.save_condition())
    body.condition_state.set_stamina(100)
    assert(body.load_condition() and body.condition_state.exhausted)
    body.condition_path=original_path
    var rates=[24] if capture else [30,60,120]
    for fps in rates:
        body.global_position=start
        body.locomotion.cancel()
        body.command=Vector2.ZERO
        body.command_run=false
        body.command_sprint=false
        body.preview_motion=""
        body.set_movement_condition("normal")
        body.condition_state.set_stamina(18)
        for frame in ceili(9.0*fps):
            var time=frame/float(fps)
            body.command=Vector2(.70710678,-.70710678) if map_view else Vector2(0,1)
            body.command_run=true
            body.command_sprint=true
            if time>=1.5:
                body.command=Vector2.ZERO
            if time>=7.8:
                body.condition_state.set_injury("L",.6)
                body.command=(Vector2(.70710678,-.70710678) if map_view else Vector2(0,1))
            if time>=8.6:
                body.command=Vector2.ZERO
            body._physics_process(1.0/fps)
            if not capture and fps==60 and frame%4==0:
                poses.append(_snapshot(body.avatar))
            if time>1 and time<1.45:
                assert(body.condition_state.exhausted)
                assert(body.movement_condition=="tired",body.movement_condition)
            if time>7.2 and time<7.75:
                assert(not body.condition_state.exhausted)
                assert(body.movement_condition=="normal",body.movement_condition)
            if capture:
                scene.hud.visible=false
                if map_view:
                    scene.zoom=5.0
                    scene.focus=body.global_position+Vector3.UP*.95
                    scene._update_camera()
                else:
                    scene.camera.size=3.0
                    scene.camera.position=body.global_position+Vector3(-4,2,4)
                    scene.camera.look_at(body.global_position+Vector3.UP*.95)
                await RenderingServer.frame_post_draw
                DirAccess.make_dir_recursive_absolute("res://previews/condicao61")
                scene.get_viewport().get_texture().get_image().save_png("res://previews/condicao61/%03d.png"%frame)
                trace.append({"time":time,"stamina":body.condition_state.stamina,"condition":body.movement_condition,"motion":body.avatar.motion})
        assert(body.movement_condition=="injured_left")
        body.command=Vector2.ZERO
        body.condition_state.set_injury("L",0)
        body.condition_state.set_stamina(100)
        body._physics_process(1.0/fps)
        assert(body.movement_condition=="normal")
        body.paused=true
        var stamina: float=body.condition_state.stamina
        body._physics_process(1)
        assert(body.condition_state.stamina==stamina)
        body.paused=false
    FileAccess.open("res://qa/condicao61_captura.json" if capture else "res://qa/condicao61_runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"rates":rates,"persistence":true,"hysteresis":true,"invalid_restore_atomic":true,"pause":true,"trace":trace},"  "))
    if not capture:
        FileAccess.open("res://qa/poses_deformacao.json",FileAccess.WRITE).store_string(JSON.stringify(poses))
    print("R61_CONDITION_OK ",rates)
    scene.get_tree().quit()

func _snapshot(actor: Node3D) -> Dictionary:
    var bones: Dictionary={}
    for index in actor.skeleton.get_bone_count():
        var t: Transform3D=actor.skeleton.get_bone_global_pose(index)*actor.skeleton.get_bone_global_rest(index).affine_inverse()
        bones[actor.skeleton.get_bone_name(index)]=[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z]
    var fits: Dictionary={}
    for name in actor.weights:
        if str(name).begins_with("Fit_") and actor.weights[name]>.000001:
            fits[name]=actor.weights[name]
    return {"motion":actor.motion,"time":actor.motion_clock,"bones":bones,"fits":fits}
