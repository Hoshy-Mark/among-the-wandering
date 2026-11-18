extends RefCounted
func run(scene: Node3D) -> void:
    var body: CharacterBody3D=scene.player
    var c: Node3D=body.map_doors
    var model: RefCounted=body.bag_inventory
    var capture="--capture-windows" in OS.get_cmdline_user_args()
    scene.get_window().size=Vector2i(1440,900)
    body.scripted=true
    body.set_physics_process(false)
    var origin=body.global_position
    var stock=model.snapshot()
    var initial=c.snapshot()
    assert(c.doors.size()==11 and initial.version==2)
    var windows: Array=c.doors.keys().filter(func(id):return str(id).contains("/window/"))
    assert(windows.size()==7)
    for id in windows:
        assert(await _stand(scene,id,-1),"No free window approach")
        if id==windows[0]:
            scene.set_process(false)
            var current: Dictionary=c.doors[id]
            var target: Vector3=current.leaf.global_transform*current.leaf.mesh.get_aabb().get_center()
            var view=body.global_position-target
            view.y=0
            scene.camera.size=2.8
            scene.camera.global_position=target+view.normalized()*2+Vector3.UP*.6
            scene.camera.look_at(target)
            for frame in 3:await scene.get_tree().process_frame
            var mouse=InputEventMouseButton.new()
            mouse.button_index=MOUSE_BUTTON_LEFT;mouse.position=scene.camera.unproject_position(target);mouse.pressed=true
            Input.parse_input_event(mouse);Input.flush_buffered_events()
            mouse=mouse.duplicate();mouse.pressed=false
            Input.parse_input_event(mouse);Input.flush_buffered_events()
            assert(c.pending==id)
            scene.set_process(true)
        else:
            assert(c.request(id))
        body.action.advance(.05)
        body.action.cancel()
        assert(not c.busy() and not c.doors[id].open)
        assert(c.request(id))
        body.action.advance(10)
        await _settled(scene)
        assert(c.doors[id].open and is_equal_approx(c.doors[id].fraction,1))
        assert(await _stand(scene,id,1),"No free window approach")
        assert(c.request(id))
        body.action.advance(10)
        await _settled(scene)
        assert(not c.doors[id].open and model.items==stock.items)
    var chosen: String=windows[0]
    var data: Dictionary=c.doors[chosen]
    assert(await _stand(scene,chosen,1),"No free window approach")
    # E chooses the real window and does not create an inventory interaction.
    _key(KEY_E)
    assert(c.pending==chosen and not scene.world_items.has_interaction())
    body.action.advance(10)
    await _settled(scene)
    assert(data.open and not scene.game_ui.nearby.visible)
    assert(c.request(chosen))
    body.action.advance(10)
    await _settled(scene)
    # A solid object blocks the path without changing inventory or window state.
    var pose: Transform3D=data.hinge.get_parent().global_transform*c._pose(data,.5)*data.body.transform*data.collider.transform
    var blocker=_blocker(scene,pose.origin)
    await scene.get_tree().physics_frame
    assert(not c.request(chosen) and not data.open and not c.busy())
    blocker.queue_free()
    await scene.get_tree().physics_frame
    assert(c.request(chosen))
    body.action.advance(10)
    await _settled(scene)
    assert(c.request(chosen))
    body.action.advance(10)
    blocker=_blocker(scene,pose.origin)
    await scene.get_tree().physics_frame
    for frame in 35:await scene.get_tree().physics_frame
    assert(c.busy() and data.fraction>0)
    assert(not body.save_condition())
    blocker.queue_free()
    await scene.get_tree().physics_frame
    await _settled(scene)
    assert(not data.open)
    # The character is included in the same swept-volume test.
    var normal: Vector3=data.hinge.get_parent().global_basis*Vector3(0,0,-1)
    body.global_position=pose.origin+normal*.25
    body.global_position.y=origin.y
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    assert(not c.clear_path(chosen,1))
    body.global_position=origin
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    assert(await _stand(scene,chosen,1),"No free window approach")
    assert(c.request(chosen))
    body.action.advance(10)
    await _settled(scene)
    body.condition_path="user://qa_windows_r75.json"
    assert(body.save_condition())
    var saved=JSON.parse_string(FileAccess.get_file_as_string(body.condition_path))
    assert(saved.doors_h01.version==2 and saved.doors_h01.states[chosen])
    c.apply_restore(initial)
    assert(body.load_condition() and data.open)
    var before=model.snapshot()
    var state=c.snapshot()
    var invalid=saved.duplicate(true)
    invalid.doors_h01.states[chosen]="open"
    FileAccess.open(body.condition_path,FileAccess.WRITE).store_string(JSON.stringify(invalid))
    assert(not body.load_condition() and c.snapshot()==state and model.items==before.items)
    # The previous four-door schema migrates with all windows closed.
    var legacy=saved.duplicate(true)
    legacy.doors_h01={"version":1,"states":{}}
    for id in c.doors:
        if id not in windows:legacy.doors_h01.states[id]=initial.states[id]
    FileAccess.open(body.condition_path,FileAccess.WRITE).store_string(JSON.stringify(legacy))
    assert(body.load_condition())
    for id in windows:assert(not c.doors[id].open)
    var result={"windows":7,"openings_total":11,"both_sides":true,"click_interaction":true,"cancel_before_effect":true,"e_context":true,"inventory_unchanged":true,"preflight_blocked":true,"close_pauses_and_resumes":true,"actor_sweep":true,"profile_v2":true,"invalid_profile_atomic":true,"legacy_four_door_schema":true,"traversal_not_enabled":true}
    if capture:
        scene.set_process(false)
        scene.game_ui.personal.visible=false
        scene.game_ui.nearby_wanted=false
        scene.game_ui.refresh()
        for index in [0,3,4]:
            var id: String=windows[index]
            assert(await _stand(scene,id,1),"No free window approach")
            var current: Dictionary=c.doors[id]
            var center: Vector3=current.leaf.global_transform*current.leaf.mesh.get_aabb().get_center()
            var direction=body.global_position-center
            direction.y=0
            direction=direction.normalized()
            if index==3:direction=(current.hinge.get_parent().global_basis*Vector3.BACK).normalized()
            var axis=direction+Vector3.UP*.75-direction.cross(Vector3.UP)*.6
            scene.camera.size=4.3
            scene.camera.global_position=center+axis*10
            scene.camera.look_at(center)
            await _capture(scene,str(index)+"_closed")
            assert(c.request(id))
            body.action.advance(10)
            await _settled(scene)
            await _capture(scene,str(index)+"_open")
            assert(c.request(id))
            body.action.advance(10)
            await _settled(scene)
            if index==0:
                for frame in 28:
                    if frame==3:assert(c.request(id))
                    body.action.advance(.035)
                    c._physics_process(.035)
                    await _capture(scene,"frames/%02d"%frame)
                body.action.advance(10)
                await _settled(scene)
                assert(c.request(id))
                body.action.advance(10)
                await _settled(scene)
        scene.set_process(true)
        result.native_capture=true
    FileAccess.open("res://qa/windows75.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R75_WINDOWS_OK ",result)
    c.apply_restore(initial)
    body.global_position=origin
    body.set_physics_process(true)
    await load("res://personagem/revisao73.gd").new().run(scene)

