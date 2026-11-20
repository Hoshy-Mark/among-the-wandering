extends "res://personagem/menu107/menu.gd"
## Presentation revision. All transactions and gameplay adapters remain R107.
var icons=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/menu108/icons.json"))
var icon_cache={}
var inner108: MarginContainer
var footer_margin108: MarginContainer
var background108: TextureRect
var tab_icons=[]
var tab_names=[]
var tab_rules=[]
var initialized108=false
const INK=preload("res://personagem/menu108/ink.gd")
func label(parent: Node,text: String,font_size: int=15,color: Color=Color("ebe9de"),serif: bool=false) -> Label:
    var result=super.label(parent,text,font_size,color,serif);result.autowrap_mode=TextServer.AUTOWRAP_OFF;return result
func gap(parent: Node,height: float) -> Control:
    var item=Control.new();item.custom_minimum_size.y=height;item.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(item);return item
func rule(parent: Node) -> void:
    var item=HSeparator.new();item.add_theme_stylebox_override("separator",line_style());parent.add_child(item)
func line_style() -> StyleBoxLine:
    var result=StyleBoxLine.new();result.color=Color("46524988");result.thickness=1;return result
func icon(id: String,size108: int=23,color108: Color=Color("a8b7a7")) -> TextureRect:
    var key=id+color108.to_html()
    if not icon_cache.has(key):
        var svg='<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#'+color108.to_html(false)+'" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round">'+icons[id]+'</svg>'
        var image=Image.new();assert(image.load_svg_from_string(svg)==OK);icon_cache[key]=ImageTexture.create_from_image(image)
    var texture=TextureRect.new();texture.texture=icon_cache[key];texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;texture.custom_minimum_size=Vector2.ONE*size108;texture.mouse_filter=Control.MOUSE_FILTER_IGNORE;return texture
func icon_texture(id: String,color108: Color=Color("a8b7a7")) -> Texture2D:
    var temporary=icon(id,23,color108);var result=temporary.texture;temporary.free();return result
func padding(parent: Node,left: int=0,top: int=0,right: int=0,bottom: int=0) -> MarginContainer:
    var margin=MarginContainer.new()
    for pair in [["left",left],["top",top],["right",right],["bottom",bottom]]:margin.add_theme_constant_override("margin_"+pair[0],pair[1])
    margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL;margin.size_flags_vertical=Control.SIZE_EXPAND_FILL;parent.add_child(margin);return margin
func passive(node: Node) -> void:
    if node is Control:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
    for child in node.get_children():passive(child)
func button(parent: Node,text: String,callback: Callable,active: bool=false) -> Button:
    var value=super.button(parent,text,callback,active);value.add_theme_font_size_override("font_size",13);value.custom_minimum_size.y=38
    value.add_theme_stylebox_override("normal",style("75674759" if active else "25332b","c8a979" if active else "536659",12))
    value.add_theme_stylebox_override("disabled",style("253029","465248",12));value.add_theme_color_override("font_disabled_color",Color("829286"));value.add_theme_color_override("font_color",Color("f0e3c7") if active else Color("c8d3c8"));return value
func flat_button(parent: Node,text: String,callback: Callable,active: bool=false) -> Button:
    var value=button(parent,text,callback,active);var box=style("7f704f30" if active else "00000000","b99c697e" if active else "46544855",0)
    if active:box.border_width_left=3
    else:box.border_width_left=0;box.border_width_top=0;box.border_width_right=0
    value.add_theme_stylebox_override("normal",box);return value
