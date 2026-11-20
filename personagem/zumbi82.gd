extends CharacterBody3D
signal changed
var scene: Node3D
var identity=""
var avatar: Node3D
var capsule: CollisionShape3D
var state="idle"
var health=.48
var elapsed=0.0
var cooldown=0.0
var memory=0.0
var last_known=Vector3.ZERO
var recoil=Vector3.ZERO
var seen={}
var attack_id=""
var effect_done=false
var attacks=0
var hits=0
var ai_enabled=true
var motion=""
var hit_motion="hit_front"
func setup(root_scene: Node3D,definition: Dictionary) -> void:
    scene=root_scene;identity=definition.id
    name=identity
    collision_layer=2;collision_mask=3;floor_snap_length=.2
    capsule=CollisionShape3D.new()
    var shape=CapsuleShape3D.new();shape.radius=.23;shape.height=1.84
    capsule.shape=shape;capsule.position.y=.92;add_child(capsule)
    avatar=load("res://personagem/personagem.tscn").instantiate()
    avatar.manual_update=true;avatar.position.y=.006;add_child(avatar)
    avatar.catalog.options.skin_id.append({"id":"infectado82","name":"Pele infectada","hex":"#96ab87"})
    var applied=avatar.set_appearance({"skin_id":"infectado82","hair_id":definition.hair,"beard_id":"none","mustache_id":"none","shirt_id":definition.shirt,"pants_id":"calca_carvao","boots_id":"botas_escuras"})
    if not applied:push_error("Invalid zombie appearance "+identity)
    avatar.rotation.y=definition.yaw
    avatar.hand_layer.set_pose("Relaxed")
    add_to_group("combat_receivers79")
func _distance(point: Vector3) -> float:
    return Vector2(point.x-global_position.x,point.z-global_position.z).length()
func clear_line(point: Vector3,receiver: Object=null) -> bool:
    var query=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.15,point+Vector3.UP*1.15,3,[get_rid()])
    var hit=get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.collider==receiver
func sees_player() -> bool:
    var p=scene.player
    var delta=p.global_position-global_position;delta.y=0
    var reach=3.5 if p.crouched else 6.5
    return absf(p.global_position.y-global_position.y)<.8 and delta.length()<=reach and (delta.length()<.05 or avatar.global_basis.z.dot(delta.normalized())>=cos(deg_to_rad(55))) and clear_line(p.global_position,p)
func hears_player() -> bool:
    return not scene.player.crouched and Vector2(scene.player.velocity.x,scene.player.velocity.z).length()>2.7 and _distance(scene.player.global_position)<8
func can_hit_player() -> bool:
    var delta=scene.player.global_position-global_position
    var flat=Vector3(delta.x,0,delta.z)
    return absf(delta.y)<.55 and flat.length()<=1.05 and (flat.length()<.05 or avatar.global_basis.z.dot(flat.normalized())>.6) and clear_line(scene.player.global_position,scene.player)
func _begin_attack() -> void:
    state="attack";elapsed=0;effect_done=false
    attack_id="z82_"+Crypto.new().generate_random_bytes(12).hex_encode()
    attacks+=1
func _attack_step(delta: float) -> void:
    elapsed+=delta
    if not effect_done and elapsed>=.52:
        effect_done=true
        if can_hit_player():
            if scene.player.receive_combat_hit({"id":attack_id,"action":"zombie_scratch","zone":"forearm_left" if identity.ends_with("01") else "forearm_right","kind":"scratch","amount":.06,"source_position":global_position}):hits+=1
    if elapsed>=1.12:state="search";cooldown=1.2;elapsed=0
func _safe_direction(direction: Vector3) -> bool:
    var point=global_position+direction*.65
    var floor_query=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.35,point-Vector3.UP*.55,1,[get_rid()])
    var floor=get_world_3d().direct_space_state.intersect_ray(floor_query)
    if floor.is_empty() or floor.normal.y<.8 or absf(floor.position.y-global_position.y)>.3:return false
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=capsule.shape;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.95);query.exclude=[get_rid()];query.collision_mask=3
    return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func steer(goal: Vector3) -> Vector3:
    var toward=goal-global_position;toward.y=0
    if toward.length()<.12:return Vector3.ZERO
    toward=toward.normalized()
    for angle in [0,35,-35,70,-70,110,-110]:
        var direction=toward.rotated(Vector3.UP,deg_to_rad(angle))
        if _safe_direction(direction):return direction
    return Vector3.ZERO
