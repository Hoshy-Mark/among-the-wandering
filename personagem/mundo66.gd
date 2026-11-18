extends Node3D

const OPEN_TIME=.32
const CLOSE_TIME=.24
var player: CharacterBody3D
var ui: Control
var visuals: Dictionary={}
var progress: Dictionary={}
var pending_id=""
var active_id=""
var nearest_id=""
var prompt: Label3D

func setup(body: CharacterBody3D, interface: Control) -> void:
    player=body
    ui=interface
    player.world_interaction=self
    prompt=Label3D.new()
    prompt.font_size=30
    prompt.pixel_size=.0035
    prompt.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    prompt.modulate=Color("f6df9e")
    add_child(prompt)
    player.bag_inventory.changed.connect(refresh)
    refresh()

func has_interaction() -> bool:
    return not pending_id.is_empty() or not active_id.is_empty()

func _physics_process(delta: float) -> void:
    advance(delta)

func advance(delta: float) -> void:
    if not is_finite(delta) or delta<0:
        return
    var model: RefCounted=player.bag_inventory
    var current=active_id if not active_id.is_empty() else pending_id
    if not current.is_empty() and (current not in model.reachable or player.reaction.is_active() or (not pending_id.is_empty() and player.action.state=="idle")):
        close_interaction()
    for id in model.world_containers:
        var opening=id==pending_id or model.is_open(id)
        progress[id]=move_toward(float(progress.get(id,0)),1.0 if opening else 0.0,delta/(OPEN_TIME if opening else CLOSE_TIME))
        _pose(id)
    if not pending_id.is_empty() and float(progress.get(pending_id,0))>=1:
        var id=pending_id
        pending_id=""
        if model.set_open(id,true) and ui.show_container(id):
            active_id=id
        else:
            model.set_open(id,false)
            close_interaction()
    _update_prompt()

func interact_nearest() -> bool:
    if has_interaction():
        close_interaction()
        return true
    player.update_nearby()
    _update_prompt()
    return request_open(nearest_id)

func request_open(id: String) -> bool:
    player.update_nearby()
    var model: RefCounted=player.bag_inventory
    if has_interaction() or id not in model.reachable or not model.world_containers.has(id) or model.world_containers[id].kind=="ground":
        ui.feedback.text="Aproxime-se de um recipiente para abrir."
        return false
    if not player.request_gesture():
        ui.feedback.text="Conclua a ação atual antes de abrir."
        return false
    if not player.set_hud_open(true):
        player.action.cancel()
        return false
    var direction: Vector3=model.point(id)-player.global_position
    player.avatar.rotation.y=atan2(direction.x,direction.z)
    player.velocity.x=0
    player.velocity.z=0
    pending_id=id
    return true

func close_interaction(hide_inventory: bool=true) -> void:
    var ids=[pending_id,active_id]
    pending_id=""
    active_id=""
    for id in ids:
        if not id.is_empty():
            player.bag_inventory.set_open(id,false)
    if player.action.state!="idle" and player.action.action_id=="access":
        player.action.cancel()
    if hide_inventory:
        ui.windows[0].visible=false
    player.set_hud_open(ui.windows.any(func(window):return window.visible))
    _update_prompt()

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT:
        return
    var camera=get_viewport().get_camera_3d()
    if camera==null:
        return
    var origin=camera.project_ray_origin(event.position)
    var query=PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(event.position)*80,4)
    var hit=get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider.has_meta("container_id"):
        var id: String=hit.collider.get_meta("container_id")
        if id==active_id or id==pending_id:
            close_interaction()
        else:
            request_open(id)
        get_viewport().set_input_as_handled()

func _update_prompt() -> void:
    nearest_id=""
    var distance=INF
    var model: RefCounted=player.bag_inventory
    for id in model.reachable:
        if model.world_containers.has(id) and model.world_containers[id].kind!="ground":
            var candidate=player.global_position.distance_squared_to(model.point(id))
            if candidate<distance:
                distance=candidate
                nearest_id=id
    prompt.visible=not nearest_id.is_empty()
    if prompt.visible:
        prompt.global_position=model.point(nearest_id)+Vector3(0,1.52 if model.world_containers[nearest_id].kind=="cabinet" else .9,0)
        prompt.text="E · Fechar" if has_interaction() else "E · Abrir"