func setup(owner: Node3D) -> void:
    super.setup(owner)
    var root=panel.get_parent();var theme=root.theme
    var body_font=SystemFont.new();body_font.font_names=PackedStringArray(["Arial","Liberation Sans","sans-serif"]);theme.default_font=body_font;theme.default_font_size=15
    theme.set_color("font_color","Label",Color("ebe9de"));theme.set_stylebox("separator","HSeparator",line_style());theme.set_stylebox("separator","VSeparator",line_style())
    theme.set_stylebox("normal","OptionButton",style("27362b","607162",10));theme.set_stylebox("hover","OptionButton",style("334132","9a916d",10));theme.set_font_size("font_size","OptionButton",13)
    theme.set_stylebox("slider","HSlider",style("344438","536357",0));theme.set_stylebox("grabber_area","HSlider",style("c8aa76","c8aa76",0))
    for variant in ["grabber","grabber_highlight"]:
        var image=Image.create(12,16,false,Image.FORMAT_RGBA8);image.fill(Color("c8aa76"));theme.set_icon(variant,"HSlider",ImageTexture.create_from_image(image))
    for variant in ["scroll","scroll_focus"]:theme.set_stylebox(variant,"VScrollBar",style("17211b","17211b",0))
    for variant in ["grabber","grabber_highlight","grabber_pressed"]:theme.set_stylebox(variant,"VScrollBar",style("586b59","586b59",0))
    var blur=Shader.new();blur.code='shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap; void fragment(){vec3 c=textureLod(screen_texture,SCREEN_UV,2.0).rgb; COLOR=vec4(mix(c,vec3(.043,.071,.055),.58),1.0);}'
    var material108=ShaderMaterial.new();material108.shader=blur;shade.material=material108;shade.color=Color.WHITE
    var border=style("00000000","8b856c",1);border.shadow_color=Color(0,0,0,.5);border.shadow_size=28;border.shadow_offset=Vector2(0,16);panel.add_theme_stylebox_override("panel",border)
    var svg='<svg xmlns="http://www.w3.org/2000/svg" width="1050" height="632"><defs><linearGradient id="p" x2="1" y2="1"><stop stop-color="#19231d"/><stop offset="1" stop-color="#0e1612"/></linearGradient><radialGradient id="g" cx=".9" cy=".1"><stop stop-color="#6b754e" stop-opacity=".07"/><stop offset="1" stop-opacity="0"/></radialGradient></defs><rect width="1050" height="632" fill="url(#p)"/><rect width="1050" height="632" fill="url(#g)"/></svg>'
    var image=Image.new();image.load_svg_from_string(svg);background108=TextureRect.new();background108.texture=ImageTexture.create_from_image(image);background108.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background108.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(background108);panel.move_child(background108,0)
    var shell=panel.get_child(1);var header=shell.get_child(0);var close_button=header.get_child(1);close_button.text="";close_button.icon=icon_texture("close");close_button.expand_icon=true;close_button.custom_minimum_size=Vector2(34,34);close_button.add_theme_stylebox_override("normal",StyleBoxEmpty.new());close_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    header.remove_child(close_button);var close_margin=MarginContainer.new();close_margin.add_theme_constant_override("margin_right",36);header.add_child(close_margin);close_margin.add_child(close_button)
    inner108=content.get_parent();footer_margin108=MarginContainer.new();shell.remove_child(settings_host);footer_margin108.add_child(settings_host);shell.add_child(footer_margin108);shell.move_child(footer_margin108,shell.get_child_count()-2)
    for side in ["left","right"]:footer_margin108.add_theme_constant_override("margin_"+side,38)
    footer_margin108.add_theme_constant_override("margin_bottom",18)
    for index in range(4):
        var b=tabs[index];b.text="";b.custom_minimum_size.y=77
        var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);b.add_child(center);var stack=column(center,false);stack.add_theme_constant_override("separation",7)
        var svg_icon=icon(["skills","people","map","settings"][index]);svg_icon.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;stack.add_child(svg_icon);tab_icons.append(svg_icon)
        var name108=label(stack,["Habilidades","Personagens","Mapa","Configurações"][index],13);name108.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tab_names.append(name108)
        var active_rule=ColorRect.new();active_rule.color=Color("d1b27b");active_rule.anchor_left=.18;active_rule.anchor_right=.82;active_rule.offset_top=-1;active_rule.offset_bottom=1;b.add_child(active_rule);tab_rules.append(active_rule);passive(center);active_rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
    initialized108=true;_layout();refresh()
