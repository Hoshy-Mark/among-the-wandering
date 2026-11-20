extends Node
var manager: Node3D
var scene: Node3D
var panel: PanelContainer
var launch: Button
var opened=false
var tab=0
var selected="persuasion"
var selected_npc=""
var selected_place=""
var category=0
var capture=""
var draft={}
var buttons={}
var ranks={}
var last_points=-1
var content: VBoxContainer
var title: Label
var tabs=[]
var layer: CanvasLayer
var shade: ColorRect
var preferences=preload("res://personagem/menu107/preferences.gd").new()
var exploration=preload("res://personagem/menu107/exploration.gd").new()
var projection=preload("res://personagem/menu107/projection.gd")
var map_view: Control
var map_center=Vector2.ZERO
var map_zoom=7.0
var map_filter=0
var legend=true
var modal: ConfirmationDialog
var video: ConfirmationDialog
var video_seconds=0.0
var title_font=preload("res://personagem/menu107/title.tres")
var amber=Color("c6ad75")
var muted=Color("9ba99a")
var timer=0.0
var settings_footer: BoxContainer
var settings_host: VBoxContainer
func style(color: String,border: String="364237",margin: int=12) -> StyleBoxFlat:
    var box=StyleBoxFlat.new();box.bg_color=Color(color);box.border_color=Color(border);box.set_border_width_all(1);box.set_content_margin_all(margin);return box
func label(parent: Node,text: String,font_size: int=15,color: Color=Color("e1e0d1"),serif: bool=false) -> Label:
    var value=Label.new();value.text=text;value.add_theme_font_size_override("font_size",font_size);value.add_theme_color_override("font_color",color)
    if serif:value.add_theme_font_override("font",title_font)
    value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(value);return value
func button(parent: Node,text: String,callback: Callable,active: bool=false) -> Button:
    var value=Button.new();value.text=text;value.custom_minimum_size.y=38;value.pressed.connect(callback)
    value.add_theme_stylebox_override("normal",style("303827" if active else "1b261e","bda36a" if active else "354135"))
    value.add_theme_color_override("font_color",amber if active else muted);parent.add_child(value);return value
func horizontal(parent: Node,gap: int=18) -> HBoxContainer:
    var row=HBoxContainer.new();row.add_theme_constant_override("separation",gap);parent.add_child(row);return row
func column(parent: Node,expand: bool=true) -> VBoxContainer:
    var col=VBoxContainer.new();col.add_theme_constant_override("separation",14)
    if expand:col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;col.size_flags_vertical=Control.SIZE_EXPAND_FILL
    parent.add_child(col);return col
func section(parent: Node,text: String) -> Label:return label(parent,text,12,amber)
func setup(owner: Node3D) -> void:
    manager=owner;scene=owner.scene;process_priority=85
    exploration.setup(scene)
    if "--menu107-test" in OS.get_cmdline_user_args():preferences.path="res://qa/menu107/preferences.json"
    preferences.setup();draft=preferences.applied.duplicate(true)
    layer=CanvasLayer.new();layer.layer=45;scene.add_child(layer)
    var root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root)
    var theme=Theme.new();theme.default_font=preload("res://personagem/menu107/body.tres");theme.default_font_size=14
    theme.set_stylebox("hover","Button",style("303b2a","69745b"));var focus=StyleBoxFlat.new();focus.bg_color=Color(0,0,0,0);focus.border_color=Color("8c9a81");focus.set_border_width_all(1);theme.set_stylebox("focus","Button",focus);root.theme=theme
    shade=ColorRect.new();shade.color=Color(0.03,.05,.025,.65);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(shade)
    panel=PanelContainer.new();panel.name="MenuM03M07";panel.add_theme_stylebox_override("panel",style("131e17fa","646c53",0));root.add_child(panel)
    var shell=column(panel);shell.add_theme_constant_override("separation",0)
    var header=horizontal(shell);header.custom_minimum_size.y=64
    var margin=MarginContainer.new();margin.add_theme_constant_override("margin_left",36);margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(margin)
    title=label(margin,"Habilidades",30,Color("e5e2d4"),true)
    var close_button=button(header,"×",close);close_button.custom_minimum_size.x=65
    shell.add_child(HSeparator.new())
    var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;shell.add_child(scroll)
    var inner=MarginContainer.new();inner.size_flags_horizontal=Control.SIZE_EXPAND_FILL;inner.add_theme_constant_override("margin_left",28);inner.add_theme_constant_override("margin_right",28);inner.add_theme_constant_override("margin_top",20);inner.add_theme_constant_override("margin_bottom",16);scroll.add_child(inner)
    content=column(inner)
    settings_host=column(shell,false)
    var bottom=horizontal(shell,0);bottom.custom_minimum_size.y=76
    for index in range(4):
        var b=button(bottom,["▤\nHabilidades","♙\nPersonagens","◇\nMapa","☷\nConfigurações"][index],select_tab.bind(index));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tabs.append(b)
    launch=Button.new();launch.text="P  Menu";launch.custom_minimum_size=Vector2(100,31);launch.position=Vector2(490,12);launch.pressed.connect(open);scene.game_ui.add_child(launch)
    modal=ConfirmationDialog.new();modal.title="Alterações pendentes";modal.dialog_text="Descartar alterações?";modal.ok_button_text="Descartar";modal.cancel_button_text="Continuar editando";modal.confirmed.connect(func():draft=preferences.applied.duplicate(true);_close());root.add_child(modal)
    video=ConfirmationDialog.new();video.title="Configuração de vídeo";video.ok_button_text="Manter";video.cancel_button_text="Reverter";video.confirmed.connect(_confirm_video);video.canceled.connect(_rollback_video);root.add_child(video)
    shade.visible=false;panel.visible=false;get_viewport().size_changed.connect(_layout);_layout();refresh()
    scene.player.reaction.started.connect(func(_kind):force_close())
