extends "res://isometric_base_r54.gd"


func _ready() -> void:
    await super._ready()
    var arguments = OS.get_cmdline_user_args()
    if "--qa-reactions-only" in arguments:
        training_target.position += Vector3(8, 0, 0)
        await _qa()
        await _qa_combat()
        await _qa_reactions()
        get_tree().quit()
    elif "--capture-reactions-only" in arguments:
        await _capture_reactions()


func _interface() -> void:
    super._interface()
    var tabs = panel.get_child(0)
    var column = VBoxContainer.new()
    column.name = "Reações"
    column.add_theme_constant_override("separation", 8)
    tabs.add_child(column)
    tabs.move_child(column, 0)
    tabs.current_tab = 0
    var title = Label.new()
    title.text = "R55 · Impacto e recuperação"
    column.add_child(title)
    var help = Label.new()
    help.text = "H · impacto     J · desequilíbrio\nK · cair     L · levantar     M · morrer"
    column.add_child(help)
    for entry in [["hit_front", "Impacto frontal"], ["hit_back", "Impacto pelas costas"], ["hit_left", "Impacto à esquerda"], ["hit_right", "Impacto à direita"], ["stagger", "Desequilíbrio"], ["fall", "Cair"], ["get_up", "Levantar"], ["death", "Morrer"]]:
        _button(column, entry[1], func(): player.request_reaction(entry[0]))
    var pause = CheckButton.new()
    pause.text = "Pausar animação"
    pause.toggled.connect(func(value: bool): player.paused = value)
    column.add_child(pause)
    _button(column, "Área livre de teste", _free_area)
    _button(column, "Reiniciar personagem", reset_player)
    var status_label = Label.new()
    status_label.name = "ReactionStatus"
    column.add_child(status_label)


func reset_player() -> void:
    if player != null and player.reaction != null:
        player.avatar.motion_paused = false
        player.reaction.reset()
        player.restore_collision()
    super.reset_player()


func _free_area() -> void:
    reset_player()
    player.global_position = spawn + Vector3(0, .03, -3)
    player.avatar.rotation.y += deg_to_rad(50)
    _place_target()
    focus = player.global_position + Vector3(0, .85, 0)
    _update_camera()


func _process(delta: float) -> void:
    super._process(delta)
    if not is_instance_valid(player) or player.reaction == null:
        return
    var label = panel.find_child("ReactionStatus", true, false)
    if label != null:
        label.text = "%s · %s\n%s" % [player.avatar.motion, player.reaction.state, player.reaction_message]


func _qa_reactions() -> void:
    reset_player()
    player.set_physics_process(false)
    await load("res://personagem/verificar_reacoes.gd").new().run(player.avatar, player.action, player.combat, player.reaction, training_target)
    player.set_physics_process(true)
    _free_area()
    await _wait_frames(20)
    assert(player.can_fall())
    var anchor: Vector3 = player.global_position
    assert(player.request_reaction("fall"))
    player.command = Vector2.RIGHT
    await _wait_frames(140)
    assert(player.reaction.state == "down" and player.is_on_floor())
    assert(Vector2(player.global_position.x - anchor.x, player.global_position.z - anchor.z).length() < .01)
    assert(absf(capsule_axis().y) < .01)
    assert(not player.request_use("drink") and not player.request_attack())
    var ceiling = StaticBody3D.new()
    var collision = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = Vector3(.6, .15, .6)
    collision.shape = shape
    ceiling.add_child(collision)
    add_child(ceiling)
    ceiling.global_position = player.global_position + Vector3.UP * 1.5
    await _wait_frames(2)
    assert(not player.request_reaction("get_up"))
    ceiling.queue_free()
    await _wait_frames(2)
    player.command = Vector2.ZERO
    assert(player.request_reaction("get_up"))
    await _wait_frames(210)
    assert(player.reaction.state == "idle" and player.is_on_floor())
    assert(absf(capsule_axis().y - 1) < .001)
    player.scripted = false
    var key = InputEventKey.new()
    key.physical_keycode = KEY_H
    key.pressed = true
    Input.parse_input_event(key)
    await _wait_frames(2)
    assert(player.reaction.kind == "hit_front" and player.reaction.is_active())
    player.scripted = true
    await _wait_frames(80)
    _free_area()
    await _wait_frames(20)
    assert(player.request_reaction("death"))
    await _wait_frames(160)
    assert(player.reaction.state == "dead" and player.is_on_floor())
    player.command = Vector2.RIGHT
    var before: Vector3 = player.global_position
    await _wait_frames(25)
    assert(player.global_position.distance_to(before) < .01)
    reset_player()
    assert(player.reaction.state == "idle" and not player.combat.control_locked)
    var root_index = player.avatar.skeleton.find_bone("Root")
    var root_pose = player.avatar.skeleton.get_bone_pose_rotation(root_index)
    var root_rest = player.avatar.skeleton.get_bone_rest(root_index).basis.get_rotation_quaternion()
    assert(root_pose.angle_to(root_rest) < .002)
    FileAccess.open("res://qa/reacoes_interface_r55.json", FileAccess.WRITE).store_string(JSON.stringify({"floor": true, "horizontal_down_collision": true, "standing_collision_restored": true, "blocked_recovery": true, "movement_lock": true, "dead_lock": true, "keyboard_h": true}, "  "))
    print("ISOMETRIC_REACTIONS_R55_QA_OK")


func capsule_axis() -> Vector3:
    return player.capsule.basis.y


func _capture_reactions() -> void:
    assert(DisplayServer.get_name() != "headless")
    player.set_physics_process(false)
    hud.visible = false
    training_target.visible = false
    zoom = 5
    var sequences: Dictionary = {}
    for id in ["hit_front", "hit_back", "hit_left", "hit_right", "stagger", "fall", "get_up", "death"]:
        _free_area()
        player.avatar.set_appearance({"shirt_id": "camisa_xadrez_vinho"})
        player.combat.set_armed(false)
        player.avatar.motion_clock = 0
        player.avatar.motion_blend = 1
        player.avatar.advance(0)
        if id == "get_up":
            assert(player.request_reaction("fall"))
            player.reaction.advance(4)
        assert(player.request_reaction(id))
        player.reaction.advance(player.avatar.motion_transition_duration)
        var duration: float = player.reaction.definitions[id].duration
        var frames = ceili((duration + .4) * 12) + 1
        var trace: Array = []
        focus = player.global_position + player.avatar.basis * Vector3(0, .70, -.65)
        _update_camera()
        for frame in frames:
            if frame > 0:
                if player.reaction.is_active():
                    player.reaction.advance(1.0 / 12)
                else:
                    player.action.advance(1.0 / 12)
            trace.append({"time": frame / 12.0, "state": player.reaction.state, "motion": player.avatar.motion})
            await _save_consumption("reacoes_r55/%s/%03d.png" % [id, frame])
        sequences[id] = {"frames": frames, "fps": 12, "trace": trace}
    _free_area()
    hud.visible = true
    zoom = 8
    await _wait_frames(2)
    await _save_consumption("reacoes_r55/interface.png")
    FileAccess.open("res://qa/reacoes_r55_capturas.json", FileAccess.WRITE).store_string(JSON.stringify(sequences, "  "))
    print("ISOMETRIC_REACTIONS_R55_CAPTURE_OK")
    get_tree().quit()
