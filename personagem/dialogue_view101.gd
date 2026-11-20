extends "res://personagem/dialogue_hud_d02.gd"
var relationship_hint: Label
func _ready() -> void:
    super._ready()
    relationship_hint=_label(canvas,"",10,DIM);layout_panel()
func layout_panel() -> void:
    super.layout_panel()
    if relationship_hint!=null:_place(relationship_hint,Rect2(26,112,size.x/ui_scale-52,16))
    if transcript!=null:
        for child in transcript.find_children("*","Control",true,false):
            if child is DiceFace:child.custom_minimum_size=Vector2.ONE*36*ui_scale;child.queue_redraw()
class DiceFace extends Control:
    var face=1
    func _draw() -> void:
        draw_style_box(_style(),Rect2(Vector2.ZERO,size))
        var patterns={1:[Vector2.ZERO],2:[Vector2(-1,-1),Vector2(1,1)],3:[Vector2(-1,-1),Vector2.ZERO,Vector2(1,1)],4:[Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)],5:[Vector2(-1,-1),Vector2(1,-1),Vector2.ZERO,Vector2(-1,1),Vector2(1,1)],6:[Vector2(-1,-1),Vector2(1,-1),Vector2(-1,0),Vector2(1,0),Vector2(-1,1),Vector2(1,1)]}
        for point in patterns[face]:draw_circle(size*.5+point*size.x*.24,maxf(2,size.x*.055),Color("f0e8d9"))
    func _style() -> StyleBoxFlat:
        var style=StyleBoxFlat.new();style.bg_color=Color("182520");style.border_color=Color("d1ae75");style.set_border_width_all(1);style.set_corner_radius_all(3);return style

func set_options(rows: Array) -> void:
    super.set_options(rows)
    for i in choices.get_child_count():
        var row=rows[i];var button=choices.get_child(i)
        button.tooltip_text=str(row.get("tooltip",row.get("reason","")))
        if row.get("state","")=="visited":button.get_child(1).modulate.a=.68

func append_line(line: Dictionary) -> void:
    super.append_line(line)
    if not line.has("dice"):return
    var container=transcript.get_child(transcript.get_child_count()-1).get_child(0)
    var panel_style=container.get_parent().get_theme_stylebox("panel").duplicate()
    panel_style.border_color=Color("b3cbb0") if line.get("success",false) else Color("c98d75")
    container.get_parent().add_theme_stylebox_override("panel",panel_style)
    var pair=HBoxContainer.new();pair.add_theme_constant_override("separation",8);container.add_child(pair);container.move_child(pair,1)
    for face in line.dice:
        var die=DiceFace.new();die.face=int(face);die.custom_minimum_size=Vector2.ONE*36*ui_scale;die.mouse_filter=Control.MOUSE_FILTER_IGNORE;pair.add_child(die)
