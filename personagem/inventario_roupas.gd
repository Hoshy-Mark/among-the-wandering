extends Node
signal changed
var actor: Node3D
var instances: Dictionary={}
var equipped: Dictionary={"shirt":"","pants":"","boots":"","belt":""}
var next_id:=1

func setup(character: Node3D,grant_starting_items: bool=true) -> void:
    assert(actor==null,"Inventario ja configurado")
    if actor!=null:return
    actor=character
    if not grant_starting_items:
        var profile: Dictionary={}
        for slot in equipped:profile[slot+"_id"]="none"
        var cleared: bool=actor.set_appearance(profile)
        assert(cleared)
        return
    for slot in equipped:
        var definition: String=actor.selection[slot+"_id"]
        if definition=="none":continue
        var uid:=receive(definition)
        var equipped_ok:=equip(uid)
        assert(equipped_ok)

func receive(definition: String,uid: String="",notify: bool=true) -> String:
    if actor.clothing_item(definition).is_empty():return ""
    if uid.is_empty():
        uid="roupa_%06d"%next_id;next_id+=1
        while instances.has(uid):uid="roupa_%06d"%next_id;next_id+=1
    if instances.has(uid):return ""
    instances[uid]={"instance_id":uid,"item_id":definition}
    if notify:changed.emit()
    return uid

func equip(uid: String) -> bool:
    if not instances.has(uid):return false
    var item: Dictionary=actor.clothing_item(instances[uid].item_id)
    var slot: String=item.slot
    if not actor.set_appearance({slot+"_id":item.id}):return false
    equipped[slot]=uid;changed.emit();return true

func unequip(slot: String,notify: bool=true) -> bool:
    if not equipped.has(slot):return false
    if not actor.set_appearance({slot+"_id":"none"}):return false
    equipped[slot]=""
    if notify:changed.emit()
    return true

func release(uid: String,notify: bool=true) -> Dictionary:
    if not instances.has(uid):return {}
    for slot in equipped:
        if equipped[slot]==uid and not unequip(slot,false):return {}
    var item: Dictionary=instances[uid].duplicate(true)
    instances.erase(uid)
    if notify:changed.emit()
    return item

func report() -> Dictionary:
    return {"schema":"ea.clothing.inventory.v1","instances":instances.duplicate(true),"equipped":equipped.duplicate(true),"next_id":next_id}

func load_report(data: Variant,notify: bool=true) -> bool:
    if not data is Dictionary or data.get("schema","")!="ea.clothing.inventory.v1":return false
    if not data.get("instances") is Dictionary or not data.get("equipped") is Dictionary:return false
    if not data.get("next_id") is float and not data.get("next_id") is int:return false
    if not is_finite(float(data.next_id)) or data.next_id<1 or data.next_id!=floor(data.next_id):return false
    if data.equipped.size()!=equipped.size():return false
    var profile: Dictionary={}
    for uid in data.instances:
        if not uid is String or uid.is_empty() or not data.instances[uid] is Dictionary:return false
        var instance: Dictionary=data.instances[uid]
        if instance.get("instance_id")!=uid or not instance.get("item_id") is String or actor.clothing_item(instance.item_id).is_empty():return false
    var used: Dictionary={}
    for slot in equipped:
        if not data.equipped.has(slot) or not data.equipped[slot] is String:return false
        var uid: String=data.equipped[slot]
        profile[slot+"_id"]="none"
        if uid.is_empty():continue
        if not data.instances.has(uid) or used.has(uid):return false
        var item: Dictionary=actor.clothing_item(data.instances[uid].item_id)
        if item.slot!=slot:return false
        used[uid]=true;profile[slot+"_id"]=item.id
    if not actor.set_appearance(profile):return false
    instances=data.instances.duplicate(true);equipped=data.equipped.duplicate(true);next_id=int(data.next_id)
    if notify:changed.emit()
    return true
