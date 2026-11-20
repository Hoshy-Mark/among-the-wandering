extends "res://personagem/partida95.gd"
var pending_clock98=0.0
var residential98=load("res://personagem/portas_res98.gd").new()
var residential_parts98=[]
func setup(root_scene: Node3D) -> void:
    residential98.setup(root_scene);super.setup(root_scene)
func _parts(doors: Dictionary,furniture: Dictionary) -> Array:
    residential_parts98=residential98.parts(self)
    # These are authored binary endpoints, also used by the map's E interaction.
    # Validate saved people against their proposed leaves; do not reinterpret
    # authored leaf/frame contact as a dynamically movable furniture obstacle.
    return super._parts(doors,furniture)
func _excluded(parts: Array) -> Array[RID]:
    var result=super._excluded(parts)
    for part in residential_parts98:
        if part.rid.is_valid() and part.rid not in result:result.append(part.rid)
    return result
func _space(point: Vector3,crouched: bool,parts: Array) -> bool:
    var nearby=[]
    for part in parts:
        if point.distance_to(part.pose.origin)<part.shape.size.length()+3:nearby.append(part)
    if not super._space(point,crouched,nearby):return false
    for part in residential_parts98:
        if point.distance_to(part.pose.origin)>part.shape.size.length()+3:continue
        if geometry.capsule_box(point,1.56 if crouched else 1.84,part):return false
    return true
func _signature() -> String:
    var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://fontes.json"))
    return super._signature()+FileAccess.get_sha256("res://population97/populacao97.json")+str(manifest.world98_digest)
func snapshot() -> Dictionary:
    var data=super.snapshot()
    data.population98={"version":1,"catalog":FileAccess.get_sha256("res://population97/populacao97.json"),"clock":enemies.model.clock,"residential_doors":1}
    data.residential98=residential98.snapshot()
    return data
func prepare(value: Variant,spatial: bool=true) -> Dictionary:
    pending_clock98=0
    if not value is Dictionary:reason="invalid";return {}
    var data=value.duplicate(true);var field=data.get("population98")
    if not residential98.prepare(data.get("residential98"),field is Dictionary and field.get("residential_doors")==1):reason="invalid";return {}
    if field!=null:
        if not field is Dictionary or field.get("version")!=1 or field.get("catalog")!=FileAccess.get_sha256("res://population97/populacao97.json") or not enemies.model._number(field.get("clock"),0,1e12) or not data.has("enemies82"):reason="invalid";return {}
        pending_clock98=float(field.clock)
    else:
        if data.has("enemies82"):
            var expanded=enemies.expand_legacy(data.enemies82)
            if expanded.is_empty():reason="invalid";return {}
            data.enemies82=expanded
        else:data.enemies82=enemies.initial.duplicate(true)
        if data.get("session81") is Dictionary and data.session81.get("world")==super._signature():data.session81.world=_signature()
    return super.prepare(data,spatial)
func load_game() -> bool:
    if not super.load_game():return false
    enemies.model.clock=pending_clock98;residential98.apply();return true
