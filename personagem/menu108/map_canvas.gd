extends "res://personagem/menu107/map_canvas.gd"
## Ink, paper fibres and page folds are presentation only; survey stays authoritative.
func _draw() -> void:
    super._draw()
    var page=Rect2(Vector2.ZERO,size)
    for y in range(11,int(size.y),31):
        for x in range(9,int(size.x),47):
            var offset=Vector2((y*7+x*3)%17,(x+y)%13)
            draw_line(Vector2(x,y)+offset,Vector2(x+9,y-1)+offset,Color(.36,.29,.17,.10),.6,true)
    # Subtle age at edges and a printed inset frame.
    for i in range(18):
        var inset=float(i);draw_rect(page.grow(-inset),Color(.38,.29,.15,.018*(1-float(i)/18)),false,1)
    draw_rect(page.grow(-4),Color(.42,.35,.23,.25),false,1)
    var fold=size.x*.49
    draw_line(Vector2(fold,0),Vector2(fold+4,size.y),Color(.40,.32,.20,.12),1)
    draw_line(Vector2(fold+2,0),Vector2(fold+6,size.y),Color(.98,.92,.75,.15),2)
