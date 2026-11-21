extends "res://personagem/portas74.gd"
var includes_windows=false

func setup(owner_scene: Node3D) -> void:
    super.setup(owner_scene)
    var args=OS.get_cmdline_user_args()
    if "--qa-doors" in args or "--capture-doors" in args:return
    _install_windows()
    includes_windows=true

func _pose(data: Dictionary, fraction: float) -> Transform3D:
    var axis: Vector3=data.get("axis",Vector3.UP)
    return Transform3D(Basis(axis,data.angle*fraction)*data.closed_basis,data.hinge.position)

func _install_windows() -> void:
    var house: Node3D=scene.world_items.house
    var model: Node3D=house.home.model
    var visual: Node3D=house.home.building.get_node("Visual")
    scene.city.static_batcher.restore_tree(visual)
    var glass: MeshInstance3D=visual.find_child("H01_VIDROS_RECUADOS",true,false)
    var frame: MeshInstance3D=visual.find_child("H01_CAIXILHOS",true,false)
    var glass_material=glass.get_active_material(0)
    var wood_material=frame.get_active_material(0)
    glass.visible=false
    var mullions: MeshInstance3D=visual.find_child("H01_MONTANTES",true,false)
    mullions.visible=false
    if scene.city.get_meta("spatial_revision_enabled",false):house.home.walls.erase(glass);house.home.walls.erase(mullions)
    var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/janelas_h01_75.json"))
    for original in config.windows:
        var definition:Dictionary=original.duplicate(true)
        if scene.city.get_meta("spatial_revision_enabled",false):
            var rule:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://staging/e06_world/arroio/spatial_loot/layouts.json")).houses.H01;var f:float=rule.factor_xz;var a:Array=rule.anchor_xz
            definition.center[0]=a[0]+(definition.center[0]-a[0])*f;definition.center[2]=a[1]+(definition.center[2]-a[1])*f;definition.size[0]*=f;definition.size[2]*=f
            if definition.has("positive_width_inset"):definition.positive_width_inset*=f
        var center=Vector3(definition.center[0],definition.center[1],definition.center[2])
        var source_size=Vector3(definition.size[0],definition.size[1],definition.size[2])
        var normal=Vector3(definition.normal[0],definition.normal[1],definition.normal[2])
        var across=normal.cross(Vector3.UP)
        var width=source_size.z if absf(normal.x)>.5 else source_size.x
        width-=.02
        var inset: float=definition.get("positive_width_inset",0)
        if inset>0:
            var lateral=Vector3.BACK if absf(normal.x)>.5 else Vector3.RIGHT
            var old_edge=center+lateral*(width/2)
            var filler_center=old_edge-lateral*(inset/2-.0125)+normal*.065
            var filler_size=Vector3(.19,source_size.y,inset+.015) if absf(normal.x)>.5 else Vector3(inset+.015,source_size.y,.19)
            house._panel(model,filler_size,filler_center,wood_material)
            var jamb=StaticBody3D.new()
            jamb.name="WindowJamb_"+str(definition.id).get_file()
            model.add_child(jamb)
            var collision=CollisionShape3D.new()
            var box=BoxShape3D.new()
            box.size=filler_size
            box.margin=.001
            collision.shape=box
            collision.position=filler_center
            jamb.add_child(collision)
            center-=lateral*inset/2
            width-=inset
        var height=source_size.y-.04
        var hinge=Node3D.new()
        hinge.name="Window_"+str(definition.id).get_file()
        model.add_child(hinge)
        hinge.position=center+Vector3.UP*(height/2)+normal*.03
        var leaf=MeshInstance3D.new()
        var pane=BoxMesh.new()
        pane.size=Vector3(.012,height,width) if absf(normal.x)>.5 else Vector3(width,height,.012)
        leaf.mesh=pane
        leaf.material_override=glass_material
        leaf.position=center-hinge.position
        hinge.add_child(leaf)
        var full_size=Vector3(.06,height,width) if absf(normal.x)>.5 else Vector3(width,height,.06)
        for side in [-1,1]:
            var stile=Vector3(.06,height,.028) if absf(normal.x)>.5 else Vector3(.028,height,.06)
            house._panel(hinge,stile,leaf.position+across*side*(width-.028)/2,wood_material)
            var rail=Vector3(.06,.028,width) if absf(normal.x)>.5 else Vector3(width,.028,.06)
            house._panel(hinge,rail,leaf.position+Vector3.UP*side*(height-.028)/2,wood_material)
        var middle=Vector3(.06,height,.045) if absf(normal.x)>.5 else Vector3(.045,height,.06)
        house._panel(hinge,middle,leaf.position,wood_material)
        var body=StaticBody3D.new()
        body.name="WindowCollision"
        hinge.add_child(body)
        var collider=CollisionShape3D.new()
        var shape=BoxShape3D.new()
        shape.size=full_size
        shape.margin=.001
        collider.shape=shape
        collider.position=leaf.position
        body.add_child(collider)
        var pick=StaticBody3D.new()
        pick.collision_layer=4
        pick.collision_mask=0
        hinge.add_child(pick)
        var pick_shape=CollisionShape3D.new()
        pick_shape.shape=shape
        pick_shape.position=leaf.position
        pick.add_child(pick_shape)
        pick.set_meta("door_id",definition.id)
        doors[definition.id]={"id":definition.id,"kind":"window","name":definition.name,"hinge":hinge,"leaf":leaf,"closed_basis":Basis.IDENTITY,"angle":PI/2,"axis":across,"body":body,"collider":collider,"fraction":0.0,"target":0.0,"open":false,"exterior":true}
    # Remove only the old combined glazing from the outer static collision.
    # Wall openings, frames, floors and roofs retain their original geometry.
    var faces=PackedVector3Array()
    _static_faces(visual,glass,faces)
    var shape=ConcavePolygonShape3D.new()
    shape.backface_collision=true
    shape.set_faces(faces)
    house.home.building.get_node("BuildingCollision").get_child(0).shape=shape
    scene.city.static_batcher.batch_tree(visual)

