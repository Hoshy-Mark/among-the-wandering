extends RefCounted
func bone(actor: Node3D,name: String) -> Vector3:
    var rig=actor.skeleton;var index=rig.find_bone(name)
    assert(index>=0,name)
    return rig.global_transform*rig.get_bone_global_pose(index).origin
func joint(actor: Node3D,name: String,side: String,key: String) -> Vector3:
    var rig=actor.skeleton;var index=rig.find_bone(name);var values=actor.arm_articulation.joints[side][key]
    return rig.global_transform*(rig.get_bone_global_pose(index)*rig.get_bone_global_rest(index).affine_inverse()*Vector3(values[0],values[1],values[2]))
func volumes(actor: Node3D) -> Array:
    var up=actor.global_basis.y.normalized();var hip=bone(actor,"Hips");var neck=bone(actor,"Neck");var head=bone(actor,"Head")
    var index=actor.skeleton.find_bone("Head")
    var head_up=(actor.skeleton.global_basis*actor.skeleton.get_bone_global_pose(index).basis*actor.skeleton.get_bone_global_rest(index).basis.inverse()*Vector3.UP).normalized()
    var middle=hip.lerp(neck,.60)
    var result=[{"zone":"head","a":head+head_up*.04,"b":head+head_up*.17,"radius":.12},{"zone":"chest","a":middle,"b":neck-up*.08,"radius":.16},{"zone":"abdomen","a":hip+up*.06,"b":middle,"radius":.14}]
    for side in ["L","R"]:
        var suffix="left" if side=="L" else "right"
        var elbow=joint(actor,"UpperArm."+side,side,"elbow").lerp(joint(actor,"Forearm."+side,side,"elbow"),.5)
        var wrist=joint(actor,"Forearm."+side,side,"wrist").lerp(joint(actor,"Hand."+side,side,"wrist"),.5)
        result.append({"zone":"upper_arm_"+suffix,"a":bone(actor,"UpperArm."+side),"b":elbow,"radius":.065})
        result.append({"zone":"forearm_"+suffix,"a":elbow,"b":wrist+(wrist-elbow).normalized()*.085,"radius":.055})
        result.append({"zone":"thigh_"+suffix,"a":bone(actor,"Thigh."+side),"b":bone(actor,"Shin."+side),"radius":.085})
        result.append({"zone":"calf_"+suffix,"a":bone(actor,"Shin."+side),"b":bone(actor,"Foot."+side),"radius":.065})
    return result
func sphere(origin: Vector3,direction: Vector3,center: Vector3,radius: float) -> float:
    var offset=origin-center;var b=offset.dot(direction);var c=offset.length_squared()-radius*radius
    if c<=0:return 0
    var discriminant=b*b-c
    if discriminant<0:return INF
    var t=-b-sqrt(discriminant)
    return t if t>=0 else INF
func capsule(origin: Vector3,direction: Vector3,a: Vector3,b: Vector3,radius: float) -> float:
    var axis=b-a;var aa=axis.length_squared()
    if aa<.0000001:return sphere(origin,direction,a,radius)
    var close=a+axis*clampf((origin-a).dot(axis)/aa,0,1)
    if close.distance_squared_to(origin)<=radius*radius:return 0
    var offset=origin-a;var ad=axis.dot(direction);var ao=axis.dot(offset);var od=offset.dot(direction)
    var qa=aa-ad*ad;var qb=aa*od-ao*ad;var qc=aa*offset.length_squared()-ao*ao-radius*radius*aa
    var first=minf(sphere(origin,direction,a,radius),sphere(origin,direction,b,radius))
    var discriminant=qb*qb-qa*qc
    if qa>.0000001 and discriminant>=0:
        for t in [(-qb-sqrt(discriminant))/qa,(-qb+sqrt(discriminant))/qa]:
            var along=ao+t*ad
            if t>=0 and along>=0 and along<=aa:first=minf(first,t)
    return first
func intersect(origin: Vector3,direction: Vector3,reach: float,regions: Array) -> Dictionary:
    var result={};var distance=reach+.00001
    for region in regions:
        var t=capsule(origin,direction,region.a,region.b,float(region.radius))
        if t<=reach and t<distance:
            distance=t;var point=origin+direction*t;var axis: Vector3=region.b-region.a
            var closest: Vector3=region.a+axis*clampf((point-region.a).dot(axis)/maxf(.0000001,axis.length_squared()),0,1)
            result={"position":point,"normal":(point-closest).normalized() if point.distance_squared_to(closest)>.000001 else -direction,"distance":t,"zone":region.zone}
    return result
