extends Control
signal selected(zone: String)
var health: RefCounted
var current="forearm_left"
var zones={"head":Rect2(.42,.02,.16,.12),"neck":Rect2(.45,.145,.10,.04),"chest":Rect2(.34,.19,.32,.15),"abdomen":Rect2(.36,.345,.28,.115),"groin":Rect2(.39,.465,.22,.08)}

func _ready() -> void:
    custom_minimum_size=Vector2(210,380)
    mouse_filter=Control.MOUSE_FILTER_STOP
    for side in ["left","right"]:
        var left=side=="left"
        zones["upper_arm_"+side]=Rect2(.68 if left else .21,.20,.11,.15)
        zones["forearm_"+side]=Rect2(.75 if left else .14,.355,.11,.15)
        zones["hand_"+side]=Rect2(.80 if left else .09,.51,.11,.09)
        zones["thigh_"+side]=Rect2(.51 if left else .34,.55,.15,.17)
        zones["shin_"+side]=Rect2(.52 if left else .35,.725,.13,.17)
        zones["foot_"+side]=Rect2(.52 if left else .32,.90,.16,.065)

func _rect(zone: String) -> Rect2:
    return Rect2(zones[zone].position*size,zones[zone].size*size)

func _draw() -> void:
    if health==null:
        return
    for zone in zones:
        var rect=_rect(zone)
        var color=Color(.29,.36,.37).lerp(Color(.86,.27,.20),health.severity(zone))
        draw_style_box(_style(color),rect)
        if current==zone:
            draw_rect(rect.grow(2),Color(.88,.76,.43),false,2)
    var font=ThemeDB.fallback_font
    draw_string(font,Vector2(size.x*.79,14),"E",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(.65,.72,.69))
    draw_string(font,Vector2(size.x*.12,14),"D",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(.65,.72,.69))

func _style(color: Color) -> StyleBoxFlat:
    var style=StyleBoxFlat.new()
    style.bg_color=color
    style.set_corner_radius_all(4)
    return style

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
        for zone in zones:
            if _rect(zone).has_point(event.position):
                current=zone
                selected.emit(zone)
                queue_redraw()
                accept_event()
                return

func _get_tooltip(at_position: Vector2) -> String:
    for zone in zones:
        if _rect(zone).has_point(at_position):
            return health.regions[zone].name
    return "Selecione uma região"
