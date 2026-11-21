extends Node3D

const CAMERA_AXIS:=Vector3(1,.81649658,-1)
var city: Node3D
var player: CharacterBody3D
var camera: Camera3D
var spawn:=Vector3.ZERO
var focus:=Vector3.ZERO
var zoom:=10.0
var hud: CanvasLayer
var panel: PanelContainer
var status: Label
var mode_choice: OptionButton
var pause_button: CheckButton
var item_choice: OptionButton
var ready_for_tests:=false

func _ready() -> void:
    if "--map117-test" in OS.get_cmdline_user_args():get_tree().set_meta("demo95_profile_override","user://qa_map117_boot_"+str(OS.get_process_id())+".json")
    city=load("res://staging/e06_world/arroio/scenes/arroio_reconstruction.tscn").instantiate()
    city.name="Arroio"
    if load("res://personagem/map117/mode.gd").enabled():city.set_meta("spatial_revision_enabled",true)
    var inspection: Camera3D=city.get_node("InspectionCamera")
    inspection.set_script(null)
    inspection.current=false
    add_child(city)
    if not city.ready_for_integration:
        await city.city_ready
    (city.get_node("Sun") as DirectionalLight3D).directional_shadow_max_distance=35
    for family in ["Terrain/Roads","Terrain/Sidewalks","Terrain/Pavements"]:
        for mesh in city.get_node(family).find_children("*","MeshInstance3D",true,false):
            mesh.create_trimesh_collision()
    camera=Camera3D.new()
    camera.name="IsometricCamera"
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.current=true
    camera.near=.08
    camera.far=140
    add_child(camera)
    player=CharacterBody3D.new()
    player.name="Personagem"
    player.set_script(load("res://player/character.gd"))
    player.camera=camera
    player.scripted="--qa" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args() or "--capture-consumption" in OS.get_cmdline_user_args() or "--capture-combat" in OS.get_cmdline_user_args() or "--capture-reactions" in OS.get_cmdline_user_args() or "--capture-obstacles" in OS.get_cmdline_user_args()
    var gate: Array=city.catalog("lot_overrides").lots.H01.gate_center
    spawn=Vector3(gate[0],.8,gate[1]-1.5)
    player.position=spawn
    add_child(player)
    player.avatar.rotation.y=atan2(CAMERA_AXIS.x,CAMERA_AXIS.z)
    focus=player.global_position+Vector3(0,.85,0)
    _update_camera()
    city.get_node("Landscape").set_occlusion_target(player)
    _interface()
    await _wait_frames(45)
    spawn=player.global_position
    ready_for_tests=true
    if "--qa-base" in OS.get_cmdline_user_args():
        await _qa()
    elif "--capture-consumption" in OS.get_cmdline_user_args():
        await _capture_consumption()
    elif "--capture" in OS.get_cmdline_user_args():
        await _capture()

