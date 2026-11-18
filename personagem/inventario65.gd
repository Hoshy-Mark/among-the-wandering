extends "res://personagem/inventario64.gd"

func _fresh_id() -> int:
    var candidate=next_id
    while candidate<2147483647 and items.has("item_%06d"%candidate):
        candidate+=1
    return candidate if candidate<2147483647 else 0

func split(uid: String, amount: int) -> String:
    message=""
    if not can_touch(uid):
        message="Item fora de alcance"
        return ""
    var source: Dictionary=items[uid]
    if amount<1 or amount>=source.count or str(source.location).begins_with("slot:"):
        message="Escolha uma quantidade menor que a pilha"
        return ""
    var candidate=_fresh_id()
    if candidate==0:
        message="Limite de identificadores atingido"
        return ""
    var created="item_%06d"%candidate
    var staged=items.duplicate(true)
    staged[uid].count-=amount
    staged[created]={"definition":source.definition,"count":amount,"location":source.location}
    if not _commit(staged,false):
        return ""
    next_id=candidate+1
    message="Pilha dividida"
    changed.emit()
    return created

func merge(uid: String, target: String, amount: int) -> bool:
    message=""
    if uid==target or not can_touch(uid) or not can_touch(target):
        message="Selecione duas pilhas acessíveis"
        return false
    var source: Dictionary=items[uid]
    var other: Dictionary=items[target]
    if source.definition!=other.definition or amount<1 or amount>source.count:
        message="As pilhas precisam conter o mesmo item"
        return false
    var room=int(catalog[source.definition].stack)-int(other.count)
    if room<=0 or int(catalog[source.definition].stack)<2:
        message="A pilha de destino está completa"
        return false
    var moved=mini(amount,room)
    var staged=items.duplicate(true)
    staged[target].count+=moved
    staged[uid].count-=moved
    if staged[uid].count==0:
        staged.erase(uid)
    if not _commit(staged,false):
        return false
    message="%d unidade(s) unida(s)"%moved
    changed.emit()
    return true

func transfer(uid: String, destination: String, amount: int) -> bool:
    message=""
    if not can_touch(uid) or not accessible(destination) or destination.begins_with("slot:"):
        message="Aproxime-se do recipiente ou item"
        return false
    var source: Dictionary=items[uid]
    if amount<1 or amount>source.count or destination==source.location:
        message="Escolha outro destino e uma quantidade válida"
        return false
    var staged=items.duplicate(true)
    var remainder=amount
    var limit=int(catalog[source.definition].stack)
    for target in contents(destination):
        if staged[target].definition==source.definition and limit>1:
            var moved=mini(remainder,limit-int(staged[target].count))
            staged[target].count+=moved
            remainder-=moved
            if remainder==0:
                break
    var whole=amount==source.count
    if whole:
        staged.erase(uid)
    else:
        staged[uid].count-=amount
    var candidate=0
    if remainder>0:
        var target=uid
        if not whole:
            candidate=_fresh_id()
            if candidate==0:
                message="Limite de identificadores atingido"
                return false
            target="item_%06d"%candidate
        staged[target]={"definition":source.definition,"count":remainder,"location":destination}
    if not _commit(staged,false):
        return false
    if candidate>0:
        next_id=candidate+1
    message="%d unidade(s) movida(s)"%amount
    changed.emit()
    return true

func move(uid: String, destination: String) -> bool:
    return transfer(uid,destination,int(items[uid].count)) if items.has(uid) else false

func transfer_to_ground(uid: String, amount: int, position: Vector3) -> bool:
    if not can_touch(uid):
        message="Item fora de alcance"
        return false
    var saved=world_containers.duplicate(true)
    var access=reachable.duplicate()
    var id=ground_at(position)
    if transfer(uid,id,amount):
        return true
    world_containers=saved
    reachable=access
    return false
