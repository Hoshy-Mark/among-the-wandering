extends SceneTree
func _initialize() -> void:
    for path in ["menu.gd","preferences.gd","projection.gd","exploration.gd","map_canvas.gd","qa.gd"]:
        var resource=load("res://personagem/menu107/"+path)
        assert(resource!=null,"parse "+path)
    print("MENU107_PARSE_OK");quit()
