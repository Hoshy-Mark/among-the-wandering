extends "res://population97/estudo_base97.gd"
var manager: Node3D
func _free(p: Vector3) -> bool:
    var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=3;q.margin=.001
    q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.942);q.exclude=manager.actor_rids()
    return get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()
func _edge(a: Vector3,b: Vector3) -> bool:
    if absf(a.y-b.y)>.085 or not _free(b):return false
    var upper=Vector3(a.x,maxf(a.y,b.y),a.z)
    if not _free(upper):return false
    var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=3;q.margin=.001
    q.transform=Transform3D(Basis.IDENTITY,upper+Vector3.UP*.942);q.motion=Vector3(b.x-a.x,0,b.z-a.z);q.exclude=manager.actor_rids()
    return get_world_3d().direct_space_state.cast_motion(q)[0]>.9999
func index_population() -> void:
    cells.clear()
    for id in registry.states:
        if registry.states[id].mode=="dead":continue
        var key=_cell(point(registry.states[id].position))
        if not cells.has(key):cells[key]=[]
        cells[key].append(id)
func ambient_point(id: String,delta: float) -> Vector3:
    var s=registry.states[id];var current=point(s.position)
    if s.mode in ["confined","dead"]:return current
    if s.wait97>0:s.wait97=maxf(0,s.wait97-delta);return current
    var path=config.paths[s.route];var target=point(path[int(s.waypoint)])
    if current.distance_to(target)<.08:
        s.visits97=int(s.visits97)+1
        if s.visits97%5==0:s.direction97=-int(s.direction97)
        s.waypoint=posmod(int(s.waypoint)+int(s.direction97),path.size())
        s.wait97=.7+float(posmod(hash(id)+s.visits97*17,29))*.1;return current
    var direction=target-current;direction.y=0;direction=direction.normalized()
    for angle in [0,35,-35,70,-70]:
        var p=current+direction.rotated(Vector3.UP,deg_to_rad(angle))*minf(current.distance_to(target),float(registry.definitions[id].wander_speed)*delta)
        var floor=_floor(p)
        if floor!=null and _edge(current,floor) and _separated(id,floor):s.blocked=0.0;return floor
    s.blocked+=delta
    if s.blocked>3:s.waypoint=posmod(int(s.waypoint)+int(s.direction97),path.size());s.blocked=0.0
    return current
