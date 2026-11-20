extends "res://personagem/revisao87.gd"
var reload_reference: Node3D
var reload_reference_delta=0.0
var reload_reference_max=0.0
func _step88(scene: Node3D,dt: float) -> void:
    var p=scene.player;var aim=scene.shoulder
    aim._physics_process(dt)
    if p.combat.guarding:p.combat.advance(dt)
    else:p.action.advance(dt)
    p._update_equipment();aim.advance(dt)
    if p.avatar.motion=="equip_item" and reload_reference!=null:
        var reference=reload_reference
        reference.motion=p.avatar.motion;reference.motion_source=p.avatar.motion_source
        reference.motion_source_clock=p.avatar.motion_source_clock;reference.motion_clock=p.avatar.motion_clock
        reference.motion_blend=p.avatar.motion_blend;reference.motion_from=p.avatar.motion_from.duplicate()
        reference.motion_rate=p.avatar.motion_rate;reference.advance(0)
        for side in ["L","R"]:
            var values=p.avatar.arm_articulation.joints[side]
            var elbow=Vector3(values.elbow[0],values.elbow[1],values.elbow[2])
            var current=(p.avatar.arm_articulation._skin("UpperArm."+side)*elbow).distance_to(p.avatar.arm_articulation._skin("Forearm."+side)*elbow)
            var original=(reference.arm_articulation._skin("UpperArm."+side)*elbow).distance_to(reference.arm_articulation._skin("Forearm."+side)*elbow)
            reload_reference_max=maxf(reload_reference_max,original);reload_reference_delta=maxf(reload_reference_delta,absf(current-original))
    else:_joints(p.avatar)

func _look88(scene: Node3D,point: Vector3) -> void:
    var aim=scene.shoulder
    for iteration in 12:
        var direction=point-scene.camera.global_position
        aim.yaw=atan2(direction.x,direction.z)
        aim.pitch=clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),deg_to_rad(-28),deg_to_rad(32))
        _step88(scene,.05)
func _mouse88(scene: Node3D,button: int,pressed: bool) -> void:
    var aim=scene.shoulder;var old=aim.scripted;aim.scripted=false
    var event=InputEventMouseButton.new();event.button_index=button;event.pressed=pressed
    aim._input(event);aim.scripted=old
