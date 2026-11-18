extends RefCounted

const EVENTS=[[0.0,1,false,false],[1.2,1,true,false],[2.5,1,true,true],[3.6,1,true,false],[4.6,1,false,false],[5.6,0,false,false],[7.2,-1,false,false],[8.6,1,false,false],[10.8,0,false,false]]

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
    var yaw=body.avatar.rotation.y
    var rates=[24] if capture else [30,60,120]
    var reports: Array=[]
    var poses: Array=[]
    for fps in rates:
        body.global_position=start
        body.avatar.rotation.y=yaw
        body.locomotion.cancel()
        body.locomotion.history.clear()
        body.preview_motion=""
        body.avatar.set_motion("idle")
        var event_index=0
        var frames=ceili(13.0*fps)
        var trace: Array=[]
        for frame in frames:
            var time=frame/float(fps)
            while event_index<EVENTS.size() and time>=EVENTS[event_index][0]:
                var event: Array=EVENTS[event_index]
                body.command=Vector2(0,event[1])
                if map_view:
                    body.command=Vector2(.70710678,-.70710678)*event[1]
                body.command_run=event[2]
                body.command_sprint=event[3]
                event_index+=1
            body._physics_process(1.0/fps)
            if not capture and fps==60 and frame%4==0:
                var matrices: Dictionary={}
                var actor: Node3D=body.avatar
                for index in actor.skeleton.get_bone_count():
                    var transform: Transform3D=actor.skeleton.get_bone_global_pose(index)*actor.skeleton.get_bone_global_rest(index).affine_inverse()
                    matrices[actor.skeleton.get_bone_name(index)]=[transform.basis.x.x,transform.basis.y.x,transform.basis.z.x,transform.origin.x,transform.basis.x.y,transform.basis.y.y,transform.basis.z.y,transform.origin.y,transform.basis.x.z,transform.basis.y.z,transform.basis.z.z,transform.origin.z]
                var fits: Dictionary={}
                for name in actor.weights:
                    if str(name).begins_with("Fit_") and actor.weights[name]>.000001:
                        fits[name]=actor.weights[name]
                poses.append({"motion":actor.motion,"time":actor.motion_clock,"bones":matrices,"fits":fits})
            assert(body.global_position.is_finite())
            if capture:
                scene.hud.visible=false
                if map_view:
                    scene.zoom=5.5
                    scene.focus=body.global_position+Vector3.UP*.95
                    scene._update_camera()
                else:
                    scene.camera.size=3.5
                    scene.camera.position=body.global_position+Vector3(-4,2,4)
                    scene.camera.look_at(body.global_position+Vector3.UP*.95)
                await RenderingServer.frame_post_draw
                var folder="res://previews/automatico60"
                DirAccess.make_dir_recursive_absolute(folder)
                scene.get_viewport().get_texture().get_image().save_png(folder+"/%03d.png"%frame)
                trace.append({"time":time,"motion":body.avatar.motion})
        assert(not body.locomotion.blocked)
        assert(body.locomotion.queue.is_empty(),str(body.locomotion.queue))
        assert(body.avatar.motion=="idle",body.avatar.motion)
        var history: Array=body.locomotion.history.duplicate()
        assert(history.any(func(id):return str(id).begins_with("walk_start")),str(history))
        assert(history.any(func(id):return str(id).begins_with("changes")),str(history))
        assert(history.any(func(id):return str(id).contains("stop")),str(history))
        reports.append({"fps":fps,"history":history,"trace":trace})
    var report_path="res://qa/capturas_automatico60.json" if capture else "res://qa/automatico60.json"
    FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
    if not capture:
        await _extra(body,start,map_view)
        FileAccess.open("res://qa/poses_deformacao.json",FileAccess.WRITE).store_string(JSON.stringify(poses))
    print("R60_AUTO_OK ",rates)
    scene.get_tree().quit()

func _extra(body: CharacterBody3D, start: Vector3, map_view: bool) -> void:
    body.global_position=start
    body.command=Vector2(0,1)
    var forward=Vector2(.70710678,-.70710678) if map_view else Vector2(0,1)
    body.command=forward
    body.command_run=false
    body.command_sprint=false
    body._physics_process(.1)
    body.paused=true
    var clock: float=body.locomotion.clock
    body._physics_process(.5)
    assert(body.locomotion.clock==clock)
    body.paused=false
    body.command=Vector2.ZERO
    assert(body.request_use("drink"))
    assert(body.locomotion.queue.is_empty())
    body._physics_process(.01)
    assert(body.avatar.motion_rate==0)
    body.action.cancel()
    assert(body.set_crouch(true))
    body.global_position=start
    body.command=forward
    for frame in 180:
        body._physics_process(1.0/60)
    assert(body.avatar.motion.begins_with("flow_crouch"),body.avatar.motion)
    body.command=Vector2.ZERO
    for frame in 180:
        body._physics_process(1.0/60)
    assert(body.avatar.motion=="crouch_idle",body.avatar.motion)
    assert(body.set_crouch(false))
    assert(body.set_movement_condition("injured_left"))
    body.global_position=start
    body.command=forward
    for frame in 30:
        body._physics_process(1.0/60)
    assert(body.avatar.motion=="limp_left",body.avatar.motion)
    assert(body.set_movement_condition("normal"))
    body.command=forward
    body._physics_process(.1)
    assert(body.request_reaction("hit_front"))
    assert(body.locomotion.queue.is_empty())
    body._physics_process(.01)
    assert(body.avatar.motion_rate==0)
    body.reaction.reset()
    var target=load("res://personagem/alvo_treino.gd").new()
    body.get_parent().add_child(target)
    target.global_position=body.global_position+Vector3(0,0,.8)
    await body.get_tree().physics_frame
    body.combat_target=target
    body.command=forward
    body._physics_process(.1)
    assert(body.request_attack("punch"))
    assert(body.locomotion.queue.is_empty())
    body._physics_process(.01)
    assert(body.avatar.motion_rate==0)
    body.combat.cancel()
    body.combat.set_guard(false)
    target.queue_free()
    await body.get_tree().physics_frame
    body.global_position=start+Vector3(-3,0,0)
    body.velocity=Vector3.ZERO
    body.command=Vector2.ZERO
    body.scripted=false
    var event=InputEventKey.new()
    event.keycode=KEY_W
    event.physical_keycode=KEY_W
    event.pressed=true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    body._physics_process(1.0/60)
    assert(not body.locomotion.queue.is_empty(),str([body.action.state,body.combat.guarding,body.reaction.state,body.movement_condition,body.global_position,body.avatar.motion]))
    event=event.duplicate()
    event.pressed=false
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    body.locomotion.cancel()
    body.scripted=true
    FileAccess.open("res://qa/prioridades60.json",FileAccess.WRITE).store_string(JSON.stringify({"pause":true,"inventory_priority":true,"combat_priority":true,"reaction_priority":true,"crouch":true,"injury":true,"physical_w_key":true}))
