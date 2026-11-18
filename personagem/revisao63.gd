extends RefCounted

func run(scene: Node3D, capture: bool=false, map_view: bool=false) -> void:
    var body: CharacterBody3D=scene.player
    body.scripted=true
    body.set_physics_process(false)
    for fixture in scene.fixtures.values():
        fixture.position.x+=30
    if map_view:
        scene.training_target.position.x+=30
        body.global_position=scene.spawn+Vector3(0,.03,-3)
    await scene.get_tree().physics_frame
    var query=PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP,body.global_position-Vector3.UP,1)
    var floor_hit=body.get_world_3d().direct_space_state.intersect_ray(query)
    if not floor_hit.is_empty():
        body.global_position.y=floor_hit.position.y+.01
    var model: RefCounted=body.bag_inventory
    var original=model.snapshot()
    var profile=body.condition_state.snapshot()
    assert(model.catalog.bag_school.capacity==8 and model.catalog.bag_canvas.capacity==16 and model.catalog.bag_hiking.capacity==24)
    assert(body.body_health.regions.size()==17)
    assert(body.body_health.TYPES.size()==5)
    var pants: String=model.equipped("pants")
    var with_pants=model.snapshot()
    assert(not model.move(pants,"ground"))
    assert(model.snapshot()==with_pants)
    var bag: String=model.equipped("backpack")
    for index in 16-model.contents(bag).size():
        assert(not model.add("water",1,bag).is_empty())
    var before=model.snapshot()
    assert(model.add("water",1,bag).is_empty())
    assert(model.snapshot()==before)
    assert(model.move(bag,bag)==false)
    var large=""
    for uid in model.items:
        if model.items[uid].definition=="bag_hiking":
            large=uid
    assert(body.equip_item(large))
    assert(model.contents(bag).size()==16 and model.equipped("backpack")==large)
    assert(model.items[bag].location=="ground")
    assert(model.restore(original))
    var uid=""
    for id in model.items:
        if model.items[id].definition=="bandage":
            uid=id
    scene.game_ui.container_id="pockets"
    scene.game_ui.refresh()
    for button in scene.game_ui.grid.get_children():
        if button.uid==uid:
            button.pressed.emit()
            break
    assert(scene.game_ui.selected_uid==uid)
    var target=load("res://personagem/slot63.gd").new()
    target.hud=scene.game_ui
    target.destination=bag
    assert(target._can_drop_data(Vector2.ZERO,{"item_uid":uid}))
    target._drop_data(Vector2.ZERO,{"item_uid":uid})
    assert(model.items[uid].location==bag)
    scene.game_ui.move_uid(uid,"pockets")
    assert(model.items[uid].location=="pockets")
    target.free()
    var baton=""
    for id in model.items:
        if model.items[id].definition=="baton":
            baton=id
    scene.game_ui.equip_uid(baton,"main_hand")
    assert(model.equipped("main_hand")==baton and body.combat.weapon.visible)
    scene.game_ui.move_uid(baton,"ground")
    assert(model.equipped("main_hand").is_empty())
    var event=InputEventMouseButton.new()
    event.button_index=MOUSE_BUTTON_LEFT
    event.pressed=true
    event.position=scene.game_ui.body_map._rect("hand_right").get_center()
    scene.game_ui.body_map._gui_input(event)
    assert(scene.game_ui.zone_id=="hand_right")
    scene.game_ui.select_zone("forearm_left")
    _key(KEY_I)
    assert(not scene.game_ui.windows[0].visible)
    _key(KEY_H)
    assert(scene.game_ui.windows[1].visible and body.hud_open)
    _key(KEY_H)
    _key(KEY_I)
    assert(scene.game_ui.windows[0].visible and not scene.game_ui.windows[1].visible)
    if not capture:
        var original_size=scene.get_window().size
        scene.get_window().size=Vector2i(960,720)
        await scene.get_tree().process_frame
        scene.game_ui._layout()
        _key(KEY_H)
        assert(scene.game_ui.windows[1].visible and not scene.game_ui.windows[0].visible)
        assert(is_equal_approx(scene.game_ui.windows[1].position.x,16))
        scene.get_window().size=original_size
        await scene.get_tree().process_frame
        _key(KEY_H)
        _key(KEY_I)
    assert(body.receive_zone_damage("hud_test","forearm_left","cut",.4))
    assert(not body.receive_zone_damage("hud_test","forearm_left","cut",.4))
    body.reaction.advance(2)
    assert(body.use_item(uid))
    body.action.advance(.1)
    body.action.cancel()
    assert(model.items[uid].count==3)
    var observed={"count":0,"dressed":false}
    var observer=func():
        observed.count+=1
        observed.dressed=body.condition_state.forearm_dressed
    model.changed.connect(observer)
    assert(body.use_item(uid))
    body.action.advance(10)
    model.changed.disconnect(observer)
    assert(observed.count==1 and observed.dressed)
    assert(model.items[uid].count==2 and body.condition_state.forearm_dressed)
    var saved_path: String=body.condition_path
    body.condition_path="user://qa_profile63.json"
    assert(body.save_condition())
    assert(body.save_condition())
    assert(model.move(uid,"ground"))
    var saved_health=body.condition_state.snapshot()
    body.condition_state.set_injury("R",.9)
    assert(body.load_condition())
    assert(model.items[uid].count==2 and model.owned(uid))
    assert(is_equal_approx(body.condition_state.right_injury,saved_health.right_injury))
    assert(is_equal_approx(body.condition_state.forearm_injury,saved_health.forearm_injury))
    assert(body.condition_state.forearm_dressed==saved_health.forearm_dressed)
    var file=FileAccess.open(body.condition_path,FileAccess.READ)
    var data: Dictionary=JSON.parse_string(file.get_as_text())
    file.close()
    data.inventory.items[uid].location="missing_container"
    var inventory_before=model.snapshot()
    var health_before=body.condition_state.snapshot()
    file=FileAccess.open(body.condition_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()
    assert(not body.load_condition())
    assert(model.snapshot()==inventory_before and body.condition_state.snapshot()==health_before)
    body.condition_path=saved_path
    body.action.cancel()
    body.reaction.reset()
    model.restore(original)
    body.condition_state.restore(profile)
    body.body_health.records.clear()
    assert(body.body_health.hit("scratch","hand_right","scratch",.3))
    assert(body.body_health.hit("cut","forearm_left","cut",.4))
    assert(body.body_health.hit("bruise","shin_left","bruise",.25))
    assert(body.body_health.severity("hand_right")<body.body_health.severity("forearm_left"))
    scene.game_ui.refresh()
    if capture:
        body.set_physics_process(true)
        if map_view:
            scene.zoom=4.5
        for view in ["inventory","body","both","backpack"]:
            scene.game_ui.windows[0].visible=view in ["inventory","both"]
            scene.game_ui.windows[1].visible=view in ["body","both"]
            body.set_hud_open(view!="backpack")
            if view=="backpack":
                scene.game_ui.visible=false
                body.avatar.rotation.y=0
            if view=="inventory":
                scene.game_ui.container_id=bag
                scene.game_ui.refresh()
            for frame in 4:
                await scene.get_tree().process_frame
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("res://previews/hud63")
            scene.get_viewport().get_texture().get_image().save_png("res://previews/hud63/"+view+".png")
    FileAccess.open("res://qa/hud63_captura.json" if capture else "res://qa/hud63.json",FileAccess.WRITE).store_string(JSON.stringify({"capacity":true,"bag_swap_preserves_contents":true,"cycle_rejected":true,"consumption":true,"cancel":true,"save_load":true,"invalid_load_atomic":true,"compact_layout_tested":not capture,"regions":17,"damage_types":5},"  "))
    print("R63_HUD_OK")
    scene.get_tree().quit()

func _key(code: int) -> void:
    var event=InputEventKey.new()
    event.keycode=code
    event.physical_keycode=code
    event.pressed=true
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    event=event.duplicate()
    event.pressed=false
    Input.parse_input_event(event)
    Input.flush_buffered_events()
