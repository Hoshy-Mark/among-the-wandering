extends "res://personagem/revisao91.gd"
var next_drop_row92=25
var max_reach92=0.0
var max_support92=0.0
var max_segment92=0.0
func _measure92(scene: Node3D) -> void:
    var p=scene.player;var pose=p.weapons.presentation
    if p.avatar.motion_blend>=.999 and p.avatar.motion in ["firearm_idle","firearm_shot","firearm_reload90"]:
        max_reach92=maxf(max_reach92,pose.reach_error);max_support92=maxf(max_support92,pose.support_error);max_segment92=maxf(max_segment92,pose.segment_delta)
func _equip92(scene: Node3D,id: String) -> String:
    var p=scene.player;var bag=p.bag_inventory;scene.shoulder.set_aim(false);_step88(scene,.5);_player_idle(p);p.global_position=scene.spawn;p.update_nearby()
    var held=bag.equipped("main_hand")
    if not held.is_empty():
        assert(p.place_item(held,"drop_here",0,next_drop_row92,false),p.inventory_message);_settle86(p);next_drop_row92+=5
    var uid=_find_weapon(bag,id)
    assert(p.equip_item(uid),p.inventory_message);_settle86(p)
    assert(bag.equipped("main_hand")==uid and p.weapons.visual.definition==id)
    scene.game_ui.close_nearby();scene.game_ui.personal.visible=false;scene.game_ui.windows[1].visible=false;p.set_hud_open(false)
    return uid
