extends "res://personagem/revisao85.gd"
func _find_weapon(bag: RefCounted,definition: String) -> String:
    for uid in bag.items:
        if bag.items[uid].definition==definition:return uid
    return ""
func _settle86(p: CharacterBody3D) -> void:
    for frame in 600:
        p.action.advance(1.0/60);p.weapons.present()
        if p.action.state=="idle":return
    assert(false,"Inventory action did not finish")
func run(scene: Node3D) -> void:
    var p=scene.player;var bag=p.bag_inventory;var s=p.weapons
    var actors=scene.zombie_world.actors.values();var victim=actors[0]
    for z in actors:z.ai_enabled=false
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    scene.get_window().size=Vector2i(1440,900)
    p.condition_path="user://qa_weapons86.json"
    if "--weapons-reopen" in OS.get_cmdline_user_args():
        var loaded=p.load_condition();assert(loaded,p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/weapons86_expected.json"))
        assert(helper._same(p.session_save.snapshot(),expected))
        assert(p.combat.armed and s.held_definition=="metal_bar" and s.visual.visible)
        print("R86_FRESH_PROCESS_OK");scene.get_tree().quit();return
    var baton=_find_weapon(bag,"baton");var bar=_find_weapon(bag,"metal_bar")
    assert(not baton.is_empty() and not bar.is_empty() and bag.items.size()==15)
    p.update_nearby()
    assert(bag.can_touch(baton) and bag.can_touch(bar))
    if "--capture-weapons" in OS.get_cmdline_user_args():
        var ui=scene.game_ui
        ui.personal.visible=true;ui.nearby_wanted=true;ui.near_source=s.CACHE;ui.select_item(bar);ui.refresh()
        await _capture86(scene,"inventory_ground")
        ui.personal.visible=false;ui.nearby_wanted=false;ui.refresh();p.set_hud_open(false)
    var before=bag.snapshot()
    var accepted=p.equip_item(baton);assert(accepted)
    p.action.advance(.05);p.action.cancel();s.present()
    assert(helper._same(before,bag.snapshot()) and bag.equipped("main_hand").is_empty())
    accepted=p.equip_item(baton);assert(accepted)
    _settle86(p)
    assert(bag.equipped("main_hand")==baton and p.combat.armed and s.visual.definition=="baton" and s.visual.visible)
    accepted=p.equip_item(bar);assert(accepted)
    _settle86(p)
    assert(bag.equipped("main_hand")==bar and bag.items[baton].location==s.CACHE and bag.items[baton].x==1)
    # Put both in reachable ground cells near the controlled test field.
    var pad=_field(scene)
    bag.world_containers[s.CACHE].position=[pad.x,pad.y,pad.z]
    p.global_position=pad;p.update_nearby()
    for z in actors:z.global_position=Vector3(1000,0,1000)
    var cases=[]
    for definition in ["baton","metal_bar"]:
        var uid=baton if definition=="baton" else bar
        if bag.equipped("main_hand")!=uid:
            _player_idle(p);accepted=p.equip_item(uid);assert(accepted);_settle86(p)
        var stats=s.spec(uid)
        for fps in [30,60,120]:
            _player_idle(p);p.global_position=pad;p.avatar.rotation.y=0
            victim.restore(scene.zombie_world.initial[victim.identity]);victim.global_position=pad+Vector3(0,0,.85)
            var hp=victim.health;var stamina=p.condition_state.stamina
            accepted=p.request_attack();assert(accepted)
            assert(p.condition_state.stamina==stamina-stats.cost)
            p.combat.advance(.05);p.combat.cancel();s.present()
            assert(victim.health==hp)
            _player_idle(p);accepted=p.request_attack();assert(accepted)
            for frame in fps*3:
                p.combat.advance(1.0/fps);s.present();_joints(p.avatar)
                if not p.combat.is_attacking():break
            assert(p.combat.effect_succeeded and is_equal_approx(victim.health,hp-stats.damage))
            var after=victim.health;p.combat.advance(5);s.present();assert(victim.health==after)
            var hand=p.avatar.skeleton.global_transform*p.avatar.skeleton.get_bone_global_pose(p.avatar.skeleton.find_bone("Hand.R"))*s.visual.GRIP
            assert(s.visual.global_position.distance_to(hand.origin)<.00001)
            cases.append({"weapon":definition,"fps":fps,"once":true,"cancel_before_impact":true,"cost":stats.cost,"damage":stats.damage})
        _player_idle(p);p.condition_state.set_stamina(stats.cost-.5)
        var exhausted_stamina=p.condition_state.stamina
        accepted=p.request_attack();assert(not accepted and p.condition_state.stamina==exhausted_stamina)
        _player_idle(p);victim.restore(scene.zombie_world.initial[victim.identity]);victim.global_position=pad+Vector3(0,0,.75)
        accepted=p.request_attack("push");assert(accepted)
        p.combat.advance(3);s.present();assert(p.combat.effect_succeeded and victim.health==.48)
        # Target escapes during the tell; the chosen victim is never replaced.
        _player_idle(p);victim.restore(scene.zombie_world.initial[victim.identity]);victim.global_position=pad+Vector3(0,0,.85)
        accepted=p.request_attack();assert(accepted)
        victim.global_position=pad+Vector3(0,0,3)
        var alternate=actors[1];alternate.restore(scene.zombie_world.initial[alternate.identity]);alternate.global_position=pad+Vector3(0,0,.85)
        p.combat.advance(3);s.present();assert(not p.combat.effect_succeeded and victim.health==.48 and alternate.health==.48)
        alternate.global_position=Vector3(1000,0,1000)
        for frame in 2:await scene.get_tree().physics_frame
        # A wall appearing before impact prevents damage.
        _player_idle(p);victim.global_position=pad+Vector3(0,0,.85)
        accepted=p.request_attack();assert(accepted)
        _box(scene,pad+Vector3(0,1,.43),Vector3(3,2,.1))
        for frame in 2:await scene.get_tree().physics_frame
        p.combat.advance(3);assert(not p.combat.effect_succeeded and victim.health==.48)
        await _clear_boxes(scene)
    # Equipped instance cannot be swapped under an already committed attack.
    _player_idle(p);victim.global_position=pad+Vector3(0,0,.85)
    accepted=p.request_attack();assert(accepted)
    var snapshot=bag.snapshot()
    var held=bag.equipped("main_hand")
    var destination=bag.items[baton].duplicate(true)
    bag.items[held].location=s.CACHE;bag.items[held].x=4;bag.items[held].y=0;bag.items[held].rot=false
    bag.changed.emit()
    p.combat.advance(3);assert(victim.health==.48 and not p.combat.is_attacking())
    assert(bag.restore(snapshot));s.sync()
    # Consumption hides the object and releases hand control; cancelling restores it.
    _player_idle(p);p.condition_state.hunger=60
    var food=bag.add_at("food",1,"pockets",1,0,false)
    assert(not food.is_empty())
    accepted=p.use_item(food);assert(accepted);s.present();assert(not s.visual.visible)
    p.action.advance(.05);p.action.cancel();s.present()
    assert(s.visual.visible and p.avatar.hand_layer.label=="R_Cylinder" and bag.items.has(food))
    _player_idle(p)
    var baseline=load("res://personagem/personagem.tscn").instantiate();baseline.manual_update=true;scene.add_child(baseline);baseline.visible=false
    for actor in [p.avatar,baseline]:actor.set_motion("idle");actor.motion_clock=0;actor.motion_blend=1;actor.advance(0)
    var locomotion_baseline=0.0;var locomotion_delta=0.0;var locomotion_wrist=0.0
    for motion in ["idle","walk","run","crouch_idle"]:
        p.avatar.set_motion(motion);baseline.set_motion(motion)
        for frame in 16:
            baseline.advance(.08);p.avatar.advance(.08);p._update_equipment()
            for side in ["L","R"]:
                var values=p.avatar.arm_articulation.joints[side]
                var elbow=Vector3(values.elbow[0],values.elbow[1],values.elbow[2]);var wrist=Vector3(values.wrist[0],values.wrist[1],values.wrist[2])
                var reference=(baseline.arm_articulation._skin("UpperArm."+side)*elbow).distance_to(baseline.arm_articulation._skin("Forearm."+side)*elbow)
                var armed=(p.avatar.arm_articulation._skin("UpperArm."+side)*elbow).distance_to(p.avatar.arm_articulation._skin("Forearm."+side)*elbow)
                locomotion_baseline=maxf(locomotion_baseline,reference);locomotion_delta=maxf(locomotion_delta,absf(armed-reference))
                locomotion_wrist=maxf(locomotion_wrist,(p.avatar.arm_articulation._skin("Forearm."+side)*wrist).distance_to(p.avatar.arm_articulation._skin("Hand."+side)*wrist))
            var expected_hand=p.avatar.skeleton.global_transform*p.avatar.skeleton.get_bone_global_pose(p.avatar.skeleton.find_bone("Hand.R"))*s.visual.GRIP
            assert(s.visual.visible and s.visual.global_position.distance_to(expected_hand.origin)<.00001)
    baseline.queue_free()
    print("LOCOMOTION86 ",locomotion_baseline," delta ",locomotion_delta," wrist ",locomotion_wrist)
    assert(locomotion_delta<.0001 and locomotion_wrist<.015)
    _player_idle(p)
    accepted=p.request_reaction("hit_front");assert(accepted);p._update_equipment();assert(not s.visual.visible)
    p.reaction.advance(2);p.reaction.reset();p._update_equipment();assert(s.visual.visible)
    # The equipped mesh never replaces the support pose during a real crossing.
    for actor in actors:actor.global_position=Vector3(1000,0,1000)
    var low: Node3D
    for obstacle in p.map_traversals.obstacles:
        if obstacle.has_meta("fence78") and not obstacle.model.high:low=obstacle;break
    assert(low!=null)
    p.avatar.set_motion("idle");p.avatar.motion_clock=0;p.avatar.motion_blend=1;p.avatar.advance(0)
    await _place(scene,low,-1)
    accepted=p.request_cross(low);assert(accepted,p.traversal.message)
    for frame in 400:
        p.traversal.advance(1.0/60);p._update_equipment();_joints(p.avatar)
        if not p.traversal.is_active():break
        assert(not s.visual.visible and p.avatar.hand_layer.label!="R_Cylinder")
    assert(p.traversal.effect_succeeded and s.visual.visible and bag.equipped("main_hand")==held)
    p.global_position=pad;p.update_nearby()
    # Storing in a manually chosen cell and re-equipping still uses real inventory gestures.
    _player_idle(p);p.update_nearby()
    accepted=p.place_item(held,s.CACHE,4,0,false);assert(accepted)
    _settle86(p);assert(bag.equipped("main_hand").is_empty() and not s.visual.visible and not p.combat.armed)
    accepted=p.equip_item(bar);assert(accepted);_settle86(p)
    # Stable save restores both slot and visible model.
    _player_idle(p);p.global_position=scene.spawn
    for z in actors:z.restore(scene.zombie_world.initial[z.identity])
    accepted=p.save_condition();assert(accepted,p.inventory_message)
    var saved=p.session_save.snapshot()
    if FileAccess.file_exists(p.condition_path+".bak"):DirAccess.remove_absolute(p.condition_path+".bak")
    var invalid=saved.duplicate(true);invalid.weapons86.loot_seeded="yes"
    helper._write(p.condition_path,invalid);var unchanged=p.session_save.snapshot()
    assert(not p.load_condition() and helper._same(unchanged,p.session_save.snapshot()))
    var carried=saved.duplicate(true);carried.erase("weapons86")
    carried.inventory.items.erase(bar);carried.inventory.items[baton].location="slot:main_hand";carried.inventory.world_containers.erase(s.CACHE)
    helper._write(p.condition_path,carried);accepted=p.load_condition();assert(accepted)
    assert(bag.items.values().filter(func(item):return item.definition=="baton").size()==1 and bag.equipped("main_hand")==baton)
    var legacy=saved.duplicate(true);legacy.erase("weapons86")
    for uid in legacy.inventory.items.keys():
        if legacy.inventory.items[uid].definition in ["baton","metal_bar"]:legacy.inventory.items.erase(uid)
    legacy.inventory.world_containers.erase(s.CACHE)
    helper._write(p.condition_path,legacy)
    accepted=p.load_condition();assert(accepted,p.inventory_message)
    assert(bag.items.values().filter(func(item):return item.definition=="baton").size()==1 and bag.items.values().filter(func(item):return item.definition=="metal_bar").size()==1)
    for uid in legacy.inventory.items:assert(helper._same(bag.items[uid],legacy.inventory.items[uid]))
    var updated=p.session_save.snapshot()
    helper._write(p.condition_path,updated);accepted=p.load_condition();assert(accepted)
    assert(helper._same(updated,p.session_save.snapshot()))
    # Emptying the content after its one-time introduction never respawns the weapons.
    var empty=updated.duplicate(true)
    for uid in empty.inventory.items.keys():
        if empty.inventory.items[uid].definition in ["baton","metal_bar"]:empty.inventory.items.erase(uid)
    empty.inventory.world_containers.erase(s.CACHE)
    helper._write(p.condition_path,empty);accepted=p.load_condition();assert(accepted)
    assert(_find_weapon(bag,"baton").is_empty() and _find_weapon(bag,"metal_bar").is_empty())
    helper._write(p.condition_path,saved);accepted=p.load_condition();assert(accepted)
    assert(p.combat.armed and s.held_definition=="metal_bar" and s.visual.visible)
    helper._write("res://qa/weapons86_expected.json",p.session_save.snapshot())
    assert(max_elbow<.025 and max_wrist<.015)
    var checks={"cases":cases,"equip_cancel_atomic":true,"manual_swap":true,"grip_socket":true,"moving_target_miss":true,"no_target_reassignment":true,"wall_at_impact":true,"equipped_instance_locked":true,"consumption_hides_and_restores":true,"manual_store":true,"insufficient_stamina":true,"armed_push_no_weapon_damage":true,"movement_grip":true,"locomotion_reference_baseline":locomotion_baseline,"locomotion_elbow_delta":locomotion_delta,"locomotion_wrist":locomotion_wrist,"reaction_hides_and_restores":true,"crossing_hands_free":true,"armed_roundtrip":true,"r85_migration_preserves_stock":true,"one_time_content":true,"existing_weapon_not_duplicated":true,"invalid_marker_atomic":true,"max_elbow":max_elbow,"max_wrist":max_wrist}
    helper._write("res://qa/weapons86.json",checks)
    if "--capture-weapons" in OS.get_cmdline_user_args():
        scene.set_process(false)
        p.global_position=pad;p.update_nearby();_player_idle(p)
        for definition in ["baton","metal_bar"]:
            var selected=_find_weapon(bag,definition)
            if bag.equipped("main_hand")!=selected:
                var equipped=p.equip_item(selected);assert(equipped);_settle86(p)
            for actor in actors:actor.ai_enabled=false;actor.global_position=Vector3(1000,0,1000)
            victim.restore(scene.zombie_world.initial[victim.identity]);victim.global_position=pad+Vector3(.85,0,0);victim.avatar.rotation.y=-PI/2;victim.cooldown=.4;victim.ai_enabled=true
            p.avatar.rotation.y=PI/2;p.set_physics_process(true);p.condition_state.set_stamina(100)
            _camera84(scene,pad+Vector3(.4,.9,0),4.4,Vector3(4,3,5))
            var swung=p.request_attack();assert(swung)
            for frame in 80:
                for tick in 4:await scene.get_tree().physics_frame
                if not p.combat.is_attacking() and victim.health>0 and not p.reaction.is_active():p.request_attack()
                await _capture86(scene,definition+"/%03d"%frame)
            victim.ai_enabled=false;p.set_physics_process(false);_player_idle(p)
        for actor in actors:actor.ai_enabled=false;actor.global_position=Vector3(1000,0,1000)
        _player_idle(p);p.global_position=pad;p.avatar.rotation.y=PI/2
        for index in 48:
            p.avatar.set_motion("walk" if index<24 else "run");p.avatar.advance(.04);p._update_equipment()
            await _capture86(scene,"locomotion/%03d"%index)
        scene.game_ui.personal.visible=true;scene.game_ui.nearby_wanted=true;scene.game_ui.near_source=s.CACHE
        scene.game_ui.select_item(bag.equipped("main_hand"));scene.game_ui.refresh()
        await _capture86(scene,"inventory_equipped")
    print("R86_WEAPONS_OK ",checks)
    scene.get_tree().quit()

func _capture86(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/weapons86/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
