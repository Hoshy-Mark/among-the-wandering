extends "res://personagem/revisao89.gd"
var max_segment90=0.0
var max_contact90=0.0
func _step88(scene: Node3D,dt: float) -> void:
    super._step88(scene,dt)
    var pose=scene.player.weapons.presentation
    if scene.player.avatar.motion in ["firearm_idle","firearm_shot","firearm_reload90"] and scene.player.avatar.motion_blend>=.999:
        max_segment90=maxf(max_segment90,pose.segment_delta);max_contact90=maxf(max_contact90,pose.support_error)
func run(scene: Node3D) -> void:
    var p=scene.player;var bag=p.bag_inventory;var aim=scene.shoulder
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false);scene.set_process(false)
    aim.set_process(false);aim.set_physics_process(false);aim.scripted=true
    scene.get_window().size=Vector2i(1440,900)
    p.condition_path="user://qa_pistol90.json"
    if "--pistol-reopen" in OS.get_cmdline_user_args():
        var loaded=p.load_condition();assert(loaded,p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/pistol90_expected.json"))
        assert(helper._same(expected,p.session_save.snapshot()) and not p.weapons.presentation.magazine.visible)
        print("R90_FRESH_PROCESS_OK");scene.get_tree().quit();return
    for z in scene.zombie_world.actors.values():z.ai_enabled=false;z.global_position=Vector3(1000,0,1000)
    var pistol=_find_weapon(bag,"pistol");var ammo=_find_weapon(bag,"ammo_pistol")
    p.update_nearby();var accepted=p.equip_item(pistol);assert(accepted);_settle86(p)
    accepted=p.place_item(ammo,"pockets",2,0,false);assert(accepted);_settle86(p)
    accepted=p.map_combat.reload_weapon();assert(accepted);_settle86(p)
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0
    scene.focus=pad+Vector3.UP*.85;scene.zoom=6.5;scene._update_camera()
    accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5);_step88(scene,.2)
    var presentation=p.weapons.presentation
    var support_max=0.0;var reload_error=0.0;var reach_max=0.0;var cases=[]
    for degrees in [-28,0,32]:
        aim.pitch=deg_to_rad(degrees)
        for frame in 30:_step88(scene,1.0/60)
        support_max=maxf(support_max,presentation.support_error);reach_max=maxf(reach_max,presentation.reach_error)
    aim.set_aim(false);_step88(scene,.5)
    for fps in [30,60,120]:
        p.weapons.rounds[pistol]=1
        var original=bag.snapshot();var loaded=p.weapons.loaded(pistol)
        accepted=p.map_combat.reload_weapon();assert(accepted and p.action.motion_id=="firearm_reload90")
        _step88(scene,.05);assert(p.weapons.visual.visible);p.action.cancel();p.weapons.present()
        assert(helper._same(original,bag.snapshot()) and p.weapons.loaded(pistol)==loaded and not presentation.magazine.visible)
        accepted=p.map_combat.reload_weapon();assert(accepted)
        var first_effect=-1.0;var previous=loaded
        for frame in fps*3:
            _step88(scene,1.0/fps)
            if p.action.effect_done and first_effect<0:first_effect=(frame+1.0)/fps
            if p.action.state!="idle" and p.avatar.motion_blend>=.999:
                reload_error=maxf(reload_error,presentation.support_error);reach_max=maxf(reach_max,presentation.reach_error)
                assert(p.weapons.visual.visible)
            if p.action.state=="idle":break
        assert(first_effect>=1.025-.000001 and first_effect<=1.025+1.0/fps+.000001)
        assert(p.weapons.loaded(pistol)==6 and int(bag.items[ammo].count)==int(original.items[ammo].count)-5)
        var after=bag.snapshot();p.action.advance(2);assert(helper._same(after,bag.snapshot()))
        cases.append({"fps":fps,"first_effect":first_effect,"one_transfer":true,"cancel_before_atomic":true})
        bag.restore(original,false);bag.changed.emit();_player_idle(p)
    var shots=[];var victim=scene.zombie_world.actors.values()[0]
    for fps in [30,60,120]:
        victim.restore(scene.zombie_world.initial[victim.identity]);victim.ai_enabled=false;victim.global_position=pad+Vector3(0,0,3)
        p.avatar.rotation.y=0;p.weapons.rounds[pistol]=6
        for tick in 2:await scene.get_tree().physics_frame
        accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5);_look88(scene,victim.global_position+Vector3.UP*1.15)
        var direction=(aim.aim_ray().position-p.weapons.visual.muzzle_position()).normalized()
        assert(p.weapons.visual.barrel_direction().dot(direction)>.995)
        _mouse88(scene,MOUSE_BUTTON_LEFT,true)
        for frame in fps*2:
            _step88(scene,1.0/fps)
            if not p.combat.is_attacking():break
        assert(p.combat.effect_succeeded and is_equal_approx(victim.health,.20) and p.weapons.loaded(pistol)==5)
        _mouse88(scene,MOUSE_BUTTON_LEFT,false);aim.set_aim(false);_step88(scene,.5)
        shots.append({"fps":fps,"two_hands":true,"one_hit":true,"one_round":true})
    # A cancelled reload after insertion retains the already transferred ammunition.
    p.weapons.rounds[pistol]=1;var original=bag.snapshot()
    accepted=p.map_combat.reload_weapon();assert(accepted)
    for frame in 300:
        _step88(scene,1.0/60)
        if p.action.effect_done:break
    p.action.cancel();p.weapons.present()
    assert(p.weapons.loaded(pistol)==6 and int(bag.items[ammo].count)==int(original.items[ammo].count)-5 and not presentation.magazine.visible)
    bag.restore(original,false);bag.changed.emit();p.weapons.rounds[pistol]=1
    # Stock revalidation and reaction release both hands/temporary prop.
    accepted=p.map_combat.reload_weapon();assert(accepted);bag.items[ammo].count-=1
    _settle86(p);assert(p.weapons.loaded(pistol)==1)
    bag.restore(original,false);bag.changed.emit();_player_idle(p)
    accepted=p.map_combat.reload_weapon();assert(accepted);_step88(scene,.6)
    accepted=p.request_reaction("hit_front");assert(accepted);p.weapons.present()
    assert(not p.weapons.visual.visible and not presentation.magazine.visible)
    p.reaction.advance(2);p.reaction.reset();p.action.cancel();_player_idle(p)
    # Existing traversal must control the hand supports; no two-hand layer or prop may intrude.
    for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
    var low: Node3D
    for obstacle in p.map_traversals.obstacles:
        if obstacle.has_meta("fence78") and not obstacle.model.high:low=obstacle;break
    p.avatar.set_motion("idle");p.avatar.motion_clock=0;p.avatar.motion_blend=1;p.avatar.advance(0)
    await _place(scene,low,-1);accepted=p.request_cross(low);assert(accepted)
    for frame in 400:
        p.traversal.advance(1.0/60);p._update_equipment();_joints(p.avatar)
        if not p.traversal.is_active():break
        assert(not p.weapons.visual.visible and not presentation.magazine.visible and p.avatar.hand_layer.label!="Pistol_Grip90")
    assert(p.traversal.effect_succeeded)
    _player_idle(p);aim.advance(.5);p.global_position=scene.spawn
    for z in scene.zombie_world.actors.values():z.restore(scene.zombie_world.initial[z.identity]);z.ai_enabled=false
    accepted=p.save_condition();assert(accepted,p.inventory_message)
    var saved=p.session_save.snapshot();accepted=p.load_condition();assert(accepted and helper._same(saved,p.session_save.snapshot()))
    helper._write("res://qa/pistol90_expected.json",saved)
    assert(support_max<.01 and reload_error<.01 and max_contact90<.012,str([support_max,reload_error,max_contact90]))
    assert(max_elbow<.025 and max_wrist<.015 and max_segment90<.0001,str([max_elbow,max_wrist,max_segment90]))
    var checks={"cases":cases,"shots":shots,"cancel_after_retains_transfer":true,"insertion_effect_aligned":true,"stock_revalidation":true,"reaction_hands_free":true,"traversal_hands_free":true,"roundtrip":true,"support_max":support_max,"reload_error":reload_error,"reach_max":reach_max,"max_contact":max_contact90,"max_segment_delta":max_segment90,"max_elbow":max_elbow,"max_wrist":max_wrist}
    helper._write("res://qa/pistol90.json",checks)
    if "--capture-pistol-pose" in OS.get_cmdline_user_args():
        p.global_position=pad;p.weapons.rounds[pistol]=6;p.avatar.rotation.y=0;scene.focus=pad+Vector3.UP*.85;scene._update_camera()
        for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
        aim.set_aim(true)
        for frame in 28:_step88(scene,1.0/60);await _capture90(scene,"raise/%03d"%frame)
        _step88(scene,.2)
        await _capture90(scene,"shoulder")
        victim.restore(scene.zombie_world.initial[victim.identity]);victim.ai_enabled=false;victim.global_position=pad+Vector3(0,0,3);victim.avatar.rotation.y=PI
        for tick in 2:await scene.get_tree().physics_frame
        _look88(scene,victim.global_position+Vector3.UP*1.15)
        _mouse88(scene,MOUSE_BUTTON_LEFT,true)
        for frame in 40:
            _step88(scene,.025);victim._present(.025);await _capture90(scene,"shoot/%03d"%frame)
        assert(p.combat.effect_succeeded and p.weapons.loaded(pistol)==5)
        p.weapons.rounds[pistol]=1;accepted=p.map_combat.reload_weapon();assert(accepted)
        for frame in 60:_step88(scene,.035);await _capture90(scene,"reload/%03d"%frame)
        assert(p.action.state=="idle" and p.weapons.loaded(pistol)==6 and not presentation.magazine.visible)
        victim.global_position=Vector3(1000,0,1000)
        aim.set_process(false)
        for view in [["front",Vector3(0,1,5)],["side",Vector3(-5,2,0)],["isometric",Vector3(4,3,5)]]:
            scene.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
            _camera84(scene,pad+Vector3.UP*1.2,2.3,view[1]);await _capture90(scene,str(view[0]))
        aim.advance(0);p.weapons.rounds[pistol]=1;accepted=p.map_combat.reload_weapon();assert(accepted)
        for frame in 60:
            aim.advance(0);_step88(scene,.035)
            scene.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;_camera84(scene,pad+Vector3.UP*1.23,1.6,Vector3(3,1,4))
            aim.reticle.strength=0;aim.reticle.queue_redraw();await _capture90(scene,"reload_detail/%03d"%frame)
        assert(p.action.state=="idle" and p.weapons.loaded(pistol)==6)
        aim.advance(0);aim.set_aim(false)
        for frame in 28:_step88(scene,1.0/60);await _capture90(scene,"lower/%03d"%frame)
    print("R90_PISTOL_POSE_OK ",checks);scene.get_tree().quit()
func _capture90(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
    var path="res://previews/pistol90/"+name+".png";DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
