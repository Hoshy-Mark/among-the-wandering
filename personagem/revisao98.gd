extends "res://personagem/revisao94.gd"
func _freeze98(scene: Node3D) -> void:
    var p=scene.player;p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    scene.set_process(false);scene.shoulder.scripted=true;scene.shoulder.set_process(false);scene.shoulder.set_physics_process(false)
    scene.zombie_world.set_physics_process(false)
    for actor in scene.zombie_world.actors.values():actor.ai_enabled=false
    p.get_node("Atalhos93").scripted=true
var view_trees98=[]
func _pair98(scene: Node3D,skip: Array=[],clear_view: bool=false) -> Dictionary:
    var w=scene.zombie_world
    for id in w.model.definitions:
        if id in skip or w.model.definitions[id].cohort!="urban_roamers":continue
        var a=w.motor.point(w.saved[id].position);var p=w.motor._floor(a-Vector3(0,0,4))
        if p==null or not w.motor._free(p) or not w.motor._edge(p,a) or not w.motor._separated("",p):continue
        if clear_view and not _clear_view98(scene,p,a):continue
        return {"id":id,"player":p,"actor":a}
    return {}
func run(scene: Node3D) -> void:
    if not "residential98" in scene.player.session_save:
        var source=GDScript.new();source.source_code=FileAccess.get_file_as_string("res://personagem/partida98.gd");assert(source.reload()==OK)
        var previous=scene.player.session_save;var replacement=source.new();replacement.enemies=scene.zombie_world;scene.add_child(replacement);replacement.setup(scene)
        scene.remove_child(previous);previous.queue_free()
    var p=scene.player;var w=scene.zombie_world;var tree=scene.get_tree();var service=p.session_save
    _freeze98(scene);_player_idle(p)
    var requested=""
    if FileAccess.file_exists("res://qa/mode98.txt"):
        requested=FileAccess.get_file_as_string("res://qa/mode98.txt").strip_edges();DirAccess.remove_absolute(ProjectSettings.globalize_path("res://qa/mode98.txt"))
    if not w.navigation.get_script().resource_path.ends_with("navegacao98.gd"):
        for a in w.actors.values():a.clear_route()
        var previous_nav=w.navigation;w.remove_child(previous_nav);previous_nav.queue_free()
        w.navigation=load("res://personagem/navegacao98.gd").new();w.add_child(w.navigation);w.navigation.setup(w)
    Engine.physics_ticks_per_second=60;Engine.max_fps=60
    print("R98_BOOT_OK total=",w.saved.size()," live=",w.actors.size()," houses=",scene.city.get_node("ResidentialInteriors").homes.size())
    if "--capture-population98" in OS.get_cmdline_user_args() and requested!="functional":
        var capture=await _native98(scene)
        if capture is Dictionary and capture.get("capture",false):scene.get_node("QAHost98").finish(capture)
        return
    if "--reopen-population98" in OS.get_cmdline_user_args():
        p.condition_path="res://qa/r98_after_fight.json";assert(p.load_condition(),p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/r98_expected.json"))
        assert(w.saved.size()==480 and w.saved[expected.id].state=="dead" and w.saved[expected.id].position==expected.position)
        assert(p.weapons.loaded(expected.weapon_uid)==expected.rounds)
        scene.get_node("QAHost98").finish({"fresh_process":true,"total":480,"death_restored":true,"ammunition_restored":true});return
    w.restore(w.initial);_freeze98(scene)
    for frame in 2:await tree.physics_frame
    var original=service.snapshot();assert(w.valid(original.enemies82))
    assert(not service.prepare(original,false).is_empty(),service.reason)
    var spatial=service.prepare(original);assert(not spatial.is_empty(),"initial spatial "+service.reason)
    var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://qa/demo95_checkpoint.json"));var legacy_hash=FileAccess.get_sha256("res://qa/demo95_checkpoint.json")
    legacy.enemies82.arroio82_01.state="dead";legacy.enemies82.arroio82_01.health=0
    assert(not service.prepare(legacy,false).is_empty(),"legacy codec "+service.reason)
    assert(service.pending_enemies.size()==480 and service.pending_enemies.arr96_urban_001.state=="dead")
    assert(not service.prepare(legacy).is_empty(),"legacy spatial "+service.reason)
    assert(FileAccess.get_sha256("res://qa/demo95_checkpoint.json")==legacy_hash)
    var broken=original.duplicate(true);broken.enemies82.erase("arr96_outer_001")
    assert(service.prepare(broken,false).is_empty());broken=original.duplicate(true);broken.erase("enemies82");assert(service.prepare(broken,false).is_empty())
    p.condition_path="res://qa/r98_baseline.json"
    FileAccess.open(p.condition_path,FileAccess.WRITE).store_string(JSON.stringify(original,"",true,true))
    var tested_door=""
    for door_id in service.residential98.rows:
        var proposed=original.duplicate(true);proposed.residential98.states[door_id]=true
        if service.prepare(proposed).is_empty():continue
        assert(not service.residential98.rows[door_id].open)
        FileAccess.open("res://qa/r98_door.json",FileAccess.WRITE).store_string(JSON.stringify(proposed,"",true,true))
        p.condition_path="res://qa/r98_door.json";assert(p.load_condition(),p.inventory_message)
        assert(service.residential98.rows[door_id].open);tested_door=door_id;break
    assert(not tested_door.is_empty(),"No restorable generic residential door")
    p.condition_path="res://qa/r98_baseline.json";assert(p.load_condition(),p.inventory_message)
    assert(not service.residential98.rows[tested_door].open)
    var pair=_pair98(scene);assert(not pair.is_empty(),"No safe woodland pair")
    var id=pair.id;w._activate(id);var actor=w.actors[id];actor.ai_enabled=false
    var bones=[]
    for i in range(actor.avatar.skeleton.get_bone_count()):bones.append({"name":actor.avatar.skeleton.get_bone_name(i),"parent":actor.avatar.skeleton.get_bone_parent(i),"rest":str(actor.avatar.skeleton.get_bone_rest(i))})
    print("R98_CURRENT_RIG ",actor.avatar.skeleton.get_bone_count()," ",JSON.stringify(bones).sha256_text())
    assert(actor.avatar.skeleton.get_bone_count()==58)
    var life=actor.health;var position=actor.global_position;var count=w.saved.size()
    w._retire(id);assert(w.saved.size()==count and not w.actors.has(id));await tree.physics_frame
    w._activate(id);actor=w.actors[id];actor.ai_enabled=false
    assert(actor.health==life and actor.global_position.distance_to(position)<.00001)
    var far_id="arr96_outer_001";var far=w.motor.point(w.saved[far_id].position)
    w.model.states[far_id].wait97=0;w.model.states[far_id].waypoint=1
    for step in range(12):w._physics_process(.2)
    assert(w.motor.point(w.saved[far_id].position).distance_to(far)>.05 and w.saved.size()==480)
    _freeze98(scene);_player_idle(p);assert(p.load_condition(),"baseline "+p.inventory_message)
    var uid=_equip92(scene,"pistol")
    # Start on real forest ground, not on a synthetic training platform.
    pair=_pair98(scene);id=pair.id;p.global_position=pair.player;p.velocity=Vector3.ZERO
    w._reconcile(480);_freeze98(scene);actor=w.actors[id]
    actor.avatar.rotation.y=PI;actor.memory=0;actor.search_remaining=0;actor.state="idle"
    for frame in 2:await tree.physics_frame
    assert(actor.sees_player());var start_distance=actor.global_position.distance_to(p.global_position)
    var start_hits=actor.hits
    for frame in range(600):
        await tree.physics_frame;actor.step(1.0/60)
        if actor.hits>start_hits:break
    assert(actor.hits==start_hits+1 and actor.global_position.distance_to(p.global_position)<start_distance,"chase/impact")
    assert(p.body_health.records.size()>0 and p.get_node("Demo95").integrity()<100)
    # Restore the deliberate QA checkpoint, then fire through the actual weapon service.
    _player_idle(p);actor.state="idle";actor.memory=0;actor.search_remaining=0
    assert(p.load_condition(),p.inventory_message);_freeze98(scene)
    uid=_equip92(scene,"pistol");p.global_position=pair.player;w._reconcile(480);_freeze98(scene);actor=w.actors[id]
    var result=await _shot91(scene,actor,pair.player,"head",60)
    assert(result.remaining<=.0001)
    for frame in range(130):await tree.physics_frame;actor.step(1.0/60)
    assert(actor.state=="dead" and actor.hit_regions91().is_empty())
    w.sync_actor(actor);scene.shoulder.set_aim(false);_step88(scene,.5);_player_idle(p)
    p.condition_path="res://qa/r98_after_fight.json";assert(p.save_condition(),"save "+p.inventory_message)
    var expected={"id":id,"position":w.saved[id].position.duplicate(),"weapon_uid":uid,"rounds":p.weapons.loaded(uid)}
    FileAccess.open("res://qa/r98_expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected,"",true,true))
    w._retire(id);await tree.physics_frame;w._activate(id);actor=w.actors[id];actor.ai_enabled=false
    assert(actor.state=="dead" and actor.health<=.0001 and w.saved.size()==480)
    assert(p.load_condition(),"reload "+p.inventory_message)
    assert(w.saved[id].state=="dead" and p.weapons.loaded(uid)==expected.rounds)
    scene.get_node("QAHost98").finish({"total":480,"live_models":w.actors.size(),"peak_live_models":w.peak_live,"map_homes":40,"legacy_aliases":2,"legacy_death_and_position_preflight":true,"background_movement":true,"perception_chase_and_impact":true,"real_headshot":true,"death_survives_presentation_retirement":true,"checkpoint_reload":true,"residential_doors":service.residential98.rows.size(),"residential_door_restore":true,"rig_bones":58})

func _native98(scene: Node3D) -> Dictionary:
    var p=scene.player;var w=scene.zombie_world;var aim=scene.shoulder;var tree=scene.get_tree()
    scene.get_window().size=Vector2i(960,600);w.restore(w.initial);_freeze98(scene);_player_idle(p)
    p.condition_path="res://qa/r98_baseline.json"
    if FileAccess.file_exists(p.condition_path):assert(p.load_condition(),p.inventory_message)
    _freeze98(scene)
    var uid=_equip92(scene,"pistol")
    assert(p.place_item(_find_weapon(p.bag_inventory,"ammo_pistol"),"pockets",2,0,false),p.inventory_message);_settle93(scene)
    assert(p.weapons.reload_weapon(),p.inventory_message);_settle93(scene)
    var pair={};var skip=[];var actor: CharacterBody3D
    for attempt in range(20):
        pair=_pair98(scene,skip,true);assert(not pair.is_empty())
        p.global_position=pair.player;p.velocity=Vector3.ZERO;scene.focus=p.global_position+Vector3.UP*.95;scene.zoom=5.8;scene._update_camera()
        w._reconcile(480);_freeze98(scene);actor=w.actors[pair.id];actor.restore(w.initial[pair.id]);actor.ai_enabled=false;actor.avatar.rotation.y=PI
        await tree.physics_frame
        if aim.set_aim(true):
            _step88(scene,.6);_look88(scene,actor.global_position+Vector3.UP*1.65);aim.set_aim(false);_step88(scene,.5);break
        skip.append(pair.id)
    assert(not aim.holding and actor!=null)
    _player_idle(p);p.avatar.rotation.y=0;actor.restore(w.initial[pair.id]);actor.avatar.rotation.y=PI;actor.ai_enabled=false
    Engine.physics_ticks_per_second=25;Engine.max_fps=25;aim.rng.seed=98
    var first_hits=actor.hits;var starting_distance=actor.global_position.distance_to(p.global_position);var fired=false;var shot={};var frames=150
    for frame in range(frames):
        await tree.physics_frame
        if frame==20:assert(aim.set_aim(true),p.inventory_message)
        if aim.holding and actor.state not in ["dying","dead"]:
            var region=_region91(actor,"head");var target: Vector3=(region.a+region.b)*.5;var direction=target-scene.camera.global_position
            aim.yaw=lerp_angle(aim.yaw,atan2(direction.x,direction.z),.5);aim.pitch=lerpf(aim.pitch,atan2(direction.y,Vector2(direction.x,direction.z).length()),.5)
        if frame==45:fired=p.request_attack();assert(fired,p.inventory_message)
        _player94(scene,.04);actor.step(.04)
        if frame==80:shot=p.map_combat.last_shot.duplicate(true)
        if frame==115:aim.set_aim(false)
        if not aim.holding and aim.progress<.001:scene.focus=p.global_position+Vector3.UP*.95;scene._update_camera()
        await tree.process_frame;await RenderingServer.frame_post_draw
        var file="res://previews/population98/%03d.png"%frame;DirAccess.make_dir_recursive_absolute(file.get_base_dir())
        scene.get_viewport().get_texture().get_image().save_png(file)
    assert(actor.global_position.distance_to(p.global_position)<starting_distance and fired and shot.get("hit",false) and actor.state=="dead",str(shot))
    return {"capture":true,"frames":frames,"fps":25,"population":480,"hits":actor.hits-first_hits,"shots":1,"zombie_dead":true,"remaining_rounds":p.weapons.loaded(uid),"shot_zone":shot.event.zone,"location":"actual woodland near Arroio","markers_used":false}

func _clear_view98(scene: Node3D,p: Vector3,a: Vector3) -> bool:
    if view_trees98.is_empty():
        for tree in scene.city.find_children("Trunk_*","StaticBody3D",true,false):view_trees98.append(Vector2(tree.global_position.x,tree.global_position.z))
    var direction=Vector2(1,-1).normalized()*22
    for start in [Vector2(p.x,p.z),Vector2(a.x,a.z)]:
        for tree in view_trees98:
            if tree.distance_to(start)>25:continue
            var nearest=Geometry2D.get_closest_point_to_segment(tree,start,start+direction)
            if tree.distance_to(nearest)<2.2:return false
    return true

