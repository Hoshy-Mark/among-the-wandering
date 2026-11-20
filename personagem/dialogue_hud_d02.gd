extends PanelContainer
signal choice_requested(option_id: String)
signal exit_requested
const CREAM=Color("f0e8d9")
const DIM=Color("afafa1")
const AMBER=Color("d1ae75")
var canvas: Control
var portrait: TextureRect
var portrait_frame: PanelContainer
var name_label: Label
var context_label: Label
var caption: Label
var close_button: Button
var history_heading: Label
var history_count: Label
var history_scroll: ScrollContainer
var transcript: VBoxContainer
var choices: VBoxContainer
var choice_scroll: ScrollContainer
var response_heading: Label
var footer: Label
var exit_hint: Label
var rules=[]
var legacy_line: Label
var current_options: Array=[]
var lines: Array=[]
var selected_index=-1
var history_scroll_revision=0
var npc_id=""
var exit_allowed=true
var ui_scale=1.0
var ui_font=SystemFont.new()
var prose_font=SystemFont.new()

func _ready() -> void:
    name="DialogueHUD_D02"
    ui_font.font_names=PackedStringArray(["Segoe UI","Noto Sans","DejaVu Sans"])
    prose_font.font_names=PackedStringArray(["Georgia","Noto Serif","Liberation Serif","DejaVu Serif"])
    theme=Theme.new();theme.default_font=ui_font;theme.default_font_size=15
    var style=StyleBoxFlat.new();style.bg_color=Color(.059,.094,.082,.98)
    style.border_color=Color(AMBER,.68);style.set_border_width_all(1)
    style.shadow_color=Color(0,0,0,.3);style.shadow_size=14
    add_theme_stylebox_override("panel",style)
    canvas=Control.new();canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(canvas)
    portrait_frame=PanelContainer.new();portrait_frame.clip_contents=true;canvas.add_child(portrait_frame)
    var frame=StyleBoxFlat.new();frame.bg_color=Color("344038");frame.border_color=Color(AMBER,.48);frame.set_border_width_all(1)
    portrait_frame.add_theme_stylebox_override("panel",frame)
    portrait=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;portrait_frame.add_child(portrait)
    caption=_label(canvas,"CONVERSA",10,AMBER)
    name_label=_label(canvas,"",28,CREAM,true);name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    context_label=_label(canvas,"Arroio das Figueiras",12,DIM)
    close_button=Button.new();close_button.text="×";close_button.flat=true;close_button.pressed.connect(func():exit_requested.emit());canvas.add_child(close_button)
    close_button.add_theme_font_size_override("font_size",24)
    for index in 4:
        var rule=ColorRect.new();rule.color=Color(.867,.827,.745,.23);rule.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(rule);rules.append(rule)
    history_heading=_label(canvas,"HISTÓRICO DA CONVERSA",10,DIM)
    history_count=_label(canvas,"0 FALAS",10,DIM);history_count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    history_scroll=ScrollContainer.new();history_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;canvas.add_child(history_scroll)
    history_scroll.gui_input.connect(_history_input)
    history_scroll.get_v_scroll_bar().gui_input.connect(_history_input)
    transcript=VBoxContainer.new();transcript.size_flags_horizontal=Control.SIZE_EXPAND_FILL;transcript.add_theme_constant_override("separation",24);history_scroll.add_child(transcript)
    response_heading=_label(canvas,"SUA RESPOSTA",10,AMBER)
    choice_scroll=ScrollContainer.new();choice_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;canvas.add_child(choice_scroll)
    choices=VBoxContainer.new();choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choices.add_theme_constant_override("separation",4);choice_scroll.add_child(choices)
    footer=_label(canvas,"",11,DIM);exit_hint=_label(canvas,"",11,DIM);exit_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    legacy_line=Label.new();legacy_line.visible=false;canvas.add_child(legacy_line)
    get_viewport().size_changed.connect(layout_panel);layout_panel();visible=false

func _label(parent: Node,text: String,pixels: int,color: Color,serif: bool=false) -> Label:
    var label=Label.new();label.text=text;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_override("font",prose_font if serif else ui_font)
    label.add_theme_font_size_override("font_size",pixels);label.add_theme_color_override("font_color",color);parent.add_child(label)
    label.set_meta("base_size",pixels);return label

func _place(control: Control,rect: Rect2) -> void:
    control.position=rect.position*ui_scale;control.size=rect.size*ui_scale

