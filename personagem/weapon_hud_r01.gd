extends Control
## Original vector silhouettes and CanvasItem drawing, no inventory authority.
const FG=Color("e9e9df")
const SECONDARY=Color("c0c7bf")
const ACCENT=Color("e3c997")
const MUTED=Color("809088")
const PLACES={"up":Vector2(111,0),"left":Vector2(0,78),"right":Vector2(222,78),"down":Vector2(111,156)}
var controller: Node
var cross_open=false
var font: Font=ThemeDB.fallback_font
var gradient_r01: GradientTexture2D
var compact_rect=Rect2()
var cross_rect=Rect2()

func _ready() -> void:
    name="WeaponQuickHUD_R01";mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var gradient=Gradient.new()
    gradient.offsets=PackedFloat32Array([0,.4,1])
    gradient.colors=PackedColorArray([Color(.047,.078,.074,.10),Color(.047,.078,.074,.96),Color(.047,.078,.074,.96)])
    gradient_r01=GradientTexture2D.new();gradient_r01.gradient=gradient
    gradient_r01.width=230;gradient_r01.height=1;gradient_r01.fill_from=Vector2.ZERO;gradient_r01.fill_to=Vector2.RIGHT

func _text(value: String,point: Vector2,pixels: int,color: Color=FG,width: float=-1,align: HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT) -> void:
    draw_string(font,point,value,align,width,pixels,color)

func _icon(definition: String,at: Vector2,factor: float,color: Color) -> void:
    # Coordinates are authored here for the game's own simplified equipment.
    var path=[]
    if definition in ["pistol","revolver"]:
        path=[Vector2(4,11),Vector2(42,11),Vector2(49,16),Vector2(40,21),Vector2(29,21),Vector2(20,33),Vector2(12,33),Vector2(17,20),Vector2(5,20),Vector2(4,11)]
    elif definition=="carbine":
        path=[Vector2(2,20),Vector2(14,15),Vector2(21,15),Vector2(23,11),Vector2(42,11),Vector2(44,14),Vector2(65,14),Vector2(65,18),Vector2(42,19),Vector2(36,23),Vector2(34,30),Vector2(29,30),Vector2(30,23),Vector2(19,23),Vector2(5,29),Vector2(2,20)]
    elif definition in ["knife","kitchen_knife"]:
        path=[Vector2(7,32),Vector2(23,18),Vector2(25,21),Vector2(49,3),Vector2(44,19),Vector2(30,29),Vector2(26,26),Vector2(12,38),Vector2(7,32)]
    elif definition in ["baton","metal_bar","crowbar","axe"]:
        path=[Vector2(9,34),Vector2(39,5),Vector2(45,6),Vector2(44,12),Vector2(14,39),Vector2(9,34)]
    elif definition=="reserved":
        path=[Vector2(20,7),Vector2(29,7),Vector2(30,12),Vector2(34,16),Vector2(34,29),Vector2(30,33),Vector2(19,33),Vector2(15,29),Vector2(15,17),Vector2(20,12),Vector2(20,7)]
    if path.is_empty():
        for x in range(17,39,5):draw_line(at+Vector2(x,20)*factor,at+Vector2(x+2,20)*factor,color,1,true)
        return
    var points=PackedVector2Array()
    for p in path:points.append(at+p*factor)
    draw_polyline(points,color,1.5*factor,true)
    if definition=="pistol":
        draw_rect(Rect2(at+Vector2(15,7)*factor,Vector2(10,4)*factor),color,false,1.2*factor)
        draw_polyline(PackedVector2Array([at+Vector2(25,21)*factor,at+Vector2(24,26)*factor,at+Vector2(20,26)*factor]),color,1.1*factor,true)
    if definition=="revolver":draw_arc(at+Vector2(25,17)*factor,5*factor,0,TAU,16,color,1.1*factor,true)

func _hint(direction: String) -> String:
    return _action_hint(controller.ACTIONS_R01[direction])

func _action_hint(action: String) -> String:
    var events=InputMap.action_get_events(action)
    var labels=[]
    for event in events:
        if event is InputEventKey:
            var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
            labels.append({KEY_UP:"↑",KEY_LEFT:"←",KEY_RIGHT:"→",KEY_DOWN:"↓"}.get(code,OS.get_keycode_string(code)))
        elif event is InputEventJoypadButton:labels.append("J%d"%event.button_index)
    return "/".join(labels) if not labels.is_empty() else "—"

