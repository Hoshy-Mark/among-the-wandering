extends "res://personagem/revisao86.gd"
func _shoot87(p: CharacterBody3D,fps: int=60) -> void:
    var accepted=p.request_attack();assert(accepted,p.inventory_message)
    for step in fps*2:
        p.combat.advance(1.0/fps);p.weapons.present();_joints(p.avatar)
        if not p.combat.is_attacking():return
    assert(false)
func run(scene: Node3D) -> void:
    var p=scene.player;var bag=p.bag_inventory;var s=p.weapons;var actors=scene.zombie_world.actors.values();var victim=actors[0]
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    for z in actors:z.ai_enabled=false
    scene.get_window().size=Vector2i(1440,900);p.condition_path="user://qa_firearms87.json"
    if "--firearms-reopen" in OS.get_cmdline_user_args():
        var accepted=p.load_condition();assert(accepted,p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/firearms87_expected.json"))
        assert(helper._same(expected,p.session_save.snapshot()))
        print("R87_FRESH_PROCESS_OK");scene.get_tree().quit();return
    var pistol=_find_weapon(bag,"pistol");var ammo=_find_weapon(bag,"ammo_pistol")
    assert(bag.items.size()==17 and s.loaded(pistol)==0)
    p.update_nearby();assert(bag.can_touch(pistol) and bag.can_touch(ammo))
    var accepted=p.equip_item(pistol);assert(accepted);_settle86(p)
    assert(bag.equipped("main_hand")==pistol and s.visual.definition=="pistol" and p.combat.firearm_mode)
    assert(not p.request_attack() and not p.map_combat.reload_weapon()) # Ground ammunition is not owned.
    accepted=p.place_item(ammo,"pockets",2,0,false);assert(accepted);_settle86(p)
    var stock=bag.snapshot();accepted=p.map_combat.reload_weapon();assert(accepted)
    p.action.advance(.05);p.action.cancel();assert(helper._same(stock,bag.snapshot()) and s.loaded(pistol)==0)
    accepted=p.map_combat.reload_weapon();assert(accepted)
    p.action.advance(.05);assert(not s.visual.visible)
    _settle86(p);assert(s.loaded(pistol)==6 and bag.items[ammo].count==12 and s.visual.visible)
    assert(not p.map_combat.reload_weapon())
    p.combat.set_guard(true);p.combat.advance(.3);s.present()
    assert(s.visual.barrel_direction().dot(p.avatar.global_basis.z.normalized())>.995)
    _player_idle(p)
    var pad=_field(scene);p.global_position=pad
    for z in actors:z.global_position=Vector3(1000,0,1000)
    var cases=[]
    for fps in [30,60,120]:
        _pose(scene,victim,pad,Vector3(0,0,3));s.rounds[pistol]=6
        for frame in 2:await scene.get_tree().physics_frame
        var before=p.condition_state.stamina
        _shoot87(p,fps)
        assert(p.combat.effect_succeeded and is_equal_approx(victim.health,.20) and s.loaded(pistol)==5)
        assert(p.condition_state.stamina==before-1)
        p.combat.advance(5);assert(s.loaded(pistol)==5 and is_equal_approx(victim.health,.20))
        cases.append({"fps":fps,"one_round":true,"one_hit":true})
    # Cancel before the effect preserves ammunition; effort was spent on preparation.
    _player_idle(p);s.rounds[pistol]=6;accepted=p.request_attack();assert(accepted)
    p.combat.advance(.05);p.combat.cancel();assert(s.loaded(pistol)==6)
    # Empty-space shot still spends one round and alerts living neighbours.
    _player_idle(p);victim.global_position=pad+Vector3(3,0,0);victim.state="idle";victim.memory=0
    _shoot87(p);assert(not p.combat.effect_succeeded and s.loaded(pistol)==5 and victim.memory==12 and victim.search_remaining==12 and victim.last_known==pad)
    # Target moves out of the cone; another target cannot inherit the shot.
    _pose(scene,victim,pad,Vector3(0,0,3));s.rounds[pistol]=6
    for frame in 2:await scene.get_tree().physics_frame
    accepted=p.request_attack();assert(accepted)
    victim.global_position=pad+Vector3(3,0,3)
    var alternate=actors[1];alternate.restore(scene.zombie_world.initial[alternate.identity]);alternate.global_position=pad+Vector3(0,0,3)
    for frame in 2:await scene.get_tree().physics_frame
    p.combat.advance(2);assert(not p.combat.effect_succeeded and victim.health==.48 and alternate.health==.48 and s.loaded(pistol)==5)
    alternate.global_position=Vector3(1000,0,1000)
    # A new wall before the effect blocks the shot but ammunition is expended.
    _pose(scene,victim,pad,Vector3(0,0,3));s.rounds[pistol]=6
    for frame in 2:await scene.get_tree().physics_frame
    accepted=p.request_attack();assert(accepted)
    _box(scene,pad+Vector3(0,1,1.5),Vector3(3,2,.1))
    for frame in 2:await scene.get_tree().physics_frame
    p.combat.advance(2);assert(not p.combat.effect_succeeded and victim.health==.48 and s.loaded(pistol)==5)
    await _clear_boxes(scene)
    # One actor physically in front blocks damage to the locked receiver.
    _pose(scene,victim,pad,Vector3(0,0,3));s.rounds[pistol]=6
    for frame in 2:await scene.get_tree().physics_frame
    accepted=p.request_attack();assert(accepted)
    alternate.global_position=pad+Vector3(0,0,1.5)
    for frame in 2:await scene.get_tree().physics_frame
    p.combat.advance(2);assert(not p.combat.effect_succeeded and victim.health==.48 and alternate.health==.48)
    alternate.global_position=Vector3(1000,0,1000)
    # No attack from a stale equipped UID, and no free ammunition when reload stock changes.
    _player_idle(p);s.rounds[pistol]=2;stock=bag.snapshot()
    accepted=p.map_combat.reload_weapon();assert(accepted)
    bag.items[ammo].count-=1
    _settle86(p);assert(s.loaded(pistol)==2 and bag.items[ammo].count==11)
    bag.restore(stock,false);bag.changed.emit()
    _player_idle(p);accepted=p.map_combat.reload_weapon();assert(accepted);_settle86(p)
    assert(s.loaded(pistol)==6 and bag.items[ammo].count==8)
    # Cancel after effect retains the already transferred rounds.
    s.rounds[pistol]=5;_player_idle(p);accepted=p.map_combat.reload_weapon();assert(accepted)
    for frame in 300:
        p.action.advance(1.0/60)
        if p.action.effect_done:break
    p.action.cancel();s.present();assert(s.loaded(pistol)==6 and bag.items[ammo].count==7)
    _player_idle(p);s.rounds[pistol]=0
    assert(not p.request_attack());s.rounds[pistol]=3
    # The loaded instance remains the same after manual storing and re-equipping.
    _player_idle(p);p.global_position=scene.spawn;p.update_nearby()
    accepted=p.place_item(pistol,s.FIRE_CACHE,0,0,false);assert(accepted);_settle86(p)
    assert(s.loaded(pistol)==3 and not s.visual.visible and not p.combat.firearm_mode)
    accepted=p.equip_item(pistol);assert(accepted);_settle86(p);assert(s.loaded(pistol)==3)
    stock=bag.snapshot();accepted=p.request_attack();assert(accepted)
    bag.items[pistol].location=s.FIRE_CACHE;bag.items[pistol].x=0;bag.items[pistol].y=0;bag.items[pistol].rot=false
    bag.changed.emit();p.combat.advance(2);assert(not p.combat.is_attacking() and s.loaded(pistol)==3)
    bag.restore(stock,false);bag.changed.emit();_player_idle(p)
    accepted=p.request_reaction("hit_front");assert(accepted);p._update_equipment();assert(not s.visual.visible)
    p.reaction.advance(2);p.reaction.reset();p._update_equipment();assert(s.visual.visible and s.loaded(pistol)==3)
    # One real low-fence passage, including release of the firearm hand pose.
    for z in actors:z.global_position=Vector3(1000,0,1000)
    var low: Node3D
    for obstacle in p.map_traversals.obstacles:
        if obstacle.has_meta("fence78") and not obstacle.model.high:low=obstacle;break
    p.avatar.set_motion("idle");p.avatar.motion_clock=0;p.avatar.motion_blend=1;p.avatar.advance(0)
    await _place(scene,low,-1);accepted=p.request_cross(low);assert(accepted)
    for frame in 400:
        p.traversal.advance(1.0/60);p._update_equipment();_joints(p.avatar)
        if not p.traversal.is_active():break
        assert(not s.visual.visible and p.avatar.hand_layer.label!="R_Cylinder")
    assert(p.traversal.effect_succeeded and s.visual.visible and s.loaded(pistol)==3)
    # Save and restore exact loaded counts, including stored pistols.
    for z in actors:z.restore(scene.zombie_world.initial[z.identity]);z.ai_enabled=false
    p.global_position=scene.spawn;p.avatar.rotation.y=0;_player_idle(p)
    accepted=p.save_condition();assert(accepted,p.inventory_message)
    var saved=p.session_save.snapshot();s.rounds[pistol]=0
    accepted=p.load_condition();assert(accepted and s.loaded(pistol)==3)
    var bak=p.condition_path+".bak"
    if FileAccess.file_exists(bak):DirAccess.remove_absolute(bak)
    for bad in [-1,7,1.5,"3",true]:
        var corrupt=saved.duplicate(true);corrupt.firearms87.rounds[pistol]=bad
        helper._write(p.condition_path,corrupt);var before=p.session_save.snapshot()
        accepted=p.load_condition();assert(not accepted and helper._same(before,p.session_save.snapshot()))
    var orphan=saved.duplicate(true);orphan.firearms87.rounds.ghost=1
    helper._write(p.condition_path,orphan);accepted=p.load_condition();assert(not accepted)
    var legacy=saved.duplicate(true);legacy.erase("firearms87")
    for uid in legacy.inventory.items.keys():
        if legacy.inventory.items[uid].definition in ["pistol","ammo_pistol"]:legacy.inventory.items.erase(uid)
    legacy.inventory.world_containers.erase(s.FIRE_CACHE)
    helper._write(p.condition_path,legacy);accepted=p.load_condition();assert(accepted,p.inventory_message)
    for uid in legacy.inventory.items:assert(helper._same(legacy.inventory.items[uid],bag.items[uid]))
    assert(_find_weapon(bag,"pistol")!="" and s.loaded(_find_weapon(bag,"pistol"))==0)
    var empty=p.session_save.snapshot()
    for uid in empty.inventory.items.keys():
        if empty.inventory.items[uid].definition in ["pistol","ammo_pistol"]:empty.inventory.items.erase(uid)
    empty.firearms87.rounds={};empty.inventory.world_containers.erase(s.FIRE_CACHE)
    helper._write(p.condition_path,empty);accepted=p.load_condition();assert(accepted and _find_weapon(bag,"pistol").is_empty())
    helper._write(p.condition_path,saved);accepted=p.load_condition();assert(accepted)
    helper._write("res://qa/firearms87_expected.json",p.session_save.snapshot())
    assert(max_elbow<.025 and max_wrist<.015)
    var checks={"cases":cases,"empty_refused":true,"owned_ammo_only":true,"barrel_aligned":true,"reload_cancel_before":true,"reload_cancel_after":true,"reload_revalidate":true,"full_refused":true,"miss_spends_ammo":true,"noise":true,"no_retarget":true,"wall":true,"actor_blocks":true,"roundtrip":true,"stored_rounds_preserved":true,"equipped_uid_locked":true,"reaction_hands_free":true,"crossing_hands_free":true,"invalid_rounds_atomic":true,"orphan_refused":true,"legacy_stock_preserved":true,"no_restock":true,"max_elbow":max_elbow,"max_wrist":max_wrist}
    helper._write("res://qa/firearms87.json",checks)
    if "--capture-firearms" in OS.get_cmdline_user_args():await _native87(scene,pad,pistol,ammo)
    print("R87_FIREARMS_OK ",checks);scene.get_tree().quit()
func _native87(scene: Node3D,pad: Vector3,pistol: String,ammo: String) -> void:
    var p=scene.player;var s=p.weapons;var bag=p.bag_inventory;var actors=scene.zombie_world.actors.values();var victim=actors[0]
    scene.set_process(false);p.global_position=pad;p.avatar.rotation.y=0;_player_idle(p)
    _camera84(scene,pad+Vector3(0,.9,1.2),5.5,Vector3(4,3,5))
    for z in actors:z.global_position=Vector3(1000,0,1000)
    victim.restore(scene.zombie_world.initial[victim.identity]);victim.global_position=pad+Vector3(0,0,3);victim.avatar.rotation.y=PI
    for tick in 2:await scene.get_tree().physics_frame
    s.rounds[pistol]=6;var accepted=p.request_attack();assert(accepted)
    for frame in 54:
        p.combat.advance(.04);s.present();victim.step(.04)
        if frame==24:accepted=p.request_attack();assert(accepted)
        await _capture87(scene,"shoot/%03d"%frame)
    assert(victim.health<=.0001 and s.loaded(pistol)==4,"Native sequence must resolve two actual shots")
    _player_idle(p);s.rounds[pistol]=0;accepted=p.map_combat.reload_weapon();assert(accepted)
    for frame in 54:
        p.action.advance(.04);s.present();await _capture87(scene,"reload/%03d"%frame)
    assert(p.action.state=="idle" and s.loaded(pistol)>0)
    for z in actors:z.global_position=Vector3(1000,0,1000)
    _player_idle(p);p.combat.set_guard(true);p.combat.advance(.3);s.present()
    assert(s.visual.barrel_direction().dot(p.avatar.global_basis.z.normalized())>.995)
    for view in [["front",Vector3(0,1,5)],["side",Vector3(-5,2,0)],["isometric",Vector3(4,3,5)]]:
        _camera84(scene,pad+Vector3(0,1,0),2.8,view[1]);await _capture87(scene,str(view[0]))
    scene.game_ui.personal.visible=true;scene.game_ui.nearby_wanted=false
    scene.game_ui.select_item(pistol);scene.game_ui.refresh();await _capture87(scene,"inventory")
func _capture87(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/firearms87/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
