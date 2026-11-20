extends "res://personagem/revisao78.gd"
var routes=[]
var window_refusals=[]
func _place83(scene: Node3D,z: CharacterBody3D,obstacle: Node3D,side: int) -> void:
    if z.crossing.is_active():z.crossing.reset_test()
    z.restore(scene.zombie_world.initial[z.identity])
    if obstacle.kind=="fence":obstacle.base_center=(obstacle.a+obstacle.b)/2;obstacle.normal=(obstacle.b-obstacle.a).normalized().cross(Vector3.UP)
    var point: Vector3=obstacle.base_center+obstacle.normal*side*.85
    var query=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.55,point-Vector3.UP*.8,1)
    var floor=scene.get_world_3d().direct_space_state.intersect_ray(query)
    assert(not floor.is_empty(),obstacle.opening_id)
    point.y=floor.position.y+.003
    z.global_position=point;z.avatar.rotation.y=atan2(-obstacle.normal.x*side,-obstacle.normal.z*side)
    z.velocity=Vector3.ZERO;z.state="search";z.memory=4
    z.last_known=obstacle.base_center-obstacle.normal*side*2.5;z.cross_delay=0
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
func _geometry83(z: CharacterBody3D,obstacle: Node3D) -> void:
    var rig: Skeleton3D=z.avatar.skeleton
    var transforms=[]
    for index in rig.get_bone_count():transforms.append(obstacle.global_transform.affine_inverse()*rig.global_transform*rig.get_bone_global_pose(index)*rig.get_bone_global_rest(index).affine_inverse())
    var top=obstacle.ledge_y-obstacle.global_position.y
    var half=.12
    if obstacle.has_meta("fence78"):half=float(obstacle.model.thickness)/2+(.0175 if obstacle.model.id=="reboco" else 0)
    for probe in probes:
        var point=Vector3.ZERO
        for weight in probe.weights:point+=transforms[weight[0]]*probe.point*weight[1]
        if absf(point.z)>half or absf(point.x)>.59:continue
        var penetration=maxf(0,top-point.y)
        if penetration>max_penetration:
            max_penetration=penetration;penetration_detail={"time":z.crossing.cursor,"point":str(point),"obstacle":obstacle.opening_id}