func run(scene: Node3D) -> void:
    var p=scene.player;var aim=scene.shoulder;var bag=p.bag_inventory;var s=p.weapons
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false);scene.set_process(false)
    aim.set_process(false);aim.set_physics_process(false);aim.scripted=true;p.map_combat.effects.set_physics_process(false)
    scene.get_window().size=Vector2i(1280,800);p.condition_path="user://qa_arsenal92.json"
    for z in scene.zombie_world.actors.values():z.ai_enabled=false
    if "--arsenal-reopen" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/arsenal92_expected.json"))
        assert(helper._same(expected,p.session_save.snapshot()))
        print("R92_FRESH_PROCESS_OK");scene.get_tree().quit();return
    for z in scene.zombie_world.actors.values():z.global_position=Vector3(1000,0,1000)
    var initial=bag.snapshot();var uid_map=s.rounds.duplicate(true)
    var shadow=bag.get_script().new();shadow.house_anchors=bag.house_anchors.duplicate(true);assert(shadow.restore(initial,false))
    assert(s.seed_extra(shadow) and helper._same(initial,shadow.snapshot()))
    # A real R91 profile migrates once and keeps its existing loaded pistol.
    var old=JSON.parse_string(FileAccess.get_file_as_string("res://qa/shots91_expected.json"))
    var migrated=p.session_save.prepare(old,false);assert(not migrated.is_empty(),p.session_save.reason)
    assert(p.session_save.pending_rounds.size()==3)
    for uid in old.firearms87.rounds:assert(p.session_save.pending_rounds[uid]==old.firearms87.rounds[uid])
    assert(helper._same(initial,bag.snapshot()) and s.rounds==uid_map)
    p.update_nearby()
    var pistol_ammo=_find_weapon(bag,"ammo_pistol");var rifle_ammo=_find_weapon(bag,"ammo_carbine")
    assert(p.place_item(pistol_ammo,"pockets",2,0,false));_settle86(p)
    var carbine=_equip92(scene,"carbine")
    assert(not s.reload_weapon()) # Different or ground ammo cannot feed this weapon.
    assert(p.place_item(rifle_ammo,"pockets",2,1,false));_settle86(p)
    var pad=_field(scene);var victim=scene.zombie_world.actors.values()[0];var cases=[]
    for id in ["pistol","revolver","carbine"]:
        var uid=_equip92(scene,id);var info=s.spec(uid);var ammo=pistol_ammo if id!="carbine" else rifle_ammo
        var other=rifle_ammo if id!="carbine" else pistol_ammo
        # Atomic reload/cancel in three simulation steps; the other calibre stays unchanged.
        for fps in [30,60,120]:
            var stock=bag.snapshot();var other_count=bag.items[other].count;s.rounds[uid]=int(info.capacity)-1
            assert(s.reload_weapon(),str([id,fps,p.inventory_message,p.action.state,p.combat.state,s.reload_job,s.loaded(uid),bag.items[ammo],p.map_combat.ready_to_act(),p.paused,p.hud_open,p.inventory_actions.job,bag.owned(ammo),p.avatar.motion_paused,p.action.control_locked,p.combat.control_locked]));_step88(scene,.05);p.action.cancel();s.present()
            assert(helper._same(stock,bag.snapshot()) and s.loaded(uid)==int(info.capacity)-1)
            assert(s.reload_weapon())
            for frame in fps*3:
                _step88(scene,1.0/fps);_measure92(scene)
                if p.action.state=="idle":break
            assert(s.loaded(uid)==int(info.capacity) and bag.items[ammo].count==stock.items[ammo].count-1 and bag.items[other].count==other_count)
            var done=bag.snapshot();p.action.advance(2);assert(helper._same(done,bag.snapshot()))
            bag.restore(stock,false);bag.changed.emit();_player_idle(p)
        for stop_time in [.70,1.15]:
            var stock=bag.snapshot();s.rounds[uid]=int(info.capacity)-1
            assert(s.reload_weapon());_step88(scene,stop_time);p.action.cancel();s.present();p.avatar.advance(0)
            assert(not s.presentation.magazine.visible)
            if id=="revolver":assert(s.visual.cylinder.position.distance_to(Vector3(0,.043,.02).rotated(Vector3.UP,s.visual.BARREL_YAW))<.00001)
            if stop_time<1:
                assert(helper._same(stock,bag.snapshot()) and s.loaded(uid)==int(info.capacity)-1)
            else:assert(s.loaded(uid)==int(info.capacity) and bag.items[ammo].count==stock.items[ammo].count-1)
            bag.restore(stock,false);bag.changed.emit();_player_idle(p)
        p.global_position=pad;p.avatar.rotation.y=0;scene.focus=pad+Vector3.UP*.85;scene._update_camera()
        _pose91(scene,victim,pad)
        for tick in 2:await scene.get_tree().physics_frame
        assert(aim.set_aim(true));_step88(scene,.5)
        for degrees in [-28,0,32]:
            aim.pitch=deg_to_rad(degrees)
            for frame in 30:_step88(scene,1.0/60);_measure92(scene)
        aim.pitch=0
        for fps in [30,60,120]:
            _pose91(scene,victim,pad);_look88(scene,victim.global_position+Vector3.UP*1.19)
            for frame in fps:_step88(scene,1.0/fps)
            s.rounds[uid]=int(info.capacity);aim.rng.seed=92
            assert(p.request_attack(),p.inventory_message)
            assert(not p.request_attack())
            for frame in fps*2:
                _step88(scene,1.0/fps);_measure92(scene)
                if not p.combat.is_attacking():break
            var shot=p.map_combat.last_shot
            assert(shot.hit and shot.event.zone=="chest",str(shot))
            assert(is_equal_approx(victim.health,.48-float(info.damage)) and s.loaded(uid)==int(info.capacity)-1)
            cases.append({"weapon":id,"fps":fps,"damage":shot.event.amount,"rounds":s.loaded(uid),"one_hit":true,"cone":shot.cone_degrees})
        # Weapon switch before impact cancels; no cartridge belongs to the replacement UID.
        var rounds=s.rounds.duplicate(true);assert(p.request_attack());_step88(scene,.04);aim.set_aim(false);_step88(scene,.6)
        assert(s.rounds==rounds)
        aim.set_aim(true);_step88(scene,.5);_look88(scene,victim.global_position+Vector3.UP*1.19)
        _box(scene,pad+Vector3(0,1,1.5),Vector3(3,2,.1))
        for tick in 2:await scene.get_tree().physics_frame
        var health=victim.health;var loaded=s.loaded(uid);assert(p.request_attack())
        for frame in 60:_step88(scene,1.0/60)
        assert(not p.map_combat.last_shot.hit and victim.health==health and s.loaded(uid)==loaded-1)
        await _clear_boxes(scene);aim.set_aim(false);_step88(scene,.5);_player_idle(p)
    assert(max_segment92<.0001 and max_support92<.035 and max_reach92<.035,str([max_segment92,max_support92,max_reach92]))
    p.global_position=scene.spawn;p.update_nearby()
    var baseline=bag.snapshot();var original_revolver=_find_weapon(bag,"revolver");var old_rounds=s.loaded(original_revolver)
    var duplicate=bag.add_at("revolver",1,s.EXTRA_CACHE,0,10,false);assert(not duplicate.is_empty());s.sync()
    s.rounds[original_revolver]=2;assert(s.loaded(duplicate)==0)
    s.rounds[duplicate]=4;assert(s.loaded(original_revolver)==2)
    bag.restore(baseline,false);bag.changed.emit();assert(not s.rounds.has(duplicate));s.rounds[original_revolver]=old_rounds
    # Exact per-UID capacity validation and rejection leave live state untouched.
    p.global_position=scene.spawn
    for z in scene.zombie_world.actors.values():z.restore(scene.zombie_world.initial[z.identity]);z.ai_enabled=false
    assert(p.save_condition(),p.inventory_message)
    var saved=p.session_save.snapshot();var before=bag.snapshot()
    var bad=saved.duplicate(true);bad.firearms87.rounds[carbine]=9
    assert(p.session_save.prepare(bad,false).is_empty() and helper._same(before,bag.snapshot()))
    bad=saved.duplicate(true);bad.firearms87.rounds.erase(carbine);assert(p.session_save.prepare(bad,false).is_empty())
    bad=saved.duplicate(true);bad.firearms87.rounds[carbine]=1.5;assert(p.session_save.prepare(bad,false).is_empty())
    bad=saved.duplicate(true);bad.firearms87.rounds[42]=1;assert(p.session_save.prepare(bad,false).is_empty())
    assert(p.load_condition() and helper._same(saved,p.session_save.snapshot()))
    helper._write("res://qa/arsenal92_expected.json",saved)
    var checks={"cases":cases,"seed_idempotent":true,"migration91":true,"wrong_ammo_refused":true,"cancel_before_effect":true,"wall_blocks":true,"roundtrip":true,"invalid_rounds_refused":true,"cancel_during_and_after_reload":true,"same_model_uid_independent":true,"max_segment_delta":max_segment92,"max_support_error":max_support92,"max_reach_error":max_reach92}
    helper._write("res://qa/arsenal92.json",checks)
    if "--capture-arsenal" in OS.get_cmdline_user_args():await _native92(scene,pad)
    print("R92_ARSENAL_OK ",checks);scene.get_tree().quit()
