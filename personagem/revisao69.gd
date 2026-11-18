extends RefCounted
var results: Dictionary={}
func run(scene: Node3D) -> void:
    var h: Node3D=scene.world_items.house
    var world: Node3D=scene.world_items
    var body: CharacterBody3D=scene.player
    var model: RefCounted=body.bag_inventory
    var ui: Control=scene.game_ui
    var capture="--capture-drawers" in OS.get_cmdline_user_args()
    scene.get_window().size=Vector2i(1440,900)
    body.scripted=true
    body.set_physics_process(false)
    world.set_physics_process(false)
    var original=model.snapshot()
    var ids: Array=[]
    for id in h.bindings:
        if h.groups[h.bindings[id]].has("drawers"):
            ids.append(id)
    assert(ids.size()==5 and h.groups.size()==4 and h.bindings.size()==8)
    for id in ids:
        var group: String=h.bindings[id]
        var part: Dictionary=h.groups[group].drawers[id]
        h.visit(id)
        await scene.get_tree().physics_frame
        body.update_nearby()
        assert(id in model.reachable and h.standing_clear(h.groups[group].point) and h.in_room(group,body.global_position))
        assert(h.clear_to_open(id),str(h.last_clearance))
        assert(model.dimensions(id)==Vector2i(4,2))
        assert(world.request_open(id))
        _tick(body,world,.75)
        assert(world.active_id==id and model.accessible(id) and is_equal_approx(part.fraction,1))
        assert(part.pivot.transform.basis.is_equal_approx(part.closed_transform.basis))
        assert(is_equal_approx(part.pivot.position.distance_to(part.closed_transform.origin),part.travel))
        for other in h.groups[group].drawers:
            if other!=id:
                assert(not model.accessible(other) and is_zero_approx(h.groups[group].drawers[other].fraction))
        assert(ui.nearby.visible and ui.near_source==id and world.nearest_id==id)
        var stock=model.contents(id)
        if not stock.is_empty():
            var uid: String=stock[0]
            assert(body.place_item(uid,"pockets",1,1,false))
            assert(model.items[uid].location=="pockets")
            assert(body.place_item(uid,id,3,1,false))
            var saved=model.snapshot()
            assert(model.restore(JSON.parse_string(JSON.stringify(saved))))
            assert(model.items[uid].x==3 and model.items[uid].y==1)
            # Restoring stock closes access and cannot replenish an empty drawer.
            assert(not model.accessible(id))
            model.set_open(id,true)
        world.close_interaction()
        _tick(body,world,.5)
        assert(is_zero_approx(part.fraction) and not model.accessible(id))
        # Swept whole drawer volume rejects a new obstacle before any inventory change.
        var blocker=StaticBody3D.new()
        blocker.collision_layer=2
        var shape=CollisionShape3D.new()
        var box=BoxShape3D.new()
        box.size=Vector3(.035,.035,.035)
        shape.shape=box
        blocker.add_child(shape)
        scene.add_child(blocker)
        var collision: CollisionShape3D=part.drawer_collision
        blocker.global_position=collision.global_position+h.groups[group].front*(part.travel+collision.shape.size.x/2-.025)
        await scene.get_tree().physics_frame
        var before=model.snapshot()
        assert(not h.clear_to_open(id))
        assert(not world.request_open(id) and model.snapshot()==before and world.pending_id.is_empty())
        blocker.queue_free()
        await scene.get_tree().physics_frame
        assert(h.clear_to_open(id))
        # A blocked close retains the last safe pose, then resumes after clearance.
        assert(h.apply_drawer(id,1))
        blocker=StaticBody3D.new()
        blocker.collision_layer=2
        shape=CollisionShape3D.new()
        shape.shape=box
        blocker.add_child(shape)
        scene.add_child(blocker)
        blocker.global_position=collision.global_position-h.groups[group].front*(part.travel+collision.shape.size.x/2-.025)
        await scene.get_tree().physics_frame
        assert(not h.apply_drawer(id,0) and is_equal_approx(part.fraction,1))
        blocker.queue_free()
        await scene.get_tree().physics_frame
        assert(h.apply_drawer(id,0))
    assert(model.restore(original))
    # A prior C05 save gains empty anchors without creating replacement loot.
    var legacy=original.duplicate(true)
    for id in ids:
        legacy.world_containers.erase(id)
    for uid in legacy.items.keys():
        if legacy.items[uid].location in ids:
            legacy.items.erase(uid)
    assert(model.restore(legacy))
    for id in ids:
        assert(model.world_containers.has(id) and model.contents(id).is_empty())
    var empty_save=model.snapshot()
    assert(model.restore(empty_save))
    for id in ids:
        assert(model.contents(id).is_empty())
    assert(model.restore(original))
    # Keyboard selection is real input and does not open or alter stock.
    h.visit(ids[0])
    await scene.get_tree().physics_frame
    body.update_nearby()
    ui.personal.visible=false
    ui.nearby.visible=false
    ui.sync_lock()
    world._update_prompt()
    var selected=world.nearest_id
    var key=InputEventKey.new()
    key.keycode=KEY_J
    key.pressed=true
    Input.parse_input_event(key)
    Input.flush_buffered_events()
    await scene.get_tree().process_frame
    assert(world.nearest_id!=selected and not world.has_interaction())
    # Pointer click selects the actual front, rather than a click_group-wide proxy.
    scene.set_process(false)
    var click_id: String=ids[0]
    var click_group: Dictionary=h.groups[h.bindings[click_id]]
    var click_part: Dictionary=click_group.drawers[click_id]
    var click_focus: Vector3=click_part.leaf.global_transform*click_part.leaf.mesh.get_aabb().get_center()
    scene.camera.global_position=click_focus+click_group.front*4+Vector3.UP*1.3
    scene.camera.look_at(click_focus)
    scene.camera.size=2.5
    for frame in 3:
        await scene.get_tree().process_frame
    var click=InputEventMouseButton.new()
    click.button_index=MOUSE_BUTTON_LEFT
    click.pressed=true
    click.position=scene.camera.unproject_position(click_focus)
    Input.parse_input_event(click)
    Input.flush_buffered_events()
    assert(world.pending_id==click_id)
    _tick(body,world,.75)
    assert(world.active_id==click_id and world.nearest_id==click_id)
    world.close_interaction()
    _tick(body,world,.5)
    # The player's own capsule is included in the opening sweep.
    var standing=body.global_position
    body.global_position=click_part.drawer_collision.global_position+click_group.front*click_part.travel
    body.global_position.y=standing.y
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    assert(not h.clear_to_open(click_id))
    body.global_position=standing
    await scene.get_tree().physics_frame
    assert(h.clear_to_open(click_id))
    results={"drawers":5,"furniture":2,"individual_access":true,"translation_only":true,"whole_volume_sweep":true,"blocked_open_atomic":true,"blocked_close_resumes":true,"spatial_transfers":true,"save_load_coordinates":true,"prior_profile_empty_anchors":true,"no_loot_respawn":true,"keyboard_selection":true,"pointer_front_selection":true,"player_capsule_sweep":true,"room_and_standing_clearance":true}
    if capture:
        scene.set_process(false)
        for index in [0,2]:
            var id: String=ids[index]
            h.visit(id)
            await scene.get_tree().physics_frame
            body.update_nearby()
            var group: Dictionary=h.groups[h.bindings[id]]
            var center: Vector3=h.home.model.to_global(group.bounds.get_center())
            var axis: Vector3=group.front+Vector3.UP*.9+group.front.cross(Vector3.UP)*.6
            var focus=(center+body.global_position+Vector3.UP*.5)/2
            scene.camera.size=3.8
            scene.camera.global_position=focus+axis*10
            scene.camera.look_at(focus)
            ui.visible=false
            await _capture(scene,str(index)+"_closed")
            assert(world.request_open(id))
            _tick(body,world,.75)
            await _capture(scene,str(index)+"_open")
            ui.visible=true
            ui.personal.visible=false
            ui.nearby_wanted=true
            ui.refresh()
            focus-=scene.camera.global_basis.x*.65
            scene.camera.global_position=focus+axis*10
            scene.camera.look_at(focus)
            scene.camera.size=4.4
            await _capture(scene,str(index)+"_hud")
            ui.visible=false
            world.close_interaction()
            _tick(body,world,.5)
            for frame in 24:
                if frame==3:
                    assert(world.request_open(id))
                if frame==16:
                    world.close_interaction()
                _tick(body,world,.05)
                await _capture(scene,str(index)+"_frames/%02d"%frame)
        results.native_capture=true
    DirAccess.make_dir_recursive_absolute("res://qa")
    FileAccess.open("res://qa/drawers69.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    print("R69_DRAWERS_OK ",results)
    scene.get_tree().quit()

func _tick(body: CharacterBody3D, world: Node3D, seconds: float) -> void:
    for index in ceili(seconds/.01):
        body.action.advance(.01)
        world.advance(.01)

func _capture(scene: Node3D, name: String) -> void:
    for frame in 4:
        await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/drawers69/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
