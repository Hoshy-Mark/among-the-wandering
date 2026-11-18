extends RefCounted

func run(scene: Node3D, capture: bool=false, finish: bool=true) -> void:
    await load("res://personagem/revisao64.gd").new().run(scene,false,false)
    var body: CharacterBody3D=scene.player
    var model: RefCounted=body.bag_inventory
    var ui: Control=scene.game_ui
    var original=model.snapshot()
    var origin=body.global_position
    var bag: String=model.equipped("backpack")
    var bandage=_find(model,"bandage","pockets")
    var total=_total(model,"bandage")
    var events={"count":0,"id":0}
    var observer=func():
        events.count+=1
        events.id=model.next_id
    model.changed.connect(observer)
    ui.container_id="pockets"
    ui.refresh()
    ui.select_item(bandage)
    ui.amount.value=1
    var next_id: int=model.next_id
    ui.divide_button.pressed.emit()
    var separated: String=ui.selected_uid
    assert(separated!=bandage and model.items[bandage].count==2 and model.items[separated].count==1)
    assert(events.count==1 and events.id==next_id+1 and model.next_id==next_id+1)
    assert(model.contents("pockets").size()==5 and _total(model,"bandage")==total)
    # Dropping onto the compatible stack merges and frees the extra cell.
    var target=load("res://personagem/slot65.gd").new()
    target.hud=ui
    target.uid=bandage
    target.destination="pockets"
    assert(target._can_drop_data(Vector2.ZERO,{"item_uid":separated}))
    target._drop_data(Vector2.ZERO,{"item_uid":separated})
    assert(model.items[bandage].count==3 and not model.items.has(separated))
    assert(events.count==2 and _total(model,"bandage")==total)
    assert(not target._can_drop_data(Vector2.ZERO,{"item_uid":bandage}))
    target.free()
    # Splitting in a full container cannot allocate IDs or modify a count.
    assert(not model.add("water",1,"pockets").is_empty())
    assert(not model.add("water",1,"pockets").is_empty())
    var before=model.snapshot()
    assert(body.split_item(bandage,1).is_empty() and model.snapshot()==before)
    assert(body.split_item(bandage,0).is_empty() and model.snapshot()==before)
    assert(body.split_item(bandage,3).is_empty() and model.snapshot()==before)
    assert(body.split_item(bag,1).is_empty() and model.snapshot()==before)
    model.restore(original)
    body.update_nearby()
    # A full backpack accepts quantities that fit existing piles.
    var destination=model.add("bandage",9,bag)
    for index in model.capacity(bag)-model.contents(bag).size():
        assert(not model.add("water",1,bag).is_empty())
    assert(body.transfer_items(bandage,bag,1))
    assert(model.items[destination].count==10 and model.items[bandage].count==2)
    before=model.snapshot()
    assert(not body.transfer_items(bandage,bag,1) and model.snapshot()==before)
    assert(not body.merge_items(bandage,destination,1) and model.snapshot()==before)
    # A transfer that partly fits is rejected as a whole if its remainder has no cell.
    model.restore(original)
    body.update_nearby()
    destination=model.add("bandage",9,bag)
    for index in model.capacity(bag)-model.contents(bag).size():
        model.add("water",1,bag)
    before=model.snapshot()
    assert(not body.transfer_items(bandage,bag,2) and model.snapshot()==before)
    # Explicit joining fills the target and leaves the remainder in its source.
    assert(body.merge_items(bandage,destination,3))
    assert(model.items[destination].count==10 and model.items[bandage].count==2)
    assert(_total(model,"bandage")==12)
    var water=_find(model,"water",bag)
    before=model.snapshot()
    assert(not body.merge_items(bandage,water,1) and model.snapshot()==before)
    # Identifiers are needed only when a new pile is created.
    model.restore(original)
    body.update_nearby()
    model.next_id=2147483647
    before=model.snapshot()
    assert(body.split_item(bandage,1).is_empty() and model.snapshot()==before)
    assert(not body.transfer_items(bandage,bag,1) and model.snapshot()==before)
    assert(body.move_item(bandage,bag) and model.items[bandage].location==bag)
    model.restore(original)
    body.update_nearby()
    # Distant or blocked containers cannot receive partial transfers or merges.
    var remote=model.add("bandage",2,"world:crate")
    body.global_position=origin+Vector3(-6,0,0)
    body.update_nearby()
    before=model.snapshot()
    assert(not body.transfer_items(remote,bag,1) and model.snapshot()==before)
    assert(not body.transfer_items(bandage,"world:crate",1) and model.snapshot()==before)
    assert(not body.merge_items(bandage,remote,1) and model.snapshot()==before)
    body.global_position=origin
    body.update_nearby()
    # Partial dropping preserves quantity and the physical location of the new pile.
    ui.container_id="pockets"
    ui.refresh()
    ui.select_item(bandage)
    _destination(ui,"ground")
    ui.amount.value=1
    ui.transfer_button.pressed.emit()
    var loose=_find_world(model,"bandage")
    assert(model.items[bandage].count==2 and model.items[loose].count==1)
    assert(model.point(model.items[loose].location).distance_to(origin)<.01)
    body.condition_path="user://qa_profile65.json"
    assert(body.save_condition())
    var saved=model.snapshot()
    assert(body.move_item(loose,bag))
    assert(body.load_condition() and model.items==saved.items and model.next_id==saved.next_id)
    model.changed.disconnect(observer)
    # The UI preserves the chosen destination through a partial transfer refresh.
    model.restore(original)
    body.update_nearby()
    ui.container_id="pockets"
    ui.refresh()
    ui.select_item(bandage)
    _destination(ui,bag)
    ui.amount.value=1
    ui.transfer_button.pressed.emit()
    assert(model.items[bandage].count==2)
    assert(str(ui.destination.get_item_metadata(ui.destination.selected))==bag)
    var split_to_bag=_find(model,"bandage",bag)
    assert(model.items[split_to_bag].count==1)
    # Changing a pile during an item action invalidates its pending consumption.
    model.restore(original)
    body.update_nearby()
    var health=body.condition_state.snapshot()
    assert(body.receive_zone_damage("stacks65_care","forearm_left","cut",.4))
    body.reaction.advance(2)
    assert(body.use_item(bandage))
    assert(not body.split_item(bandage,1).is_empty())
    body.action.advance(10)
    assert(not body.condition_state.forearm_dressed and _total(model,"bandage")==3)
    body.action.cancel()
    body.reaction.reset()
    body.condition_state.restore(health)
    body.body_health.records.clear()
    # Compact layout still fits the added quantity controls.
    var window=scene.get_window()
    var size=window.size
    if not capture:
        window.size=Vector2i(960,720)
        await scene.get_tree().process_frame
        ui._layout()
        ui.windows[1].visible=false
        ui.windows[0].visible=true
        await scene.get_tree().process_frame
        ui._layout()
        assert(ui.windows[0].size.x<=window.size.x-30)
        assert(ui.windows[0].get_global_rect().end.y<=window.size.y)
        window.size=size
        await scene.get_tree().process_frame
    model.restore(original)
    body.update_nearby()
    if capture:
        ui.container_id="pockets"
        ui.refresh()
        ui.select_item(bandage)
        ui.amount.value=1
        ui.feedback.text="Escolha a quantidade para dividir, mover ou juntar."
        await _capture(scene,"quantity")
        ui.divide_button.pressed.emit()
        await _capture(scene,"split")
        ui.join_button.pressed.emit()
        await _capture(scene,"joined")
        ui.select_item(bandage)
        _destination(ui,bag)
        ui.amount.value=1
        ui.transfer_button.pressed.emit()
        ui.container_id=bag
        ui.refresh()
        ui.select_item(_find(model,"bandage",bag))
        ui.feedback.text="Uma unidade foi transferida. Duas permanecem nos bolsos."
        await _capture(scene,"transfer")
    FileAccess.open("res://qa/stacks65_capture.json" if capture else "res://qa/stacks65.json",FileAccess.WRITE).store_string(JSON.stringify({"world64_regression":true,"split":true,"merge_drag":true,"quantity_ui":true,"full_destination_merge":true,"remainder_failure_atomic":true,"partial_merge":true,"incompatible_rejected":true,"id_exhaustion":true,"stale_access":true,"partial_ground_drop":true,"save_load":true,"signals_atomic":true,"pending_consumption_revalidated":true,"compact_layout":not capture},"  "))
    print("R65_STACKS_OK")
    if finish:
        scene.get_tree().quit()

func _capture(scene: Node3D, name: String) -> void:
    for frame in 6:
        await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var panel: Control=scene.game_ui.windows[0]
    assert(panel.get_global_rect().end.y<=scene.get_viewport().get_visible_rect().size.y)
    DirAccess.make_dir_recursive_absolute("res://previews/stacks65")
    scene.get_viewport().get_texture().get_image().save_png("res://previews/stacks65/"+name+".png")

func _find(model: RefCounted, definition: String, location: String) -> String:
    for uid in model.items:
        if model.items[uid].definition==definition and model.items[uid].location==location:
            return uid
    return ""

func _find_world(model: RefCounted, definition: String) -> String:
    for uid in model.items:
        var location: String=model.items[uid].location
        if model.items[uid].definition==definition and model.world_containers.has(location) and model.world_containers[location].kind=="ground":
            return uid
    return ""

func _total(model: RefCounted, definition: String) -> int:
    var total=0
    for item in model.items.values():
        if item.definition==definition:
            total+=int(item.count)
    return total

func _destination(ui: Control, id: String) -> void:
    for index in ui.destination.item_count:
        if str(ui.destination.get_item_metadata(index))==id:
            ui.destination.select(index)
            return
    assert(false,"Destino ausente")
