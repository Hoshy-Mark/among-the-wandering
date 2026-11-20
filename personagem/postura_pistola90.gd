extends Node3D
var body: CharacterBody3D
var actor: Node3D
var rig: Skeleton3D
var magazine: MeshInstance3D
var segment_delta=0.0
var support_error=0.0
var reach_error=0.0
var left_frame=Basis.IDENTITY
var last_targets={}
func setup(player: CharacterBody3D) -> void:
    body=player;actor=body.avatar;rig=actor.skeleton;actor.firearm_presentation=self
    var idle: Animation=actor.player.get_animation(actor.clips.idle)
    var library=AnimationLibrary.new()
    for entry in [["aim","firearm_idle",1.0],["shot","firearm_shot",.48],["reload","firearm_idle",1.65]]:
        var clip: Animation=actor.player.get_animation(actor.clips[entry[1]]).duplicate(true)
        clip.length=float(entry[2]);clip.loop_mode=Animation.LOOP_LINEAR if entry[0]=="aim" else Animation.LOOP_NONE
        for track in clip.get_track_count():
            var name=str(clip.track_get_path(track).get_subname(0))
            if name.begins_with("Clavicle") or name.begins_with("UpperArm") or name.begins_with("Forearm") or name.begins_with("Hand") or name.begins_with("Elbow") or name.begins_with("Wrist"):continue
            var type=clip.track_get_type(track)
            if type not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D,Animation.TYPE_SCALE_3D]:continue
            var found=idle.find_track(clip.track_get_path(track),type)
            if found<0:continue
            var value: Variant
            if type==Animation.TYPE_ROTATION_3D:value=idle.rotation_track_interpolate(found,0)
            elif type==Animation.TYPE_POSITION_3D:value=idle.position_track_interpolate(found,0)
            else:value=idle.scale_track_interpolate(found,0)
            for key in clip.track_get_key_count(track):clip.track_set_key_value(track,key,value)
        library.add_animation(entry[0],clip)
    actor.player.add_animation_library("Pistol90",library)
    actor.clips.firearm_idle="Pistol90/aim";actor.clips.firearm_shot="Pistol90/shot";actor.clips.firearm_reload90="Pistol90/reload"
    actor.hand_layer.poses.Pistol_Grip90=actor.hand_layer.poses.Cylinder.duplicate(true)
    var reload_hands=actor.hand_layer.poses.Open.duplicate(true)
    for name in actor.hand_layer.poses.Cylinder:
        if str(name).ends_with(".R"):reload_hands[name]=actor.hand_layer.poses.Cylinder[name].duplicate(true)
    actor.hand_layer.poses.Pistol_Reload90=reload_hands
    var rest=rig.get_bone_global_rest(rig.find_bone("Hand.L"))
    var middle=rig.get_bone_global_rest(rig.find_bone("Middle.01.L")).origin-rest.origin
    var across=rig.get_bone_global_rest(rig.find_bone("Index.01.L")).origin-rig.get_bone_global_rest(rig.find_bone("Little.01.L")).origin
    var f=(rest.basis.inverse()*middle).normalized();var n=(rest.basis.inverse()*middle.cross(across)).normalized()
    left_frame=Basis(f,n,f.cross(n)).orthonormalized()
    magazine=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.024,.07,.032);magazine.mesh=box
    var mat=StandardMaterial3D.new();mat.albedo_color=Color("454e4a");mat.roughness=.8;magazine.material_override=mat
    actor.add_child(magazine);magazine.visible=false
func _position(name: String) -> Vector3:return rig.global_transform*rig.get_bone_global_pose(rig.find_bone(name)).origin
func _rotation(name: String) -> Quaternion:return (rig.global_basis*rig.get_bone_global_pose(rig.find_bone(name)).basis).orthonormalized().get_rotation_quaternion()
func _rotate(name: String,world_delta: Quaternion) -> void:
    var index=rig.find_bone(name);var parent=rig.get_bone_parent(index)
    var rotation=(rig.global_basis*rig.get_bone_global_pose(parent).basis).orthonormalized().get_rotation_quaternion()
    rig.set_bone_pose_rotation(index,rotation.inverse()*world_delta*rotation*rig.get_bone_pose_rotation(index));rig.force_update_all_bone_transforms()
