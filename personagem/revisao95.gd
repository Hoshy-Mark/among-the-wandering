extends "res://personagem/revisao94.gd"
func _step95(scene: Node3D,dt: float) -> void:
    var p=scene.player
    if p.traversal.is_active():p.traversal.advance(dt)
    elif p.reaction.is_active():p.reaction.advance(dt)
    elif not p.paused:_step88(scene,dt)
    p.get_node("Demo95").advance(dt)
func _event95(id: String,source: Vector3,zone: String="forearm_left",amount: float=.06,kind: String="scratch") -> Dictionary:
    return {"id":id,"action":"zombie_scratch","zone":zone,"kind":kind,"amount":amount,"source_position":source}
func run(scene: Node3D) -> void:
    var tree=scene.get_tree();var p=scene.player;var demo=p.get_node("Demo95");var bag=p.bag_inventory;var quick=p.get_node("Atalhos93")
    var actors_live=scene.zombie_world.actors.values().all(func(z):return z.ai_enabled)
    var nav_live=scene.zombie_world.navigation.is_physics_processing()
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false);scene.set_process(false)
    p.shoulder.scripted=true;p.shoulder.set_process(false);p.shoulder.set_physics_process(false);quick.scripted=true;demo.set_physics_process(false);p.map_combat.effects.set_physics_process(false)
    for z in scene.zombie_world.actors.values():z.ai_enabled=false
    scene.get_window().size=Vector2i(1280,800)
    p.condition_path="user://qa_demo95_capture.json" if "--capture-demo95" in OS.get_cmdline_user_args() else "user://qa_demo95.json"
    var phase=str(tree.get_meta("qa95_phase","initial"))
    if "--capture-demo95" in OS.get_cmdline_user_args():await _native95(scene,phase);return
    if "--death95-reopen" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/demo95_checkpoint.json"))
        assert(helper._same(expected,p.session_save.snapshot()) and demo.state=="alive" and demo.integrity()>0)
        print("R95_FRESH_PROCESS_OK");tree.quit();return
    if phase=="after_resume":
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/demo95_checkpoint.json"))
        assert(helper._same(expected,p.session_save.snapshot()),p.inventory_message)
        assert(demo.state=="alive" and not p.paused and p.reaction.state=="idle" and actors_live and nav_live)
        assert(p.get_instance_id()!=int(tree.get_meta("qa95_old_player")))
        assert(FileAccess.get_sha256(p.condition_path)==str(tree.get_meta("qa95_save_hash")))
        for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
        var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0
        _box(scene,pad+Vector3(0,1,-.85),Vector3(1.3,2,.1))
        for tick in 2:await tree.physics_frame
        assert(not demo.can_fall());await _clear_boxes(scene)
        var found=false
        for obstacle in p.map_traversals.obstacles:
            if not obstacle.has_meta("fence78") or obstacle.model.high:continue
            await _place(scene,obstacle,-1);_player_idle(p)
            if p.request_cross(obstacle):found=true;break
        assert(found)
        for frame in 300:
            _step95(scene,1.0/60)
            if p.traversal.state=="playing" and p.traversal.cursor>float(p.traversal.definitions.actions.vault_fence.takeoff)+.05:break
        assert(p.traversal.is_active())
        assert(p.receive_combat_hit(_event95("fatal_traversal95",p.global_position+Vector3.BACK,"head",1,"cut")))
        assert(demo.state=="ending_traversal" and p.traversal.is_active())
        var largest=0.0
        for frame in 600:
            var previous=p.global_position;_step95(scene,1.0/60);largest=maxf(largest,p.global_position.distance_to(previous));_joints(p.avatar)
            if demo.state=="defeated":break
        assert(demo.state=="defeated" and not p.traversal.is_active() and largest<.17 and demo.fallback)
        assert(not p.save_condition() and FileAccess.get_sha256(p.condition_path)==str(tree.get_meta("qa95_save_hash")))
        tree.set_meta("qa95_phase","after_new");tree.set_meta("qa95_old_player",p.get_instance_id())
        assert(demo.request_new());return
    if phase=="after_new":
        assert(p.get_instance_id()!=int(tree.get_meta("qa95_old_player")) and demo.state=="alive" and not p.paused and actors_live and nav_live)
        assert(p.body_health.records.is_empty() and is_equal_approx(demo.integrity(),100) and quick.bindings.is_empty())
        assert(bag.items.size()==int(tree.get_meta("qa95_initial_count")) and p.weapons.rounds.values().all(func(n):return n==0))
        assert(FileAccess.get_sha256(p.condition_path)==str(tree.get_meta("qa95_save_hash")))
        var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://qa/legacy94.json"))
        assert(not p.session_save.prepare(legacy,false).is_empty())
        var raw=0.0
        for wound in legacy.body.records.values():raw+=float(wound.severity)
        assert(is_equal_approx(p.session_save.pending_baseline,raw))
        var wounded=JSON.parse_string(FileAccess.get_file_as_string("res://qa/demo95_checkpoint.json"));wounded.erase("vitals95")
        assert(not p.session_save.prepare(wounded,false).is_empty() and p.session_save.pending_baseline>0)
        var original_path=p.condition_path;var probe="user://qa_demo95_probe.json"
        var file=FileAccess.open(probe,FileAccess.WRITE);file.store_string("{");file.close()
        helper._write(probe+".bak",JSON.parse_string(FileAccess.get_file_as_string("res://qa/demo95_checkpoint.json")))
        p.condition_path=probe;assert(demo.can_resume())
        file=FileAccess.open(probe+".bak",FileAccess.WRITE);file.store_string("{");file.close();assert(not demo.can_resume())
        p.condition_path=original_path
        var saved=p.session_save.snapshot();var bad=saved.duplicate(true);bad.vitals95.baseline=-1;assert(p.session_save.prepare(bad,false).is_empty())
        bad=saved.duplicate(true);bad.vitals95.baseline=100;assert(p.session_save.prepare(bad,false).is_empty())
        bad=saved.duplicate(true);bad.vitals95.baseline=NAN;assert(p.session_save.prepare(bad,false).is_empty())
        bad=saved.duplicate(true);bad.body.records["fatal"]={"zone":"head","kind":"cut","severity":1.0};assert(p.session_save.prepare(bad,false).is_empty())
        var balance_cases=[]
        for zone in ["head","chest","forearm_left"]:
            var model=load("res://personagem/corpo63.gd").new();model.condition=load("res://personagem/condicao80.gd").new()
            var total=0.0;var hits=0
            while 1-total*3>0:
                assert(model.hit("balance95_"+str(hits),zone,"scratch",.06));total+=float(model.records["balance95_"+str(hits)].severity);hits+=1
            balance_cases.append({"zone":zone,"hits_to_defeat":hits,"damage":.06,"kind":"scratch"})
        assert(balance_cases[0].hits_to_defeat==6 and balance_cases[1].hits_to_defeat==8 and balance_cases[2].hits_to_defeat==14)
        demo.load_failure("Save indisponível no teste");assert(demo.state=="resume_error" and p.paused and not demo.new_button.disabled and not p.save_condition())
        var checks={"backup_preflight":true,"resume_error_blocks_play":true,"wounded_legacy_starts_full":true,"checkpoint_resume_exact":true,"scene_instances_recreated":true,"save_preserved_on_death":true,"new_attempt_clean":true,"npc_and_navigation_unfrozen_after_reload":true,"grace_and_duplicate_rejected":true,"reload_cancelled_without_ammo":true,"postmortem_actions_blocked":true,"open_space_death_clip":true,"tight_space_fallback":true,"fatal_traversal_finishes_safely":true,"legacy94_migration":true,"invalid_vitals_refused":true,"balance":balance_cases}
        helper._write("res://qa/demo95.json",checks)
        tree.remove_meta("qa95_phase");tree.remove_meta("demo95_profile_override")
        print("R95_DEMO_OK ",checks);tree.quit();return
    tree.set_meta("qa95_initial_count",bag.items.size());tree.set_meta("demo95_profile_override",p.condition_path)
    for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
    p.update_nearby()
    for pair in [["left","pistol"],["up","carbine"],["right","baton"]]:assert(quick.bind(pair[0],_find_weapon(bag,pair[1])));_settle93(scene)
    assert(p.place_item(_find_weapon(bag,"ammo_pistol"),"pockets",2,0,false));_settle93(scene)
    assert(quick.activate("left"));_settle93(scene);assert(p.weapons.reload_weapon());_settle93(scene)
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0;_player_idle(p)
    var first=_event95("grace95_first",pad+Vector3.BACK)
    assert(p.receive_combat_hit(first));var integrity=demo.integrity();assert(absf(integrity-92.44)<.01)
    assert(not p.receive_combat_hit(_event95("grace95_other",pad+Vector3.BACK)) and demo.integrity()==integrity)
    demo.advance(.61);_player_idle(p);assert(not p.receive_combat_hit(first))
    assert(p.receive_combat_hit(_event95("grace95_second",pad+Vector3.BACK)))
    demo.advance(.61);_player_idle(p);p.global_position=scene.spawn;p.weapons.rounds[quick.bindings.left]=1
    for z in scene.zombie_world.actors.values():z.restore(scene.zombie_world.initial[z.identity]);z.ai_enabled=false
    p.survival.update_pain();p.survival.refresh()
    assert(p.save_condition(),p.inventory_message);helper._write("res://qa/demo95_checkpoint.json",p.session_save.snapshot())
    tree.set_meta("qa95_save_hash",FileAccess.get_sha256(p.condition_path))
    for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
    p.global_position=pad;p.avatar.rotation.y=0;assert(demo.can_fall())
    var stock=bag.snapshot();var rounds=p.weapons.rounds.duplicate(true)
    assert(p.weapons.reload_weapon());_step95(scene,.05)
    assert(p.receive_combat_hit(_event95("fatal_reload95",pad+Vector3.BACK,"chest",1,"bruise")))
    assert(demo.state=="dying" and not demo.fallback)
    for frame in 240:_step95(scene,1.0/60);_joints(p.avatar)
    assert(demo.state=="defeated" and demo.deaths==1 and p.paused)
    assert(helper._same(stock,bag.snapshot()) and p.weapons.rounds==rounds)
    assert(not p.receive_combat_hit(_event95("postmortem95",pad+Vector3.BACK)))
    assert(not quick.activate("up") and not p.request_attack() and not p.weapons.reload_weapon() and not p.save_condition())
    assert(FileAccess.get_sha256(p.condition_path)==str(tree.get_meta("qa95_save_hash")))
    tree.set_meta("qa95_phase","after_resume");tree.set_meta("qa95_old_player",p.get_instance_id())
    assert(demo.request_resume());return
