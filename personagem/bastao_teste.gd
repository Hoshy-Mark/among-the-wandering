extends Node3D

const GRIP = Transform3D(Basis(Vector3.FORWARD, Vector3.LEFT, Vector3.UP), Vector3(.073, .068, -.15))


func _ready() -> void:
    for entry in [[.0205, .18, -.035, Color(.24, .15, .08)], [.025, .31, .20, Color(.45, .29, .13)], [.029, .055, .383, Color(.38, .23, .10)]]:
        var instance = MeshInstance3D.new()
        var mesh = CylinderMesh.new()
        mesh.top_radius = entry[0]
        mesh.bottom_radius = entry[0]
        mesh.height = entry[1]
        mesh.radial_segments = 8
        mesh.rings = 1
        instance.mesh = mesh
        instance.position.y = entry[2]
        var material = StandardMaterial3D.new()
        material.albedo_color = entry[3]
        material.roughness = 1
        instance.material_override = material
        add_child(instance)
    visible = false


func attach(actor: Node3D) -> void:
    var rig: Skeleton3D = actor.skeleton
    global_transform = rig.global_transform * rig.get_bone_global_pose(rig.find_bone("Hand.R")) * GRIP