func run(scene: Node3D) -> void:
    var p=scene.player;var aim=scene.shoulder;var bag=p.bag_inventory;var s=p.weapons
    var actors=scene.zombie_world.actors.values();var victim=actors[0]
    for z in actors:z.ai_enabled=false
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    scene.set_process(false);aim.set_process(false);aim.set_physics_process(false);aim.scripted=true
    scene.get_window().size=Vector2i(1440,900)
    p.condition_path="user://qa_shoulder88.json"
    if "--shoulder-reopen" in OS.get_cmdline_user_args():
        var loaded=p.load_condition();assert(loaded,p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/shoulder88_expected.json"))
        assert(helper._same(expected,p.session_save.snapshot()))
        assert(not aim.holding and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
        print("R88_FRESH_PROCESS_OK");scene.get_tree().quit();return
    var pistol=_find_weapon(bag,"pistol");var ammo=_find_weapon(bag,"ammo_pistol")
    p.update_nearby();var accepted=p.equip_item(pistol);assert(accepted);_settle86(p)
    accepted=p.place_item(ammo,"pockets",2,0,false);assert(accepted);_settle86(p)
    accepted=p.map_combat.reload_weapon();assert(accepted);_settle86(p)
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0
    for z in actors:z.global_position=Vector3(1000,0,1000)
    scene.focus=pad+Vector3.UP*.85;scene.zoom=6.5;scene._update_camera()
    _player_idle(p);p.avatar.set_motion("idle");p.avatar.advance(.5)
    reload_reference=load("res://personagem/personagem.tscn").instantiate();reload_reference.manual_update=true;scene.add_child(reload_reference);reload_reference.visible=false
    load("res://personagem/poses_fogo87.gd").new().setup(reload_reference)
    var stock=bag.snapshot();var count=s.loaded(pistol)
    assert(not p.request_attack() and s.loaded(pistol)==count)
    # Actual mouse handlers: hold right, click left only once, release right.
    _mouse88(scene,MOUSE_BUTTON_RIGHT,true);assert(aim.holding and p.combat.guarding)
    _mouse88(scene,MOUSE_BUTTON_LEFT,true);assert(not p.combat.is_attacking() and s.loaded(pistol)==count)
    _mouse88(scene,MOUSE_BUTTON_LEFT,false)
    for frame in 30:_step88(scene,1.0/60)
    assert(aim.progress==1 and scene.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and aim.ready_to_fire())
    assert(not p.save_condition())
    var standing=p.global_position;p.command=Vector2(1,1);p._physics_process(1.0/60);p.command=Vector2.ZERO
    assert(Vector2(p.global_position.x-standing.x,p.global_position.z-standing.z).length()<.0001)
    _mouse88(scene,MOUSE_BUTTON_RIGHT,false)
    for frame in 30:_step88(scene,1.0/60)
    assert(not aim.holding and aim.progress==0 and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and not p.combat.guarding)
    # Three time steps, exact screen-centre hit, no repeated shot while a button stays down.
    var cases=[]
    for fps in [30,60,120]:
        victim.restore(scene.zombie_world.initial[victim.identity]);victim.global_position=pad+Vector3(0,0,3);victim.ai_enabled=false
        for frame in 2:await scene.get_tree().physics_frame
        s.rounds[pistol]=6;accepted=aim.set_aim(true);assert(accepted)
        for frame in fps/2:_step88(scene,1.0/fps)
        _look88(scene,victim.global_position+Vector3.UP*1.15)
        assert(aim.aim_ray().get("collider")==victim)
        var point: Vector3=aim.aim_ray().position
        var direction=(point-s.visual.muzzle_position()).normalized()
        assert(s.visual.barrel_direction().dot(direction)>.995)
        _mouse88(scene,MOUSE_BUTTON_LEFT,true)
        for frame in fps*2:_step88(scene,1.0/fps)
        assert(p.combat.effect_succeeded and is_equal_approx(victim.health,.20) and s.loaded(pistol)==5)
        _mouse88(scene,MOUSE_BUTTON_LEFT,false)
        accepted=aim.set_aim(false);assert(accepted)
        for frame in fps/2:_step88(scene,1.0/fps)
        assert(scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
        cases.append({"fps":fps,"centre_ray_hit":true,"one_click_one_shot":true,"projection_roundtrip":true})
    # Releasing aim before the effect cancels the pending shot without spending a round.
    s.rounds[pistol]=6;accepted=aim.set_aim(true);assert(accepted)
    for frame in 30:_step88(scene,1.0/60)
    _mouse88(scene,MOUSE_BUTTON_LEFT,true);assert(p.combat.is_attacking())
    _step88(scene,.05);_mouse88(scene,MOUSE_BUTTON_RIGHT,false)
    for frame in 60:_step88(scene,1.0/60)
    assert(s.loaded(pistol)==6 and not p.combat.is_attacking())
    # Aim away from the enemy: no automatic nearest-target selection.
    accepted=aim.set_aim(true);assert(accepted)
    for frame in 30:_step88(scene,1.0/60)
    _look88(scene,pad+Vector3(4,1.2,4))
    var health=victim.health;count=s.loaded(pistol)
    _mouse88(scene,MOUSE_BUTTON_LEFT,true)
    for frame in 60:_step88(scene,1.0/60)
    assert(not p.combat.effect_succeeded and victim.health==health and s.loaded(pistol)==count-1)
    # Near muzzle cover can block the bullet even when the camera sees the target.
    _look88(scene,victim.global_position+Vector3.UP*1.15)
    var muzzle=s.visual.muzzle_position();var point: Vector3=aim.aim_ray().position
    var cover=muzzle.lerp(point,.10)
    _box(scene,cover,Vector3(.16,.22,.12))
    for frame in 2:await scene.get_tree().physics_frame
    _step88(scene,0)
    assert(aim.reticle.blocked)
    health=victim.health;_mouse88(scene,MOUSE_BUTTON_LEFT,true)
    for frame in 60:_step88(scene,1.0/60)
    assert(victim.health==health and not p.combat.effect_succeeded)
    await _clear_boxes(scene)
    # Camera sphere retracts from a wall behind the player's shoulder.
    aim.set_aim(false)
    for frame in 30:_step88(scene,1.0/60)
    p.avatar.rotation.y=0;accepted=aim.set_aim(true);assert(accepted)
    _box(scene,pad+Vector3(-.2,1.45,-.9),Vector3(3,3,.12))
    for frame in 2:await scene.get_tree().physics_frame
    for frame in 30:_step88(scene,1.0/60)
    assert(aim.collision_fraction<.65)
    await _clear_boxes(scene)
    # Pitch bounds and yaw change the arms through rotations, keeping support joints coherent.
    for degrees in [-28,0,32]:
        aim.pitch=deg_to_rad(degrees)
        for frame in 20:_step88(scene,1.0/60)
        assert(p.avatar.shoulder_pitch>=deg_to_rad(-28)-.001 and p.avatar.shoulder_pitch<=deg_to_rad(32)+.001)
    aim.move_aim(Vector2(100000,-100000));assert(aim.pitch<=deg_to_rad(32))
    # Reload remains in shoulder view, lowers the weapon and restores the same instance.
    aim.pitch=0;s.rounds[pistol]=1;accepted=p.map_combat.reload_weapon();assert(accepted)
    _step88(scene,.05);assert(not s.visual.visible and aim.holding)
    for frame in 240:_step88(scene,1.0/60)
    assert(s.loaded(pistol)==6 and aim.holding and s.visual.visible and p.combat.guarding)
    # HUD, reaction, unarmed equipment and focus loss cannot leave a captured cursor/mira active.
    accepted=p.set_hud_open(true);assert(accepted);aim._physics_process(0);aim.advance(.5)
    assert(not aim.holding and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
    p.set_hud_open(false)
    accepted=aim.set_aim(true);assert(accepted);p.request_reaction("hit_front");aim._physics_process(0);aim.advance(.5)
    assert(not aim.holding);p.reaction.advance(2);p.reaction.reset();_player_idle(p)
    accepted=aim.set_aim(true);assert(accepted);aim._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);aim.advance(.5);assert(not aim.holding)
    accepted=aim.set_aim(true);assert(accepted);aim.advance(.15);aim.set_aim(false);aim.advance(.5)
    assert(aim.progress==0 and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
    # View state is transient; a stable save restores in the approved isometric view.
    p.global_position=scene.spawn;_player_idle(p)
    for z in actors:z.restore(scene.zombie_world.initial[z.identity]);z.ai_enabled=false
    accepted=p.save_condition();assert(accepted,p.inventory_message)
    var saved=p.session_save.snapshot();accepted=p.load_condition();assert(accepted)
    assert(helper._same(saved,p.session_save.snapshot()) and not aim.holding and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
    helper._write("res://qa/shoulder88_expected.json",saved)
    assert(max_elbow<.025 and max_wrist<.015,str([max_elbow,max_wrist]))
    assert(reload_reference_delta<.0001,str(reload_reference_delta))
    reload_reference.queue_free();reload_reference=null
    var checks={"cases":cases,"right_hold_left_click":true,"stationary_aim":true,"release_cancels_pending_shot":true,"aim_save_refused":true,"isometric_save_roundtrip":true,"transition_blocks_early_shot":true,"no_automatic_target":true,"muzzle_cover":true,"camera_collision":true,"pitch_bounds":true,"barrel_tracks_reticle":true,"reload_in_shoulder":true,"hud_exit":true,"reaction_exit":true,"focus_loss_exit":true,"interrupted_transition":true,"reload_reference_delta":reload_reference_delta,"reload_reference_max":reload_reference_max,"max_elbow":max_elbow,"max_wrist":max_wrist}
    helper._write("res://qa/shoulder88.json",checks)
    if "--capture-shoulder" in OS.get_cmdline_user_args():await _native88(scene,pad,victim,pistol)
    print("R88_SHOULDER_OK ",checks);scene.get_tree().quit()
func _native88(scene: Node3D,pad: Vector3,victim: CharacterBody3D,pistol: String) -> void:
    var aim=scene.shoulder;var p=scene.player;var s=p.weapons
    aim.set_aim(false);aim.advance(.5);_player_idle(p);p.global_position=pad;p.avatar.rotation.y=0
    for z in scene.zombie_world.actors.values():z.ai_enabled=false;z.global_position=Vector3(1000,0,1000)
    victim.restore(scene.zombie_world.initial[victim.identity]);victim.global_position=pad+Vector3(0,0,4);victim.avatar.rotation.y=PI
    for frame in 2:await scene.get_tree().physics_frame
    scene.focus=pad+Vector3.UP*.85;scene.zoom=6.5;scene._update_camera();s.rounds[pistol]=6
    await _capture88(scene,"isometric")
    aim.set_aim(true)
    for frame in 28:
        _step88(scene,1.0/60);await _capture88(scene,"transition/%03d"%frame)
    _look88(scene,victim.global_position+Vector3.UP*1.15)
    await _capture88(scene,"aim")
    _mouse88(scene,MOUSE_BUTTON_LEFT,true)
    for frame in 40:
        _step88(scene,.025);victim._present(.025);await _capture88(scene,"shoot/%03d"%frame)
    _mouse88(scene,MOUSE_BUTTON_LEFT,false)
    assert(p.combat.effect_succeeded)
    s.rounds[pistol]=1;var accepted=p.map_combat.reload_weapon();assert(accepted)
    for frame in 60:
        _step88(scene,.04);await _capture88(scene,"reload/%03d"%frame)
    aim.set_aim(false)
    for frame in 28:
        _step88(scene,1.0/60);await _capture88(scene,"return/%03d"%frame)
    await _capture88(scene,"returned")
func _capture88(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/shoulder88/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
