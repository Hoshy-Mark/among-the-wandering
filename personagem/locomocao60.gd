extends "res://personagem/fluxo59.gd"

var gait="walk"
var desired=""
var lead="l"
var history: Array=[]
var turn_pending=""
var sole_probes: Array=[]

func setup(player: CharacterBody3D) -> void:
    super.setup(player)
    sole_probes=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/solas60.json"))

func ground_pose() -> void:
    var actor: Node3D=body.avatar
    var low=INF
    var skins: Dictionary={}
    for probe in sole_probes:
        var rest=Vector3(probe.p[0],probe.p[1],probe.p[2])
        var point=Vector3.ZERO
        for name in probe.w:
            if not skins.has(name):
                skins[name]=actor.arm_articulation._skin(name)
            point+=skins[name]*rest*probe.w[name]
        low=minf(low,point.y)
    if low<.002:
        var index=actor.skeleton.find_bone("Root")
        var position=actor.skeleton.get_bone_pose_position(index)
        position.y+=.002-low
        actor.skeleton.set_bone_pose_position(index,position)
        actor.skeleton.force_update_all_bone_transforms()
        actor.arm_articulation.apply()

func cancel() -> void:
    if queue.is_empty():
        return
    queue.clear()
    clock=0
    body.avatar.motion_rate=1
    turn_pending=""

func _next() -> void:
    clock=0
    origin=body.global_position
    yaw=body.avatar.rotation.y
    if queue.is_empty():
        body.avatar.motion_rate=1
        return
    var id: String=queue[0]
    body.avatar.set_motion("flow_"+id)
    body.avatar.motion_blend=1
    history.append(id)

func _start(id: String, blend: bool=false) -> void:
    blocked=false
    queue=[id]
    _next()
    if blend:
        body.avatar.motion_blend=0

func update(delta: float, input: Vector2, running: bool, sprinting: bool) -> bool:
    if body.paused:
        return not queue.is_empty()
    if not input.is_finite():
        input=Vector2.ZERO
    desired="" if input.is_zero_approx() else "crouch" if body.crouched else "sprint" if sprinting else "jog" if running else "walk"
    if queue.is_empty():
        if desired.is_empty():
            return false
        gait=desired
        _start(gait+"_start_l",true)
    var id: String=queue[0]
    var direction=Vector3.ZERO
    if not input.is_zero_approx():
        var right: Vector3=body.camera.global_basis.x
        var down: Vector3=body.camera.global_basis.z
        right.y=0
        down.y=0
        direction=(right.normalized()*input.x+down.normalized()*input.y).normalized()
    if not direction.is_zero_approx() and "turn" not in id:
        var target=atan2(direction.x,direction.z)
        var difference=wrapf(target-yaw,-PI,PI)
        if absf(difference)>deg_to_rad(150) and id.ends_with("loop"):
            turn_pending=("crouch_turn_" if gait=="crouch" else "turn_")+("left_180" if difference>0 else "right_180")
        elif turn_pending.is_empty():
            var next_yaw=lerp_angle(yaw,target,minf(1,delta*12))
            var distance: float=sample(definitions[id],clock).distance
            yaw=next_yaw
            origin=body.global_position-Basis(Vector3.UP,yaw)*Vector3(0,0,distance)
    var definition: Dictionary=definitions[id]
    if id.ends_with("loop") and (desired!=gait or not turn_pending.is_empty()):
        var boundary: float=definition.duration*.5 if clock<definition.duration*.5 else definition.duration
        if clock+delta>=boundary:
            advance(maxf(0,boundary-clock-.0000001))
            lead="r" if boundary<definition.duration else "l"
            if not turn_pending.is_empty() or desired.is_empty() or "crouch" in [gait,desired]:
                _start(gait+"_stop_"+lead)
            else:
                var target=desired
                if gait=="walk" and target=="sprint":
                    target="jog"
                elif gait=="sprint" and target=="walk":
                    target="jog"
                _start("changes_"+gait+"_to_"+target+"_"+lead)
                gait=target
            return true
    body.avatar.motion_blend=minf(1,body.avatar.motion_blend+delta/body.avatar.motion_transition_duration)
    advance(delta)
    if blocked:
        cancel()
        body.velocity=Vector3.ZERO
        return true
    if queue.is_empty():
        if "_stop_" in id:
            if not turn_pending.is_empty() and not desired.is_empty():
                _start(turn_pending)
                turn_pending=""
            elif not desired.is_empty():
                gait=desired
                _start(gait+"_start_l",true)
            else:
                turn_pending=""
                body.avatar.set_motion("crouch_idle" if body.crouched else "idle")
        else:
            _start(gait+"_loop")
            if id.ends_with("_r"):
                clock=definitions[gait+"_loop"].duration*.5
                var distance: float=sample(definitions[gait+"_loop"],clock).distance
                origin=body.global_position-Basis(Vector3.UP,yaw)*Vector3(0,0,distance)
                body.avatar.motion_clock=clock
                body.avatar.motion_blend=0
    return true
