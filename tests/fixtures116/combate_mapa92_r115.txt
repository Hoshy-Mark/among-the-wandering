extends "res://personagem/combate_mapa88.gd"
var config: Dictionary
var ballistics=load("res://personagem/balistica91.gd").new()
var effects: Node3D
var last_shot={}
func setup(root_scene: Node3D) -> void:
    super.setup(root_scene);ballistics.scene=scene
    config=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/tiros91.json"))
    effects=load("res://personagem/impactos91.gd").new();effects.scene=scene;add_child(effects)
func shot_trace(origin: Vector3,end: Vector3) -> Dictionary:return ballistics.trace(origin,end)
func request(kind: String="") -> bool:
    var p=scene.player;var aim=p.shoulder;var service=p.weapons;var uid=p.bag_inventory.equipped("main_hand");var spec=service.spec(uid)
    if spec.get("type","")!="firearm" or kind=="push":return super.request(kind)
    if kind not in ["","firearm_shot"] or aim==null or not aim.ready_to_fire() or not ready_to_act() or p.combat.is_attacking():return false
    if service.loaded(uid)<=0:p.inventory_message="Arma vazia · R para recarregar";return false
    if p.condition_state.stamina<float(spec.cost):return false
    var definition=str(p.bag_inventory.items[uid].definition)
    var event_id="shot91_"+Crypto.new().generate_random_bytes(12).hex_encode()
    var accepted=p.combat.begin("firearm_shot",func() -> bool:
        if p.bag_inventory.equipped("main_hand")!=uid or not p.bag_inventory.items.has(uid) or p.bag_inventory.items[uid].definition!=definition or service.loaded(uid)<=0:return false
        var cone=aim.cone_degrees();var direction: Vector3=aim.direction_with_spread(cone)
        var center=scene.get_viewport().get_visible_rect().size*.5;var camera_origin=scene.camera.project_ray_origin(center)
        var camera_hit=shot_trace(camera_origin,camera_origin+direction*50)
        var origin: Vector3=service.visual.muzzle_position();var towards: Vector3=camera_hit.position-origin
        var point=origin+towards.normalized()*minf(float(spec.reach),towards.length()+.02)
        var hit=shot_trace(origin,point);var receiver=hit.get("collider");var zone=str(hit.get("zone",""))
        service.rounds[uid]=service.loaded(uid)-1;service.flash();_noise();aim.note_shot()
        var amount=minf(1,float(spec.damage)*float(config.damage_factors.get(zone,0)))
        var event={"id":event_id,"action":"firearm_shot","kind":"bullet","zone":zone,"amount":amount,"source_position":p.global_position,"weapon_uid":uid,"position":hit.position,"normal":hit.normal}
        var applied=false
        if is_instance_valid(receiver) and not zone.is_empty() and receiver.has_method("receive_combat_hit"):applied=receiver.receive_combat_hit(event)
        if applied:aim.confirm_hit(zone)
        effects.spawn(origin,hit.position,hit.normal,"flesh" if applied else "world" if is_instance_valid(receiver) else "miss")
        last_shot={"event":event,"hit":applied,"cone_degrees":cone,"direction":direction,"origin":origin,"end":hit.position,"receiver_id":receiver.identity if applied else ""}
        p.inventory_message="%s · %d/%d"%[p.bag_inventory.catalog[definition].name,service.loaded(uid),int(spec.capacity)]
        resolved.emit(event,applied);return applied
    )
    if accepted:p.condition_state.set_stamina(p.condition_state.stamina-float(spec.cost));p.preview_motion=""
    return accepted
