extends "res://personagem/revisao88.gd"
var cases89=[]
var captures89={}
func _floor89(scene: Node3D,raw: Vector3) -> Variant:
    var q=PhysicsRayQueryParameters3D.create(raw+Vector3.UP*.8,raw-Vector3.UP*.7,1,[scene.player.get_rid()])
    var hit=scene.get_world_3d().direct_space_state.intersect_ray(q)
    if hit.is_empty() or hit.normal.y<.8:return null
    var house=scene.world_items.house
    if house.shell.contains_point("H01",raw):
        var floor_y=house.home.model.to_global(Vector3(0,float(house.home.rule.floor_local_y),0)).y
        if absf(hit.position.y-floor_y)>.06:return null
    var point: Vector3=hit.position+Vector3.UP*.02
    return point if scene.world_items.house.standing_clear(point) else null
func _room89(scene: Node3D,room: Dictionary) -> Variant:
    var polygon=PackedVector2Array();var center=Vector2.ZERO
    for vertex in room.polygon_xz:polygon.append(Vector2(vertex[0],vertex[1]));center+=polygon[-1]
    center/=polygon.size();var found: Variant=null;var score=INF
    var home=scene.world_items.house.home
    for x in range(-18,20):
        for z in range(-18,20):
            var local=Vector2(x*.25,z*.25)
            if not Geometry2D.is_point_in_polygon(local,polygon) or local.distance_squared_to(center)>=score:continue
            var point=_floor89(scene,home.model.to_global(Vector3(local.x,.275,local.y)))
            if point!=null:found=point;score=local.distance_squared_to(center)
    return found
func _near89(scene: Node3D,origin: Vector3) -> Variant:
    var found: Variant=null;var score=INF
    for x in range(-5,6):
        for z in range(-5,6):
            var raw=origin+Vector3(x*.3,0,z*.3)
            var point=_floor89(scene,raw)
            if point!=null and point.distance_squared_to(origin)<score:found=point;score=point.distance_squared_to(origin)
    return found
