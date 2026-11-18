extends "res://isometric_test.gd"
var demo_ready=false
var demo_data: Dictionary
var loading_cover: CanvasLayer

func _ready() -> void:
    await super._ready()
    var args=OS.get_cmdline_user_args()
    # Keep the preserved laboratory suites running on their original fixtures.
    for arg in args:
        if (str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) and arg not in ["--qa-demo","--capture-demo","--qa-doors","--capture-doors","--qa-windows","--capture-windows","--qa-variants","--capture-variants","--qa-traversals","--capture-traversals","--qa-fences","--capture-fences"]:
            return
    demo_data=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/demo_h01_73.json"))
    player.demo_mode=true
    player.condition_path=demo_data.profile
    if not _new_inventory():
        push_error("Invalid H01 inventory configuration")
        return
    for fixture in fixtures.values():
        remove_child(fixture)
        fixture.queue_free()
    fixtures.clear()
    if is_instance_valid(training_target):
        remove_child(training_target)
        training_target.queue_free()
    player.combat_target=null
    hud.visible=false
    var house: Node3D=world_items.house
    var spawn_values: Array=demo_data.spawn_local
    var point: Vector3=house.home.model.to_global(Vector3(spawn_values[0],spawn_values[1],spawn_values[2]))
    assert(house.standing_clear(point-Vector3.UP*.02))
    player.global_position=point
    player.velocity=Vector3.ZERO
    spawn=point
    var doors=load("res://personagem/aberturas77.gd").new()
    add_child(doors)
    doors.setup(self)
    await get_tree().physics_frame
    await get_tree().physics_frame
    if not ("--qa-doors" in args or "--capture-doors" in args or "--qa-windows" in args or "--capture-windows" in args or "--qa-variants" in args or "--capture-variants" in args):
        var traversals=load("res://personagem/travessias77.gd").new()
        add_child(traversals)
        traversals.setup(self)
        var fences=load("res://personagem/cercamentos78.gd").new()
        fences.name="Cercamentos78"
        add_child(fences)
        fences.setup(self)
    player.update_nearby()
    zoom=6.5
    focus=point+Vector3.UP*.95
    _update_camera()
    game_ui.personal.visible=false
    game_ui.nearby_wanted=false
    game_ui.nearby.visible=false
    game_ui.windows[1].visible=false
    game_ui.refresh()
    var help=Label.new()
    help.text="WASD · mover    Shift · correr    I · inventário    E · interagir    B · atravessar"
    help.position=Vector2(20, get_viewport().get_visible_rect().size.y-34)
    help.mouse_filter=Control.MOUSE_FILTER_IGNORE
    game_ui.add_child(help)
    get_viewport().size_changed.connect(func():help.position.y=get_viewport().get_visible_rect().size.y-34)
    var verification=false
    for arg in args:
        if str(arg).begins_with("--qa") or str(arg).begins_with("--capture"):verification=true
    if FileAccess.file_exists(player.condition_path) and not verification:
        if player.load_condition():
            game_ui.feedback.text="Inventário retomado"
        else:
            game_ui.feedback.text="Não foi possível carregar o inventário salvo"
    if loading_cover!=null:
        loading_cover.queue_free()
    demo_ready=true
    if "--probe-route" in args:
        await get_tree().physics_frame
        for x in range(-280,90,10):
            var clear=true
            for z in [-.4,-.65,-.9]:
                if not house.standing_clear(house.home.model.to_global(Vector3(x/100.0,.255,z))):clear=false
            if clear:print("KITCHEN_GAP ",x/100.0)
        get_tree().quit()
        return
    if "--qa-fences" in args or "--capture-fences" in args:
        await load("res://personagem/revisao78.gd").new().run(self)
        return
    if "--qa-traversals" in args or "--capture-traversals" in args:
        await load("res://personagem/revisao77.gd").new().run(self)
        return
    if "--qa-variants" in args or "--capture-variants" in args:
        await load("res://personagem/revisao76.gd").new().run(self)
        return
    if "--qa-windows" in args or "--capture-windows" in args:
        await load("res://personagem/revisao75.gd").new().run(self)
        return
    if "--qa-doors" in args or "--capture-doors" in args:
        await load("res://personagem/revisao74.gd").new().run(self)
        return
    if "--qa-demo" in args or "--capture-demo" in args:
        await load("res://personagem/revisao73.gd").new().run(self)

func _new_inventory() -> bool:
    var model: RefCounted=player.bag_inventory
    world_items.close_interaction()
    model.items=model.items.duplicate(true)
    for uid in model.items.keys():
        if model.items[uid].location not in ["slot:shirt","slot:pants","slot:boots","slot:belt"]:
            model.items.erase(uid)
    model.world_containers=model.house_anchors.duplicate(true)
    model.import_grids.clear()
    model.opened.clear()
    model.reachable.clear()
    model.next_id=1
    for uid in model.items:
        model.next_id=maxi(model.next_id,int(str(uid).trim_prefix("item_"))+1)
    for item in demo_data.pockets:
        var uid=model.add_at(item.definition,item.count,"pockets",item.x,item.y,false)
        if uid.is_empty():return false
    for entry in demo_data.loot:
        var id="world:arroio:"+str(entry.furniture)
        if not model.world_containers.has(id):return false
        for item in entry.items:
            var uid=model.add_at(item.definition,item.count,id,item.x,item.y,false)
            if uid.is_empty():return false
    model.seeding=false
    if not model.valid(model.items):return false
    model.changed.emit()
    player.update_nearby()
    game_ui.cancel_pending()
    game_ui.refresh()
    return true

func _unhandled_input(event: InputEvent) -> void:
    if demo_ready and event is InputEventKey and event.physical_keycode==KEY_F1:
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)

func _interface() -> void:
    super._interface()
    for arg in OS.get_cmdline_user_args():
        if (str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) and arg not in ["--qa-demo","--capture-demo","--qa-doors","--capture-doors","--qa-windows","--capture-windows","--qa-variants","--capture-variants","--qa-traversals","--capture-traversals","--qa-fences","--capture-fences"]:
            return
    loading_cover=CanvasLayer.new()
    loading_cover.layer=90
    add_child(loading_cover)
    var cover=ColorRect.new()
    cover.color=Color("19211e")
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_cover.add_child(cover)
    var label=Label.new()
    label.text="Carregando..."
    label.position=Vector2(28,28)
    cover.add_child(label)
