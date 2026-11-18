extends "res://personagem/revisao75.gd"
var completions: Array=[]
var max_elbow=0.0
var max_wrist=0.0
var probes: Array=[]
var max_penetration=0.0
var penetration_detail={}
func run(scene: Node3D) -> void:
    var body: CharacterBody3D=scene.player
    var c: RefCounted=body.traversal
    var registry: Node3D=body.map_traversals
    var capture="--capture-traversals" in OS.get_cmdline_user_args()
    scene.get_window().size=Vector2i(1440,900)
    body.scripted=true
    body.set_physics_process(false)
    c.finished.connect(func(id,ok):completions.append({"id":id,"success":ok}))
    var windows=registry.obstacles.filter(func(n):return n.kind=="window")
    var fences=registry.obstacles.filter(func(n):return n.kind=="fence")
    assert(windows.size()==7 and fences.size()>0)
    var window: Node3D=windows[0]
    var fence: Node3D=fences[2]
    var initial=body.map_doors.snapshot()
    var opened=initial.duplicate(true)
    opened.states[window.opening_id]=true
    body.map_doors.apply_restore(opened)
    assert(not c.begin(window,"open_window") and not c.is_active())
    await _place(scene,window,-1)
    var actual_ledge: float=window.ledge_y
    window.ledge_y+=.3
    assert(not body.request_cross(window) and not c.is_active())
    window.ledge_y=actual_ledge
    var stock=body.bag_inventory.snapshot()
    var raw: Array=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/sondas_travessia77.json"))
    for item in raw:
        var weights=[]
        for name in item.w:weights.append([body.avatar.skeleton.find_bone(name),float(item.w[name])])
        probes.append({"point":Vector3(item.p[0],item.p[1],item.p[2]),"weights":weights})
    var cases=[]
    for fps in [30,60,120]:
        for obstacle in [window,fence]:
            for side in [-1,1]:
                await _place(scene,obstacle,side)
                if fps==30 and obstacle==window and side==-1:
                    _key(KEY_B)
                    assert(c.is_active(),"Physical B did not start traversal")
                elif fps==60:assert(body.request_cross(),c.message)
                else:assert(body.request_cross(obstacle),c.message)
                var count=obstacle.effects
                var last=body.global_position
                var crossing={}
                for frame in fps*4:
                    c.advance(1.0/fps)
                    assert(body.global_position.distance_to(last)<.17,"Unexpected root jump")
                    last=body.global_position
                    _joints(body.avatar)
                    for foot_side in ["R","L"]:
                        var rig: Skeleton3D=body.avatar.skeleton
                        var point=obstacle.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("Foot."+foot_side)).origin))
                        if point.z*-side>.10 and not crossing.has(foot_side):crossing[foot_side]=c.cursor
                    if c.is_active() and c.state=="playing" and frame%4==0:_geometry(body,obstacle)
                    if not c.is_active():break
                assert(not c.is_active() and c.effect_succeeded and obstacle.effects==count+1,c.message)
                assert(is_equal_approx(body.capsule.shape.height,1.84) and not body.action.control_locked and not body.combat.control_locked)
                assert(absf(body.global_position.y-obstacle.floor_at(body.global_position).position.y)<.015)
                cases.append({"kind":obstacle.kind,"side":side,"fps":fps,"effect_once":true,"foot_crossing_times":crossing})
    assert(max_penetration<.005,"Mesh probes crossed obstacle profile")
    for case in cases:assert(case.foot_crossing_times.size()==2 and absf(case.foot_crossing_times.R-case.foot_crossing_times.L)>.5)
    assert(max_elbow<.025 and max_wrist<.015,str([max_elbow,max_wrist]))
    # Existing windows with half openings refuse traversal without changing stock or player.
    for obstacle in windows:
        if obstacle.opening.get("mechanism","") not in ["sash","horizontal_slider"]:continue
        var state=opened.duplicate(true);state.states[obstacle.opening_id]=true
        body.map_doors.apply_restore(state)
        await _place(scene,obstacle,1)
        var before=body.global_position
        assert(not body.request_cross(obstacle) and body.global_position==before and not c.is_active())
    body.map_doors.apply_restore(initial)
    await _place(scene,window,1)
    assert(not body.request_cross(window))
    assert(body.request_open(window))
    body.action.advance(10)
    await _settled(scene)
    assert(window.opening.open and not body.request_open(window))
    assert(body.map_doors.request(window.opening_id))
    body.action.advance(10)
    await _settled(scene)
    _key(KEY_E)
    assert(body.map_doors.pending==window.opening_id)
    body.action.advance(10)
    await _settled(scene)
    assert(window.opening.open)
    await _place(scene,window,-1)
    # Occupied landing is rejected by the same physical preflight, without effect.
    var blocker=_blocker(scene,window.base_center+window.normal*.95+Vector3.UP*.8)
    blocker.get_child(0).shape.size=Vector3(.6,1.6,.6)
    await scene.get_tree().physics_frame
    var effects=window.effects
    assert(not body.request_cross(window) and window.effects==effects)
    blocker.queue_free()
    await scene.get_tree().physics_frame
    await _place(scene,window,-1)
    assert(body.request_cross(window))
    c.advance(.1)
    assert(c.cancel())
    c.advance(2)
    assert(not c.is_active() and window.effects==effects)
    await _place(scene,window,-1)
    assert(body.request_cross(window))
    c.advance(.7)
    var middle: Dictionary=c.path.sample("vault_window",2.0)
    blocker=_blocker(scene,c._position(2.0)+c._volume(middle).origin)
    await scene.get_tree().physics_frame
    c.advance(8)
    assert(not c.is_active() and not c.effect_succeeded and window.effects==effects,"Mid-course obstruction did not return safely")
    blocker.queue_free()
    await scene.get_tree().physics_frame
    await _place(scene,window,-1)
    assert(body.request_cross(window))
    c.advance(.65)
    body.paused=true
    var cursor: float=c.cursor
    var point=body.global_position
    c.advance(2)
    assert(c.cursor==cursor and body.global_position==point)
    assert(not body.save_condition() and not body.map_doors.request(window.opening_id))
    body.paused=false
    c.advance(8)
    assert(c.effect_succeeded)
    assert(body.bag_inventory.snapshot()==stock)
    await _place(scene,window,-1)
    var original_clip: String=body.avatar.clips.vault_window
    assert(body.request_cross(window))
    c.advance(.05)
    c.reset_test()
    assert(not c.is_active() and body.avatar.clips.vault_window==original_clip)
    if capture:
        scene.set_process(false)
        for index in 4:
            var obstacle: Node3D=window if index<2 else fence
            var side=-1 if index%2==0 else 1
            await _place(scene,obstacle,side)
            assert(body.request_cross(obstacle),c.message)
            var target: Vector3=c.anchor+Vector3.UP*1.05
            scene.camera.size=3.4 if index<2 else 4.2
            var view_side=1 if index<2 else side
            scene.camera.global_position=target+(obstacle.normal*view_side-obstacle.normal.cross(Vector3.UP)*.65+Vector3.UP*.65)*9
            scene.camera.look_at(target)
            print("CAPTURE77 ",index," target=",target," player=",body.global_position," anchor=",c.anchor)
            for frame in 62:
                c.advance(.05)
                if frame==25:print("CAPTURE77_MID ",index," player=",body.global_position," anchor=",c.anchor)
                await _capture(scene,"cycle%d/%02d"%[index,frame])
            assert(not c.is_active() and c.effect_succeeded)
        scene.set_process(true)
    var result={"windows_registered":windows.size(),"fences_registered":fences.size(),"cases":cases,"both_directions":true,"partial_apertures_rejected":true,"closed_window_rejected":true,"occupied_landing_rejected":true,"physical_b_and_e":true,"generic_obstacle_api":true,"wrong_support_height_rejected":true,"reset_restores_original_clip":true,"midcourse_block_returns":true,"cancel_alignment":true,"pause":true,"save_and_close_blocked_during_crossing":true,"inventory_unchanged":true,"max_elbow_gap_m":max_elbow,"max_wrist_gap_m":max_wrist,"probe_max_penetration_m":max_penetration,"probe_detail":penetration_detail}
    FileAccess.open("res://qa/traversals77.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R77_TRAVERSALS_OK ",result)
    body.map_doors.apply_restore(initial)
    scene.get_tree().quit()
