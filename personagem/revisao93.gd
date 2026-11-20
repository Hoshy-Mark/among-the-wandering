extends "res://personagem/revisao92.gd"
func _settle93(scene: Node3D,fps: int=60) -> void:
    for frame in fps*3:
        _step88(scene,1.0/fps)
        if scene.player.action.state=="idle":return
    assert(false,"Quick gesture did not finish")
func run(scene: Node3D) -> void:
    var p=scene.player;var bag=p.bag_inventory;var aim=scene.shoulder;var quick=p.get_node("Atalhos93")
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false);scene.set_process(false)
    aim.set_process(false);aim.set_physics_process(false);aim.scripted=true;quick.scripted=true;p.map_combat.effects.set_physics_process(false)
    scene.get_window().size=Vector2i(1280,800);p.condition_path="user://qa_quick93.json"
    for z in scene.zombie_world.actors.values():z.ai_enabled=false
    if "--quick-capture-only" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message);await _native93(scene)
        print("R93_NATIVE_OK");scene.get_tree().quit();return
    if "--quick-reopen" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/quick93_expected.json"))
        assert(helper._same(expected,p.session_save.snapshot()) and quick.bindings.size()==3)
        print("R93_FRESH_PROCESS_OK");scene.get_tree().quit();return
    for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
    var migration=JSON.parse_string(FileAccess.get_file_as_string("res://qa/arsenal92_expected.json"))
    assert(not p.session_save.prepare(migration,false).is_empty() and p.session_save.pending_bindings.is_empty())
    var pistol=_find_weapon(bag,"pistol");var revolver=_find_weapon(bag,"revolver");var carbine=_find_weapon(bag,"carbine");var baton=_find_weapon(bag,"baton")
    var ids={"left":pistol,"up":carbine,"right":baton};var count=bag.items.size();var rounds=p.weapons.rounds.duplicate(true)
    assert(not quick.bind("up",pistol) and not quick.activate("down"))
    for direction in ids:
        p.update_nearby();assert(quick.bind(direction,ids[direction]),p.inventory_message)
        assert(not bag.owned(ids[direction]));_step88(scene,.10);assert(not bag.owned(ids[direction]))
        assert(not quick.activate(direction));_settle93(scene)
        assert(bag.equipped("quick_"+direction)==ids[direction] and bag.owned(ids[direction]))
    assert(bag.items.size()==count and p.weapons.rounds==rounds)
    assert(quick.carried.up.visible and not quick.carried.up.global_transform.origin.is_equal_approx(Vector3.ZERO))
    var cases=[]
    for fps in [30,60,120]:
        for direction in ["left","up","right","up","left","left"]:
            var before=bag.snapshot();var old=p.weapons.rounds.duplicate(true);var held=bag.equipped("main_hand")
            assert(quick.activate(direction),p.inventory_message)
            _step88(scene,.10);assert(helper._same(before,bag.snapshot()))
            _settle93(scene,fps)
            var expected="" if held==ids[direction] else ids[direction]
            assert(bag.equipped("main_hand")==expected and p.weapons.rounds==old and bag.items.size()==count)
            assert(p.weapons.visual.visible==(not expected.is_empty()),str([direction,expected,p.weapons.held_uid,p.weapons.spec(p.weapons.held_uid),p.action.state,p.flow.queue,p.traversal.state,p.reaction.state,p.weapons.visual.visible]))
            cases.append({"fps":fps,"direction":direction,"hand":expected,"one_transfer":true})
    # Cancel before/after the transfer: one atomic inventory transaction.
    assert(quick.activate("left"));_step88(scene,.10);var untouched=bag.snapshot();p.action.cancel();assert(helper._same(untouched,bag.snapshot()))
    assert(quick.activate("left"));_step88(scene,.50);assert(bag.equipped("main_hand")==pistol);p.action.cancel();assert(bag.equipped("main_hand")==pistol)
    assert(quick.activate("left"));_settle93(scene)
    # Real arrow handler: ignore echoes and consume a single keypress.
    var event=InputEventKey.new();event.physical_keycode=KEY_UP;event.pressed=true;event.echo=true
    quick._unhandled_key_input(event);assert(p.action.state=="idle")
    event.echo=false;quick._unhandled_key_input(event);assert(p.action.state!="idle");_settle93(scene);assert(bag.equipped("main_hand")==carbine)
    assert(not quick.carried.up.visible)
    var rifle_ammo=_find_weapon(bag,"ammo_carbine");assert(p.place_item(rifle_ammo,"pockets",2,1,false));_settle93(scene)
    assert(p.weapons.reload_weapon());_settle93(scene)
    var field=_field(scene);var victim=scene.zombie_world.actors.values()[0]
    p.global_position=field;p.avatar.rotation.y=0;scene.focus=field+Vector3.UP*.85;scene._update_camera();_pose91(scene,victim,field)
    for tick in 2:await scene.get_tree().physics_frame
    assert(aim.set_aim(true));_step88(scene,.5);_look88(scene,victim.global_position+Vector3.UP*1.19)
    for frame in 60:_step88(scene,1.0/60)
    aim.rng.seed=93;assert(p.request_attack())
    for frame in 60:_step88(scene,1.0/60)
    assert(p.map_combat.last_shot.hit and p.map_combat.last_shot.event.zone=="chest" and p.weapons.loaded(carbine)==7)
    victim.global_position=Vector3(1000,0,1000)
    # Aim to melee exits shoulder mode; a draw never fires or consumes ammunition.
    assert(quick.activate("right"));_settle93(scene)
    _step88(scene,.5);assert(not aim.holding and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and bag.equipped("main_hand")==baton)
    assert(quick.activate("right"));_settle93(scene)
    p.global_position=scene.spawn
    # Rebind only after holstering, preserving the outgoing weapon in the incoming exact cells.
    p.update_nearby();assert(quick.bind("left",revolver));_settle93(scene)
    assert(quick.bindings.left==revolver and not bag.owned(pistol) and bag.equipped("quick_left")==revolver)
    assert(quick.activate("left"));_settle93(scene);assert(not quick.bind("left",pistol))
    assert(quick.activate("left"));_settle93(scene);p.update_nearby();assert(quick.bind("left",pistol));_settle93(scene)
    ids.left=pistol
    # Refuse swaps during reload, traversal and reaction; preserve all items.
    var ammo=_find_weapon(bag,"ammo_pistol");assert(p.place_item(ammo,"pockets",2,0,false));_settle93(scene)
    assert(quick.activate("left"));_settle93(scene);assert(p.weapons.reload_weapon());assert(not quick.activate("up"));_settle93(scene)
    var loaded=p.weapons.loaded(pistol);assert(loaded==6)
    assert(quick.activate("right"));_settle93(scene);assert(p.weapons.loaded(pistol)==loaded)
    assert(quick.activate("right"));_settle93(scene)
    assert(p.reaction.begin("hit_front"));assert(not quick.activate("left"));p.reaction.reset();_player_idle(p)
    p.traversal.state="align";assert(not quick.activate("left"));p.traversal.state="idle"
    p.set_hud_open(true);event.physical_keycode=KEY_LEFT;quick._unhandled_key_input(event);assert(p.action.state=="idle");p.set_hud_open(false)
    var before_external=bag.snapshot();var empty_hand=bag.equipped("main_hand")
    assert(quick.activate("left"));bag.items[ammo].count-=1;bag.changed.emit();_settle93(scene)
    assert(not p.action.effect_succeeded and bag.equipped("main_hand")==empty_hand and bag.items[ammo].count==before_external.items[ammo].count-1)
    assert(bag.restore(before_external,false));bag.changed.emit()
    # Dropping a bound weapon removes its shortcut and carried copy instead of recalling it remotely.
    var baseline=bag.snapshot();var links=quick.bindings.duplicate(true)
    p.update_nearby();assert(p.place_item(baton,"drop_here",0,50,false));_settle93(scene)
    assert(not quick.bindings.has("right") and not quick.activate("right") and not quick.carried.right.visible)
    assert(bag.restore(baseline,false));bag.changed.emit();quick.bindings=links;quick.sync()
    scene.game_ui.close_nearby();scene.game_ui.personal.visible=false;scene.game_ui.windows[1].visible=false;p.set_hud_open(false)
    await _zombie_interrupt93(scene)
    # Stable snapshot, migration and malformed link rejection without live mutation.
    p.global_position=scene.spawn;_player_idle(p)
    for z in scene.zombie_world.actors.values():z.restore(scene.zombie_world.initial[z.identity]);z.ai_enabled=false
    assert(p.save_condition(),p.inventory_message);var saved=p.session_save.snapshot()
    var bad=saved.duplicate(true);bad.quick93.bindings.up=pistol;assert(p.session_save.prepare(bad,false).is_empty())
    bad=saved.duplicate(true);bad.quick93.bindings.left="missing";assert(p.session_save.prepare(bad,false).is_empty())
    bad=saved.duplicate(true);bad.quick93.bindings.erase("up");assert(p.session_save.prepare(bad,false).is_empty())
    assert(p.load_condition() and helper._same(saved,p.session_save.snapshot()))
    helper._write("res://qa/quick93_expected.json",saved)
    var checks={"cases":cases,"no_duplicate_items":true,"category_restrictions":true,"cancel_before_after":true,"echo_ignored":true,"aim_to_melee":true,"draw_and_fire_carbine":true,"real_zombie_interrupts_draw":true,"rebind_exact_source":true,"reload_blocks":true,"reaction_blocks":true,"traversal_blocks":true,"hud_blocks_arrows":true,"drop_unbinds":true,"migration92":true,"invalid_links_refused":true,"roundtrip":true,"ammo_preserved":true,"stock_revalidation":true,"arrows_reserved":p.quick_slots_enabled,"throwable_slot_empty":not quick.bindings.has("down")}
    helper._write("res://qa/quick93.json",checks)
    if "--capture-quickslots" in OS.get_cmdline_user_args():await _native93(scene)
    print("R93_QUICKSLOTS_OK ",checks);scene.get_tree().quit()
