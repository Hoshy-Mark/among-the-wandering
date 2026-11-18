extends "res://isometric_base_r55.gd"

var fixtures: Dictionary = {}
var chosen = "fence"


func _ready() -> void:
    await super._ready()
    var centre = spawn + Vector3(0, 0, -4)
    for kind in ["fence", "window"]:
        var fixture = load("res://personagem/obstaculo_teste.gd").new()
        fixture.kind = kind
        fixture.position = centre + (Vector3(3.5, 0, 0) if kind == "window" else Vector3.ZERO)
        fixture.rotation_degrees.y = 0
        var query = PhysicsRayQueryParameters3D.create(fixture.position + Vector3.UP * 2, fixture.position - Vector3.UP, 1)
        var hit = get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            fixture.position.y = hit.position.y
        add_child(fixture)
        fixtures[kind] = fixture
    await _wait_frames(2)
    var arguments = OS.get_cmdline_user_args()
    if "--qa" in arguments:
        training_target.position += Vector3(8, 0, 0)
        await _qa()
        await _qa_combat()
        await _qa_reactions()
        await _qa_obstacles()
        get_tree().quit()
    elif "--capture-obstacles" in arguments:
        await _capture_obstacles()


func _interface() -> void:
    super._interface()
    var tabs = panel.get_child(0)
    tabs.get_child(1).name = "Combate"
    tabs.get_child(2).name = "Itens"
    tabs.custom_minimum_size.x = 350
    var column = VBoxContainer.new()
    column.name = "Obstáculos"
    column.add_theme_constant_override("separation", 9)
    tabs.add_child(column)
    tabs.move_child(column, 0)
    tabs.current_tab = 0
    var title = Label.new()
    title.text = "R58 · Janelas e cercas"
    column.add_child(title)
    var help = Label.new()
    help.text = "B · transpor     V · abrir janela\nEsc · cancelar antes do salto"
    column.add_child(help)
    _button(column, "Posicionar na cerca", func(): place_fixture("fence"))
    _button(column, "Posicionar na janela", func(): place_fixture("window"))
    _button(column, "Abrir janela", func(): player.request_open(fixtures.window))
    _button(column, "Transpor obstáculo selecionado", func(): player.request_cross(fixtures[chosen]))
    _button(column, "Cancelar ação", func(): player.traversal.cancel())
    var pause = CheckButton.new()
    pause.text = "Pausar animação"
    pause.toggled.connect(func(value: bool): player.paused = value)
    column.add_child(pause)
    var label = Label.new()
    label.name = "ObstacleStatus"
    column.add_child(label)


func reset_player() -> void:
    if player != null and player.traversal != null:
        player.traversal.reset_test()
    super.reset_player()


func place_fixture(kind: String) -> void:
    reset_player()
    for fixture in fixtures.values():
        fixture.reset_test()
    chosen = kind
    var fixture: Node3D = fixtures[kind]
    player.global_position = fixture.global_position + fixture.global_basis * Vector3(0, .003, -.85)
    player.avatar.rotation.y = fixture.rotation.y
    player.velocity = Vector3.ZERO
    player.command = Vector2.ZERO
    focus = fixture.global_position + Vector3.UP * 1.0
    _update_camera()


func _process(delta: float) -> void:
    super._process(delta)
    if not is_instance_valid(player) or player.traversal == null:
        return
    var label = panel.find_child("ObstacleStatus", true, false)
    if label != null:
        label.text = "%s · %s\n%s" % [player.avatar.motion, player.traversal.state, player.traversal.message]


