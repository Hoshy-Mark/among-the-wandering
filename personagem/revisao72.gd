extends RefCounted
var events: Array=[]
func run(scene: Node3D) -> void:
    var body: CharacterBody3D=scene.player
    var model: RefCounted=body.bag_inventory
    var ui: Control=scene.game_ui
    var world: Node3D=scene.world_items
    var capture="--capture-equipment" in OS.get_cmdline_user_args()
    scene.get_window().size=Vector2i(1440,900)
    body.scripted=true
    body.set_physics_process(false)
    world.set_physics_process(false)
    var original=model.snapshot()
    var original_condition=body.condition_state.snapshot()
    var original_health=body.body_health.snapshot()
    var bag: String=model.equipped("backpack")
    var shirt: String=model.equipped("shirt")
    var top=_find(model,"moletom_cinza",bag)
    var food=_find(model,"food","pockets")
    var water=_find(model,"water",bag)
    body.action.effect_applied.connect(func(kind,ok):events.append({"kind":kind,"success":ok}))
    ui.personal.visible=true
    ui.refresh()
    assert(body.equip_item(top))
    assert(body.inventory_actions.busy() and body.action.motion_id=="equip_item" and model.snapshot()==original)
    assert(not body.equip_item(top) and not body.rotate_item(water) and not body.place_item(food,bag,3,0,false))
    body.condition_path="user://qa_equipment72.json"
    assert(not body.save_condition() and not body.load_condition())
    body.action.advance(.05)
    _escape()
    assert(not body.inventory_actions.busy() and body.action.state=="idle" and model.snapshot()==original)
    # The effect is applied once at the gesture's defined boundary.
    events.clear()
    assert(body.equip_item(top))
    _to_effect(body)
    assert(model.equipped("shirt")==top and events.size()==1 and events[0].success)
    assert(model.items[shirt].location==bag and model.items[shirt].x==1 and model.items[shirt].y==2)
    var committed=model.snapshot()
    body.action.cancel()
    body.action.advance(10)
    assert(model.snapshot()==committed and events.size()==1 and not body.inventory_actions.busy())
    # Removing waits for a valid, explicitly selected cell.
    var before=model.snapshot()
    assert(not body.place_item(top,bag,0,0,false) and model.snapshot()==before and not body.inventory_actions.busy())
    assert(body.place_item(top,bag,1,0,false))
    assert(model.snapshot()==before and body.action.motion_id=="store_item")
    body.action.advance(.05)
    body.action.cancel()
    assert(model.snapshot()==before)
    assert(body.place_item(top,bag,1,0,false))
    body.action.advance(10)
    assert(model.equipped("shirt").is_empty() and model.items[top].location==bag and model.items[top].x==1 and model.items[top].y==0)
    assert(body.avatar.selection.shirt_id=="none")
    assert(body.save_condition())
    var stored=model.snapshot()
    assert(body.place_item(food,bag,3,2,false))
    assert(body.load_condition() and model.items==stored.items)
    # A destination changed by an external event cannot displace an item.
    assert(model.restore(original))
    body.update_nearby()
    assert(body.equip_item(top))
    assert(model.place(food,bag,1,0,false))
    before=model.snapshot()
    body.action.advance(10)
    assert(model.snapshot()==before and model.equipped("shirt")==shirt and not body.action.effect_succeeded)
    # Damage cancels before the effect boundary.
    assert(model.restore(original))
    body.update_nearby()
    assert(body.equip_item(top))
    before=model.snapshot()
    assert(body.receive_zone_damage("equipment72_hit","forearm_left","cut",.1))
    body.action.advance(10)
    assert(model.snapshot()==before and not body.inventory_actions.busy())
    body.reaction.reset()
    body.condition_state.restore(original_condition)
    body.body_health.restore(original_health)
    body._sync_condition()
    # Equipped full backpack and occupied clothing destinations fail preflight.
    before=model.snapshot()
    assert(not body.place_item(bag,"drop_here",0,0,false) and model.snapshot()==before and not body.inventory_actions.busy())
    # Empty backpack drop allocates ground only at the effect, never at preview.
    model.restore(original)
    for uid in model.contents(bag):model.items.erase(uid)
    model.changed.emit()
    body.update_nearby()
    before=model.snapshot()
    assert(body.place_item(bag,"drop_here",0,0,false))
    assert(model.snapshot()==before)
    body.action.cancel()
    assert(model.snapshot()==before)
    assert(body.place_item(bag,"drop_here",0,0,false))
    body.action.advance(10)
    assert(model.equipped("backpack").is_empty() and model.world_containers[model.items[bag].location].kind=="ground")
    assert(ui.nearby_wanted and ui.near_source==model.items[bag].location)
    # Losing the open source before the effect refuses the equipment swap.
    model.restore(original)
    body.update_nearby()
    var cabinet="world:arroio:H01_FURN_COMODA_CASAL/storage/drawer_1"
    world.house.visit(cabinet)
    await scene.get_tree().physics_frame
    body.update_nearby()
    assert(model.set_open(cabinet,true))
    assert(model.place(top,cabinet,1,0,false))
    assert(body.equip_item(top))
    model.set_open(cabinet,false)
    before=model.snapshot()
    body.action.advance(10)
    assert(model.snapshot()==before and model.equipped("shirt")==shirt and not body.action.effect_succeeded)
    model.restore(original)
    body.update_nearby()
    var result={"delayed_equip":true,"delayed_store":true,"cancel_before_unchanged":true,"cancel_after_keeps_commit":true,"one_effect":true,"exact_destination":true,"no_auto_pack":true,"preflight_fail_unchanged":true,"busy_mutations_blocked":true,"save_load_guard":true,"saved_coordinates":true,"changed_stock_rejected":true,"damage_cancel":true,"full_bag_blocked":true,"empty_bag_ground_deferred":true,"source_access_rechecked":true,"clothing_visual_synced":true}
    if capture:
        scene.set_process(false)
        # Use the same standing spot in Arroio with the existing isometric basis.
        world.house.visit("world:arroio:H01_FURN_PIA_COZ/storage/main")
        await scene.get_tree().physics_frame
        body.update_nearby()
        scene.camera.size=3.8
        var focus=body.global_position+Vector3.UP*.9
        var front: Vector3=world.house.groups["H01_FURN_PIA_COZ"].front
        var axis=front+Vector3.UP*.9-front.cross(Vector3.UP)*.6
        scene.camera.global_position=focus+axis*12
        scene.camera.look_at(focus)
        ui.visible=false
        await _capture(scene,"before")
        assert(body.equip_item(top))
        var equip_duration=body.avatar.motion_transition_duration+body.avatar.player.get_animation(body.avatar.clips.equip_item).length
        for frame in 30:
            body.action.advance(equip_duration/30)
            await _capture(scene,"equip_frames/%02d"%frame)
        body.action.advance(10)
        await _capture(scene,"equipped")
        ui.visible=true
        ui.personal.visible=true
        ui.nearby_wanted=false
        ui.refresh()
        scene.camera.size=4.6
        focus-=scene.camera.global_basis.x*1.4
        scene.camera.global_position=focus+axis*12
        scene.camera.look_at(focus)
        await _capture(scene,"hud")
        ui.visible=false
        focus=body.global_position+Vector3.UP*.9
        scene.camera.size=3.8
        scene.camera.global_position=focus+axis*12
        scene.camera.look_at(focus)
        assert(body.place_item(top,bag,1,0,false))
        var store_duration=body.avatar.motion_transition_duration+body.avatar.player.get_animation(body.avatar.clips.store_item).length
        for frame in 30:
            body.action.advance(store_duration/30)
            await _capture(scene,"store_frames/%02d"%frame)
        body.action.advance(10)
        await _capture(scene,"stored")
        result.native_capture=true
    FileAccess.open("res://qa/equipment72.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R72_EQUIPMENT_OK ",result)
    scene.get_tree().quit()

func _find(model: RefCounted, definition: String, place: String) -> String:
    for uid in model.contents(place):
        if model.items[uid].definition==definition:return uid
    return ""
func _to_effect(body: CharacterBody3D) -> void:
    for frame in 1000:
        body.action.advance(.005)
        if body.action.effect_done:return
    assert(false,"No effect boundary reached")
func _escape() -> void:
    var key=InputEventKey.new()
    key.physical_keycode=KEY_ESCAPE
    key.keycode=KEY_ESCAPE
    key.pressed=true
    Input.parse_input_event(key)
    Input.flush_buffered_events()
func _capture(scene: Node3D, name: String) -> void:
    for frame in 3:await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/equipment72/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