func _native93(scene: Node3D) -> void:
    var p=scene.player;var quick=p.get_node("Atalhos93");var aim=scene.shoulder
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0;scene.focus=pad+Vector3.UP*.85;scene.zoom=4.6;scene._update_camera()
    for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
    Engine.physics_ticks_per_second=25
    for frame in 220:
        await scene.get_tree().physics_frame
        if frame in [20,65,110,155,190]:
            var direction="left" if frame in [20,155] else "up" if frame in [65,190] else "right"
            assert(quick.activate(direction),p.inventory_message)
        if frame in [38,84,173,209]:assert(aim.set_aim(true))
        if frame in [56,101,181]:aim.set_aim(false)
        if frame==128:p.combat.set_guard(true)
        if frame==146:p.combat.set_guard(false)
        _step88(scene,.04);quick.sync()
        await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
        var path="res://previews/quick93/%03d.png"%frame
        DirAccess.make_dir_recursive_absolute(path.get_base_dir());scene.get_viewport().get_texture().get_image().save_png(path)
    assert(quick.activate("left"));_settle93(scene);quick.sync()
    # External view of the stowed long gun and an inventory binding button.
    scene.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;scene.camera.fov=58;scene.camera.global_position=pad+Vector3(1.6,1.6,-2.0);scene.camera.look_at(pad+Vector3.UP*1.15)
    await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
    scene.get_viewport().get_texture().get_image().save_png("res://previews/quick93/back.png")
    scene.game_ui.toggle(0);scene.game_ui.select_item(quick.bindings.left);scene.game_ui.feedback.text="Selecione uma arma e clique em Vincular."
    await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
    scene.get_viewport().get_texture().get_image().save_png("res://previews/quick93/inventory.png")