func _qa_obstacles() -> void:
    reset_player()
    player.set_physics_process(false)
    await load("res://personagem/verificar_obstaculos.gd").new().run(player, fixtures)
    place_fixture("window")
    player.set_physics_process(true)
    player.scripted = false
    var key = InputEventKey.new()
    key.physical_keycode = KEY_V
    key.keycode = KEY_V
    key.pressed = true
    Input.parse_input_event(key)
    Input.flush_buffered_events()
    await _wait_frames(3)
    assert(player.traversal.is_active() and player.traversal.id == "open_window", player.traversal.message + " state=" + player.traversal.state + " key=" + str(player.last_obstacle_key) + " accepted=" + str(player.last_obstacle_request))
    key = key.duplicate()
    key.pressed = false
    Input.parse_input_event(key)
    Input.flush_buffered_events()
    for frame in 240:
        if not player.traversal.is_active():
            break
        await _wait_frames(1)
    assert(fixtures.window.opened and player.traversal.state == "idle")
    key = InputEventKey.new()
    key.physical_keycode = KEY_B
    key.keycode = KEY_B
    key.pressed = true
    Input.parse_input_event(key)
    Input.flush_buffered_events()
    await _wait_frames(3)
    assert(player.traversal.is_active() and player.traversal.id == "vault_window", player.traversal.message + " state=" + player.traversal.state + " position=" + str(player.global_position) + " fixture=" + str(fixtures.window.global_position) + " key=" + str(player.last_obstacle_key) + " accepted=" + str(player.last_obstacle_request))
    key = key.duplicate()
    key.pressed = false
    Input.parse_input_event(key)
    Input.flush_buffered_events()
    await _wait_frames(300)
    assert(player.traversal.state == "idle" and player.is_on_floor())
    assert(fixtures.window.effects.vault_window == 1)
    player.scripted = true
    FileAccess.open("res://qa/obstaculos_interface_r58.json", FileAccess.WRITE).store_string(JSON.stringify({"keyboard_v_b": true, "grounded_after_landing": true, "physical_fixtures": true}, "  "))
    print("ISOMETRIC_OBSTACLES_R58_QA_OK")


func _prepare_capture(id: String) -> void:
    place_fixture("fence" if id == "vault_fence" else "window")
    player.avatar.set_appearance({"shirt_id": "camisa_xadrez_vinho"})
    if id == "vault_window":
        assert(player.request_open(fixtures.window))
        player.traversal.advance(4)
        await _wait_frames(2)
    assert(player.request_open(fixtures.window) if id == "open_window" else player.request_cross(fixtures[chosen]))
    for frame in 180:
        if player.traversal.state == "playing":
            return
        player.traversal.advance(1.0 / 120)
    assert(false)


func _capture_obstacles() -> void:
    player.set_physics_process(false)
    hud.visible = false
    training_target.visible = false
    zoom = 5.5
    var sequences: Dictionary = {}
    for id in ["open_window", "vault_fence", "vault_window"]:
        await _prepare_capture(id)
        var duration: float = player.traversal.definitions.actions[id].duration / player.traversal.playback_rate
        var frames = ceili((duration + .4) * 24) + 1
        var trace: Array = []
        focus = fixtures[chosen].global_position + Vector3.UP * 1.1
        _update_camera()
        for frame in frames:
            if frame > 0:
                if player.traversal.is_active():
                    player.traversal.advance(1.0 / 24)
                else:
                    player.action.advance(1.0 / 24)
            trace.append({"time": frame / 24.0, "state": player.traversal.state, "cursor": player.traversal.cursor, "effect_done": player.traversal.effect_done})
            await _save_consumption("obstaculos_r58/%s/%03d.png" % [id, frame])
        assert(player.traversal.effect_succeeded and player.traversal.state == "idle")
        sequences[id] = {"frames": frames, "fps": 24, "trace": trace}
    place_fixture("window")
    zoom = 8
    hud.visible = true
    await _wait_frames(2)
    await _save_consumption("obstaculos_r58/interface.png")
    FileAccess.open("res://qa/obstaculos_r58_capturas.json", FileAccess.WRITE).store_string(JSON.stringify(sequences, "  "))
    print("ISOMETRIC_OBSTACLES_R58_CAPTURE_OK")
    get_tree().quit()
