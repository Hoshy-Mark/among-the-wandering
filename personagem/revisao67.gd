extends RefCounted

func run(scene: Node3D, capture: bool=false) -> void:
    await load("res://personagem/revisao66.gd").new().run(scene,false,false)
    var world: Node3D=scene.world_items
    var house: Node3D=world.house
    var body: CharacterBody3D=scene.player
    var model: RefCounted=body.bag_inventory
    var ui: Control=scene.game_ui
    assert(house.bindings.size()==3 and house.groups.size()==2)
    var original=model.snapshot()
    for id in house.bindings:
        house.visit(id)
        await scene.get_tree().physics_frame
        body.update_nearby()
        print("HOUSE_POSITION ",id," ",house.home.model.to_local(body.global_position)," inside=",house.shell.contains_point("H01",body.global_position))
        assert(house.shell.contains_point("H01",body.global_position))
        assert(house.standing_clear(body.global_position-Vector3.UP*.02))
        var local: Vector3=house.home.model.to_local(body.global_position)
        var room_id="H01_ROOM_04" if str(id).contains("GELADEIRA") else "H01_ROOM_03"
        var in_room=false
        for room in house.home.rule.rooms:
            if room.id==room_id:
                var polygon=PackedVector2Array()
                for point in room.polygon_xz:
                    polygon.append(Vector2(point[0],point[1]))
                in_room=Geometry2D.is_point_in_polygon(Vector2(local.x,local.z),polygon)
        assert(in_room)
        var floor_query=PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP*.2,body.global_position-Vector3.UP*.2,1,[body.get_rid()])
        var floor_hit=body.get_world_3d().direct_space_state.intersect_ray(floor_query)
        assert(not floor_hit.is_empty() and floor_hit.normal.y>.9)
        var clear: bool=house.clear_to_open(id)
        print("HOUSE_CLEARANCE ",id," ",clear," ",house.last_clearance)
        assert(clear)
        assert(world.request_open(id))
        var center: Vector3=house.home.model.to_global(house.groups[house.bindings[id]].bounds.get_center())
        var facing=body.avatar.global_basis.z
        var toward=center-body.global_position
        assert(Vector2(facing.x,facing.z).normalized().dot(Vector2(toward.x,toward.z).normalized())>.999)
        _tick(body,world,.7)
        assert(model.accessible(id) and ui.container_id==id)
        world.close_interaction()
        _tick(body,world,.3)
    var cooler="world:arroio:H01_FURN_GELADEIRA/storage/cooler"
    var freezer="world:arroio:H01_FURN_GELADEIRA/storage/freezer"
    var wardrobe="world:arroio:H01_FURN_GUARDA_CASAL/storage/main"
    assert(model.capacity(cooler)==12 and model.capacity(freezer)==6 and model.capacity(wardrobe)==20)
    house.visit(cooler)
    await scene.get_tree().physics_frame
    assert(world.request_open(cooler))
    _tick(body,world,.7)
    assert(model.accessible(freezer) and not model.accessible(wardrobe))
    var freezer_before=model.contents(freezer).duplicate()
    var bag: String=model.equipped("backpack")
    for uid in model.contents(cooler):
        assert(body.move_item(uid,bag))
    assert(model.contents(cooler).is_empty() and model.contents(freezer)==freezer_before)
    assert(world.active_id==cooler)
    for part in house.groups[house.bindings[cooler]].parts:
        assert(is_equal_approx(part.fraction,1))
    body.condition_path="user://qa_profile67.json"
    assert(body.save_condition())
    var saved=model.snapshot()
    var reload=load("res://personagem/inventario67.gd").new()
    assert(reload.restore(saved))
    for id in model.house_anchors:
        reload.register_anchor(id,model.house_anchors[id],[["food",1]])
    assert(reload.contents(cooler).is_empty())
    assert(reload.items==saved.items and not reload.is_open(cooler))
    assert(body.load_condition())
    assert(model.contents(cooler).is_empty() and not model.is_open(cooler))
    # Fixed furniture anchors are supplied by the map during profile restoration.
    var altered=model.snapshot()
    altered.world_containers[cooler].position=[0,0,0]
    assert(model.restore(altered))
    assert(model.point(cooler).distance_to(house.groups[house.bindings[cooler]].point)<.0001)
    var invalid=model.snapshot()
    var uid: String=model.items.keys()[0]
    invalid.items[uid].count=999
    var before=model.snapshot()
    assert(not model.restore(invalid) and model.snapshot()==before)
    # Loading an older inventory adds empty mapped anchors instead of respawning loot.
    var legacy=original.duplicate(true)
    for id in house.bindings:
        legacy.world_containers.erase(id)
    for id in legacy.items.keys():
        if house.bindings.has(legacy.items[id].location):
            legacy.items.erase(id)
    assert(model.restore(legacy))
    assert(model.world_containers.has(cooler) and model.contents(cooler).is_empty())
    assert(model.restore(original))
    house.visit(cooler)
    await scene.get_tree().physics_frame
    # A new solid obstruction prevents the source door leaves crossing it.
    var part: Dictionary=house.groups[house.bindings[cooler]].parts[0]
    var sweep_pose: Transform3D=part.pivot.get_parent().global_transform*part.closed_transform*Transform3D(Basis(part.axis,deg_to_rad(50)*part.sign),Vector3.ZERO)*part.proxy.transform
    var blocker=StaticBody3D.new()
    var blocker_shape=CollisionShape3D.new()
    var blocker_box=BoxShape3D.new()
    blocker_box.size=Vector3(.12,.4,.12)
    blocker_shape.shape=blocker_box
    blocker.add_child(blocker_shape)
    scene.add_child(blocker)
    blocker.global_position=sweep_pose.origin
    await scene.get_tree().physics_frame
    assert(not house.clear_to_open(cooler) and not world.request_open(cooler))
    assert(world.blocked_time>0)
    blocker.queue_free()
    await scene.get_tree().physics_frame
    assert(house.clear_to_open(cooler))
    # The actor is also checked against the door sweep.
    var stand: Vector3=body.global_position
    body.global_position=sweep_pose.origin-Vector3(0,.65,0)
    await scene.get_tree().physics_frame
    assert(not house.clear_to_open(cooler))
    body.global_position=stand
    await scene.get_tree().physics_frame
    if capture:
        world.blocked_time=0
        await _show(scene,cooler,"fridge")
        ui.show_container(freezer)
        await _capture(scene,"freezer_inventory")
        await _show(scene,wardrobe,"wardrobe")
        world.close_interaction()
        _tick(body,world,.4)
        ui.visible=false
        scene.zoom=11
        scene.focus=house.home.model.to_global(Vector3(0,1,0))
        scene._update_camera()
        # Freeze follow only for the house overview.
        scene.set_process(false)
        house.shell.review_cut=true
        await _capture(scene,"house_context")
    FileAccess.open("res://qa/house67_capture.json" if capture else "res://qa/house67.json",FileAccess.WRITE).store_string(JSON.stringify({"regression66":true,"anchors":3,"furniture":2,"clearance":true,"compartments_independent":true,"transfers":true,"doors_preserved_on_transfer":true,"save_load":true,"no_loot_respawn":true,"authoritative_anchors":true,"invalid_restore_atomic":true,"old_profile_registration":true,"sweep_obstruction":true,"actor_sweep":true}))
    print("R67_HOUSE_OK")
    scene.get_tree().quit()

