extends StaticBody3D

var visuals: Node3D
var impacts: Array = []
var flash = 0.0
var material: StandardMaterial3D


func _ready() -> void:
    collision_layer = 1
    collision_mask = 2
    var collision = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = .20
    capsule.height = 1.50
    collision.shape = capsule
    collision.position.y = .75
    add_child(collision)
    visuals = Node3D.new()
    add_child(visuals)
    material = StandardMaterial3D.new()
    material.albedo_color = Color(.43, .30, .17)
    material.roughness = 1
    for entry in [[Vector3(.32, .53, .24), Vector3(0, 1.03, 0)], [Vector3(.23, .24, .23), Vector3(0, 1.43, 0)], [Vector3(.10, .70, .10), Vector3(0, .41, 0)], [Vector3(.48, .07, .42), Vector3(0, .035, 0)]]:
        var instance = MeshInstance3D.new()
        var mesh = BoxMesh.new()
        mesh.size = entry[0]
        instance.mesh = mesh
        instance.position = entry[1]
        instance.material_override = material
        visuals.add_child(instance)


func reset() -> void:
    impacts.clear()
    flash = 0


func try_hit(attacker: Node3D, kind: String, definition: Dictionary) -> bool:
    if not is_instance_valid(attacker):
        return false
    var offset = global_position - attacker.global_position
    var horizontal = Vector3(offset.x, 0, offset.z)
    if horizontal.length() > float(definition.reach) or absf(offset.y) > .55:
        return false
    var forward = attacker.global_basis.z
    forward.y = 0
    if horizontal.length() > .001 and forward.normalized().dot(horizontal.normalized()) < cos(deg_to_rad(float(definition.cone_degrees))):
        return false
    var start = attacker.global_position + Vector3.UP * 1.20
    var end = global_position + Vector3.UP * 1.15
    var query = PhysicsRayQueryParameters3D.create(start, end, 1)
    var hit = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider != self:
        return false
    impacts.append({"action": kind, "number": impacts.size() + 1})
    flash = .16
    return true


func _process(delta: float) -> void:
    flash = maxf(0, flash - delta)
    material.albedo_color = Color(.85, .61, .25) if flash > 0 else Color(.43, .30, .17)