func _draw() -> void:
    if controller==null:return
    var viewport=get_viewport_rect().size
    var scale_ui=clampf(minf(viewport.x/1200.0,viewport.y/750.0),.86,1.25)
    var margin=24.0
    var safe=DisplayServer.get_display_safe_area()
    # Windowed desktop uses viewport margins. Fullscreen additionally honors OS safe area.
    if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN:
        margin=maxf(margin,float(DisplayServer.screen_get_size().x-safe.end.x))
    var origin=Vector2(viewport.x-margin,viewport.y-46)
    draw_set_transform(origin,0,Vector2.ONE*scale_ui)
    var data=controller.presentation_r01();var active=data.active
    compact_rect=Rect2(origin+Vector2(-230,-66)*scale_ui,Vector2(230,66)*scale_ui)
    # Left-to-right graphite/green gradient, like the approved compact reference.
    draw_texture_rect(gradient_r01,Rect2(-230,-66,230,66),false)
    draw_line(Vector2(0,-66),Vector2.ZERO,Color(ACCENT,.68),1.5)
    _icon(active.definition,Vector2(-218,-54),.94,SECONDARY)
    var title=str(active.name).to_upper()
    if font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x>151:
        while font.get_string_size(title+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,10).x>151:title=title.left(-1)
        title+="…"
    _text(title,Vector2(-166,-44),10,SECONDARY,152,HORIZONTAL_ALIGNMENT_RIGHT)
    if not str(active.ammo).is_empty():
        var values=str(active.ammo).split(" / ")
        var suffix="/ "+values[1];var suffix_width=font.get_string_size(suffix,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
        _text(values[0],Vector2(-160,-19),26,FG,140-suffix_width,HORIZONTAL_ALIGNMENT_RIGHT)
        _text(suffix,Vector2(-14-suffix_width,-19),16,SECONDARY)
    else:
        _text("Corpo a corpo" if active.type=="melee" else "—",Vector2(-164,-20),13,SECONDARY,150,HORIZONTAL_ALIGNMENT_RIGHT)
    cross_rect=Rect2(origin+Vector2(-338,-326)*scale_ui,Vector2(338,230)*scale_ui)
    if not cross_open:return
    var base=Vector2(-338,-326)
    for direction in ["up","left","right","down"]:
        var slot=data.slots[direction];var at=base+PLACES[direction]
        var unavailable=slot.state=="unavailable";var empty=slot.state=="empty"
        var tint=Color(.078,.106,.102,.91)
        if slot.active:tint=Color(.176,.180,.149,.96)
        if unavailable:tint.a=.65
        draw_rect(Rect2(at,Vector2(116,72)),tint)
        var border=ACCENT if slot.active else Color(.88,.90,.86,.11 if empty or unavailable else .17)
        draw_rect(Rect2(at,Vector2(116,72)),border,false,1)
        if slot.active:draw_rect(Rect2(at,Vector2(3,72)),ACCENT)
        var text_color=Color(MUTED,.65) if unavailable else (MUTED if empty else SECONDARY)
        _text(controller.LABELS[direction],at+Vector2(8,16),10,text_color)
        _text(_hint(direction),at+Vector2(79,16),10,Color(ACCENT,.5) if unavailable else ACCENT,30,HORIZONTAL_ALIGNMENT_RIGHT)
        _icon("reserved" if unavailable else slot.definition,at+Vector2(39,22),.65,Color(MUTED,.6) if unavailable or empty else (ACCENT if slot.active else FG))
        var short_name=str(slot.name)
        while font.get_string_size(short_name,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x>104:short_name=short_name.left(-2)+"…"
        _text(short_name,at+Vector2(6,62),11,text_color,104,HORIZONTAL_ALIGNMENT_CENTER)
    var center=base+Vector2(169,114)
    draw_circle(center,26,Color(.08,.12,.10,.88))
    draw_arc(center,26,0,TAU,48,Color(.9,.91,.83,.3),1,true)
    draw_line(center-Vector2(8,0),center+Vector2(8,0),MUTED,1,true)
    draw_line(center-Vector2(0,8),center+Vector2(0,8),MUTED,1,true)
    _text("Atalhos · setas / 1–4   ·   %s para consultar"%_action_hint("weapon_quick_consult"),Vector2(-338,-79),10,SECONDARY,338,HORIZONTAL_ALIGNMENT_RIGHT)
