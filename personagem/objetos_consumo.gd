extends Node3D

var objects: Dictionary = {}
var dressing: Node3D
var active_kind = ""
var forearm_center = Vector3.ZERO


func _material(color: Color) -> StandardMaterial3D:
    var material = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1
    return material


func _box(parent: Node3D, size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
    var instance = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = center
    instance.material_override = _material(color)
    parent.add_child(instance)
    return instance


func _cylinder(parent: Node3D, radius: float, height: float, center: Vector3, color: Color, top_radius: float = -1) -> MeshInstance3D:
    var instance = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.radial_segments = 8
    mesh.rings = 1
    mesh.top_radius = radius if top_radius < 0 else top_radius
    mesh.bottom_radius = radius
    mesh.height = height
    instance.mesh = mesh
    instance.position = center
    instance.material_override = _material(color)
    parent.add_child(instance)
    return instance


func _ready() -> void:
    for kind in ["eat", "drink", "medicine", "bandage"]:
        var holder = Node3D.new()
        holder.name = kind
        holder.visible = false
        add_child(holder)
        objects[kind] = holder
    _box(objects.eat, Vector3(.075, .045, .05), Vector3.ZERO, Color(.76, .54, .27))
    _box(objects.eat, Vector3(.069, .037, .051), Vector3.ZERO, Color(.89, .75, .46))
    _cylinder(objects.drink, .021, .16, Vector3(0, -.015, 0), Color(.21, .43, .39))
    _cylinder(objects.drink, .021, .02, Vector3(0, .075, 0), Color(.21, .43, .39), .011)
    _cylinder(objects.drink, .011, .04, Vector3(0, .105, 0), Color(.21, .43, .39))
    _cylinder(objects.drink, .009, .001, Vector3(0, .1256, 0), Color(.06, .12, .11))
    _cylinder(objects.drink, .0215, .04, Vector3(0, -.008, 0), Color(.76, .78, .66))
    _box(objects.drink, Vector3(.025, .014, .002), Vector3(0, -.008, .021), Color(.24, .38, .49))
    _cylinder(objects.medicine, .006, .014, Vector3.ZERO, Color(.90, .89, .77))
    _box(objects.bandage, Vector3(.033, .033, .014), Vector3.ZERO, Color(.86, .84, .72))
    _box(objects.bandage, Vector3(.025, .004, .015), Vector3.ZERO, Color(.66, .65, .55))
    dressing = Node3D.new()
    dressing.name = "CurativoAntebracoEsquerdo"
    add_child(dressing)
    _cylinder(dressing, .039, .068, Vector3.ZERO, Color(.84, .82, .70))
    _cylinder(dressing, .0395, .009, Vector3(0, .018, 0), Color(.72, .71, .61))
    dressing.visible = false


func show_kind(kind: String) -> void:
    active_kind = kind
    for key in objects:
        objects[key].visible = key == kind
        for child in objects[key].get_children():
            child.scale = Vector3.ONE


func apply_effect(kind: String) -> void:
    if kind == "eat":
        for child in objects.eat.get_children():
            child.scale.x = .70
    elif kind == "medicine":
        objects.medicine.visible = false
    elif kind == "bandage":
        dressing.visible = true


func hide_held() -> void:
    active_kind = ""
    for object in objects.values():
        object.visible = false


func update_attachments(actor: Node3D, grip: Transform3D) -> void:
    var rig: Skeleton3D = actor.skeleton
    var right_hand = rig.get_bone_global_pose(rig.find_bone("Hand.R"))
    for object in objects.values():
        object.global_transform = rig.global_transform * right_hand * grip
    var forearm = rig.get_bone_global_pose(rig.find_bone("Forearm.L"))
    var local_band = Transform3D(Basis.from_scale(Vector3(1.4, 1, .97)), forearm_center)
    dressing.global_transform = rig.global_transform * forearm * local_band
