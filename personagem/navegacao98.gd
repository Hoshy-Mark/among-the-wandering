extends "res://personagem/navegacao84.gd"
func project(point: Vector3) -> Variant:return world.motor._floor(point)
func walk_clear(a: Vector3,b: Vector3) -> bool:
    if not free_at(a) or not free_at(b) or absf(a.y-b.y)>.085:return false
    if a.distance_to(b)<.00001:return true
    var upper=Vector3(a.x,maxf(a.y,b.y),a.z)
    if not free_at(upper):return false
    var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=3;query.margin=.0001
    query.transform=Transform3D(Basis.IDENTITY,upper+Vector3.UP*.942);query.motion=Vector3(b.x-a.x,0,b.z-a.z);query.exclude=excludes()
    return get_world_3d().direct_space_state.cast_motion(query)[0]>.9999
