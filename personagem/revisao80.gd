extends "res://personagem/revisao75.gd"
func run(scene: Node3D) -> void:
    var p=scene.player
    var s=p.survival
    var c=p.condition_state
    var bag=p.bag_inventory
    p.scripted=true
    p.set_physics_process(false)
    s.set_physics_process(false)
    var cases=[]
    for fps in [30,60,120]:
        for definition in ["food","water","medicine","bandage"]:
            p.action.cancel()
            c.hunger=70;c.thirst=80;c.medicine_remaining=0
            if definition in ["medicine","bandage"]:
                assert(p.body_health.hit("qa80_%s_%d"%[definition,fps],"forearm_left","cut",.1))
            s.update_pain()
            var uid=bag.add_at(definition,1,"pockets",1,0,false)
            assert(not uid.is_empty(),definition)
            var before=c.snapshot()
            var inventory=bag.snapshot()
            assert(p.use_item(uid))
            p.action.advance(.03)
            p.action.cancel()
            assert(c.snapshot()==before and bag.snapshot()==inventory)
            assert(p.use_item(uid))
            for frame in fps*7:
                p.action.advance(1.0/fps)
                if p.action.state=="idle":break
            assert(p.action.state=="idle" and p.action.effect_succeeded and not bag.items.has(uid),definition)
            if definition=="food":assert(c.hunger==40)
            if definition=="water":assert(c.thirst==45)
            if definition=="medicine":assert(c.medicine_remaining==120 and c.pain()<c.pain_base)
            if definition=="bandage":assert(c.forearm_dressed)
            var after=c.snapshot()
            p.action.advance(10)
            assert(c.snapshot()==after)
            cases.append({"item":definition,"fps":fps,"once":true,"cancel_atomic":true})
    c.hunger=0
    var uid=bag.add_at("food",1,"pockets",1,0,false)
    assert(not p.use_item(uid) and bag.items.has(uid))
    bag.items.erase(uid)
    c.medicine_remaining=100
    uid=bag.add_at("medicine",1,"pockets",1,0,false)
    assert(not p.use_item(uid) and bag.items.has(uid))
    bag.items.erase(uid)
    assert(p.body_health.hit("qa80_revision","forearm_left","cut",.1))
    uid=bag.add_at("bandage",1,"pockets",1,0,false)
    assert(p.use_item(uid))
    assert(p.body_health.hit("qa80_new_wound","forearm_left","cut",.1))
    p.action.advance(10)
    assert(not p.action.effect_succeeded and bag.items.has(uid) and not c.forearm_dressed)
    bag.items.erase(uid)
    c.hunger=70
    uid=bag.add_at("food",1,"pockets",1,0,false)
    assert(p.use_item(uid))
    assert(bag.drop_at(uid,0,0,false))
    p.action.advance(10)
    assert(not p.action.effect_succeeded and c.hunger==70 and bag.items.has(uid))
    c.medicine_remaining=0;s.update_pain()
    var untreated=c.recovery_factor()
    c.medicine_remaining=120
    assert(c.recovery_factor()>untreated)
    var wounds=p.body_health.snapshot()
    c.tick_needs(121)
    assert(c.medicine_remaining==0 and p.body_health.snapshot()==wounds)
    p.paused=true
    var before=c.snapshot()
    s._physics_process(10)
    assert(c.snapshot()==before)
    p.paused=false
    c.hunger=100;c.thirst=100;c.pain_base=100;c.medicine_remaining=0
    c.set_stamina(10)
    c.set_stamina(39.5)
    c.advance(.1,false,false,false)
    assert(c.stamina<40 and c.exhausted)
    c.set_stamina(100)
    s.update_pain()
    c.hunger=42.125;c.thirst=63.75;c.medicine_remaining=17.25
    p.condition_path="user://qa_health_effects_r80.json"
    p.combat.set_guard(false)
    assert(p.save_condition())
    var saved=c.snapshot()
    c.hunger=99;c.thirst=99;c.medicine_remaining=0
    var loaded=p.load_condition()
    assert(loaded)
    for field in ["hunger","thirst","medicine_remaining","stamina","forearm_injury"]:assert(is_equal_approx(float(c.snapshot()[field]),float(saved[field])))
    assert(c.damage_events.size()==saved.damage_events.size() and c.forearm_revision==saved.forearm_revision and c.forearm_dressed==saved.forearm_dressed)
    var profile=JSON.parse_string(FileAccess.get_file_as_string(p.condition_path))
    if FileAccess.file_exists(p.condition_path+".bak"):DirAccess.remove_absolute(p.condition_path+".bak")
    var invalid=profile.duplicate(true)
    invalid.condition.hunger=-1
    FileAccess.open(p.condition_path,FileAccess.WRITE).store_string(JSON.stringify(invalid))
    var old_bag=bag.snapshot();before=c.snapshot();var old_body=p.body_health.snapshot()
    assert(not p.load_condition() and c.snapshot()==before and bag.snapshot()==old_bag and p.body_health.snapshot()==old_body)
    profile.condition.version=2
    profile.condition.erase("hunger");profile.condition.erase("thirst");profile.condition.erase("medicine_remaining")
    FileAccess.open(p.condition_path,FileAccess.WRITE).store_string(JSON.stringify(profile))
    assert(p.load_condition() and c.hunger==25 and c.thirst==25 and c.medicine_remaining==0 and is_equal_approx(c.forearm_injury,saved.forearm_injury))
    var result={"cases":cases,"full_need_refused":true,"medicine_no_stacking":true,"new_wound_invalidates_dressing":true,"item_moved_before_effect":true,"medicine_changes_recovery":true,"medicine_expires_without_healing":true,"pause":true,"profile_v3":true,"active_timer_roundtrip":true,"legacy_v2":true,"invalid_load_atomic":true,"recovery_hysteresis":true}
    if "--capture-health-effects" in OS.get_cmdline_user_args():
        scene.set_process(false)
        p.body_health.records.clear()
        c.forearm_injury=0;c.forearm_dressed=false;c.forearm_revision=0;c.damage_events.clear()
        scene.get_window().size=Vector2i(1440,900)
        var point=scene.world_items.house.home.model.to_global(Vector3(2.86,.01,-7))
        var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1)
        var floor=scene.get_world_3d().direct_space_state.intersect_ray(ray)
        point.y=floor.position.y+.01
        p.global_position=point
        p.avatar.rotation.y=0
        scene.camera.size=3.3
        scene.camera.global_position=point+Vector3(-4,3,5)
        scene.camera.look_at(point+Vector3.UP*.9)
        for index in 4:
            var definition: String=["food","water","medicine","bandage"][index]
            c.hunger=65;c.thirst=65;c.medicine_remaining=0
            if definition in ["medicine","bandage"]:p.body_health.hit("capture80_%d"%index,"forearm_left","cut",.1)
            uid=bag.add_at(definition,1,"pockets",1,0,false)
            assert(p.use_item(uid))
            for frame in 55:
                p.action.advance(.1)
                await _capture80(scene,"%d/%02d"%[index,frame])
            assert(p.action.state=="idle" and p.action.effect_succeeded)
            if index==2:
                scene.game_ui.toggle(1)
                s.refresh()
                await _capture80(scene,"health_medicine")
                scene.game_ui.toggle(1)
        scene.game_ui.toggle(1)
        s.refresh()
        await _capture80(scene,"health")
    FileAccess.open("res://qa/health80.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R80_HEALTH_OK ",result)
    scene.get_tree().quit()
func _capture80(scene: Node3D, name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/health80/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
