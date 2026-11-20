extends "res://personagem/revisao81.gd"
func _pad(scene: Node3D) -> Vector3:
    var house=scene.world_items.house
    for x in range(-8,9,2):
        for z in range(-12,-5):
            var point=house.home.model.to_global(Vector3(x,0,z))
            var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*2,1)
            var floor=scene.get_world_3d().direct_space_state.intersect_ray(ray)
            if floor.is_empty():continue
            point.y=floor.position.y+.02
            var clear=true
            for offset in [Vector3.ZERO,Vector3(0,0,1),Vector3(0,0,3),Vector3(1,0,0),Vector3(-1,0,0)]:
                if not house.standing_clear(point+offset):clear=false
            if clear:return point
    assert(false,"No test pad");return Vector3.ZERO
func _wall(scene: Node3D,point: Vector3) -> StaticBody3D:
    var body=StaticBody3D.new();body.collision_layer=1
    var shape=BoxShape3D.new();shape.size=Vector3(4,2,.15)
    var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision);scene.add_child(body);body.global_position=point+Vector3.UP
    return body
func run(scene: Node3D) -> void:
    var p=scene.player;var world=scene.zombie_world;var save=p.session_save
    assert(world.actors.size()==2)
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    scene.get_window().size=Vector2i(1440,900)
    for actor in world.actors.values():actor.ai_enabled=false
    p.condition_path="user://qa_zombies82.json"
    if "--zombie-reopen" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/zombies82_expected.json"))
        assert(_same(save.snapshot(),expected),"NPC fresh-process mismatch")
        print("R82_FRESH_PROCESS_OK");scene.get_tree().quit();return
    for suffix in ["",".bak",".tmp"]:
        if FileAccess.file_exists(p.condition_path+suffix):DirAccess.remove_absolute(p.condition_path+suffix)
    var z=world.actors.values()[0];var other=world.actors.values()[1]
    var pad=_pad(scene)
    other.global_position=pad+Vector3(0,0,-6)
    z.global_position=pad;z.avatar.rotation.y=0;p.global_position=pad+Vector3(0,0,3)
    for frame in 3:await scene.get_tree().physics_frame
    assert(z.sees_player())
    z.avatar.rotation.y=PI;assert(not z.sees_player())
    p.velocity=Vector3(3.2,0,0);assert(z.hears_player());p.velocity=Vector3.ZERO
    z.avatar.rotation.y=0;p.crouched=true;p.global_position=pad+Vector3(0,0,4)
    assert(not z.sees_player());p.crouched=false;p.global_position=pad+Vector3(0,0,3)
    var wall=_wall(scene,pad+Vector3(0,0,1.5))
    for frame in 2:await scene.get_tree().physics_frame
    assert(not z.sees_player() and not z.clear_line(p.global_position,p))
    # Steering cannot pass through the wall, and actual motion uses move_and_slide.
    z.state="chase";z.memory=4;z.last_known=p.global_position
    for frame in 90:
        z.step(1.0/60)
        await scene.get_tree().physics_frame
    assert(z.global_position.z<pad.z+1.35 or absf(z.global_position.x-pad.x)>2.2)
    wall.queue_free()
    for frame in 2:await scene.get_tree().physics_frame
    # Exercise the live physics loop: pursuit must actually close the distance and hit.
    z.global_position=pad;z.avatar.rotation.y=0;z.state="idle";z.cooldown=0;z.memory=0
    p.global_position=pad+Vector3(0,0,3)
    var start_distance=z.global_position.distance_to(p.global_position)
    var hit_count=z.hits
    z.ai_enabled=true
    for frame in 420:
        await scene.get_tree().physics_frame
        if z.hits>hit_count:break
    z.ai_enabled=false
    assert(z.hits==hit_count+1 and z.global_position.distance_to(p.global_position)<start_distance-1,"Live pursuit did not reach/attack")
    p.paused=true
    var frozen=z.snapshot()
    z.ai_enabled=true;z._physics_process(1)
    assert(z.snapshot()==frozen)
    z.ai_enabled=false;p.paused=false
    # With no continuing stimulus, memory expires instead of tracking through walls.
    z.state="search";z.memory=.01;z.avatar.rotation.y=PI;p.velocity=Vector3.ZERO;p.global_position=pad+Vector3(0,0,12)
    z.step(.02);assert(z.state=="idle" and z.memory==0)
    var cases=[]
    for fps in [30,60,120]:
        z.global_position=pad;z.avatar.rotation.y=0;p.global_position=pad+Vector3(0,0,.85)
        z.state="idle";z.cooldown=0;z.health=.48
        z._begin_attack()
        var wounds=p.body_health.records.size()
        for frame in fps*2:z._attack_step(1.0/fps)
        assert(p.body_health.records.size()==wounds+1 and z.effect_done)
        z._attack_step(10);assert(p.body_health.records.size()==wounds+1)
        # Moving out during windup turns this attack into a miss.
        z._begin_attack();p.global_position=pad+Vector3(0,0,3)
        wounds=p.body_health.records.size();z._attack_step(.6)
        assert(p.body_health.records.size()==wounds)
        cases.append({"fps":fps,"once":true,"out_of_reach_miss":true})
    z.state="idle";p.global_position=pad+Vector3(0,0,.85);z.global_position=pad;z.avatar.rotation.y=0
    z._begin_attack()
    assert(not p.save_condition() and p.inventory_message.contains("inimigos"))
    assert(not p.load_condition() and p.inventory_message.contains("inimigos"))
    wall=_wall(scene,pad+Vector3(0,0,.43))
    for frame in 2:await scene.get_tree().physics_frame
    var before=p.body_health.snapshot();z._attack_step(.6)
    assert(p.body_health.snapshot()==before)
    wall.queue_free()
    for frame in 2:await scene.get_tree().physics_frame
    z._begin_attack()
    var event={"id":"qa82_push","action":"push","amount":.06,"source_position":p.global_position}
    assert(z.receive_combat_hit(event) and z.state=="hit" and is_equal_approx(z.health,.48))
    assert(not z.receive_combat_hit(event))
    before=p.body_health.snapshot()
    z.step(.1);assert(p.body_health.snapshot()==before)
    assert(not z.receive_combat_hit({"id":"bad","action":"punch","amount":-1,"source_position":pad}))
    z.state="idle";z.health=.48
    # Drive the player's actual targeting and impact callback against the NPC.
    p.reaction.reset();p.map_combat.pending_reaction="";p.combat.set_guard(false);p.action.cancel();p.condition_state.set_stamina(100)
    z.global_position=pad;p.global_position=pad+Vector3(0,0,.85);p.avatar.rotation.y=PI
    assert(p.map_combat.request("punch"))
    for frame in 180:p.combat.advance(1.0/60)
    assert(is_equal_approx(z.health,.36),"Player impact did not reach NPC")
    z.state="idle";z.health=.12
    assert(z.receive_combat_hit({"id":"qa82_kill","action":"punch","amount":.12,"source_position":p.global_position}))
    assert(z.state=="dying" and not z.receive_combat_hit(event))
    z.step(1.8)
    for frame in 2:await scene.get_tree().physics_frame
    assert(z.state=="dead" and z.capsule.disabled and not z.is_in_group("combat_receivers79"))
    z.step(10);assert(z.state=="dead")
    # Save an injured living NPC and a dead NPC; move both, then resume atomically.
    p.reaction.reset();p.map_combat.pending_reaction="";p.combat.set_guard(false);p.action.cancel()
    other.state="search";other.health=.3;other.memory=2;other.last_known=pad;other.cooldown=.7
    other.global_position=pad+Vector3(0,0,-3)
    p.global_position=pad+Vector3(0,0,2)
    assert(p.save_condition(),p.inventory_message+" "+save.reason)
    var saved=save.snapshot()
    z.restore(world.initial[z.identity]);other.restore(world.initial[other.identity])
    assert(p.load_condition(),p.inventory_message+" "+save.reason)
    assert(_same(save.snapshot(),saved),"NPC roundtrip")
    var invalid=saved.duplicate(true);invalid.enemies82[z.identity].health=-1
    _write(p.condition_path,invalid)
    before=save.snapshot()
    assert(not p.load_condition() and _same(save.snapshot(),before))
    _write(p.condition_path,saved)
    # A live enemy cannot materialize on top of the saved player.
    invalid=saved.duplicate(true);invalid.enemies82[other.identity].position=invalid.session81.position.duplicate()
    _write(p.condition_path,invalid);assert(not p.load_condition() and save.reason=="occupied" and _same(save.snapshot(),before))
    # Pre-enemy R81 saves migrate, retaining player/world progress.
    var legacy=saved.duplicate(true);legacy.erase("enemies82");legacy.session81.world=save._signature().left(-64)
    _write(p.condition_path,legacy);assert(p.load_condition(),p.inventory_message)
    assert(world.actors[z.identity].state=="idle" and _same(p.bag_inventory.snapshot(),saved.inventory))
    _write(p.condition_path,saved);assert(p.load_condition())
    _write("res://qa/zombies82_expected.json",save.snapshot())
    var checks={"actors":2,"vision_and_cone":true,"crouch_visibility":true,"running_noise":true,"wall_blocks_sight_and_attack":true,"collision_steering":true,"live_pursuit_attack":true,"pause":true,"save_waits_for_enemy_attack":true,"memory_expires":true,"cases":cases,"push_interrupts_no_damage":true,"duplicate_rejected":true,"player_punch_receiver":true,"death_persists":true,"npc_roundtrip":true,"invalid_atomic":true,"occupied_atomic":true,"r81_migration":true}
    _write("res://qa/zombies82.json",checks)
    if "--capture-zombies" in OS.get_cmdline_user_args():
        scene.set_process(false)
        p.global_position=pad+Vector3(0,0,2)
        other.global_position=pad+Vector3(0,0,-.2);other.state="idle";other.avatar.rotation.y=0
        z.global_position=pad+Vector3(-1,0,.5)
        other._present(0);z._present(0)
        scene.camera.size=5;scene.camera.global_position=pad+Vector3(-4,3,5);scene.camera.look_at(pad+Vector3.UP*.9)
        await _capture82(scene,"encounter")
        p.reaction.reset();p.action.cancel();p.combat.set_guard(false)
        p.global_position=pad+Vector3(0,0,2);p.avatar.rotation.y=PI
        other.global_position=pad+Vector3(0,0,-1);other.state="idle";other.cooldown=0;other.health=.3
        other.ai_enabled=true;p.set_physics_process(true)
        for frame in 72:
            for tick in 3:await scene.get_tree().physics_frame
            await _capture82(scene,"pursuit/%02d"%frame)
        other.ai_enabled=false;p.set_physics_process(false)
        scene.game_ui.toggle(1);p.survival.refresh()
        await _capture82(scene,"wounds")
    print("R82_ZOMBIES_OK ",checks)
    scene.get_tree().quit()
func _capture82(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/zombies82/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
