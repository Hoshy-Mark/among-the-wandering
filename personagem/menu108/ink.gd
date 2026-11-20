extends Control
var kind="cells"
var count=6
var filled=0
var known=false
var amount=0.0
var paper=false
func _ready() -> void:mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
    if kind=="cells":
        var gap=5.0;var width=(size.x-gap*(count-1))/count
        for i in range(count):
            var rect=Rect2(Vector2(i*(width+gap),0),Vector2(width,size.y))
            draw_rect(rect,Color("c6a976") if i<filled else Color("29372f"));draw_rect(rect,Color("d4b780") if i<filled else Color("526155"),false,1)
    elif kind=="metric":
        draw_rect(Rect2(Vector2.ZERO,size),Color("2e3c32"))
        if known:draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*clampf(amount,0,1),size.y)),Color("bfa779"))
        else:
            for x in range(0,int(size.x),6):draw_rect(Rect2(x,0,3,size.y),Color("435044"))
        draw_rect(Rect2(Vector2.ZERO,size),Color("536357"),false,1)
    elif kind=="rule":draw_line(Vector2.ZERO,Vector2(size.x,0),Color("465249"),1)
