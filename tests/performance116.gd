extends "res://tests/fps115.gd"
var retained=[]
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/r116"))
    var baseline="--uncached116" in OS.get_cmdline_user_args();var label="uncached" if baseline else "cached"
    if baseline:
        # Isolate only the old repeated visibility work; keep all R116 fixes active.
        var script=load("res://personagem/mira_ambiente89.gd")
        var pattern=RegEx.new();pattern.compile("(?ms)^func _solid\\(.*?(?=^func |\\z)")
        var old=FileAccess.get_file_as_string("res://tests/fixtures116/mira_ambiente89_r115.txt")
        var found=pattern.search(old)
        if found==null:push_error("Missing visibility baseline");quit(1);return
        script.source_code=pattern.sub(script.source_code,found.get_string(),true)
        if script.reload()!=OK:quit(1);return
        retained.append(script)
    set_meta("demo95_fresh",true);set_meta("demo95_profile_override","res://qa/r116/performance_profile.json")
    game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
    while not game.demo_ready:await process_frame
    game.get_window().size=Vector2i(1280,720);Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    game.get_node("Characters99").ambient_elapsed109=-100000
    var p=game.player;p.scripted=true;p.command=Vector2.ZERO
    var pad=load("res://personagem/revisao91.gd").new()._field(game);p.global_position=pad;p.avatar.rotation.y=0
    p.bag_inventory.seeding=true;p.bag_inventory.add("pistol",1,"slot:main_hand");p.bag_inventory.seeding=false;p.weapons.sync()
    game.shoulder.scripted=true
    for i in 30:await process_frame
    if not game.shoulder.set_aim(true):push_error("Cannot enter benchmark aim");quit(1);return
    var until=Time.get_ticks_msec()+3000
    while Time.get_ticks_msec()<until:await process_frame
    var frames=[];until=Time.get_ticks_msec()+8000
    while Time.get_ticks_msec()<until:
        var t=Time.get_ticks_usec();await process_frame;frames.append((Time.get_ticks_usec()-t)/1000.0)
    var result={"variant":label,"frame":stats(frames),"samples":frames.size(),"population":game.zombie_world.saved.size(),"live_zombies":game.zombie_world.actors.size(),"player":[p.global_position.x,p.global_position.y,p.global_position.z],"holding":game.shoulder.holding,"progress":game.shoulder.progress,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}
    FileAccess.open("res://qa/r116/performance_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("PERFORMANCE116_DONE ",JSON.stringify(result));quit()
