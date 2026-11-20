extends Node3D

const WORLD="res://staging/e06_world/arroio/"
const SELECTED=["H01_FURN_GELADEIRA","H01_FURN_GUARDA_CASAL","H01_FURN_BALCAO_SERV","H01_FURN_COMODA_CASAL","H01_FURN_RACK01","H01_FURN_ROUPARIA","H01_FURN_PIA_COZ","H01_FURN_ESTANTE_Q2","H01_FURN_DESPENSA"]
var shell: Node3D
var home: Dictionary
var bindings: Dictionary={}
var groups: Dictionary={}
var scene: Node3D
var last_clearance: Dictionary={}
var visit_index=0

func setup(owner_scene: Node3D) -> void:
    scene=owner_scene
    var rule: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/h01_rule67.json")).lots.H01
    var building: Node3D=scene.city.get_node("UrbanSectors/"+str(rule.exterior_rule.sector)+"/H01")
    var old: Node3D=building.get_node("Visual")
    var pose=old.transform
    scene.city.static_batcher.restore_tree(old)
    building.remove_child(old)
    old.queue_free()
    for child in building.get_children():
        if str(child.name)=="BuildingCollision" or str(child.name).begins_with("ReviewDoor_"):
            building.remove_child(child)
            child.queue_free()
    var visual: Node3D=load(rule.exterior_rule.visual_path).instantiate()
    visual.name="Visual"
    visual.transform=pose
    building.add_child(visual)
    building._install_review_doors(visual)
    building.set_review_doors_open(true)
    var faces=PackedVector3Array()
    building._collect_faces(visual,faces)
    var body=StaticBody3D.new()
    body.name="BuildingCollision"
    building.add_child(body)
    var shape=ConcavePolygonShape3D.new()
    shape.backface_collision=true
    shape.set_faces(faces)
    var collider=CollisionShape3D.new()
    collider.shape=shape
    body.add_child(collider)
    shell=load("res://personagem/h01_shell67.gd").new()
    shell.name="HouseH01Interior"
    scene.add_child(shell)
    shell.configure(scene.city)
    home=shell.homes.H01
    shell.review_cut=true
    shell.set_doors_open("H01",true)
    for door in home.doors:
        if not door.exterior:
            door.leaf.set_meta("interior_original_shadow",door.leaf.cast_shadow)
            home.walls.append(door.leaf)
    scene.city.static_batcher.restore_tree(home.instance)
    scene.world_items.house=self
    for group in SELECTED:
        _activate(group)
    await get_tree().physics_frame
    _resolve_standing_points()
    scene.world_items.refresh()
    scene.player.update_nearby()

func _resolve_standing_points() -> void:
    var inventory: RefCounted=scene.player.bag_inventory
    for group in groups:
        var data: Dictionary=groups[group]
        var chosen: Vector3=data.point
        var found=false
        for distance in [.0,.3]:
            for side in [.0,.65,-.65,1.1,-1.1]:
                var candidate: Vector3=data.point+data.front*distance+data.front.cross(Vector3.UP)*side
                if standing_clear(candidate) and in_room(group,candidate):
                    chosen=candidate
                    found=true
                    break
            if found:
                break
        assert(found,"No clear standing point for "+group)
        data.point=chosen
        for id in bindings:
            if bindings[id]==group:
                var entry: Dictionary=inventory.house_anchors[id].duplicate(true)
                entry.position=[chosen.x,chosen.y,chosen.z]
                inventory.register_anchor(id,entry,[])

func standing_clear(point: Vector3) -> bool:
    var shape=CapsuleShape3D.new()
    shape.radius=.23
    shape.height=1.84
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=shape
    query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.94)
    query.collision_mask=3
    query.exclude=[scene.player.get_rid()]
    return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func in_room(group: String, point: Vector3) -> bool:
    var id="H01_ROOM_04" if group.contains("GELADEIRA") or group.contains("BALCAO") else "H01_ROOM_03"
    if group.contains("PIA"):
        id="H01_ROOM_04"
    elif group.contains("ESTANTE"):
        id="H01_ROOM_08"
    elif group.contains("DESPENSA"):
        id="H01_ROOM_05"
    elif group.contains("RACK"):
        id="H01_ROOM_01"
    elif group.contains("ROUPARIA"):
        id="H01_ROOM_06"
    var local: Vector3=home.model.to_local(point)
    for room in home.rule.rooms:
        if room.id==id:
            var polygon=PackedVector2Array()
            for vertex in room.polygon_xz:
                polygon.append(Vector2(vertex[0],vertex[1]))
            return Geometry2D.is_point_in_polygon(Vector2(local.x,local.z),polygon)
    return false