func _orient(name: String,desired: Quaternion) -> void:_rotate(name,desired*_rotation(name).inverse())
func _joint(name: String,side: String,key: String) -> Vector3:
    var values=actor.arm_articulation.joints[side][key]
    var ref=Vector3(values[0],values[1],values[2]);var index=rig.find_bone(name)
    return rig.global_transform*(rig.get_bone_global_pose(index)*rig.get_bone_global_rest(index).affine_inverse()*ref)
func _about(name: String,rotation: Quaternion,pivot: Vector3) -> void:
    var index=rig.find_bone(name);var parent=rig.get_bone_parent(index)
    var world=rig.global_transform*rig.get_bone_global_pose(index)
    world=Transform3D(Basis(rotation),pivot-Basis(rotation)*pivot)*world
    var parent_world=rig.global_transform*rig.get_bone_global_pose(parent)
    rig.set_bone_pose(index,parent_world.affine_inverse()*world);rig.force_update_all_bone_transforms()
func _hand_orientation(side: String,desired: Quaternion) -> void:
    var name="Hand."+side
    _about(name,desired*_rotation(name).inverse(),_joint(name,side,"wrist"))
func _ik(side: String,target: Vector3,pole: Vector3,orientation: Quaternion) -> void:
    var a=_position("UpperArm."+side)
    var b=_joint("UpperArm."+side,side,"elbow")
    var fore_elbow=_joint("Forearm."+side,side,"elbow")
    var c=_joint("Forearm."+side,side,"wrist")
    var values=actor.arm_articulation.joints[side].wrist
    var rest=rig.get_bone_global_rest(rig.find_bone("Hand."+side))
    var wrist_local=rest.affine_inverse()*Vector3(values[0],values[1],values[2])
    var gap=c-_joint("Hand."+side,side,"wrist")
    var wrist_target=target+Basis(orientation)*wrist_local+gap
    var upper=a.distance_to(b);var lower=fore_elbow.distance_to(c);var offset=wrist_target-a
    var length=clampf(offset.length(),absf(upper-lower)+.005,upper+lower-.005)
    reach_error=maxf(reach_error,maxf(0,offset.length()-(upper+lower-.005)))
    var direction=offset.normalized();var bend=pole-a;bend=(bend-direction*bend.dot(direction)).normalized()
    var along=(length*length+upper*upper-lower*lower)/(2*length)
    var elbow=a+direction*along+bend*sqrt(maxf(0,upper*upper-along*along))
    _rotate("UpperArm."+side,Quaternion((b-a).normalized(),(elbow-a).normalized()))
    b=_joint("Forearm."+side,side,"elbow");c=_joint("Forearm."+side,side,"wrist")
    _about("Forearm."+side,Quaternion((c-b).normalized(),(wrist_target-b).normalized()),b)
    _hand_orientation(side,orientation)
