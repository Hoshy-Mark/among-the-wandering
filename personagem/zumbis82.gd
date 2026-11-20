extends Node3D
var scene: Node3D
var actors={}
var initial={}
func setup(root_scene: Node3D) -> void:
    scene=root_scene
    var config=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/zumbis82.json"))
    for definition in config.actors:
        var raw=definition.local
        var point=scene.world_items.house.home.model.to_global(Vector3(raw[0],raw[1],raw[2]))
        var found=false
        for offset in [Vector3.ZERO,Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)]:
            var floor_query=PhysicsRayQueryParameters3D.create(point+offset+Vector3.UP*2,point+offset-Vector3.UP*2,1)
            var floor=get_world_3d().direct_space_state.intersect_ray(floor_query)
            if floor.is_empty():continue
            var candidate: Vector3=floor.position+Vector3.UP*.02
            if candidate.distance_to(scene.player.global_position)<7 or not scene.world_items.house.standing_clear(candidate):continue
            point=candidate;found=true;break
        assert(found,"No safe zombie spawn "+definition.id)
        if not found:continue
        var actor=load("res://personagem/zumbi82.gd").new()
        add_child(actor);actor.setup(scene,definition);actor.global_position=point
        actors[definition.id]=actor
        initial[definition.id]=actor.snapshot()
func settled() -> bool:
    for actor in actors.values():
        if actor.state in ["attack","hit","dying"]:return false
    return true
func snapshot() -> Dictionary:
    var result={}
    for id in actors:result[id]=actors[id].snapshot()
    return result
func valid(data: Variant) -> bool:
    if not data is Dictionary or data.size()!=actors.size():return false
    for id in actors:
        if not data.has(id) or not data[id] is Dictionary:return false
        var entry: Dictionary=data[id]
        if entry.get("state") not in ["idle","chase","search","dead"]:return false
        for key in ["position","last_known"]:
            if not entry.get(key) is Array or entry[key].size()!=3:return false
            for n in entry[key]:
                if not (n is int or n is float) or not is_finite(float(n)) or absf(n)>10000:return false
        for key in ["yaw","health","memory","cooldown"]:
            var n=entry.get(key)
            if not (n is int or n is float) or not is_finite(float(n)):return false
        if entry.health<0 or entry.health>.48 or (entry.state=="dead")!=(entry.health<=.0001) or entry.memory<0 or entry.memory>4 or entry.cooldown<0 or entry.cooldown>1.2:return false
    return true
func restore(data: Dictionary) -> void:
    for id in actors:actors[id].restore(data[id])
