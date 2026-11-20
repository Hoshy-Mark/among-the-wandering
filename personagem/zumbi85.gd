extends "res://personagem/zumbi84.gd"
var profiles: Dictionary
var variant_id=""
var default_variant=""
var profile: Dictionary
var last_attack_zone=""
var last_attack_result=false
func setup(root_scene: Node3D,definition: Dictionary) -> void:
    var config=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/perfis_zumbis85.json"))
    profiles=config.profiles;default_variant=config.assignments[definition.id]
    variant_id=default_variant;profile=profiles[variant_id].duplicate(true)
    super.setup(root_scene,definition)
    _appearance()
func _appearance() -> void:
    var skin_id="infectado85_"+variant_id
    if not avatar.catalog.options.skin_id.any(func(item):return item.id==skin_id):avatar.catalog.options.skin_id.append({"id":skin_id,"name":profile.label,"hex":profile.skin})
    var applied=avatar.set_appearance({"skin_id":skin_id})
    if not applied:push_error("Invalid NPC profile appearance")
    crossing.playback_rate=profile.cross_rate
func movement_speed() -> float:return float(profile.get("speed",.95))
func walking_rate() -> float:return movement_speed()/.95*.62
func attack_duration() -> float:return float(profile.get("attack_duration",1.12))
func hit_duration() -> float:return float(profile.get("push_stun",.8) if hit_motion=="stagger" else profile.get("hit_stun",.8))
func hit_rate(clip: String) -> float:
    return avatar.player.get_animation(avatar.clips[clip]).length/hit_duration()
func attack_zone() -> String:
    var p=scene.player
    var local=p.avatar.global_basis.inverse()*(global_position-p.global_position)
    if local.z< -absf(local.x):return "chest"
    if absf(local.x)>absf(local.z):return "upper_arm_left" if local.x>0 else "upper_arm_right"
    return "forearm_left" if local.x>=0 else "forearm_right"
func _begin_attack() -> void:
    super._begin_attack();last_attack_zone="";last_attack_result=false
func _attack_step(delta: float) -> void:
    if state!="attack" or not is_finite(delta) or delta<=0:return
    elapsed+=delta
    if not effect_done and elapsed>=float(profile.impact):
        effect_done=true
        if can_hit_player():
            last_attack_zone=attack_zone()
            last_attack_result=scene.player.receive_combat_hit({"id":attack_id,"action":"zombie_scratch","zone":last_attack_zone,"kind":"scratch","amount":.06,"source_position":global_position})
            if last_attack_result:hits+=1
    if elapsed>=attack_duration():state="search";cooldown=profile.recovery;elapsed=0
func step(delta: float) -> void:
    var was_hit=state=="hit"
    super.step(delta)
    if was_hit and state=="search":cooldown=maxf(cooldown,float(profile.after_hit))
func snapshot() -> Dictionary:
    var data=super.snapshot();data.variant85=variant_id
    return data
func restore(data: Dictionary) -> void:
    var requested=str(data.get("variant85",default_variant))
    if not profiles.has(requested):return
    if variant_id!=requested:variant_id=requested;profile=profiles[requested].duplicate(true);_appearance()
    last_attack_zone="";last_attack_result=false
    super.restore(data)
