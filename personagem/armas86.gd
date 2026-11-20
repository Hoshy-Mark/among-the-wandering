extends Node3D
const CACHE="world:weapons86"
var scene: Node3D
var held_uid=""
var held_definition=""
var visual: Node3D
func setup(root_scene: Node3D) -> void:
    scene=root_scene;scene.player.weapons=self
    var p=scene.player
    p.combat.weapon.visible=false;p.combat.weapon.queue_free()
    visual=load("res://personagem/arma_visual86.gd").new();p.avatar.add_child(visual);p.combat.weapon=visual
    p.bag_inventory.changed.connect(sync)
    p.action.started.connect(present)
    sync()
func spec(uid: String) -> Dictionary:
    var bag=scene.player.bag_inventory
    if not bag.items.has(uid):return {}
    return bag.catalog[bag.items[uid].definition].get("weapon",{})
func sync() -> void:
    var p=scene.player;var uid=p.bag_inventory.equipped("main_hand")
    var id="" if uid.is_empty() else str(p.bag_inventory.items[uid].definition)
    if uid!=held_uid or id!=held_definition:
        if p.combat.is_attacking():p.combat.cancel()
        held_uid=uid;held_definition=id
        visual.configure(id)
    var armed=not uid.is_empty() and not spec(uid).is_empty()
    if p.combat.armed!=armed:p.combat.set_armed(armed)
    present()
func present() -> void:
    if scene==null or visual==null:return
    var p=scene.player
    var busy=p.action.state!="idle" or p.traversal.is_active() or p.reaction.is_active() or not p.flow.queue.is_empty()
    visual.visible=not held_uid.is_empty() and not spec(held_uid).is_empty() and not busy
    visual.attach(p.avatar)
    if busy:return
    if visual.visible and not p.combat.guarding and not p.combat.is_attacking() and p.avatar.hand_layer.label!="R_Cylinder":p.avatar.hand_layer.set_pose("R_Cylinder")
    elif not visual.visible and not p.combat.guarding and p.avatar.hand_layer.label=="R_Cylinder":p.avatar.hand_layer.set_pose("Relaxed")
func seed(model: RefCounted) -> bool:
    var missing=[]
    for definition in ["baton","metal_bar"]:
        if not model.items.values().any(func(item):return item.definition==definition):missing.append(definition)
    if missing.is_empty():return true
    if model.world_containers.has(CACHE):return false
    var raw: Array=scene.demo_data.spawn_local
    var point=scene.world_items.house.home.model.to_global(Vector3(raw[0],raw[1],raw[2]))
    var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP,1)
    var floor=get_world_3d().direct_space_state.intersect_ray(ray)
    if floor.is_empty():return false
    point.y=floor.position.y+.01
    model.world_containers[CACHE]={"name":"Chão · Entrada H01","kind":"ground","capacity":999,"position":[point.x,point.y,point.z]}
    for definition in missing:
        var uid=model.add_at(definition,1,CACHE,0 if definition=="baton" else 1,0,false)
        if uid.is_empty():return false
    return true
