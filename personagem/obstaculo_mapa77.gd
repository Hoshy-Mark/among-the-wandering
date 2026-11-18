extends Node3D
var kind="window"
var opened=true
var spec: Dictionary={}
var scene: Node3D
var opening: Dictionary={}
var opening_id=""
var a=Vector3.ZERO
var b=Vector3.ZERO
var base_center=Vector3.ZERO
var normal=Vector3.FORWARD
var ledge_y=1.21
var rise=0.0
var landing=0.0
var variant=""
var token=0
var owner_ref: WeakRef
var committed_token=-1
var effects=0
var reason=""

func floor_at(point: Vector3) -> Dictionary:
    var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.55,point-Vector3.UP*.8,3,[scene.player.get_rid()])
    var hit=get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty() or hit.normal.y<.9:return {}
    return hit

func locate(actor: Node3D) -> void:
    if owner_ref!=null and is_instance_valid(owner_ref.get_ref()):return
    if kind=="fence":
        var d=b-a
        var fraction=clampf((actor.global_position-a).dot(d)/d.length_squared(),.7/d.length(),1-.7/d.length())
        base_center=a+d*fraction
        normal=d.normalized().cross(Vector3.UP)
    global_position=base_center
    global_rotation=Vector3(0,atan2(normal.x,normal.z),0)

func prepare(actor: Node3D) -> bool:
    reason=""
    locate(actor)
    if kind=="window":
        opened=opening.open and not scene.player.map_doors.busy()
        if not opened:reason="Abra a janela e aguarde a folha parar";return false
        if opening.get("mechanism","") not in ["awning","casement_pair"]:
            reason="O vão livre desta janela é insuficiente para esta travessia"
            return false
    var direction=1 if to_local(actor.global_position).z<0 else -1
    var start=floor_at(base_center-normal*direction*.65)
    var finish=floor_at(base_center+normal*direction*.95)
    if start.is_empty() or finish.is_empty():reason="Falta piso seguro na entrada ou chegada";return false
    landing=finish.position.y-start.position.y
    if absf(landing)>.27:reason="Desnível fora da faixa validada";return false
    if kind=="window":
        variant="window_in" if landing<0 else "window_out"
        var expected=-.255 if variant=="window_in" else .255
        if absf(landing-expected)>.015:reason="Altura de piso ainda não validada para esta janela";return false
        rise=.125 if variant=="window_in" else .38
    else:
        variant="fence"
        rise=.41
        if absf(landing)>.015:reason="Cerca com desnível ainda não validado";return false
    if absf(ledge_y-start.position.y-(.8+rise))>.02:
        reason="Altura de apoio fora da faixa validada"
        return false
    global_position.y=start.position.y
    return true

func reserve(actor: Node3D) -> int:
    if owner_ref!=null and is_instance_valid(owner_ref.get_ref()):return -1
    token+=1
    owner_ref=weakref(actor)
    return token
func owned_by(actor: Node3D, expected: int) -> bool:
    return token==expected and owner_ref!=null and owner_ref.get_ref()==actor
func release(actor: Node3D, expected: int) -> void:
    if owned_by(actor,expected):owner_ref=null
func commit(_id: String, actor: Node3D, expected: int) -> bool:
    if not owned_by(actor,expected) or committed_token==expected:return false
    committed_token=expected
    effects+=1
    return true
