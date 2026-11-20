extends Control
var grid: Control

func _draw() -> void:
    if grid.preview_cell.x<0:
        return
    var step=grid.cell+4
    var rect=Rect2(Vector2(grid.preview_cell*step),Vector2(grid.preview_size*step)-Vector2(4,4))
    var color=Color("89b7a0") if grid.preview_valid else Color("c67b71")
    draw_rect(rect,Color(color,.25))
    draw_rect(rect,color,false,2)
    draw_string(ThemeDB.fallback_font,rect.position+Vector2(7,18),"Juntar" if grid.preview_merge else "+" if grid.preview_valid else "×",HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
