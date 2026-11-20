extends RefCounted
static func boxes(a: Dictionary,b: Dictionary) -> bool:
    var axes=[a.pose.basis.x.normalized(),a.pose.basis.y.normalized(),a.pose.basis.z.normalized(),b.pose.basis.x.normalized(),b.pose.basis.y.normalized(),b.pose.basis.z.normalized()]
    for i in 3:
        for j in 3:
            var cross: Vector3=axes[i].cross(axes[3+j])
            if cross.length_squared()>.000001:axes.append(cross.normalized())
    var ea: Vector3=a.shape.size*.5*a.pose.basis.get_scale()
    var eb: Vector3=b.shape.size*.5*b.pose.basis.get_scale()
    for axis in axes:
        var ra=0.0;var rb=0.0
        for k in 3:
            ra+=absf(axis.dot(a.pose.basis[k].normalized()))*ea[k]
            rb+=absf(axis.dot(b.pose.basis[k].normalized()))*eb[k]
        if absf(axis.dot(a.pose.origin-b.pose.origin))>=ra+rb-.002:return false
    return true
static func capsule_box(point: Vector3,height: float,box: Dictionary) -> bool:
    var inverse: Transform3D=box.pose.affine_inverse()
    var a=inverse*(point+Vector3.UP*.25)
    var b=inverse*(point+Vector3.UP*(height-.21))
    var extents: Vector3=box.shape.size*.5
    var low=0.0;var high=1.0
    for i in 32:
        var x=(2*low+high)/3
        var y=(low+2*high)/3
        var px: Vector3=a.lerp(b,x)
        var py: Vector3=a.lerp(b,y)
        if px.distance_squared_to(px.clamp(-extents,extents))<py.distance_squared_to(py.clamp(-extents,extents)):high=y
        else:low=x
    var closest: Vector3=a.lerp(b,(low+high)/2)
    return closest.distance_squared_to(closest.clamp(-extents,extents))<pow(.228,2)
