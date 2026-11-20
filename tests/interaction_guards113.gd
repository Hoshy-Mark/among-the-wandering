extends RefCounted
func run(game: Node3D) -> Dictionary:
    var p=game.player;var c=p.traversal;var checks=[]
    var w=p.map_traversals.obstacles.filter(func(o):return o.opening_id=="H01/window/04")[0]
    var centre=w.base_center
    p.restore_collision();p.global_position=centre-w.normal*.35;p.global_position.y=w.floor_at(p.global_position).position.y+.003
    await game.get_tree().physics_frame;await game.get_tree().physics_frame
    var begun=p.request_cross(w);var cancelled=c.cancel() if begun else false
    checks.append({"passed":begun and cancelled and not c.is_active() and w.base_center==centre and w.owner_ref==null,"message":"window cancellation releases route and reservation"})
    var states=p.map_doors.snapshot();states.states[w.opening_id]=false;p.map_doors.apply_restore(states)
    checks.append({"passed":not p.request_cross(w) and not c.is_active(),"message":"closed window remains impassable"})
    states.states[w.opening_id]=true;p.map_doors.apply_restore(states)
    var block=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1.4,1.8,1.4);shape.shape=box;block.add_child(shape);game.add_child(block);block.global_position=centre+w.normal*.95+Vector3.UP*.7
    await game.get_tree().physics_frame;await game.get_tree().physics_frame
    var effects=w.effects
    checks.append({"passed":not p.request_cross(w) and not c.is_active() and w.effects==effects,"message":"occupied landing cannot be bypassed by route selection"})
    block.queue_free();await game.get_tree().physics_frame;await game.get_tree().physics_frame
    var crossed={}
    for fence in p.map_traversals.obstacles:
        if not fence.has_meta("fence78"):continue
        var kind="high" if fence.model.high else "low"
        if crossed.has(kind):continue
        p.condition_state.set_stamina(100)
        p.global_position=(fence.a+fence.b)*.5+fence.normal*.85;fence.locate(p)
        var floor=fence.floor_at(p.global_position)
        if floor.is_empty():continue
        p.global_position.y=floor.position.y+.003;p.restore_collision()
        await game.get_tree().physics_frame;await game.get_tree().physics_frame
        if not p.request_cross(fence):continue
        var before=fence.effects
        for frame in 600:
            c.advance(1.0/60);await game.get_tree().physics_frame
            if not c.is_active():break
        var ok=not c.is_active() and c.effect_succeeded and fence.effects==before+1
        crossed[kind]=ok
        checks.append({"passed":ok,"message":"existing "+kind+" fence traversal retained"})
    checks.append({"passed":crossed.get("low",false) and crossed.get("high",false),"message":"low and high fence regressions covered"})
    var result={"passed":checks.all(func(v):return v.passed),"checks":checks}
    FileAccess.open("res://qa/interactions113/guards.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R113_GUARDS ",JSON.stringify(result));return result