func visit_next() -> void:
    var ids: Array=[]
    for group in groups:
        for id in bindings:
            if bindings[id]==group:
                ids.append(id)
                break
    visit(str(ids[visit_index%ids.size()]))
    visit_index+=1

func visit(id: String) -> void:
    var body: CharacterBody3D=scene.player
    if body.traversal.is_active() or body.reaction.is_active() or body.combat.is_attacking():
        return
    scene.world_items.close_interaction()
    body.action.cancel()
    body.locomotion.cancel()
    body.preview_motion=""
    body.velocity=Vector3.ZERO
    body.global_position=groups[bindings[id]].point+Vector3.UP*.02
    body.update_nearby()
    scene.zoom=5.5
    scene.focus=body.global_position+Vector3.UP*.95
    scene._update_camera()

func _activate(group: String) -> void:
    var entry: Dictionary=home.preparation.entries[group]
    if entry.definition.role=="sink_cabinet":
        _prepare_sink(entry)
    # Source fronts face nearby partitions. Keep each center and orient the doors
    # toward the usable room, including the stove clearance in the kitchen.
    var alignment=Node3D.new()
    alignment.name="RoomFacing_"+group
    home.model.add_child(alignment)
    alignment.position=entry.bounds_model.get_center()
    entry.node.reparent(alignment,true)
    for mesh in entry.meshes.values():
        if not entry.node.is_ancestor_of(mesh):
            mesh.reparent(alignment,true)
    alignment.rotate_y(0 if group.contains("BALCAO") or group.contains("ROUPARIA") or entry.definition.role=="shelf" else (-PI/2 if entry.definition.role in ["fridge","sink_cabinet"] else PI))
    if group=="H01_FURN_RACK01":
        # The source rack intersects the sofa. Use the free wall in this lab.
        alignment.position.z-=2.3
    var first=true
    var aligned_bounds: AABB
    for mesh in entry.meshes.values():
        var current: AABB=(home.model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
        aligned_bounds=current if first else aligned_bounds.merge(current)
        first=false
    entry.bounds_model=aligned_bounds
    var parts: Array=[]
    var front=Vector3.ZERO
    for definition in entry.definition.parts:
        var data: Dictionary=home.preparation.articulations[definition.id]
        parts.append(data)
        front+=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()
    var bounds: AABB=entry.bounds_model
    var model: Node3D=home.model
    var center=model.to_global(bounds.get_center())
    front=(front/parts.size()-center) if not parts.is_empty() else (model.global_basis*Vector3.RIGHT)
    front.y=0
    # Door handles can be laterally offset. The mean leaf plane identifies the front.
    var direction=model.global_basis.inverse()*front
    direction=Vector3(signf(direction.x),0,0) if absf(direction.x)>absf(direction.z) else Vector3(0,0,signf(direction.z))
    front=(model.global_basis*direction).normalized()
    for data in parts:
        var closed_global: Transform3D=data.pivot.get_parent().global_transform*data.closed_transform
        var leaf_center: Vector3=data.leaf.global_transform*data.leaf.mesh.get_aabb().get_center()
        var moved: Vector3=(closed_global*Transform3D(Basis(data.axis,deg_to_rad(12)),Vector3.ZERO))*closed_global.affine_inverse()*leaf_center
        data.sign=1.0 if (moved-leaf_center).dot(front)>0 else -1.0
    var front_model=(model.global_basis.inverse()*front).normalized()
    var point=center+front*(absf(front_model.x)*bounds.size.x/2+absf(front_model.z)*bounds.size.z/2+.9)
    point.y=model.to_global(Vector3(0,float(home.rule.floor_local_y),0)).y
    var old_proxy=home.model.get_node("InteriorCollision/Furniture_"+group)
    old_proxy.set_deferred("disabled",true)
    var fixed=StaticBody3D.new()
    fixed.name="Active_"+group
    fixed.collision_layer=2
    fixed.collision_mask=0
    model.add_child(fixed)
    var proxy=CollisionShape3D.new()
    var box=BoxShape3D.new()
    box.size=bounds.size
    proxy.shape=box
    proxy.position=bounds.get_center()
    fixed.add_child(proxy)
    var pick=StaticBody3D.new()
    pick.collision_layer=4
    pick.collision_mask=0
    model.add_child(pick)
    var pick_shape=CollisionShape3D.new()
    pick_shape.shape=box
    pick_shape.position=bounds.get_center()
    pick.add_child(pick_shape)
    var cavity=_cavity(entry,front_model)
    var render_meshes: Array=entry.meshes.values()
    render_meshes.append_array(cavity.find_children("*","MeshInstance3D",true,false))
    var materials: Array=[]
    for mesh in render_meshes:
        if not mesh.visible:
            continue
        var originals: Array=[]
        var faded: Array=[]
        for surface in mesh.mesh.get_surface_count():
            var material=mesh.get_active_material(surface)
            originals.append(material)
            var ghost=material.duplicate() if material!=null else StandardMaterial3D.new()
            if ghost is BaseMaterial3D:
                ghost.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
                ghost.albedo_color.a=.22
            faded.append(ghost)
        materials.append({"mesh":mesh,"override":mesh.material_override,"originals":originals,"faded":faded})
    groups[group]={"role":entry.definition.role,"parts":parts,"body":fixed,"point":point,"front":front,"bounds":bounds,"pick":pick,"materials":materials,"faded":false}
    var model_inventory: RefCounted=scene.player.bag_inventory
    for compartment in entry.definition.compartments:
        var id="world:arroio:"+str(compartment.id)
        bindings[id]=group
        var label="Guarda-roupa · H01"
        var limit=20
        var seeds: Array=[["moletom_cinza",1],["bag_school",1]]
        var drawer=entry.definition.role.begins_with("cabinet_")
        if drawer:
            var number=int(str(compartment.id).get_slice("drawer_",1))
            var names={"H01_FURN_BALCAO_SERV":"Balcão","H01_FURN_COMODA_CASAL":"Cômoda","H01_FURN_RACK01":"Rack","H01_FURN_ROUPARIA":"Rouparia"}
            label=str(names[group])+" · Gaveta "+str(number)+" · H01"
            limit=8
            seeds=[["bandage",1]] if number==1 else []
        if entry.definition.role=="shelf":
            label=("Despensa" if group.contains("DESPENSA") else "Estante do quarto")+" · H01"
            limit=12
            seeds=[["food",1]] if group.contains("DESPENSA") else []
        elif entry.definition.role=="sink_cabinet":
            label="Armário da pia · H01"
            limit=12
            seeds=[]
        if entry.definition.role=="fridge":
            var freezer=str(compartment.id).ends_with("freezer")
            label="Congelador · H01" if freezer else "Geladeira · H01"
            limit=6 if freezer else 12
            seeds=[["food",1]] if freezer else [["food",2],["water",1]]
        model_inventory.register_anchor(id,{"name":label,"position":[point.x,point.y,point.z],"capacity":limit,"kind":"cabinet","house":"H01","furniture":group,"drawer":drawer},seeds)
        if not pick.has_meta("container_id"):
            pick.set_meta("container_id",id)
    if entry.definition.role.begins_with("cabinet_"):
        _complete_drawers(group,entry,front_model)
    entry.node.set_meta("gameplay_enabled",true)

func _cavity(entry: Dictionary, front: Vector3) -> Node3D:
    var carcass: MeshInstance3D=entry.meshes[entry.definition.source_meshes[0]]
    var bounds: AABB=(home.model.global_transform.affine_inverse()*carcass.global_transform)*carcass.mesh.get_aabb()
    var material=carcass.get_active_material(0)
    carcass.visible=false
    var root=Node3D.new()
    root.name="Cavity_"+str(entry.definition.id)
    home.model.add_child(root)
    var center=bounds.get_center()
    var size=bounds.size
    var thickness=.025
    # Keep the source silhouette and material while replacing its solid core.
    for side in [-1,1]:
        var offset=center+Vector3(0,side*(size.y-thickness)/2,0)
        _panel(root,Vector3(size.x,thickness,size.z),offset,material)
    if absf(front.z)>absf(front.x):
        for side in [-1,1]:
            _panel(root,Vector3(thickness,size.y,size.z),center+Vector3(side*(size.x-thickness)/2,0,0),material)
        _panel(root,Vector3(size.x,size.y,thickness),center-Vector3(0,0,signf(front.z)*(size.z-thickness)/2),material)
    else:
        for side in [-1,1]:
            _panel(root,Vector3(size.x,size.y,thickness),center+Vector3(0,0,side*(size.z-thickness)/2),material)
        _panel(root,Vector3(thickness,size.y,size.z),center-Vector3(signf(front.x)*(size.x-thickness)/2,0,0),material)
    var levels: Array=[] if entry.definition.role.begins_with("cabinet_") or entry.definition.role=="shelf" else ([.30,.62,.82] if entry.definition.role=="fridge" else [.32,.70])
    if entry.definition.role=="sink_cabinet":
        levels=[] # Leave the basin and plumbing clearance unobstructed.
    for fraction in levels:
        _panel(root,Vector3(size.x-.03,.018,size.z-.03),Vector3(center.x,bounds.position.y+size.y*fraction,center.z),material)
    return root

func _process(_delta: float) -> void:
    if home.is_empty():
        return
    var camera=get_viewport().get_camera_3d()
    if camera==null:
        return
    var model: Node3D=home.model
    var from=model.to_local(camera.global_position)
    var target=model.to_local(scene.player.global_position+Vector3.UP*1.25)
    for group in groups.values():
        var faded=not camera.get_meta("solid_world89",false) and group.bounds.intersects_segment(from,target)!=null
        if faded==group.faded:
            continue
        group.faded=faded
        for binding in group.materials:
            var mesh: MeshInstance3D=binding.mesh
            if binding.override!=null:
                mesh.material_override=binding.faded[0] if faded else binding.override
            else:
                for surface in binding.originals.size():
                    mesh.set_surface_override_material(surface,binding.faded[surface] if faded else binding.originals[surface])

func _panel(parent: Node3D, size: Vector3, point: Vector3, material: Material) -> void:
    var mesh=MeshInstance3D.new()
    var box=BoxMesh.new()
    box.size=size
    mesh.mesh=box
    mesh.position=point
    mesh.material_override=material
    parent.add_child(mesh)

func apply_fraction(group: String, fraction: float) -> void:
    for part in groups[group].parts:
        if part.definition.motion=="slide":
            continue
        part.pivot.transform=part.closed_transform*Transform3D(Basis(part.axis,deg_to_rad(90)*part.sign*fraction),Vector3.ZERO)
        part.fraction=fraction

func clear_to_open(id: String) -> bool:
    var group: String=bindings[id]
    var data: Dictionary=groups[group]
    if data.role=="sink_cabinet":
        for step in range(19):
            if not _sink_clear(data,step/18.0):
                return false
        last_clearance={"clear":true}
        return true
    if data.has("drawers"):
        var part: Dictionary=data.drawers[id]
        for step in range(19):
            if not _drawer_clear(data,part,step/18.0):
                return false
        last_clearance={"clear":true}
        return true
    for part in data.parts:
        for step in range(1,19):
            var query=PhysicsShapeQueryParameters3D.new()
            query.shape=part.proxy.shape
            var pose: Transform3D=part.closed_transform*Transform3D(Basis(part.axis,deg_to_rad(90)*part.sign*step/18.0),Vector3.ZERO)
            query.transform=part.pivot.get_parent().global_transform*pose*part.proxy.transform
            query.collision_mask=3
            query.exclude=[data.body.get_rid()]
            query.margin=.002
            var hits=get_world_3d().direct_space_state.intersect_shape(query,8)
            if not hits.is_empty():
                var hit_body: CollisionObject3D=hits[0].collider
                var owner_id=hit_body.shape_find_owner(hits[0].shape)
                var owner=hit_body.shape_owner_get_owner(owner_id)
                last_clearance={"part":part.definition.id,"step":step,"collider":str(hit_body.name),"shape":str(owner.name)}
                if owner is CollisionShape3D and owner.shape is BoxShape3D:
                    last_clearance["bounds"]=str(AABB(owner.position-owner.shape.size/2,owner.shape.size))
                return false
    last_clearance={"clear":true}
    return true

# Drawer boxes are built in model coordinates, then attached preserving pose.
# Existing fronts and handles remain the source geometry.
func _complete_drawers(group: String, entry: Dictionary, front: Vector3) -> void:
    var data: Dictionary=groups[group]
    data.pick.collision_layer=0
    data.drawers={}
    var material=entry.meshes[entry.definition.source_meshes[0]].get_active_material(0)
    var carcass: AABB=(home.model.global_transform.affine_inverse()*entry.meshes[entry.definition.source_meshes[0]].global_transform)*entry.meshes[entry.definition.source_meshes[0]].mesh.get_aabb()
    for part in data.parts:
        var face: AABB=(home.model.global_transform.affine_inverse()*part.leaf.global_transform)*part.leaf.mesh.get_aabb()
        var depth=maxf(.08,carcass.size.x-.07)
        var size=Vector3(depth,maxf(.06,face.size.y-.028),maxf(.06,face.size.z-.035))
        var center=face.get_center()-front*(depth/2+.0125)
        var root=Node3D.new()
        root.name="DrawerBox"
        home.model.add_child(root)
        var thickness=.012
        _panel(root,Vector3(size.x,thickness,size.z),center-Vector3(0,(size.y-thickness)/2,0),material)
        for side in [-1,1]:
            _panel(root,Vector3(size.x,size.y,thickness),center+Vector3(0,0,side*(size.z-thickness)/2),material)
        _panel(root,Vector3(thickness,size.y,size.z),center-front*(size.x-thickness)/2,material)
        root.reparent(part.pivot,true)
        var solid=StaticBody3D.new()
        solid.collision_layer=2
        solid.collision_mask=0
        home.model.add_child(solid)
        var collision=CollisionShape3D.new()
        var box=BoxShape3D.new()
        box.size=size+Vector3(.025,0,0)
        center+=front*.0125
        collision.shape=box
        collision.position=center
        solid.add_child(collision)
        solid.reparent(part.pivot,true)
        var pick=StaticBody3D.new()
        pick.collision_layer=4
        pick.collision_mask=0
        home.model.add_child(pick)
        var click=CollisionShape3D.new()
        var click_box=BoxShape3D.new()
        click_box.size=face.size+Vector3(.014,0,0)
        click.shape=click_box
        click.position=face.get_center()
        pick.add_child(click)
        pick.reparent(part.pivot,true)
        var id="world:arroio:"+group+"/storage/"+str(part.definition.id).get_slice("/",1)
        pick.set_meta("container_id",id)
        part.drawer_solid=solid
        part.drawer_collision=collision
        part.travel=minf(.30,depth*.68)
        part.translation=part.pivot.get_parent().global_basis.inverse()*data.front*part.travel
        data.drawers[id]=part
        for mesh in root.find_children("*","MeshInstance3D",true,false):
            var ghost=material.duplicate() if material!=null else StandardMaterial3D.new()
            if ghost is BaseMaterial3D:
                ghost.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
                ghost.albedo_color.a=.22
            data.materials.append({"mesh":mesh,"override":material,"originals":[material],"faded":[ghost]})

func _drawer_pose(part: Dictionary, fraction: float) -> Transform3D:
    var pose: Transform3D=part.closed_transform
    pose.origin+=part.translation*fraction
    return pose

func _drawer_clear(data: Dictionary, part: Dictionary, fraction: float) -> bool:
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=part.drawer_collision.shape
    var relative: Transform3D=part.pivot.global_transform.affine_inverse()*part.drawer_collision.global_transform
    query.transform=part.pivot.get_parent().global_transform*_drawer_pose(part,fraction)*relative
    query.collision_mask=3
    query.exclude=[data.body.get_rid(),part.drawer_solid.get_rid()]
    query.margin=.001
    var hits=get_world_3d().direct_space_state.intersect_shape(query,1)
    if not hits.is_empty():
        var hit: CollisionObject3D=hits[0].collider
        var owner=hit.shape_owner_get_owner(hit.shape_find_owner(hits[0].shape))
        last_clearance={"drawer":part.definition.id,"fraction":fraction,"collider":str(hit.name),"shape":str(owner.name),"at":str(query.transform.origin),"bounds":str(AABB(owner.position-owner.shape.size/2,owner.shape.size)) if owner is CollisionShape3D and owner.shape is BoxShape3D else "other"}
        return false
    return true

func apply_drawer(id: String, fraction: float) -> bool:
    var data: Dictionary=groups[bindings[id]]
    var part: Dictionary=data.drawers[id]
    if is_equal_approx(part.fraction,fraction):
        return true
    # Validate closing too; never retract a drawer through the player.
    for step in range(1,5):
        if not _drawer_clear(data,part,lerpf(part.fraction,fraction,step/4.0)):
            return false
    part.pivot.transform=_drawer_pose(part,fraction)
    part.fraction=fraction
    return true

# Rebuild the combined sink panel as two leaves with independent hinge pivots.
# The source GLTF and its original combined panel remain unchanged on disk.
func _prepare_sink(entry: Dictionary) -> void:
    var combined: MeshInstance3D=entry.meshes[entry.definition.source_meshes[1]]
    var bounds: AABB=(home.model.global_transform.affine_inverse()*combined.global_transform)*combined.mesh.get_aabb()
    var material=combined.get_active_material(0)
    combined.visible=false
    for side in [-1,1]:
        var definition={"id":str(entry.definition.id)+("/door_left" if side==-1 else "/door_right"),"motion":"hinge_y"}
        var hinge=bounds.get_center()+Vector3(0,0,side*bounds.size.z/2)
        var center=bounds.get_center()+Vector3(0,0,side*bounds.size.z/4)
        var size=Vector3(bounds.size.x,bounds.size.y,bounds.size.z/2-.004)
        var pivot=Node3D.new()
        pivot.name="SinkLeafLeft" if side==-1 else "SinkLeafRight"
        home.model.add_child(pivot)
        pivot.position=hinge
        pivot.reparent(entry.node,true)
        var leaf=MeshInstance3D.new()
        var box=BoxMesh.new()
        box.size=size
        leaf.mesh=box
        leaf.material_override=material
        leaf.position=center-hinge
        pivot.add_child(leaf)
        entry.meshes[str(leaf.get_instance_id())]=leaf
        var handle=MeshInstance3D.new()
        var handle_box=BoxMesh.new()
        handle_box.size=Vector3(.028,.10,.018)
        handle.mesh=handle_box
        handle.position=center-hinge+Vector3(size.x/2+.014,0,-side*(size.z/2-.035))
        handle.material_override=material
        pivot.add_child(handle)
        entry.meshes[str(handle.get_instance_id())]=handle
        var body=AnimatableBody3D.new()
        body.collision_layer=2
        body.collision_mask=0
        body.sync_to_physics=false
        pivot.add_child(body)
        var proxy=CollisionShape3D.new()
        var shape=BoxShape3D.new()
        shape.size=size+Vector3(.056,0,0) # Conservative envelope also includes handle.
        proxy.shape=shape
        proxy.position=leaf.position+Vector3(.014,0,0)
        proxy.disabled=false
        body.add_child(proxy)
        entry.definition.parts.append(definition)
        home.preparation.articulations[definition.id]={"definition":definition,"pivot":pivot,"closed_transform":pivot.transform,"axis":Vector3.UP,"leaf":leaf,"proxy":proxy,"moving_body":body,"fraction":0.0}

func _sink_clear(data: Dictionary, fraction: float) -> bool:
    var exclusions: Array[RID]=[data.body.get_rid()]
    for part in data.parts:
        exclusions.append(part.moving_body.get_rid())
    for part in data.parts:
        var query=PhysicsShapeQueryParameters3D.new()
        query.shape=part.proxy.shape
        var pose: Transform3D=part.closed_transform*Transform3D(Basis(part.axis,deg_to_rad(90)*part.sign*fraction),Vector3.ZERO)
        query.transform=part.pivot.get_parent().global_transform*pose*part.proxy.transform
        query.collision_mask=3
        query.exclude=exclusions
        query.margin=.002
        var hits=get_world_3d().direct_space_state.intersect_shape(query,1)
        if not hits.is_empty():
            last_clearance={"part":part.definition.id,"fraction":fraction,"collider":str(hits[0].collider.name)}
            return false
    return true

func apply_sink(group: String, fraction: float) -> bool:
    var data: Dictionary=groups[group]
    var current: float=data.parts[0].fraction
    if is_equal_approx(current,fraction):
        return true
    for step in range(1,5):
        if not _sink_clear(data,lerpf(current,fraction,step/4.0)):
            return false
    apply_fraction(group,fraction)
    return true
