extends Node3D
signal resolved(event: Dictionary, accepted: bool)
var scene: Node3D
var serial=0
var pending_reaction=""
var costs={"punch":3.0,"push":2.0,"strike_onehand":4.0}
func setup(root_scene: Node3D) -> void:
    scene=root_scene
    scene.player.map_combat=self
func ready_to_act() -> bool:
    var p=scene.player
    return not p.paused and not p.hud_open and not p.traversal.is_active() and not p.reaction.is_active() and p.action.state=="idle" and not p.inventory_actions.busy() and p.flow.queue.is_empty() and not p.map_doors.busy() and not scene.world_items.has_interaction()
func candidates() -> Array:
    return get_tree().get_nodes_in_group("combat_receivers79")
func valid_target(node: Node3D, definition: Dictionary) -> bool:
    var p=scene.player
    if not is_instance_valid(node) or node==p or not node.has_method("receive_combat_hit"):return false
    var offset=node.global_position-p.global_position
    var horizontal=Vector3(offset.x,0,offset.z)
    if horizontal.length()>float(definition.reach) or absf(offset.y)>.55:return false
    var facing=p.avatar.global_basis.z.normalized()
    if horizontal.length()>.001 and facing.dot(horizontal.normalized())<cos(deg_to_rad(float(definition.cone_degrees))):return false
    var query=PhysicsRayQueryParameters3D.create(p.global_position+Vector3.UP*1.15,node.global_position+Vector3.UP*1.15,3,[p.get_rid()])
    var hit=get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.collider==node
func nearest(definition: Dictionary) -> Node3D:
    var found: Node3D
    var distance=INF
    for node in candidates():
        if valid_target(node,definition):
            var d=scene.player.global_position.distance_squared_to(node.global_position)
            if d<distance:distance=d;found=node
    return found
func request(kind: String="") -> bool:
    var p=scene.player
    if not ready_to_act() or p.combat.is_attacking():return false
    if kind.is_empty():kind="strike_onehand" if p.combat.armed else "punch"
    if not costs.has(kind) or p.condition_state.stamina<costs[kind]:return false
    if not p.set_crouch(false):return false
    var selected="push_armed" if kind=="push" and p.combat.armed else kind
    var definition: Dictionary=p.combat.definitions[selected].duplicate(true)
    var target=nearest(definition)
    serial+=1
    var event_id="combat79_"+Crypto.new().generate_random_bytes(12).hex_encode()+"_%d"%serial
    var receiver=weakref(target) if target!=null else null
    var accepted=p.combat.begin(kind,func() -> bool:
        # Lock the chosen target: a miss cannot jump to somebody else at impact.
        var victim=receiver.get_ref() if receiver!=null else null
        if not is_instance_valid(victim) or not valid_target(victim,definition):return false
        var event={"id":event_id,"action":kind,"zone":"chest","kind":"bruise","amount":.12 if kind=="punch" else .06 if kind=="push" else .22,"source_position":p.global_position}
        var result=victim.receive_combat_hit(event)
        var applied: bool=result is bool and result
        resolved.emit(event,applied)
        return applied
    )
    if accepted:
        p.condition_state.set_stamina(p.condition_state.stamina-costs[kind])
        p.preview_motion=""
    return accepted
func receive(event: Dictionary) -> bool:
    var p=scene.player
    if not event.get("id") is String or not event.get("zone") is String or not event.get("kind") is String:return false
    if event.id.strip_edges().is_empty():return false
    var amount=event.get("amount")
    if not (amount is float or amount is int) or not is_finite(float(amount)) or amount<=0 or amount>1:return false
    var source=event.get("source_position")
    if not source is Vector3 or not source.is_finite():return false
    if p.paused or p.reaction.state=="dead" or p.combat.executing_effect or p.action.executing_effect:return false
    if not p.body_health.hit(event.id,event.zone,event.kind,float(amount)):return false
    var local=p.avatar.global_basis.inverse()*(source-p.global_position)
    pending_reaction="hit_front" if absf(local.z)>=absf(local.x) and local.z>=0 else "hit_back" if absf(local.z)>=absf(local.x) else "hit_left" if local.x>0 else "hit_right"
    p.action.cancel()
    p.locomotion.cancel()
    p.combat.set_guard(false)
    _react()
    return true
func _react() -> void:
    var p=scene.player
    if not pending_reaction.is_empty() and not p.traversal.is_active() and not p.reaction.is_active() and p.request_reaction(pending_reaction):pending_reaction=""
func _physics_process(_delta: float) -> void:
    if scene==null:return
    _react()
    var p=scene.player
    if p.combat.guarding and not p.combat.is_attacking() and not p.scripted and not p.hud_open:
        var mouse=scene.get_viewport().get_mouse_position()
        var origin=scene.camera.project_ray_origin(mouse)
        var point=Plane(Vector3.UP,p.global_position.y).intersects_ray(origin,scene.camera.project_ray_normal(mouse))
        if point!=null:
            var direction: Vector3=point-p.global_position
            if Vector2(direction.x,direction.z).length()>.1:p.avatar.rotation.y=atan2(direction.x,direction.z)
