extends RefCounted
var checks=[]
var failures=[]
var max_elbow=0.0
var max_wrist=0.0
var max_foot=0.0
func expect(value: bool,message: String) -> void:
    checks.append({"passed":value,"message":message})
    if not value:failures.append(message)
    print("R113_CHECK ",value," ",message)
func settle(game: Node3D) -> void:
    for frame in 150:
        var p=game.player;var d=p.map_doors
        if d.yielding113():d.advance_yield113(1.0/60)
        p.action.advance(1.0/60);d._physics_process(1.0/60)
        await game.get_tree().physics_frame
        if not d.busy() and p.action.state=="idle":return
func capture(game: Node3D,name: String) -> void:
    game.focus=game.player.global_position+Vector3.UP*.9;game.zoom=4;game._update_camera()
    for frame in 3:await game.get_tree().process_frame
    await RenderingServer.frame_post_draw
    expect(game.get_viewport().get_texture().get_image().save_png("res://qa/interactions113/"+name+".png")==OK,"capture "+name)
func joints(p: CharacterBody3D) -> void:
    for side in ["L","R"]:
        var j=p.avatar.arm_articulation.joints[side]
        var e=Vector3(j.elbow[0],j.elbow[1],j.elbow[2]);var w=Vector3(j.wrist[0],j.wrist[1],j.wrist[2])
        var a=p.avatar.arm_articulation
        max_elbow=maxf(max_elbow,(a._skin("UpperArm."+side)*e).distance_to(a._skin("Forearm."+side)*e))
        max_wrist=maxf(max_wrist,(a._skin("Forearm."+side)*w).distance_to(a._skin("Hand."+side)*w))
func run(game: Node3D) -> Dictionary:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/interactions113"))
    var p=game.player;var d=p.map_doors;var c=p.traversal
    load("res://personagem/revisao98.gd").new()._freeze98(game)
    game.get_node("Characters99").ambient_elapsed109=-100000
    d.set_physics_process(false);game.world_items.set_physics_process(false)
    if d.yielding113():d._end_yield113()
    d.active="";d.pending="";p.action.control_locked=false;p.combat.control_locked=false;p.action.cancel();c.reset_test()
    var inventory=p.bag_inventory.snapshot()
    var initial=d.snapshot()
    for id in initial.states:initial.states[id]=id.contains("/window/")
    d.apply_restore(initial)
    for data in d.doors.values():
        if data.get("kind","")=="window" or data.exterior:continue
        for opening in [true,false]:
            var pose: Transform3D=data.hinge.get_parent().global_transform*d._pose(data,.55)*data.body.transform*data.collider.transform
            p.restore_collision();p.global_position=Vector3(pose.origin.x,.258,pose.origin.z)
            await game.get_tree().physics_frame;await game.get_tree().physics_frame
            var start=p.global_position
            expect(d.request(data.id),"door request accepted from sweep "+data.id+" open="+str(opening))
            expect(d.yielding113(),"automatic collision-checked step starts")
            if d.yielding113():
                expect(not p.save_condition(),"save refuses unfinished door interaction")
                p.paused=true;d.advance_yield113(.2);d._physics_process(.2)
                expect(p.global_position==start,"pause freezes assisted step");p.paused=false
            await settle(game)
            expect(data.open==opening and not d.busy(),"door finishes after retreat "+data.id)
            expect(p.global_position.distance_to(start)>.15 and p.global_position.distance_to(start)<1.01,"retreat is short and uses movement")
            expect(not p.action.control_locked and not p.combat.control_locked,"player controls restored")
            if opening and data.id.contains("Q1"):await capture(game,"01_porta_aberta_com_recuo")
    # An actual world obstruction remains authoritative.
    var door=d.doors["H01/Hinge_BASE_PORTAL_D_Q1_LEAF_PIVOT"]
    var blocked_pose: Transform3D=door.hinge.get_parent().global_transform*d._pose(door,.55)*door.body.transform*door.collider.transform
    p.global_position=Vector3(blocked_pose.origin.x,.258,blocked_pose.origin.z)
    var blocker=StaticBody3D.new();var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.08,.3,.08);collider.shape=box;blocker.add_child(collider);game.add_child(blocker);blocker.global_position=blocked_pose.origin
    await game.get_tree().physics_frame;await game.get_tree().physics_frame
    var before=p.global_position
    expect(not d.request(door.id) and not d.yielding113() and p.global_position==before,"furniture obstruction never forces a door or teleports player")
    blocker.queue_free();await game.get_tree().physics_frame;await game.get_tree().physics_frame
    expect(d.request(door.id) and d.yielding113(),"assist can start again after obstruction removed")
    var esc=InputEventKey.new();esc.pressed=true;esc.physical_keycode=KEY_ESCAPE;d._unhandled_input(esc)
    expect(not d.yielding113() and not p.action.control_locked,"Escape cancels retreat without locking controls")
    var selected=[]
    for w in p.map_traversals.obstacles:
        if w.kind=="window" and w.opening_id in ["H01/window/01","H01/window/04"]:selected.append(w)
    for w in selected:
        var centre=w.base_center
        for fps in [30,60,120]:
            for side in [-1,1]:
                p.restore_collision();p.global_position=centre+w.normal*side*.35
                p.global_position.y=w.floor_at(p.global_position).position.y+.003
                await game.get_tree().physics_frame;await game.get_tree().physics_frame
                var effects=w.effects;var accepted=p.request_cross(w)
                expect(accepted,"window starts "+w.opening_id+" side="+str(side)+" fps="+str(fps))
                if not accepted:continue
                var last=p.global_position;var captured=false
                for frame in fps*5:
                    c.advance(1.0/fps);joints(p)
                    expect(p.global_position.distance_to(last)<.18,"continuous traversal root") if p.global_position.distance_to(last)>=.18 else null
                    last=p.global_position
                    if c.is_active() and c.state=="playing":
                        var sample=c.path.sample(c.id,c.cursor)
                        for foot in ["R","L"]:
                            var expected=c.anchor+c.basis*sample[foot]
                            var rig=p.avatar.skeleton
                            var actual=rig.to_global(rig.get_bone_global_pose(rig.find_bone("Foot."+foot)).origin)
                            max_foot=maxf(max_foot,actual.distance_to(expected))
                        if w.opening_id=="H01/window/04" and fps==60 and c.cursor>1.8 and not captured:
                            await capture(game,"02_janela_saida" if side==-1 else "03_janela_entrada");captured=true
                    await game.get_tree().physics_frame
                    if not c.is_active():break
                expect(not c.is_active() and c.effect_succeeded and w.effects==effects+1,"complete traversal applies once")
                expect(is_equal_approx(p.capsule.shape.height,1.84) and not p.action.control_locked,"landing restores standing capsule and controls")
                expect(w.base_center==centre and not w.mirrored113,"route reservation restores window anchor")
    expect(max_elbow<.025 and max_wrist<.015,"arm articulation preserved in original and mirrored animations")
    expect(max_foot<.04,"collision foot samples match animated feet")
    expect(p.bag_inventory.snapshot()==inventory,"inventory and manual positions unchanged")
    expect(game.zombie_world.saved.size()==480 and game.get_node("Characters99").actors.size()==9,"fixed population and nine characters preserved")
    var result={"passed":failures.is_empty(),"checks":checks,"failures":failures,"max_elbow_m":max_elbow,"max_wrist_m":max_wrist,"max_foot_error_m":max_foot}
    FileAccess.open("res://qa/interactions113/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R113_RESULT ",JSON.stringify(result));return result
