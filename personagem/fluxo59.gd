extends RefCounted

const PLANS = {
    "walk":["walk_start_l","walk_loop","walk_loop","walk_stop_l"],
    "run":["jog_start_l","jog_loop","jog_loop","jog_stop_l"],
    "changes":["walk_start_l","changes_walk_to_jog_l","changes_jog_to_sprint_l","sprint_loop","changes_sprint_to_jog_l","changes_jog_to_walk_l","walk_stop_l"],
    "turn_left":["walk_start_l","walk_stop_l","turn_left_180","walk_start_l","walk_stop_l"],
    "turn_right":["walk_start_l","walk_stop_l","turn_right_180","walk_start_l","walk_stop_l"],
    "crouch":["crouch_start_l","crouch_loop","crouch_stop_l","crouch_turn_left_180","crouch_start_l","crouch_stop_l"],
    "sprint":["sprint_start_l","sprint_loop","sprint_loop","sprint_stop_l"]
}
var body: CharacterBody3D
var definitions: Dictionary
var queue: Array=[]
var clock=0.0
var origin=Vector3.ZERO
var yaw=0.0
var blocked=false

func setup(player: CharacterBody3D) -> void:
    body=player
    definitions=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/fluxo59.json"))

func begin(id: String) -> bool:
    if not queue.is_empty() or not PLANS.has(id) or not body._prepare_action():
        return false
    queue=PLANS[id].duplicate()
    body.velocity=Vector3.ZERO
    body.action.control_locked=true
    body.combat.control_locked=true
    blocked=false
    _next()
    return true

func _next() -> void:
    clock=0
    origin=body.global_position
    yaw=body.avatar.rotation.y
    if queue.is_empty():
        body.avatar.motion_rate=1
        body.action.control_locked=false
        body.combat.control_locked=false
        body.avatar.set_motion("crouch_idle" if body.crouched else "idle")
        return
    if not body.set_crouch(str(queue[0]).begins_with("crouch")):
        queue.clear()
        _next()
        return
    body.avatar.set_motion("flow_"+queue[0])
    body.avatar.motion_blend=1

func sample(data: Dictionary, seconds: float) -> Dictionary:
    var rows: Array=data.samples
    var source=clampf(seconds/data.duration,0,1)*data.authored_duration
    var index=0
    while index<rows.size()-2 and source>rows[index+1].time_s:
        index+=1
    var a: Dictionary=rows[index]
    var b: Dictionary=rows[index+1]
    var amount=clampf((source-a.time_s)/maxf(.000001,b.time_s-a.time_s),0,1)
    return {"distance":lerpf(a.get("distance_m",0),b.get("distance_m",0),amount),"yaw":deg_to_rad(lerpf(a.get("yaw_deg",0),b.get("yaw_deg",0),amount))}

func advance(delta: float) -> void:
    if queue.is_empty() or body.paused:
        return
    var remaining=delta
    while remaining>0.000001 and not queue.is_empty():
        var data: Dictionary=definitions[queue[0]]
        var step=minf(remaining,minf(1.0/120,data.duration-clock))
        clock+=step
        remaining-=step
        var pose=sample(data,clock)
        var desired=origin+Basis(Vector3.UP,yaw)*Vector3(0,0,pose.distance)
        var query=PhysicsRayQueryParameters3D.create(desired+Vector3.UP,desired-Vector3.UP,1)
        var floor_hit=body.get_world_3d().direct_space_state.intersect_ray(query)
        if not floor_hit.is_empty() and floor_hit.normal.y>.8:
            desired.y=floor_hit.position.y+.01
        var collision=body.move_and_collide(desired-body.global_position)
        if collision!=null and collision.get_normal().y>.8:
            # At a descending threshold the rear of the capsule can still rest
            # on the upper floor. Keep the horizontal remainder instead of
            # cancelling the gait because the entire descent has not finished.
            var slide=collision.get_remainder().slide(collision.get_normal())
            collision=body.move_and_collide(slide) if slide.length_squared()>.00000001 else null
        if collision!=null and not (collision.get_normal().y>.8 and body.global_position.distance_to(desired)<.03):
            blocked=true
            queue.clear()
            _next()
            return
        body.avatar.rotation.y=yaw+pose.yaw
        body.avatar.motion_clock=clock
        body.avatar.motion_rate=0
        body.avatar.advance(0)
        if clock>=data.duration-.000001:
            queue.pop_front()
            _next()
    if queue.is_empty():
        body.avatar.motion_rate=1
