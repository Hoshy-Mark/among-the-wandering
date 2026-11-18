extends Node3D

var player: CharacterBody3D
var visuals: Dictionary={}
var signature=""

func setup(body: CharacterBody3D) -> void:
    player=body
    player.bag_inventory.changed.connect(refresh)
    refresh()

func refresh() -> void:
    var model: RefCounted=player.bag_inventory
    var visible_items: Dictionary={}
    for uid in model.items:
        if model.world_containers.has(model.items[uid].location):
            visible_items[uid]=model.items[uid]
    var state=JSON.stringify([model.world_containers,visible_items],"",true)
    if state==signature:
        return
    signature=state
    for child in get_children():
        child.queue_free()
        child.visible=false
    visuals.clear()
    for id in model.world_containers:
        var entry: Dictionary=model.world_containers[id]
        var contents: Array=model.contents(id)
        if entry.kind=="ground" and contents.is_empty():
            continue
        var node=Node3D.new()
        add_child(node)
        node.global_position=model.point(id)
        visuals[id]=node
        if entry.kind=="crate":
            _box(node,Vector3(.65,.42,.5),Vector3(0,.21,0),Color("736043"))
            _box(node,Vector3(.69,.05,.54),Vector3(0,.445,0),Color("9b8157"))
            for side in [-1,1]:
                _box(node,Vector3(.04,.45,.56),Vector3(.24*side,.22,0),Color("3a4540"))
        elif entry.kind=="cabinet":
            _box(node,Vector3(.70,1.10,.43),Vector3(0,.55,0),Color("506258"))
            for side in [-1,1]:
                _box(node,Vector3(.32,1,.035),Vector3(.17*side,.55,-.24),Color("708178"))
                _box(node,Vector3(.025,.16,.035),Vector3(.045*side,.60,-.27),Color("c1b28b"))
        else:
            var index=0
            for uid in contents:
                var definition: Dictionary=model.catalog[model.items[uid].definition]
                var bag=definition.has("capacity")
                var color=Color(definition.get("color","bca673"))
                _box(node,Vector3(.27,.32,.14) if bag else Vector3(.14,.08,.12),Vector3(.4+(index%3)*.18,.16 if bag else .05,floori(index/3.0)*.15),color)
                index+=1
        var label=Label3D.new()
        label.text=entry.name+"\n%d itens"%contents.size()
        label.position.y=1.32 if entry.kind=="cabinet" else .68
        if entry.kind=="ground":
            label.position.x=.4
        label.font_size=24
        label.pixel_size=.0035
        label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test=false
        node.add_child(label)

func _box(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> void:
    var visual=MeshInstance3D.new()
    var mesh=BoxMesh.new()
    mesh.size=size
    visual.mesh=mesh
    visual.position=offset
    var material=StandardMaterial3D.new()
    material.albedo_color=color
    material.roughness=1
    visual.material_override=material
    parent.add_child(visual)
    if size.y>.4:
        var solid=StaticBody3D.new()
        solid.collision_layer=2
        solid.collision_mask=0
        visual.add_child(solid)
        var shape=CollisionShape3D.new()
        var box=BoxShape3D.new()
        box.size=size
        shape.shape=box
        solid.add_child(shape)