func _interface() -> void:
    hud=CanvasLayer.new()
    hud.name="ControlesDeTeste"
    add_child(hud)
    panel=PanelContainer.new()
    panel.position=Vector2(14,14)
    panel.custom_minimum_size.x=280
    var style:=StyleBoxFlat.new()
    style.bg_color=Color(.06,.09,.08,.90)
    for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
        style.set_content_margin(side,12)
    panel.add_theme_stylebox_override("panel",style)
    hud.add_child(panel)
    var column:=VBoxContainer.new()
    column.add_theme_constant_override("separation",8)
    panel.add_child(column)
    var title:=Label.new()
    title.text="Arroio · testes do personagem"
    column.add_child(title)
    var help:=Label.new()
    help.text="WASD / setas · mover\nShift · correr     C · furtividade\nI · gesto     Roda · zoom     F1 · painel"
    column.add_child(help)
    mode_choice=OptionButton.new()
    for entry in [["","Controle por teclado"],["idle","Repouso"],["walk","Caminhada no lugar"],["run","Corrida no lugar"],["crouch_idle","Agachado parado"],["crouch","Furtividade no lugar"]]:
        mode_choice.add_item(entry[1])
        mode_choice.set_item_metadata(mode_choice.item_count-1,entry[0])
    mode_choice.item_selected.connect(func(index: int):player.set_preview(mode_choice.get_item_metadata(index)))
    column.add_child(mode_choice)
    pause_button=CheckButton.new()
    pause_button.text="Pausar animação"
    pause_button.toggled.connect(func(value: bool):player.paused=value)
    column.add_child(pause_button)
    _button(column,"Gesto de inventário",func():player.request_gesture())
    item_choice=OptionButton.new()
    for entry in [["camisa_xadrez_vinho","Camisa xadrez"],["camiseta_oliva","Camiseta oliva"],["moletom_cinza","Moletom cinza"]]:
        item_choice.add_item(entry[1])
        item_choice.set_item_metadata(item_choice.item_count-1,entry[0])
    item_choice.select(1)
    column.add_child(item_choice)
    _button(column,"Equipar peça selecionada",func():player.request_equip(item_choice.get_item_metadata(item_choice.selected)))
    _button(column,"Guardar peça do tronco",func():player.request_store())
    _button(column,"Voltar ao ponto de teste",reset_player)
    if player.supplies != null:
        var heading = Label.new()
        heading.text = "Consumo e cuidados · 1 / 2 / 3 / 4"
        column.add_child(heading)
        for pair in [[["eat", "Comer"], ["drink", "Beber"]], [["medicine", "Remédio"], ["bandage", "Curativo"]]]:
            var row = HBoxContainer.new()
            column.add_child(row)
            for entry in pair:
                _button(row, entry[1], func(): player.request_use(entry[0]))
        _button(column, "Repor suprimentos de teste", player.refill_supplies)
    status=Label.new()
    column.add_child(status)

func _button(parent: Node,text: String,callback: Callable) -> void:
    var button:=Button.new()
    button.text=text
    button.pressed.connect(callback)
    parent.add_child(button)

func reset_player() -> void:
    player.global_position=spawn+Vector3.UP*.02
    player.action.cancel()
    player.set_preview("")
    player.velocity=Vector3.ZERO
    player.command=Vector2.ZERO
    player.command_run=false
    player.avatar.rotation.y=atan2(CAMERA_AXIS.x,CAMERA_AXIS.z)
    focus=player.global_position+Vector3(0,.85,0)
    _update_camera()

func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    focus=focus.lerp(player.global_position+Vector3(0,.85,0),1-exp(-delta*12))
    _update_camera()
    if status!=null:
        status.text="%s · zoom %.1f m\n%s"%[player.motion_id,zoom,player.avatar.selection.shirt_id]
        if player.supplies != null:
            var action_label = player.action.action_id if player.action.state != "idle" else player.motion_id
            status.text = "%s · zoom %.1f m\nComida %d · Água %d\nRemédio %d · Curativo %d" % [action_label, zoom, player.supplies.stock.eat, player.supplies.stock.drink, player.supplies.stock.medicine, player.supplies.stock.bandage]
        pause_button.set_pressed_no_signal(player.paused)
        for index in mode_choice.item_count:
            if mode_choice.get_item_metadata(index)==player.preview_motion:
                mode_choice.select(index)

func _update_camera() -> void:
    camera.size=zoom
    camera.global_position=focus+CAMERA_AXIS*12
    camera.look_at(focus)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index==MOUSE_BUTTON_WHEEL_UP:
            zoom=maxf(5,zoom*.85)
        elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
            zoom=minf(18,zoom/.85)
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F1:
        hud.visible=not hud.visible

func _wait_frames(count: int) -> void:
    for frame in range(count):
        await get_tree().physics_frame

