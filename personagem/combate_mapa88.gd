extends "res://personagem/combate_mapa87.gd"
func request(kind: String="") -> bool:
    var p=scene.player;var aim=p.shoulder
    var uid=p.bag_inventory.equipped("main_hand");var spec=p.weapons.spec(uid)
    if spec.get("type","")!="firearm" or kind=="push":return super.request(kind)
    if kind not in ["","firearm_shot"] or aim==null or not aim.ready_to_fire() or not ready_to_act() or p.combat.is_attacking():return false
    if p.weapons.loaded(uid)<=0:p.inventory_message="Arma vazia · R para recarregar";return false
    if p.condition_state.stamina<float(spec.cost):return false
    var event_id="shoulder88_"+Crypto.new().generate_random_bytes(12).hex_encode()
    var accepted=p.combat.begin("firearm_shot",func() -> bool:
        if p.bag_inventory.equipped("main_hand")!=uid or p.weapons.loaded(uid)<=0:return false
        var point: Vector3=aim.aim_ray().position
        p.weapons.rounds[uid]=p.weapons.loaded(uid)-1;p.weapons.flash();_noise()
        var hit=aim.muzzle_ray(point)
        var receiver=hit.get("collider")
        var event={"id":event_id,"action":"firearm_shot","kind":"bullet","zone":"chest","amount":float(spec.damage),"source_position":p.global_position,"weapon_uid":uid}
        var applied=false
        if is_instance_valid(receiver) and receiver.has_method("receive_combat_hit"):applied=receiver.receive_combat_hit(event)
        p.inventory_message="Pistola · %d/%d"%[p.weapons.loaded(uid),int(spec.capacity)]
        resolved.emit(event,applied);return applied
    )
    if accepted:p.condition_state.set_stamina(p.condition_state.stamina-float(spec.cost));p.preview_motion=""
    return accepted
func _physics_process(delta: float) -> void:
    if scene!=null and scene.player.shoulder!=null and scene.player.shoulder.owns_camera():_react();return
    super._physics_process(delta)
