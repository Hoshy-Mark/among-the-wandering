extends RefCounted

func run(scene: Node3D, capture: bool=false) -> void:
    var body: CharacterBody3D=scene.player
    var ui: Control=scene.game_ui
    var world: Node3D=scene.world_items
    var model: RefCounted=body.bag_inventory
    scene.get_window().size=Vector2i(1280,720)
    await _frames(scene,3)
    body.scripted=true
    body.set_physics_process(false)
    world.set_physics_process(false)
    for fixture in scene.fixtures.values():
        fixture.position.x+=30
    if "training_target" in scene:
        scene.training_target.position.x+=30
    var origin=body.global_position
    var original=model.snapshot()
    assert(original.items.size()==(29 if world.house!=null else 19))
    var health=body.condition_state.snapshot()
    var bag: String=model.equipped("backpack")
    var water=_find(model,"water",bag)
    var food=_find(model,"food","pockets")
    var bandage=_find(model,"bandage","pockets")
    await _frames(scene,3)
    assert(ui.personal.visible and not ui.nearby.visible and ui.actions.get_child_count()==0)
    assert(_grid(ui,"pockets")!=null and _grid(ui,bag)!=null)
    for grid in ui.grids:
        var tiles=0
        for tile in grid.get_children():
            if "uid" in tile:
                tiles+=1
        assert(tiles==model.contents(grid.container_id).size())
    ui.select_item(food)
    assert(_action(ui,"Usar")!=null and _action(ui,"Equipar")==null)
    ui.begin_pending("drop")
    var before=model.snapshot()
    assert(not body.save_condition() and model.snapshot()==before)
    _key(KEY_ESCAPE)
    await _frames(scene,2)
    assert(model.snapshot()==before and ui.pending_mode.is_empty() and not ui.nearby.visible)
    ui.select_item(food)
    ui.begin_pending("drop")
    assert(model.snapshot()==before)
    ui.commit_target(_grid(ui,"drop_here"),Vector2i(0,0))
    var ground: String=model.items[food].location
    assert(model.world_containers[ground].kind=="ground" and ui.nearby.visible and ui.personal.visible)
    ui.close_nearby()
    assert(ui.personal.visible and not ui.nearby.visible and ui.reopen.visible)
    ui.reopen.pressed.emit()
    assert(ui.nearby.visible)
    ui.select_item(food)
    ui.start_drag(food,Vector2i.ZERO)
    before=model.snapshot()
    body.global_position=origin+Vector3(-7,0,0)
    body.update_nearby()
    assert(ui.drag_uid.is_empty() and model.snapshot()==before)
    body.global_position=origin
    body.update_nearby()
    ui.reopen.pressed.emit()
    _key(KEY_I)
    assert(not ui.personal.visible and ui.nearby.visible)
    _key(KEY_I)
    assert(ui.personal.visible and ui.nearby.visible)
    body.global_position=origin+Vector3(-7,0,0)
    body.update_nearby()
    assert(not ui.nearby.visible and not ui.reopen.visible)
    body.global_position=origin
    body.update_nearby()
    assert(not ui.nearby.visible and ui.reopen.visible)
    ui.reopen.pressed.emit()
    assert(ui.nearby.visible)
    # Click-to-place and rotation modify exactly the selected piece.
    ui.select_item(water)
    ui.commit_target(_grid(ui,bag),Vector2i(3,1))
    assert(model.items[water].x==3 and model.items[water].y==1)
    ui.select_item(water)
    before=model.snapshot()
    _key(KEY_R)
    assert(model.snapshot()==before)
    ui.commit_target(_grid(ui,bag),Vector2i(0,0))
    ui.select_item(water)
    _key(KEY_R)
    assert(model.items[water].rot)
    _key(KEY_R)
    assert(not model.items[water].rot)
    await _frames(scene,3)
    # Actual GUI mouse events retain the grip cell and publish only on release.
    var source_grid=_grid(ui,bag)
    var pocket_grid=_grid(ui,"pockets")
    var start: Vector2=source_grid.get_global_transform()*Vector2(20,20)
    var target: Vector2=pocket_grid.get_global_transform()*Vector2(78,20)
    before=model.snapshot()
    _motion(start)
    _mouse(start,true)
    _motion(start+Vector2(10,0))
    assert(ui.drag_uid==water)
    _motion(target)
    assert(model.snapshot()==before and ui.hover_grid==pocket_grid and pocket_grid.preview_valid)
    _mouse(target,false)
    assert(model.items[water].location=="pockets" and model.items[water].x==1 and model.items[water].y==0)
    await _frames(scene,2)
    # A refused drop and Escape preserve the previous position and identity.
    pocket_grid=_grid(ui,"pockets")
    start=pocket_grid.get_global_transform()*Vector2(78,20)
    target=pocket_grid.get_global_transform()*Vector2(136,78)
    before=model.snapshot()
    _mouse(start,true)
    _motion(start+Vector2(10,0))
    _motion(target)
    assert(not pocket_grid.preview_valid)
    _mouse(target,false)
    assert(model.snapshot()==before)
    _mouse(start,true)
    _motion(start+Vector2(10,0))
    _key(KEY_R)
    assert(model.snapshot()==before)
    _key(KEY_ESCAPE)
    _mouse(start,false)
    assert(model.snapshot()==before and ui.drag_uid.is_empty())
    ui.select_item(food)
    ui.begin_pending("split")
    before=model.snapshot()
    assert(model.items[food].count==2)
    ui.commit_target(_grid(ui,bag),Vector2i(3,0))
    assert(model.snapshot()==before and ui.pending_mode=="split")
    ui.commit_target(_grid(ui,bag),Vector2i(2,0))
    assert(model.items[food].count==1)
    # R68 retains clothing and body integration while equipment waits for placement.
    var top=_find(model,"moletom_cinza",bag)
    ui.select_item(top)
    assert(_action(ui,"Equipar")!=null and _action(ui,"Usar")==null)
    _action(ui,"Equipar").pressed.emit()
    assert(model.equipped("shirt")!=top and body.inventory_actions.busy())
    body.action.advance(10)
    assert(model.equipped("shirt")==top)
    ui.select_item(top)
    ui.begin_pending("unequip")
    before=model.snapshot()
    ui.commit_target(_grid(ui,bag),Vector2i(2,0))
    assert(model.snapshot()==before and model.equipped("shirt")==top)
    ui.commit_target(_grid(ui,bag),Vector2i(0,0))
    assert(model.equipped("shirt")==top and body.inventory_actions.busy())
    body.action.advance(10)
    assert(model.equipped("shirt").is_empty() and model.items[top].location==bag)
    model.restore(original)
    body.update_nearby()
    ui.cancel_pending()
    await _frames(scene,2)
    body.condition_path="user://qa_c05_profile68.json"
    assert(body.save_condition())
    assert(body.rotate_item(water))
    assert(body.load_condition() and not model.items[water].rot)
    assert(model.items==original.items)
    assert(body.receive_zone_damage("c05_care","forearm_left","cut",.4))
    body.reaction.advance(2)
    assert(body.use_item(bandage))
    body.action.advance(.1)
    _key(KEY_ESCAPE)
    assert(body.action.state=="idle" and model.items[bandage].count==3 and not body.condition_state.forearm_dressed)
    ui.personal.visible=true
    ui.sync_lock()
    assert(body.use_item(bandage))
    body.action.advance(10)
    assert(model.items[bandage].count==2 and body.condition_state.forearm_dressed)
    body.action.cancel()
    body.reaction.reset()
    body.condition_state.restore(health)
    body.body_health.records.clear()
    model.restore(original)
    body.update_nearby()
    # The direct furniture interaction opens Nearby without closing Personal.
    ui.personal.visible=true
    assert(world.request_open("world:crate"))
    _tick(body,world,.7)
    assert(ui.nearby.visible and ui.personal.visible and ui.near_source=="world:crate")
    _key(KEY_H)
    assert(ui.windows[1].visible and ui.nearby.visible)
    ui.health_ui.toggle(1)
    assert(not ui.windows[1].visible and ui.nearby.visible)
    ui.close_nearby()
    assert(ui.personal.visible and not world.has_interaction())
    _tick(body,world,.3)
    # Hidden windows leave world pointer input available.
    ui.personal.visible=false
    ui.refresh()
    await _frames(scene,3)
    var forbidden=RegEx.new()
    forbidden.compile("(?i)(auto.organiz|abrir espaço|[0-9]+\\s*/\\s*[0-9]+|[0-9]+\\s+(slots|pilhas|livres))")
    for control in ui.find_children("*","Control",true,false):
        if control.is_visible_in_tree() and (control is Label or control is Button):
            assert(forbidden.search(control.text)==null)
    var hit_point=scene.camera.unproject_position(model.point("world:crate")+Vector3.UP*.2)
    _motion(hit_point)
    _mouse(hit_point,true)
    _mouse(hit_point,false)
    assert(world.pending_id=="world:crate")
    world.close_interaction()
    _tick(body,world,.3)
    model.restore(original)
    body.update_nearby()
    ui.cancel_pending()
    ui.personal.visible=true
    ui.refresh()
    await _frames(scene,3)
    var size=scene.get_window().size
    if not capture:
        for width in [960,720]:
            scene.get_window().size=Vector2i(width,720)
            await _frames(scene,3)
            ui._layout()
            assert(ui.workspace.custom_minimum_size.x>=600)
            assert(ui.personal.position.x>=0)
        scene.get_window().size=size
        await _frames(scene,3)
    if capture:
        scene.get_window().size=Vector2i(1440,900)
        await _frames(scene,4)
        # Ground is a real source, created by an explicit item placement.
        assert(body.place_item(food,"drop_here",0,0,false))
        ground=model.items[food].location
        # This item exists only in the QA scene, never in a normal character save.
        model.catalog.qa_box={"name":"Ferramentas · exemplo C05","stack":1,"grid":[3,2]}
        var demo_ground: String=model.ground_at(body.global_position+Vector3(.8,0,0))
        var box: String=model.add_at("qa_box",1,demo_ground,0,0,false)
        body.update_nearby()
        assert(not box.is_empty() and model.world_containers[ground].name!=model.world_containers[demo_ground].name)
        ui.near_source=demo_ground
        ui.nearby_wanted=true
        ui.refresh()
        ui.feedback.text="Arraste os itens para organizar a mochila e os bolsos."
        await _capture(scene,"desktop")
        ui.close_nearby()
        await _capture(scene,"personal")
        ui.reopen.pressed.emit()
        await _frames(scene,3)
        ui.select_item(box)
        ui.start_drag(box,Vector2i.ZERO)
        source_grid=_grid(ui,bag)
        # Keep an external desktop pointer from changing the captured candidate.
        ui.set_process_input(false)
        ui._hover(source_grid.get_global_transform()*Vector2(20,20))
        assert(ui.hover_grid==source_grid and not source_grid.preview_valid)
        await _capture(scene,"invalid")
        ui.set_process_input(true)
        ui.cancel_pending()
        ui.select_item(water)
        ui.commit_target(_grid(ui,bag),Vector2i(3,1))
        ui.select_item(box)
        ui.commit_target(_grid(ui,bag),Vector2i(0,0))
        await _capture(scene,"manual")
        if "house" in world and world.house!=null:
            ui.close_nearby()
            world.house.visit("world:arroio:H01_FURN_GELADEIRA/storage/cooler")
            await scene.get_tree().physics_frame
            assert(world.request_open("world:arroio:H01_FURN_GELADEIRA/storage/cooler"))
            _tick(body,world,.7)
            await _capture(scene,"house")
        scene.get_window().size=Vector2i(960,720)
        await _frames(scene,4)
        await _capture(scene,"narrow")
        ui.scroll.scroll_vertical=ceili(ui.personal.size.y)
        await _capture(scene,"narrow_near")
        ui.scroll.scroll_vertical=0
        scene.get_window().size=size
    FileAccess.open("res://qa/c05_capture68.json" if capture else "res://qa/c05_runtime68.json",FileAccess.WRITE).store_string(JSON.stringify({"personal_sections":true,"unique_multicell_tiles":true,"contextual_actions":true,"pending_drop_no_mutation":true,"save_during_drag_blocked":true,"independent_windows":true,"nearby_no_auto_reopen":true,"rotation":true,"gui_drag":true,"invalid_drop_atomic":true,"escape_cancel":true,"split_manual":true,"equipment_manual":true,"save_load_positions":true,"real_care_consumption":true,"furniture_integration":true,"health_preserved":true,"compact":not capture},"  "))
    print("R68_C05_UI_OK")
    scene.get_tree().quit()

