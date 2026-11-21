extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var result=load("res://tests/budget115.gd").new().run(root)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/fps115"))
    FileAccess.open("res://qa/fps115/unit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("UNIT115 passed=",result.passed," checks=",result.checks.size())
    quit(0 if result.passed else 1)
