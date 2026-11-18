extends "res://personagem/revisao77.gd"
func run(scene: Node3D) -> void:
    var body=scene.player
    var c=body.traversal
    body.scripted=true
    body.set_physics_process(false)
    scene.get_window().size=Vector2i(1440,900)
    var set: Node3D=scene.get_node("Cercamentos78")
    var chosen=[]
    for model in set.models:
        var found: Node3D
        for obstacle in set.obstacles:
            if obstacle.model.id!=model.id:continue
            await _place(scene,obstacle,-1)
            body.condition_state.set_stamina(100)
            if body.request_cross(obstacle):
                c.advance(12)
                if c.effect_succeeded:found=obstacle;break
        assert(found!=null,"No route for "+model.id)
        chosen.append(found)
    var raw: Array=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/sondas_travessia77.json"))
    for item in raw:
        var weights=[]
        for name in item.w:weights.append([body.avatar.skeleton.find_bone(name),float(item.w[name])])
        probes.append({"point":Vector3(item.p[0],item.p[1],item.p[2]),"weights":weights})
    var cases=[]
    for fps in [30,60,120]:
        for obstacle in chosen:
            for side in [-1,1]:
                await _place(scene,obstacle,side)
                body.condition_state.set_stamina(100)
                var effects=obstacle.effects
                assert(body.request_cross(obstacle),c.message)
                for frame in fps*7:
                    c.advance(1.0/fps)
                    _joints(body.avatar)
                    if fps==60 and frame%4==0 and c.state=="playing":_geometry(body,obstacle)
                    if not c.is_active():break
                assert(not c.is_active() and c.effect_succeeded and obstacle.effects==effects+1,c.message)
                assert(is_equal_approx(body.condition_state.stamina,100-float(obstacle.model.stamina_cost)))
                assert(obstacle.can_cross("player") and obstacle.can_cross("zombie")==not obstacle.model.high)
                cases.append({"model":obstacle.model.id,"fps":fps,"side":side})
    assert(max_penetration<.005,str(penetration_detail)+" depth "+str(max_penetration))
    assert(max_elbow<.025 and max_wrist<.015)
    for obstacle in chosen:
        await _place(scene,obstacle,-1)
        body.condition_state.set_stamina(0)
        assert(not body.request_cross(obstacle))
        body.condition_state.set_stamina(100)
        assert(body.request_cross(obstacle))
        c.advance(.1)
        assert(c.cancel())
        c.advance(2)
        assert(not c.is_active() and body.condition_state.stamina==100)
    if "--capture-fences" in OS.get_cmdline_user_args():
        scene.set_process(false)
        for index in chosen.size():
            var obstacle: Node3D=chosen[index]
            for side in [-1,1]:
                await _place(scene,obstacle,side)
                body.condition_state.set_stamina(100)
                assert(body.request_cross(obstacle),c.message)
                var center: Vector3=c.anchor+Vector3.UP*(1.35 if obstacle.model.high else 1.0)
                scene.camera.size=4.4
                scene.camera.global_position=center+(obstacle.normal*side-obstacle.normal.cross(Vector3.UP)*.65+Vector3.UP*.65)*10
                scene.camera.look_at(center)
                var frames=52 if obstacle.model.high else 32
                for frame in frames:
                    c.advance(.1)
                    await _capture78(scene,"%d_%d/%02d"%[index,side,frame])
                assert(not c.is_active() and c.effect_succeeded)
    var result={"models":6,"segments":set.obstacles.size(),"cases":cases,"max_elbow_gap":max_elbow,"max_wrist_gap":max_wrist,"probe_max_penetration":max_penetration,"probe_detail":penetration_detail,"stamina_cost_once":true,"insufficient_stamina_rejected":true,"cancel_no_cost":true,"zombie_traversal_policy":true}
    FileAccess.open("res://qa/fences78.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R78_FENCES_OK ",result)
    scene.get_tree().quit()
func _capture78(scene: Node3D, name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/fences78/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)

func _geometry(body: CharacterBody3D, obstacle: Node3D) -> void:
    var rig: Skeleton3D=body.avatar.skeleton
    var transforms=[]
    for index in rig.get_bone_count():transforms.append(obstacle.global_transform.affine_inverse()*rig.global_transform*rig.get_bone_global_pose(index)*rig.get_bone_global_rest(index).affine_inverse())
    var sill=.8+obstacle.rise
    for probe in probes:
        var point=Vector3.ZERO
        for weight in probe.weights:point+=transforms[weight[0]]*probe.point*weight[1]
        if absf(point.z)>float(obstacle.model.thickness)/2+(.0175 if obstacle.model.id=="reboco" else 0) or absf(point.x)>.59:continue
        var penetration=maxf(0,sill-point.y)
        if penetration>max_penetration:
            max_penetration=penetration
            penetration_detail={"time":body.traversal.cursor,"point":str(point),"variant":obstacle.variant,"weights":str(probe.weights.map(func(w):return [rig.get_bone_name(w[0]),w[1]])),"source":str(probe.point)}