func _hint() -> String:
    var keys=[]
    for event in InputMap.action_get_events("character_skills"):
        if event is InputEventKey:keys.append(OS.get_keycode_string(event.physical_keycode))
    return "/".join(keys)
func _layout() -> void:
    if panel==null:return
    var size=get_viewport().get_visible_rect().size
    panel.position=Vector2(maxf(8,(size.x-1050)*.5),maxf(8,(size.y-632)*.5));panel.size=Vector2(minf(size.x-16,1050),minf(size.y-16,632))
    for b in tabs:
        b.add_theme_font_size_override("font_size",11 if size.x<700 else 14)
        b.add_theme_constant_override("outline_size",0)
    if opened:refresh()
func ready_to_open() -> bool:return manager.call("ready") and manager.social.active.is_empty()
func open() -> bool:
    if opened or not ready_to_open() or not scene.player.set_hud_open(true):return false
    opened=true;shade.show();panel.show();scene.player.velocity=Vector3.ZERO;refresh();tabs[tab].grab_focus();return true
func close() -> void:
    if not opened:return
    if video_seconds>0:return
    if draft!=preferences.applied:modal.popup_centered(Vector2i(370,150));return
    _close()
func _close() -> void:
    opened=false;shade.hide();panel.hide();modal.hide();capture="";scene.game_ui.sync_lock()
func force_close() -> void:
    if video_seconds>0:_rollback_video()
    draft=preferences.applied.duplicate(true);_close()
func select_tab(index: int) -> void:
    if map_view!=null and is_instance_valid(map_view):map_center=map_view.center;map_zoom=map_view.zoom
    tab=index;refresh()
func refresh() -> void:
    if content==null:return
    for child in content.get_children():content.remove_child(child);child.queue_free()
    for child in settings_host.get_children():settings_host.remove_child(child);child.queue_free()
    settings_footer=VBoxContainer.new() if get_viewport().get_visible_rect().size.x<700 else HBoxContainer.new();settings_footer.add_theme_constant_override("separation",8);settings_host.add_child(settings_footer)
    settings_host.visible=tab==3
    map_view=null;buttons.clear();ranks.clear()
    last_points=manager.social.available_points();launch.text=_hint()+"  Menu"
    title.text=["Habilidades","Personagens","Mapa","Configurações"][tab]
    for index in range(4):
        var tab_style=style("2c3527" if index==tab else "1a251e","354135",5);tab_style.border_width_top=2 if index==tab else 1
        if index==tab:tab_style.border_color=amber
        tabs[index].add_theme_stylebox_override("normal",tab_style);tabs[index].add_theme_color_override("font_color",amber if index==tab else muted)
    if tab==0:_skills()
    elif tab==1:_characters()
    elif tab==2:_map()
    else:_settings()
func split(ratio: float=.54) -> Array:
    var narrow=get_viewport().get_visible_rect().size.x<700
    var row: BoxContainer=VBoxContainer.new() if narrow else HBoxContainer.new();row.add_theme_constant_override("separation",38);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(row)
    var left=column(row);var right=column(row);left.size_flags_stretch_ratio=ratio;right.size_flags_stretch_ratio=1-ratio
    if not narrow:left.custom_minimum_size.y=380
    return [left,right]