func run(scene: Node3D) -> void:
    var world=scene.zombie_world;var p=scene.player
    assert(world.actors.size()==2)
    for actor in world.actors.values():actor.ai_enabled=false
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    scene.get_window().size=Vector2i(1440,900)
    p.condition_path="user://qa_zombie_traversals83.json"
    if "--zombie-cross-reopen" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/zombie_traversals83_expected.json"))
        assert(load("res://personagem/revisao81.gd").new()._same(p.session_save.snapshot(),expected))
        print("R83_FRESH_PROCESS_OK");scene.get_tree().quit();return
    var z=world.actors.values()[0];var other=world.actors.values()[1]
    p.global_position=Vector3(1000,.02,1000);other.global_position=Vector3(1003,.02,1000)
    var opened=p.map_doors.snapshot()
    for key in opened.states:opened.states[key]=true
    p.map_doors.apply_restore(opened)
    for frame in 2:await scene.get_tree().physics_frame
    var fences=scene.get_node("Cercamentos78")
    for model in fences.models:
        if model.high:continue
        var found: Node3D
        for obstacle in fences.obstacles:
            if obstacle.model.id!=model.id:continue
            await _place83(scene,z,obstacle,-1)
            if z.request_cross(obstacle):
                z.crossing.advance(8)
                if z.crossing_result.get("success",false):found=obstacle;break
        assert(found!=null,"No NPC route for "+model.id)
        routes.append(found)
    for obstacle in p.map_traversals.obstacles:
        if obstacle.kind!="window" or obstacle.opening.get("mechanism","") not in ["awning","casement_pair"]:continue
        await _place83(scene,z,obstacle,-1)
        var accepted=z.request_cross(obstacle)
        print("WINDOW83 ",obstacle.opening_id," ",accepted," ",z.crossing.message)
        if not accepted:
            window_refusals.append({"id":obstacle.opening_id,"reason":z.crossing.message})
            continue
        z.crossing.advance(8)
        assert(z.crossing_result.get("success",false),z.crossing.message)
        routes.append(obstacle)
    print("ROUTES83 ",routes.size())
    var raw=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/sondas_travessia77.json"))
    for item in raw:
        var weights=[]
        for name in item.w:weights.append([z.avatar.skeleton.find_bone(name),float(item.w[name])])
        probes.append({"point":Vector3(item.p[0],item.p[1],item.p[2]),"weights":weights})
    var cases=[]
    for fps in [30,60,120]:
        for obstacle in routes:
            for side in [-1,1]:
                await _place83(scene,z,obstacle,side)
                var count=obstacle.effects
                assert(z.request_cross(obstacle),z.crossing.message)
                var last=z.global_position;var feet={}
                for frame in fps*6:
                    z.crossing.advance(1.0/fps)
                    assert(z.global_position.distance_to(last)<.17,"Unexpected NPC root jump")
                    last=z.global_position
                    _joints(z.avatar)
                    for foot in ["R","L"]:
                        var rig: Skeleton3D=z.avatar.skeleton
                        var point=obstacle.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("Foot."+foot)).origin))
                        if point.z*-side>.10 and not feet.has(foot):feet[foot]=z.crossing.cursor
                    if fps==60 and frame%4==0 and z.crossing.state=="playing":_geometry83(z,obstacle)
                    if not z.crossing.is_active():break
                assert(not z.crossing.is_active() and z.crossing_result.get("success",false),z.crossing.message)
                assert(obstacle.effects==count+1 and is_equal_approx(z.capsule.shape.height,1.84))
                assert(feet.size()==2 and absf(feet.R-feet.L)>.5,str(feet))
                cases.append({"obstacle":obstacle.opening_id,"kind":obstacle.kind,"fps":fps,"side":side,"foot_times":feet})
        print("FPS83_OK ",fps)
    print("GEOMETRY83 ",max_elbow," ",max_wrist," ",max_penetration," ",penetration_detail)
    assert(max_elbow<.025 and max_wrist<.015 and max_penetration<.005)
    var low=routes[0];var window=routes[-1]
    assert(routes.size()==5 and window.kind=="window")
    # High obstacles and half-open apertures do not start an NPC crossing.
    var denied_high=[];var denied_windows=[]
    for model in fences.models:
        if not model.high:continue
        for obstacle in fences.obstacles:
            if obstacle.model.id!=model.id:continue
            for side in [-1,1]:
                await _place83(scene,z,obstacle,side)
                var point=z.global_position;var count=obstacle.effects
                assert(not z.request_cross(obstacle) and z.global_position==point and obstacle.effects==count and not z.crossing.is_active())
            denied_high.append(model.id);break
    for obstacle in p.map_traversals.obstacles:
        if obstacle.kind!="window" or obstacle.opening.get("mechanism","") in ["awning","casement_pair"]:continue
        await _place83(scene,z,obstacle,-1)
        var point=z.global_position
        assert(not z.request_cross(obstacle) and point==z.global_position)
        denied_windows.append(obstacle.opening_id)
    var closed=opened.duplicate(true);closed.states[window.opening_id]=false
    p.map_doors.apply_restore(closed)
    for frame in 2:await scene.get_tree().physics_frame
    await _place83(scene,z,window,-1)
    assert(not z.request_cross(window))
    p.map_doors.apply_restore(opened)
    for frame in 2:await scene.get_tree().physics_frame
    # Reservation is shared with another NPC, the player and the opening controller.
    await _place83(scene,z,window,-1)
    assert(z.request_cross(window))
    assert(window.reserve(p)<0 and not other.request_cross(window))
    assert(not p.map_doors.request(window.opening_id) and scene.game_ui.feedback.text.contains("passagem"))
    assert(not p.save_condition() and not p.load_condition())
    z.crossing.advance(.7)
    p.paused=true
    var frozen_cursor=z.crossing.cursor;var frozen_point=z.global_position
    z.crossing.advance(1)
    assert(z.crossing.cursor==frozen_cursor and z.global_position==frozen_point)
    p.paused=false
    z.crossing.reset_test()
    assert(window.owner_ref==null)
    # A player/body on the landing prevents any move or reservation.
    await _place83(scene,z,window,-1)
    var point=window.base_center+window.normal*.95
    var floor_query=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.55,point-Vector3.UP*.8,1)
    point.y=scene.get_world_3d().direct_space_state.intersect_ray(floor_query).position.y+.8
    var blocker=_blocker(scene,point);blocker.get_child(0).shape.size=Vector3(.6,1.6,.6)
    for frame in 2:await scene.get_tree().physics_frame
    var before=z.global_position;var effects=window.effects
    assert(not z.request_cross(window) and z.global_position==before and window.effects==effects and window.owner_ref==null)
    blocker.queue_free()
    for frame in 2:await scene.get_tree().physics_frame
    # A newly blocked landing produces a physical retreat, without committing.
    await _place83(scene,z,low,-1)
    assert(z.request_cross(low))
    var entry=z.crossing._position(0)
    z.crossing.advance(.9)
    point=z.crossing._position(z.crossing.definitions.actions.vault_fence.duration)+Vector3.UP*.8
    blocker=_blocker(scene,point);blocker.get_child(0).shape.size=Vector3(.6,1.6,.6)
    for frame in 2:await scene.get_tree().physics_frame
    effects=low.effects
    z.crossing.advance(6)
    assert(not z.crossing.is_active() and not z.crossing_result.success and low.effects==effects and z.global_position.distance_to(entry)<.02)
    blocker.queue_free()
    for frame in 2:await scene.get_tree().physics_frame
    # A hit before takeoff cancels; a lethal hit in the air waits for safe landing.
    await _place83(scene,z,low,-1)
    assert(z.request_cross(low));z.crossing.advance(.1)
    assert(z.receive_combat_hit({"id":"early83","action":"push","amount":.06,"source_position":z.global_position+low.normal}))
    assert(not z.crossing.is_active() and z.state=="hit" and low.owner_ref==null)
    await _place83(scene,z,low,-1)
    assert(z.request_cross(low));z.crossing.advance(1.3)
    assert(z.crossing.cursor>z.crossing.definitions.actions.vault_fence.takeoff)
    var attacks=z.attacks
    assert(z.receive_combat_hit({"id":"late83","action":"punch","amount":1.0,"source_position":z.global_position+low.normal}))
    assert(z.crossing.is_active() and z.state=="crossing" and z.deferred_state=="dying")
    z.crossing.advance(6)
    assert(not z.crossing.is_active() and z.state=="dying" and z.attacks==attacks and low.owner_ref==null)
    z.step(1.8)
    for frame in 2:await scene.get_tree().physics_frame
    assert(z.state=="dead" and z.capsule.disabled)
    # The real AI selects the route, completes it and continues after the obstacle.
    var automatic=[]
    for obstacle in [low,window]:
        await _place83(scene,z,obstacle,-1)
        point=obstacle.base_center+obstacle.normal*1.7
        floor_query=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.55,point-Vector3.UP*.8,1)
        point.y=scene.get_world_3d().direct_space_state.intersect_ray(floor_query).position.y+.003
        p.global_position=point;z.last_known=point;z.memory=4;z.state="chase";z.ai_enabled=true
        for frame in 420:
            await scene.get_tree().physics_frame
            if z.crossing_result.get("success",false):break
        z.ai_enabled=false
        assert(z.crossing_result.get("success",false),"Automatic route failed "+obstacle.opening_id)
        assert((z.global_position-obstacle.base_center).dot(obstacle.normal)>.7)
        automatic.append(obstacle.opening_id)
        p.global_position=Vector3(1000,.02,1000)
    # Save only the settled result; loading during traversal was refused above.
    p.global_position=scene.spawn;p.velocity=Vector3.ZERO;p.action.cancel();p.reaction.reset();p.map_combat.pending_reaction="";p.combat.set_guard(false)
    other.restore(world.initial[other.identity])
    assert(other.receive_combat_hit({"id":"corpse83","action":"punch","amount":1.0,"source_position":other.global_position+Vector3.BACK}))
    other.step(1.8)
    for frame in 2:await scene.get_tree().physics_frame
    assert(p.save_condition(),p.inventory_message+" "+p.session_save.reason)
    var saved=p.session_save.snapshot()
    z.restore(world.initial[z.identity]);other.restore(world.initial[other.identity])
    assert(p.load_condition(),p.inventory_message)
    assert(load("res://personagem/revisao81.gd").new()._same(saved,p.session_save.snapshot()))
    FileAccess.open("res://qa/zombie_traversals83_expected.json",FileAccess.WRITE).store_string(JSON.stringify(saved,"",true,true))
    var checks={"cases":cases,"max_elbow":max_elbow,"max_wrist":max_wrist,"max_penetration":max_penetration,"window_refusals":window_refusals,"high_refused":denied_high,"half_apertures_refused":denied_windows,"closed_window_refused":true,"shared_reservation":true,"window_locked_while_crossing":true,"busy_save_refused":true,"pause_freezes_crossing":true,"occupied_landing_refused":true,"dynamic_block_retreat":true,"early_hit_cancel":true,"late_death_deferred":true,"no_attack_while_crossing":true,"automatic":automatic,"settled_roundtrip":true}
    FileAccess.open("res://qa/zombie_traversals83.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
    if "--capture-zombie-traversals" in OS.get_cmdline_user_args():
        scene.set_process(false);p.global_position=Vector3(1000,.02,1000);other.global_position=Vector3(1003,.02,1000)
        for index in routes.size():
            var obstacle: Node3D=routes[index]
            for side in ([-1,1] if obstacle.kind=="window" else [-1]):
                await _place83(scene,z,obstacle,side)
                assert(z.request_cross(obstacle),z.crossing.message)
                var center=z.crossing.anchor+Vector3.UP
                scene.camera.size=4.4;scene.camera.global_position=center+Vector3(-4,3,5);scene.camera.look_at(center)
                for frame in 34:
                    z.crossing.advance(.1)
                    await _capture83(scene,"%d_%d/%02d"%[index,side,frame])
                assert(not z.crossing.is_active() and z.crossing_result.success)
    print("R83_TRAVERSALS_OK ",checks)
    scene.get_tree().quit()
func _capture83(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/zombie_traversals83/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