func _qa() -> void:
    assert(player.is_on_floor())
    assert(get_tree().get_nodes_in_group("arroio_inspection_walker").is_empty())
    assert(camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
    var original_basis:=camera.global_basis
    var cases: Array=[]
    for mode in ["walk","run","crouch"]:
        reset_player()
        await _wait_frames(5)
        assert(player.set_crouch(mode=="crouch"))
        var before: Vector3=player.global_position
        player.command=Vector2(1,0)
        player.command_run=mode=="run"
        await _wait_frames(40)
        var distance: float=player.global_position.distance_to(before)
        assert(distance>.15 and player.is_on_floor(),mode)
        assert(camera.global_basis.is_equal_approx(original_basis))
        cases.append({"motion":mode,"distance_m":distance,"grounded":player.is_on_floor()})
    reset_player()
    var h01: Dictionary=city.catalog("lot_overrides").lots.H01
    var facade_z: float=h01.body_bounds_xz[1]
    player.global_position=Vector3(h01.body_center_xz[0],.8,facade_z-1.5)
    player.velocity=Vector3.ZERO
    await _wait_frames(30)
    var right:=camera.global_basis.x
    var down:=camera.global_basis.z
    right.y=0
    down.y=0
    player.command=Vector2(Vector3.FORWARD.dot(right.normalized()),Vector3.FORWARD.dot(down.normalized()))*-1
    player.command_run=true
    await _wait_frames(60)
    assert(player.global_position.z<facade_z+.1,"A colisão da fachada H01 não bloqueou o personagem")
    reset_player()
    await _wait_frames(10)
    assert(player.request_gesture())
    await _wait_frames(100)
    assert(player.action.state=="idle")
    assert(player.request_equip("moletom_cinza"))
    await _wait_frames(100)
    assert(player.avatar.selection.shirt_id=="moletom_cinza")
    assert(player.request_store())
    await _wait_frames(100)
    assert(player.avatar.selection.shirt_id=="none")
    player.request_equip("camisa_xadrez_vinho")
    await _wait_frames(100)
    player.set_preview("walk")
    await _wait_frames(10)
    player.paused=true
    var clock: float=player.avatar.motion_clock
    await _wait_frames(15)
    assert(player.avatar.motion_clock==clock)
    player.paused=false
    reset_player()
    if player.supplies != null:
        var verifier = load("res://personagem/verificar_consumo.gd").new()
        verifier.run(player.avatar, player.action)
        var ui_actions = {"Comer": "eat", "Beber": "drink", "Remédio": "medicine", "Curativo": "bandage"}
        var tested_buttons: Array = []
        for button in panel.find_children("*", "Button", true, false):
            if not ui_actions.has(button.text):
                continue
            player.refill_supplies()
            button.pressed.emit()
            var expected: String = ui_actions[button.text]
            assert(player.action.action_id == expected and player.action.state != "idle")
            player.action.advance(10)
            assert(player.supplies.effects[expected] == 1)
            tested_buttons.append(expected)
        assert(tested_buttons.size() == 4)
        player.refill_supplies()
        player.scripted = false
        var key = InputEventKey.new()
        key.physical_keycode = KEY_1
        key.pressed = true
        Input.parse_input_event(key)
        await _wait_frames(2)
        assert(player.action.action_id == "eat" and player.action.state != "idle")
        key = InputEventKey.new()
        key.physical_keycode = KEY_ESCAPE
        key.pressed = true
        Input.parse_input_event(key)
        await _wait_frames(2)
        assert(player.action.state == "idle" and player.supplies.stock.eat == 3)
        player.scripted = true
        FileAccess.open("res://qa/consumo_interface.json", FileAccess.WRITE).store_string(JSON.stringify({"buttons": tested_buttons, "keyboard_begin_cancel": true}, "  "))
    FileAccess.open("res://qa/cena_runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"map":"current Arroio H01-H10","spawn":[spawn.x,spawn.y,spawn.z],"orthographic":true,"elevation_degrees":30,"fixed_camera_basis_verified":true,"movements":cases,"h01_collision_verified":true,"standing_gesture":true,"wardrobe_effects":true,"pause_verified":true,"rig_bones":player.avatar.skeleton.get_bone_count()},"  "))
    print("ISOMETRIC_SCENE_QA_OK")

func _capture() -> void:
    assert(DisplayServer.get_name()!="headless")
    hud.visible=false
    var shots: Array=[]
    for entry in [["contexto","idle",13.0],["personagem","idle",8.0],["caminhada","walk",8.0],["corrida","run",8.0],["furtividade","crouch",8.0]]:
        reset_player()
        zoom=entry[2]
        player.set_preview(entry[1])
        await _wait_frames(35)
        await RenderingServer.frame_post_draw
        var path: String="previews/"+entry[0]+".png"
        assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://"+path))==OK)
        shots.append(path)
    reset_player()
    zoom=9
    player.set_preview("walk")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://previews/ciclo"))
    for frame in range(25):
        player.paused=true
        player.avatar.motion_paused=false
        player.avatar.motion_blend=1
        player.avatar.motion_clock=1.2*frame/24.0
        player.avatar.advance(0)
        player.avatar.motion_paused=true
        await _wait_frames(2)
        await RenderingServer.frame_post_draw
        assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://previews/ciclo/%03d.png"%frame))==OK)
    reset_player()
    zoom=10
    hud.visible=true
    await _wait_frames(15)
    await RenderingServer.frame_post_draw
    assert(get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://previews/interface.png"))==OK)
    shots.append("previews/interface.png")
    FileAccess.open("res://qa/capturas.json",FileAccess.WRITE).store_string(JSON.stringify({"shots":shots,"walk_frames":25,"walk_duration_s":1.2},"  "))
    print("ISOMETRIC_SCENE_CAPTURE_OK")
    get_tree().quit()


func _save_consumption(path: String) -> void:
    await RenderingServer.frame_post_draw
    var destination = ProjectSettings.globalize_path("res://previews/" + path)
    DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
    assert(get_viewport().get_texture().get_image().save_png(destination) == OK)


func _capture_consumption() -> void:
    assert(DisplayServer.get_name() != "headless")
    player.set_physics_process(false)
    hud.visible = false
    zoom = 6
    var sequences: Dictionary = {}
    var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://fontes.json"))
    var revision = int(sources.character_revision)
    var folder = "consumo_r%d" % revision if revision >= 53 else "consumo"
    for kind in player.action.definitions:
        reset_player()
        player.refill_supplies()
        player.avatar.set_appearance({"shirt_id": "camisa_xadrez_vinho"})
        player.avatar.motion_clock = 0
        player.avatar.motion_blend = 1
        player.avatar.hand_layer.advance(.25)
        player.avatar.advance(0)
        assert(player.request_use(kind))
        var entry: Dictionary = player.action.definitions[kind]
        var total: float = player.avatar.motion_transition_duration + entry.duration + .4
        var peak_frame = ceili((player.avatar.motion_transition_duration + float(entry.effect_time)) * 12)
        var frames = ceili(total * 12)
        var trace: Array = []
        for frame in range(frames + 1):
            await _save_consumption("%s/%s/%03d.png" % [folder, kind, frame])
            trace.append({"time": frame / 12.0, "state": player.action.state, "effect_done": player.action.effect_done, "effect_succeeded": player.action.effect_succeeded, "stock": player.supplies.stock[kind], "effects": player.supplies.effects[kind]})
            if frame == peak_frame:
                await _save_consumption("%s/%s.png" % [folder, kind])
            player.action.advance(1.0 / 12)
        sequences[kind] = {"frames": frames + 1, "fps": 12, "peak_frame": peak_frame, "trace": trace}
    player.refill_supplies()
    reset_player()
    player.set_physics_process(true)
    zoom = 10
    hud.visible = true
    await _wait_frames(20)
    await _save_consumption("interface.png")
    FileAccess.open("res://qa/%s_capturas.json" % folder, FileAccess.WRITE).store_string(JSON.stringify(sequences, "  "))
    print("ISOMETRIC_CONSUMPTION_CAPTURE_OK")
    get_tree().quit()
