extends "res://personagem/mira_ombro88.gd"
var sheltered_transition=false
var iso_distance=19.5959
var current_offset=Vector2(.65,1.65)
var veil: ColorRect
var warning: Label
var landscape: Node3D
var original_reveal=true
var original_cull_mask=1048575
var probe_radius=.18
var last_solve={}
var last_position: Variant=null
var previewing=false
var view_blocked=false
var goal_distance=0.0
var solid_state116: Variant=null
func setup(root_scene: Node3D) -> void:
    super.setup(root_scene)
    original_cull_mask=scene.camera.cull_mask
    landscape=scene.city.get_node_or_null("Landscape")
    if landscape!=null:original_reveal=landscape.reveal_enabled
    veil=ColorRect.new();veil.color=Color(0,0,0,0);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
    scene.game_ui.add_child(veil);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    warning=Label.new();warning.text="Sem espaço para a câmera · solte a mira e afaste-se";warning.position=Vector2(20,78)
    warning.mouse_filter=Control.MOUSE_FILTER_IGNORE;warning.visible=false;scene.game_ui.add_child(warning)
func exclusions() -> Array[RID]:
    var list: Array[RID]=[scene.player.get_rid()]
    for node in get_tree().get_nodes_in_group("combat_receivers79"):
        if node is CharacterBody3D:list.append(node.get_rid())
    return list
func sweep(origin: Vector3,point: Vector3) -> float:
    var query=PhysicsShapeQueryParameters3D.new();var sphere=SphereShape3D.new();sphere.radius=probe_radius
    query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,origin);query.collision_mask=3;query.exclude=exclusions();query.margin=.01
    if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return 0
    query.motion=point-origin
    var result=get_world_3d().direct_space_state.cast_motion(query)
    return 1.0 if float(result[0])>=.9999 else clampf(float(result[0])-.025,0,1)
func camera_clear(point: Vector3) -> bool:
    var query=PhysicsShapeQueryParameters3D.new();var sphere=SphereShape3D.new();sphere.radius=.16
    query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,point);query.collision_mask=3;query.exclude=exclusions()
    return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func set_aim(value: bool) -> bool:
    var entering=value and not holding
    var was_progress=progress
    var original_distance=scene.camera.global_position.distance_to(scene.focus) if scene!=null else iso_distance
    if entering and is_firearm():
        var angle=scene.player.avatar.rotation.y
        var head=scene.player.global_position+Vector3.UP*1.58
        var previous=current_offset;current_offset=Vector2(.65,1.65);previewing=true
        var point=solve_position(head,Vector3(-cos(angle),0,sin(angle)),Vector3(sin(angle),0,cos(angle)),.5)
        previewing=false
        if point.distance_to(head)<.5:
            current_offset=previous;scene.game_ui.feedback.text="Sem espaço para a câmera · afaste-se da parede"
            return false
    var accepted=super.set_aim(value)
    if accepted and entering:
        iso_distance=original_distance if progress==0 else iso_distance
        var head=scene.player.global_position+Vector3.UP*1.58
        sheltered_transition=scene.world_items.house.shell.contains_point("H01",scene.player.global_position) or sweep(head,scene.camera.global_position)<.96
        current_offset=Vector2(.65,1.65)
        if was_progress==0:last_position=null
    return accepted
func travel_fraction(origin: Vector3,target: Vector3) -> float:
    var query=PhysicsShapeQueryParameters3D.new();var sphere=SphereShape3D.new();sphere.radius=probe_radius
    query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,origin);query.motion=target-origin;query.collision_mask=3;query.exclude=exclusions();query.margin=.01
    var result=get_world_3d().direct_space_state.cast_motion(query)
    return 1.0 if float(result[0])>=.9999 else maxf(0,float(result[0])-.03)
func solve_position(head: Vector3,right: Vector3,forward: Vector3,delta: float) -> Vector3:
    var best=Vector2.ZERO;var best_score=-1.0;var raw=0.0
    for offset in [Vector2(.65,1.65),Vector2(.65,1.15),Vector2(.65,.75),Vector2(.65,.45),Vector2(.4,.6)]:
        var ratio=sweep(head,head+right*offset.x-forward*offset.y)
        if raw==0:raw=ratio
        var candidate=offset*ratio
        var score=candidate.length()+candidate.x*.15
        if score>best_score:best=candidate;best_score=score
        if offset==Vector2(.65,1.65) and ratio>.96:break
    var target=best
    # Retract immediately for safety; ease outward only through rechecked free space.
    if best.length()>current_offset.length():target=current_offset.lerp(best,1-exp(-delta*7))
    var ratio=sweep(head,head+right*target.x-forward*target.y)
    current_offset=target*ratio
    collision_fraction=current_offset.length()/Vector2(.65,1.65).length()
    last_solve={"raw_fraction":raw,"offset":[current_offset.x,current_offset.y],"distance":current_offset.length()}
    var goal=head+right*current_offset.x-forward*current_offset.y
    goal_distance=goal.distance_to(head)
    if previewing:return goal
    if last_position==null:last_position=goal
    var result: Vector3=last_position
    if goal_distance>=.5:
        var proposed=result.move_toward(goal,12*delta)
        if travel_fraction(result,proposed)<.999:
            var retreat=head+(result-head).normalized()*.6
            proposed=result.move_toward(retreat,12*delta)
        proposed=result.lerp(proposed,travel_fraction(result,proposed))
        if proposed.distance_to(head)>=.5 and camera_clear(proposed):result=proposed
    last_position=result
    view_blocked=goal_distance<.5 or sweep(head,result)<.96
    collision_fraction=result.distance_to(head)/Vector2(.65,1.65).length()
    return result
