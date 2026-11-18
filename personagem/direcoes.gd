extends RefCounted
## Condutor de preview. A integração física com CharacterBody3D permanece externa.
var actor: Node3D
var stage:="free"
var stage_time:=0.0
var turn_sign:=1
var queued_turn:=0
var resume_motion:="idle"
var yaw_start:=0.0
var translate_preview:=false
var finished_turns:=0
var yaw_contract: Dictionary

func setup(npc: Node3D) -> void:
    actor=npc;actor.manual_update=true
    yaw_contract=JSON.parse_string(FileAccess.get_file_as_string(actor.base_dir+"assets/motion/yaw_contract.json"))

func set_motion(id: String) -> bool:
    if id not in ["idle","walk","run","crouch","crouch_idle","backward","left","right"]:return false
    resume_motion=id
    if stage!="free":return true
    actor.motion_rate=1
    return actor.set_motion(id)

func request_turn(sign_value: int) -> bool:
    if sign_value not in [-1,1]:return false
    if stage!="free":queued_turn=sign_value;return true
    turn_sign=sign_value;yaw_start=actor.rotation.y
    actor.set_motion("turn_left" if turn_sign>0 else "turn_right")
    actor.motion_clock=0;actor.motion_rate=0
    stage="prepare";stage_time=0
    return true

func _duration() -> float:
    if stage=="prepare":return actor.motion_transition_duration
    if stage=="turn":return actor.player.get_animation(actor.clips[actor.motion]).length
    return .18

func _yaw_at(seconds: float) -> float:
    var spec: Dictionary=yaw_contract.clips[0 if turn_sign>0 else 1]
    var phase:=clampf(seconds/float(spec.duration_s),0,1)*float(spec.frames)
    var a:=mini(floori(phase),spec.samples.size()-1);var b:=mini(a+1,spec.samples.size()-1)
    return deg_to_rad(lerpf(float(spec.samples[a].yaw_deg),float(spec.samples[b].yaw_deg),phase-floor(phase)))

func advance(delta: float) -> void:
    if not is_finite(delta) or delta<0:return
    if actor.motion_paused:actor.advance(delta);return
    var remaining:=delta
    var iterations:=0
    while remaining>0 or iterations==0:
        iterations+=1;assert(iterations<128)
        if stage=="free":
            actor.advance(remaining)
            if translate_preview:
                var direction:=Vector3.ZERO;var speed:=0.0
                if actor.motion=="backward":direction=Vector3(0,0,-1);speed=.5
                elif actor.motion=="left":direction=Vector3(1,0,0);speed=.2/.72
                elif actor.motion=="right":direction=Vector3(-1,0,0);speed=.2/.72
                actor.position+=actor.basis*direction*speed*remaining
            return
        var step:=minf(remaining,maxf(0,_duration()-stage_time))
        actor.advance(step);stage_time+=step;remaining-=step
        if stage=="turn":actor.rotation.y=yaw_start+_yaw_at(stage_time)
        if stage_time>=_duration()-.0000001:
            if stage=="prepare":
                stage="turn";stage_time=0;actor.motion_clock=0;actor.motion_blend=1;actor.motion_rate=1;actor.advance(0)
            elif stage=="turn":
                actor.rotation.y=yaw_start+turn_sign*PI/2
                actor.set_motion("turn_ready");actor.motion_blend=1;actor.motion_clock=0;actor.advance(0)
                stage="settle";stage_time=0;finished_turns+=1
            else:
                stage="free";stage_time=0
                if queued_turn!=0:
                    var next:=queued_turn;queued_turn=0;request_turn(next)
                else:set_motion(resume_motion)
        else:return
        if remaining<=0:return

func reset() -> void:
    stage="free";stage_time=0;queued_turn=0;finished_turns=0;resume_motion="idle"
    actor.rotation.y=0;actor.position=Vector3.ZERO;actor.motion_rate=1;actor.motion_paused=false
    actor.set_motion("idle");actor.motion_blend=1;actor.motion_clock=0;actor.advance(0)
