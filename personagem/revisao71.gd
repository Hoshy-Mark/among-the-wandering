extends RefCounted
func run(scene: Node3D) -> void:
    var h: Node3D=scene.world_items.house
    var world: Node3D=scene.world_items
    var body: CharacterBody3D=scene.player
    var model: RefCounted=body.bag_inventory
    var ui: Control=scene.game_ui
    var capture="--capture-storage" in OS.get_cmdline_user_args()
    scene.get_window().size=Vector2i(1440,900)
    body.scripted=true
    body.set_physics_process(false)
    world.set_physics_process(false)
    scene.set_process(false)
    var original=model.snapshot()
    assert(h.groups.size()==9 and h.bindings.size()==15 and original.items.size()==29)
    var ids: Array=[]
    for id in h.bindings:
        if str(id).contains("PIA") or str(id).contains("ESTANTE") or str(id).contains("DESPENSA"):
            ids.append(id)
    assert(ids.size()==3)
    for id in ids:
        h.visit(id)
        await scene.get_tree().physics_frame
        body.update_nearby()
        var group: Dictionary=h.groups[h.bindings[id]]
        assert(h.standing_clear(group.point) and h.in_room(h.bindings[id],body.global_position))
        assert(id in model.reachable and h.clear_to_open(id),str(h.last_clearance))
        assert(model.dimensions(id)==Vector2i(4,3))
        assert(group.parts.size()==(2 if group.role=="sink_cabinet" else 0))
        # Point-click on the actual cabinet selects the intended container.
        var center: Vector3=h.home.model.to_global(group.bounds.get_center())
        scene.camera.size=3.8
        scene.camera.global_position=center+group.front*6+Vector3.UP*3
        scene.camera.look_at(center)
        ui.personal.visible=false
        ui.nearby.visible=false
        ui.sync_lock()
        for frame in 3:
            await scene.get_tree().process_frame
        var click=InputEventMouseButton.new()
        click.button_index=MOUSE_BUTTON_LEFT
        click.pressed=true
        click.position=scene.camera.unproject_position(center)
        Input.parse_input_event(click)
        Input.flush_buffered_events()
        assert(world.pending_id==id)
        _tick(body,world,.75)
        assert(world.active_id==id and model.accessible(id) and ui.near_source==id)
        if group.role=="sink_cabinet":
            assert(is_equal_approx(group.parts[0].fraction,1) and is_equal_approx(group.parts[1].fraction,1))
            assert(not h.home.preparation.entries[h.bindings[id]].meshes["H01_FURN_PIA_COZ__01__portas"].visible)
        for label in ui.find_children("*","Label",true,false):
            assert(not str(label.text).to_lower().contains("cada fonte"))
        var stock=model.contents(id)
        if stock.is_empty():
            var bandage=""
            for uid in model.contents("pockets"):
                if model.items[uid].definition=="bandage":bandage=uid
            assert(not bandage.is_empty())
            assert(body.place_item(bandage,id,0,0,false,1,true))
            stock=model.contents(id)
        var uid: String=stock[0]
        assert(body.place_item(uid,"pockets",1,1,false))
        assert(body.place_item(uid,id,3,2,false))
        var saved=model.snapshot()
        assert(model.restore(JSON.parse_string(JSON.stringify(saved))))
        assert(model.items[uid].location==id and model.items[uid].x==3 and model.items[uid].y==2)
        assert(not model.accessible(id))
        body.update_nearby()
        assert(model.set_open(id,true))
        assert(body.place_item(uid,"pockets",1,1,false))
        var empty=model.snapshot()
        assert(model.restore(empty) and model.contents(id).is_empty())
        assert(not model.accessible(id))
        world.close_interaction()
        _tick(body,world,.5)
        assert(model.restore(original))
        if group.role=="sink_cabinet":
            var part: Dictionary=group.parts[0]
            var half: Transform3D=part.pivot.get_parent().global_transform*part.closed_transform*Transform3D(Basis(part.axis,deg_to_rad(50)*part.sign),Vector3.ZERO)*part.proxy.transform
            var blocker=StaticBody3D.new()
            blocker.collision_layer=2
            var shape=CollisionShape3D.new()
            var box=BoxShape3D.new()
            box.size=Vector3(.035,.10,.035)
            shape.shape=box
            blocker.add_child(shape)
            scene.add_child(blocker)
            blocker.global_position=half.origin
            await scene.get_tree().physics_frame
            var before=model.snapshot()
            assert(not h.clear_to_open(id) and not world.request_open(id) and model.snapshot()==before)
            blocker.queue_free()
            await scene.get_tree().physics_frame
            assert(h.clear_to_open(id))
            assert(h.apply_sink(h.bindings[id],1))
            blocker=StaticBody3D.new()
            blocker.collision_layer=2
            shape=CollisionShape3D.new()
            shape.shape=box
            blocker.add_child(shape)
            scene.add_child(blocker)
            blocker.global_position=half.origin
            await scene.get_tree().physics_frame
            assert(not h.apply_sink(h.bindings[id],0) and is_equal_approx(part.fraction,1))
            blocker.queue_free()
            await scene.get_tree().physics_frame
            assert(h.apply_sink(h.bindings[id],0))
            var standing=body.global_position
            body.global_position=half.origin-Vector3.UP*.5
            body.global_position.y=standing.y
            await scene.get_tree().physics_frame
            await scene.get_tree().physics_frame
            assert(not h.clear_to_open(id))
            body.global_position=standing
            await scene.get_tree().physics_frame
            await scene.get_tree().physics_frame
            assert(h.clear_to_open(id))
    var legacy=original.duplicate(true)
    for id in ids:legacy.world_containers.erase(id)
    for uid in legacy.items.keys():
        if legacy.items[uid].location in ids:legacy.items.erase(uid)
    assert(model.restore(legacy))
    for id in ids:
        assert(model.world_containers.has(id) and model.contents(id).is_empty())
    assert(model.restore(original))
    var result={"furniture":9,"compartments":15,"new_storage":3,"sink_leaves":2,"shelf_no_fake_doors":true,"point_and_click":true,"room_clearance":true,"separate_stock":true,"manual_coordinates":true,"save_load":true,"old_profile_empty_anchors":true,"no_loot_respawn":true,"sink_blocked_open_atomic":true,"sink_blocked_close_resumes":true,"actor_sweep":true,"removed_note_preserved":true}
    if capture:
        for index in ids.size():
            var id: String=ids[index]
            h.visit(id)
            await scene.get_tree().physics_frame
            body.update_nearby()
            var group: Dictionary=h.groups[h.bindings[id]]
            var center: Vector3=h.home.model.to_global(group.bounds.get_center())
            var focus=(center+body.global_position+Vector3.UP*.5)/2
            var axis: Vector3=group.front+Vector3.UP*.9-group.front.cross(Vector3.UP)*.6
            scene.camera.size=4.0
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
            focus-=scene.camera.global_basis.x*.7
            scene.camera.size=4.6
            scene.camera.global_position=focus+axis*10
            scene.camera.look_at(focus)
            await _capture(scene,str(index)+"_hud")
            ui.visible=false
            world.close_interaction()
            _tick(body,world,.5)
            if group.role=="sink_cabinet":
                for frame in 24:
                    if frame==3:assert(world.request_open(id))
                    if frame==16:world.close_interaction()
                    _tick(body,world,.05)
                    await _capture(scene,"sink_frames/%02d"%frame)
        result.native_capture=true
    FileAccess.open("res://qa/storage71.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R71_STORAGE_OK ",result)
    scene.get_tree().quit()

func _tick(body: CharacterBody3D, world: Node3D, seconds: float) -> void:
    for frame in ceili(seconds/.01):
        body.action.advance(.01)
        world.advance(.01)

func _capture(scene: Node3D, name: String) -> void:
    for frame in 4:await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/storage71/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
