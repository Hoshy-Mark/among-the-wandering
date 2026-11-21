extends "res://tests/performance115.gd"
func counts_stats(values: Array) -> Dictionary:
    var result=stats(values)
    return {"mean":result.mean_ms,"median":result.median_ms,"p95":result.p95_ms}
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/fps115"))
    var baseline="--baseline115" in OS.get_cmdline_user_args()
    var label="baseline" if baseline else "optimized"
    if baseline:
        for path in ["personagem/humano99.gd","personagem/motor_populacao98.gd","personagem/zumbis98.gd","staging/e06_world/arroio/scripts/residential_interiors.gd"]:
            var script=load("res://"+path);script.source_code=FileAccess.get_file_as_string("res://tests/fixtures115/"+path.get_file().get_basename()+"_r114.txt")
            if script.reload()!=OK:quit(1);return
            retained.append(script)
    set_meta("demo95_fresh",true);set_meta("demo95_profile_override","res://qa/fps115/checkpoint.json")
    game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
    while not game.demo_ready:await process_frame
    Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);game.get_window().size=Vector2i(1280,720)
    game.get_node("Characters99").ambient_elapsed109=-100000
    var w=game.zombie_world;var p=game.player
    w.restore(w.initial);w.model.clock=0;w.accumulator=0
    var pair=load("res://personagem/revisao98.gd").new()._pair98(game)
    if pair.is_empty():push_error("No fixed woodland location");quit(1);return
    p.global_position=pair.player;p.velocity=Vector3.ZERO
    # Six existing identities start at validated points in this QA scene only.
    # All 480 data records, normal simulation and normal activation policy remain active.
    var candidates=[]
    for id in w.saved:
        if w.model.definitions[id].cohort!="urban_roamers":continue
        candidates.append({"id":id,"distance":w.motor.point(w.saved[id].position).distance_squared_to(p.global_position)})
    candidates.sort_custom(func(a,b):return a.distance<b.distance)
    var fixtures=[];var data=w.initial.duplicate(true)
    for row in candidates.slice(0,6):
        var index=fixtures.size();var point: Variant=null
        for attempt in 36:
            var angle=TAU*(float(index)/6.0+float(attempt)*.027)
            var candidate=p.global_position+Vector3(cos(angle),0,sin(angle))*(4.0+attempt*.3)
            var floor=w.motor._floor(candidate)
            if floor!=null and w.motor._free(floor):point=floor;break
        if point==null:push_error("No valid stress-test point");quit(1);return
        data[row.id].position=w.motor.raw(point);data[row.id].last_known=w.motor.raw(p.global_position)
        data[row.id].state="chase";data[row.id].memory=4.0
        fixtures.append({"id":row.id,"point":w.motor.raw(point)})
    w.restore(data)
    var demo=p.get_node("Demo95");demo.set_physics_process(false);demo.grace=1000000
    var until=Time.get_ticks_msec()+3000
    while Time.get_ticks_msec()<until:await process_frame
    var frames=[];var counts=[];var draws=[];var primitives=[];var start=Time.get_ticks_usec()
    until=Time.get_ticks_msec()+8000
    while Time.get_ticks_msec()<until:
        var t=Time.get_ticks_usec();await process_frame
        frames.append((Time.get_ticks_usec()-t)/1000.0);counts.append(w.actors.size())
        draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    var result={"variant":label,"player":w.motor.raw(pair.player),"fixtures":fixtures,"frame":stats(frames),"samples":frames.size(),"duration_ms":(Time.get_ticks_usec()-start)/1000.0,"live_min":counts.min(),"live_max":counts.max(),"population":w.saved.size(),"humans":game.get_node("Characters99").actors.size(),"draw_calls":counts_stats(draws),"primitives":counts_stats(primitives),"qa_damage_immunity":true}
    FileAccess.open("res://qa/fps115/woodland_"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    await RenderingServer.frame_post_draw
    game.get_viewport().get_texture().get_image().save_jpg("res://qa/fps115/woodland_"+label+".jpg",.88)
    print("WOODLAND115_DONE ",JSON.stringify(result));quit()