func layout_panel() -> void:
    if canvas==null:return
    var history_bar=history_scroll.get_v_scroll_bar()
    var followed=history_bar.value>=history_bar.max_value-history_bar.page-12
    var viewport=get_viewport().get_visible_rect().size
    ui_scale=clampf(minf(viewport.x/1280,viewport.y/720),.85,1.5)
    var margin=35*ui_scale;var width=minf(410*ui_scale,viewport.x-32)
    position=Vector2(viewport.x-margin-width,65*ui_scale)
    size=Vector2(width,viewport.y-position.y-36*ui_scale)
    var w=width/ui_scale;var h=size.y/ui_scale
    theme.default_font_size=roundi(15*ui_scale)
    _place(portrait_frame,Rect2(26,22,78,88))
    _place(caption,Rect2(121,25,w-152,18));_place(name_label,Rect2(121,46,w-147,38));_place(context_label,Rect2(121,87,w-147,20))
    _place(close_button,Rect2(w-44,12,30,32))
    _place(rules[0],Rect2(26,130,w-52,1));_place(history_heading,Rect2(26,141,w-150,25));_place(history_count,Rect2(w-116,141,90,25));_place(rules[1],Rect2(26,169,w-52,1))
    var available_width=(w-52)*ui_scale
    var desired=0.0
    for button in choices.get_children():
        var row=button.get_meta("row");var height=_choice_height(str(row.text),available_width-14*ui_scale)
        button.custom_minimum_size.y=height;desired+=height+4*ui_scale
        var number: Label=button.get_child(0);var text: Label=button.get_child(1)
        number.position=Vector2(18,11)*ui_scale;number.size=Vector2(30,24)*ui_scale
        text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        text.offset_left=55*ui_scale;text.offset_top=12*ui_scale;text.offset_right=-16*ui_scale;text.offset_bottom=-12*ui_scale
    var choice_height=clampf(desired/ui_scale,92,minf(210,h*.34))
    var footer_top=h-49;var choices_top=footer_top-16-choice_height
    _place(choice_scroll,Rect2(26,choices_top,w-52,choice_height))
    _place(rules[2],Rect2(26,choices_top-36,w-52,1));_place(response_heading,Rect2(26,choices_top-28,w-52,22))
    _place(history_scroll,Rect2(26,188,w-52,maxf(40,choices_top-242)))
    _place(rules[3],Rect2(26,footer_top,w-52,1))
    _place(footer,Rect2(26,footer_top+11,w-155,24));_place(exit_hint,Rect2(w-126,footer_top+11,100,24))
    for label in canvas.find_children("*","Label",true,false):
        if label.has_meta("base_size"):label.add_theme_font_size_override("font_size",roundi(int(label.get_meta("base_size"))*ui_scale))
    transcript.add_theme_constant_override("separation",roundi(24*ui_scale))
    refresh_hints()
    if followed:_follow_history(true,history_bar.value)

func _choice_height(text: String,width: float) -> float:
    return maxf(46*ui_scale,ui_font.get_multiline_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,maxf(80,width-70*ui_scale),roundi(15*ui_scale)).y+24*ui_scale)

func _action_hint(action: String) -> String:
    var hints=[]
    for event in InputMap.action_get_events(action):
        if event is InputEventKey:
            var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
            hints.append({KEY_UP:"↑",KEY_DOWN:"↓",KEY_ESCAPE:"Esc",KEY_ENTER:"Enter",KEY_KP_ENTER:"Enter"}.get(code,OS.get_keycode_string(code)))
        elif event is InputEventJoypadButton:hints.append("J%d"%event.button_index)
    return "/".join(hints) if not hints.is_empty() else "—"

func refresh_hints() -> void:
    var count=mini(current_options.size(),9);var first=_action_hint("dialogue_choice_1")
    var last=_action_hint("dialogue_choice_"+str(maxi(count,1)))
    footer.text=(first if count<=1 else first+"–"+last)+"  Selecionar resposta"
    exit_hint.text=_action_hint("dialogue_exit")+"  "+("Sair" if exit_allowed else "Indisponível")

func begin_session(header: Dictionary,initial_lines: Array,options: Array,can_exit: bool=true) -> void:
    npc_id=str(header.npc_id);name_label.text=str(header.name);context_label.text=str(header.get("context","Arroio das Figueiras"))
    portrait.texture=header.get("portrait");clear_history()
    for line in initial_lines:append_line(line)
    set_options(options);set_exit_allowed(can_exit);visible=true
    if selected_index>=0:select(selected_index)

func clear_history() -> void:
    history_scroll_revision+=1
    lines.clear()
    for row in transcript.get_children():transcript.remove_child(row);row.queue_free()
    history_scroll.scroll_vertical=0;history_count.text="0 FALAS"

