extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    set_meta("demo95_fresh",true)
    set_meta("demo95_profile_override","res://qa/interactions113/checkpoint.json")
    var game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
    while not game.demo_ready:await process_frame
    var main=await load("res://tests/interactions113.gd").new().run(game)
    var guards=await load("res://tests/interaction_guards113.gd").new().run(game)
    quit(0 if main.passed and guards.passed else 1)
