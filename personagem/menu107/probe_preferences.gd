extends SceneTree
func _initialize() -> void:
    var service=load("res://personagem/menu107/preferences.gd").new();service.path="res://qa/menu107/preferences.json";service.setup()
    var value=JSON.parse_string(FileAccess.get_file_as_string(service.path))
    print("VALID ",service.valid(value)," APPLIED ",service.applied)
    print("MODE ", value.mode in [0,1,2], " KEYS ",80.0 in [80]," equals ",80.0==80)
    print("DEFAULT ",service.defaults)
    quit()
