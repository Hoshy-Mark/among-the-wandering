extends RefCounted
var checks=[]
func check(ok: bool,message: String) -> void:
    checks.append({"passed":ok,"message":message})
    if not ok:push_error(message)
func shadow_state(controller: Node3D) -> Array:
    var state=[]
    for home in controller.homes.values():
        if not is_instance_valid(home.instance) or not home.instance.is_inside_tree():continue
        for mesh in home.roofs+home.walls:state.append([mesh.visible,mesh.cast_shadow])
    return state
func compare_cutaway(game: Node3D) -> void:
    var script=GDScript.new();script.source_code=FileAccess.get_file_as_string("res://tests/fixtures115/residential_interiors_r114.txt")
    if script.reload()!=OK:check(false,"legacy cutaway compiles");return
    var marker=Node3D.new();game.add_child(marker)
    for controller in game.city.find_children("*","Node",true,false):
        if not "homes" in controller or not controller.has_method("_contains_unit"):continue
        var reference=script.new();game.add_child(reference);reference.set_process(false);reference.set_process_unhandled_key_input(false)
        reference.city=controller.city;reference.homes=controller.homes.duplicate(true);reference.review_focus=marker
        var old_focus=controller.review_focus;var old_forced=controller.forced_home;var old_cut=controller.review_cut
        controller.review_focus=marker
        var scenarios=[]
        for lot in controller.homes:
            var home=controller.homes[lot]
            if not is_instance_valid(home.instance) or not home.instance.is_inside_tree():continue
            if home.rule.has("units"):
                for unit in home.rule.units:
                    var b=unit.bounds
                    scenarios.append({"point":home.model.to_global(Vector3((b[0][0]+b[1][0])*.5,unit.floor_local_y+.1,(b[0][2]+b[1][2])*.5)),"forced":"","cut":false})
            else:
                var b=home.rule.interior_bounds
                scenarios.append({"point":home.model.to_global(Vector3((b[0][0]+b[1][0])*.5,home.rule.floor_local_y+.1,(b[0][2]+b[1][2])*.5)),"forced":"","cut":false})
            scenarios.append({"point":Vector3(-900,0,-900),"forced":lot,"cut":true})
            scenarios.append({"point":Vector3(-900,0,-900),"forced":"","cut":false})
            scenarios.append(scenarios[-1])
        var index=0
        for row in scenarios:
            marker.global_position=row.point;controller.forced_home=row.forced;reference.forced_home=row.forced;controller.review_cut=row.cut;reference.review_cut=row.cut
            controller._process(1.0/60);var actual=shadow_state(controller)
            reference._process(1.0/60);var expected=shadow_state(reference)
            check(actual==expected,"cutaway matches R114 %s scenario %d"%[controller.name,index]);index+=1
        # Civic adapters explicitly refresh after overriding upper-floor shadows.
        controller.forced_home="";controller.review_cut=false;reference.forced_home="";reference.review_cut=false
        marker.global_position=Vector3(-900,0,-900)
        controller._process(0);var state=shadow_state(controller);reference._process(0)
        check(state==shadow_state(reference),"explicit cutaway refresh matches R114 "+str(controller.name))
        controller.review_focus=old_focus;controller.forced_home=old_forced;controller.review_cut=old_cut;controller._process(0)
        reference.queue_free()
    marker.queue_free()
func run(game: Node3D) -> bool:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/performance114"))
    game.player.global_position=game.spawn;game.player.velocity=Vector3.ZERO
    game.zombie_world.restore(game.zombie_world.initial)
    load("res://personagem/revisao98.gd").new()._freeze98(game)
    for h in game.get_node("Characters99").actors.values():h.set_physics_process(false)
    var unit=load("res://tests/budget115.gd").new().run(game)
    check(unit.passed,"scheduler/spatial unit checks")
    compare_cutaway(game)
    var w=game.zombie_world;var original=w.snapshot();var id=w.model.definitions.keys()[0]
    w._activate(id);var actor=w.actors[id];actor.ai_enabled=false
    for i in 20:
        actor.global_position+=Vector3(.31,0,-.17);w.sync_actor(actor)
        var incremental=w.motor.cells.duplicate(true);w.motor.index_population()
        var same=true
        for cell in w.motor.cells:
            var a=incremental.get(cell,[]).duplicate();var b=w.motor.cells[cell].duplicate();a.sort();b.sort()
            if a!=b:same=false
        for cell in incremental:
            if not incremental[cell].is_empty() and not w.motor.cells.has(cell):same=false
        check(same,"live actor cell sync %d"%i)
    actor.health=0;actor.state="dead";w.sync_actor(actor)
    check(not w.motor.cells.values().any(func(ids):return id in ids),"dead actor leaves separation grid")
    w.restore(original)
    check(w.valid(w.snapshot()) and w.saved.size()==480,"all fixed population data restores after movement/death test")
    var social=game.get_node("Characters99").social.snapshot()
    var human=game.get_node("Characters99").actors.values()[0]
    var body_transform=human.global_transform;var before=human.avatar.clock
    var pending=human.visual_budget.pending;var manager=human.manager
    var was_paused=game.player.paused;game.player.paused=false
    var active=manager.active;manager.active=human.identity
    human._physics_process(1.0/60)
    check(absf(human.avatar.clock-before-pending-1.0/60)<.00001,"active dialogue immediately updates full pose and pending time")
    check(human.global_transform==body_transform and social==manager.social.snapshot(),"visual budgeting preserves collider and social state")
    game.player.paused=true;before=human.avatar.clock;human._physics_process(.5)
    check(human.avatar.clock==before and human.visual_budget.pending==0,"pause does not accumulate delayed animation")
    manager.active=active;game.player.paused=was_paused
    var gameplay=await load("res://tests/regression114.gd").new().run(game)
    check(gameplay,"save/load, doors, windows, fences and joint guards")
    var result={"passed":checks.all(func(v):return v.passed),"checks":checks,"unit_checks":unit.checks.size()}
    FileAccess.open("res://qa/fps115/regression.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("REGRESSION115 passed=",result.passed," checks=",checks.size()," unit=",unit.checks.size())
    return result.passed
