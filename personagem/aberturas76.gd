extends "res://personagem/aberturas75.gd"

func _install_windows() -> void:
    super._install_windows()
    var args=OS.get_cmdline_user_args()
    if "--qa-windows" in args or "--capture-windows" in args:return
    var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/variacoes_janelas77.json"))
    for definition in config.windows:
        var data: Dictionary=doors[definition.id]
        data.mechanism=definition.mechanism
        if definition.mechanism=="awning":continue
        var parent: Node3D=data.hinge.get_parent()
        var center: Vector3=data.hinge.transform*data.leaf.position
        var normal=Vector3(definition.normal[0],definition.normal[1],definition.normal[2])
        var across=normal.cross(Vector3.UP)
        var width: float=data.collider.shape.size.z if absf(normal.x)>.5 else data.collider.shape.size.x
        var height: float=data.collider.shape.size.y
        var glass: Material=data.leaf.material_override
        var wood: Material
        for child in data.hinge.get_children():
            if child is MeshInstance3D and child!=data.leaf:
                wood=child.material_override
                break
        parent.remove_child(data.hinge)
        data.hinge.queue_free()
        var parts: Array=[]
        if definition.mechanism=="casement_pair":
            for side in [-1,1]:
                var pane_center=center+across*side*width/4
                var pivot=center+across*side*width/2+normal*.03
                var direction=(Basis(Vector3.UP,.1)*(pane_center-pivot)+pivot-pane_center).dot(normal)
                parts.append(_piece(parent,pane_center,width/2-.006,height,normal,pivot,Vector3.UP,signf(direction)*PI/2,Vector3.ZERO,glass,wood))
        elif definition.mechanism=="horizontal_slider":
            var fixed=center-across*width/4+normal*.015
            var moving=center+across*width/4+normal*.075
            parts.append(_piece(parent,moving,width/2-.006,height,normal,moving,Vector3.UP,0,-across*width/2,glass,wood))
            parts.append(_piece(parent,fixed,width/2-.006,height,normal,fixed,Vector3.UP,0,Vector3.ZERO,glass,wood))
        elif definition.mechanism=="sash":
            var upper=center+Vector3.UP*height/4+normal*.015
            var lower=center-Vector3.UP*height/4+normal*.075
            parts.append(_piece(parent,lower,width,height/2-.006,normal,lower,Vector3.UP,0,Vector3.UP*height/2,glass,wood))
            parts.append(_piece(parent,upper,width,height/2-.006,normal,upper,Vector3.UP,0,Vector3.ZERO,glass,wood))
        data.parts=parts
        data.aperture_point=parent.to_global(center)
        data.aperture_size=Vector2(width,height)
        data.free_opening=Vector2(width,height/2) if definition.mechanism=="sash" else Vector2(width/2,height) if definition.mechanism=="horizontal_slider" else Vector2(width,height)
        var first: Dictionary=parts[0]
        for key in ["hinge","body","collider","leaf"]:data[key]=first[key]
        for part in parts:
            part.pick.set_meta("door_id",definition.id)

func _piece(parent: Node3D, center: Vector3, width: float, height: float, normal: Vector3, pivot: Vector3, axis: Vector3, angle: float, travel: Vector3, glass: Material, wood: Material) -> Dictionary:
    var hinge=Node3D.new()
    hinge.name="WindowPart"
    parent.add_child(hinge)
    hinge.position=pivot
    var leaf=MeshInstance3D.new()
    var pane=BoxMesh.new()
    pane.size=Vector3(.012,height,width) if absf(normal.x)>.5 else Vector3(width,height,.012)
    leaf.mesh=pane
    leaf.material_override=glass
    leaf.position=center-pivot
    hinge.add_child(leaf)
    var across=normal.cross(Vector3.UP)
    for side in [-1,1]:
        var stile=Vector3(.045,height,.028) if absf(normal.x)>.5 else Vector3(.028,height,.045)
        scene.world_items.house._panel(hinge,stile,leaf.position+across*side*(width-.028)/2,wood)
        var rail=Vector3(.045,.028,width) if absf(normal.x)>.5 else Vector3(width,.028,.045)
        scene.world_items.house._panel(hinge,rail,leaf.position+Vector3.UP*side*(height-.028)/2,wood)
    var body=StaticBody3D.new()
    body.name="WindowPartCollision"
    hinge.add_child(body)
    var collision=CollisionShape3D.new()
    var box=BoxShape3D.new()
    box.size=Vector3(.045,height,width) if absf(normal.x)>.5 else Vector3(width,height,.045)
    box.margin=.001
    collision.shape=box
    collision.position=leaf.position
    body.add_child(collision)
    var pick=StaticBody3D.new()
    pick.collision_layer=4
    pick.collision_mask=0
    hinge.add_child(pick)
    var click=CollisionShape3D.new()
    click.shape=box
    click.position=leaf.position
    pick.add_child(click)
    return {"hinge":hinge,"leaf":leaf,"body":body,"collider":collision,"pick":pick,"closed":hinge.transform,"axis":axis,"angle":angle,"travel":travel}

func _part_pose(part: Dictionary, fraction: float) -> Transform3D:
    var pose: Transform3D=part.closed
    pose.basis=Basis(part.axis,part.angle*fraction)*pose.basis
    pose.origin+=part.travel*fraction
    return pose

func _pose(data: Dictionary, fraction: float) -> Transform3D:
    if data.has("parts"):return _part_pose(data.parts[0],fraction)
    return super._pose(data,fraction)

func _clear(data: Dictionary, fraction: float) -> bool:
    if not data.has("parts"):return super._clear(data,fraction)
    var exclusions: Array[RID]=[]
    for part in data.parts:exclusions.append(part.body.get_rid())
    for part in data.parts:
        var query=PhysicsShapeQueryParameters3D.new()
        query.shape=part.collider.shape
        query.transform=part.hinge.get_parent().global_transform*_part_pose(part,fraction)*part.body.transform*part.collider.transform
        query.collision_mask=3
        query.exclude=exclusions
        query.margin=.001
        var hits=get_world_3d().direct_space_state.intersect_shape(query,1)
        if not hits.is_empty():
            last_hit={"window":data.id,"fraction":fraction,"collider":str(hits[0].collider.name)}
            return false
    last_hit={"clear":true}
    return true

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    _sync_parts()

func _sync_parts() -> void:
    for data in doors.values():
        if data.has("parts"):
            for part in data.parts:part.hinge.transform=_part_pose(part,data.fraction)

func _distance(data: Dictionary) -> float:
    if not data.has("aperture_point"):return super._distance(data)
    var delta: Vector3=data.aperture_point-scene.player.global_position
    return Vector2(delta.x,delta.z).length()

func _reachable(data: Dictionary) -> bool:
    if not data.has("parts"):return super._reachable(data)
    if _distance(data)>1.6:return false
    var exclusions: Array[RID]=[scene.player.get_rid()]
    for part in data.parts:exclusions.append(part.body.get_rid())
    var ray=PhysicsRayQueryParameters3D.create(scene.player.global_position+Vector3.UP*1.1,data.aperture_point,3,exclusions)
    return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func apply_restore(candidate: Dictionary) -> void:
    super.apply_restore(candidate)
    _sync_parts()
