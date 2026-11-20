extends "res://personagem/reticulo88.gd"
var cone_pixels=4.0
var hit_left=0.0
var head_hit=false
func _draw() -> void:
    super._draw()
    if strength<=.001:return
    var center=size*.5;var color=Color(.94,.94,.87,.5*strength)
    draw_arc(center,maxf(4,cone_pixels),0,TAU,48,color,1,true)
    if hit_left>0:
        var hit_color=Color("f5ce79") if head_hit else Color("f2eee0")
        hit_color.a=minf(1,hit_left/.12)*strength
        for direction in [Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1)]:draw_line(center+direction*5,center+direction*10,hit_color,2,true)
