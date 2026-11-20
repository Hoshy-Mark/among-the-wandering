extends "res://personagem/travessia_cercas78.gd"
const Window113=preload("res://personagem/obstaculo_mapa113.gd")
var routed113: Node3D
var original_centre113=Vector3.ZERO
func _step(delta: float) -> void:
    if state!="align":super._step(delta);return
    elapsed+=delta
    var entry=_position(0)
    var destination=align_start.lerp(entry,smoothstep(0,.25,elapsed))
    var motion=destination-body.global_position
    # A shallow frame contact can recover farther than the first tiny substep.
    # Do not pull the player back into that contact on the next substep.
    if motion.dot(entry-body.global_position)<0:motion=Vector3.ZERO
    var collision=body.move_and_collide(motion)
    actor.rotation.y=lerp_angle(actor.rotation.y,basis.get_euler().y,minf(1,delta*16))
    _present(delta)
    if collision!=null:
        var remaining=entry-body.global_position
        var separating=collision.get_normal().dot(remaining)>.00001 and not body.test_move(body.global_transform,remaining)
        var floor_contact=collision.get_normal().y>.8 and body.global_position.distance_to(destination)<.015
        if not separating and not floor_contact:
            message="Aproximação bloqueada";_finish(false);return
    if elapsed>=.25 and body.global_position.distance_to(entry)<.015:
        actor.rotation.y=basis.get_euler().y;actor.set_motion(id);actor.motion_clock=0
        actor.hand_layer.set_pose("Cylinder" if id=="open_window" else "Obstacle_Support")
        elapsed=0;state="prepare"
    elif elapsed>.75:
        message="Aproximação bloqueada";_finish(false)
func setup(player: CharacterBody3D) -> void:
    super.setup(player)
    path=load("res://personagem/percurso_mapa113.gd").new();path.setup(definitions)
    base_path=path
    var source: AnimationLibrary=load("res://personagem/assets/motion/r113/window_mirrors.res").duplicate(true)
    var library=actor.player.get_animation_library("Map77")
    for name in source.get_animation_list():
        var clip=source.get_animation(name)
        for track in clip.get_track_count():
            clip.track_set_path(track,NodePath(str(actor.get_path_to(actor.skeleton))+":"+str(clip.track_get_path(track).get_subname(0))))
        library.add_animation(name,clip)
func begin(obstacle: Node3D,action_id: String) -> bool:
    if super.begin(obstacle,action_id):return true
    if not is_instance_valid(obstacle) or not obstacle is Window113 or action_id!="vault_window":return false
    if not (message.begins_with("Entrada, passagem") or message=="Aproximação bloqueada"):return false
    var centre: Vector3=obstacle.base_center
    var across: Vector3=obstacle.normal.cross(Vector3.UP)
    for mirrored in [false,true]:
        for offset in [0.0,-.05,.05,-.10,.10,-.15,.15,-.20,.20,-.25,.25,-.30,.30,-.35,.35]:
            if not mirrored and is_zero_approx(offset):continue
            obstacle.base_center=centre+across*offset
            obstacle.mirrored113=mirrored;path.mirrored113=mirrored
            if super.begin(obstacle,action_id):
                routed113=obstacle;original_centre113=centre
                return true
    obstacle.base_center=centre;obstacle.mirrored113=false;path.mirrored113=false;obstacle.locate(body)
    return false
func _restore_route113() -> void:
    if is_instance_valid(routed113):
        routed113.base_center=original_centre113;routed113.mirrored113=false;routed113.locate(body)
    routed113=null
func _finish(success: bool) -> void:
    super._finish(success);_restore_route113()
func reset_test() -> void:
    super.reset_test();_restore_route113()
