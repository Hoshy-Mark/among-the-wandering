extends Node3D
var scene: Node3D
var doors: Dictionary={}
var active=""
var pending=""
var nearest=""
var last_hit: Dictionary={}
var blocked_time=0.0
var prompt: Label3D

func setup(owner_scene: Node3D) -> void:
    scene=owner_scene
    var home: Dictionary=scene.world_items.house.home
    for data in home.doors:
        var id="H01/"+str(data.hinge.name)
        if data.exterior:
            data.closed_basis=data.hinge.get_meta("closed_basis")
        else:
            home.walls.erase(data.leaf)
            data.leaf.cast_shadow=data.leaf.get_meta("interior_original_shadow",GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
        data.id=id
        data.fraction=0.0
        data.target=0.0
        data.open=false
        data.body=data.hinge.get_node("DoorCollision")
        data.collider=data.body.get_child(0)
        data.collider.shape=data.collider.shape.duplicate()
        data.collider.shape.margin=.001
        if data.exterior:
            var vertices: PackedVector3Array=data.collider.shape.points
            for index in vertices.size():
                var world: Vector3=data.collider.global_transform*vertices[index]
                world.y=maxf(world.y,home.model.to_global(Vector3(0,home.rule.floor_local_y+.015,0)).y)
                vertices[index]=data.collider.to_local(world)
            data.collider.shape.points=vertices
        var vertices: PackedVector3Array=data.collider.shape.points
        var bounds=AABB(vertices[0],Vector3.ZERO)
        for point in vertices:bounds=bounds.expand(point)
        var proxy=BoxShape3D.new()
        proxy.size=bounds.size
        proxy.margin=.001
        data.collider.shape=proxy
        data.collider.position+=bounds.get_center()
        data.hinge.basis=data.closed_basis
        var closed_leaf_pose: Transform3D=data.leaf.global_transform
        if not data.exterior:
            var center: Vector3=data.hinge.get_parent().to_local(data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center())
            var offset=center-data.hinge.position
            offset.y=0
            offset=offset.normalized()*.03
            data.hinge.position+=offset
            for child in data.hinge.get_children():
                if child is Node3D:child.position-=data.hinge.basis.inverse()*offset
        assert(data.leaf.global_transform.is_equal_approx(closed_leaf_pose))
        var pick=StaticBody3D.new()
        pick.collision_layer=4
        pick.collision_mask=0
        data.hinge.add_child(pick)
        var shape=CollisionShape3D.new()
        shape.shape=data.collider.shape
        shape.transform=data.body.transform*data.collider.transform
        pick.add_child(shape)
        pick.set_meta("door_id",id)
        doors[id]=data
    scene.player.map_doors=self
    scene.player.action.cancelled.connect(_cancelled)
    prompt=Label3D.new()
    prompt.font_size=28
    prompt.pixel_size=.0035
    prompt.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    prompt.no_depth_test=true
    prompt.modulate=Color("f6df9e")
    add_child(prompt)

func busy() -> bool:
    return not active.is_empty() or not pending.is_empty()

func _pose(data: Dictionary, fraction: float) -> Transform3D:
    return Transform3D(Basis(Vector3.UP,data.angle*fraction)*data.closed_basis,data.hinge.position)

func _clear(data: Dictionary, fraction: float) -> bool:
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=data.collider.shape
    query.transform=data.hinge.get_parent().global_transform*_pose(data,fraction)*data.body.transform*data.collider.transform
    query.collision_mask=3
    query.exclude=[data.body.get_rid()]
    query.margin=.001
    var hits=get_world_3d().direct_space_state.intersect_shape(query,1)
    if not hits.is_empty():
        var hit: CollisionObject3D=hits[0].collider
        var owner=hit.shape_owner_get_owner(hit.shape_find_owner(hits[0].shape))
        last_hit={"door":data.id,"fraction":fraction,"collider":str(hit.name),"shape":str(owner.name)}
        return false
    last_hit={"clear":true}
    return true

func clear_path(id: String, target: float) -> bool:
    var data: Dictionary=doors[id]
    # A player may touch the current leaf. Test the future sweep, allowing
    # the door to move away from that contact while still checking its endpoint.
    for step in range(1,37):
        if not _clear(data,lerpf(data.fraction,target,step/36.0)):
            return false
    return true

func _distance(data: Dictionary) -> float:
    var center: Vector3=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()
    var delta=center-scene.player.global_position
    return Vector2(delta.x,delta.z).length()

func _reachable(data: Dictionary) -> bool:
    if _distance(data)>1.6:return false
    var from: Vector3=scene.player.global_position+Vector3.UP*1.1
    var center: Vector3=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()
    var ray=PhysicsRayQueryParameters3D.create(from,center,3,[scene.player.get_rid(),data.body.get_rid()])
    return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func prefers() -> bool:
    if scene.player.hud_open:return false
    _nearest()
    if nearest.is_empty():return false
    scene.player.update_nearby()
    scene.world_items._update_prompt()
    var id: String=scene.world_items.nearest_id
    if id.is_empty():return true
    return _distance(doors[nearest])<scene.player.global_position.distance_to(scene.player.bag_inventory.point(id))

func _nearest() -> void:
    nearest=""
    var distance=1.6
    for id in doors:
        if _distance(doors[id])<distance and _reachable(doors[id]):
            nearest=id
            distance=_distance(doors[id])

func request(id: String) -> bool:
    if busy() or not doors.has(id) or scene.player.hud_open or scene.world_items.has_interaction() or not _reachable(doors[id]):return false
    var target=0.0 if doors[id].open else 1.0
    if not clear_path(id,target):
        blocked_time=2.0
        scene.game_ui.feedback.text="Libere espaço para a porta"
        return false
    if not scene.player._prepare_action():return false
    var direction: Vector3=doors[id].leaf.global_transform*doors[id].leaf.mesh.get_aabb().get_center()-scene.player.global_position
    scene.player.avatar.rotation.y=atan2(direction.x,direction.z)
    scene.player.velocity.x=0
    scene.player.velocity.z=0
    blocked_time=0
    pending=id
    if not scene.player.action.begin(_commit,"access"):
        pending=""
        return false
    return true

func _commit() -> bool:
    var id=pending
    pending=""
    if id.is_empty() or not _reachable(doors[id]):return false
    var target=0.0 if doors[id].open else 1.0
    if not clear_path(id,target):
        blocked_time=2.0
        return false
    doors[id].target=target
    active=id
    return true

func _cancelled(kind: String, _done: bool) -> void:
    if kind=="access":pending=""

func _physics_process(delta: float) -> void:
    blocked_time=maxf(0,blocked_time-delta)
    if not active.is_empty():
        var data: Dictionary=doors[active]
        var next=move_toward(data.fraction,data.target,delta/.32)
        var safe=true
        for step in range(1,5):
            if not _clear(data,lerpf(data.fraction,next,step/4.0)):safe=false;break
        if safe:
            data.fraction=next
            data.hinge.transform=_pose(data,next)
            if is_equal_approx(next,data.target):
                data.open=data.target>0
                active=""
        else:
            blocked_time=.15
    _nearest()
    prompt.visible=not nearest.is_empty() and not scene.player.hud_open and not scene.world_items.has_interaction()
    if prompt.visible:
        var data: Dictionary=doors[nearest]
        prompt.global_position=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()+Vector3.UP*.35
        prompt.text="Libere espaço para a porta" if blocked_time>0 else "Movendo porta..." if busy() else "E · Fechar porta" if data.open else "E · Abrir porta"
        if prefers():scene.world_items.prompt.visible=false
        else:prompt.visible=false

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:return
    var camera=scene.camera
    var from=camera.project_ray_origin(event.position)
    var ray=PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(event.position)*80,4)
    var hit=get_world_3d().direct_space_state.intersect_ray(ray)
    if not hit.is_empty() and hit.collider.has_meta("door_id"):
        request(hit.collider.get_meta("door_id"))
        get_viewport().set_input_as_handled()

func snapshot() -> Dictionary:
    var states: Dictionary={}
    for id in doors:states[id]=bool(doors[id].open)
    return {"version":1,"states":states}

func prepare_restore(value: Variant) -> Dictionary:
    if busy():return {}
    var candidate: Dictionary={"version":1,"states":{}}
    if value==null:
        for id in doors:candidate.states[id]=false
    else:
        if not value is Dictionary or value.get("version")!=1 or not value.get("states") is Dictionary or value.states.size()!=doors.size():return {}
        for id in doors:
            if not value.states.has(id) or not value.states[id] is bool:return {}
            candidate.states[id]=value.states[id]
    # Loading is an atomic state restoration, not a door animation. Require the
    # destination pose free before allowing the inventory/profile to be applied.
    for id in doors:
        if not _clear(doors[id],1.0 if candidate.states[id] else 0.0):return {}
    return candidate

func apply_restore(candidate: Dictionary) -> void:
    for id in doors:
        var data: Dictionary=doors[id]
        data.open=candidate.states[id]
        data.fraction=1.0 if data.open else 0.0
        data.target=data.fraction
        data.hinge.transform=_pose(data,data.fraction)
