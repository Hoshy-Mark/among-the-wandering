extends "res://personagem/revisao83.gd"
var helper=load("res://personagem/revisao81.gd").new()
var boxes=[]
var outcomes=[]
var capture_name=""
var capture_frame=0
func _box(scene: Node3D,point: Vector3,size: Vector3) -> StaticBody3D:
    var body=StaticBody3D.new();body.collision_layer=1
    var shape=BoxShape3D.new();shape.size=size
    var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
    var mesh=MeshInstance3D.new();var cube=BoxMesh.new();cube.size=size;mesh.mesh=cube
    var material=StandardMaterial3D.new();material.albedo_color=Color("645d51");mesh.material_override=material;body.add_child(mesh)
    scene.add_child(body);body.global_position=point;boxes.append(body);return body
func _clear_boxes(scene: Node3D) -> void:
    for box in boxes:
        if is_instance_valid(box):box.queue_free()
    boxes.clear()
    for frame in 2:await scene.get_tree().physics_frame
func _field(scene: Node3D) -> Vector3:
    var nav=scene.zombie_world.navigation
    for x in range(-12,13,2):
        for z in range(-20,-7,2):
            var raw=scene.world_items.house.home.model.to_global(Vector3(x,0,z))
            var point=nav.project(raw)
            if point==null:continue
            var clear=true
            for dx in range(-2,3):
                for dz in range(-2,6):
                    var sample=nav.project(point+Vector3(dx,0,dz))
                    if sample==null or absf(sample.y-point.y)>.02 or not nav.free_at(sample):clear=false;break
                if not clear:break
            if clear:return point
    assert(false,"No navigation test field");return Vector3.ZERO
func _reset(scene: Node3D,z: CharacterBody3D,point: Vector3,goal: Vector3) -> void:
    z.ai_enabled=false;z.restore(scene.zombie_world.initial[z.identity]);z.global_position=point;z.avatar.rotation.y=0
    z.state="search";z.memory=4;z.search_remaining=12;z.last_known=goal
    z.cross_delay=0;z.crossing_result={}
func _plan(scene: Node3D,z: CharacterBody3D,goal: Vector3) -> Array:
    z.clear_route();z.replan_delay=0;z.ensure_route(goal)
    for frame in 900:
        await scene.get_tree().physics_frame
        if not z.path_pending:break
    assert(not z.path_pending,"Planner timeout")
    return z.route.duplicate()
func _follow(scene: Node3D,z: CharacterBody3D,goal: Vector3,limit: int=1000) -> Dictionary:
    var start=z.global_position;var max_x=0.0;var min_z=0.0
    z.ai_enabled=true
    for frame in limit:
        await scene.get_tree().physics_frame
        max_x=maxf(max_x,absf(z.global_position.x-start.x));min_z=minf(min_z,z.global_position.z-start.z)
        if not capture_name.is_empty() and frame%4==0:
            await _capture84(scene,capture_name+"/%03d"%capture_frame);capture_frame+=1
        if z.global_position.distance_to(goal)<1.03:break
    z.ai_enabled=false
    return {"reached":z.global_position.distance_to(goal)<1.03,"sideways":max_x,"backwards":min_z,"stats":z.navigation_stats.duplicate(true)}
func _verify_segments(nav: Node3D,start: Vector3,route: Array) -> void:
    var point=start
    for step in route:
        if step.kind=="walk":
            if not nav.walk_clear(point,step.point):print("BAD_SEGMENT84 ",point," to ",step.point)
            assert(nav.walk_clear(point,step.point),"Route cut a solid corner")
            point=step.point
        else:point=step.exit
