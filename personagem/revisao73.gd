extends RefCounted
var shots: Array=[]
func run(scene: Node3D) -> void:
    var h: Node3D=scene.world_items.house
    var body: CharacterBody3D=scene.player
    var model: RefCounted=body.bag_inventory
    var ui: Control=scene.game_ui
    var world: Node3D=scene.world_items
    var capture="--capture-demo" in OS.get_cmdline_user_args()
    scene.get_window().size=Vector2i(1440,900)
    body.condition_path="user://qa_demo_inventory_r75_%d.json"%(body.map_doors.doors.size() if body.map_doors!=null else 0)
    assert(model.items.size()==13 and model.equipped("backpack").is_empty())
    assert(model.world_containers.size()==15 and not model.world_containers.has("world:crate") and not model.world_containers.has("world:cabinet"))
    assert(scene.fixtures.is_empty() and not is_instance_valid(body.combat_target) and not scene.hud.visible)
    assert(not ui.personal.visible and not ui.nearby.visible and body.demo_mode)
    var before=model.snapshot()
    var point=body.global_position
    for key in [KEY_F7,KEY_1,KEY_J,KEY_K,KEY_L,KEY_M,KEY_V,KEY_B]:_key(key)
    await scene.get_tree().physics_frame
    assert(model.snapshot()==before and not body.reaction.is_active() and body.action.state=="idle" and body.global_position.distance_to(point)<.05)
    if body.map_doors!=null and not body.map_doors.doors["H01/Hinge_BASE_PORTAL_D_Q1_LEAF_PIVOT"].open:
        _key(KEY_E)
        await _idle(scene)
    # Verify the actual physical-key path, then drive the same collision controller
    # along explicit waypoints so the traversal test is repeatable without teleport.
    body.scripted=false
    _key(KEY_W,true)
    for frame in 14:await scene.get_tree().physics_frame
    _key(KEY_W,false)
    for frame in 8:await scene.get_tree().physics_frame
    assert(body.global_position.distance_to(point)>.03)
    body.scripted=true
    await _walk(scene,Vector3(1.73,.275,.2))
    if capture:await _capture(scene,"start")
    await _walk(scene,Vector3(1.73,.275,.55))
    await _walk(scene,h.home.model.to_local(h.groups["H01_FURN_GUARDA_CASAL"].point)+Vector3.UP*.02)
    var wardrobe="world:arroio:H01_FURN_GUARDA_CASAL/storage/main"
    _key(KEY_E)
    await _idle(scene)
    assert(world.active_id==wardrobe and ui.nearby.visible and model.accessible(wardrobe))
    if capture:await _capture(scene,"wardrobe")
    var bag=_find(model,"bag_school",wardrobe)
    var top=_find(model,"moletom_cinza",wardrobe)
    ui.select_item(bag)
    _button(ui,"Equipar").pressed.emit()
    assert(body.inventory_actions.busy() and model.equipped("backpack").is_empty())
    await _idle(scene)
    assert(model.equipped("backpack")==bag and model.dimensions(bag)==Vector2i(4,2))
    ui.select_item(top)
    ui.commit_target(_grid(ui,bag),Vector2i(1,0))
    assert(model.items[top].location==bag and model.items[top].x==1)
    ui.select_item(top)
    _button(ui,"Equipar").pressed.emit()
    await _idle(scene)
    assert(model.equipped("shirt")==top and model.contents(wardrobe).is_empty())
    assert(body.avatar.selection.shirt_id=="moletom_cinza")
    ui.personal.visible=true
    ui.refresh()
    if capture:await _capture(scene,"equipped")
    _close(ui,world)
    await _walk(scene,Vector3(1.73,.275,.2))
    await _walk(scene,Vector3(-.65,.275,0))
    await _walk(scene,Vector3(-.65,.275,-1.1))
    await _walk(scene,h.home.model.to_local(h.groups["H01_FURN_GELADEIRA"].point)+Vector3.UP*.02)
    var cooler="world:arroio:H01_FURN_GELADEIRA/storage/cooler"
    _key(KEY_E)
    await _idle(scene)
    assert(world.active_id==cooler and model.accessible(cooler))
    var water=_find(model,"water",cooler)
    var food=_find(model,"food",cooler)
    ui.select_item(water)
    ui.commit_target(_grid(ui,bag),Vector2i(0,0))
    ui.select_item(food)
    ui.commit_target(_grid(ui,bag),Vector2i(3,0))
    assert(model.items[water].location==bag and model.items[food].location==bag and model.contents(cooler).is_empty())
    ui.personal.visible=true
    ui.refresh()
    if capture:await _capture(scene,"supplies")
    ui.select_item(food)
    _button(ui,"Usar").pressed.emit()
    await _idle(scene)
    assert(model.items[food].count==1)
    _close(ui,world)
    assert(body.save_condition())
    var saved=model.snapshot()
    assert(model.restore(saved))
    body.update_nearby()
    # Change an owned item, then use the real profile loader to restore its cells.
    assert(body.place_item(food,"pockets",1,0,false))
    assert(body.load_condition())
    assert(model.items==saved.items and model.contents(wardrobe).is_empty() and model.contents(cooler).is_empty())
    assert(model.equipped("backpack")==bag and model.equipped("shirt")==top)
    assert(not ui.nearby.visible)
    ui.personal.visible=true
    ui.refresh()
    if capture:await _capture(scene,"saved")
    var result={"normal_wasd":true,"collision_walk_no_teleport":true,"e_interaction":true,"hud_equipment":true,"manual_loot_cells":true,"item_consumed_once":true,"save_load_stock":true,"emptied_containers_stay_empty":true,"no_test_containers":true,"no_training_target":true,"no_test_obstacles":true,"test_shortcuts_disabled":true,"separate_profile":true,"initial_instances":13,"fixed_containers":15}
    if capture:result.native_capture=true
    FileAccess.open("res://qa/demo73.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R73_DEMO_OK ",result)
    scene.get_tree().quit()

