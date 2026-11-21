extends "res://personagem/aberturas83.gd"
## A short, collision-checked step makes room for a door that the player blocks.
var yield_id113=""
var yield_destination113=Vector3.ZERO
var yield_target113=0.0
var external_id118=""
func request_external118(data: Dictionary) -> bool:
    if busy():return false
    for key in doors:
        if doors[key].hinge==data.hinge:return request(key)
    var collider:CollisionShape3D=data.hinge.get_node("DoorCollision").get_child(0)
    if collider.shape is ConvexPolygonShape3D:
        var vertices=collider.shape.points
        var centre=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()
        var query=PhysicsRayQueryParameters3D.create(centre-Vector3.UP*.1,centre-Vector3.UP*2,1,[collider.get_parent().get_rid(),scene.player.get_rid()])
        var floor=get_world_3d().direct_space_state.intersect_ray(query)
        if not floor.is_empty() and floor.normal.y>.9:
            for index in vertices.size():
                var point=collider.global_transform*vertices[index];point.y=maxf(point.y,floor.position.y+.015);vertices[index]=collider.to_local(point)
        var bounds=AABB(vertices[0],Vector3.ZERO)
        for point in vertices:bounds=bounds.expand(point)
        var box=BoxShape3D.new();box.size=bounds.size;box.margin=.001
        collider.shape=box;collider.position+=bounds.get_center()
    if not collider.shape is BoxShape3D:return false
    var id="external118/"+str(data.hinge.get_instance_id())
    data.id=id;data.body=collider.get_parent();data.collider=collider;data.fraction=1.0 if data.open else 0.0;data.target=data.fraction
    doors[id]=data;calibrate_map118()
    var accepted=request(id)
    if accepted:external_id118=id
    else:doors.erase(id)
    return accepted
func calibrate_map118() -> void:
    if not scene.city.get_meta("spatial_revision_enabled",false):return
    for data in doors.values():
        if data.get("kind","")=="window" or data.get("exterior",false) or _world_sweep113(data,1):continue
        clear_path(data.id,1)
        if last_hit.get("collider","")!="InteriorCollision" or str(last_hit.get("shape","")).begins_with("Furniture_"):continue
        var closed=data.hinge.global_transform
        var normal=closed.basis.z.normalized() if data.collider.shape.size.z<data.collider.shape.size.x else closed.basis.x.normalized()
        var original=data.hinge.position;var children={}
        for child in data.hinge.get_children():
            if child is Node3D:children[child]=child.position
        for distance in [.01,-.01,.02,-.02,.03,-.03,.04,-.04,.05,-.05]:
            var offset=data.hinge.get_parent().global_basis.inverse()*normal*distance
            data.hinge.position=original+offset
            for child in children:child.position=children[child]-data.hinge.basis.inverse()*offset
            if _world_sweep113(data,1):
                data["pivot_clearance118"]=distance
                break
            data.hinge.position=original
            for child in children:child.position=children[child]

func yielding113() -> bool:return not yield_id113.is_empty()
func busy() -> bool:return not external_id118.is_empty() or yielding113() or super.busy()

func _world_sweep113(data: Dictionary,target: float) -> bool:
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=data.collider.shape
    query.collision_mask=3
    query.exclude=[data.body.get_rid(),scene.player.get_rid()]
    query.margin=.001
    for frame in range(1,37):
        query.transform=data.hinge.get_parent().global_transform*_pose(data,lerpf(data.fraction,target,frame/36.0))*data.body.transform*data.collider.transform
        if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
    return true

func _outside_sweep113(data: Dictionary,target: float,point: Vector3) -> bool:
    var p=scene.player
    var half: Vector3=data.collider.shape.size*.5
    for frame in range(37):
        var pose: Transform3D=data.hinge.get_parent().global_transform*_pose(data,lerpf(data.fraction,target,frame/36.0))*data.body.transform*data.collider.transform
        var local: Vector3=pose.affine_inverse()*(point+Vector3.UP*p.capsule.position.y)
        var scale=pose.basis.get_scale().abs()
        if absf(local.y)>half.y+p.capsule.shape.height*.5/maxf(.001,scale.y):continue
        var distance=Vector2(maxf(absf(local.x)-half.x,0),maxf(absf(local.z)-half.z,0)).length()
        if distance<(p.capsule.shape.radius+.035)/maxf(.001,minf(scale.x,scale.z)):return false
    return true

