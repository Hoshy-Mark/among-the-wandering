extends Control
var strength=0.0
var hostile=false
var blocked=false
var kick=0.0
func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw() -> void:
    if strength<=.001:return
    var center=size*.5
    var color=Color("f2efe0") if not hostile else Color("e5aa66")
    if blocked:color=Color("d96b57")
    color.a=strength
    draw_circle(center,2.1,color)
    var gap=7+kick*7
    for axis in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
        draw_line(center+axis*gap,center+axis*(gap+5),Color(0,0,0,.65*strength),3,true)
        draw_line(center+axis*gap,center+axis*(gap+5),color,1.2,true)