func _skills() -> void:
    var halves=split();var model=manager.social
    var symbols=["▱","◎","♡","♧"];var index=0
    for skill in model.learning_rules.trainable:
        var rank=int(model.data.skills[skill]);var entry=PanelContainer.new();var entry_style=style("293222" if skill==selected else "162119","bba36c" if skill==selected else "344032",10);entry.add_theme_stylebox_override("panel",entry_style);halves[0].add_child(entry)
        var row=VBoxContainer.new();row.add_theme_constant_override("separation",5);entry.add_child(row)
        var b=button(row,"%s    %s                         %d/6"%[symbols[index],model.config.skills[skill].label,rank],func():selected=skill;refresh(),skill==selected);b.add_theme_stylebox_override("normal",StyleBoxEmpty.new());b.add_theme_font_size_override("font_size",16);b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.custom_minimum_size.y=28;buttons[skill]=b
        var cells=horizontal(row,5)
        for cell in range(6):
            var rect=ColorRect.new();rect.color=amber if cell<rank else Color("344237");rect.custom_minimum_size=Vector2(20,7);rect.size_flags_horizontal=Control.SIZE_EXPAND_FILL;cells.add_child(rect)
        index+=1
    var space=Control.new();space.size_flags_vertical=Control.SIZE_EXPAND_FILL;halves[0].add_child(space)
    label(halves[0],"Experiências   %d/3    %s"%[model.experience_progress(),"▪ ".repeat(model.experience_progress())+"▫ ".repeat(3-model.experience_progress())],13,muted)
    label(halves[1],"%d ponto%s disponíve%s"%[model.available_points(),"s" if model.available_points()!=1 else "","is" if model.available_points()!=1 else "l"],18,amber)
    section(halves[1],"N Í V E L   %d / 6"%int(model.data.skills[selected]))
    label(halves[1],model.config.skills[selected].label,32,amber,true)
    label(halves[1],model.learning_rules.descriptions[selected],16)
    var improve=button(halves[1],"Melhorar · 1 ponto",func():train(selected),true);improve.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;improve.disabled=model.available_points()<=0 or int(model.data.skills[selected])>=6
func train(skill: String) -> bool:
    if not opened or scene.player.paused or scene.player.reaction.is_active() or not manager.social.train(skill):return false
    refresh();return true
func _characters() -> void:
    var rows=projection.characters(manager)
    if rows.is_empty():label(content,"Nenhum personagem conhecido.",16,muted);return
    if not rows.any(func(row):return row.id==selected_npc):selected_npc=rows[0].id
    var halves=split(.25);var current={}
    for row in rows:
        button(halves[0],row.name+"\n"+row.bond,func():selected_npc=row.id;refresh(),row.id==selected_npc)
        if row.id==selected_npc:current=row
    var top=horizontal(halves[1]);var portrait=TextureRect.new();portrait.texture=manager.portrait_d02(selected_npc);portrait.custom_minimum_size=Vector2(70,90);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;top.add_child(portrait)
    var info=column(top);label(info,current.name,26,amber,true);label(info,"Arroio das Figueiras",13,muted);label(info,current.life+"    ·    "+current.bond,12)
    halves[1].add_child(HSeparator.new());var detail=horizontal(halves[1]);var bio=column(detail);var relations=column(detail)
    section(bio,"B I O G R A F I A");label(bio," ".join(current.biography) if not current.biography.is_empty() else "Encontrado em Arroio das Figueiras.",15,Color("e1e0d1"),true)
    section(relations,"RELAÇÃO COM VOCÊ")
    for dimension in current.relationship:label(relations,dimension+"                         —",13,muted)
    halves[1].add_child(HSeparator.new());var bottom=horizontal(halves[1]);var secrets=column(bottom);var events=column(bottom)
    section(secrets,"SEGREDOS CONHECIDOS");label(secrets,"Nenhum segredo descoberto.",13,muted);section(events,"EVENTOS IMPORTANTES");label(events,"Nenhum evento importante registrado.",13,muted)