func _grip() -> Transform3D:return rig.global_transform*rig.get_bone_global_pose(rig.find_bone("Hand.R"))*body.weapons.visual.GRIP
func apply(_delta: float) -> void:
    magazine.visible=false;support_error=0;reach_error=0
    if body.weapons.held_definition!="pistol" or actor.motion not in ["firearm_idle","firearm_shot","firearm_reload90"]:return
    var loading=actor.motion=="firearm_reload90" and not body.weapons.reload_job.is_empty() and body.action.state!="idle"
    if not loading and (not body.combat.guarding or body.action.state!="idle" or body.traversal.is_active() or body.reaction.is_active()):return
    var phase=clampf(actor.motion_clock/1.65,0,1) if loading else 0.0
    var grasping=not loading or (phase>=.18 and phase<.50) or phase>=.75
    var hands="Pistol_Grip90" if grasping else "Pistol_Reload90"
    if actor.hand_layer.label!=hands:actor.hand_layer.set_pose(hands)
    var blend=smoothstep(0,1,actor.motion_blend)
    var forward=actor.global_basis.z.normalized();var left=actor.global_basis.x.normalized();var right=-left
    var low=sin(phase*PI) if loading else 0.0
    var recoil=0.0
    if actor.motion=="firearm_shot" and body.combat.state=="attack":recoil=smoothstep(.10,.15,body.combat.elapsed)*(1-smoothstep(.16,.32,body.combat.elapsed))
    var elevation=actor.shoulder_pitch if not loading else 0.0
    var aim_forward=forward*cos(elevation)+Vector3.UP*sin(elevation)
    var target=body.global_position+Vector3.UP*(1.36-low*.10)+aim_forward*(.32-low*.06-recoil*.035)+right*.08
    var lengths=[]
    for side in ["L","R"]:
        lengths.append(_position("UpperArm."+side).distance_to(_joint("UpperArm."+side,side,"elbow")))
        lengths.append(_joint("Forearm."+side,side,"elbow").distance_to(_joint("Forearm."+side,side,"wrist")))
    var reference=actor.arm_blend.capture()
    var old_right=_rotation("Hand.R")
    for iteration in 3:
        _ik("R",_position("Hand.R").lerp(target,blend),body.global_position+right*.40+Vector3.UP*1.08+forward*.09,old_right)
        if not loading and body.shoulder!=null and body.shoulder.holding and not body.shoulder.barrel_obstructed():
            var grip=_grip();var barrel=(grip.basis*Vector3(0,0,1).rotated(Vector3.UP,body.weapons.visual.BARREL_YAW)).normalized()
            var muzzle=grip*Vector3(0,.042,.18).rotated(Vector3.UP,body.weapons.visual.BARREL_YAW)
            var direction=(body.shoulder.aim_ray().position-muzzle).normalized()
            _about("Hand.R",Quaternion(barrel,direction),_joint("Hand.R","R","wrist"))
        actor.arm_blend.correct(reference,reference,1)
    var grip=_grip();var gun_basis=grip.basis*Basis(Vector3.UP,body.weapons.visual.BARREL_YAW)
    var gun_forward=gun_basis.z.normalized();var gun_right=gun_basis.x.normalized();var gun_up=gun_basis.y.normalized()
    var support=grip.origin+gun_right*.08-gun_forward*.16-gun_up*.025
    var left_target=support
    if loading:
        var belt=body.global_position+left*.22+Vector3.UP*1.08+forward*.10
        var under=grip.origin-gun_up*.055+gun_right*.08-gun_forward*.16
        var insert=grip.origin+gun_up*.03+gun_right*.08-gun_forward*.16
        if phase<.18:left_target=support.lerp(belt,smoothstep(0,.18,phase))
        elif phase<.40:left_target=belt.lerp(under,smoothstep(.18,.40,phase))
        elif phase<.50:left_target=under.lerp(insert,smoothstep(.40,.50,phase))
        elif phase<.65:left_target=insert
        else:left_target=insert.lerp(support,smoothstep(.65,1,phase))
    var desired=Basis(gun_forward,-gun_right,gun_forward.cross(-gun_right)).orthonormalized()*left_frame.inverse()
    var left_orientation=_rotation("Hand.L").slerp(desired.get_rotation_quaternion(),blend)
    for iteration in 3:
        _ik("L",_position("Hand.L").lerp(left_target,blend),body.global_position+left*.40+Vector3.UP*1.05+forward*.06,left_orientation)
        actor.arm_blend.correct(reference,reference,1)
    segment_delta=0.0
    for index in 2:
        var side="L" if index==0 else "R"
        segment_delta=maxf(segment_delta,absf(lengths[index*2]-_position("UpperArm."+side).distance_to(_joint("UpperArm."+side,side,"elbow"))))
        segment_delta=maxf(segment_delta,absf(lengths[index*2+1]-_joint("Forearm."+side,side,"elbow").distance_to(_joint("Forearm."+side,side,"wrist"))))
    support_error=_position("Hand.L").distance_to(left_target)
    last_targets={"left":left_target,"right":target,"phase":phase}
    magazine.visible=loading and phase>=.18 and phase<.50
    if magazine.visible:magazine.global_transform=Transform3D(gun_basis,_position("Hand.L")+gun_forward*.16-gun_right*.08-gun_up*.04)
