extends "res://isometric_base_r57.gd"


func _ready() -> void:
    await super._ready()
    var arguments = OS.get_cmdline_user_args()
    if "--qa-states" in arguments:
        training_target.position += Vector3(8,0,0)
        for fixture in fixtures.values():
            fixture.position += Vector3(30,0,0)
        await load("res://personagem/verificar_estados.gd").new().run(player,spawn+Vector3(0,.03,-3))
        print("ISOMETRIC_STATES_R58_QA_OK")
        get_tree().quit()
    elif "--capture-states" in arguments:
        await _capture_states()


func _interface() -> void:
    super._interface()
    var tabs = panel.get_child(0)
    var column = VBoxContainer.new()
    column.name = "Condição"
    column.add_theme_constant_override("separation",9)
    tabs.add_child(column)
    tabs.move_child(column,0)
    tabs.current_tab = 0
    var title = Label.new()
    title.text = "R58 · Lesão e cansaço"
    column.add_child(title)
    var help = Label.new()
    help.text = "Escolha a condição e use WASD.\nShift solicita corrida. Lesão mantém o mancar."
    column.add_child(help)
    for entry in [["normal","Normal"],["injured_left","Perna esquerda ferida"],["injured_right","Perna direita ferida"],["tired","Cansado"]]:
        _button(column,entry[1],func(): player.set_movement_condition(entry[0]))
    for entry in [["injured_idle","Repouso ferido"],["tired_idle","Recuperar o fôlego"]]:
        _button(column,entry[1],func(): player.set_preview(entry[0]))
    _button(column,"Área livre de teste",_free_area)
    var pause = CheckButton.new()
    pause.text = "Pausar"
    pause.toggled.connect(func(value: bool): player.paused=value)
    column.add_child(pause)


func reset_player() -> void:
    super.reset_player()
    if player != null:
        player.movement_condition = "normal"


func _capture_states() -> void:
    player.scripted = true
    player.set_physics_process(false)
    hud.visible = false
    training_target.visible = false
    zoom = 4.5
    for fixture in fixtures.values():
        fixture.position += Vector3(30,0,0)
    var metadata: Dictionary = {}
    var conditions = {"injured_idle":"injured_left","limp_left":"injured_left","limp_right":"injured_right","tired_idle":"tired","tired_walk":"tired","tired_run":"tired"}
    for id in player.avatar.state_motion.definitions:
        _free_area()
        training_target.position += Vector3(20,0,0)
        assert(player.set_movement_condition(conditions[id]))
        player.command = Vector2.ZERO if id.ends_with("idle") else Vector2(0,1)
        player.command_run = id == "tired_run"
        player.velocity = Vector3.ZERO
        player.avatar.set_appearance({"shirt_id":"camisa_xadrez_vinho"})
        player.avatar.set_motion(id)
        player.avatar.motion_clock = 0
        player.avatar.motion_blend = 1
        player.avatar.rotation.y = atan2(camera.global_basis.z.x,camera.global_basis.z.z)
        player.avatar.advance(0)
        var count = ceili(player.avatar.state_motion.definitions[id].duration*2*12)+1
        var trace: Array = []
        player.set_physics_process(true)
        for frame in count:
            if frame > 0:
                await _wait_frames(5)
            focus = player.global_position+Vector3.UP*.95
            _update_camera()
            await _save_consumption("estados_r58/%s/%03d.png" % [id,frame])
            trace.append({"time":frame/12.0,"clock":player.avatar.motion_clock,"motion":player.avatar.motion,"speed":Vector2(player.velocity.x,player.velocity.z).length(),"position":[player.position.x,player.position.y,player.position.z]})
        player.set_physics_process(false)
        player.command = Vector2.ZERO
        assert(player.avatar.motion == id)
        metadata[id] = {"frames":count,"fps":12,"trace":trace}
    FileAccess.open("res://qa/estados_r58_capturas.json",FileAccess.WRITE).store_string(JSON.stringify(metadata,"  "))
    print("ISOMETRIC_STATES_R58_CAPTURED")
    get_tree().quit()
