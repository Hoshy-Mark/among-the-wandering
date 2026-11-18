extends "res://personagem/inventario63.gd"
signal access_changed

const REACH=1.8
var world_containers: Dictionary={}
var reachable: Array[String]=[]
var actor_position=Vector3.ZERO

func _init() -> void:
    super()
    configure(Vector3.ZERO)

func configure(origin: Vector3) -> void:
    world_containers["world:crate"]={"name":"Caixa de suprimentos","position":[origin.x+1.1,origin.y,origin.z],"capacity":12,"kind":"crate"}
    world_containers["world:cabinet"]={"name":"Armário de teste","position":[origin.x+1.1,origin.y,origin.z-3.5],"capacity":18,"kind":"cabinet"}

func point(id: String) -> Vector3:
    var p: Array=world_containers[id].position
    return Vector3(p[0],p[1],p[2])

func set_reachable(ids: Array[String], position: Vector3) -> void:
    actor_position=position
    if reachable!=ids:
        reachable=ids
        access_changed.emit()

func accessible(location: String) -> bool:
    if location=="pockets" or location.begins_with("slot:"):
        return true
    if world_containers.has(location):
        return location in reachable
    if items.has(location):
        var owner: String=items[location].location
        return owner=="slot:backpack" or owner in reachable
    return false

func can_touch(uid: String) -> bool:
    return items.has(uid) and accessible(items[uid].location)

func capacity(container: String) -> int:
    if world_containers.has(container):
        return int(world_containers[container].capacity)
    return super.capacity(container)

func move(uid: String, destination: String) -> bool:
    if not can_touch(uid) or not accessible(destination):
        message="Aproxime-se do recipiente ou item"
        return false
    return super.move(uid,destination)

func move_to_ground(uid: String, position: Vector3) -> bool:
    if not can_touch(uid):
        message="Item fora de alcance"
        return false
    var saved=world_containers.duplicate(true)
    var access=reachable.duplicate()
    var id=ground_at(position)
    if move(uid,id):
        return true
    world_containers=saved
    reachable=access
    return false

func ground_at(position: Vector3) -> String:
    for id in world_containers:
        if world_containers[id].kind=="ground" and point(id).distance_to(position)<.65 and id in reachable:
            return id
    for id in world_containers.keys():
        if world_containers[id].kind=="ground" and contents(id).is_empty():
            world_containers.erase(id)
            reachable.erase(id)
    if world_containers.size()>=4096:
        message="Limite de pontos de armazenamento atingido"
        return ""
    var id="world:drop:%d"%next_id
    var suffix=0
    while world_containers.has(id):
        suffix+=1
        id="world:drop:%d:%d"%[next_id,suffix]
    world_containers[id]={"name":"Itens no chão","position":[position.x,position.y,position.z],"capacity":999,"kind":"ground"}
    reachable.append(id)
    return id

func equip(uid: String) -> bool:
    if not can_touch(uid):
        message="Item fora de alcance"
        return false
    var slot: String=catalog[items[uid].definition].get("slot","")
    if slot.is_empty():
        return false
    var previous=equipped(slot)
    var source: String=items[uid].location
    var saved=world_containers.duplicate(true)
    var access=reachable.duplicate()
    var staged=items.duplicate(true)
    staged[uid].location="slot:"+slot
    if not previous.is_empty() and previous!=uid:
        staged[previous].location=ground_at(actor_position) if slot=="backpack" else source
    if _commit(staged):
        return true
    world_containers=saved
    reachable=access
    return false

func valid(staged: Variant) -> bool:
    if not staged is Dictionary:
        return false
    var used: Dictionary={}
    for uid in staged:
        if not uid is String or uid.is_empty() or uid in ["ground","pockets"] or uid.begins_with("slot:") or uid.begins_with("world:") or not staged[uid] is Dictionary:
            return false
        var item: Dictionary=staged[uid]
        if not catalog.has(item.get("definition","")) or not item.get("location") is String:
            return false
        if not (item.get("count") is int or item.get("count") is float) or not is_finite(float(item.count)) or item.count!=floor(item.count) or item.count<1 or item.count>catalog[item.definition].stack:
            return false
        var definition: Dictionary=catalog[item.definition]
        var location: String=item.location
        if location.begins_with("slot:"):
            var slot=location.trim_prefix("slot:")
            if slot not in SLOTS or definition.get("slot","")!=slot or used.has(location):
                return false
            used[location]=1
        else:
            var limit=6 if location=="pockets" else int(world_containers[location].capacity) if world_containers.has(location) else 0
            if location=="pockets" and not staged.values().any(func(entry):return entry is Dictionary and entry.get("location")=="slot:pants"):
                limit=0
            if staged.has(location):
                var bag: Dictionary=staged[location]
                if not catalog.has(bag.get("definition","")):
                    return false
                limit=int(catalog[bag.definition].get("capacity",0))
                if definition.has("capacity"):
                    return false
            if definition.has("capacity") and not world_containers.has(location):
                return false
            if limit<=0:
                return false
            used[location]=int(used.get(location,0))+1
            if used[location]>limit:
                return false
    return true

func valid_world(data: Variant) -> bool:
    if not data is Dictionary or data.size()>4096:
        return false
    for id in data:
        if not id is String or not id.begins_with("world:") or id.length()>100 or not data[id] is Dictionary:
            return false
        var entry: Dictionary=data[id]
        if not entry.get("name") is String or entry.name.length()>80 or entry.get("kind") not in ["ground","crate","cabinet"]:
            return false
        if not entry.get("position") is Array or entry.position.size()!=3:
            return false
        for component in entry.position:
            if not (component is float or component is int) or not is_finite(float(component)) or absf(float(component))>100000:
                return false
        var limit=entry.get("capacity")
        if not (limit is float or limit is int) or not is_finite(float(limit)) or limit<1 or limit>999 or limit!=floor(limit):
            return false
    return true

func snapshot() -> Dictionary:
    return {"version":2,"items":items.duplicate(true),"next_id":next_id,"world_containers":world_containers.duplicate(true)}

func restore(data: Variant, notify: bool=true) -> bool:
    if not data is Dictionary or (data.get("version")!=1 and data.get("version")!=2):
        return false
    var candidate: Dictionary=data.duplicate(true)
    var registry=world_containers.duplicate(true)
    if candidate.version==1:
        if not candidate.get("items") is Dictionary:
            return false
        for entry in candidate.items.values():
            if entry is Dictionary and entry.get("location")=="ground":
                entry.location="world:crate"
        if not registry.has("world:crate"):
            registry["world:crate"]={"name":"Caixa importada","position":[actor_position.x,actor_position.y,actor_position.z],"capacity":12,"kind":"crate"}
        # Retain every legacy bancada item if it exceeds the new finite capacity.
        var legacy_count=0
        for entry in candidate.items.values():
            if entry is Dictionary and entry.get("location")=="world:crate":
                legacy_count+=1
        registry["world:crate"].capacity=maxi(12,legacy_count)
    else:
        if not candidate.get("world_containers") is Dictionary:
            return false
        registry=candidate.world_containers
    if not valid_world(registry):
        return false
    var saved=world_containers
    world_containers=registry
    candidate.version=1
    if not super.restore(candidate,false):
        world_containers=saved
        return false
    for item in items.values():
        item.count=int(item.count)
    for container in world_containers.values():
        container.capacity=int(container.capacity)
    reachable.clear()
    if notify:
        changed.emit()
    return true
