extends SceneTree
func _initialize() -> void:
    assert(load("res://personagem/menu108/menu.gd")!=null)
    assert(load("res://personagem/menu108/map_canvas.gd")!=null)
    print("MENU108_PARSE_OK");quit()