func _layout() -> void:
    super._layout()
    if not initialized108:return
    var viewport=get_viewport().get_visible_rect().size
    if viewport.x<761:panel.position=Vector2.ZERO;panel.size=viewport
    else:panel.position=Vector2((viewport.x-minf(1050,viewport.x-56))*.5,(viewport.y-minf(632,viewport.y-56))*.5);panel.size=Vector2(minf(1050,viewport.x-56),minf(632,viewport.y-56))
    refresh()
func refresh() -> void:
    super.refresh()
    if not initialized108:return
    var narrow=get_viewport().get_visible_rect().size.x<761
    for side in ["left","right"]:footer_margin108.add_theme_constant_override("margin_"+side,20 if narrow else 38)
    for side in ["left","right"]:inner108.add_theme_constant_override("margin_"+side,13 if tab==2 else 20 if narrow else 38)
    inner108.add_theme_constant_override("margin_top",10 if tab==2 else 18 if tab==1 else 26);inner108.add_theme_constant_override("margin_bottom",11 if tab==2 else 18)
    footer_margin108.visible=tab==3
    for index in range(4):
        var box=style("c2a87012" if index==tab else "19241d", "46524944",0);box.border_width_top=0;box.border_width_bottom=0;box.border_width_left=0;tabs[index].add_theme_stylebox_override("normal",box)
        var color108=Color("ead0a0") if index==tab else Color("9ead9f");tab_names[index].add_theme_color_override("font_color",color108);tab_names[index].add_theme_font_size_override("font_size",11 if narrow else 13)
        tab_icons[index].texture=icon_texture(["skills","people","map","settings"][index],color108);tab_rules[index].visible=index==tab
func split108(ratio: float=.54,gap108: int=42) -> Array:
    var row: BoxContainer=VBoxContainer.new() if get_viewport().get_visible_rect().size.x<761 else HBoxContainer.new();row.add_theme_constant_override("separation",gap108);row.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(row)
    var left=column(row);var right=column(row);left.add_theme_constant_override("separation",0);right.add_theme_constant_override("separation",0);left.size_flags_stretch_ratio=ratio;right.size_flags_stretch_ratio=1-ratio
    if row is HBoxContainer:left.custom_minimum_size.y=444 if tab==0 else 438
    return [left,right]
func cells(parent: Node,total: int,filled108: int,width: int=0) -> Control:
    var item=INK.new();item.count=total;item.filled=filled108;item.custom_minimum_size=Vector2(width,8);item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;parent.add_child(item);return item
func _skills() -> void:
    var halves=split108();var model=manager.social;var narrow=get_viewport().get_visible_rect().size.x<761
    for skill in model.learning_rules.trainable:
        var rank=int(model.data.skills[skill]);var b=flat_button(halves[0],"",func():selected=skill;refresh(),skill==selected);b.custom_minimum_size.y=67 if narrow else 73;buttons[skill]=b
        var margin=padding(b,14,11,14,11);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);var row=horizontal(margin,16)
        var box=PanelContainer.new();box.custom_minimum_size=Vector2(40,40);box.size_flags_vertical=Control.SIZE_SHRINK_CENTER;box.add_theme_stylebox_override("panel",style("967c4e21" if skill==selected else "53695717","c6a56c59" if skill==selected else "81958030",8));row.add_child(box);box.add_child(icon(skill,22,Color("dfc590") if skill==selected else Color("a8b7a7")))
        var main=column(row);main.add_theme_constant_override("separation",12);var head=horizontal(main,12);label(head,model.config.skills[skill].label,16).size_flags_horizontal=Control.SIZE_EXPAND_FILL;label(head,"%d/6"%rank,13,Color("c2c7b9"));cells(main,6,rank);passive(margin)
    var spacer=gap(halves[0],16);spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;rule(halves[0]);var strip=horizontal(halves[0]);strip.custom_minimum_size.y=48
    label(strip,"Experiências  %d/3"%model.experience_progress(),13,Color("afb9a9")).size_flags_horizontal=Control.SIZE_EXPAND_FILL;var chips=cells(strip,3,model.experience_progress(),93);chips.size_flags_horizontal=Control.SIZE_SHRINK_END;chips.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    var border=PanelContainer.new();var box=style("00000000","96a4902e",0);box.set_border_width_all(0);box.border_width_left=0 if narrow else 1;border.add_theme_stylebox_override("panel",box);halves[1].add_child(border);border.size_flags_vertical=Control.SIZE_EXPAND_FILL
    var detail=column(padding(border,4 if narrow else 42,0,6,0));detail.add_theme_constant_override("separation",0);var top=horizontal(detail);top.custom_minimum_size.y=65;top.add_child(icon(selected,35,Color("aa9975")));var stretch=Control.new();stretch.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(stretch);label(top,str(model.available_points()),29,Color("e5c992"),true);label(top,"pontos disponíveis" if model.available_points()!=1 else "ponto disponível",12,Color("c8c4aa"))
    gap(detail,19);label(detail,"NÍVEL %d / 6"%int(model.data.skills[selected]),11,Color("bba77d"));gap(detail,13);label(detail,model.config.skills[selected].label,35,Color("ead2a4"),true);gap(detail,19)
    var text=label(detail,model.learning_rules.descriptions[selected],16,Color("d3d9cf"));text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;text.add_theme_constant_override("line_spacing",7);gap(detail,38)
    var improve=button(detail,"Melhorar · 1 ponto",func():train(selected),true);improve.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;improve.custom_minimum_size=Vector2(165,43);improve.disabled=model.available_points()<=0 or int(model.data.skills[selected])>=6
