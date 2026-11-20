extends "res://personagem/revisao90.gd"
func _step88(scene: Node3D,dt: float) -> void:
    super._step88(scene,dt);scene.player.map_combat.effects.advance(dt)
func _pose91(scene: Node3D,victim: CharacterBody3D,pad: Vector3) -> void:
    victim.restore(scene.zombie_world.initial[victim.identity]);victim.ai_enabled=false;victim.global_position=pad+Vector3(0,0,3);victim.avatar.rotation.y=PI
    victim.avatar.set_motion("idle");victim.avatar.motion_blend=1;victim.avatar.motion_clock=0;victim.avatar.advance(0)
func _region91(victim: Node3D,zone: String) -> Dictionary:
    for region in victim.hit_regions91():
        if region.zone==zone:return region
    assert(false,zone);return {}
func _shot91(scene: Node3D,victim: CharacterBody3D,pad: Vector3,zone: String,fps: int) -> Dictionary:
    var p=scene.player;var aim=scene.shoulder
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.global_position=pad;p.avatar.rotation.y=0
    _pose91(scene,victim,pad)
    for tick in 2:await scene.get_tree().physics_frame
    var region=_region91(victim,zone);var point: Vector3=(region.a+region.b)*.5
    var accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5);_look88(scene,point)
    for frame in fps:_step88(scene,1.0/fps)
    aim.rng.seed=91
    var uid=p.bag_inventory.equipped("main_hand");p.weapons.rounds[uid]=6
    accepted=p.request_attack();assert(accepted,p.inventory_message)
    for frame in fps*2:
        _step88(scene,1.0/fps)
        if not p.combat.is_attacking():break
    var shot=p.map_combat.last_shot.duplicate(true)
    assert(shot.hit and shot.event.zone==zone,str(shot))
    assert(p.weapons.loaded(uid)==5 and victim.last_bullet_zone==zone)
    var after=victim.health;p.combat.advance(3);assert(victim.health==after and p.weapons.loaded(uid)==5)
    return {"fps":fps,"zone":zone,"damage":shot.event.amount,"remaining":victim.health,"once":true,"cone":shot.cone_degrees}