func _zombie_interrupt93(scene: Node3D) -> void:
    var p=scene.player;var quick=p.get_node("Atalhos93");var actor=scene.zombie_world.actors.values()[0]
    var old_position=p.global_position;var condition=p.condition_state.snapshot();var health=p.body_health.snapshot()
    var stock=p.bag_inventory.snapshot();var rounds=p.weapons.rounds.duplicate(true)
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0;_player_idle(p)
    _pose91(scene,actor,pad);actor.global_position=pad+Vector3(0,0,.85)
    for tick in 2:await scene.get_tree().physics_frame
    assert(actor.can_hit_player());var hits=actor.hits;actor._begin_attack();actor.elapsed=float(actor.profile.impact)-.10
    assert(quick.activate("left"))
    for frame in 120:
        await scene.get_tree().physics_frame
        if actor.state=="attack":actor.step(1.0/60)
        if p.reaction.is_active():p.reaction.advance(1.0/60)
        else:_step88(scene,1.0/60)
    assert(actor.hits==hits+1 and p.body_health.records.size()==health.records.size()+1)
    assert(helper._same(stock,p.bag_inventory.snapshot()) and p.weapons.rounds==rounds and p.bag_inventory.equipped("main_hand").is_empty())
    _player_idle(p);assert(quick.activate("up"));_settle93(scene)
    assert(p.weapons.visual.visible and p.weapons.held_uid==quick.bindings.up)
    assert(quick.activate("up"));_settle93(scene)
    assert(p.condition_state.restore(condition));assert(p.body_health.restore(health));_player_idle(p)
    actor.restore(scene.zombie_world.initial[actor.identity]);actor.ai_enabled=false;actor.global_position=Vector3(1000,0,1000)
    p.global_position=old_position