func portrait108(parent: Node,id: String,dimensions: Vector2) -> void:
    var frame=PanelContainer.new();frame.custom_minimum_size=dimensions;frame.size_flags_vertical=Control.SIZE_SHRINK_CENTER;frame.add_theme_stylebox_override("panel",style("364338","8b8368",1));parent.add_child(frame)
    var texture=TextureRect.new();texture.texture=manager.portrait_d02(id);texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;frame.add_child(texture)
func chip(parent: Node,text: String) -> void:
    var frame=PanelContainer.new();frame.add_theme_stylebox_override("panel",style("27342b","6b766b88",5));parent.add_child(frame);label(frame,text,11,Color("d7ddcc"))
func _characters() -> void:
    var rows=projection.characters(manager)
    if rows.is_empty():label(content,"Nenhum personagem conhecido.",15,muted);return
    if not rows.any(func(row):return row.id==selected_npc):selected_npc=rows[0].id
    var narrow=get_viewport().get_visible_rect().size.x<761;var halves=split108(.25,24);var current={}
    var roster: BoxContainer=halves[0]
    if narrow:
        var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.custom_minimum_size.y=70;halves[0].add_child(scroll);roster=horizontal(scroll,8)
    for row in rows:
        var b=flat_button(roster,"",func():selected_npc=row.id;refresh(),row.id==selected_npc);b.custom_minimum_size=Vector2(168 if narrow else 0,69)
        var margin=padding(b,8,9,8,9);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);var info=horizontal(margin,11);portrait108(info,row.id,Vector2(40,48));var text=column(info);text.add_theme_constant_override("separation",5);label(text,row.name,14,Color("e9e8dc"));label(text,row.bond,11,Color("acb7a9"));passive(margin)
        if row.id==selected_npc:current=row
    var sheet=halves[1];var head=horizontal(sheet,16);portrait108(head,current.id,Vector2(67,78));var heading=column(head);heading.add_theme_constant_override("separation",7)
    label(heading,current.name,27,Color("ecd9b4"),true);label(heading,"Arroio das Figueiras",12,Color("afb9ad"));var chips=horizontal(heading,7);chip(chips,"● Vivo");chips.get_child(0).tooltip_text=current.life;chip(chips,current.bond)
    gap(sheet,11);rule(sheet);gap(sheet,12)
    var core: BoxContainer=VBoxContainer.new() if narrow else HBoxContainer.new();core.add_theme_constant_override("separation",22);sheet.add_child(core)
    var biography=column(core);section(biography,"B I O G R A F I A");var description=label(biography," ".join(current.biography) if not current.biography.is_empty() else "Encontrado em Arroio das Figueiras.",15,Color("e0e3d9"),true);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.add_theme_constant_override("line_spacing",5)
    var relation_frame=PanelContainer.new();var border=style("00000000","66725f42",0);border.set_border_width_all(0);border.border_width_left=0 if narrow else 1;relation_frame.add_theme_stylebox_override("panel",border);relation_frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL;core.add_child(relation_frame)
    var relationships=column(padding(relation_frame,0 if narrow else 21));relationships.add_theme_constant_override("separation",12);section(relationships,"RELAÇÃO COM VOCÊ")
    for dimension in current.relationship:
        var metric=horizontal(relationships,7);var name108=label(metric,dimension,12,Color("d3d9cc"));name108.custom_minimum_size.x=94
        var track=INK.new();track.kind="metric";track.custom_minimum_size=Vector2(40,6);track.size_flags_horizontal=Control.SIZE_EXPAND_FILL;track.size_flags_vertical=Control.SIZE_SHRINK_CENTER;metric.add_child(track);track.tooltip_text="Desconhecido";var number=label(metric,"—",11,Color("abb9a9"));number.custom_minimum_size.x=25;number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    gap(sheet,16);rule(sheet);gap(sheet,11)
    var notes: BoxContainer=VBoxContainer.new() if narrow else HBoxContainer.new();notes.add_theme_constant_override("separation",22);sheet.add_child(notes)
    var secrets=column(notes);section(secrets,"SEGREDOS CONHECIDOS");var events=column(notes);section(events,"EVENTOS IMPORTANTES")
    for category109 in ["secrets","events"]:
        var host=secrets if category109=="secrets" else events
        if current.get(category109,[]).is_empty():label(host,"Nenhum segredo descoberto." if category109=="secrets" else "Nenhum evento importante registrado.",12,Color("8c9e90"))
        for entry109 in current.get(category109,[]):
            var detail109=label(host,entry109.detail,13,Color("d9dacc"));detail109.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
            var source109=label(host,"Relato · "+entry109.source,10,Color("b8a27c"));source109.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func _map() -> void:
    var narrow=get_viewport().get_visible_rect().size.x<761;var halves=split108(.79,12)
    map_view=load("res://personagem/menu108/map_canvas.gd").new();map_view.survey=exploration;map_view.size_flags_vertical=Control.SIZE_EXPAND_FILL;halves[0].add_child(map_view);map_view.custom_minimum_size.y=340 if narrow else 462
    map_view.center=exploration.position if map_center==Vector2.ZERO else map_center;map_view.zoom=map_zoom;map_view.selected=selected_place
    map_view.picked.connect(func(id):selected_place=id;map_center=map_view.center;map_zoom=map_view.zoom;refresh())
    var tools=VBoxContainer.new();tools.add_theme_constant_override("separation",5);map_view.add_child(tools);tools.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);tools.position=Vector2(-44,12)
    for action in [["+",func():map_view.set_zoom(map_view.zoom*1.2)],["−",func():map_view.set_zoom(map_view.zoom/1.2)],["◎",func():map_view.focus_player()]]:
        var b=button(tools,action[0],action[1]);b.custom_minimum_size=Vector2(33,30);b.add_theme_font_size_override("font_size",18);b.add_theme_color_override("font_color",Color("443e32"));b.add_theme_stylebox_override("normal",style("f0e5c7eb","9b8664",0))
    var title_card=PanelContainer.new();title_card.position=Vector2(15,13);title_card.add_theme_stylebox_override("panel",style("e7d8b9df","b8a580",10));map_view.add_child(title_card);var text=column(title_card,false);text.add_theme_constant_override("separation",5);label(text,"Arroio das Figueiras",19,Color("534631"),true);label(text,"V I S Ã O  L O C A L",9,Color("796b53"));passive(title_card)
    var key=PanelContainer.new();key.add_theme_stylebox_override("panel",style("ebdfc3ed","9e8a67",0));map_view.add_child(key);key.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);key.position=Vector2(13,-(236 if legend else 34)-13);key.custom_minimum_size.x=154
    var legend_box=column(key,false);legend_box.add_theme_constant_override("separation",0);var toggle=button(legend_box,"Legenda                         "+("−" if legend else "+"),func():legend=not legend;map_center=map_view.center;map_zoom=map_view.zoom;refresh());toggle.add_theme_stylebox_override("normal",StyleBoxEmpty.new());toggle.add_theme_color_override("font_color",Color("4a4030"));toggle.add_theme_font_size_override("font_size",11);toggle.custom_minimum_size.y=31
    if legend:
        var grid=GridContainer.new();grid.columns=2;grid.add_theme_constant_override("h_separation",9);grid.add_theme_constant_override("v_separation",5);padding(legend_box,10,7,10,10).add_child(grid)
        for entry in [["◉","Você está aqui"],["◇","Descoberto"],["◆","Visitado"],["◇","Marcado"],["━","Estrada"],["┄","Trilha"],["▣","Área urbana"],["▧","Água"],["▨","Não mapeado"]]:label(grid,entry[0],12,Color("596652"));label(grid,entry[1],11,Color("4b4535"))
    var aside=halves[1];aside.add_theme_constant_override("separation",10);label(aside,"Locais",20,Color("e1ddcb"),true);var filters=horizontal(aside,2)
    for index in range(3):
        var b=flat_button(filters,["Todos","Visitados","Marcados"][index],func():map_filter=index;map_center=map_view.center;map_zoom=map_view.zoom;refresh(),index==map_filter);b.add_theme_font_size_override("font_size",11);b.custom_minimum_size.y=29
    rule(aside);var known=exploration.known()
    for row in known:
        if map_filter==1 and not row.visited or map_filter==2 and not row.marked:continue
        var b=flat_button(aside,"",func():selected_place=row.id;map_center=map_view.center;map_zoom=map_view.zoom;refresh(),row.id==selected_place);b.custom_minimum_size.y=65;var margin=padding(b,7,10,7,10);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);var data=column(margin);data.add_theme_constant_override("separation",5);label(data,row.name,13);label(data,"Visitado" if row.visited else "Descoberto",10,muted);passive(margin)
    var space=gap(aside,8);space.size_flags_vertical=Control.SIZE_EXPAND_FILL
    if selected_place!="" and known.any(func(row):return row.id==selected_place):
        rule(aside);label(aside,exploration.places[selected_place].name,17,Color("ead3a6"),true);button(aside,"Desmarcar local" if selected_place in exploration.data.marked else "Marcar local",func():exploration.mark(selected_place);map_center=map_view.center;map_zoom=map_view.zoom;refresh())