func _present(delta: float) -> void:
    var next="idle";var rate=1.0
    if state in ["chase","search"] and Vector2(velocity.x,velocity.z).length()>.1:next="walk";rate=walking_rate()
    elif state=="attack":next="push";rate=avatar.player.get_animation(avatar.clips.push).length/attack_duration()
    elif state=="hit":next=hit_motion;rate=hit_rate(hit_motion)
    elif state in ["dying","dead"]:next="death"
    if motion!=next:
        motion=next;avatar.set_motion(next);avatar.motion_clock=0
    avatar.motion_rate=0 if state=="dead" else rate
    if state=="dead":avatar.motion_clock=1.8;avatar.motion_blend=1
    var hand="Open" if state=="attack" else "Relaxed"
    if avatar.hand_layer.label!=hand:avatar.hand_layer.set_pose(hand)
    avatar.advance(delta)
func _physics_process(delta: float) -> void:
    if scene==null or not ai_enabled or scene.player.paused:return
    step(delta)
func step(delta: float) -> void:
    if not is_finite(delta) or delta<=0:return
    cooldown=maxf(0,cooldown-delta)
    velocity.x=0;velocity.z=0
    if state=="dead":_present(0);return
    if state=="dying":
        elapsed+=delta
        if elapsed>=1.8:
            state="dead";capsule.set_deferred("disabled",true);remove_from_group("combat_receivers79");changed.emit()
    elif state=="hit":
        elapsed+=delta
        velocity.x=recoil.x;velocity.z=recoil.z
        recoil=recoil.move_toward(Vector3.ZERO,delta*2.5)
        if elapsed>=hit_duration():state="search";elapsed=0;recoil=Vector3.ZERO
    elif state=="attack":_attack_step(delta)
    elif scene.player.reaction.state=="dead":state="idle"
    else:
        var detected=sees_player() or hears_player()
        if detected:
            last_known=scene.player.global_position;memory=4;state="chase"
        else:
            memory=maxf(0,memory-delta)
            state="search" if memory>0 else "idle"
        if detected and _distance(last_known)<1.2:
            var facing=last_known-global_position
            avatar.rotation.y=lerp_angle(avatar.rotation.y,atan2(facing.x,facing.z),minf(1,delta*6))
        if detected and cooldown<=0 and can_hit_player():_begin_attack()
        elif should_pursue():
            var direction=steer(last_known)
            velocity.x=direction.x*movement_speed();velocity.z=direction.z*movement_speed()
            if direction.length()>.01:avatar.rotation.y=lerp_angle(avatar.rotation.y,atan2(direction.x,direction.z),minf(1,delta*5))
    if not is_on_floor():velocity.y-=20*delta
    else:velocity.y=0
    move_and_slide()
    _present(delta)
func receive_combat_hit(event: Dictionary) -> bool:
    if state in ["dying","dead"] or not event.get("id") is String or event.id.is_empty() or seen.has(event.id):return false
    var amount=event.get("amount");var source=event.get("source_position")
    if not (amount is int or amount is float) or not is_finite(float(amount)) or amount<=0 or amount>1 or not source is Vector3 or not source.is_finite() or event.get("action") not in ["punch","push","strike_onehand"]:return false
    var local=avatar.global_basis.inverse()*(source-global_position)
    hit_motion="hit_front" if absf(local.z)>=absf(local.x) and local.z>=0 else "hit_back" if absf(local.z)>=absf(local.x) else "hit_left" if local.x>0 else "hit_right"
    if event.action=="push" and hit_motion=="hit_front":hit_motion="stagger"
    seen[event.id]=true
    health=maxf(0,health-(0 if event.action=="push" else float(amount)))
    var away=global_position-source;away.y=0
    recoil=away.normalized()*(1.15 if event.action=="push" else .25)
    effect_done=true;attack_id="";elapsed=0;memory=4;last_known=source
    state="dying" if health<=.0001 else "hit"
    if state=="dying":remove_from_group("combat_receivers79")
    changed.emit()
    return true
func snapshot() -> Dictionary:
    return {"position":[global_position.x,global_position.y,global_position.z],"yaw":avatar.rotation.y,"health":health,"state":state,"memory":memory,"last_known":[last_known.x,last_known.y,last_known.z],"cooldown":cooldown}
func restore(data: Dictionary) -> void:
    global_position=Vector3(data.position[0],data.position[1],data.position[2]);avatar.rotation.y=data.yaw
    health=data.health;state=data.state;memory=data.memory;last_known=Vector3(data.last_known[0],data.last_known[1],data.last_known[2]);cooldown=data.cooldown
    velocity=Vector3.ZERO;elapsed=0;recoil=Vector3.ZERO;effect_done=true;attack_id="";seen.clear()
    capsule.disabled=state=="dead"
    if state=="dead":remove_from_group("combat_receivers79")
    elif not is_in_group("combat_receivers79"):add_to_group("combat_receivers79")
    motion="";_present(0)

func should_pursue() -> bool:
    return memory>0 and _distance(last_known)>.95

func movement_speed() -> float:return .95
func walking_rate() -> float:return .62
func attack_duration() -> float:return 1.12
func hit_duration() -> float:return .8
func hit_rate(_clip: String) -> float:return 1.0