func _retreat113(data: Dictionary,target: float) -> Variant:
    var p=scene.player
    var centre: Vector3=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()
    var away=p.global_position-centre;away.y=0
    if away.length_squared()<.00001:away=p.avatar.global_basis.z*-1
    away=away.normalized()
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=p.capsule.shape;query.exclude=[p.get_rid()];query.collision_mask=3;query.margin=.001
    for distance in [.25,.40,.55,.70,.85,1.0]:
        for turn in [0,1,-1,2,-2,3,-3,4,-4,5,-5,6,-6,7,-7,8]:
            var point: Vector3=p.global_position+away.rotated(Vector3.UP,turn*PI/8)*distance
            if Vector2(point.x-centre.x,point.z-centre.z).length()>1.55 or not _outside_sweep113(data,target,point):continue
            query.transform=Transform3D(p.global_basis,point)*p.capsule.transform
            if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
            if p.test_move(p.global_transform,point-p.global_position):continue
            var floor_safe=true
            for frame in range(1,9):
                if not p.traversal._floor(p.global_position.lerp(point,frame/8.0)):floor_safe=false;break
            if floor_safe:return point
    return null

func request(id: String) -> bool:
    if busy() or not doors.has(id):return false
    var data: Dictionary=doors[id]
    if data.get("kind","")=="window":return super.request(id)
    var p=scene.player
    if p.hud_open or scene.world_items.has_interaction() or not _reachable(data):return false
    var target=0.0 if data.open else 1.0
    if clear_path(id,target):return super.request(id)
    # Other actors, furniture and walls still block the leaf normally.
    if not _world_sweep113(data,target):return super.request(id)
    var destination=_retreat113(data,target)
    if destination==null:return super.request(id)
    if not p._prepare_action():return false
    yield_destination113=destination;yield_target113=target;yield_id113=id
    p.velocity=Vector3.ZERO
    p.action.control_locked=true;p.combat.control_locked=true
    var direction: Vector3=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()-p.global_position;direction.y=0
    p.avatar.rotation.y=atan2(direction.x,direction.z)
    var movement=p.avatar.global_basis.inverse()*(yield_destination113-p.global_position).normalized()
    p.avatar.set_motion("backward" if movement.z<-.45 else "left" if movement.x<0 else "right")
    p.avatar.motion_rate=1.6
    blocked_time=0
    scene.game_ui.feedback.text="Abrindo espaço para a porta"
    return true

func _end_yield113() -> void:
    var p=scene.player
    yield_id113="";p.velocity=Vector3.ZERO
    if not p.reaction.is_active():
        p.action.control_locked=false;p.combat.control_locked=false
        p.avatar.motion_rate=1;p.avatar.set_motion("idle")

func advance_yield113(delta: float) -> void:
    if not yielding113() or not is_finite(delta) or delta<0:return
    var p=scene.player
    if p.paused:return
    if p.hud_open or p.reaction.is_active():_end_yield113();return
    var offset=yield_destination113-p.global_position
    var next=p.global_position+offset.limit_length(1.4*delta)
    if not p.traversal._floor(next):_end_yield113();return
    var collision=p.move_and_collide(next-p.global_position)
    if collision!=null and not (collision.get_normal().y>.8 and p.global_position.distance_to(next)<.015):
        _end_yield113();return
    p.avatar.advance(delta)
    # Begin the swing as soon as it is safe, overlapping the end of the step.
    if active.is_empty() and clear_path(yield_id113,yield_target113):
        doors[yield_id113].target=yield_target113;active=yield_id113
    if p.global_position.distance_to(yield_destination113)<.006:
        if active.is_empty() and _world_sweep113(doors[yield_id113],yield_target113) and _outside_sweep113(doors[yield_id113],yield_target113,p.global_position):
            doors[yield_id113].target=yield_target113;active=yield_id113
        _end_yield113()

func _physics_process(delta: float) -> void:
    if yielding113() and scene.player.paused:return
    super._physics_process(delta)
    if not external_id118.is_empty() and not yielding113() and active.is_empty() and pending.is_empty():
        if nearest==external_id118:nearest="";prompt.visible=false
        doors.erase(external_id118);external_id118=""
    if yielding113() and prompt.visible:prompt.text="Abrindo espaço para a porta..."

func _unhandled_input(event: InputEvent) -> void:
    if yielding113() and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
        _end_yield113();get_viewport().set_input_as_handled();return
    super._unhandled_input(event)
