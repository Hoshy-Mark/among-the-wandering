extends "res://personagem/revisao93.gd"
func _player94(scene: Node3D,dt: float) -> void:
    if scene.player.reaction.is_active():scene.player.reaction.advance(dt);scene.player.weapons.present()
    else:_step88(scene,dt)
func _reset94(scene: Node3D,z: CharacterBody3D,pad: Vector3,offset: Vector3) -> void:
    _player_idle(scene.player);z.restore(scene.zombie_world.initial[z.identity]);z.ai_enabled=false
    z.global_position=pad+offset;z.avatar.rotation.y=PI;z.avatar.set_motion("idle");z.avatar.advance(0)
func run(scene: Node3D) -> void:
    if "--queue-debug" in OS.get_cmdline_user_args() or "--queue-check" in OS.get_cmdline_user_args():await load("res://personagem/revisao94_fila.gd").new().run(scene);return
    var p=scene.player;var world=scene.zombie_world;var nav=world.navigation;var aim=scene.shoulder;var actors=world.actors.values();var a=actors[0];var b=actors[1]
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false);scene.set_process(false)
    aim.scripted=true;aim.set_process(false);aim.set_physics_process(false);p.get_node("Atalhos93").scripted=true;p.map_combat.effects.set_physics_process(false)
    scene.get_window().size=Vector2i(1280,800);p.condition_path="user://qa_cycle94.json"
    for z in actors:z.ai_enabled=false
    if "--cycle-reopen" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/cycle94_expected.json"))
        assert(helper._same(expected,p.session_save.snapshot()) and a.state=="dead" and a.hit_regions91().is_empty() and b.flank_steps94==0)
        print("R94_FRESH_PROCESS_OK");scene.get_tree().quit();return
    if "--cycle-capture-only" in OS.get_cmdline_user_args():
        await _native94(scene);print("R94_NATIVE_OK");scene.get_tree().quit();return
    var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://qa/legacy93.json"))
    assert(not p.session_save.prepare(legacy,false).is_empty(),p.session_save.reason)
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0
    var condition=p.condition_state.snapshot();var health=p.body_health.snapshot()
    _reset94(scene,a,pad,Vector3(0,0,1.7));_reset94(scene,b,pad,Vector3(0,0,3.0))
    for tick in 2:await scene.get_tree().physics_frame
    assert(b.sees_player() and not b.clear_line(p.global_position,p))
    a.global_position=pad+Vector3(0,0,.5);b.global_position=pad+Vector3(0,0,1.02)
    for tick in 2:await scene.get_tree().physics_frame
    assert(b.sees_player() and not b.can_hit_player())
    _box(scene,pad+Vector3(0,1,.22),Vector3(5,2,.08))
    for tick in 2:await scene.get_tree().physics_frame
    assert(not b.sees_player());await _clear_boxes(scene)
    a.global_position=Vector3(1000,0,1000);_reset94(scene,b,pad,Vector3(0,0,3))
    b.state="search";b.memory=4;b.search_remaining=12;b.last_known=pad;b.ensure_route(pad)
    var ticket=b.path_ticket
    for i in 5:b.hear_shot(pad,12)
    assert(b.path_ticket==ticket and b.path_pending)
    for tick in 240:
        await scene.get_tree().physics_frame
        if not b.path_pending:break
    assert(not b.route.is_empty() and b.path_ticket==ticket)
    var route=b.route.duplicate(true)
    for i in 5:b.hear_shot(pad,12)
    assert(b.path_ticket==ticket and b.route==route and b.memory==4 and b.search_remaining==12)
    var new_goal=pad+Vector3(1.2,0,0);b.hear_shot(new_goal,12)
    assert(b.path_ticket==ticket+1 and b.route.is_empty() and b.last_known==new_goal)
    b.hear_shot(Vector3(NAN,0,0),12);b.hear_shot(pad,-1);assert(b.last_known==new_goal)
    _box(scene,pad+Vector3(0,1,1.5),Vector3(6,2,.08))
    p.global_position=pad+Vector3(-1,0,0);p.velocity=Vector3.ZERO
    for tick in 2:await scene.get_tree().physics_frame
    for frame in 60:
        await scene.get_tree().physics_frame;b.step(1.0/60);_player94(scene,1.0/60)
    assert(b.last_known==new_goal and absf(b.search_remaining-11)<.001)
    b.hear_shot(b.global_position,12)
    for frame in 241:b.step(.05)
    assert(b.state=="idle" and b.memory==0 and b.search_remaining==0)
    await _clear_boxes(scene);p.global_position=pad
    var cases=[]
    for actor in actors:
        for other in actors:
            if other!=actor:other.global_position=Vector3(1000,0,1000)
        for fps in [30,60,120]:
            Engine.physics_ticks_per_second=fps
            assert(p.condition_state.restore(condition));assert(p.body_health.restore(health));_reset94(scene,actor,pad,Vector3(0,0,3.5))
            var hit_count=actor.hits;var before=p.body_health.records.size();var first=-1.0;var largest=0.0;var started=false
            for frame in fps*12:
                await scene.get_tree().physics_frame
                var previous=actor.global_position;actor.step(1.0/fps);_player94(scene,1.0/fps);_joints(actor.avatar)
                largest=maxf(largest,previous.distance_to(actor.global_position))
                if actor.state=="attack":started=true
                if actor.hits>hit_count and first<0:first=(frame+1.0)/fps
                if started and actor.state!="attack":break
            assert(first>0 and actor.hits==hit_count+1 and p.body_health.records.size()==before+1,str([actor.identity,fps,first,actor.state,actor.navigation_stats]))
            assert(actor.cooldown>0 and largest<.09,str(largest))
            var after=p.body_health.snapshot();actor._attack_step(5);assert(p.body_health.snapshot()==after)
            cases.append({"variant":actor.variant_id,"fps":fps,"first_hit_seconds":first,"largest_step":largest,"one_hit":true})
    Engine.physics_ticks_per_second=60
    assert(p.condition_state.restore(condition));assert(p.body_health.restore(health));_player_idle(p)
    var aligned=nav.project(Vector3(round(pad.x/nav.CELL)*nav.CELL,pad.y,round(pad.z/nav.CELL)*nav.CELL));assert(aligned!=null)
    p.global_position=aligned;_reset94(scene,a,aligned,Vector3(0,0,1.65));_reset94(scene,b,aligned,Vector3(0,0,2.75))
    var min_gap=100.0;var sideways=0.0;var hits=b.hits
    for frame in 900:
        await scene.get_tree().physics_frame;b.step(1.0/60);_player94(scene,1.0/60);_joints(b.avatar)
        var delta=b.global_position-a.global_position;delta.y=0;min_gap=minf(min_gap,delta.length());sideways=maxf(sideways,absf(b.global_position.x-aligned.x))
        if b.hits>hits:break
    assert(b.hits==hits+1 and sideways>.22 and min_gap>.43,str([b.state,b.global_position,sideways,min_gap,b.flank_steps94,b.navigation_stats]))
    assert(b.flank_steps94>0);var flank_steps=b.flank_steps94
    # Old saves and stable dead/search states keep the existing schema.
    p.global_position=scene.spawn;assert(p.condition_state.restore(condition));assert(p.body_health.restore(health));_player_idle(p)
    for actor in actors:actor.restore(world.initial[actor.identity]);actor.ai_enabled=false
    assert(a.receive_combat_hit({"id":"cycle94_head","action":"firearm_shot","zone":"head","amount":.8,"source_position":p.global_position}))
    for frame in 120:
        await scene.get_tree().physics_frame;a.step(1.0/60)
    b.hear_shot(b.global_position+Vector3.RIGHT,12)
    assert(a.state=="dead" and b.state=="search" and b.memory==4 and b.search_remaining==12)
    assert(p.save_condition(),p.inventory_message);var saved=p.session_save.snapshot();assert(p.load_condition() and helper._same(saved,p.session_save.snapshot()))
    assert(a.hit_regions91().is_empty() and b.flank_steps94==0)
    helper._write("res://qa/cycle94_expected.json",saved)
    var checks={"cases":cases,"vision_through_friend":true,"friend_blocks_attack":true,"wall_blocks_vision":true,"same_shot_preserves_route":true,"new_shot_replans":true,"finite_stimulus_validation":true,"last_known_no_xray":true,"search_expires":true,"flank_sideways":sideways,"minimum_actor_gap":min_gap,"flank_steps":flank_steps,"crowd_reaches_player":true,"migration93":true,"roundtrip":true,"dead_has_no_hit_regions":true}
    helper._write("res://qa/cycle94.json",checks)
    if "--capture-zombie-cycle" in OS.get_cmdline_user_args():await _native94(scene)
    print("R94_CYCLE_OK ",checks);scene.get_tree().quit()
