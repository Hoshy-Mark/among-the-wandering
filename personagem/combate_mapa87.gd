extends "res://personagem/combate_mapa86.gd"
func reload_weapon() -> bool:return scene.player.weapons.reload_weapon()
func request(kind: String="") -> bool:
    var p=scene.player;var service=p.weapons;var uid=p.bag_inventory.equipped("main_hand");var spec=service.spec(uid)
    if spec.get("type","")!="firearm" or kind=="push":return super.request(kind)
    if kind not in ["","firearm_shot"] or not ready_to_act() or p.combat.is_attacking() or not service.reload_job.is_empty():return false
    if service.loaded(uid)<=0:p.inventory_message="Arma vazia · R para recarregar";return false
    if p.condition_state.stamina<float(spec.cost) or not p.set_crouch(false):return false
    var definition={"reach":float(spec.reach),"cone_degrees":float(spec.cone_degrees)}
    var target=nearest(definition);var receiver=weakref(target) if target!=null else null
    var event_id="shot87_"+Crypto.new().generate_random_bytes(12).hex_encode()
    var accepted=p.combat.begin("firearm_shot",func() -> bool:
        if p.bag_inventory.equipped("main_hand")!=uid or service.loaded(uid)<=0:return false
        service.rounds[uid]=service.loaded(uid)-1
        service.flash();_noise()
        p.inventory_message="Pistola · %d/%d"%[service.loaded(uid),int(spec.capacity)]
        var victim=receiver.get_ref() if receiver!=null else null
        var event={"id":event_id,"action":"firearm_shot","kind":"bullet","zone":"chest","amount":float(spec.damage),"source_position":p.global_position,"weapon_uid":uid}
        var applied=false
        if is_instance_valid(victim) and valid_target(victim,definition):
            var query=PhysicsRayQueryParameters3D.create(service.visual.muzzle_position(),victim.global_position+Vector3.UP*1.15,3,[p.get_rid()])
            var hit=get_world_3d().direct_space_state.intersect_ray(query)
            if hit.is_empty() or hit.collider==victim:applied=victim.receive_combat_hit(event)
        resolved.emit(event,applied)
        return applied
    )
    if accepted:p.condition_state.set_stamina(p.condition_state.stamina-float(spec.cost));p.preview_motion=""
    return accepted
func _noise() -> void:
    for node in candidates():
        if node.has_method("hear_shot"):node.hear_shot(scene.player.global_position,12.0)
