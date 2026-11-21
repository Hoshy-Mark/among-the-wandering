extends SceneTree
var game: Node3D
func _initialize() -> void:call_deferred("run")
func stats(values: Array) -> Dictionary:
    values.sort();var avg=values.reduce(func(a,b):return a+b,0.0)/values.size()
    return {"mean_ms":avg,"median_ms":values[values.size()/2],"p95_ms":values[mini(values.size()-1,int(values.size()*.95))],"fps_from_mean":1000/avg}
func sample(label: String,count: int=120) -> Dictionary:
    for i in 30:await process_frame
    var values=[];var physics=[];var process=[]
    for i in count:
        var start=Time.get_ticks_usec();await process_frame
        values.append((Time.get_ticks_usec()-start)/1000.0)
        physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
        process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
    var result={"label":label,"frame":stats(values),"physics":stats(physics),"process":stats(process),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"live_zombies":game.zombie_world.actors.size(),"humans":game.get_node("Characters99").actors.size(),"demo_state":game.player.get_node("Demo95").state}
    print("FPS115_SAMPLE ",JSON.stringify(result));return result
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/fps115"))
    set_meta("demo95_fresh",true);set_meta("demo95_profile_override","res://qa/fps115/checkpoint.json")
    game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
    while not game.demo_ready:await process_frame
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);game.get_window().size=Vector2i(1280,720)
    game.get_node("Characters99").ambient_elapsed109=-100000
    var until=Time.get_ticks_msec()+4000
    while Time.get_ticks_msec()<until:await process_frame
    var results=[];results.append(await sample("baseline"))
    var humans=game.get_node("Characters99").actors.values()
    for h in humans:h.set_physics_process(false)
    results.append(await sample("diagnostic_human_poses_frozen"))
    for h in humans:h.set_physics_process(true)
    game.zombie_world.set_physics_process(false);game.zombie_world.navigation.set_physics_process(false)
    results.append(await sample("diagnostic_population_simulation_frozen"))
    game.zombie_world.set_physics_process(true);game.zombie_world.navigation.set_physics_process(true)
    var interiors=[]
    for node in game.city.find_children("*","Node",true,false):
        if node.get_script()!=null and node.get_script().resource_path.get_file() in ["residential_interiors.gd","civic_interiors.gd","residential_services.gd"] and node.is_processing():interiors.append(node);node.set_process(false)
    results.append(await sample("diagnostic_interior_updates_frozen"))
    for node in interiors:node.set_process(true)
    game.city.hide();results.append(await sample("diagnostic_city_rendering_hidden"));game.city.show()
    results.append(await sample("baseline_repeat"))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/fps115"))
    FileAccess.open("res://qa/fps115/ablation.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":results},"  "))
    print("FPS115_DONE");quit()