func _native92(scene: Node3D,pad: Vector3) -> void:
    var p=scene.player;var aim=scene.shoulder;var victim=scene.zombie_world.actors.values()[0]
    Engine.physics_ticks_per_second=25
    for id in ["revolver","carbine"]:
        var uid=_equip92(scene,id);p.weapons.rounds[uid]=int(p.weapons.spec(uid).capacity)
        p.global_position=pad;p.avatar.rotation.y=0;scene.focus=pad+Vector3.UP*.85;scene.zoom=5.5;scene._update_camera()
        _pose91(scene,victim,pad)
        for other in scene.zombie_world.actors.values():
            if other!=victim:other.global_position=Vector3(1000,0,1000)
        for frame in 140:
            await scene.get_tree().physics_frame
            if frame==20:assert(aim.set_aim(true))
            if frame>=20 and frame<125:
                var point=victim.global_position+Vector3.UP*1.60;var d=point-scene.camera.global_position
                aim.yaw=lerp_angle(aim.yaw,atan2(d.x,d.z),.45);aim.pitch=lerpf(aim.pitch,atan2(d.y,Vector2(d.x,d.z).length()),.45)
            if frame==50:assert(p.request_attack())
            if frame==75:assert(p.weapons.reload_weapon())
            if frame==125:assert(aim.set_aim(false))
            _step88(scene,.04);victim.step(.04)
            await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
            var path="res://previews/arsenal92/%s/%03d.png"%[id,frame]
            DirAccess.make_dir_recursive_absolute(path.get_base_dir());scene.get_viewport().get_texture().get_image().save_png(path)
        assert(p.weapons.loaded(uid)==int(p.weapons.spec(uid).capacity))
        _player_idle(p);p.avatar.rotation.y=0;assert(aim.set_aim(true));_step88(scene,.5)
        _look88(scene,pad+Vector3(0,1.5,4));_step88(scene,.5)
        var old_camera=scene.camera.global_transform
        scene.camera.global_position=pad+Vector3(-1.4,1.65,1.8);scene.camera.look_at(pad+Vector3(0,1.3,.15))
        await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
        scene.get_viewport().get_texture().get_image().save_png("res://previews/arsenal92/"+id+"/front.png")
        scene.camera.global_transform=old_camera
        aim.set_aim(false);_step88(scene,.5)