func run(scene: Node3D) -> void:
    var p=scene.player;var aim=scene.shoulder;var bag=p.bag_inventory;var combat=p.map_combat
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false);scene.set_process(false)
    aim.set_process(false);aim.set_physics_process(false);aim.scripted=true
    combat.effects.set_physics_process(false);scene.get_window().size=Vector2i(1440,900)
    p.condition_path="user://qa_shots91.json"
    for z in scene.zombie_world.actors.values():z.ai_enabled=false
    if "--shots-reopen" in OS.get_cmdline_user_args():
        var accepted=p.load_condition();assert(accepted,p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/shots91_expected.json"))
        assert(helper._same(expected,p.session_save.snapshot()) and combat.effects.bursts.is_empty() and not aim.holding)
        print("R91_FRESH_PROCESS_OK");scene.get_tree().quit();return
    for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
    var actor=scene.zombie_world.actors.values()[0];var model=combat.ballistics.regions
    var pistol=_find_weapon(bag,"pistol");var ammo=_find_weapon(bag,"ammo_pistol")
    p.update_nearby();var accepted=p.equip_item(pistol);assert(accepted);_settle86(p)
    accepted=p.place_item(ammo,"pockets",2,0,false);assert(accepted);_settle86(p)
    accepted=p.map_combat.reload_weapon();assert(accepted);_settle86(p)
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0;scene.focus=pad+Vector3.UP*.85;scene._update_camera()
    _pose91(scene,actor,pad)
    for tick in 2:await scene.get_tree().physics_frame
    # Isolated ray/capsule geometry and all anatomical regions, without depending on overlap order.
    assert(is_equal_approx(model.capsule(Vector3(0,.5,-3),Vector3.BACK,Vector3.ZERO,Vector3.UP,.1),2.9))
    assert(model.capsule(Vector3(2,.5,-3),Vector3.BACK,Vector3.ZERO,Vector3.UP,.1)==INF)
    var regions=[]
    for region in actor.hit_regions91():
        var center: Vector3=(region.a+region.b)*.5;var isolated=model.intersect(center+Vector3.BACK*2,Vector3.FORWARD,4,[region])
        assert(not isolated.is_empty() and isolated.zone==region.zone)
        var found=false
        for axis in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD,Vector3.UP]:
            var hit=combat.shot_trace(center+axis*2,center-axis*.3)
            if hit.get("collider")==actor and hit.get("zone")==region.zone:found=true;break
        assert(found,region.zone)
        var event={"id":"region91_"+region.zone,"action":"firearm_shot","zone":region.zone,"amount":.28*float(combat.config.damage_factors[region.zone]),"source_position":pad}
        actor.health=.48;actor.state="idle";actor.seen.clear();actor.add_to_group("combat_receivers79")
        accepted=actor.receive_combat_hit(event);assert(accepted)
        var health=actor.health;assert(not actor.receive_combat_hit(event) and actor.health==health)
        regions.append({"zone":region.zone,"damage":event.amount,"remaining":health})
        _pose91(scene,actor,pad)
    # Physical silhouettes: arms outside the old capsule can be hit; empty space is not chest.
    var gap_origin=actor.global_position+Vector3(0,.22,2)
    var gap=combat.shot_trace(gap_origin,gap_origin+Vector3.FORWARD*4)
    assert(gap.get("collider")!=actor)
    var old_arm=_region91(actor,"forearm_left").b
    actor.avatar.set_motion("push");actor.avatar.motion_blend=1;actor.avatar.motion_clock=.45;actor.avatar.advance(0)
    assert(old_arm.distance_to(_region91(actor,"forearm_left").b)>.04)
    _pose91(scene,actor,pad)
    var cases=[]
    for zone in ["head","chest","calf_left"]:
        for fps in [30,60,120]:cases.append(await _shot91(scene,actor,pad,zone,fps))
    assert(cases[0].remaining==0 and is_equal_approx(cases[3].remaining,.20) and is_equal_approx(cases[6].remaining,.326))
    # Stabilizing, turning, recoil, stamina and pain alter spread in a reproducible way.
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);_pose91(scene,actor,pad)
    accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5)
    aim.steady=1;aim.turn=0;aim.bloom=0;p.condition_state.set_stamina(100);p.condition_state.pain_base=0
    var stable=aim.cone_degrees();var spread_cases=[]
    for fps in [30,60,120]:
        aim.steady=1;aim.turn=0;aim.bloom=0
        for frame in fps:aim.move_aim(Vector2(300.0/fps,0));aim.advance(1.0/fps)
        spread_cases.append(aim.cone_degrees())
    assert(absf(spread_cases[0]-spread_cases[2])<.003)
    aim.steady=1;aim.turn=0;aim.bloom=0;p.condition_state.set_stamina(20)
    var tired=aim.cone_degrees();p.condition_state.pain_base=100;var pain=aim.cone_degrees()
    assert(tired>stable and pain>tired)
    p.condition_state.set_stamina(100);p.condition_state.pain_base=0;aim.note_shot();var recoil=aim.cone_degrees();assert(recoil>stable)
    aim.advance(3);assert(is_equal_approx(aim.cone_degrees(),stable))
    aim.rng.seed=123;var first=aim.direction_with_spread(1.5);aim.rng.seed=123;assert(first.is_equal_approx(aim.direction_with_spread(1.5)))
    var maximum_angle=0.0
    for sample in 1000:
        var direction=aim.direction_with_spread(1.5);maximum_angle=maxf(maximum_angle,rad_to_deg(direction.angle_to(-scene.camera.global_basis.z)))
    assert(maximum_angle<=1.501 and maximum_angle>1.3)
    # No target magnetism: an off-target shot spends ammunition without damaging either NPC.
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.avatar.rotation.y=0;_pose91(scene,actor,pad)
    accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5);_look88(scene,pad+Vector3(4,1.3,4))
    var untouched=actor.health;var ammunition=p.weapons.loaded(pistol);accepted=p.request_attack();assert(accepted)
    for frame in 60:_step88(scene,1.0/60)
    assert(not combat.last_shot.hit and actor.health==untouched and p.weapons.loaded(pistol)==ammunition-1)
    # The physically first NPC intercepts the trajectory; no damage is sent through it.
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.avatar.rotation.y=0;_pose91(scene,actor,pad)
    var second=scene.zombie_world.actors.values()[1];_pose91(scene,second,pad);second.global_position=pad+Vector3(0,0,1.6)
    for tick in 2:await scene.get_tree().physics_frame
    accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5);_look88(scene,actor.global_position+Vector3.UP*1.18)
    p.weapons.rounds[pistol]=6;accepted=p.request_attack();assert(accepted)
    for frame in 60:_step88(scene,1.0/60)
    assert(combat.last_shot.hit and combat.last_shot.receiver_id==second.identity and actor.health==.48 and second.health<.48)
    second.restore(scene.zombie_world.initial[second.identity]);second.ai_enabled=false;second.global_position=Vector3(1000,0,1000)
    _pose91(scene,actor,pad);actor.state="idle";actor.memory=0;actor.hear_shot(pad,12)
    assert(actor.memory==4 and actor.search_remaining==12 and scene.zombie_world.valid(scene.zombie_world.snapshot()))
    # A wall in front of the skeleton takes priority; the old broad capsule never leaks a hit through it.
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.avatar.rotation.y=0;_pose91(scene,actor,pad)
    accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5);_look88(scene,actor.global_position+Vector3.UP*1.2)
    _box(scene,pad+Vector3(0,1,1.5),Vector3(3,2,.1))
    for tick in 2:await scene.get_tree().physics_frame
    var before=actor.health;p.weapons.rounds[pistol]=6
    accepted=p.request_attack();assert(accepted)
    for frame in 80:_step88(scene,1.0/60)
    assert(not combat.last_shot.hit and actor.health==before and p.weapons.loaded(pistol)==5)
    await _clear_boxes(scene)
    # Cancel before impact: no round and no extra effect; effects are bounded and transient.
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.avatar.rotation.y=0
    accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5);_look88(scene,actor.global_position+Vector3.UP*1.2)
    var rounds=p.weapons.loaded(pistol);accepted=p.request_attack();assert(accepted)
    _step88(scene,.05);aim.set_aim(false);_step88(scene,1)
    assert(p.weapons.loaded(pistol)==rounds and combat.effects.bursts.is_empty())
    combat.effects.spawn(pad,pad,Vector3.UP,"world");combat.effects.advance(1);assert(combat.effects.bursts.is_empty())
    # Head damage, death and ammunition persist with the existing profile contract.
    await _shot91(scene,actor,pad,"head",60)
    for frame in 120:actor.step(1.0/60)
    assert(actor.state=="dead" and actor.hit_regions91().is_empty())
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.global_position=scene.spawn
    var other=scene.zombie_world.actors.values()[1];other.restore(scene.zombie_world.initial[other.identity]);other.ai_enabled=false
    accepted=p.save_condition();assert(accepted,p.inventory_message+" reason "+p.session_save.reason+" enemies "+str(scene.zombie_world.snapshot())+" condition "+str(p.condition_state.snapshot()))
    var saved=p.session_save.snapshot();accepted=p.load_condition();assert(accepted and helper._same(saved,p.session_save.snapshot()))
    assert(actor.state=="dead" and actor.hit_regions91().is_empty())
    helper._write("res://qa/shots91_expected.json",saved)
    var checks={"regions":regions,"cases":cases,"spread_fps":spread_cases,"stable_cone":stable,"tired_cone":tired,"pain_cone":pain,"recoil_cone":recoil,"sample_max_angle":maximum_angle,"empty_gap_miss":true,"world_blocks_regions":true,"cancel_no_round":true,"effects_expire":true,"dead_roundtrip":true,"no_duplicate_event":true,"hearing_profile_valid":true,"animated_regions":true,"off_target_miss":true,"first_npc_intercepts":true}
    helper._write("res://qa/shots91.json",checks)
    if "--capture-shots" in OS.get_cmdline_user_args():await _native91(scene,pad,actor,pistol)
    print("R91_SHOTS_OK ",checks);scene.get_tree().quit()
