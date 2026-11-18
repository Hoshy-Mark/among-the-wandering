extends RefCounted
func run(scene: Node3D) -> void:
    var body: CharacterBody3D=scene.player
    var c: Node3D=body.map_doors
    var house: Node3D=scene.world_items.house
    var model: RefCounted=body.bag_inventory
    var capture="--capture-doors" in OS.get_cmdline_user_args()
    scene.get_window().size=Vector2i(1440,900)
    body.scripted=true
    body.set_physics_process(false)
    var origin=body.global_position
    var initial=model.snapshot()
    var closed=c.snapshot()
    assert(c.doors.size()==4 and not c.busy())
    for data in c.doors.values():
        assert(not data.open and data.leaf.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
    for id in c.doors:
        var data: Dictionary=c.doors[id]
        await _stand(scene,id,-1)
        if id.contains("Q1"):
            scene.set_process(false)
            var center: Vector3=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()
            var axis=body.global_position-center
            axis.y=0
            scene.camera.size=2.8
            scene.camera.global_position=center+axis.normalized()*2+Vector3.UP*.7
            scene.camera.look_at(center)
            for frame in 3:await scene.get_tree().process_frame
            var mouse=InputEventMouseButton.new()
            mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=scene.camera.unproject_position(center);mouse.pressed=true
            Input.parse_input_event(mouse);Input.flush_buffered_events()
            mouse=mouse.duplicate();mouse.pressed=false
            Input.parse_input_event(mouse);Input.flush_buffered_events()
            assert(c.pending==id)
            scene.set_process(true)
        else:
            assert(c.request(id))
        assert(not c.request(id) and not body.save_condition())
        body.action.advance(.05)
        body.action.cancel()
        assert(not c.busy() and not data.open and is_zero_approx(data.fraction))
        assert(c.request(id))
        body.action.advance(10)
        await _settled(scene)
        assert(data.open and is_equal_approx(data.fraction,1) and model.items==initial.items)
        await _stand(scene,id,1)
        assert(c.request(id))
        body.action.advance(10)
        await _settled(scene)
        assert(not data.open and is_zero_approx(data.fraction))
        # A physical object in the sweep blocks opening before any state change.
        var query_pose: Transform3D=data.hinge.get_parent().global_transform*c._pose(data,.5)*data.body.transform*data.collider.transform
        var blocker=StaticBody3D.new()
        blocker.collision_layer=2
        var shape=CollisionShape3D.new()
        var box=BoxShape3D.new()
        box.size=Vector3(.06,.20,.06)
        shape.shape=box
        blocker.add_child(shape)
        scene.add_child(blocker)
        blocker.global_position=query_pose.origin
        await scene.get_tree().physics_frame
        assert(not c.request(id) and not c.busy() and not data.open)
        blocker.queue_free()
        await scene.get_tree().physics_frame
        assert(c.clear_path(id,1))
    var q1="H01/Hinge_BASE_PORTAL_D_Q1_LEAF_PIVOT"
    var door: Dictionary=c.doors[q1]
    await _stand(scene,q1,-1)
    assert(c.request(q1))
    body.action.advance(10)
    await _settled(scene)
    # Add a blocker only after a valid close has started; it must pause safely.
    assert(c.request(q1))
    body.action.advance(10)
    var blocker=StaticBody3D.new()
    blocker.collision_layer=2
    var shape=CollisionShape3D.new()
    var box=BoxShape3D.new()
    box.size=Vector3(.06,.2,.06)
    shape.shape=box
    blocker.add_child(shape)
    scene.add_child(blocker)
    blocker.global_position=(door.hinge.get_parent().global_transform*c._pose(door,.5)*door.body.transform*door.collider.transform).origin
    await scene.get_tree().physics_frame
    for frame in 35:await scene.get_tree().physics_frame
    assert(c.busy() and door.fraction>0 and door.fraction<1)
    blocker.queue_free()
    await scene.get_tree().physics_frame
    await _settled(scene)
    assert(not door.open)
    # Player capsule is part of the same sweep query.
    var sweep=(door.hinge.get_parent().global_transform*c._pose(door,.5)*door.body.transform*door.collider.transform).origin
    body.global_position=Vector3(sweep.x,origin.y,sweep.z)
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    assert(not c.clear_path(q1,1))
    body.global_position=origin
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    # Closed leaf physically stops the normal movement controller.
    body.set_physics_process(true)
    var target: Vector3=house.home.model.to_global(Vector3(1.73,.275,1.0))
    var direction=(target-body.global_position).normalized()
    var right: Vector3=scene.camera.global_basis.x;right.y=0
    var down: Vector3=scene.camera.global_basis.z;down.y=0
    body.command=Vector2(direction.dot(right.normalized()),direction.dot(down.normalized()))
    for frame in 75:await scene.get_tree().physics_frame
    body.command=Vector2.ZERO
    for frame in 10:await scene.get_tree().physics_frame
    assert(house.home.model.to_local(body.global_position).z<.48)
    # Use E with the correct priority over nearby furniture.
    _key(KEY_E)
    assert(c.pending==q1 and not scene.world_items.has_interaction(),"pending="+c.pending+" nearest="+c.nearest+" prefer="+str(c.prefers())+" point="+str(house.home.model.to_local(body.global_position))+" hit="+str(c.last_hit))
    await _settled(scene)
    assert(door.open and not scene.game_ui.nearby.visible)
    body.set_physics_process(false)
    body.global_position=origin
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    body.condition_path="user://qa_doors_r74.json"
    assert(body.save_condition())
    var saved=JSON.parse_string(FileAccess.get_file_as_string(body.condition_path))
    assert(saved.doors_h01.states[q1])
    c.apply_restore(closed)
    assert(body.load_condition() and door.open)
    var before=model.snapshot()
    var state=c.snapshot()
    var invalid=saved.duplicate(true)
    invalid.doors_h01.states[q1]="yes"
    for item in invalid.inventory.items.values():
        if item.definition=="bandage" and item.location=="pockets":item.count=2
    FileAccess.open(body.condition_path,FileAccess.WRITE).store_string(JSON.stringify(invalid))
    assert(not body.load_condition() and model.items==before.items and c.snapshot()==state)
    # Refuse a load that would close a leaf on the player, before applying stock.
    saved.doors_h01=closed
    FileAccess.open(body.condition_path,FileAccess.WRITE).store_string(JSON.stringify(saved))
    var center: Vector3=door.hinge.get_parent().global_transform*c._pose(door,0)*door.body.transform*door.collider.transform.origin
    body.global_position=Vector3(center.x,origin.y,center.z)
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    assert(not body.load_condition() and model.items==before.items and door.open)
    body.global_position=origin
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    # Old inventory profiles have no door section and start with closed leaves.
    saved.erase("doors_h01")
    FileAccess.open(body.condition_path,FileAccess.WRITE).store_string(JSON.stringify(saved))
    assert(body.load_condition() and c.snapshot()==closed)
    if capture:
        scene.set_process(false)
        scene.game_ui.personal.visible=false
        scene.game_ui.nearby_wanted=false
        scene.game_ui.refresh()
        var focus: Vector3=door.leaf.global_transform*door.leaf.mesh.get_aabb().get_center()
        var axis=body.global_position-focus
        axis.y=0
        axis=axis.normalized()
        axis=axis+Vector3.UP*.9-axis.cross(Vector3.UP)*.6
        scene.camera.size=4.0
        scene.camera.global_position=focus+axis*9
        scene.camera.look_at(focus)
        await _capture(scene,"closed")
        for frame in 28:
            if frame==3:assert(c.request(q1))
            body.action.advance(.035)
            c._physics_process(.035)
            await _capture(scene,"frames/%02d"%frame)
        body.action.advance(10)
        await _settled(scene)
        await _capture(scene,"open")
        assert(c.request(q1))
        body.action.advance(10)
        await _settled(scene)
        await _capture(scene,"closed_again")
        for other in c.doors:
            if other==q1:continue
            await _stand(scene,other,-1)
            var data: Dictionary=c.doors[other]
            var tag="entry" if data.exterior else "bathroom" if other.contains("WC") else "bedroom2"
            var capture_center: Vector3=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()
            var capture_direction=body.global_position-capture_center
            capture_direction.y=0
            capture_direction=capture_direction.normalized()
            var view=capture_direction+Vector3.UP*.9-capture_direction.cross(Vector3.UP)*.6
            scene.camera.global_position=capture_center+view*9
            scene.camera.look_at(capture_center)
            await _capture(scene,tag+"_closed")
            assert(c.request(other))
            body.action.advance(10)
            await _settled(scene)
            await _capture(scene,tag+"_open")
            assert(c.request(other))
            body.action.advance(10)
            await _settled(scene)
        scene.set_process(true)
    var result={"real_doors":4,"both_sides":true,"click_interaction":true,"cancel_before_effect":true,"one_context_for_e":true,"inventory_unchanged":true,"blocked_preflight":true,"blocked_close_resumes":true,"actor_sweep":true,"closed_leaf_blocks_walk":true,"e_opens_without_inventory":true,"saved_states":true,"invalid_restore_atomic":true,"occupied_restore_atomic":true,"legacy_profile":true}
    if capture:result.native_capture=true
    FileAccess.open("res://qa/doors74.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R74_DOORS_OK ",result)
    # Continue through the previous real inventory route with the bedroom open.
    var ready=closed.duplicate(true);ready.states[q1]=true
    c.apply_restore(ready)
    body.global_position=origin
    body.set_physics_process(true)
    await load("res://personagem/revisao73.gd").new().run(scene)

func _stand(scene: Node3D, id: String, side: int) -> void:
    var c: Node3D=scene.player.map_doors
    var d: Dictionary=c.doors[id]
    var base: Transform3D=d.hinge.get_parent().global_transform*c._pose(d,0)
    var center: Vector3=base*d.leaf.transform*d.leaf.mesh.get_aabb().get_center()
    var normal=(base.basis*(Vector3.RIGHT if d.collider.shape.size.x<d.collider.shape.size.z else Vector3.BACK)).normalized()
    var tangent=normal.cross(Vector3.UP)
    for distance in [.5,.65,.8,1.05,1.35]:
        for offset in [0,-.5,.5]:
            var point=center+normal*side*distance+tangent*offset
            point.y=scene.spawn.y
            scene.player.global_position=point
            await scene.get_tree().physics_frame
            await scene.get_tree().physics_frame
            var standing: bool=scene.world_items.house.standing_clear(point-Vector3.UP*.02)
            var reachable: bool=c._reachable(d)
            var path_clear: bool=c.clear_path(id,0 if d.open else 1)
            if standing and reachable and path_clear:return
    assert(false,"No free approach to "+id+" side "+str(side)+" "+str(c.last_hit))
func _settled(scene: Node3D) -> void:
    for frame in 300:
        if not scene.player.map_doors.busy() and scene.player.action.state=="idle":return
        if not scene.player.is_physics_processing():scene.player.action.advance(.0166667)
        await scene.get_tree().physics_frame
    assert(false,"Door did not settle "+str(scene.player.map_doors.last_hit))
func _key(code: int) -> void:
    var event=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
    Input.parse_input_event(event);Input.flush_buffered_events()
    event=event.duplicate();event.pressed=false
    Input.parse_input_event(event);Input.flush_buffered_events()
func _capture(scene: Node3D, name: String) -> void:
    for frame in 3:await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/doors74/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