func refresh() -> void:
    var model: RefCounted=player.bag_inventory
    if has_interaction():
        var current=active_id if not active_id.is_empty() else pending_id
        if not model.world_containers.has(current) or (not active_id.is_empty() and not model.is_open(current)):
            close_interaction()
    for id in visuals.keys():
        if not model.world_containers.has(id):
            visuals[id].queue_free()
            visuals.erase(id)
            progress.erase(id)
    for id in model.world_containers:
        var entry: Dictionary=model.world_containers[id]
        var contents: Array=model.contents(id)
        if entry.kind=="ground" and contents.is_empty():
            if visuals.has(id):
                visuals[id].queue_free()
                visuals.erase(id)
            continue
        if not visuals.has(id):
            visuals[id]=_build(id,entry.kind)
        var node: Node3D=visuals[id]
        node.global_position=model.point(id)
        node.get_node("Title").text=entry.name
        var props=node.get_node("Contents")
        for child in props.get_children():
            child.queue_free()
            child.visible=false
        if entry.kind=="ground" or model.is_open(id):
            for index in mini(contents.size(),6):
                var definition: Dictionary=model.catalog[model.items[contents[index]].definition]
                var bag=definition.has("capacity")
                var offset=Vector3(.4+(index%3)*.18,.16 if bag else .05,floori(index/3.0)*.15) if entry.kind=="ground" else Vector3(-.20+(index%3)*.20,.35 if index<3 else .70,-.04)
                if entry.kind=="crate":
                    offset=Vector3(-.20+(index%3)*.20,.20 if bag else .12,-.12 if index<3 else .12)
                _box(props,Vector3(.25,.30,.14) if bag else Vector3(.11,.13,.10),offset,Color(definition.get("color","bca673")))
        _pose(id)
    _update_prompt()

func _build(id: String, kind: String) -> Node3D:
    var node=Node3D.new()
    add_child(node)
    var props=Node3D.new()
    props.name="Contents"
    node.add_child(props)
    if kind=="cabinet":
        node.rotation.y=-PI/4
        var color=Color("506258")
        _box(node,Vector3(.70,1.10,.04),Vector3(0,.55,.20),color)
        for side in [-1,1]:
            _box(node,Vector3(.04,1.10,.43),Vector3(.33*side,.55,0),color)
            var hinge=Node3D.new()
            hinge.name="DoorLeft" if side==-1 else "DoorRight"
            hinge.position=Vector3(.34*side,.55,-.235)
            node.add_child(hinge)
            _box(hinge,Vector3(.335,1.04,.035),Vector3(-.1675*side,0,0),Color("708178"))
            _box(hinge,Vector3(.025,.16,.035),Vector3(-.285*side,.05,-.035),Color("c1b28b"))
        for height in [.04,.28,.64,1.08]:
            _box(node,Vector3(.66,.04,.43),Vector3(0,height,0),color)
        _solid(node,id,Vector3(.70,1.10,.43),Vector3(0,.55,0))
    elif kind=="crate":
        var color=Color("736043")
        _box(node,Vector3(.65,.04,.5),Vector3(0,.02,0),color)
        for side in [-1,1]:
            _box(node,Vector3(.035,.42,.5),Vector3(.31*side,.21,0),color)
            _box(node,Vector3(.65,.42,.035),Vector3(0,.21,.235*side),color)
        var lid=Node3D.new()
        lid.name="Lid"
        lid.position=Vector3(0,.445,.25)
        node.add_child(lid)
        _box(lid,Vector3(.69,.05,.54),Vector3(0,0,-.25),Color("9b8157"))
        _solid(node,id,Vector3(.65,.42,.50),Vector3(0,.21,0))
    var label=Label3D.new()
    label.name="Title"
    label.position=Vector3(.4 if kind=="ground" else 0,1.30 if kind=="cabinet" else .64,0)
    label.font_size=24
    label.pixel_size=.0035
    label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    node.add_child(label)
    return node

func _pose(id: String) -> void:
    if not visuals.has(id):
        return
    var node: Node3D=visuals[id]
    var eased=smoothstep(0,1,float(progress.get(id,0)))
    if node.has_node("DoorLeft"):
        node.get_node("DoorLeft").rotation.y=deg_to_rad(102)*eased
        node.get_node("DoorRight").rotation.y=-deg_to_rad(102)*eased
    elif node.has_node("Lid"):
        node.get_node("Lid").rotation.x=deg_to_rad(105)*eased

func _solid(parent: Node3D, id: String, size: Vector3, offset: Vector3) -> void:
    var solid=StaticBody3D.new()
    solid.position=offset
    solid.collision_layer=6
    solid.collision_mask=0
    solid.set_meta("container_id",id)
    parent.add_child(solid)
    var collider=CollisionShape3D.new()
    var box=BoxShape3D.new()
    box.size=size
    collider.shape=box
    solid.add_child(collider)

func _box(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> void:
    var visual=MeshInstance3D.new()
    var box=BoxMesh.new()
    box.size=size
    visual.mesh=box
    visual.position=offset
    var material=StandardMaterial3D.new()
    material.albedo_color=color
    material.roughness=1
    visual.material_override=material
    parent.add_child(visual)
