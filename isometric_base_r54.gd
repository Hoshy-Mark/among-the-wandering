extends "res://isometric_base_r53.gd"

var training_target: StaticBody3D


func _ready() -> void:
    await super._ready()
    training_target = load("res://personagem/alvo_treino.gd").new()
    training_target.name = "AlvoDeTreino"
    add_child(training_target)
    player.combat_target = training_target
    _place_target()
    var arguments = OS.get_cmdline_user_args()
    if "--qa-combat-only" in arguments:
        training_target.position += Vector3(8, 0, 0)
        await _qa()
        await _qa_combat()
        get_tree().quit()
    elif "--capture-combat-only" in arguments:
        await _capture_combat()


func _place_target() -> void:
    if not is_instance_valid(training_target):
        return
    training_target.global_position = player.global_position + player.avatar.global_basis.z * .70
    training_target.rotation.y = player.avatar.global_rotation.y
    training_target.reset()


func _interface() -> void:
    super._interface()
    var existing = panel.get_child(0)
    panel.remove_child(existing)
    var tabs = TabContainer.new()
    tabs.custom_minimum_size.x = 290
    panel.add_child(tabs)
    var column = VBoxContainer.new()
    column.name = "Combate R54"
    column.add_theme_constant_override("separation", 9)
    tabs.add_child(column)
    existing.name = "Movimento"
    tabs.add_child(existing)
    var title = Label.new()
    title.text = "Arroio · combate inicial"
    column.add_child(title)
    var help = Label.new()
    help.text = "WASD · mover     Shift · correr\nQ · guarda     E · bastão\nF · atacar     Espaço · empurrar\nEsc · cancelar / sair da guarda\nRoda · zoom     F1 · painel"
    column.add_child(help)
    _button(column, "Prontidão / repouso", player.toggle_guard)
    _button(column, "Equipar / guardar bastão", func():
        if not player.paused:
            player.combat.set_armed(not player.combat.armed))
    _button(column, "Atacar alvo de treino", func(): player.request_attack())
    _button(column, "Empurrar alvo", func(): player.request_attack("push"))
    _button(column, "Reposicionar alvo à frente", _place_target)
    var pause = CheckButton.new()
    pause.text = "Pausar animação"
    pause.toggled.connect(func(value: bool): player.paused = value)
    column.add_child(pause)
    _button(column, "Voltar ao ponto de teste", reset_player)
    var note = Label.new()
    note.text = "Bastão e alvo de treino\nImpactos locais de teste"
    column.add_child(note)
    var combat_status = Label.new()
    combat_status.name = "CombatStatus"
    column.add_child(combat_status)


func reset_player() -> void:
    super.reset_player()
    _place_target()


func _process(delta: float) -> void:
    super._process(delta)
    if not is_instance_valid(training_target):
        return
    var label = panel.find_child("CombatStatus", true, false)
    label.text = "%s\nImpactos %d" % [player.avatar.motion, training_target.impacts.size()]


func _qa_combat() -> void:
    reset_player()
    player.set_physics_process(false)
    await _wait_frames(2)
    var verifier = load("res://personagem/verificar_combate.gd").new()
    await verifier.run(player.avatar, player.action, player.combat, training_target)
    reset_player()
    player.set_physics_process(true)
    training_target.position += Vector3(8, 0, 0)
    assert(player.toggle_guard())
    player.command = Vector2.RIGHT
    await _wait_frames(20)
    assert(player.avatar.motion.begins_with("combat_") and player.is_on_floor())
    player.command = Vector2.ZERO
    await _wait_frames(10)
    _place_target()
    await _wait_frames(2)
    assert(player.request_attack("punch"))
    assert(not player.request_use("drink"))
    await _wait_frames(110)
    assert(training_target.impacts.size() == 1)
    assert(player.request_use("drink"))
    assert(not player.combat.guarding)
    player.action.cancel()
    player.scripted = false
    for keycode in [KEY_Q, KEY_E, KEY_F]:
        var key = InputEventKey.new()
        key.physical_keycode = keycode
        key.pressed = true
        Input.parse_input_event(key)
        await _wait_frames(2)
    assert(player.combat.armed and player.combat.is_attacking())
    player.combat.cancel()
    player.combat.set_guard(false)
    player.scripted = true
    FileAccess.open("res://qa/combate_interface_r54.json", FileAccess.WRITE).store_string(JSON.stringify({"guard_movement": true, "grounded": true, "attack_once": true, "consumption_exclusion": true, "keyboard_q_e_f": true}, "  "))
    print("ISOMETRIC_COMBAT_R54_QA_OK")


func _capture_combat() -> void:
    assert(DisplayServer.get_name() != "headless")
    player.set_physics_process(false)
    hud.visible = false
    zoom = 5
    var sequences: Dictionary = {}
    for kind in ["combat_forward", "push", "push_armed", "punch", "strike_onehand"]:
        reset_player()
        player.avatar.rotation.y += deg_to_rad(50)
        _place_target()
        player.avatar.set_appearance({"shirt_id": "camisa_xadrez_vinho"})
        player.combat.set_armed(kind in ["push_armed", "strike_onehand"])
        player.combat.set_guard(true)
        player.combat.advance(.3)
        if kind.begins_with("combat_"):
            player.avatar.set_motion(kind)
            player.avatar.motion_clock = 0
            player.avatar.motion_blend = 1
            player.avatar.advance(0)
        else:
            assert(player.request_attack("push" if kind == "push_armed" else kind))
            player.combat.advance(player.avatar.motion_transition_duration)
        var duration: float = player.avatar.player.get_animation(player.avatar.clips[kind]).length
        var frames = ceili((duration + .35) * 12) + 1
        var trace: Array = []
        focus = player.global_position + Vector3(0, .85, 0)
        _update_camera()
        for frame in frames:
            if frame > 0:
                player.combat.advance(1.0 / 12, Vector2(0, 1) if kind.begins_with("combat_") else Vector2.ZERO)
            trace.append({"time": frame / 12.0, "motion": player.avatar.motion, "state": player.combat.state, "impacts": training_target.impacts.size()})
            await _save_consumption("combate_r54/%s/%03d.png" % [kind, frame])
        sequences[kind] = {"frames": frames, "fps": 12, "trace": trace}
        if not kind.begins_with("combat_"):
            assert(training_target.impacts.size() == 1)
    reset_player()
    zoom = 8
    hud.visible = true
    await _wait_frames(2)
    await _save_consumption("combate_r54/interface.png")
    FileAccess.open("res://qa/combate_r54_capturas.json", FileAccess.WRITE).store_string(JSON.stringify(sequences, "  "))
    print("ISOMETRIC_COMBAT_R54_CAPTURE_OK")
    get_tree().quit()
