extends "res://personagem/zumbi91.gd"
var flank_sign94=1.0
var flank_hold94=0.0
var flank_steps94=0
var blocked94=0.0
var last_stimulus94=""
var queue_wait_steps94=0
var queue_backoffs94=0
func setup(root_scene: Node3D,definition: Dictionary) -> void:
    super.setup(root_scene,definition)
    flank_sign94=1.0 if identity.ends_with("01") else -1.0
func sees_player() -> bool:
    var p=scene.player;var delta=p.global_position-global_position;delta.y=0
    var reach=3.5 if p.crouched else 6.5
    if absf(p.global_position.y-global_position.y)>=.8 or delta.length()>reach:return false
    if delta.length()>=.05 and avatar.global_basis.z.dot(delta.normalized())<cos(deg_to_rad(55)):return false
    # Bodies interrupt attacks, not visual detection of the player behind them.
    var ignore: Array[RID]=[get_rid()]
    for other in scene.zombie_world.actors.values():
        if other!=self:ignore.append(other.get_rid())
    var query=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.15,p.global_position+Vector3.UP*1.15,3,ignore)
    var hit=get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.collider==p
func hear_shot(point: Vector3,radius: float) -> void:
    if not point.is_finite() or not is_finite(radius) or radius<=0 or state in ["dying","dead"] or global_position.distance_to(point)>radius:return
    var changed_goal=last_known.distance_to(point)>.8
    last_known=point;memory=4.0;search_remaining=12.0;last_stimulus94="shot"
    # Preserve an already useful route, including an incremental request still in flight.
    if changed_goal:clear_route();replan_delay=0
    if state=="idle":state="search";elapsed=0
func _dynamic_step94(point: Vector3) -> bool:
    var floor=navigator().project(point)
    if floor==null or not navigator().walk_clear(global_position,floor):return false
    var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule.shape
    query.transform=Transform3D(Basis.IDENTITY,global_position+Vector3.UP*.942)
    query.motion=floor-global_position;query.exclude=[get_rid()];query.collision_mask=3;query.margin=.0001
    return get_world_3d().direct_space_state.cast_motion(query)[0]>.9999 and navigator().local_clear(self,floor)
func steer(goal: Vector3) -> Vector3:
    var normal=super.steer(goal)
    # The owner may need to retreat to the entry. Keep followers out of that space.
    for edge in route:
        if edge.kind!="portal":continue
        var owner=edge.source.owner_ref.get_ref() if is_instance_valid(edge.source) and edge.source.owner_ref!=null else null
        var distance=global_position.distance_to(edge.point)
        if is_instance_valid(owner) and owner!=self and distance<1.4:
            queue_wait_steps94+=1;flank_hold94=0
            if distance<.9:
                var away: Vector3=global_position-edge.point;away.y=0
                if away.length()<.01:away=edge.point-edge.exit;away.y=0
                away=away.normalized()
                if _dynamic_step94(global_position+away*.20):queue_backoffs94+=1;return away
            return Vector3.ZERO
        break
    if normal.length()>.01 and flank_hold94<=0:blocked94=0;return normal
    # Keep portals and unfinished paths under the navigator's existing reservation rules.
    if path_pending or route.is_empty() or route[0].kind!="walk":return normal
    for edge in route:
        if edge.kind=="portal":
            if global_position.distance_to(edge.point)<1.5:return normal
            break
    if blocked94<.12 and flank_hold94<=0:return normal
    var toward: Vector3=route[0].point-global_position;toward.y=0
    if toward.length()<.015:return normal
    toward=toward.normalized()
    for sign_value in [flank_sign94,-flank_sign94]:
        for angle in [60,85]:
            var direction=toward.rotated(Vector3.UP,deg_to_rad(angle)*sign_value)
            if _dynamic_step94(global_position+direction*.32):
                flank_sign94=sign_value
                if flank_hold94<=0:flank_hold94=.35
                flank_steps94+=1;return direction
    return normal
func step(delta: float) -> void:
    if not is_finite(delta) or delta<=0:return
    flank_hold94=maxf(0,flank_hold94-delta)
    var before=global_position
    super.step(delta)
    if state in ["chase","search"] and memory>0 and not crossing.is_active():
        if Vector2(global_position.x-before.x,global_position.z-before.z).length()<.002:blocked94=minf(2,blocked94+delta)
        else:blocked94=maxf(0,blocked94-delta*.25)
    else:blocked94=0;flank_hold94=0
func restore(data: Dictionary) -> void:
    super.restore(data);flank_sign94=1.0 if identity.ends_with("01") else -1.0;flank_hold94=0;blocked94=0;flank_steps94=0;last_stimulus94="";queue_wait_steps94=0;queue_backoffs94=0