func run(scene: Node3D) -> void:
    var world=scene.zombie_world;var nav=world.navigation;var p=scene.player
    var z=world.actors.values()[0];var other=world.actors.values()[1]
    for actor in world.actors.values():actor.ai_enabled=false
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    scene.get_window().size=Vector2i(1440,900)
    p.condition_path="user://qa_navigation94.json"
    if "--navigation-reopen" in OS.get_cmdline_user_args():
        assert(p.load_condition(),p.inventory_message)
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/navigation94_expected.json"))
        assert(helper._same(p.session_save.snapshot(),expected))
        assert(z.route.is_empty() and not z.path_pending)
        assert(not (await _plan(scene,z,z.last_known)).is_empty(),"Fresh route was not rebuilt")
        z.clear_route()
        print("R94_NAV_FRESH_PROCESS_OK");scene.get_tree().quit();return
    other.global_position=Vector3(1000,0,1000)
    var pad=_field(scene);var goal=pad+Vector3(0,0,4)
    p.global_position=goal
    # A U-shaped solid obstacle requires first walking away from the target.
    _box(scene,pad+Vector3(0,1.2,1),Vector3(2.8,2.4,.15))
    _box(scene,pad+Vector3(-1.4,1.2,.05),Vector3(.15,2.4,1.9))
    _box(scene,pad+Vector3(1.4,1.2,.05),Vector3(.15,2.4,1.9))
    for frame in 2:await scene.get_tree().physics_frame
    _reset(scene,z,pad,pad+Vector3(0,0,1))
    assert((await _plan(scene,z,z.last_known)).is_empty(),"Occupied goal was accepted")
    _reset(scene,z,pad,goal)
    p.paused=true
    z.ensure_route(goal)
    for frame in 3:await scene.get_tree().physics_frame
    assert(z.path_pending and nav.jobs[0].expanded==0)
    p.paused=false
    var route=await _plan(scene,z,goal)
    assert(not route.is_empty(),str(z.navigation_stats))
    _verify_segments(nav,z.global_position,route)
    if "--capture-zombie-navigation" in OS.get_cmdline_user_args():
        scene.set_process(false);_camera84(scene,pad+Vector3(0,.9,1),8,Vector3(-6,6,-8));capture_name="u";capture_frame=0
        await _capture84(scene,"u_start")
    var u=await _follow(scene,z,goal)
    if not capture_name.is_empty():await _capture84(scene,"u_end")
    capture_name=""
    print("U84 ",u)
    assert(u.reached and u.sideways>1.55 and u.backwards<-.9,"Did not escape U trap")
    outcomes.append({"name":"u_trap","result":u})
    await _clear_boxes(scene)
    # New collision invalidates an already planned straight route.
    _reset(scene,z,pad,goal);p.global_position=goal
    assert(not (await _plan(scene,z,goal)).is_empty())
    var ticket=z.path_ticket
    _box(scene,pad+Vector3(0,1.2,1.8),Vector3(3,2.4,.2))
    for frame in 2:await scene.get_tree().physics_frame
    if "--capture-zombie-navigation" in OS.get_cmdline_user_args():
        _camera84(scene,pad+Vector3(0,.9,1.5),7,Vector3(-4,4,6));capture_name="dynamic";capture_frame=0
    var dynamic=await _follow(scene,z,goal)
    capture_name=""
    assert(dynamic.reached and dynamic.sideways>1.65 and z.path_ticket>ticket)
    outcomes.append({"name":"dynamic_block","result":dynamic})
    await _clear_boxes(scene)
    # A nearby hidden player is not tracked at their new unseen position.
    _reset(scene,z,pad,goal);p.global_position=pad+Vector3(0,0,30)
    z.ai_enabled=true
    for frame in 20:await scene.get_tree().physics_frame
    z.ai_enabled=false
    assert(z.last_known==goal and z.search_remaining<12 and z.search_remaining>10)
    z.search_remaining=.01;z.step(.02)
    assert(z.memory==0 and z.state=="idle" and z.route.is_empty() and not z.path_pending)
    # Only open doors may form walk connections; choose a closed bathroom.
    var all_closed=p.map_doors.snapshot()
    for key in all_closed.states:all_closed.states[key]=false
    p.map_doors.apply_restore(all_closed)
    for frame in 2:await scene.get_tree().physics_frame
    var door_id="H01/Hinge_BASE_PORTAL_D_WC_LEAF_PIVOT"
    var data: Dictionary=p.map_doors.doors[door_id]
    var pose: Transform3D=data.hinge.get_parent().global_transform*p.map_doors._pose(data,0)*data.body.transform*data.collider.transform
    var normal=(pose.basis.x if data.collider.shape.size.x<data.collider.shape.size.z else pose.basis.z).normalized()
    var a=nav.project(Vector3(pose.origin.x,scene.spawn.y,pose.origin.z)+normal*.85)
    var b=nav.project(Vector3(pose.origin.x,scene.spawn.y,pose.origin.z)-normal*.85)
    assert(a!=null and b!=null and nav.free_at(a) and nav.free_at(b),"Door endpoints unavailable")
    p.global_position=Vector3(1000,0,1000);_reset(scene,z,a,b)
    var closed_route=await _plan(scene,z,b)
    assert(closed_route.is_empty(),"Closed door unexpectedly reachable")
    var door_open=all_closed.duplicate(true);door_open.states[door_id]=true;p.map_doors.apply_restore(door_open)
    for frame in 2:await scene.get_tree().physics_frame
    var open_route=await _plan(scene,z,b)
    print("DOOR84 ",z.navigation_stats)
    assert(not open_route.is_empty(),"Open door route missing "+str(z.navigation_stats))
    _verify_segments(nav,z.global_position,open_route)
    # Discover an open window from a point laterally outside the old local radius.
    var window: Node3D
    var fence: Node3D
    for obstacle in p.map_traversals.obstacles:
        if obstacle.kind=="window" and obstacle.opening_id=="H01/window/01":window=obstacle
        if fence==null and obstacle.has_meta("fence78") and not obstacle.model.high and obstacle.a.distance_to(obstacle.b)>6:fence=obstacle
    assert(window!=null and fence!=null)
    var windows_open=all_closed.duplicate(true);windows_open.states[window.opening_id]=true;p.map_doors.apply_restore(windows_open)
    for frame in 2:await scene.get_tree().physics_frame
    var entry_side=1
    for side in [-1,1]:
        var floor=nav.project(window.base_center+window.normal*side*.85)
        if floor!=null and floor.y<.1:entry_side=side
    var start=nav.project(window.base_center+window.normal*entry_side*.85)
    goal=_window_goal(nav,window,entry_side)
    assert(start!=null and goal!=null)
    var tangent=window.normal.cross(Vector3.UP)
    var distant: Variant=null
    for offset in [2.0,-2.0,2.6,-2.6]:
        var point=nav.project(start+tangent*offset)
        if point!=null and nav.free_at(point):distant=point;break
    assert(distant!=null)
    _reset(scene,z,distant,goal);p.global_position=goal
    route=await _plan(scene,z,goal)
    print("WINDOW_ROUTE84 ",z.navigation_stats," portals ",route.filter(func(step):return step.kind=="portal").size())
    assert(route.any(func(step):return step.kind=="portal" and step.source==window))
    _verify_segments(nav,z.global_position,route)
    if "--capture-zombie-navigation" in OS.get_cmdline_user_args():
        _camera84(scene,window.base_center+Vector3.UP*.9,5,Vector3(-4,3,5));capture_frame=0
    z.ai_enabled=true
    for frame in 900:
        await scene.get_tree().physics_frame
        if "--capture-zombie-navigation" in OS.get_cmdline_user_args() and frame%4==0:
            await _capture84(scene,"window/%03d"%capture_frame);capture_frame+=1
        if z.crossing_result.get("success",false):break
    z.ai_enabled=false
    assert(z.crossing_result.get("success",false),"Did not approach and traverse window")
    # Two actors use planned crossings without overlapping or sharing a reservation.
    p.global_position=Vector3(1000,0,1000)
    await _place83(scene,z,fence,-1)
    start=z.global_position
    goal=nav.project((fence.a+fence.b)*.5+fence.normal*3.0)
    assert(goal!=null and nav.free_at(goal))
    _reset(scene,z,start,goal)
    var trailing=nav.project(start-fence.normal*1.1)
    assert(trailing!=null)
    _reset(scene,other,trailing,goal);p.global_position=goal
    if "--capture-zombie-navigation" in OS.get_cmdline_user_args():
        _camera84(scene,fence.base_center+Vector3.UP*.9,6.3,Vector3(-4,3,5));capture_frame=0
    z.ai_enabled=true;other.ai_enabled=true
    var min_distance=INF
    for frame in 1100:
        await scene.get_tree().physics_frame
        if not z.crossing.is_active() and not other.crossing.is_active():min_distance=minf(min_distance,z.global_position.distance_to(other.global_position))
        if "--capture-zombie-navigation" in OS.get_cmdline_user_args() and frame%4==0:
            await _capture84(scene,"queue/%03d"%capture_frame);capture_frame+=1
        if z.crossing_result.get("success",false) and other.crossing_result.get("success",false):break
    z.ai_enabled=false;other.ai_enabled=false
    print("QUEUE84 ",z.crossing_result," ",other.crossing_result," distance ",min_distance)
    assert(z.crossing_result.get("success",false) and other.crossing_result.get("success",false) and min_distance>.43)
    # Stable state and the bounded search timer roundtrip; routes are rebuilt.
    p.global_position=scene.spawn;p.velocity=Vector3.ZERO;p.action.cancel();p.reaction.reset();p.map_combat.pending_reaction="";p.combat.set_guard(false)
    _reset(scene,z,pad,pad+Vector3(0,0,4));z.memory=3;z.search_remaining=7.25;z.state="search"
    other.restore(world.initial[other.identity])
    p.map_combat.pending_reaction="hit_front"
    assert(not p.save_condition() and not p.load_condition())
    p.map_combat.pending_reaction=""
    assert(p.save_condition(),p.inventory_message+" "+p.session_save.reason)
    var saved=p.session_save.snapshot()
    z.search_remaining=1;z.clear_route()
    assert(p.load_condition() and is_equal_approx(z.search_remaining,7.25) and z.route.is_empty())
    assert(not (await _plan(scene,z,z.last_known)).is_empty())
    z.clear_route()
    if FileAccess.file_exists(p.condition_path+".bak"):DirAccess.remove_absolute(p.condition_path+".bak")
    var bad=saved.duplicate(true);bad.enemies82[z.identity].search_remaining84=-1
    helper._write(p.condition_path,bad);var before=p.session_save.snapshot()
    assert(not p.load_condition() and helper._same(before,p.session_save.snapshot()))
    var legacy=saved.duplicate(true)
    for entry in legacy.enemies82.values():entry.erase("search_remaining84")
    helper._write(p.condition_path,legacy)
    assert(p.load_condition() and is_equal_approx(z.search_remaining,9))
    helper._write(p.condition_path,saved);assert(p.load_condition())
    helper._write("res://qa/navigation94_expected.json",p.session_save.snapshot())
    var checks={"scenarios":outcomes,"u_trap":true,"occupied_goal_refused":true,"paused_planner":true,"dynamic_replan":true,"solid_segments":true,"last_known_only":true,"search_expires":true,"closed_door_refused":true,"open_door":true,"distant_window_route":true,"two_actor_queue":true,"minimum_actor_distance":min_distance,"search_timer_roundtrip":true,"invalid_atomic":true,"pending_reaction_blocks_save":true,"r83_migration":true,"transient_route_rebuilt":true,"max_navigation_slice_us":nav.max_slice_us}
    helper._write("res://qa/navigation94.json",checks)
    print("R94_NAVIGATION_OK ",checks)
    scene.get_tree().quit()

func _window_goal(nav: Node3D,window: Node3D,side: int) -> Vector3:
    for distance in [1.5,1.7,2.0,2.3]:
        for lateral in [0,-.4,.4]:
            var point=nav.project(window.base_center-window.normal*side*distance+window.normal.cross(Vector3.UP)*lateral)
            if point!=null and nav.free_at(point):return point
    assert(false,"No free window goal");return Vector3.ZERO

func _camera84(scene: Node3D,point: Vector3,size: float,offset: Vector3) -> void:
    scene.camera.size=size;scene.camera.global_position=point+offset;scene.camera.look_at(point)
func _capture84(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/navigation94/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
