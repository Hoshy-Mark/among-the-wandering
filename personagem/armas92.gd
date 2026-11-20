extends "res://personagem/armas90.gd"
const EXTRA_CACHE="world:arsenal92"
func setup(root_scene: Node3D) -> void:
    super.setup(root_scene)
    visual.queue_free();visual=load("res://personagem/arma_visual92.gd").new()
    scene.player.avatar.add_child(visual);scene.player.combat.weapon=visual
    presentation.magazine.queue_free();presentation.queue_free()
    presentation=load("res://personagem/postura_armas92.gd").new();add_child(presentation);presentation.setup(scene.player)
    held_definition="";held_uid="";sync()
func sync() -> void:
    if scene==null:return
    var p=scene.player;var bag=p.bag_inventory
    for uid in rounds.keys():
        if not bag.items.has(uid) or spec(uid).get("type","")!="firearm":rounds.erase(uid)
    for uid in bag.items:
        if spec(uid).get("type","")=="firearm" and not rounds.has(uid):rounds[uid]=0
    p.combat.firearm_mode=spec(bag.equipped("main_hand")).get("type","")=="firearm"
    var uid=bag.equipped("main_hand");var id="" if uid.is_empty() else str(bag.items[uid].definition)
    if uid!=held_uid or id!=held_definition:
        if p.combat.is_attacking():p.combat.cancel()
        held_uid=uid;held_definition=id;visual.configure(id)
        var info=spec(uid)
        p.combat.definitions.firearm_shot={"duration":float(info.get("shot_seconds",.48)),"impact_time":.10,"right_pose":"Cylinder","left_pose":"Fist"}
    var armed=not uid.is_empty() and not spec(uid).is_empty()
    if p.combat.armed!=armed:p.combat.set_armed(armed)
    present()
func seed_firearms(model: RefCounted) -> bool:
    return super.seed_firearms(model) and seed_extra(model)
func seed_extra(model: RefCounted) -> bool:
    var missing=[]
    for id in ["revolver","carbine","ammo_carbine"]:
        if not model.items.values().any(func(item):return item.definition==id):missing.append(id)
    if missing.is_empty():return true
    if model.world_containers.has(EXTRA_CACHE):return false
    var raw: Array=scene.demo_data.spawn_local
    var point=scene.world_items.house.home.model.to_global(Vector3(raw[0],raw[1],raw[2]))
    var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP,1)
    var floor=get_world_3d().direct_space_state.intersect_ray(ray)
    if floor.is_empty():return false
    point.y=floor.position.y+.01
    model.world_containers[EXTRA_CACHE]={"name":"Chão · Armas adicionais","kind":"ground","capacity":999,"position":[point.x,point.y,point.z]}
    for i in missing.size():
        if model.add_at(missing[i],16 if missing[i]=="ammo_carbine" else 1,EXTRA_CACHE,[0,3,4][i],0,false).is_empty():return false
    return true
func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    if scene==null or status==null:return
    var info=spec(held_uid)
    if info.get("type","")=="firearm":status.text="%s · %d/%d · R recarregar"%[scene.player.bag_inventory.catalog[held_definition].name,loaded(held_uid),int(info.capacity)]
