extends "res://personagem/travessia_mapa77.gd"
func setup(zombie: CharacterBody3D) -> void:
    body=zombie;actor=body.avatar
    definitions=actor.obstacle_path.definitions.duplicate(true)
    for key in ["vault_window","vault_fence"]:definitions.actions[key].effect_time=definitions.actions[key].duration
    load("res://personagem/maos_apoio.gd").register(actor.hand_layer)
    for entry in [["ZMap83","res://personagem/assets/motion/r77/map_traversals.res"],["ZFences83","res://personagem/assets/motion/r78/fences.res"]]:
        var library: AnimationLibrary=load(entry[1]).duplicate(true)
        for clip in library.get_animation_list():
            var animation=library.get_animation(clip)
            for track in animation.get_track_count():
                var bone=str(animation.track_get_path(track).get_subname(0))
                animation.track_set_path(track,NodePath(str(actor.get_path_to(actor.skeleton))+":"+bone))
        var added=actor.player.add_animation_library(entry[0],library)
        if added!=OK:push_error("Could not install NPC traversal clips")
    playback_rate=1.8
func begin(original: Node3D,_action: String="") -> bool:
    message=""
    if processing or is_active() or body.paused or body.state not in ["chase","search","idle"] or not is_instance_valid(original):return false
    var proxy=load("res://personagem/obstaculo_zumbi83.gd").new()
    body.add_child(proxy);proxy.bind(original,body)
    if not proxy.prepare(body):message=proxy.reason;proxy.queue_free();return false
    id="vault_window" if proxy.kind=="window" else "vault_fence"
    if original.has_meta("fence78"):
        path=load("res://personagem/percurso_cercas78.gd").new();path.setup(definitions);path.high=false
    else:path=load("res://personagem/percurso_mapa77.gd").new();path.setup(definitions)
    path.configure(id,proxy.rise,proxy.landing)
    anchor=proxy.global_position+Vector3.UP*.003
    var side=1 if proxy.to_local(body.global_position).z<0 else -1
    basis=Basis(Vector3.UP,proxy.global_rotation.y+(PI if side<0 else 0))
    var entry=_position(0)
    if body.global_position.distance_to(entry)>1.4 or not _preflight():proxy.queue_free();return false
    if body.test_move(body.global_transform,entry-body.global_position):message="Aproximação bloqueada";proxy.queue_free();return false
    token=proxy.reserve(body)
    if token<0:proxy.queue_free();message="Passagem em uso";return false
    target=proxy
    old_clip=actor.clips[id]
    actor.clips[id]=("ZFences83/" if original.has_meta("fence78") else "ZMap83/")+proxy.variant
    map_action=true
    body.velocity=Vector3.ZERO;actor.hand_layer.set_pose("Relaxed");actor.set_motion("idle");actor.motion_rate=0
    align_start=body.global_position;cursor=0;elapsed=0;effect_done=false;effect_succeeded=false
    state="align"
    return true
func _present(delta: float) -> void:
    actor.advance(delta)
    if state in ["playing","retreat"]:
        var support=actor.hand_layer.decode(actor.hand_layer.poses.Obstacle_Support)
        var relaxed=actor.hand_layer.decode(actor.hand_layer.poses.Relaxed)
        var sample: Dictionary=path.sample(id,cursor)
        for name in support:
            var amount: float=sample.hand_R if str(name).ends_with(".R") else sample.hand_L
            support[name]=relaxed[name].interpolate_with(support[name],amount)
        actor.hand_layer.current=support;actor.hand_layer.apply()
func _finish(success: bool) -> void:
    var completed=id
    var previous=target
    if is_instance_valid(previous):previous.release(body,token)
    state="idle";target=null
    actor.motion_rate=1;actor.set_motion("idle");actor.hand_layer.set_pose("Relaxed")
    _height(1.84)
    if map_action:actor.clips[completed]=old_clip
    map_action=false
    if is_instance_valid(previous):previous.queue_free()
    finished.emit(completed,success)
func cancel() -> bool:
    if processing or not is_active():return false
    if state=="align":_finish(false);return true
    if cursor<=definitions.actions[id].takeoff:state="retreat";return true
    return false
func reset_test() -> void:
    if is_active():_finish(false)
    actor.motion_clock=0;actor.motion_blend=1;actor.advance(0)
func _step(delta: float) -> void:
    if not is_instance_valid(target) or not is_instance_valid(target.source):
        if state=="align":_finish(false);return
        state="retreat"
    super._step(delta)