func _native94(scene: Node3D) -> void:
    var p=scene.player;var aim=scene.shoulder;var quick=p.get_node("Atalhos93");var bag=p.bag_inventory;var actors=scene.zombie_world.actors.values()
    for actor in actors:actor.ai_enabled=false;actor.global_position=Vector3(1000,0,1000)
    p.global_position=scene.spawn;p.update_nearby();_player_idle(p)
    for pair in [["left","pistol"],["up","carbine"],["right","baton"]]:
        assert(quick.bind(pair[0],_find_weapon(bag,pair[1])));_settle93(scene)
    assert(p.place_item(_find_weapon(bag,"ammo_pistol"),"pockets",2,0,false));_settle93(scene)
    assert(p.place_item(_find_weapon(bag,"ammo_carbine"),"pockets",2,1,false));_settle93(scene)
    assert(quick.activate("up"));_settle93(scene);assert(p.weapons.reload_weapon());_settle93(scene)
    assert(quick.activate("left"));_settle93(scene);assert(p.weapons.reload_weapon());_settle93(scene)
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0;scene.focus=pad+Vector3.UP*.85;scene.zoom=5.4;scene._update_camera()
    for i in 2:_reset94(scene,actors[i],pad,Vector3(0 if i==0 else 1.8,0,5 if i==0 else 8))
    Engine.physics_ticks_per_second=25;aim.rng.seed=94
    var shots=[]
    for frame in 300:
        await scene.get_tree().physics_frame
        if frame in [25,128]:assert(aim.set_aim(true))
        if aim.holding:
            var victim=actors[0] if frame<105 else actors[1]
            if victim.state not in ["dying","dead"]:
                var region=_region91(victim,"chest" if frame<105 else "head");var point: Vector3=(region.a+region.b)*.5;var direction=point-scene.camera.global_position
                aim.yaw=lerp_angle(aim.yaw,atan2(direction.x,direction.z),.45);aim.pitch=lerpf(aim.pitch,atan2(direction.y,Vector2(direction.x,direction.z).length()),.45)
        if frame in [55,80,155]:assert(p.request_attack())
        if frame in [74,99,174]:shots.append(p.map_combat.last_shot.duplicate(true))
        if frame==105:aim.set_aim(false);assert(quick.activate("up"))
        if frame==180:aim.set_aim(false);assert(quick.activate("right"))
        if frame==220:assert(quick.activate("up"))
        if frame==244:assert(p.weapons.reload_weapon())
        _player94(scene,.04)
        for actor in actors:actor.step(.04)
        quick.sync()
        await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
        var path="res://previews/cycle94/%03d.png"%frame;DirAccess.make_dir_recursive_absolute(path.get_base_dir())
        scene.get_viewport().get_texture().get_image().save_png(path)
    for shot in shots:assert(shot.hit,str(shot))
    for actor in actors:assert(actor.state=="dead")
    helper._write("res://qa/cycle94_native.json",{"shots":shots,"frames":300,"fps":25,"dead":2})
