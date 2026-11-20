extends Node
var manager: Node3D
var scene: Node3D
var panel: PanelContainer
var launch: Button
var summary: Label
var buttons={}
var ranks={}
var opened=false
var last_points=-1
var close_button: Button

func setup(owner: Node3D) -> void:
    manager=owner;scene=manager.scene;process_priority=85
    launch=Button.new();launch.name="Skills102Button";launch.focus_mode=Control.FOCUS_NONE
    launch.pressed.connect(open);scene.game_ui.add_child(launch)
    panel=PanelContainer.new();panel.name="Skills102Panel";scene.game_ui.add_child(panel)
    var style=StyleBoxFlat.new();style.bg_color=Color("141b1afa");style.border_color=Color("d1ae75");style.set_border_width_all(1);style.set_content_margin_all(22)
    panel.add_theme_stylebox_override("panel",style)
    var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);panel.add_child(column)
    var title=Label.new();title.text="Habilidades de diálogo";title.add_theme_font_size_override("font_size",22);title.add_theme_color_override("font_color",Color("d1ae75"));column.add_child(title)
    var description=Label.new();description.text="Experiências diferentes geram aprendizado. Repetir o mesmo assunto não concede pontos.";description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(description)
    summary=Label.new();column.add_child(summary)
    for skill in manager.social.learning_rules.trainable:
        var row=HBoxContainer.new();row.add_theme_constant_override("separation",18);column.add_child(row)
        var info=VBoxContainer.new();info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(info)
        var rank=Label.new();rank.add_theme_font_size_override("font_size",16);info.add_child(rank);ranks[skill]=rank
        var detail=Label.new();detail.text=manager.social.learning_rules.descriptions[skill];detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_child(detail)
        var button=Button.new();button.text="Melhorar · 1 ponto";button.custom_minimum_size=Vector2(130,36);button.pressed.connect(func():train(skill));row.add_child(button);buttons[skill]=button
    close_button=Button.new();close_button.text="Fechar";close_button.pressed.connect(close);column.add_child(close_button)
    panel.visible=false;get_viewport().size_changed.connect(_layout)
    scene.player.reaction.started.connect(func(_kind):close());get_window().focus_exited.connect(close)
    _layout.call_deferred();refresh()

func _hint() -> String:
    var labels=[]
    for event in InputMap.action_get_events("character_skills"):
        if event is InputEventKey:labels.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode!=0 else event.keycode))
    return "/".join(labels) if not labels.is_empty() else "—"

func _layout() -> void:
    var right=476.0
    for control in scene.game_ui.find_children("*","Button",true,false):
        if control.text=="Carregar":right=control.get_global_rect().end.x;break
    launch.position=Vector2(right+12,12);launch.custom_minimum_size=Vector2(116,31)
    _fit_panel()

func _fit_panel() -> void:
    var viewport=get_viewport().get_visible_rect().size
    var height=minf(350+maxi(0,buttons.size()-2)*80,viewport.y-100)
    panel.size=Vector2(minf(540,viewport.x-40),height)
    panel.position=Vector2((viewport.x-panel.size.x)*.5,maxf(65,(viewport.y-panel.size.y)*.5))

func refresh() -> void:
    var model=manager.social;var points=model.available_points()
    launch.text=_hint()+"  Habilidades"+(" ("+str(points)+")" if points>0 else "")
    launch.tooltip_text="Desenvolver habilidades fora de conversas e ações."
    summary.text="Pontos disponíveis: %d   ·   Próximo ponto: %d/%d experiências"%[points,model.experience_progress(),model.learning_rules.experiences_per_point]
    for skill in buttons:
        var rank=int(model.data.skills[skill]);ranks[skill].text="%s · nível %d/6"%[model.config.skills[skill].label,rank]
        buttons[skill].disabled=points<=0 or rank>=6
        buttons[skill].tooltip_text="Nível máximo atingido." if rank>=6 else "Invista um ponto para aumentar esta habilidade."
    last_points=points

func ready_to_open() -> bool:
    return manager.call("ready") and manager.social.active.is_empty()

func open() -> bool:
    if opened or not ready_to_open() or not scene.player.set_hud_open(true):return false
    opened=true;panel.visible=true;scene.player.velocity=Vector3.ZERO;refresh();_layout()
    var focused=false
    for button in buttons.values():
        if not button.disabled:button.grab_focus();focused=true;break
    if not focused:close_button.grab_focus()
    return true

func close() -> void:
    if not opened:return
    opened=false;panel.visible=false
    var focus=get_viewport().gui_get_focus_owner()
    if focus!=null and (focus==launch or panel.is_ancestor_of(focus)):focus.release_focus()
    scene.game_ui.sync_lock()

func train(skill: String) -> bool:
    if not opened or scene.player.paused or scene.player.reaction.is_active() or not manager.social.train(skill):return false
    refresh();return true

func _process(_delta: float) -> void:
    if manager==null:return
    if manager.social.available_points()!=last_points:refresh()
    if not opened:return
    var p=scene.player
    if p.paused or p.reaction.is_active() or p.traversal.is_active() or scene.game_ui.personal.visible or scene.game_ui.nearby.visible or scene.game_ui.windows[1].visible:close()
    else:
        p.set_hud_open(true)
        # Wrapped labels settle their minimum height after becoming visible.
        # Fit again so the first opening never keeps the narrow initial height.
        _fit_panel()

func _input(event: InputEvent) -> void:
    if not opened:return
    if event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_RIGHT or (event.button_index==MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position)):get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_SPACE,KEY_R,KEY_E,KEY_Q,KEY_F]:get_viewport().set_input_as_handled()

func _shortcut_input(event: InputEvent) -> void:
    if event.is_action("character_skills"):
        get_viewport().set_input_as_handled()
        if event.is_action_pressed("character_skills",false):
            if opened:close()
            else:open()
        return
    if opened and event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode==KEY_ESCAPE:get_viewport().set_input_as_handled();close()
        elif event.physical_keycode in [KEY_I,KEY_H]:close()