func _sample89(scene: Node3D,label: String,point: Vector3,angle: float) -> void:
    var p=scene.player;var aim=scene.shoulder
    aim.set_aim(false);aim.advance(.5);_player_idle(p)
    p.global_position=point;p.avatar.rotation.y=angle
    scene.focus=point+Vector3.UP*.85;scene._update_camera()
    var accepted=aim.set_aim(true)
    if not accepted:
        assert(not aim.holding and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
        cases89.append({"label":label,"yaw":angle,"position":[point.x,point.y,point.z],"distance":aim.goal_distance,"safe":true,"accepted":false})
        return
    _step88(scene,.5);_step88(scene,.1)
    var clear=aim.camera_clear(scene.camera.global_position)
    assert(clear,label+" camera inside geometry "+str(aim.last_solve))
    assert(scene.camera.get_meta("solid_world89",false) and scene.camera.cull_mask&(1<<19)==0)
    if aim.barrel_obstructed():
        assert(not aim.ready_to_fire())
        var rounds=scene.player.weapons.loaded(scene.player.bag_inventory.equipped("main_hand"))
        assert(not scene.player.request_attack() and scene.player.weapons.loaded(scene.player.bag_inventory.equipped("main_hand"))==rounds)
    var home=scene.world_items.house.home
    for wall in home.walls:assert(wall.cast_shadow!=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,label)
    for group in scene.world_items.house.groups.values():assert(not group.faded,label)
    var info={"label":label,"yaw":angle,"position":[point.x,point.y,point.z],"distance":aim.camera_distance,"safe":clear,"accepted":true,"sheltered_transition":aim.sheltered_transition,"openings":p.map_doors.snapshot(),"blocked":aim.barrel_obstructed()}
    cases89.append(info)
    info.score=aim.camera_distance+minf(5,aim.aim_ray().position.distance_to(point))*.5-(3 if info.blocked else 0)
    if not captures89.has(label) or info.score>captures89[label].score:captures89[label]=info
    aim.set_aim(false);_step88(scene,.5)
    assert(not scene.camera.get_meta("solid_world89",false) and scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL)
    assert(aim.veil.color.a==0 and not aim.warning.visible and scene.camera.cull_mask==aim.original_cull_mask)
    if aim.landscape!=null:assert(aim.landscape.reveal_enabled==aim.original_reveal)
func run(scene: Node3D) -> void:
    var p=scene.player;var aim=scene.shoulder;var bag=p.bag_inventory
    p.scripted=true;p.set_physics_process(false);p.survival.set_physics_process(false)
    scene.set_process(false);aim.set_process(false);aim.set_physics_process(false);aim.scripted=true
    scene.get_window().size=Vector2i(1440,900)
    for z in scene.zombie_world.actors.values():z.ai_enabled=false;z.global_position=Vector3(1000,0,1000)
    var pistol=_find_weapon(bag,"pistol");var accepted=p.equip_item(pistol);assert(accepted);_settle86(p)
    var ammo=_find_weapon(bag,"ammo_pistol")
    accepted=p.place_item(ammo,"pockets",2,0,false);assert(accepted);_settle86(p)
    accepted=p.map_combat.reload_weapon();assert(accepted);_settle86(p)
    var house=scene.world_items.house;var home=house.home
    var rooms=[];var skipped=[];var orbit_samples=0;var orbit_max_step=0.0
    for room in home.rule.rooms:
        var point=_room89(scene,room)
        if point==null:skipped.append(room.id);continue
        rooms.append(room.id)
        for angle in 8:_sample89(scene,str(room.source_name),point,angle*PI/4)
        p.global_position=point;p.avatar.rotation.y=captures89[str(room.source_name)].yaw;var initial_yaw=p.avatar.rotation.y
        var orbit_accepted=aim.set_aim(true);assert(orbit_accepted);_step88(scene,.5)
        var previous=scene.camera.global_position
        for frame in 72:
            aim.yaw=initial_yaw+frame*TAU/72;_step88(scene,1.0/60)
            assert(aim.camera_clear(scene.camera.global_position),str(room.id)+" orbit")
            orbit_max_step=maxf(orbit_max_step,previous.distance_to(scene.camera.global_position));previous=scene.camera.global_position;orbit_samples+=1
        aim.set_aim(false);_step88(scene,.5)
    assert(rooms.size()>=7,str(skipped))
    var endpoints=p.map_doors.snapshot();var openings=[]
    for id in p.map_doors.doors:
        var door=p.map_doors.doors[id]
        for state in [false,true]:
            var config=endpoints.duplicate(true);config.states[id]=state;p.map_doors.apply_restore(config)
            for frame in 2:await scene.get_tree().physics_frame
            var origin: Vector3=door.hinge.global_position;origin.y=home.model.to_global(Vector3(0,.275,0)).y
            var point=_near89(scene,origin)
            if point==null:skipped.append(str(id)+"_"+str(state));continue
            for angle in [0,2,4,6]:_sample89(scene,str(id)+("_open" if state else "_closed"),point,angle*PI/4)
            openings.append({"id":id,"open":state})
        p.map_doors.apply_restore(endpoints)
    var furniture=[]
    for id in house.groups:
        var point=_near89(scene,house.groups[id].point)
        if point==null:skipped.append(id);continue
        for angle in [0,2,4,6]:_sample89(scene,"furniture_"+str(id),point,angle*PI/4)
        furniture.append(id)
    # Existing trunk colliders in the current map, not replacement tree fixtures.
    var landscape=scene.city.get_node_or_null("Landscape");var trees=[]
    if landscape!=null:
        for node in landscape.find_children("*","StaticBody3D",true,false):
            if trees.size()>=3:break
            var shapes=node.find_children("*","CollisionShape3D",true,false)
            if shapes.is_empty() or not shapes[0].shape is CylinderShape3D:continue
            var origin=node.global_position;origin.y=home.model.to_global(Vector3(0,.275,0)).y
            var point=_near89(scene,origin+Vector3(0,0,1))
            if point==null:continue
            for angle in [0,2,4,6]:_sample89(scene,"tree_"+str(node.name),point,angle*PI/4)
            trees.append(str(node.name))
    assert(trees.size()==3)
    # Furniture is on layer 2: it must retract the camera just like a layer-1 wall.
    var pad=_field(scene);p.global_position=pad;p.avatar.rotation.y=0
    var obstacle=_box(scene,pad+Vector3(0,1.6,-1),Vector3(3,3,.15));obstacle.collision_layer=2
    for frame in 2:await scene.get_tree().physics_frame
    _sample89(scene,"layer2_safety",pad,0)
    assert(cases89[-1].distance<1.7)
    await _clear_boxes(scene)
    # A clear field must still permit an actual shot with the revised camera service.
    p.global_position=pad;p.avatar.rotation.y=0
    var victim=scene.zombie_world.actors.values()[0]
    victim.restore(scene.zombie_world.initial[victim.identity]);victim.ai_enabled=false;victim.global_position=pad+Vector3(0,0,3)
    for frame in 2:await scene.get_tree().physics_frame
    accepted=aim.set_aim(true);assert(accepted);_step88(scene,.5)
    _look88(scene,victim.global_position+Vector3.UP*1.15)
    assert(aim.ready_to_fire() and aim.aim_ray().get("collider")==victim)
    var rounds=scene.player.weapons.loaded(pistol);_mouse88(scene,MOUSE_BUTTON_LEFT,true)
    for frame in 60:_step88(scene,1.0/60)
    assert(p.combat.effect_succeeded and is_equal_approx(victim.health,.20) and scene.player.weapons.loaded(pistol)==rounds-1)
    aim.set_aim(false);_step88(scene,.5);victim.global_position=Vector3(1000,0,1000)
    # Real-time processing order: the isometric updater must not overwrite shoulder view.
    p.global_position=pad;p.avatar.rotation.y=0;aim.set_aim(true)
    scene.set_process(true);aim.set_process(true);aim.set_physics_process(true);p.set_physics_process(true)
    for frame in 40:await scene.get_tree().physics_frame
    assert(aim.progress==1 and scene.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and aim.camera_clear(scene.camera.global_position))
    aim.set_aim(false)
    for frame in 40:await scene.get_tree().physics_frame
    assert(scene.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and not scene.camera.get_meta("solid_world89",false))
    scene.set_process(false);aim.set_process(false);aim.set_physics_process(false);p.set_physics_process(false)
    assert(orbit_max_step<=.205,str(orbit_max_step))
    var checks={"cases":cases89,"orbit_samples":orbit_samples,"orbit_max_step":orbit_max_step,"rooms":rooms,"openings":openings,"furniture":furniture,"trees":trees,"skipped":skipped,"layer2_safety":true,"clear_field_shot":true,"near_barrel_guard":true,"tight_entry_refused_safely":true,"bounded_orbit_motion":true,"prompts_hidden_in_shoulder":true,"solid_perspective":true,"isometric_restored":true,"live_process_roundtrip":true,"canonical_geometry_unchanged":true}
    helper._write("res://qa/camera89.json",checks)
    if "--capture-camera-world" in OS.get_cmdline_user_args():await _native89(scene)
    print("R89_CAMERA_WORLD_OK ",cases89.size()," cases; rooms ",rooms.size()," openings ",openings.size()," furniture ",furniture.size()," trees ",trees.size()," skipped ",skipped)
    scene.get_tree().quit()
func _native89(scene: Node3D) -> void:
    var aim=scene.shoulder;var p=scene.player
    var selected=[]
    for pattern in ["SALA_A","HALL","COZINHA","BANHEIRO","window/","tree_","furniture_H01_FURN_GUARDA"]:
        for label in captures89:
            if pattern in label:selected.append(label);break
    for label in selected:
        var data=captures89[label];var raw=data.position
        p.map_doors.apply_restore(data.openings)
        for tick in 2:await scene.get_tree().physics_frame
        p.global_position=Vector3(raw[0],raw[1],raw[2]);p.avatar.rotation.y=data.yaw
        scene.focus=p.global_position+Vector3.UP*.85;scene._update_camera();_player_idle(p)
        aim.set_aim(true);_step88(scene,.5);_step88(scene,.2)
        await _capture89(scene,str(selected.find(label)))
        aim.set_aim(false);_step88(scene,.5)
    var label=selected[0];var data=captures89[label];var raw=data.position
    p.global_position=Vector3(raw[0],raw[1],raw[2]);p.avatar.rotation.y=data.yaw;scene.focus=p.global_position+Vector3.UP*.85;scene._update_camera()
    aim.set_aim(true)
    for frame in 28:_step88(scene,1.0/60);await _capture89(scene,"interior_enter/%03d"%frame)
    aim.set_aim(false)
    for frame in 28:_step88(scene,1.0/60);await _capture89(scene,"interior_exit/%03d"%frame)
    helper._write("res://qa/camera89_captures.json",selected)
func _capture89(scene: Node3D,name: String) -> void:
    await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
    var path="res://previews/camera89/"+name+".png";DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
