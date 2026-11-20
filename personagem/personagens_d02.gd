extends "res://personagem/personagens99.gd"
## Presentation/input adapter. Existing R99 authority and persistence unchanged.
var view_d02: PanelContainer
var portraits_d02={}
var can_exit=true:
    set(value):
        can_exit=value
        if view_d02!=null:
            view_d02.set_exit_allowed(value)
            if not active.is_empty():view_d02.set_options(_options_d02())

func _interface() -> void:
    prompt=Label.new();prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;prompt.add_theme_font_size_override("font_size",15)
    prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;scene.game_ui.add_child(prompt);prompt.visible=false
    view_d02=load("res://personagem/dialogue_hud_d02.gd").new();scene.game_ui.add_child(view_d02)
    panel=view_d02;speaker=view_d02.name_label;speech=view_d02.legacy_line;options=view_d02.choices
    view_d02.choice_requested.connect(_choose_d02);view_d02.exit_requested.connect(request_exit_d02)
    view_d02.set_options(_options_d02())
    get_viewport().size_changed.connect(_layout);_layout()

func _layout() -> void:
    if view_d02==null:return
    view_d02.layout_panel();var viewport=get_viewport().get_visible_rect().size
    prompt.position=Vector2(20,viewport.y-82);prompt.size=Vector2(viewport.x-40,28)

func _options_d02() -> Array:
    return [{"id":"ask_origin","text":"Você é daqui?","available":true},{"id":"farewell","text":"Conversar depois","available":can_exit}]

func portrait_d02(id: String) -> Texture2D:
    if not portraits_d02.has(id):
        var viewport=load("res://personagem/retrato_d02.gd").new();add_child(viewport)
        viewport.configure(config.encounters[id].appearance,config.encounters[id].get("avatar_scene","res://personagem/personagem.tscn"));portraits_d02[id]=viewport
    return portraits_d02[id].get_texture()

func open(id: String) -> bool:
    if not super.open(id):return false
    view_d02.begin_session({"npc_id":id,"name":registry.definitions[id].name,"context":"Arroio das Figueiras","portrait":portrait_d02(id)},[{"speaker":registry.definitions[id].name,"text":speech.text,"kind":"npc"}],_options_d02(),can_exit)
    view_d02.select(0);return true

func _choose_d02(id: String) -> void:
    if active.is_empty() or not reachable(active):return
    if id=="ask_origin":
        view_d02.append_line({"speaker":"Você","text":"Você é daqui?","kind":"player"});_about()
    elif id=="farewell":request_exit_d02()

func _about() -> void:
    super._about()
    if not active.is_empty():view_d02.append_line({"speaker":registry.definitions[active].name,"text":speech.text,"kind":"npc"})

func request_exit_d02() -> void:
    if can_exit:close()

func close() -> void:
    super.close()
    if view_d02!=null:view_d02.hide_session()

func _input(event: InputEvent) -> void:
    if active.is_empty():return
    if event is InputEventKey or event is InputEventJoypadButton:
        for n in range(1,10):
            if event.is_action("dialogue_choice_"+str(n)):
                get_viewport().set_input_as_handled()
                if event.is_action_pressed("dialogue_choice_"+str(n),false):view_d02.request_choice(n-1)
                return
        for action in ["dialogue_previous","dialogue_next","dialogue_confirm","dialogue_exit"]:
            if not event.is_action(action):continue
            get_viewport().set_input_as_handled()
            if not event.is_action_pressed(action,false):return
            if action=="dialogue_previous":view_d02.move_selection(-1)
            elif action=="dialogue_next":view_d02.move_selection(1)
            elif action=="dialogue_confirm":view_d02.request_choice(view_d02.selected_index)
            else:request_exit_d02()
            return
        if event is InputEventKey and event.physical_keycode==KEY_SPACE:get_viewport().set_input_as_handled();return
    super._input(event)

func _shortcut_input(event: InputEvent) -> void:
    if not active.is_empty() and event is InputEventKey and event.physical_keycode==KEY_E:
        get_viewport().set_input_as_handled()
        if event.pressed and not event.echo:request_exit_d02()
        return
    if not active.is_empty() and not can_exit and event is InputEventKey and event.physical_keycode in [KEY_I,KEY_H]:
        get_viewport().set_input_as_handled();return
    super._shortcut_input(event)