func _static_faces(node: Node, excluded: Node, faces: PackedVector3Array) -> void:
    if node==excluded or str(node.name) in ["H01_MONTANTES","_StaticRender","ReadableWallBase"]:return
    if node is MeshInstance3D:
        var pose: Transform3D=scene.world_items.house.home.building.global_transform.affine_inverse()*node.global_transform
        for vertex in node.mesh.get_faces():faces.append(pose*vertex)
    for child in node.get_children():_static_faces(child,excluded,faces)

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if prompt.visible and doors[nearest].get("kind","")=="window":
        prompt.text="Libere espaço para a janela" if blocked_time>0 else "Movendo janela..." if busy() else "E · Fechar janela" if doors[nearest].open else "E · Abrir janela"

func snapshot() -> Dictionary:
    var data=super.snapshot()
    if includes_windows:data.version=2
    return data

func prepare_restore(value: Variant) -> Dictionary:
    if not includes_windows:return super.prepare_restore(value)
    if busy():return {}
    var candidate: Dictionary={"version":2,"states":{}}
    for id in doors:candidate.states[id]=false
    if value!=null:
        if not value is Dictionary or not value.get("states") is Dictionary:return {}
        if value.get("version")==1:
            var original: Array=doors.keys().filter(func(id):return not str(id).contains("/window/"))
            if value.states.size()!=original.size():return {}
            for id in original:
                if not value.states.has(id) or not value.states[id] is bool:return {}
                candidate.states[id]=value.states[id]
        elif value.get("version")==2:
            if value.states.size()!=doors.size():return {}
            for id in doors:
                if not value.states.has(id) or not value.states[id] is bool:return {}
                candidate.states[id]=value.states[id]
        else:return {}
    for id in doors:
        if not _clear(doors[id],1.0 if candidate.states[id] else 0.0):return {}
    return candidate

func _process(_delta: float) -> void:
    if not includes_windows or nearest.is_empty() or doors[nearest].get("kind","")!="window":return
    var home: Dictionary=scene.world_items.house.home
    if home.inside:return
    var camera: Camera3D=scene.camera
    var target: Vector3=scene.player.global_position+Vector3.UP*1.2
    var occluders: Array=home.roofs.duplicate()
    occluders.append_array(home.walls)
    for roof in occluders:
        var inverse: Transform3D=roof.global_transform.affine_inverse()
        if roof.mesh.get_aabb().grow(.04).intersects_segment(inverse*camera.global_position,inverse*target)!=null:
            roof.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
