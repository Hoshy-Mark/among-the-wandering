extends "res://personagem/obstaculo_mapa77.gd"
var source: Node3D
var crossing_body: CharacterBody3D
func bind(original: Node3D,actor: CharacterBody3D) -> void:
    source=original;crossing_body=actor;scene=actor.scene
    kind=source.kind;opening=source.opening;opening_id=source.opening_id
    a=source.a;b=source.b;base_center=source.base_center;normal=source.normal;ledge_y=source.ledge_y
func available() -> bool:
    return is_instance_valid(source) and (source.owner_ref==null or not is_instance_valid(source.owner_ref.get_ref()))
func floor_at(point: Vector3) -> Dictionary:
    var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.55,point-Vector3.UP*.8,1,[crossing_body.get_rid(),scene.player.get_rid()])
    var hit=get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty() or hit.normal.y<.9:return {}
    return hit
func prepare(actor: Node3D) -> bool:
    if not available():reason="Passagem em uso";return false
    if source.has_meta("fence78"):
        if not source.can_cross("zombie") or source.model.high:reason="Zumbis não escalam muros altos";return false
        locate(actor)
        var direction=1 if to_local(actor.global_position).z<0 else -1
        var start=floor_at(base_center-normal*direction*.65)
        var finish=floor_at(base_center+normal*direction*.95)
        if start.is_empty() or finish.is_empty():reason="Falta piso seguro";return false
        landing=finish.position.y-start.position.y
        if absf(landing)>.015 or absf(ledge_y-start.position.y-float(source.model.height))>.02:reason="Altura ou piso incompatível";return false
        global_position.y=start.position.y;rise=float(source.model.height)-.8;variant=source.model.id
        return true
    return super.prepare(actor)
func reserve(actor: Node3D) -> int:
    if not available():return -1
    source.global_transform=global_transform;source.base_center=base_center
    return source.reserve(actor)
func owned_by(actor: Node3D,expected: int) -> bool:
    return is_instance_valid(source) and source.owned_by(actor,expected)
func release(actor: Node3D,expected: int) -> void:
    if is_instance_valid(source):source.release(actor,expected)
func commit(_id: String,actor: Node3D,expected: int) -> bool:
    if not owned_by(actor,expected) or source.committed_token==expected:return false
    source.committed_token=expected;source.effects+=1
    return true