func config_row(parent: Node,text: String,height: int=67) -> HBoxContainer:
    var narrow=get_viewport().get_visible_rect().size.x<761
    var frame=PanelContainer.new();var box=style("00000000","a4b8a429",0);box.set_border_width_all(0);box.border_width_bottom=1;frame.add_theme_stylebox_override("panel",box);parent.add_child(frame);var margin=padding(frame,3 if narrow else 13,11,3 if narrow else 13,11);var row=horizontal(margin,12 if narrow else 26);row.custom_minimum_size.y=height-22;var name108=label(row,text,14 if narrow else 15,Color("e3e7dc"));name108.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;name108.size_flags_horizontal=Control.SIZE_EXPAND_FILL;name108.size_flags_vertical=Control.SIZE_SHRINK_CENTER;return row
func _option(text: String,key: String,items: Array,values: Array=[]) -> void:
    var row=config_row(content,text);var option=OptionButton.new();option.custom_minimum_size=Vector2(155 if get_viewport().get_visible_rect().size.x<761 else 184,38);option.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    for item in items:option.add_item(item)
    option.selected=values.find(int(draft[key])) if not values.is_empty() else int(draft[key]);option.item_selected.connect(func(index):draft[key]=values[index] if not values.is_empty() else index;refresh());row.add_child(option)
