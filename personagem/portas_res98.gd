extends RefCounted
var rows={}
var pending={}
func setup(scene: Node3D) -> void:
    var homes=scene.city.get_node("ResidentialInteriors").homes
    var ids=homes.keys();ids.sort()
    for lot in ids:
        for i in range(homes[lot].doors.size()):
            var door=homes[lot].doors[i]
            rows[lot+"/"+str(i)+"/"+str(door.hinge.name)]=door
func snapshot() -> Dictionary:
    var states={}
    for id in rows:states[id]=bool(rows[id].open)
    return {"version":1,"states":states}
func prepare(value: Variant,required: bool) -> bool:
    if value==null:
        if required:return false
        pending.clear()
        for id in rows:pending[id]=false
        return true
    if not value is Dictionary or value.get("version")!=1 or not value.get("states") is Dictionary or value.states.size()!=rows.size():return false
    for id in rows:
        if not value.states.has(id) or not value.states[id] is bool:return false
    pending=value.states.duplicate(true);return true
func apply() -> void:
    for id in rows:
        var door=rows[id];door.hinge.basis=door.closed_basis
        if pending.get(id,false):door.hinge.rotate_y(door.angle)
        door.open=bool(pending.get(id,false))
func parts(service: Node) -> Array:
    var result=[]
    for id in rows:
        var door=rows[id];var opened=bool(pending.get(id,door.open))
        var basis=Basis(Vector3.UP,door.angle if opened else 0.0)*door.closed_basis
        var local=Transform3D(basis,door.hinge.position);var n=0
        for collider in door.hinge.find_children("*","CollisionShape3D",true,false):
            if collider.disabled:continue
            var vertices=PackedVector3Array()
            if collider.shape is ConvexPolygonShape3D:vertices=collider.shape.points
            elif collider.shape is ConcavePolygonShape3D:vertices=collider.shape.get_faces()
            elif collider.shape is BoxShape3D:vertices.append(-collider.shape.size*.5);vertices.append(collider.shape.size*.5)
            if vertices.is_empty():continue
            var bounds=AABB(vertices[0],Vector3.ZERO)
            for point in vertices:bounds=bounds.expand(point)
            var box=BoxShape3D.new();box.size=bounds.size
            var proxy=CollisionShape3D.new();proxy.shape=box
            var relative=door.hinge.global_transform.affine_inverse()*collider.global_transform
            var pose=door.hinge.get_parent().global_transform*local*relative*Transform3D(Basis.IDENTITY,bounds.get_center())
            service._add(result,"res98/"+id+"/"+str(n),"res98/"+id,proxy,pose,collider.get_parent() as CollisionObject3D,RID(),opened)
            proxy.free();n+=1
    return result