func _map() -> void:
    var halves=split(.77)
    map_view=preload("res://personagem/menu107/map_canvas.gd").new();map_view.survey=exploration;map_view.size_flags_vertical=Control.SIZE_EXPAND_FILL;halves[0].add_child(map_view)
    map_view.center=exploration.position if map_center==Vector2.ZERO else map_center;map_view.zoom=map_zoom;map_view.selected=selected_place
    map_view.picked.connect(func(id):selected_place=id;map_center=map_view.center;map_zoom=map_view.zoom;refresh())
    var tools=horizontal(halves[0],5);button(tools,"+",func():map_view.set_zoom(map_view.zoom*1.2));button(tools,"−",func():map_view.set_zoom(map_view.zoom/1.2));button(tools,"Centrar",func():map_view.focus_player());button(tools,"Legenda "+("−" if legend else "+"),func():legend=not legend;map_center=map_view.center;map_zoom=map_view.zoom;refresh())
    if legend:label(halves[0],"◉ Você está aqui   ◇ Descoberto   ◆ Visitado   ◇ Marcado\n━ Estrada   ┄ Trilha   ▣ Área urbana   ▧ Água   ▨ Não mapeado",11,muted)
    label(halves[1],"Locais",21,Color("e5dfc8"),true);var filters=horizontal(halves[1],2)
    for i in range(3):button(filters,["Todos","Visitados","Marcados"][i],func():map_filter=i;map_center=map_view.center;map_zoom=map_view.zoom;refresh(),i==map_filter)
    var known=exploration.known()
    for row in known:
        if map_filter==1 and not row.visited or map_filter==2 and not row.marked:continue
        button(halves[1],row.name+"\n"+("Visitado" if row.visited else "Descoberto")+(" · Marcado" if row.marked else ""),func():selected_place=row.id;map_center=map_view.center;map_zoom=map_view.zoom;refresh(),row.id==selected_place)
    if known.is_empty():label(halves[1],"Nenhum local descoberto.",13,muted)
    if selected_place!="" and known.any(func(row):return row.id==selected_place):button(halves[1],"Desmarcar" if selected_place in exploration.data.marked else "Marcar local",func():exploration.mark(selected_place);map_center=map_view.center;map_zoom=map_view.zoom;refresh())
func dirty() -> bool:return draft!=preferences.applied
func _settings() -> void:
    var cat_scroll=ScrollContainer.new();cat_scroll.custom_minimum_size.y=44;cat_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(cat_scroll)
    var categories=horizontal(cat_scroll,4)
    for index in range(5):button(categories,["Vídeo","Áudio","Controles","Interface","Acessibilidade"][index],func():category=index;refresh(),category==index)
    if category==0:
        _option("Modo de tela","mode",["Janela","Tela cheia","Janela sem bordas"])
        _option("Resolução","resolution",["1280 × 720","1600 × 900","1920 × 1080"])
        var row=horizontal(content);label(row,"Sincronização vertical").size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var check=CheckButton.new();check.button_pressed=draft.vsync;check.toggled.connect(func(value):draft.vsync=value;refresh());row.add_child(check)
        _option("Limite de quadros","fps",["Ilimitado","30","60","120"],[0,30,60,120])
    elif category==1:
        var row=horizontal(content);label(row,"Volume geral").size_flags_horizontal=Control.SIZE_EXPAND_FILL
        var slider=HSlider.new();slider.min_value=0;slider.max_value=100;slider.value=draft.volume;slider.custom_minimum_size.x=180;row.add_child(slider)
        var amount=label(row,str(int(draft.volume))+"%")
        slider.value_changed.connect(func(value):draft.volume=value;amount.text=str(int(value))+"%";_update_footer())
    elif category==2:
        for action in preferences.actions:
            var row=horizontal(content);label(row,{"character_skills":"Menu","weapon_quick_up":"Arma longa","weapon_quick_left":"Arma curta","weapon_quick_right":"Arma branca","weapon_quick_down":"Arremessável","weapon_quick_consult":"Consultar atalhos"}[action]).size_flags_horizontal=Control.SIZE_EXPAND_FILL
            var names=[]
            for code in draft.bindings[action]:names.append(OS.get_keycode_string(int(code)))
            button(row,"Pressione uma tecla…" if capture==action else " / ".join(names),func():capture=action;refresh())
        label(content,"WASD · mover    Shift · correr    E · interagir    I · inventário    R · recarregar\nComandos fixos nesta versão.",12,muted)
    else:label(content,"Nenhuma opção disponível nesta versão.",15,muted)
    var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(spacer)
    var footer=settings_footer;var state=label(footer,"Alterações não aplicadas" if dirty() else "Sem alterações",13,amber if dirty() else muted);state.name="PreferenceStatus";state.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    button(footer,"Padrão",func():draft=preferences.defaults.duplicate(true);refresh());button(footer,"Desfazer",func():draft=preferences.applied.duplicate(true);capture="";refresh());var apply=button(footer,"Aplicar",apply_preferences,true);apply.name="ApplyPreferences";apply.disabled=not dirty()
