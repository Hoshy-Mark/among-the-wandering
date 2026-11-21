extends RefCounted
signal changed

const SLOTS=["shirt","pants","boots","belt","backpack","main_hand","quick_left","quick_up","quick_right","quick_down"]
var catalog: Dictionary
var items: Dictionary={}
var next_id=1
var message=""

func _init() -> void:
    catalog=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/itens63.json"))
    if FileAccess.file_exists("res://personagem/map117/items.json"):
        catalog.merge(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/map117/items.json")),false)
    if FileAccess.file_exists("res://personagem/armas92.json"):
        catalog.merge(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/armas92.json")).items,true)
    if FileAccess.file_exists("res://personagem/armas87.json"):
        var firearms=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/armas87.json"))
        catalog.merge(firearms.items,true)
    if FileAccess.file_exists("res://personagem/armas86.json"):
        var extra=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/armas86.json"))
        catalog.merge(extra.items,true)

func equipped(slot: String) -> String:
    for uid in items:
        if items[uid].location=="slot:"+slot:
            return uid
    return ""

func capacity(container: String) -> int:
    if container=="ground":
        return 999
    if container=="pockets":
        return 0 if equipped("pants").is_empty() else 6
    if items.has(container):
        return int(catalog[items[container].definition].get("capacity",0))
    return 0

func contents(container: String) -> Array:
    return items.keys().filter(func(uid): return items[uid].location==container)

func owned(uid: String) -> bool:
    if not items.has(uid):
        return false
    var location: String=items[uid].location
    if location=="pockets" or location.begins_with("slot:"):
        return true
    return items.has(location) and items[location].location=="slot:backpack"

func add(definition: String, count: int, location: String) -> String:
    if not catalog.has(definition) or count<1 or count>catalog[definition].stack:
        return ""
    if next_id>=2147483647:
        return ""
    var candidate_id=next_id
    var uid="item_%06d"%candidate_id
    while items.has(uid):
        candidate_id+=1
        if candidate_id>=2147483647:
            return ""
        uid="item_%06d"%candidate_id
    var staged=items.duplicate(true)
    staged[uid]={"definition":definition,"count":count,"location":location}
    if not valid(staged):
        message="Destino sem espaço ou incompatível"
        return ""
    items=staged
    next_id=candidate_id+1
    changed.emit()
    return uid

func move(uid: String, destination: String) -> bool:
    if not items.has(uid) or destination.begins_with("slot:"):
        return false
    var staged=items.duplicate(true)
    staged[uid].location=destination
    return _commit(staged)

func equip(uid: String) -> bool:
    if not items.has(uid):
        return false
    var slot: String=catalog[items[uid].definition].get("slot","")
    if slot.is_empty():
        return false
    var previous=equipped(slot)
    var source: String=items[uid].location
    var staged=items.duplicate(true)
    staged[uid].location="slot:"+slot
    if not previous.is_empty() and previous!=uid:
        staged[previous].location="ground" if slot=="backpack" else source
    return _commit(staged)

func consume(uid: String, count: int, expected: int, notify: bool=true) -> bool:
    if not owned(uid) or count<1 or items[uid].count!=expected or expected<count:
        return false
    var staged=items.duplicate(true)
    staged[uid].count-=count
    if staged[uid].count==0:
        staged.erase(uid)
    return _commit(staged,notify)

func _commit(staged: Dictionary, notify: bool=true) -> bool:
    if not valid(staged):
        message="Destino sem espaço ou incompatível"
        if not staged.values().any(func(item):return item is Dictionary and item.get("location")=="slot:pants") and not contents("pockets").is_empty():
            message="Esvazie os bolsos antes de retirar a calça"
        return false
    items=staged
    message="Inventário atualizado"
    if notify:
        changed.emit()
    return true

func valid(staged: Variant) -> bool:
    if not staged is Dictionary:
        return false
    var used: Dictionary={}
    for uid in staged:
        if not uid is String or uid.is_empty() or not staged[uid] is Dictionary:
            return false
        if uid in ["pockets","ground"] or uid.begins_with("slot:"):
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
            var limit=6 if location=="pockets" else 999 if location=="ground" else 0
            if location=="pockets" and not staged.values().any(func(entry):return entry is Dictionary and entry.get("location")=="slot:pants"):
                limit=0
            if staged.has(location):
                var bag: Dictionary=staged[location]
                if not bag.get("definition") is String or not catalog.has(bag.definition):
                    return false
                limit=int(catalog[bag.definition].get("capacity",0))
                if definition.has("capacity"):
                    return false
            if definition.has("capacity") and location!="ground":
                return false
            if limit<=0:
                return false
            used[location]=int(used.get(location,0))+1
            if used[location]>limit:
                return false
    return true

func snapshot() -> Dictionary:
    return {"version":1,"items":items.duplicate(true),"next_id":next_id}

func restore(data: Variant, notify: bool=true) -> bool:
    if not data is Dictionary or data.get("version")!=1 or not valid(data.get("items")):
        return false
    if not (data.get("next_id") is float or data.get("next_id") is int) or not is_finite(float(data.next_id)) or data.next_id<1 or data.next_id>2147483647 or data.next_id!=floor(data.next_id):
        return false
    items=data.items.duplicate(true)
    next_id=int(data.next_id)
    if notify:
        changed.emit()
    return true

func quick_category(uid: String) -> String:
    if not items.has(uid):return ""
    return quick_definition(str(items[uid].definition))
func quick_definition(id: String) -> String:
    if not catalog.has(id):return ""
    var data: Dictionary=catalog[id];var weapon=data.get("weapon",{})
    if data.get("throwable",false) or weapon.get("type","")=="throwable":return "down"
    if weapon.get("type","")=="firearm":return "up" if weapon.get("pose","")=="long" else "left"
    if not weapon.is_empty() and data.get("slot","")=="main_hand":return "right"
    return ""
func fits_equipment(id: String,slot: String) -> bool:
    if slot.begins_with("quick_"):return quick_definition(id)==slot.trim_prefix("quick_") and not quick_definition(id).is_empty()
    return catalog[id].get("slot","")==slot
