extends "res://tests/fps115.gd"
var retained=[]
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/fps115"))
    var baseline="--baseline115" in OS.get_cmdline_user_args()
    var label="baseline" if baseline else "optimized"
    if baseline:
        for path in ["personagem/humano99.gd","personagem/motor_populacao98.gd","personagem/zumbis98.gd","staging/e06_world/arroio/scripts/residential_interiors.gd"]:
            var script=load("res://"+path)
            script.source_code=FileAccess.get_file_as_string("res://tests/fixtures115/"+path.get_file().get_basename()+"_r114.txt")
            if script.reload()!=OK:quit(1);return
            retained.append(script)
    set_meta("demo95_fresh",true);set_meta("demo95_profile_override","res://qa/fps115/checkpoint.json")
    var started=Time.get_ticks_usec()
    game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
    while not game.demo_ready:await process_frame
    var startup_ms=(Time.get_ticks_usec()-started)/1000.0
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);game.get_window().size=Vector2i(1280,720)
    game.get_node("Characters99").ambient_elapsed109=-100000
    for i in 120:await process_frame
    var results=[];results.append(await sample("H01",240))
    await RenderingServer.frame_post_draw
    game.get_viewport().get_texture().get_image().save_jpg("res://qa/fps115/"+label+"_H01.jpg",.88)
    var p=game.player;var human=game.get_node("Characters99").actors.renata_volker
    p.global_position=human.global_position+Vector3(0,0,-3)
    p.velocity=Vector3.ZERO
    for i in 120:await process_frame
    results.append(await sample("near_humans",180))
    await RenderingServer.frame_post_draw
    game.get_viewport().get_texture().get_image().save_jpg("res://qa/fps115/"+label+"_near_humans.jpg",.88)
    var pair=load("res://personagem/revisao98.gd").new()._pair98(game)
    if pair.is_empty():push_error("No woodland benchmark location");quit(1);return
    # Keep AI, physics and render active. QA alone avoids dying during the sample.
    var demo=p.get_node("Demo95");demo.set_physics_process(false);demo.grace=1000000
    p.global_position=pair.player;p.velocity=Vector3.ZERO
    for i in 120:await process_frame
    results.append(await sample("woodland",180))
    await RenderingServer.frame_post_draw
    game.get_viewport().get_texture().get_image().save_jpg("res://qa/fps115/"+label+"_woodland.jpg",.88)
    var result={"variant":label,"startup_ms":startup_ms,"samples":results,"population":game.zombie_world.saved.size(),"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"resolution":[1280,720],"renderer":RenderingServer.get_current_rendering_method()}
    FileAccess.open("res://qa/fps115/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("PERFORMANCE115_DONE ",JSON.stringify(result))
    if "--verify115" in OS.get_cmdline_user_args():
        var passed=await load("res://tests/regression115.gd").new().run(game)
        quit(0 if passed else 1);return
    quit()