func _blocker(scene: Node3D, point: Vector3) -> StaticBody3D:
    var body=StaticBody3D.new()
    body.collision_layer=2
    var collision=CollisionShape3D.new()
    var box=BoxShape3D.new()
    box.size=Vector3(.08,.2,.08)
    collision.shape=box
    body.add_child(collision)
    scene.add_child(body)
    body.global_position=point
    return body
func _stand(scene: Node3D, id: String, side: int) -> bool:
    var c: Node3D=scene.player.map_doors
    var data: Dictionary=c.doors[id]
    var base: Transform3D=data.hinge.get_parent().global_transform*c._pose(data,0)
    var center: Vector3=base*data.leaf.transform*data.leaf.mesh.get_aabb().get_center()
    var normal=(data.hinge.get_parent().global_basis*(Vector3.RIGHT if data.collider.shape.size.x<data.collider.shape.size.z else Vector3.BACK)).normalized()
    var tangent=normal.cross(Vector3.UP)
    for distance in [.48,.6,.9,1.2]:
        for offset in [0,-.5,.5,-.95,.95]:
            var point=center+normal*side*distance+tangent*offset
            point.y=scene.spawn.y
            var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.35,point-Vector3.UP*1.2,1)
            var floor=scene.get_world_3d().direct_space_state.intersect_ray(ray)
            if floor.is_empty() or floor.normal.y<.9:continue
            point.y=floor.position.y+.02
            scene.player.global_position=point
            await scene.get_tree().physics_frame
            await scene.get_tree().physics_frame
            if scene.world_items.house.standing_clear(point-Vector3.UP*.02) and c._reachable(data) and c.clear_path(id,0 if data.open else 1):return true
    return false
func _settled(scene: Node3D) -> void:
    for frame in 300:
        if not scene.player.map_doors.busy() and scene.player.action.state=="idle":return
        if not scene.player.is_physics_processing():scene.player.action.advance(.0166667)
        await scene.get_tree().physics_frame
    assert(false,"Window did not settle "+str(scene.player.map_doors.last_hit))
func _key(code: int) -> void:
    var key=InputEventKey.new();key.keycode=code;key.physical_keycode=code;key.pressed=true
    Input.parse_input_event(key);Input.flush_buffered_events()
    key=key.duplicate();key.pressed=false
    Input.parse_input_event(key);Input.flush_buffered_events()
func _capture(scene: Node3D, name: String) -> void:
    for frame in 3:await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/windows75/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
