extends Node3D
const DURATION=.42
const AIM_FOV=58.0
var scene: Node3D
var holding=false
var progress=0.0
var yaw=0.0
var pitch=0.0
var iso_basis=Basis.IDENTITY
var previous_mouse_mode=Input.MOUSE_MODE_VISIBLE
var previous_mouse=Vector2.ZERO
var reticle: Control
var camera_distance=1.65
var collision_fraction=1.0
var recoil=0.0
var scripted=false
func setup(root_scene: Node3D) -> void:
    scene=root_scene;scene.player.shoulder=self
    scene.player.avatar.shoulder_pose_service=self
    process_priority=100;process_physics_priority=-100
    reticle=load("res://personagem/reticulo88.gd").new();scene.game_ui.add_child(reticle)
    scene.player.combat.impact_applied.connect(func(kind,_ok):
        if kind=="firearm_shot" and holding:recoil=1.0)
func is_firearm() -> bool:
    return scene!=null and scene.player.weapons.spec(scene.player.bag_inventory.equipped("main_hand")).get("type","")=="firearm"
func owns_camera() -> bool:return holding or progress>0
func allowed() -> bool:
    var p=scene.player
    return is_firearm() and not p.paused and not p.hud_open and not p.traversal.is_active() and not p.reaction.is_active() and p.flow.queue.is_empty() and not p.map_doors.busy() and not scene.world_items.has_interaction()
func set_aim(value: bool) -> bool:
    if value==holding:return true
    if value:
        var p=scene.player
        if not allowed() or p.action.state!="idle" or not p.map_combat.ready_to_act() or not p.set_crouch(false):return false
        if not p.combat.set_guard(true):return false
        if progress==0:iso_basis=scene.camera.global_basis
        yaw=p.avatar.rotation.y;pitch=0
        previous_mouse_mode=Input.mouse_mode;previous_mouse=scene.get_viewport().get_mouse_position()
        if not scripted:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
        p.locomotion.cancel();p.preview_motion="";p.velocity.x=0;p.velocity.z=0
        holding=true
    else:
        holding=false
        scene.player.combat.set_guard(false)
        scene.player.avatar.shoulder_pitch=0
        if not scripted:
            Input.mouse_mode=previous_mouse_mode
            if previous_mouse_mode==Input.MOUSE_MODE_VISIBLE:Input.warp_mouse(previous_mouse)
    return true
func ready_to_fire() -> bool:
    return holding and progress>=.999 and allowed() and scene.player.action.state=="idle" and collision_fraction>.12
func move_aim(relative: Vector2) -> void:
    if not holding:return
    yaw=wrapf(yaw-relative.x*.0028,-PI,PI)
    pitch=clampf(pitch-relative.y*.0022,deg_to_rad(-28),deg_to_rad(32))
func _input(event: InputEvent) -> void:
    if scene==null or scripted:return
    if event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_RIGHT:
            if not event.pressed and holding:set_aim(false);get_viewport().set_input_as_handled()
            elif event.pressed and set_aim(true):get_viewport().set_input_as_handled()
        elif holding and event.button_index==MOUSE_BUTTON_LEFT:
            if event.pressed:scene.player.request_attack()
            get_viewport().set_input_as_handled()
        elif owns_camera() and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and holding:
        move_aim(event.relative);get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE and holding:
        set_aim(false);get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
    if what==NOTIFICATION_APPLICATION_FOCUS_OUT and scene!=null and holding:set_aim(false)
func _exit_tree() -> void:
    if holding and not scripted:Input.mouse_mode=previous_mouse_mode
func _physics_process(_delta: float) -> void:
    if scene==null:return
    if holding and not allowed():set_aim(false)
    if holding:
        var p=scene.player
        if p.action.state=="idle" and not p.combat.guarding:p.combat.set_guard(true)
        p.avatar.rotation.y=yaw
        p.avatar.shoulder_pitch=pitch*smoothstep(0,1,progress)
    else:scene.player.avatar.shoulder_pitch=0
func _process(delta: float) -> void:
    if scene==null:return
    advance(delta)