func _native91(scene: Node3D,pad: Vector3,victim: CharacterBody3D,pistol: String) -> void:
    var p=scene.player;var aim=scene.shoulder;var combat=p.map_combat
    for tick in 2:await scene.get_tree().physics_frame
    for zone in ["head","chest","calf_left"]:
        aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.global_position=pad;p.avatar.rotation.y=0
        for actor in scene.zombie_world.actors.values():actor.ai_enabled=false;actor.global_position=Vector3(1000,0,1000)
        _pose91(scene,victim,pad)
        for tick in 2:await scene.get_tree().physics_frame
        var region=_region91(victim,zone);var point: Vector3=(region.a+region.b)*.5
        aim.set_aim(true);_step88(scene,.5);_look88(scene,point)
        for frame in 40:_step88(scene,1.0/60)
        p.weapons.rounds[pistol]=6;aim.rng.seed=91
        await _capture91(scene,zone+"_aim")
        var accepted=p.request_attack();assert(accepted)
        for frame in 60:
            _step88(scene,.04);victim.step(.04);await _capture91(scene,zone+"/%03d"%frame)
        assert(combat.last_shot.hit and combat.last_shot.event.zone==zone and p.weapons.loaded(pistol)==5)
        if zone=="head":assert(victim.state=="dead")
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.avatar.rotation.y=0
    for actor in scene.zombie_world.actors.values():actor.ai_enabled=false;actor.global_position=Vector3(1000,0,1000)
    aim.set_aim(true);_step88(scene,.5);aim.steady=1;aim.turn=0;aim.bloom=0
    for frame in 48:
        if frame<20:aim.move_aim(Vector2(6,0))
        _step88(scene,1.0/60)
        if frame==19:await _capture91(scene,"precision_turn")
        await _capture91(scene,"precision/%03d"%frame)
    await _capture91(scene,"precision_settled")
    p.condition_state.set_stamina(20);_step88(scene,.1);await _capture91(scene,"precision_tired");p.condition_state.set_stamina(100)
    aim.set_aim(false);_step88(scene,.5);_player_idle(p);p.avatar.rotation.y=0;_pose91(scene,victim,pad)
    for tick in 2:await scene.get_tree().physics_frame
    aim.set_aim(true);_step88(scene,.5);_look88(scene,victim.global_position+Vector3.UP*1.2)
    _box(scene,pad+Vector3(0,1,1.5),Vector3(3,2,.1))
    for tick in 2:await scene.get_tree().physics_frame
    p.weapons.rounds[pistol]=6;var accepted=p.request_attack();assert(accepted)
    for frame in 32:_step88(scene,.04);await _capture91(scene,"wall/%03d"%frame)
    assert(not combat.last_shot.hit and victim.health==.48)
    await _clear_boxes(scene)
func _capture91(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
    var path="res://previews/shots91/"+name+".png";DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
