extends Node3D

var kind = "fence"
var spec: Dictionary
var leaf: Node3D
var fraction = 0.0
var opened = false
var owner_ref: WeakRef
var token = 0
var committed_token = -1
var effects = {"open_window": 0, "vault_fence": 0, "vault_window": 0}


func _box(parent: Node3D, size: Vector3, centre: Vector3, colour: Color, physical: bool = true) -> void:
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position = centre
    var material = StandardMaterial3D.new()
    material.albedo_color = colour
    material.roughness = .9
    if colour.a < 1:
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.material_override = material
    parent.add_child(mesh)
    if physical:
        var body = StaticBody3D.new()
        var collision = CollisionShape3D.new()
        var shape = BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.position = centre
        body.add_child(collision)
        parent.add_child(body)


func _ready() -> void:
    add_to_group("obstacles_r57")
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://personagem/obstaculos.json"))
    spec = data.fixtures[kind]
    var wood = Color(.30, .39, .27)
    if kind == "fence":
        _box(self, Vector3(spec.width, spec.height, spec.thickness), Vector3(0, spec.height * .5, 0), wood)
        for x in [-1.2, 1.2]:
            _box(self, Vector3(.11, .90, .13), Vector3(x, .45, 0), Color(.23, .29, .20))
        for x in range(-6, 7):
            _box(self, Vector3(.12, .72, .025), Vector3(x * .18, .42, -.063), Color(.37, .45, .31), false)
        return
    var wall = Color(.62, .60, .51)
    _box(self, Vector3(2.40, spec.sill, spec.thickness), Vector3(0, spec.sill * .5, 0), wall)
    for x in [-.925, .925]:
        _box(self, Vector3(.65, 3.0, spec.thickness), Vector3(x, 1.4, 0), wall)
    _box(self, Vector3(1.2, 3.0 - spec.top, spec.thickness), Vector3(0, (3.0 + spec.top) * .5, 0), wall)
    var aperture: float = spec.top - spec.sill
    for x in [-.60, .60]:
        _box(self, Vector3(.10, aperture + .10, .20), Vector3(x, (spec.top + spec.sill) * .5, 0), wood)
    leaf = Node3D.new()
    leaf.position = Vector3(0, spec.sill, 0)
    add_child(leaf)
    _box(leaf, Vector3(1.10, aperture, .045), Vector3(0, aperture * .5, 0), Color(.34, .53, .58, .28))
    for x in [-.515, .515]:
        _box(leaf, Vector3(.07, aperture, .07), Vector3(x, aperture * .5, 0), wood, false)
    for y in [.035, aperture - .035]:
        _box(leaf, Vector3(1.10, .07, .07), Vector3(0, y, 0), wood, false)
    _box(leaf, Vector3(1.0, .05, .10), Vector3(0, .05, -.04), Color(.16, .18, .17), false)


func reserve(actor: Node3D) -> int:
    if owner_ref != null and is_instance_valid(owner_ref.get_ref()):
        return -1
    if not opened and fraction > 0:
        return -1
    token += 1
    owner_ref = weakref(actor)
    return token


func owned_by(actor: Node3D, expected: int) -> bool:
    return expected == token and owner_ref != null and owner_ref.get_ref() == actor


func release(actor: Node3D, expected: int) -> void:
    if owned_by(actor, expected):
        owner_ref = null


func set_fraction(value: float, actor: Node3D, expected: int) -> bool:
    if kind != "window" or not owned_by(actor, expected):
        return false
    fraction = clampf(value, 0, 1)
    leaf.position.y = spec.sill + fraction * spec.travel
    return true


func swing_clear(actor: CharacterBody3D, first: float = 0, last: float = 1) -> bool:
    var exclusions: Array[RID] = [actor.get_rid()]
    for item in find_children("*", "StaticBody3D", true, false):
        exclusions.append(item.get_rid())
    var shape = BoxShape3D.new()
    shape.size = Vector3(1.10, spec.top - spec.sill, .045)
    var query = PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.exclude = exclusions
    query.collision_mask = 3
    var steps = maxi(1, ceili(absf(last-first) * spec.travel / .025))
    for step in range(steps + 1):
        var height: float = spec.sill + lerpf(first,last,float(step)/steps)*spec.travel
        query.transform = global_transform * Transform3D(Basis.IDENTITY,Vector3(0,height+(spec.top-spec.sill)*.5,0))
        if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
            return false
    return true


func commit(id: String, actor: Node3D, expected: int) -> bool:
    if not owned_by(actor, expected) or committed_token == expected:
        return false
    if id == "open_window":
        if opened or fraction < .999:
            return false
        opened = true
    effects[id] += 1
    committed_token = expected
    return true


func _physics_process(delta: float) -> void:
    if not opened and fraction > 0 and (owner_ref == null or not is_instance_valid(owner_ref.get_ref())):
        fraction = move_toward(fraction, 0, delta * 4)
        leaf.position.y = spec.sill + fraction * spec.travel


func reset_test() -> bool:
    if owner_ref != null and is_instance_valid(owner_ref.get_ref()):
        return false
    opened = false
    fraction = 0
    if leaf != null:
        leaf.position.y = spec.sill
    for id in effects:
        effects[id] = 0
    return true