func _grid(ui: Control, id: String) -> Control:
    for grid in ui.grids:
        if grid.container_id==id:
            return grid
    return null

func _find(model: RefCounted, definition: String, location: String) -> String:
    for uid in model.items:
        if model.items[uid].definition==definition and model.items[uid].location==location:
            return uid
    return ""

func _action(ui: Control, name: String) -> Button:
    for action in ui.actions.get_children():
        if action.text==name:
            return action
    return null

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

func _mouse(at: Vector2, pressed: bool) -> void:
    var event=InputEventMouseButton.new()
    event.position=at
    event.global_position=at
    event.button_index=MOUSE_BUTTON_LEFT
    event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
    event.pressed=pressed
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func _motion(at: Vector2) -> void:
    var event=InputEventMouseMotion.new()
    event.position=at
    event.global_position=at
    event.button_mask=MOUSE_BUTTON_MASK_LEFT
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func _tick(body: CharacterBody3D, world: Node3D, seconds: float) -> void:
    for index in ceili(seconds/.01):
        var step=minf(.01,seconds-index*.01)
        body.action.advance(step)
        world.advance(step)

func _frames(scene: Node3D, count: int) -> void:
    for index in count:
        await scene.get_tree().process_frame

func _capture(scene: Node3D, name: String) -> void:
    await _frames(scene,5)
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://previews/c05_68")
    scene.get_viewport().get_texture().get_image().save_png("res://previews/c05_68/"+name+".png")
