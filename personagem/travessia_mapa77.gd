extends "res://personagem/travessia.gd"
var old_clip=""
var map_action=false
func setup(player: CharacterBody3D) -> void:
    super.setup(player)
    definitions=definitions.duplicate(true)
    for action_id in ["vault_window","vault_fence"]:definitions.actions[action_id].effect_time=definitions.actions[action_id].duration
    path=load("res://personagem/percurso_mapa77.gd").new()
    path.setup(definitions)
    var library: AnimationLibrary=load("res://personagem/assets/motion/r77/map_traversals.res").duplicate(true)
    for clip in library.get_animation_list():
        var animation=library.get_animation(clip)
        for track in animation.get_track_count():
            var bone=str(animation.track_get_path(track).get_subname(0))
            animation.track_set_path(track,NodePath(str(actor.get_path_to(actor.skeleton))+":"+bone))
    assert(actor.player.add_animation_library("Map77",library)==OK)
func begin(obstacle: Node3D, action_id: String) -> bool:
    if not is_instance_valid(obstacle):return false
    if obstacle.has_meta("map77") and action_id not in ["vault_window","vault_fence"]:
        message="Use a interação da janela para abrir a folha"
        return false
    if not obstacle.has_meta("map77"):return super.begin(obstacle,action_id)
    if is_active() or body.hud_open or body.action.state!="idle" or body.inventory_actions.busy() or body.map_doors.busy() or body.world_interaction.has_interaction():
        message="Conclua a ação atual antes de atravessar"
        return false
    if not obstacle.prepare(body):message=obstacle.reason;return false
    path.configure(action_id,obstacle.rise,obstacle.landing)
    old_clip=actor.clips[action_id]
    actor.clips[action_id]="Map77/"+obstacle.variant
    map_action=true
    var accepted=super.begin(obstacle,action_id)
    if not accepted:
        actor.clips[action_id]=old_clip
        path.configure("",0,0)
        map_action=false
    return accepted
func _finish(success: bool) -> void:
    var completed=id
    super._finish(success)
    if map_action:
        actor.clips[completed]=old_clip
        path.configure("",0,0)
        map_action=false
func _present(delta: float) -> void:
    if not map_action:
        super._present(delta)
        return
    actor.advance(delta)
    if state in ["playing","retreat"]:
        var support=actor.hand_layer.decode(actor.hand_layer.poses.Obstacle_Support)
        var relaxed=actor.hand_layer.decode(actor.hand_layer.poses.Relaxed)
        var sample: Dictionary=path.sample(id,cursor)
        for name in support:
            var amount: float=sample.hand_R if str(name).ends_with(".R") else sample.hand_L
            support[name]=relaxed[name].interpolate_with(support[name],amount)
        actor.hand_layer.current=support
        actor.hand_layer.apply()
    body.action._present()

func _clear(position: Vector3, sample: Dictionary) -> bool:
    var shape = CapsuleShape3D.new()
    shape.radius = .23
    shape.height = sample.height
    var query = PhysicsShapeQueryParameters3D.new()
    query.shape = shape
    query.transform = _volume(sample)
    query.transform.origin += position
    query.exclude = [body.get_rid()]
    query.collision_mask = 3
    var hits = body.get_world_3d().direct_space_state.intersect_shape(query, 1)
    if not hits.is_empty():
        message = "A passagem está ocupada"
        return false
    if sample.has("R"):
        var foot = SphereShape3D.new()
        foot.radius = .07
        query.shape = foot
        for side in ["R","L"]:
            query.transform = Transform3D(Basis.IDENTITY,anchor+basis*sample[side]+Vector3.UP*.003)
            if not body.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
                message = "O trajeto das pernas está ocupado"
                return false
    return true



func _preflight() -> bool:
    var action: Dictionary=definitions.actions[id]
    if not _floor(_position(0)) or not _floor(_position(action.duration)):
        message="Piso de entrada ou chegada incompatível"
        return false
    for frame in 61:
        var time: float=action.duration*frame/60
        if not _clear(_position(time),path.sample(id,time)):
            return false
    return true

func reset_test() -> void:
    var completed=id
    super.reset_test()
    if map_action:
        actor.clips[completed]=old_clip
        path.configure("",0,0)
        map_action=false

func _begin_original(obstacle: Node3D, action_id: String) -> bool:
    return super.begin(obstacle,action_id)