func _tick(body: CharacterBody3D, world: Node3D, seconds: float) -> void:
    for index in ceili(seconds/.01):
        var step=minf(.01,seconds-index*.01)
        body.action.advance(step)
        world.advance(step)

func _show(scene: Node3D, id: String, name: String) -> void:
    var world: Node3D=scene.world_items
    var body: CharacterBody3D=scene.player
    var ui: Control=scene.game_ui
    world.house.visit(id)
    var front: Vector3=world.house.groups[world.house.bindings[id]].front
    var offset=front.cross(Vector3.UP)*.4
    if str(id).contains("GUARDA"):
        offset=-offset
    if world.house.standing_clear(body.global_position+offset-Vector3.UP*.02):
        body.global_position+=offset
    await scene.get_tree().physics_frame
    body.update_nearby()
    world.advance(.4)
    assert(world.request_open(id))
    _tick(body,world,.7)
    ui.visible=true
    if name=="wardrobe":
        scene.set_process(false)
        _wardrobe_camera(scene,id,true)
    await _capture(scene,name+"_inventory")
    ui.visible=false
    if name=="wardrobe":
        _wardrobe_camera(scene,id,false)
    await _capture(scene,name+"_open")
    world.close_interaction()
    _tick(body,world,.4)
    DirAccess.make_dir_recursive_absolute("res://previews/house67/"+name+"_frames")
    for index in 34:
        if index==4:
            assert(world.request_open(id))
        if index==23:
            world.close_interaction()
        _tick(body,world,.05)
        await _capture(scene,name+"_frames/%03d"%index)
    # Leave the chosen container available to the following static view.
    assert(world.request_open(id))
    _tick(body,world,.7)
    ui.visible=true
    scene.set_process(true)

func _wardrobe_camera(scene: Node3D, id: String, panel: bool) -> void:
    var house: Node3D=scene.world_items.house
    var bounds: AABB=house.groups[house.bindings[id]].bounds
    var center: Vector3=house.home.model.to_global(bounds.get_center())
    var focus=(center+scene.player.global_position+Vector3.UP)/2
    var axis=Vector3(-1,.81649658,1)
    scene.camera.size=5
    scene.camera.global_position=focus+axis*12
    scene.camera.look_at(focus)
    if panel:
        focus-=scene.camera.global_basis.x*1.6
        scene.camera.global_position=focus+axis*12
        scene.camera.look_at(focus)

func _capture(scene: Node3D, name: String) -> void:
    for frame in 5:
        await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://previews/house67")
    scene.get_viewport().get_texture().get_image().save_png("res://previews/house67/"+name+".png")
