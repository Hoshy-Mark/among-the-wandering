extends SceneTree
## Run with Godot 4.4.1: --path . --script res://tests/publication_smoke.gd -- --publication-smoke
var checks: Array[String]=[]
func verify(value: bool,message: String) -> void:
    if not value:
        push_error("PUBLICATION_R112_FAIL "+message)
        quit(1)
        assert(value,message)
    checks.append(message)
    print("PUBLICATION_R112_CHECK ",message)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    verify("--publication-smoke" in OS.get_cmdline_user_args(),"isolated publication test supplied")
    set_meta("demo95_fresh",true)
    set_meta("demo95_profile_override","res://qa/publication/checkpoint.json")
    var game=load("res://demo_inventory.tscn").instantiate()
    root.add_child(game)
    while not game.demo_ready:
        await process_frame
    for tick in range(5):await process_frame
    var p=game.player
    var m=game.get_node("Characters99")
    verify(game.demo_data.get("supply_revision112")==1,"R112 physical supply recipe starts from published project")
    verify(p.bag_inventory.items.size()==20 and p.bag_inventory.valid(p.bag_inventory.items),"complete inventory and authored cells valid")
    verify(p.bag_inventory.world_containers.values().all(func(entry):return entry.has("furniture")),"new game has physical sources without laboratory arsenals")
    verify(m.actors.size()==9 and m.social.data.relations.size()==90,"nine actors and directed social network loaded")
    verify(game.zombie_world.saved.size()==480,"fixed population loaded")
    verify(m.skills_ui.buttons.size()==4,"four skills and native menu loaded")
    verify(p.get_node("Atalhos93").view_r01!=null and m.view_d02!=null,"weapon HUD R01 and dialogue D02 loaded")
    verify(p.shoulder!=null and p.weapons!=null,"shoulder camera and weapon authority loaded")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/publication"))
    p.condition_path="res://qa/publication/checkpoint.json"
    var before=p.bag_inventory.snapshot()
    verify(p.save_condition(),"published project saves to isolated QA checkpoint")
    verify(p.load_condition(),"published project reloads complete campaign")
    var compare=load("res://personagem/revisao81.gd").new()
    verify(compare._same(p.bag_inventory.snapshot(),before),"save round trip preserves manual inventory")
    await RenderingServer.frame_post_draw
    verify(game.get_viewport().get_texture().get_image().save_png("res://qa/publication/gameplay.png")==OK,"real renderer gameplay capture saved")
    FileAccess.open("res://qa/publication/result.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks},"  "))
    quit()
