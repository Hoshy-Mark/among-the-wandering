extends "res://personagem/revisao94.gd"
func _details94(z: Node3D) -> Dictionary:
    return {"id":z.identity,"state":z.state,"pos":str(z.global_position),"memory":z.memory,"search":z.search_remaining,"path":z.path_pending,"route":str(z.route.slice(0,2)),"message":z.crossing.message,"result":z.crossing_result,"stats":z.navigation_stats,"blocked":z.blocked_portals,"wait":z.portal_wait,"sees":z.sees_player()}
func run(scene: Node3D) -> void:
    var p=scene.player;var nav=scene.zombie_world.navigation;var a=scene.zombie_world.actors.values()[0];var b=scene.zombie_world.actors.values()[1]
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false);scene.set_process(false)
    for actor in [a,b]:actor.ai_enabled=false
    var fence: Node3D
    for obstacle in p.map_traversals.obstacles:
        if obstacle.has_meta("fence78") and not obstacle.model.high and obstacle.a.distance_to(obstacle.b)>6:fence=obstacle;break
    assert(fence!=null);p.global_position=Vector3(1000,0,1000)
    await _place83(scene,a,fence,-1)
    var start=a.global_position;var goal=nav.project(fence.base_center+fence.normal*3)
    _reset(scene,a,start,goal);_reset(scene,b,nav.project(start-fence.normal*1.1),goal);p.global_position=goal
    print("FILA94 start ",start," goal ",goal," normal ",fence.normal)
    a.ai_enabled=true;b.ai_enabled=true
    var minimum=100.0
    for frame in 1100:
        await scene.get_tree().physics_frame
        if not a.crossing.is_active() and not b.crossing.is_active():minimum=minf(minimum,a.global_position.distance_to(b.global_position))
        if frame%120==0:print("FILA94 ",frame," ",_details94(a)," ",_details94(b))
        if a.crossing_result.get("success",false) and b.crossing_result.get("success",false):break
    a.ai_enabled=false;b.ai_enabled=false
    print("FILA94_FINAL ",_details94(a)," ",_details94(b)," min ",minimum)
    assert(a.crossing_result.get("success",false) and b.crossing_result.get("success",false) and minimum>.43)
    var waiting=a.queue_wait_steps94+b.queue_wait_steps94
    var backoff=await _backoff94(scene,a,b,fence,goal)
    helper._write("res://qa/queue94.json",{"both_crossed":true,"minimum_actor_gap":minimum,"waiting_steps":waiting,"retreat_room_preserved":true,"backoff_steps":backoff.steps,"backoff_distance":backoff.distance})
    print("R94_QUEUE_OK");scene.get_tree().quit()

func _backoff94(scene: Node3D,a: CharacterBody3D,b: CharacterBody3D,fence: Node3D,goal: Vector3) -> Dictionary:
    b.global_position=Vector3(1000,0,1000);scene.player.global_position=Vector3(1003,0,1000)
    await _place83(scene,a,fence,-1);scene.player.global_position=goal
    assert(a.request_cross(fence));var entry=a.crossing._position(0)
    for frame in 240:
        await scene.get_tree().physics_frame;a.crossing.advance(1.0/60)
        if a.global_position.distance_to(entry)>.55:break
    assert(a.crossing.is_active())
    var forward=goal-entry;forward.y=0;forward=forward.normalized()
    b.restore(scene.zombie_world.initial[b.identity]);b.ai_enabled=false;b.global_position=entry-forward*.25;b.avatar.rotation.y=atan2(forward.x,forward.z)
    b.state="search";b.memory=4;b.search_remaining=12;b.last_known=goal
    var distance=0.0
    for frame in 180:
        await scene.get_tree().physics_frame;b.step(1.0/60)
        distance=b.global_position.distance_to(entry)
        if distance>=.90 and b.queue_backoffs94>0:break
    assert(b.queue_backoffs94>0 and distance>=.88,str([distance,b.queue_backoffs94,_details94(b)]))
    a.crossing.reset_test();return {"steps":b.queue_backoffs94,"distance":distance}