func _update_footer() -> void:
    var state=settings_footer.find_child("PreferenceStatus",true,false);var apply=settings_footer.find_child("ApplyPreferences",true,false)
    if state!=null:state.text="Alterações não aplicadas" if dirty() else "Sem alterações"
    if apply!=null:apply.disabled=not dirty()
func _option(text: String,key: String,items: Array,values: Array=[]) -> void:
    var row=horizontal(content);label(row,text).size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var option=OptionButton.new();option.custom_minimum_size=Vector2(180,36)
    for item in items:option.add_item(item)
    option.selected=values.find(int(draft[key])) if not values.is_empty() else int(draft[key]);option.item_selected.connect(func(index):draft[key]=values[index] if not values.is_empty() else index;refresh());row.add_child(option)
func apply_preferences() -> void:
    var result=preferences.apply(draft)
    if result=="video":video_seconds=15;video.dialog_text="Manter esta configuração? Reversão em 15 segundos.";video.popup_centered(Vector2i(420,150))
    elif result!="":label(content,result,13,amber)
    else:draft=preferences.applied.duplicate(true);refresh()
func _confirm_video() -> void:
    video_seconds=0;var result=preferences.confirm();draft=preferences.applied.duplicate(true);refresh()
    if result!="":label(content,result,13,amber)
func _rollback_video() -> void:
    video_seconds=0;video.hide();preferences.rollback();draft=preferences.applied.duplicate(true);refresh()
func _process(delta: float) -> void:
    if manager==null:return
    timer+=delta
    if timer>.5:
        timer=0;exploration.update(Vector2(scene.player.global_position.x,scene.player.global_position.z))
    if video_seconds>0:
        video_seconds-=delta;video.dialog_text="Manter esta configuração? Reversão em %d segundos."%ceili(video_seconds)
        if video_seconds<=0:_rollback_video()
    if not opened:return
    var p=scene.player
    if p.paused or p.reaction.is_active() or p.traversal.is_active() or not manager.active.is_empty() or scene.game_ui.personal.visible or scene.game_ui.nearby.visible or scene.game_ui.windows[1].visible:force_close()
    else:p.set_hud_open(true)
func _input(event: InputEvent) -> void:
    if not opened:return
    if modal.visible or video.visible:return
    if event is InputEventKey:
        if event.pressed and not event.echo:
            var code=event.physical_keycode if event.physical_keycode else event.keycode
            if capture!="":
                if code==KEY_ESCAPE:capture="";refresh()
                else:
                    var candidate=draft.duplicate(true);candidate.bindings[capture]=[code]
                    if preferences.valid(candidate):draft=candidate;capture="";refresh()
                    else:label(content,"Tecla reservada ou já utilizada.",13,amber)
            elif event.is_action_pressed("character_skills") or code==KEY_ESCAPE:close()
            elif get_viewport().gui_get_focus_owner() in tabs and code in [KEY_LEFT,KEY_RIGHT,KEY_HOME,KEY_END]:
                var next=0 if code==KEY_HOME else 3 if code==KEY_END else posmod(tab+(1 if code==KEY_RIGHT else -1),4);select_tab(next);tabs[next].grab_focus()
            elif tab==0 and code in [KEY_1,KEY_2,KEY_3,KEY_4]:selected=manager.social.learning_rules.trainable[code-KEY_1];refresh()
            elif tab==0 and code in [KEY_UP,KEY_DOWN]:
                var skills=manager.social.learning_rules.trainable;selected=skills[posmod(skills.find(selected)+(1 if code==KEY_DOWN else -1),skills.size())];refresh();buttons[selected].grab_focus()
            elif tab==2 and code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:map_view.center+=Vector2(float(code==KEY_RIGHT)-float(code==KEY_LEFT),float(code==KEY_DOWN)-float(code==KEY_UP))*15/map_view.zoom;map_view.queue_redraw()
            elif code in [KEY_TAB,KEY_ENTER,KEY_KP_ENTER,KEY_SPACE,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:return
        # All gameplay keyboard events are captured while the menu is open.
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:get_viewport().set_input_as_handled()
func _shortcut_input(event: InputEvent) -> void:
    if event.is_action("character_skills"):
        get_viewport().set_input_as_handled()
        if event.is_action_pressed("character_skills",false):
            if opened:close()
            else:open()
