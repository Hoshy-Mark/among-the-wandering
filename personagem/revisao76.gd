extends "res://personagem/revisao75.gd"
func run(scene: Node3D) -> void:
    var body: CharacterBody3D=scene.player
    var c: Node3D=body.map_doors
    var capture="--capture-variants" in OS.get_cmdline_user_args()
    scene.get_window().size=Vector2i(1440,900)
    body.scripted=true
    body.set_physics_process(false)
    var origin=body.global_position
    var initial=c.snapshot()
    var windows: Array=c.doors.keys().filter(func(id):return str(id).contains("/window/"))
    var dimensions={}
    assert(windows.size()==7 and c.doors.size()==11)
    for id in windows:
        var data: Dictionary=c.doors[id]
        assert(await _stand(scene,id,-1),"No approach "+id)
        assert(c.request(id))
        body.action.advance(.05)
        body.action.cancel()
        assert(not c.busy() and not data.open)
        assert(c.request(id))
        body.action.advance(10)
        await _settled(scene)
        assert(data.open and is_equal_approx(data.fraction,1))
        if data.has("parts"):
            for part in data.parts:assert(part.hinge.transform.is_equal_approx(c._part_pose(part,1)))
            dimensions[id]=[data.free_opening.x,data.free_opening.y]
        assert(await _stand(scene,id,1),"No approach "+id)
        assert(c.request(id))
        body.action.advance(10)
        await _settled(scene)
        assert(not data.open)
        # Every leaf, including the second casement, participates in collision checks.
        if data.has("parts"):
            for part in data.parts:
                var pose: Transform3D=part.hinge.get_parent().global_transform*c._part_pose(part,.5)*part.collider.transform
                var obstacle=_blocker(scene,pose.origin)
                await scene.get_tree().physics_frame
                assert(not c.clear_path(id,1),"Ignored leaf obstacle "+id)
                obstacle.queue_free()
                await scene.get_tree().physics_frame
            assert(c.clear_path(id,1))
    # Preserve all eleven logical IDs; restoration updates every moving leaf.
    var opened=initial.duplicate(true)
    for id in windows:opened.states[id]=true
    c.apply_restore(opened)
    for id in windows:
        var data: Dictionary=c.doors[id]
        if data.has("parts"):
            for part in data.parts:assert(part.hinge.transform.is_equal_approx(c._part_pose(part,1)))
    body.global_position=origin
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    body.condition_path="user://qa_variants_r76.json"
    assert(body.save_condition())
    c.apply_restore(initial)
    assert(body.load_condition())
    for id in windows:assert(c.doors[id].open)
    c.apply_restore(initial)
    if capture:
        scene.set_process(false)
        scene.game_ui.personal.visible=false
        scene.game_ui.nearby_wanted=false
        scene.game_ui.refresh()
        for index in [0,1,2,3]:
            var id: String=windows[index]
            assert(await _stand(scene,id,1))
            var data: Dictionary=c.doors[id]
            var center: Vector3=data.get("aperture_point",data.leaf.global_position)
            var direction=body.global_position-center
            direction.y=0
            direction=direction.normalized()
            direction=(data.hinge.get_parent().global_basis*(Vector3.BACK if index>=2 else Vector3.FORWARD)).normalized()
            scene.camera.size=3.5
            scene.camera.global_position=center+(direction+Vector3.UP*.5-direction.cross(Vector3.UP)*.35)*10
            scene.camera.look_at(center)
            await _capture(scene,str(index)+"_closed")
            assert(c.request(id))
            body.action.advance(10)
            await _settled(scene)
            await _capture(scene,str(index)+"_open")
            assert(c.request(id))
            body.action.advance(10)
            await _settled(scene)
            for frame in 24:
                if frame==3:assert(c.request(id))
                body.action.advance(.035)
                c._physics_process(.035)
                await _capture(scene,"frames%d/%02d"%[index,frame])
            body.action.advance(10)
            await _settled(scene)
            assert(c.request(id))
            body.action.advance(10)
            await _settled(scene)
        scene.set_process(true)
    var result={"windows":7,"mechanisms":4,"both_sides":true,"cancel_before_effect":true,"all_leaves_collision":true,"all_leaves_restore":true,"profile_roundtrip":true,"free_opening_metres":dimensions,"traversal_not_enabled":true}
    FileAccess.open("res://qa/variants76.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R76_VARIANTS_OK ",result)
    c.apply_restore(initial)
    body.global_position=origin
    body.set_physics_process(true)
    if capture:
        scene.get_tree().quit()
        return
    await load("res://personagem/revisao73.gd").new().run(scene)

func _capture(scene: Node3D, name: String) -> void:
    for frame in 3:await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/variants76/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)

func _stand(scene: Node3D, id: String, side: int) -> bool:
    var c: Node3D=scene.player.map_doors
    var data: Dictionary=c.doors[id]
    var base: Transform3D=data.hinge.get_parent().global_transform*c._pose(data,0)
    var center: Vector3=data.get("aperture_point",base*data.leaf.transform*data.leaf.mesh.get_aabb().get_center())
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
