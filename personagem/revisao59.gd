extends RefCounted

func capture(scene: Node3D, body: CharacterBody3D, camera: Camera3D, hud: CanvasLayer, map_view: bool=false) -> void:
    body.scripted=true
    body.set_physics_process(false)
    hud.visible=false
    var results: Dictionary={}
    var start=body.global_position
    var query=PhysicsRayQueryParameters3D.create(start+Vector3.UP,start-Vector3.UP,1)
    var hit=body.get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        start.y=hit.position.y+.03
    var facing=body.avatar.rotation.y
    for id in body.flow.PLANS:
        if map_view and "--resume-flow" in OS.get_cmdline_user_args() and id!="sprint":
            var folder="res://previews/fluxo/"+id
            var files=DirAccess.get_files_at(folder)
            if files.size()>0:
                results[id]={"frames":files.size(),"fps":24,"resumed_native_capture":true}
                continue
        var frames=0
        var trace: Array=[]
        body.global_position=start
        body.avatar.rotation.y=facing
        body.avatar.set_appearance({"shirt_id":"camisa_xadrez_vinho"})
        assert(body.flow.begin(id))
        while not body.flow.queue.is_empty() and frames<600:
            body.flow.advance(1.0/24)
            camera.size=3.3
            camera.position=body.global_position+Vector3(-4,2,4)
            camera.look_at(body.global_position+Vector3.UP*.95)
            if map_view:
                scene.focus=body.global_position+Vector3.UP*.95
                scene.zoom=5.5
                scene._update_camera()
            await RenderingServer.frame_post_draw
            var folder="res://previews/fluxo/"+id
            DirAccess.make_dir_recursive_absolute(folder)
            get_viewport_image(scene).save_png(folder+"/%03d.png"%frames)
            trace.append({"frame":frames,"motion":body.avatar.motion,"position":str(body.position)})
            frames+=1
        assert(not body.flow.blocked,id)
        results[id]={"frames":frames,"fps":24,"trace":trace}
        FileAccess.open("res://qa/fluxo_capturas.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    FileAccess.open("res://qa/fluxo_capturas.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
    print("R59_CAPTURE_OK")
    scene.get_tree().quit()

func get_viewport_image(scene: Node) -> Image:
    return scene.get_viewport().get_texture().get_image()
