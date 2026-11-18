extends RefCounted

func run(scene: Node3D, capture: bool=false, finish: bool=true) -> void:
    var body: CharacterBody3D=scene.player
    var model: RefCounted=body.bag_inventory
    var world: Node3D=scene.world_items
    var ui: Control=scene.game_ui
    world.set_physics_process(false)
    # Earlier inventory contracts are exercised with explicitly opened fixtures.
    var open_fixtures=func(): model.opened.assign(model.world_containers.keys())
    model.changed.connect(open_fixtures)
    open_fixtures.call()
    await load("res://personagem/revisao65.gd").new().run(scene,false,false)
    model.changed.disconnect(open_fixtures)
    model.opened.clear()
    model.changed.emit()
    world.close_interaction()
    world.advance(1)
    body.action.cancel()
    body.reaction.reset()
    var origin: Vector3=body.global_position
    var original=model.snapshot()
    var cabinet="world:cabinet"
    var crate="world:crate"
    var food=_find(model,"food",cabinet)
    var bag: String=model.equipped("backpack")
    assert(not model.accessible(crate) and not model.accessible(cabinet))
    assert(not body.move_item(food,bag))
    body.global_position=model.point(cabinet)+Vector3(-.85,0,-.85)
    body.update_nearby()
    world.advance(0)
    assert(world.nearest_id==cabinet and world.prompt.visible)
    assert(not model.accessible(cabinet))
    _key(KEY_E)
    assert(world.pending_id==cabinet and body.action.action_id=="access" and body.hud_open)
    assert(not ui.windows[0].visible)
    _tick(body,world,.1)
    assert(world.progress[cabinet]>0 and world.progress[cabinet]<1 and not model.accessible(cabinet))
    assert(not body.move_item(food,bag))
    assert(not world.request_open(crate))
    _tick(body,world,.23)
    assert(world.active_id==cabinet and ui.windows[0].visible and ui.container_id==cabinet)
    assert(model.accessible(cabinet) and not model.accessible(crate))
    var doors=world.visuals[cabinet]
    assert(absf(doors.get_node("DoorLeft").rotation.y)>1.7)
    assert(absf(doors.get_node("DoorRight").rotation.y)>1.7)
    assert(body.move_item(food,bag))
    assert(world.progress[cabinet]==1 and absf(doors.get_node("DoorLeft").rotation.y)>1.7)
    var position: Vector3=body.global_position
    body.command=Vector2(1,0)
    body._physics_process(.016)
    assert(Vector2(body.global_position.x-position.x,body.global_position.z-position.z).length()<.001)
    body.command=Vector2.ZERO
    _tick(body,world,.34)
    assert(body.action.state=="idle")
    _key(KEY_ESCAPE)
    assert(not world.has_interaction() and not model.accessible(cabinet) and not ui.windows[0].visible)
    world.advance(.25)
    assert(is_zero_approx(doors.get_node("DoorLeft").rotation.y))
    # Closing during the opening cancels both gesture and access.
    assert(world.request_open(cabinet))
    _tick(body,world,.1)
    _key(KEY_E)
    _tick(body,world,.5)
    assert(not model.accessible(cabinet) and body.action.state=="idle" and not world.has_interaction())
    # Pointer input uses the cabinet collision surface as its target.
    world.advance(.3)
    for frame in 3:
        await scene.get_tree().process_frame
    await scene.get_tree().physics_frame
    var event=InputEventMouseButton.new()
    event.button_index=MOUSE_BUTTON_LEFT
    event.pressed=true
    event.position=scene.camera.unproject_position(model.point(cabinet)+Vector3(0,.6,0))
    world._unhandled_input(event)
    assert(world.pending_id==cabinet)
    _tick(body,world,.34)
    ui.toggle(0)
    assert(not world.has_interaction() and not model.accessible(cabinet))
    world.advance(.3)
    # Lost distance or a new wall invalidates a pending interaction.
    assert(world.request_open(cabinet))
    body.global_position+=Vector3(-6,0,0)
    body.update_nearby()
    _tick(body,world,.4)
    assert(not world.has_interaction() and not model.accessible(cabinet))
    body.global_position=model.point(cabinet)+Vector3(-1,0,0)
    body.update_nearby()
    var wall=StaticBody3D.new()
    var collider=CollisionShape3D.new()
    var box=BoxShape3D.new()
    box.size=Vector3(.1,2,2)
    collider.shape=box
    wall.add_child(collider)
    scene.add_child(wall)
    wall.global_position=model.point(cabinet)+Vector3(-.5,.6,0)
    await scene.get_tree().physics_frame
    body.update_nearby()
    assert(not world.request_open(cabinet))
    wall.queue_free()
    await scene.get_tree().physics_frame
    body.update_nearby()
    # A reaction interrupts the short gesture and closes access.
    assert(world.request_open(cabinet))
    assert(body.request_reaction("hit_front"))
    world.advance(.4)
    assert(not world.has_interaction() and not model.is_open(cabinet))
    body.reaction.reset()
    body.action.cancel()
    # Loaded profiles restore items and begin with the cabinet closed.
    assert(world.request_open(cabinet))
    _tick(body,world,.7)
    body.condition_path="user://qa_profile66.json"
    assert(body.save_condition())
    assert(body.load_condition())
    assert(not model.is_open(cabinet) and not world.has_interaction())
    # Crates use the same interaction, with a hinged lid.
    body.global_position=origin
    body.update_nearby()
    world.advance(.3)
    assert(world.request_open(crate))
    _tick(body,world,.7)
    assert(model.accessible(crate) and world.visuals[crate].get_node("Lid").rotation.x>1.8)
    _key(KEY_I)
    assert(not model.is_open(crate) and not world.has_interaction())
    world.advance(.3)
    model.restore(original)
    body.global_position=model.point(cabinet)+Vector3(-.85,0,-.85)
    body.update_nearby()
    world.advance(1)
    if capture:
        body.global_position=model.point(cabinet)+Vector3(1.25,0,-.1)
        body.update_nearby()
        world.advance(0)
        await _capture(scene,"closed")
        assert(world.request_open(cabinet))
        _tick(body,world,.15)
        await _capture(scene,"opening")
        _tick(body,world,.19)
        await _capture(scene,"inventory")
        _tick(body,world,.35)
        ui.visible=false
        await _capture(scene,"open")
        world.close_interaction()
        _tick(body,world,.35)
        await _capture_motion(scene)
        ui.visible=true
    FileAccess.open("res://qa/container66_capture.json" if capture else "res://qa/container66.json",FileAccess.WRITE).store_string(JSON.stringify({"inventory65_regression":true,"key_interaction":true,"pointer_interaction":true,"opening_blocks_access":true,"hinged_doors":true,"content_transfer_preserves_door":true,"movement_locked":true,"short_gesture":true,"escape_close":true,"cancel_opening":true,"panel_close":true,"distance_cancel":true,"wall_block":true,"reaction_cancel":true,"save_load_closed":true,"crate_lid":true},"  "))
    print("R66_CONTAINER_OK")
    if finish:
        scene.get_tree().quit()

func _tick(body: CharacterBody3D, world: Node3D, seconds: float) -> void:
    for index in ceili(seconds/.01):
        body.action.advance(minf(.01,seconds-index*.01))
        world.advance(minf(.01,seconds-index*.01))

func _key(code: int) -> void:
    var event=InputEventKey.new()
    event.physical_keycode=code
    event.keycode=code
    event.pressed=true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    event=event.duplicate()
    event.pressed=false
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func _find(model: RefCounted, definition: String, location: String) -> String:
    for uid in model.items:
        if model.items[uid].definition==definition and model.items[uid].location==location:
            return uid
    return ""

func _capture(scene: Node3D, name: String) -> void:
    for frame in 6:
        await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://previews/container66")
    scene.get_viewport().get_texture().get_image().save_png("res://previews/container66/"+name+".png")

func _capture_motion(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute("res://previews/container66/frames")
    for index in 34:
        if index==4:
            assert(scene.world_items.request_open("world:cabinet"))
        if index==23:
            scene.world_items.close_interaction()
        _tick(scene.player,scene.world_items,.05)
        await _capture(scene,"frames/%03d"%index)
