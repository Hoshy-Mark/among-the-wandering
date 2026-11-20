extends "res://personagem/combate_mapa79.gd"
func request(kind: String="") -> bool:
    var p=scene.player
    if p.weapons==null:return super.request(kind)
    if not ready_to_act() or p.combat.is_attacking():return false
    var uid=p.bag_inventory.equipped("main_hand")
    var weapon=p.weapons.spec(uid).duplicate(true)
    if kind.is_empty():kind="strike_onehand" if not weapon.is_empty() else "punch"
    if kind not in ["punch","push","strike_onehand"] or (kind=="strike_onehand" and weapon.is_empty()) or (kind=="punch" and not weapon.is_empty()):return false
    var cost=float(weapon.cost) if kind=="strike_onehand" else float(costs[kind])
    if p.condition_state.stamina<cost or not p.set_crouch(false):return false
    var selected="push_armed" if kind=="push" and not weapon.is_empty() else kind
    var definition: Dictionary=p.combat.definitions[selected].duplicate(true)
    if kind=="strike_onehand":definition.reach=weapon.reach
    var target=nearest(definition);var receiver=weakref(target) if target!=null else null
    var weapon_id="" if uid.is_empty() else str(p.bag_inventory.items[uid].definition)
    var event_id="weapon86_"+Crypto.new().generate_random_bytes(12).hex_encode()
    var accepted=p.combat.begin(kind,func() -> bool:
        var victim=receiver.get_ref() if receiver!=null else null
        if not is_instance_valid(victim) or not valid_target(victim,definition):return false
        if p.bag_inventory.equipped("main_hand")!=uid:return false
        if not uid.is_empty() and (not p.bag_inventory.items.has(uid) or p.bag_inventory.items[uid].definition!=weapon_id):return false
        var event={"id":event_id,"action":kind,"zone":"chest","kind":"bruise","amount":float(weapon.damage) if kind=="strike_onehand" else .06 if kind=="push" else .12,"source_position":p.global_position,"weapon_uid":uid,"weapon_definition":weapon_id}
        var applied=victim.receive_combat_hit(event)
        var result=applied is bool and applied
        resolved.emit(event,result)
        return result
    )
    if accepted:p.condition_state.set_stamina(p.condition_state.stamina-cost);p.preview_motion=""
    return accepted
