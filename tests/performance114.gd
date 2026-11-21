extends SceneTree
var start114=0
var samples114=[]
var instrumented114=[]
func _initialize() -> void:call_deferred("run")
func instrument114(path: String,method: String) -> void:
    var script=load(path)
    var source: String=script.source_code.replace("\t","    ")
    var pattern=RegEx.new();pattern.compile("(?m)^func "+method+"\\(([^\\n]*)\\)([^\\n:]*):")
    var found=pattern.search(source)
    if found==null:print("PERF114_SKIPPED ",path," ",method);return
    var signature=found.get_string(1);var result_type=found.get_string(2)
    var args=[]
    for item in signature.split(","):
        if not item.strip_edges().is_empty():args.append(item.strip_edges().get_slice(":",0).get_slice("=",0).strip_edges())
    source=source.substr(0,found.get_start())+found.get_string().replace("func "+method+"(","func _measured114_"+method+"(")+source.substr(found.get_end())
    var key=path.get_file()+"/"+method
    var call="_measured114_"+method+"("+", ".join(args)+")"
    var returning=result_type.contains("->") and not result_type.contains("void")
    source+="\nfunc "+method+"("+signature+")"+result_type+":\n    var t114=Time.get_ticks_usec()\n"
    source+="    var value114="+call+"\n" if returning else "    "+call+"\n"
    source+="    var elapsed114=Time.get_ticks_usec()-t114\n    var metrics114=Engine.get_main_loop().get_meta(\"perf114\")\n"
    source+="    var key114=\""+key+"\""+("+\"[\"+str(name)+\"]\"" if method=="catalog" else "")+"\n"
    source+="    if not metrics114.has(key114):metrics114[key114]={\"calls\":0,\"usec\":0,\"max_usec\":0}\n"
    source+="    metrics114[key114].calls+=1;metrics114[key114].usec+=elapsed114;metrics114[key114].max_usec=maxi(metrics114[key114].max_usec,elapsed114)\n"
    if returning:source+="    return value114\n"
    script.source_code=source
    assert(script.reload()==OK,path)
    instrumented114.append(script)
func statistics114(values: Array) -> Dictionary:
    values.sort()
    return {"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"mean":values.reduce(func(a,b):return a+b,0.0)/values.size()}
func run() -> void:
    var label="optimized" if "--perf114-optimized" in OS.get_cmdline_user_args() else "baseline"
    set_meta("perf114",{});set_meta("demo95_fresh",true);set_meta("demo95_profile_override","res://qa/performance114/checkpoint.json")
    var base="res://staging/e06_world/arroio/scripts/"
    if label=="baseline":
        for item in [[base+"city.gd","res://tests/fixtures114/city_before.gd"],["res://personagem/maos.gd","res://tests/fixtures114/hands_before.gd"]]:
            var original=load(item[0]);original.source_code=FileAccess.get_file_as_string(item[1]);assert(original.reload()==OK);instrumented114.append(original)
    for item in [["city.gd","catalog"],["city.gd","_ready"],["static_visual_batcher.gd","_prepare"],["city.gd","set_static_render_batching"],["residential_interiors.gd","configure"],["civic_interiors.gd","configure"],["landscape_layer.gd","configure"],["urban_components.gd","configure"],["ground_cover.gd","configure"],["lot_art_overrides.gd","configure"],["master_lot_layer.gd","configure"],["h11_h20_layer.gd","configure"],["h21_h30_layer.gd","configure"],["h31_h40_layer.gd","configure"],["current_h01_h20_layer.gd","configure"],["lrp01_layer.gd","configure"],["lrp02_layer.gd","configure"],["rural_layer.gd","configure"],["rural_network_layer.gd","configure"],["z2_finish.gd","configure"]]:instrument114(base+item[0],item[1])
    for item in [[base+"residential_interiors.gd","_process"],[base+"civic_interiors.gd","_process"],[base+"residential_services.gd","_process"],[base+"landscape_layer.gd","_process"],["res://personagem/humano99.gd","_physics_process"],["res://personagem/personagem_base.gd","advance"],["res://personagem/zumbis98.gd","_physics_process"],["res://personagem/navegacao98.gd","_physics_process"]]:instrument114(item[0],item[1])
    start114=Time.get_ticks_usec()
    var game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
    while not game.demo_ready:await process_frame
    var startup_ms=(Time.get_ticks_usec()-start114)/1000.0
    print("PERF114_READY ",label," ",startup_ms,"ms")
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    game.get_window().size=Vector2i(1280,720)
    game.get_node("Characters99").ambient_elapsed109=-100000
    var until=Time.get_ticks_usec()+5_000_000
    while Time.get_ticks_usec()<until:await process_frame
    var metrics114=get_meta("perf114")
    for key in metrics114.keys():
        if key.ends_with("/_process") or key.ends_with("/_physics_process") or key.ends_with("/advance"):metrics114.erase(key)
    var frames=[];var process_times=[];var physics=[];var draws=[];var triangles=[]
    for frame in 240:
        var t=Time.get_ticks_usec();await process_frame
        frames.append((Time.get_ticks_usec()-t)/1000.0)
        process_times.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
        physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
        draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        triangles.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    var result={"label":label,"startup_ms":startup_ms,"frame_ms":statistics114(frames),"process_ms":statistics114(process_times),"physics_ms":statistics114(physics),"draw_calls":statistics114(draws),"primitives":statistics114(triangles),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"node_count":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"stages":get_meta("perf114"),"batching":game.city.static_batcher.stats,"population":game.zombie_world.saved.size(),"live_zombies":game.zombie_world.actors.size(),"humans":game.get_node("Characters99").actors.size(),"demo_state":game.player.get_node("Demo95").state,"resolution":[1280,720]}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/performance114"))
    FileAccess.open("res://qa/performance114/"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    await RenderingServer.frame_post_draw
    game.get_viewport().get_texture().get_image().save_png("res://qa/performance114/"+label+".png")
    print("PERF114_DONE ",JSON.stringify(result))
    if "--perf114-verify" in OS.get_cmdline_user_args():
        var verified=await load("res://tests/regression114.gd").new().run(game)
        quit(0 if verified else 1);return
    quit()
