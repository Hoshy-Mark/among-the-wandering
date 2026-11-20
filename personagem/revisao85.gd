extends "res://personagem/revisao84.gd"
func _player_idle(p: CharacterBody3D) -> void:
    p.reaction.reset();p.map_combat.pending_reaction="";p.combat.set_guard(false);p.action.cancel();p.velocity=Vector3.ZERO;p.condition_state.set_stamina(100)
func _pose(scene: Node3D,z: CharacterBody3D,pad: Vector3,offset: Vector3=Vector3(0,0,.85)) -> void:
    z.ai_enabled=false;z.restore(scene.zombie_world.initial[z.identity])
    z.global_position=pad+offset;z.avatar.rotation.y=atan2(-offset.x,-offset.z);z.cooldown=0
    scene.player.global_position=pad;scene.player.avatar.rotation.y=0
    _player_idle(scene.player)
func run(scene: Node3D) -> void:
    var world=scene.zombie_world;var p=scene.player;var nav=world.navigation
    var actors=world.actors.values()
    for z in actors:z.ai_enabled=false
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    scene.get_window().size=Vector2i(1440,900)
    p.condition_path="user://qa_encounters85.json"
    if "--encounters-reopen" in OS.get_cmdline_user_args():
        var accepted=p.load_condition()
        assert(accepted,p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/encounters85_expected.json"))
        assert(helper._same(expected,p.session_save.snapshot()))
        assert(actors[0].variant_id=="errante" and actors[1].variant_id=="alerta")
        print("R85_FRESH_PROCESS_OK");scene.get_tree().quit();return
    for z in actors:z.global_position=Vector3(1000,0,1000)
    var pad=_field(scene)
    var cases=[];var zones=[]
    for z in actors:
        for other in actors:
            if other!=z:other.global_position=Vector3(1000,0,1000)
        for fps in [30,60,120]:
            _pose(scene,z,pad)
            z._begin_attack();var before=p.body_health.records.size();var first=-1.0
            for frame in fps*3:
                z._attack_step(1.0/fps);z._present(1.0/fps);_joints(z.avatar)
                if z.elapsed+0.000001<float(z.profile.impact) and z.state=="attack":assert(p.body_health.records.size()==before)
                if p.body_health.records.size()>before and first<0:first=(frame+1.0)/fps
                if z.state!="attack":break
            assert(p.body_health.records.size()==before+1 and first>=z.profile.impact-.000001 and first<=z.profile.impact+1.0/fps+.000001)
            assert(is_equal_approx(z.cooldown,z.profile.recovery))
            var interval=z.cooldown;z._attack_step(10)
            assert(p.body_health.records.size()==before+1 and z.cooldown==interval)
            cases.append({"variant":z.variant_id,"fps":fps,"first_effect":first,"duration":z.attack_duration(),"once":true})
        # Player movement during the tell turns a prepared attack into a miss.
        _pose(scene,z,pad);z._begin_attack();z._attack_step(z.profile.impact*.4)
        p.global_position=pad+Vector3(0,0,-2)
        var before=p.body_health.snapshot();z._attack_step(2)
        assert(p.body_health.snapshot()==before)
        _pose(scene,z,pad);z._begin_attack();z._attack_step(z.profile.impact*.4)
        _box(scene,pad+Vector3(0,1,.425),Vector3(3,2,.08))
        for frame in 2:await scene.get_tree().physics_frame
        before=p.body_health.snapshot();z._attack_step(2)
        assert(p.body_health.snapshot()==before)
        await _clear_boxes(scene)
        # A push cancels the prepared event, deduplicates and leaves a recovery window.
        _pose(scene,z,pad);z._begin_attack();z._attack_step(z.profile.impact*.4)
        var event={"id":"push85_"+z.identity,"action":"push","amount":.06,"source_position":p.global_position}
        assert(z.receive_combat_hit(event) and z.state=="hit" and z.health==.48)
        assert(not z.receive_combat_hit(event))
        before=p.body_health.snapshot();z._attack_step(5)
        assert(p.body_health.snapshot()==before)
        z.step(z.hit_duration()+.001)
        assert(z.state=="search" and z.cooldown>=z.profile.after_hit)
        z.step(z.profile.after_hit*.5)
        assert(z.state!="attack")
        z.step(z.profile.after_hit+.01)
        assert(z.state=="attack")
        # Region selection follows the actual approach relative to the player.
        for sample in [{"offset":Vector3(0,0,.85),"zone":"forearm_left"},{"offset":Vector3(.85,0,0),"zone":"upper_arm_left"},{"offset":Vector3(-.85,0,0),"zone":"upper_arm_right"},{"offset":Vector3(0,0,-.85),"zone":"chest"}]:
            _pose(scene,z,pad,sample.offset);z._begin_attack();z._attack_step(z.profile.impact+.001)
            assert(z.last_attack_result and z.last_attack_zone==sample.zone)
            var entry=p.body_health.records[z.attack_id]
            assert(entry.zone==sample.zone and entry.kind=="scratch")
            zones.append({"variant":z.variant_id,"zone":sample.zone})
        # The real player callback interrupts before impact (anticipation for the fast NPC).
        _pose(scene,z,pad,Vector3(0,0,.78));p.avatar.rotation.y=0
        var started=p.map_combat.request("push");assert(started)
        if z.variant_id=="alerta":
            for frame in 18:p.combat.advance(1.0/60)
        z._begin_attack();before=p.body_health.snapshot()
        for frame in 180:
            p.combat.advance(1.0/60);z.step(1.0/60)
            if p.combat.effect_succeeded:break
        assert(p.combat.effect_succeeded and z.state=="hit" and p.body_health.snapshot()==before)
        # After a missed enemy attack, a player punch can land during recovery.
        _pose(scene,z,pad);z._begin_attack();p.global_position=pad+Vector3(0,0,-2)
        z._attack_step(z.attack_duration()+.001)
        p.global_position=pad;p.avatar.rotation.y=0;_player_idle(p)
        started=p.map_combat.request("punch");assert(started)
        for frame in 180:
            p.combat.advance(1.0/60);z.step(1.0/60)
            if p.combat.effect_succeeded:break
        assert(p.combat.effect_succeeded and is_equal_approx(z.health,.36) and z.state=="hit")
    # A friend physically between attacker and player prevents the scratch.
    var a=actors[0];var b=actors[1]
    _pose(scene,a,pad,Vector3(0,0,1.02));b.restore(world.initial[b.identity]);b.global_position=pad+Vector3(0,0,.5)
    for frame in 2:await scene.get_tree().physics_frame
    a._begin_attack();var before=p.body_health.snapshot();a._attack_step(2)
    assert(not a.last_attack_result and p.body_health.snapshot()==before)
    # Both profiles reach the player through the real navigation/physics loop.
    var approaches=[]
    for z in actors:
        for other in actors:
            if other!=z:other.global_position=Vector3(1000,0,1000)
        _pose(scene,z,pad,Vector3(0,0,3));z.state="chase";z.memory=4;z.search_remaining=12;z.last_known=pad
        var begun=Time.get_ticks_msec();var hit_count=z.hits
        z.ai_enabled=true
        for frame in 900:
            await scene.get_tree().physics_frame
            _joints(z.avatar)
            if z.hits>hit_count:break
        z.ai_enabled=false
        assert(z.hits>hit_count and z.attacks>0)
        approaches.append({"variant":z.variant_id,"milliseconds":Time.get_ticks_msec()-begun,"speed":z.movement_speed()})
    assert(approaches[0].speed<approaches[1].speed)
    # Profile playback rates retain the approved physical traversal in both directions.
    var low: Node3D;var window: Node3D
    for obstacle in p.map_traversals.obstacles:
        if low==null and obstacle.has_meta("fence78") and not obstacle.model.high:low=obstacle
        if obstacle.opening_id=="H01/window/01":window=obstacle
    assert(low!=null and window!=null)
    var openings=p.map_doors.snapshot();openings.states[window.opening_id]=true;p.map_doors.apply_restore(openings)
    p.global_position=Vector3(1000,0,1000)
    for frame in 2:await scene.get_tree().physics_frame
    var traversal_cases=[]
    for z in actors:
        for other in actors:
            if other!=z:other.global_position=Vector3(1003,0,1000)
        for obstacle in [low,window]:
            for side in [-1,1]:
                await _place83(scene,z,obstacle,side)
                var started=z.request_cross(obstacle);assert(started,z.crossing.message)
                assert(is_equal_approx(z.crossing.playback_rate,z.profile.cross_rate))
                var previous_position=z.global_position
                for frame in 400:
                    z.crossing.advance(1.0/60);_joints(z.avatar)
                    assert(z.global_position.distance_to(previous_position)<.17)
                    previous_position=z.global_position
                    if not z.crossing.is_active():break
                assert(z.crossing_result.get("success",false) and is_equal_approx(z.capsule.shape.height,1.84))
                traversal_cases.append({"variant":z.variant_id,"kind":obstacle.kind,"side":side,"rate":z.profile.cross_rate})
    # Kill events and stable profiles survive save/load; previous profiles get defaults.
    _player_idle(p);p.global_position=scene.spawn
    for z in actors:z.restore(world.initial[z.identity])
    var kill={"id":"kill85","action":"punch","amount":1.0,"source_position":actors[0].global_position+Vector3.BACK}
    assert(actors[0].receive_combat_hit(kill));actors[0].step(1.8)
    for frame in 2:await scene.get_tree().physics_frame
    assert(actors[0].state=="dead" and not actors[0].receive_combat_hit(kill))
    _player_idle(p)
    var accepted=p.save_condition();assert(accepted,p.inventory_message)
    var saved=p.session_save.snapshot()
    var altered=world.initial[actors[1].identity].duplicate(true);altered.variant85="errante"
    actors[1].restore(altered);assert(actors[1].movement_speed()==.75)
    accepted=p.load_condition();assert(accepted,p.inventory_message)
    assert(actors[0].state=="dead" and actors[1].variant_id=="alerta" and actors[1].movement_speed()==1.1)
    if FileAccess.file_exists(p.condition_path+".bak"):DirAccess.remove_absolute(p.condition_path+".bak")
    var invalid=saved.duplicate(true);invalid.enemies82[actors[1].identity].variant85="missing"
    helper._write(p.condition_path,invalid);before=p.session_save.snapshot()
    assert(not p.load_condition() and helper._same(before,p.session_save.snapshot()))
    var legacy=saved.duplicate(true)
    for entry in legacy.enemies82.values():entry.erase("variant85")
    helper._write(p.condition_path,legacy);accepted=p.load_condition();assert(accepted)
    assert(actors[0].variant_id=="errante" and actors[1].variant_id=="alerta")
    helper._write(p.condition_path,saved);accepted=p.load_condition();assert(accepted)
    helper._write("res://qa/encounters85_expected.json",p.session_save.snapshot())
    assert(max_elbow<.025 and max_wrist<.015)
    var checks={"cases":cases,"traversals":traversal_cases,"zones":zones,"approaches":approaches,"move_miss":true,"wall_mid_attack":true,"push_interrupts_once":true,"after_hit_window":true,"player_push_callback":true,"counterpunch_after_miss":true,"friend_blocks":true,"variant_roundtrip":true,"dead_stays_dead":true,"unknown_variant_atomic":true,"r84_migration":true,"max_elbow":max_elbow,"max_wrist":max_wrist}
    helper._write("res://qa/encounters85.json",checks)
    if "--capture-zombie-encounters" in OS.get_cmdline_user_args():
        scene.set_process(false)
        for z in actors:
            for other in actors:
                if other!=z:other.global_position=Vector3(1000,0,1000)
            _pose(scene,z,pad,Vector3(0,0,3));z.state="chase";z.memory=4;z.search_remaining=12;z.last_known=pad
            _camera84(scene,pad+Vector3(0,.9,1.2),5.3,Vector3(4,3,5))
            p.set_physics_process(true);z.ai_enabled=true
            for frame in 70:
                for tick in 4:await scene.get_tree().physics_frame
                await _capture85(scene,z.variant_id+"/%03d"%frame)
            z.ai_enabled=false;p.set_physics_process(false)
        _player_idle(p);p.survival.update_pain();p.survival.refresh();scene.game_ui.toggle(1)
        await _capture85(scene,"body")
    print("R85_ENCOUNTERS_OK ",checks)
    scene.get_tree().quit()
func _capture85(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/encounters85/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
