extends "res://personagem/revisao75.gd"
func _write(path: String,data: Variant) -> void:
    FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data,"",true,true))
func _same(a: Variant,b: Variant) -> bool:
    if (a is float or a is int) and (b is float or b is int):return is_equal_approx(float(a),float(b))
    if a is Dictionary and b is Dictionary:
        if a.size()!=b.size():return false
        for key in a:
            if not b.has(key) or not _same(a[key],b[key]):return false
        return true
    if a is Array and b is Array:
        if a.size()!=b.size():return false
        for i in a.size():
            if not _same(a[i],b[i]):return false
        return true
    return a==b
func run(scene: Node3D) -> void:
    var p=scene.player
    var s=p.session_save
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)

    scene.get_window().size=Vector2i(1440,900)
    p.condition_path="user://qa_session81.json"
    if "--session-reopen" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message)
        await scene.get_tree().physics_frame
        await scene.get_tree().physics_frame
        await scene.get_tree().physics_frame
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/session81_expected.json"))
        assert(_same(s.snapshot(),expected),"Fresh-process snapshot differs")
        assert(scene.world_items.active_id==expected.session81.furniture.active)
        print("R81_FRESH_PROCESS_OK")
        scene.get_tree().quit();return
    for suffix in ["",".bak",".tmp"]:
        if FileAccess.file_exists(p.condition_path+suffix):DirAccess.remove_absolute(p.condition_path+suffix)
    var initial=s.snapshot()
    assert(not s.prepare(initial).is_empty(),s.reason)
    var c=p.condition_state
    c.hunger=42.125;c.thirst=63.75;c.medicine_remaining=17.25;c.set_stamina(61)
    assert(p.body_health.hit("qa81","forearm_left","cut",.1))
    p.survival.update_pain()
    p.avatar.rotation.y=.7;scene.zoom=7.5
    var uid=p.bag_inventory.add_at("water",1,"pockets",1,0,false)
    assert(not uid.is_empty())
    assert(p.bag_inventory.drop_at(uid,0,0,false))
    assert(p.save_condition(),p.inventory_message)
    var saved=s.snapshot()
    c.hunger=99;c.thirst=99;c.medicine_remaining=0
    p.global_position+=Vector3(0,0,.4);p.avatar.rotation.y=-1;scene.zoom=12
    assert(p.load_condition(),p.inventory_message)
    assert(_same(saved,s.snapshot()),"Roundtrip snapshot differs")
    var crouch=saved.duplicate(true);crouch.session81.crouched=true
    _write(p.condition_path,crouch)
    assert(p.load_condition() and p.crouched and is_equal_approx(p.capsule.shape.height,1.56))
    _write(p.condition_path,saved)
    assert(p.load_condition() and not p.crouched and is_equal_approx(p.capsule.shape.height,1.84))
    # Block the saved actor, then check that all state is preserved on refusal.
    var obstacle=StaticBody3D.new();obstacle.collision_layer=1
    var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.5,.5,.5);collision.shape=box
    obstacle.add_child(collision);scene.add_child(obstacle)
    obstacle.global_position=p.global_position+Vector3.UP*.8
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    var before=s.snapshot()
    assert(not p.load_condition() and s.reason=="occupied")
    assert(_same(before,s.snapshot()))
    obstacle.queue_free()
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    for field in ["position","zoom","world","furniture"]:
        var bad=saved.duplicate(true)
        if field=="position":bad.session81.position=[10000,10000,10000]
        elif field=="zoom":bad.session81.zoom=0
        elif field=="world":bad.session81.world="other"
        else:bad.session81.furniture.states.clear()
        _write(p.condition_path,bad)
        before=s.snapshot()
        assert(not p.load_condition(),field)
        assert(_same(before,s.snapshot()),field)
    # Legacy profile: no full-session data, still restores inventory and health.
    var legacy=saved.duplicate(true);legacy.erase("session81")
    _write(p.condition_path,legacy)
    assert(p.load_condition() and p.inventory_message.contains("anterior"))
    assert(_same(p.bag_inventory.snapshot(),saved.inventory))
    # Interrupted actions and unstable furniture never produce a partial save.
    p.combat.set_guard(true)
    assert(not p.save_condition() and not p.load_condition())
    p.combat.set_guard(false)
    var id=""
    for binding in scene.world_items.house.bindings:
        if scene.world_items.house.groups[scene.world_items.house.bindings[binding]].parts.is_empty():id=binding;break
    assert(not id.is_empty())
    scene.world_items.progress[id]=.5
    assert(not p.save_condition())
    scene.world_items.progress[id]=0
    # Current door geometry must not interfere with future saved door geometry.
    var doors=p.map_doors.snapshot()
    var tested_doors=[]
    for door in doors.states:
        var candidate=saved.duplicate(true);candidate.doors_h01.states[door]=true
        var prepared=s.prepare(candidate)
        if prepared.is_empty():continue
        _write(p.condition_path,candidate)
        assert(p.load_condition(),door+" "+p.inventory_message)
        assert(p.map_doors.snapshot().states[door])
        tested_doors.append(door)
        _write(p.condition_path,saved)
        assert(p.load_condition(),door+" close "+p.inventory_message)
    # Real furniture endpoint + active compartment + per-drawer selection.
    var world=scene.world_items
    var chosen=""
    var furniture_cases=[]
    var tested_groups=[]
    for binding in world.house.bindings:
        var group=world.house.bindings[binding]
        if group in tested_groups:continue
        var point: Vector3=world.house.groups[group].point
        var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1)
        var floor=scene.get_world_3d().direct_space_state.intersect_ray(ray)
        if floor.is_empty():continue
        point.y=floor.position.y+.02
        var candidate=saved.duplicate(true);candidate.session81.position=[point.x,point.y,point.z]
        for other in world.house.bindings:
            if world.house.bindings[other]==group and (not world.house.groups[group].has("drawers") or other==binding):candidate.session81.furniture.states[other]=true
        candidate.session81.furniture.opened=[binding];candidate.session81.furniture.active=binding
        if world.house.groups[group].has("drawers"):candidate.session81.furniture.chosen[group]=2
        if s.prepare(candidate).is_empty():continue
        _write(p.condition_path,candidate)
        assert(p.load_condition(),p.inventory_message)
        for frame in 4:await scene.get_tree().physics_frame
        if world.active_id!=binding:continue
        chosen=binding
        tested_groups.append(group)
        furniture_cases.append({"id":binding,"drawer":world.house.groups[group].has("drawers")})
    assert(furniture_cases.size()==9 and tested_doors.size()==11)
    assert(not chosen.is_empty(),"No safe active furniture case")
    assert(p.save_condition(),p.inventory_message)
    var active=s.snapshot()
    world.close_interaction()
    for frame in 100:await scene.get_tree().physics_frame
    assert(p.load_condition(),p.inventory_message)
    for frame in 4:await scene.get_tree().physics_frame
    assert(world.active_id==chosen and chosen in p.bag_inventory.opened and scene.game_ui.nearby.visible)
    assert(_same(active,s.snapshot()),"Active furniture roundtrip")
    # Backup recovery and preservation when the main file is structurally invalid.
    assert(p.save_condition())
    var backup=FileAccess.get_file_as_string(p.condition_path+".bak")
    FileAccess.open(p.condition_path,FileAccess.WRITE).store_string("{interrupted")
    assert(p.load_condition() and p.inventory_message.contains("Backup"))
    for frame in 4:await scene.get_tree().physics_frame
    var corrupt=active.duplicate(true);corrupt.condition.hunger=-1
    _write(p.condition_path,corrupt)
    assert(p.save_condition())
    assert(FileAccess.get_file_as_string(p.condition_path+".bak")==backup)
    var expected=s.snapshot()
    _write("res://qa/session81_expected.json",expected)
    _write(p.condition_path,expected)
    var checks={"roundtrip_position_facing_zoom":true,"inventory_ground_and_health":true,"active_medicine":true,"crouch_collision_restored":true,"occupied_atomic":true,"invalid_atomic":true,"legacy":true,"busy_refused":true,"door_endpoints":tested_doors,"furniture_active":chosen,"furniture_cases":furniture_cases,"backup_recovery":true,"backup_preserved":true}
    _write("res://qa/session81.json",checks)
    if "--capture-session" in OS.get_cmdline_user_args():
        scene.set_process(false)
        scene.game_ui.refresh()
        var point=p.global_position
        scene.camera.size=6;scene.camera.global_position=point+Vector3(-4,3,5);scene.camera.look_at(point+Vector3.UP*.9)
        await _capture81(scene,"resumed")
        world.close_interaction()
        point=world.house.home.model.to_global(Vector3(2.86,.01,-7))
        var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1)
        point.y=scene.get_world_3d().direct_space_state.intersect_ray(ray).position.y+.01
        p.global_position=point
        scene.camera.size=3.3;scene.camera.global_position=point+Vector3(-4,3,5);scene.camera.look_at(point+Vector3.UP*.9)
        scene.game_ui.toggle(1)
        p.survival.refresh()
        await _capture81(scene,"health")
    print("R81_SESSION_OK ",checks)
    scene.get_tree().quit()
func _capture81(scene: Node3D,name: String) -> void:
    for frame in 3:await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/session81/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)

