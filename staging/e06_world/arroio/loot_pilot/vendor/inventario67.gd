extends "res://staging/e06_world/arroio/loot_pilot/vendor/inventario66.gd"

var house_anchors: Dictionary={}

func valid_world(data: Variant) -> bool:
    if not super.valid_world(data):
        return false
    for entry in data.values():
        if entry.has("furniture") and (not entry.furniture is String or entry.furniture.length()>80 or entry.get("house")!="H01"):
            return false
    return true

func register_anchor(id: String, entry: Dictionary, seeds: Array) -> void:
    house_anchors[id]=entry.duplicate(true)
    if world_containers.has(id):
        world_containers[id]=entry.duplicate(true)
        return
    world_containers[id]=entry.duplicate(true)
    for seed in seeds:
        add(seed[0],int(seed[1]),id)

func set_open(id: String, value: bool) -> bool:
    if not world_containers.has(id) or not world_containers[id].has("furniture"):
        return super.set_open(id,value)
    var group: String=world_containers[id].furniture
    if value and id not in reachable:
        return false
    for candidate in world_containers:
        if world_containers[candidate].get("furniture","")==group:
            if value and candidate in reachable and candidate not in opened:
                opened.append(candidate)
            elif not value:
                opened.erase(candidate)
    changed.emit()
    return true

func restore(data: Variant, notify: bool=true) -> bool:
    var candidate: Variant=data.duplicate(true) if data is Dictionary else data
    if candidate is Dictionary and candidate.get("version")==1:
        var migration=load("res://staging/e06_world/arroio/loot_pilot/vendor/inventario66.gd").new()
        if not migration.restore(candidate,false):
            return false
        candidate=migration.snapshot()
    if candidate is Dictionary and candidate.get("version")==2 and candidate.get("world_containers") is Dictionary:
        for id in house_anchors:
            # The map owns fixed furniture anchors, independent of saved positions.
            candidate.world_containers[id]=house_anchors[id].duplicate(true)
    return super.restore(candidate,notify)