func advance(delta: float) -> void:
    if not is_finite(delta) or delta<0:return
    if holding and not allowed():set_aim(false)
    if not owns_camera():return
    progress=move_toward(progress,1.0 if holding else 0.0,delta/DURATION)
    recoil=move_toward(recoil,0,delta*7)
    var camera=scene.camera;var p=scene.player
    if progress<=0:
        camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.05
        reticle.strength=0;reticle.queue_redraw();scene._update_camera();return
    var blend=smoothstep(0,1,progress)
    var forward=Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
    var right=Vector3(-cos(yaw),0,sin(yaw))
    var head=p.global_position+Vector3.UP*1.58
    var wanted=head+right*.65-Vector3(sin(yaw),0,cos(yaw))*1.65
    var query=PhysicsShapeQueryParameters3D.new();var sphere=SphereShape3D.new();sphere.radius=.16
    query.shape=sphere;query.transform=Transform3D(Basis.IDENTITY,head);query.motion=wanted-head;query.collision_mask=1;query.exclude=[p.get_rid()]
    var fractions=get_world_3d().direct_space_state.cast_motion(query)
    collision_fraction=maxf(0,float(fractions[0])-.025)
    var shoulder_position=head.lerp(wanted,collision_fraction)
    var shoulder_basis=Basis.looking_at(forward,Vector3.UP)
    var distance=1.65
    var pivot=scene.focus.lerp(shoulder_position+forward*distance,blend)
    var basis=Basis(iso_basis.get_rotation_quaternion().slerp(shoulder_basis.get_rotation_quaternion(),blend))
    var fov=lerpf(3.0,AIM_FOV,blend)
    var height=lerpf(scene.zoom,2*distance*tan(deg_to_rad(AIM_FOV*.5)),blend)
    camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=fov;camera.near=.05
    camera.global_transform=Transform3D(basis,pivot+basis.z*(height/(2*tan(deg_to_rad(fov*.5)))))
    camera_distance=camera.global_position.distance_to(head)
    var aim=aim_ray()
    var collider=aim.get("collider")
    reticle.hostile=is_instance_valid(collider) and collider.is_in_group("combat_receivers79")
    var obstruction=muzzle_ray(aim.position)
    reticle.blocked=not obstruction.is_empty() and obstruction.position.distance_to(aim.position)>.12
    reticle.strength=smoothstep(.75,1,progress) if p.action.state=="idle" else 0.0
    reticle.kick=recoil;reticle.queue_redraw()
func aim_ray() -> Dictionary:
    var camera=scene.camera;var center=scene.get_viewport().get_visible_rect().size*.5
    var origin=camera.project_ray_origin(center);var direction=camera.project_ray_normal(center)
    var end=origin+direction*50
    var query=PhysicsRayQueryParameters3D.create(origin,end,3,[scene.player.get_rid()])
    var hit=get_world_3d().direct_space_state.intersect_ray(query)
    return {"position":end,"collider":null} if hit.is_empty() else hit
func muzzle_ray(point: Vector3) -> Dictionary:
    var p=scene.player;var origin=p.weapons.visual.muzzle_position()
    var direction=point-origin
    if direction.length()<.001:return {}
    var reach=float(p.weapons.spec(p.bag_inventory.equipped("main_hand")).get("reach",8))
    var query=PhysicsRayQueryParameters3D.create(origin,origin+direction.normalized()*minf(reach,direction.length()+.02),3,[p.get_rid()])
    return get_world_3d().direct_space_state.intersect_ray(query)
func align_pose(actor: Node3D) -> void:
    if not holding or progress<.25:return
    var rig=actor.skeleton;var visual=scene.player.weapons.visual
    var point: Vector3=pose_target116()
    var upper=rig.find_bone("UpperArm.R");var hand=rig.find_bone("Hand.R")
    var parent=rig.get_bone_parent(upper)
    for iteration in 3:
        var grip: Transform3D=rig.global_transform*rig.get_bone_global_pose(hand)*visual.GRIP
        var muzzle=grip*Vector3(0,.042,.18).rotated(Vector3.UP,visual.BARREL_YAW)
        var barrel=(grip.basis*Vector3(0,0,1).rotated(Vector3.UP,visual.BARREL_YAW)).normalized()
        var direction=(point-muzzle).normalized()
        if barrel.dot(direction)>.99995:break
        var rotation=Quaternion(barrel,direction)
        var angle=rotation.get_angle()
        if angle>deg_to_rad(25):rotation=Quaternion.IDENTITY.slerp(rotation,deg_to_rad(25)/angle)
        rotation=Quaternion.IDENTITY.slerp(rotation,smoothstep(.25,1,progress))
        var parent_rotation=(rig.global_basis*rig.get_bone_global_pose(parent).basis).orthonormalized().get_rotation_quaternion()
        var local=parent_rotation.inverse()*rotation*parent_rotation
        rig.set_bone_pose_rotation(upper,local*rig.get_bone_pose_rotation(upper));rig.force_update_all_bone_transforms()
func pose_target116() -> Vector3:return aim_ray().position