func _settings() -> void:
    content.add_theme_constant_override("separation",0)
    var scroll=ScrollContainer.new();scroll.custom_minimum_size.y=46;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll);var categories=horizontal(scroll,0)
    for index in range(5):
        var b=flat_button(categories,["Vídeo","Áudio","Controles","Interface","Acessibilidade"][index],func():category=index;refresh(),category==index);b.custom_minimum_size=Vector2(84 if index<3 else 120,45);b.add_theme_font_size_override("font_size",13)
        var box=style("c9b07a14" if index==category else "00000000","cba96f" if index==category else "445449",0);box.set_border_width_all(0);box.border_width_bottom=2 if index==category else 1;b.add_theme_stylebox_override("normal",box)
    gap(content,19)
    if category==0:
        _option("Modo de tela","mode",["Janela","Tela cheia","Janela sem bordas"]);_option("Resolução","resolution",["1280 × 720","1600 × 900","1920 × 1080"])
        var row=config_row(content,"Sincronização vertical");var toggle=button(row,"Ligada" if draft.vsync else "Desligada",func():draft.vsync=not draft.vsync;refresh(),draft.vsync);toggle.custom_minimum_size=Vector2(112,37);toggle.size_flags_vertical=Control.SIZE_SHRINK_CENTER
        _option("Limite de quadros","fps",["Ilimitado","30","60","120"],[0,30,60,120])
    elif category==1:
        var row=config_row(content,"Volume geral");var slider=HSlider.new();slider.min_value=0;slider.max_value=100;slider.value=draft.volume;slider.custom_minimum_size=Vector2(185,20);slider.size_flags_vertical=Control.SIZE_SHRINK_CENTER;row.add_child(slider);var value=label(row,str(int(draft.volume))+"%",13,Color("e4d1af"));value.custom_minimum_size.x=45;value.size_flags_vertical=Control.SIZE_SHRINK_CENTER;value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        slider.value_changed.connect(func(amount):draft.volume=amount;value.text=str(int(amount))+"%";_update_footer())
    elif category==2:
        var grid=GridContainer.new();grid.columns=1 if get_viewport().get_visible_rect().size.x<761 else 2;grid.add_theme_constant_override("h_separation",22);grid.add_theme_constant_override("v_separation",0);content.add_child(grid)
        for action in preferences.actions:
            var row=config_row(grid,{"character_skills":"Menu","weapon_quick_up":"Arma longa","weapon_quick_left":"Arma curta","weapon_quick_right":"Arma branca","weapon_quick_down":"Arremessável","weapon_quick_consult":"Consultar atalhos"}[action],58);row.get_parent().get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
            var names=[]
            for code in draft.bindings[action]:names.append(OS.get_keycode_string(int(code)))
            var key=button(row,"Pressione…" if capture==action else " / ".join(names),func():capture=action;refresh(),capture==action);key.custom_minimum_size=Vector2(105,34)
        gap(content,16);var hint=label(content,"WASD · mover    Shift · correr    E · interagir    I · inventário    R · recarregar",12,Color("829286"));hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    else:label(content,"Nenhuma opção disponível nesta versão.",13,Color("aebbac"))
    var footer: BoxContainer=VBoxContainer.new() if get_viewport().get_visible_rect().size.x<761 else HBoxContainer.new();settings_footer.add_child(footer);footer.add_theme_constant_override("separation",9);footer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var state=label(footer,"Alterações não aplicadas" if dirty() else "Sem alterações",12,Color("cbb78d") if dirty() else Color("84998a"));state.name="PreferenceStatus";state.size_flags_horizontal=Control.SIZE_EXPAND_FILL;state.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    var actions=horizontal(footer,9);actions.size_flags_horizontal=Control.SIZE_SHRINK_END
    button(actions,"Padrão",func():draft=preferences.defaults.duplicate(true);refresh());button(actions,"Desfazer",func():draft=preferences.applied.duplicate(true);capture="";refresh());var apply=button(actions,"Aplicar",apply_preferences,true);apply.name="ApplyPreferences";apply.custom_minimum_size.x=104;apply.disabled=not dirty()
