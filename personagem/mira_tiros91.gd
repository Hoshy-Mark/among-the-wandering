extends "res://personagem/mira_ambiente89.gd"
var accuracy: Dictionary
var steady=0.0
var turn=0.0
var bloom=0.0
var pending_motion=0.0
var rng=RandomNumberGenerator.new()
func setup(root_scene: Node3D) -> void:
    super.setup(root_scene)
    accuracy=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/tiros91.json")).accuracy
    rng.randomize()
    reticle.queue_free();reticle=load("res://personagem/reticulo91.gd").new();scene.game_ui.add_child(reticle)
    scene.game_ui.move_child(reticle,scene.game_ui.get_children().find(veil))
func move_aim(relative: Vector2) -> void:
    if not relative.is_finite():return
    if holding:pending_motion+=relative.length()
    super.move_aim(relative)
func cone_degrees() -> float:
    var p=scene.player
    return clampf(float(accuracy.minimum_degrees)+(1-steady)*float(accuracy.unsettled_degrees)+turn*float(accuracy.turn_degrees)+bloom+(1-p.condition_state.stamina/100)*float(accuracy.stamina_degrees)+p.condition_state.pain()/100*float(accuracy.pain_degrees),float(accuracy.minimum_degrees),float(accuracy.maximum_degrees))
func direction_with_spread(degrees: float) -> Vector3:
    var camera=scene.camera;var radius=sqrt(rng.randf())*tan(deg_to_rad(degrees));var phase=rng.randf()*TAU
    return (-camera.global_basis.z+camera.global_basis.x*(radius*cos(phase))+camera.global_basis.y*(radius*sin(phase))).normalized()
func note_shot() -> void:bloom=minf(float(accuracy.recoil_max),bloom+float(accuracy.recoil_step))
func confirm_hit(zone: String) -> void:
    reticle.hit_left=.24;reticle.head_hit=zone=="head";reticle.queue_redraw()
func advance(delta: float) -> void:
    if scene==null:return
    if delta>0 and is_finite(delta):
        var speed=pending_motion/maxf(.001,delta);pending_motion=0
        turn=lerpf(turn,clampf(speed/500,0,1),1-exp(-delta*12))
        if holding and speed<20:steady=move_toward(steady,1,delta/float(accuracy.settle_seconds))
        elif holding:steady=move_toward(steady,0,delta*minf(4,speed/200))
        else:steady=0
        bloom=move_toward(bloom,0,delta*float(accuracy.recoil_recovery))
        reticle.hit_left=maxf(0,reticle.hit_left-delta)
    super.advance(delta)
    if owns_camera():
        var point=aim_ray();var receiver=point.get("collider");var range_to=float(scene.player.weapons.spec(scene.player.bag_inventory.equipped("main_hand")).get("reach",8))
        reticle.hostile=is_instance_valid(receiver) and not str(point.get("zone","")).is_empty() and scene.player.weapons.visual.muzzle_position().distance_to(point.position)<=range_to
        var height=scene.get_viewport().get_visible_rect().size.y
        reticle.cone_pixels=tan(deg_to_rad(cone_degrees()))*height/(2*tan(deg_to_rad(scene.camera.fov*.5)));reticle.queue_redraw()
func aim_ray() -> Dictionary:
    if scene.player.map_combat==null or not scene.player.map_combat.has_method("shot_trace"):return super.aim_ray()
    var camera=scene.camera;var center=scene.get_viewport().get_visible_rect().size*.5
    var origin=camera.project_ray_origin(center)
    return scene.player.map_combat.shot_trace(origin,origin+camera.project_ray_normal(center)*50)
func muzzle_ray(point: Vector3) -> Dictionary:
    var p=scene.player;var origin=p.weapons.visual.muzzle_position();var direction=point-origin
    if direction.length()<.000001:return {}
    var reach=float(p.weapons.spec(p.bag_inventory.equipped("main_hand")).get("reach",8))
    var hit=p.map_combat.shot_trace(origin,origin+direction.normalized()*minf(reach,direction.length()+.02))
    return {} if hit.get("collider")==null else hit
