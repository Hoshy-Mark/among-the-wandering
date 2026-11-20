extends "res://personagem/zumbi82.gd"
var crossing: RefCounted
var cross_delay=0.0
var crossing_result={}
var deferred_state=""
var paused: bool:
    get:return scene!=null and scene.player.paused
func setup(root_scene: Node3D,definition: Dictionary) -> void:
    super.setup(root_scene,definition)
    crossing=load("res://personagem/travessia_zumbi83.gd").new();crossing.setup(self)
    crossing.finished.connect(_crossed)
func request_cross(obstacle: Node3D) -> bool:
    if state in ["attack","hit","dying","dead","crossing"] or crossing.is_active():return false
    if not crossing.begin(obstacle):return false
    state="crossing";crossing_result={};deferred_state=""
    return true
func _crossed(action_id: String,success: bool) -> void:
    crossing_result={"action":action_id,"success":success}
    cross_delay=.7;velocity=Vector3.ZERO;elapsed=0;motion=""
    state=deferred_state if not deferred_state.is_empty() else "search"
    deferred_state=""
    if success:memory=4
func try_cross(goal: Vector3) -> bool:
    var candidates=[]
    for obstacle in scene.player.map_traversals.obstacles:
        if obstacle.has_meta("fence78") and not obstacle.can_cross("zombie"):continue
        if obstacle.kind=="window" and not obstacle.opening.open:continue
        var center: Vector3=obstacle.base_center
        var normal: Vector3=obstacle.normal
        if obstacle.kind=="fence":
            var segment: Vector3=obstacle.b-obstacle.a
            var length=segment.length()
            var t=clampf((global_position-obstacle.a).dot(segment)/segment.length_squared(),.7/length,1-.7/length)
            center=obstacle.a+segment*t;normal=segment.normalized().cross(Vector3.UP)
        var own_side=(global_position-center).dot(normal)
        var goal_side=(goal-center).dot(normal)
        var lateral=absf((global_position-center).dot(normal.cross(Vector3.UP)))
        if own_side*goal_side>=-.06 or absf(goal_side)<.45 or absf(own_side)>1.5 or lateral>1.0:continue
        candidates.append({"node":obstacle,"distance":global_position.distance_squared_to(center)})
    candidates.sort_custom(func(a,b):return a.distance<b.distance)
    for candidate in candidates:
        if request_cross(candidate.node):return true
    return false
func step(delta: float) -> void:
    if not is_finite(delta) or delta<=0:return
    if crossing.is_active():crossing.advance(delta);return
    cross_delay=maxf(0,cross_delay-delta)
    if cross_delay<=0 and state in ["chase","search"] and memory>0:
        cross_delay=.4
        if try_cross(last_known):return
    super.step(delta)
func receive_combat_hit(event: Dictionary) -> bool:
    if deferred_state=="dying":return false
    var active=crossing!=null and crossing.is_active()
    if not super.receive_combat_hit(event):return false
    if active:
        deferred_state=state;state="crossing"
        crossing.cancel()
    return true
func restore(data: Dictionary) -> void:
    if crossing!=null and crossing.is_active():crossing.reset_test()
    deferred_state="";cross_delay=0;crossing_result={}
    super.restore(data)