func _native95(scene: Node3D,phase: String) -> void:
    var p=scene.player;var demo=p.get_node("Demo95");var tree=scene.get_tree()
    tree.set_meta("demo95_profile_override",p.condition_path);Engine.physics_ticks_per_second=25
    if phase=="capture_after_new":
        assert(demo.state=="alive" and demo.integrity()==100 and not p.paused)
        assert(FileAccess.get_sha256(p.condition_path)==str(tree.get_meta("qa95_capture_save_hash")))
        for frame in 75:
            await tree.physics_frame;_step95(scene,.04);await _capture95(scene,175+frame)
        helper._write("res://qa/demo95_native.json",{"frames":250,"fps":25,"prepared_integrity":1.72,"real_zombie_fatal_hit":true,"new_attempt_integrity":demo.integrity()})
        print("R95_NATIVE_OK");tree.quit();return
    for z in scene.zombie_world.actors.values():z.restore(scene.zombie_world.initial[z.identity]);z.ai_enabled=false
    p.global_position=scene.spawn;p.survival.update_pain();assert(p.save_condition(),p.inventory_message)
    tree.set_meta("qa95_capture_save_hash",FileAccess.get_sha256(p.condition_path))
    for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0;scene.focus=pad+Vector3.UP*.85;scene.zoom=4.8;scene._update_camera()
    for i in 13:assert(p.body_health.hit("native95_setup_"+str(i),"forearm_left","scratch",.06))
    demo.refresh();assert(demo.integrity()>0 and demo.integrity()<2)
    var victim=scene.zombie_world.actors.values()[1];_reset94(scene,victim,pad,Vector3(0,0,2));var hits=victim.hits
    for frame in 175:
        await tree.physics_frame
        if demo.state=="alive":victim.step(.04)
        _step95(scene,.04);await _capture95(scene,frame)
    assert(demo.state=="defeated" and victim.hits==hits+1 and not demo.fallback and not demo.resume_button.disabled)
    tree.set_meta("qa95_phase","capture_after_new");assert(demo.request_new())
func _capture95(scene: Node3D,index: int) -> void:
    await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
    var path="res://previews/demo95/%03d.png"%index;DirAccess.make_dir_recursive_absolute(path.get_base_dir());scene.get_viewport().get_texture().get_image().save_png(path)