func append_line(line: Dictionary) -> void:
    var bar=history_scroll.get_v_scroll_bar();var previous=bar.value
    var follow=previous>=bar.max_value-bar.page-12
    lines.append(line.duplicate(true))
    var row=PanelContainer.new();row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var box=StyleBoxFlat.new();box.bg_color=Color.TRANSPARENT;box.border_color=AMBER if line.get("kind","npc")=="npc" else Color(.79,.76,.69,.37)
    box.border_width_left=2;box.content_margin_left=16*ui_scale;row.add_theme_stylebox_override("panel",box)
    var body=VBoxContainer.new();body.add_theme_constant_override("separation",7);row.add_child(body)
    _label(body,str(line.get("speaker"," ")).to_upper(),10,AMBER if line.get("kind","npc")=="npc" else DIM)
    var prose=_label(body,str(line.text),19,CREAM if line.get("kind","npc")=="npc" else Color("d0cbbf"),true)
    prose.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;prose.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    transcript.add_child(row);history_count.text="%d %s"%[lines.size(),"FALA" if lines.size()==1 else "FALAS"];layout_panel()
    _follow_history(follow,previous)

func _history_input(event: InputEvent) -> void:
    var manual=false
    if event is InputEventMouseButton:manual=event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_LEFT]
    elif event is InputEventMouseMotion:manual=(event.button_mask & MOUSE_BUTTON_MASK_LEFT)!=0
    elif event is InputEventScreenDrag:manual=true
    elif event is InputEventKey:manual=event.pressed
    if manual:history_scroll_revision+=1

func _follow_history(follow: bool,_previous: float) -> void:
    if not follow:return
    var revision=history_scroll_revision
    await get_tree().process_frame;await get_tree().process_frame
    if not is_inside_tree() or revision!=history_scroll_revision:return
    # Layout clamping is not a reader scroll. Only actual input cancels follow.
    history_scroll.scroll_vertical=roundi(history_scroll.get_v_scroll_bar().max_value)

func set_options(rows: Array) -> void:
    var history_bar=history_scroll.get_v_scroll_bar()
    var followed=history_bar.value>=history_bar.max_value-history_bar.page-12
    current_options=rows.duplicate(true);selected_index=-1
    for child in choices.get_children():choices.remove_child(child);child.queue_free()
    for index in current_options.size():
        var row=current_options[index];var button=Button.new();button.set_meta("row",row)
        button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.disabled=not bool(row.get("available",true))
        button.focus_mode=Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
        choices.add_child(button)
        var number=_label(button,_action_hint("dialogue_choice_"+str(index+1)) if index<9 else str(index+1),18,AMBER,true)
        var text=_label(button,str(row.text),15,CREAM);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        if button.disabled:number.modulate.a=.45;text.modulate.a=.45
        button.pressed.connect(func():request_choice(index))
        button.focus_entered.connect(func():select(index,false))
        button.mouse_entered.connect(func():select(index))
        _choice_style(button,false)
    layout_panel();move_selection(1)
    if followed:_follow_history(true,history_bar.value)

func _choice_style(button: Button,selected: bool) -> void:
    var style=StyleBoxFlat.new();style.bg_color=Color(.76,.64,.43,.12) if selected else Color.TRANSPARENT
    style.border_color=AMBER if selected else Color.TRANSPARENT;style.set_border_width_all(1);style.set_corner_radius_all(2)
    button.add_theme_stylebox_override("normal",style);button.add_theme_stylebox_override("hover",style)
    button.add_theme_stylebox_override("pressed",style);button.add_theme_stylebox_override("disabled",style)
    var focus=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=AMBER;focus.set_border_width_all(1);focus.set_corner_radius_all(2)
    button.add_theme_stylebox_override("focus",focus)

func select(index: int,grab: bool=true) -> void:
    if index<0 or index>=current_options.size() or not current_options[index].get("available",true):return
    selected_index=index
    for n in choices.get_child_count():_choice_style(choices.get_child(n),n==index)
    if grab and is_visible_in_tree():choices.get_child(index).grab_focus()
    call_deferred("_ensure_selected")

func _ensure_selected() -> void:
    if selected_index>=0 and selected_index<choices.get_child_count():choice_scroll.ensure_control_visible(choices.get_child(selected_index))

func move_selection(direction: int) -> void:
    if current_options.is_empty():return
    var start=selected_index
    if start<0:start=-1 if direction>0 else 0
    for offset in range(1,current_options.size()+1):
        var index=posmod(start+offset*direction,current_options.size())
        if current_options[index].get("available",true):select(index);return

func request_choice(index: int) -> void:
    if index<0 or index>=current_options.size() or not current_options[index].get("available",true):return
    select(index);choice_requested.emit(str(current_options[index].id))

func set_exit_allowed(value: bool) -> void:
    exit_allowed=value;close_button.disabled=not value;refresh_hints()

func hide_session() -> void:
    visible=false
    var owner=get_viewport().gui_get_focus_owner()
    if owner!=null and is_ancestor_of(owner):owner.release_focus()