func _place(scene: Node3D, obstacle: Node3D, side: int) -> void:
    var body: CharacterBody3D=scene.player
    if obstacle.kind=="fence":obstacle.base_center=(obstacle.a+obstacle.b)/2
    body.global_position=obstacle.base_center+obstacle.normal*side*.85
    var floor=obstacle.floor_at(body.global_position)
    assert(not floor.is_empty())
    body.global_position.y=floor.position.y+.003
    body.avatar.rotation.y=atan2(-obstacle.normal.x*side,-obstacle.normal.z*side)
    body.velocity=Vector3.ZERO
    completions.clear()
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
func _joints(actor: Node3D) -> void:
    for side in ["L","R"]:
        var values: Dictionary=actor.arm_articulation.joints[side]
        var elbow=Vector3(values.elbow[0],values.elbow[1],values.elbow[2])
        var wrist=Vector3(values.wrist[0],values.wrist[1],values.wrist[2])
        var upper: Transform3D=actor.arm_articulation._skin("UpperArm."+side)
        var forearm: Transform3D=actor.arm_articulation._skin("Forearm."+side)
        var hand: Transform3D=actor.arm_articulation._skin("Hand."+side)
        max_elbow=maxf(max_elbow,(upper*elbow).distance_to(forearm*elbow))
        max_wrist=maxf(max_wrist,(forearm*wrist).distance_to(hand*wrist))
func _geometry(body: CharacterBody3D, obstacle: Node3D) -> void:
    var rig: Skeleton3D=body.avatar.skeleton
    var transforms=[]
    for index in rig.get_bone_count():transforms.append(obstacle.global_transform.affine_inverse()*rig.global_transform*rig.get_bone_global_pose(index)*rig.get_bone_global_rest(index).affine_inverse())
    var sill=.8+obstacle.rise
    for probe in probes:
        var point=Vector3.ZERO
        for weight in probe.weights:point+=transforms[weight[0]]*probe.point*weight[1]
        if absf(point.z)>.12 or absf(point.x)>.59:continue
        var penetration=maxf(0,sill-point.y)
        if penetration>max_penetration:
            max_penetration=penetration
            penetration_detail={"time":body.traversal.cursor,"point":str(point),"variant":obstacle.variant,"weights":str(probe.weights.map(func(w):return [rig.get_bone_name(w[0]),w[1]])),"source":str(probe.point)}
func _capture(scene: Node3D, name: String) -> void:
    for frame in 2:await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/traversals77/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