func _walk(scene: Node3D, local: Vector3) -> void:
    var body: CharacterBody3D=scene.player
    var target: Vector3=scene.world_items.house.home.model.to_global(local)
    for frame in 1800:
        var difference: Vector3=target-body.global_position
        difference.y=0
        if difference.length()<.08:
            body.command=Vector2.ZERO
            for wait in 8:await scene.get_tree().physics_frame
            return
        var right: Vector3=scene.camera.global_basis.x
        var down: Vector3=scene.camera.global_basis.z
        right.y=0
        down.y=0
        body.command=Vector2(difference.normalized().dot(right.normalized()),difference.normalized().dot(down.normalized()))
        await scene.get_tree().physics_frame
    assert(false,"Route blocked at "+str(scene.world_items.house.home.model.to_local(body.global_position)))
func _idle(scene: Node3D) -> void:
    for frame in 900:
        await scene.get_tree().physics_frame
        if scene.player.action.state=="idle" and scene.world_items.pending_id.is_empty() and (scene.player.map_doors==null or not scene.player.map_doors.busy()):
            for wait in 4:await scene.get_tree().process_frame
            return
    assert(false,"Action did not finish")
func _key(code: int, pressed: Variant=null) -> void:
    var event=InputEventKey.new()
    event.physical_keycode=code
    event.keycode=code
    event.pressed=true if pressed==null else bool(pressed)
    Input.parse_input_event(event)
    Input.flush_buffered_events()
    if pressed==null:
        event=event.duplicate()
        event.pressed=false
        Input.parse_input_event(event)
        Input.flush_buffered_events()
func _close(ui: Control, world: Node3D) -> void:
    world.close_interaction()
    ui.personal.visible=false
    ui.nearby_wanted=false
    ui.refresh()
func _find(model: RefCounted, definition: String, place: String) -> String:
    for uid in model.contents(place):
        if model.items[uid].definition==definition:return uid
    return ""
func _button(ui: Control, label: String) -> Button:
    for child in ui.actions.get_children():
        if child is Button and child.text==label:return child
    assert(false,"Missing action "+label)
    return null
func _grid(ui: Control, id: String) -> Control:
    for grid in ui.grids:
        if grid.container_id==id:return grid
    assert(false,"Missing grid "+id)
    return null
func _capture(scene: Node3D, name: String) -> void:
    for frame in 4:await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://previews/demo73")
    scene.get_viewport().get_texture().get_image().save_png("res://previews/demo73/"+name+".png")