func barrel_obstructed() -> bool:
    var hit=aim_ray();var point: Vector3=hit.position
    var receiver=hit.get("collider")
    # An enemy touching the weapon is a valid target, not a solid wall.
    if is_instance_valid(receiver) and receiver.is_in_group("combat_receivers79") and not str(hit.get("zone","")).is_empty():return false
    var muzzle=scene.player.weapons.visual.muzzle_position()
    return point.distance_to(scene.player.global_position+Vector3.UP*1.3)<.75 or (point-muzzle).dot(-scene.camera.global_basis.z)<.08
func pose_target116() -> Vector3:
    var hit=aim_ray();var receiver=hit.get("collider");var muzzle=scene.player.weapons.visual.muzzle_position()
    var forward=-scene.camera.global_basis.z
    if is_instance_valid(receiver) and receiver.is_in_group("combat_receivers79") and (hit.position-muzzle).dot(forward)<.12:
        return muzzle+forward*5
    return hit.position
func ready_to_fire() -> bool:return super.ready_to_fire() and camera_distance>=.5 and not barrel_obstructed() and not view_blocked
func align_pose(actor: Node3D) -> void:
    if holding and progress>.8 and barrel_obstructed():return
    super.align_pose(actor)
func _solid(value: bool) -> void:
    if solid_state116==value:return
    solid_state116=value
    scene.camera.set_meta("solid_world89",value)
    for owner in [scene.world_items,scene.player.map_doors,scene.player.map_traversals]:
        if owner==null:continue
        for label in owner.find_children("*","Label3D",true,false):label.layers=1<<19
    scene.camera.cull_mask=original_cull_mask&~(1<<19) if value else original_cull_mask
    if landscape!=null:
        landscape.reveal_enabled=false if value else original_reveal
        landscape._process(0)
    scene.world_items.house.shell._process(0)
    scene.world_items.house._process(0)
func advance(delta: float) -> void:
    if not is_finite(delta) or delta<0:return
    if holding and not allowed():set_aim(false)
    if not owns_camera():return
    progress=move_toward(progress,1.0 if holding else 0.0,delta/DURATION)
    recoil=move_toward(recoil,0,delta*7)
    var camera=scene.camera;var p=scene.player
    _solid(progress>=.5 if sheltered_transition else progress>.05)
    veil.color.a=smoothstep(0,1,1-absf(progress*2-1)) if sheltered_transition else 0.0
    if progress<=0:
        camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05
        reticle.strength=0;reticle.queue_redraw();veil.color.a=0;warning.visible=false;view_blocked=false;last_position=null;_solid(false);scene._update_camera();return
    var blend=smoothstep(0,1,progress)
    var forward=Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
    var right=Vector3(-cos(yaw),0,sin(yaw))
    var head=p.global_position+Vector3.UP*1.58
    var wanted=head+right*.65-Vector3(sin(yaw),0,cos(yaw))*1.65
    var shoulder_position=solve_position(head,right,Vector3(sin(yaw),0,cos(yaw)),delta)
    var shoulder_basis=Basis.looking_at(forward,Vector3.UP)
    var distance=1.65
    var pivot=scene.focus.lerp(shoulder_position+forward*distance,blend)
    var basis=Basis(iso_basis.get_rotation_quaternion().slerp(shoulder_basis.get_rotation_quaternion(),blend))
    var fov=lerpf(3.0,AIM_FOV,blend)
    var height=lerpf(scene.zoom,2*distance*tan(deg_to_rad(AIM_FOV*.5)),blend)
    camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=fov;camera.near=.05
    camera.global_transform=Transform3D(basis,pivot+basis.z*(height/(2*tan(deg_to_rad(fov*.5)))))
    if sheltered_transition:
        if progress<.5:
            camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=scene.zoom
            camera.global_transform=Transform3D(iso_basis,scene.focus+iso_basis.z*iso_distance)
        else:
            camera.fov=AIM_FOV;camera.global_transform=Transform3D(shoulder_basis,shoulder_position)
    camera_distance=shoulder_position.distance_to(head)
    var barrel_blocked=holding and barrel_obstructed()
    warning.visible=holding and (camera_distance<.5 or barrel_blocked or view_blocked)
    warning.text="Obstáculo junto à arma · ajuste a posição" if barrel_blocked else "Ajuste o ângulo ou afaste-se da parede"
    var aim=aim_ray()
    var collider=aim.get("collider")
    reticle.hostile=is_instance_valid(collider) and collider.is_in_group("combat_receivers79")
    var obstruction=muzzle_ray(aim.position)
    reticle.blocked=barrel_blocked or (not obstruction.is_empty() and obstruction.position.distance_to(aim.position)>.12)
    reticle.strength=smoothstep(.75,1,progress) if p.action.state=="idle" else 0.0
    reticle.kick=recoil;reticle.queue_redraw()
