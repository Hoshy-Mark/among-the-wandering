extends "res://staging/e06_world/arroio/loot_pilot/vendor/inventario67.gd"

const FORMS={"water":Vector2i(1,2),"moletom_cinza":Vector2i(2,2),"bag_school":Vector2i(2,2),"bag_canvas":Vector2i(2,3),"bag_hiking":Vector2i(2,3),"baton":Vector2i(1,3)}
var import_grids: Dictionary={}
var import_report: Array=[]
var seeding=true

func capacity(container: String) -> int:
    if container=="pockets" and equipped("pants").is_empty():
        return 0
    if world_containers.has(container) and world_containers[container].kind=="ground":
        return 2147483647
    var grid=dimensions(container)
    return grid.x*grid.y

func ground_at(position: Vector3) -> String:
    var id=super.ground_at(position)
    if not id.is_empty():
        _name_ground(id)
    return id

func _name_ground(id: String) -> void:
    if world_containers[id].name not in ["Itens no chão","Chão"]:
        return
    var names: Array=[]
    for entry in world_containers.values():
        names.append(entry.name)
    var index=0
    while true:
        var number=index
        var suffix=""
        while true:
            suffix=String.chr(65+number%26)+suffix
            number=number/26-1
            if number<0:
                break
        var label="Chão "+suffix
        if label not in names:
            world_containers[id].name=label
            return
        index+=1

func form(definition: String, rotated: bool=false) -> Vector2i:
    var size: Vector2i=FORMS.get(definition,Vector2i.ONE)
    if catalog[definition].has("grid"):
        size=Vector2i(catalog[definition].grid[0],catalog[definition].grid[1])
    elif not FORMS.has(definition):
        var slot: String=catalog[definition].get("slot","")
        size=Vector2i(2,2) if slot=="shirt" else Vector2i(1,2) if slot=="pants" else Vector2i(2,1) if slot=="boots" else Vector2i.ONE
    return Vector2i(size.y,size.x) if rotated else size

func drop_at(uid: String, x: int, y: int, rotated: bool) -> bool:
    if not owned(uid):
        return false
    var registry=world_containers.duplicate(true)
    var access=reachable.duplicate()
    var id=ground_at(actor_position)
    if place(uid,id,x,y,rotated):
        return true
    world_containers=registry
    reachable=access
    return false

func dimensions(container: String, staged: Dictionary={}) -> Vector2i:
    var state=items if staged.is_empty() else staged
    if import_grids.has(container) and not (world_containers.has(container) and world_containers[container].kind=="ground"):
        var value: Array=import_grids[container]
        return Vector2i(int(value[0]),int(value[1]))
    if container=="pockets":
        return Vector2i(3,2)
    if world_containers.has(container):
        if world_containers[container].kind=="ground":
            var rows=4
            for item in state.values():
                if item.location==container and item.has("y"):
                    rows=maxi(rows,int(item.y)+form(item.definition,item.rot).y+1)
            return Vector2i(5,rows)
        if container=="world:crate":
            return Vector2i(6,4)
        var limit=int(world_containers[container].capacity)
        return Vector2i(3,2) if limit==6 else Vector2i(4,3) if limit==12 else Vector2i(4,5) if limit==20 else Vector2i(6,ceili(limit/6.0))
    if state.has(container):
        var limit=int(catalog[state[container].definition].get("capacity",0))
        return Vector2i(4,ceili(limit/4.0))
    return Vector2i.ZERO

func placeable(staged: Dictionary, uid: String, destination: String, x: int, y: int, rotated: bool) -> bool:
    if not staged.has(uid) or destination.begins_with("slot:"):
        return false
    var item: Dictionary=staged[uid]
    if rotated and not bool(catalog[item.definition].get("can_rotate",true)):
        return false
    var shape=form(item.definition,rotated)
    var grid=dimensions(destination,staged)
    var ground=world_containers.has(destination) and world_containers[destination].kind=="ground"
    if x<0 or y<0 or x+shape.x>grid.x or (not ground and y+shape.y>grid.y) or y+shape.y>1024:
        return false
    var target=Rect2i(Vector2i(x,y),shape)
    for other in staged:
        if other==uid or staged[other].location!=destination:
            continue
        var candidate: Dictionary=staged[other]
        if not candidate.has("x") or target.intersects(Rect2i(Vector2i(candidate.x,candidate.y),form(candidate.definition,candidate.rot))):
            return false
    return true

func can_place(uid: String, destination: String, x: int, y: int, rotated: bool) -> bool:
    return can_touch(uid) and accessible(destination) and placeable(items,uid,destination,x,y,rotated)

func preview(uid: String, destination: String, x: int, y: int, rotated: bool, amount: int=0) -> bool:
    if not can_touch(uid) or not accessible(destination):
        return false
    if items[uid].location=="slot:backpack" and not contents(uid).is_empty():
        return false
    var state=items.duplicate(true)
    var target=uid
    if amount>0 and amount<items[uid].count:
        target="preview"
        state[target]=items[uid].duplicate(true)
    return placeable(state,target,destination,x,y,rotated)

func place(uid: String, destination: String, x: int, y: int, rotated: bool, amount: int=0, split_only: bool=false) -> bool:
    message=""
    if not can_touch(uid) or not accessible(destination):
        message="Item fora do alcance"
        return false
    if not items.has(uid) or destination.begins_with("slot:"):
        return false
    var source: Dictionary=items[uid]
    if source.location=="slot:pants" and not contents("pockets").is_empty():
        message="Esvazie os bolsos antes de retirar"
        return false
    var count=int(source.count) if amount==0 else amount
    if count<1 or count>source.count or (split_only and count==source.count):
        message="Quantidade inválida"
        return false
    if source.location=="slot:backpack" and not contents(uid).is_empty():
        message="Esvazie a mochila antes de retirar"
        return false
    var staged=items.duplicate(true)
    var candidate=0
    var target=uid
    if count<source.count:
        candidate=_fresh_id()
        if candidate==0:
            return false
        target="item_%06d"%candidate
        staged[uid].count-=count
        staged[target]=source.duplicate(true)
        staged[target].count=count
    if not placeable(staged,target,destination,x,y,rotated):
        message="Não cabe nesta posição"
        return false
    staged[target].location=destination
    staged[target].x=x
    staged[target].y=y
    staged[target].rot=rotated
    if not _commit(staged,false):
        message="Não é possível guardar a peça aqui"
        return false
    if candidate>0:
        next_id=candidate+1
    changed.emit()
    return true

func rotate(uid: String) -> bool:
    if not can_touch(uid) or str(items[uid].location).begins_with("slot:"):
        return false
    var item: Dictionary=items[uid]
    if not bool(catalog[item.definition].get("can_rotate",true)):
        return false
    if form(item.definition).x==form(item.definition).y:
        return false
    if not place(uid,item.location,item.x,item.y,not item.rot):
        message="Não há espaço para girar. Mova o item primeiro."
        return false
    return true

func equip(uid: String) -> bool:
    if not can_touch(uid):
        message="Item fora do alcance"
        return false
    var source: Dictionary=items[uid]
    var slot: String=catalog[source.definition].get("slot","")
    if slot.is_empty() or str(source.location).begins_with("slot:"):
        return false
    var previous=equipped(slot)
    if slot=="backpack" and not previous.is_empty() and not contents(previous).is_empty():
        message="Esvazie a mochila antes de trocar"
        return false
    var staged=items.duplicate(true)
    staged[uid].location="slot:"+slot
    if not previous.is_empty():
        # The old piece may use exactly the position explicitly vacated by the new one.
        if not placeable(staged,previous,source.location,source.x,source.y,source.rot):
            message="A peça anterior não cabe no espaço da nova"
            return false
        staged[previous].location=source.location
        staged[previous].x=source.x
        staged[previous].y=source.y
        staged[previous].rot=source.rot
    return _commit(staged)

func move(_uid: String, _destination: String) -> bool:
    message="Escolha uma célula de destino"
    return false

func split(_uid: String, _amount: int) -> String:
    message="Escolha uma célula para a nova pilha"
    return ""

func transfer(_uid: String, _destination: String, _amount: int) -> bool:
    message="Escolha uma célula de destino"
    return false

func move_to_ground(_uid: String, _position: Vector3) -> bool:
    message="Escolha uma célula no chão"
    return false

func transfer_to_ground(_uid: String, _amount: int, _position: Vector3) -> bool:
    message="Escolha uma célula no chão"
    return false

func valid(staged: Variant) -> bool:
    if not staged is Dictionary:
        return false
    var equipment: Dictionary={}
    for uid in staged:
        if not uid is String or uid.is_empty() or uid in ["pockets","ground"] or uid.begins_with("world:") or uid.begins_with("slot:") or not staged[uid] is Dictionary:
            return false
        var item: Dictionary=staged[uid]
        if not catalog.has(item.get("definition","")) or not item.get("location") is String:
            return false
        if not (item.get("count") is int or item.get("count") is float) or not is_finite(float(item.count)) or item.count<1 or item.count!=floor(item.count) or item.count>catalog[item.definition].stack:
            return false
        if str(item.location).begins_with("slot:"):
            var slot: String=str(item.location).trim_prefix("slot:")
            if slot not in SLOTS or not fits_equipment(item.definition,slot) or equipment.has(slot):
                return false
            equipment[slot]=uid
            continue
        if item.location=="pockets":
            if not staged.values().any(func(entry):return entry is Dictionary and entry.get("location")=="slot:pants"):
                return false
        elif not world_containers.has(item.location):
            if not staged.has(item.location) or not catalog.has(staged[item.location].get("definition","")) or int(catalog[staged[item.location].definition].get("capacity",0))<=0:
                return false
        if catalog[item.definition].has("capacity") and not world_containers.has(item.location):
            return false
        if not item.get("rot") is bool:
            return false
        if item.rot and not bool(catalog[item.definition].get("can_rotate",true)):
            return false
        for field in ["x","y"]:
            if not (item.get(field) is int or item.get(field) is float) or not is_finite(float(item[field])) or float(item[field])!=floor(float(item[field])):
                return false
        if not placeable(staged,uid,item.location,int(item.x),int(item.y),item.rot):
            return false
    return true

func add(definition: String, count: int, location: String) -> String:
    # Explicit initial layouts only. Runtime loot uses place/add_at, not search-for-space.
    if not seeding:
        message="Informe a posição inicial do item"
        return ""
    var index=contents(location).size()
    var position=Vector2i.ZERO
    if location=="pockets":
        position=[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1)][mini(index,3)]
    elif location=="world:crate":
        position=[Vector2i(0,0),Vector2i(2,0),Vector2i(4,0),Vector2i(0,3)][mini(index,3)]
    elif location=="world:cabinet":
        position=Vector2i(index,0)
    elif world_containers.has(location) and world_containers[location].get("house")=="H01":
        position=Vector2i(index*2,0)
    elif items.has(location):
        position=[Vector2i(0,0),Vector2i(3,0),Vector2i(1,2)][mini(index,2)]
    return add_at(definition,count,location,position.x,position.y,location=="world:crate" and definition=="baton")

func add_at(definition: String, count: int, location: String, x: int, y: int, rotated: bool) -> String:
    if not catalog.has(definition):
        return ""
    var candidate=_fresh_id()
    if candidate==0:
        return ""
    var uid="item_%06d"%candidate
    var staged=items.duplicate(true)
    staged[uid]={"definition":definition,"count":count,"location":location,"x":x,"y":y,"rot":rotated}
    if not _commit(staged,false):
        return ""
    next_id=candidate+1
    changed.emit()
    return uid

func snapshot() -> Dictionary:
    var data=super.snapshot()
    data.version=3
    data.import_grids=import_grids.duplicate(true)
    return data

func restore(data: Variant, notify: bool=true) -> bool:
    if not data is Dictionary:
        return false
    var candidate: Dictionary=data.duplicate(true)
    var old_grids=import_grids.duplicate(true)
    var report: Array=[]
    if candidate.get("version")==3:
        if not candidate.get("import_grids",{}) is Dictionary:
            return false
        import_grids=candidate.get("import_grids",{}).duplicate(true)
    elif candidate.get("version")==1 or candidate.get("version")==2:
        # Old saves have no coordinates. A visible, one-time vertical layout keeps
        # order and every instance, rather than packing or discarding legacy stock.
        var old_model=load("res://staging/e06_world/arroio/loot_pilot/vendor/inventario67.gd").new()
        old_model.house_anchors=house_anchors.duplicate(true)
        if not old_model.restore(candidate,false):
            return false
        candidate=old_model.snapshot()
        import_grids={}
        var rows: Dictionary={}
        for uid in candidate.items:
            var item: Dictionary=candidate.items[uid]
            if str(item.location).begins_with("slot:"):
                continue
            item.x=0
            item.y=int(rows.get(item.location,0))
            item.rot=false
            rows[item.location]=item.y+form(item.definition).y
            report.append({"id":uid,"container":item.location,"x":0,"y":item.y})
        for location in rows:
            import_grids[location]=[4,maxi(4,int(rows[location]))]
    else:
        return false
    for id in import_grids:
        var value: Variant=import_grids[id]
        if not value is Array or value.size()!=2 or not (value[0] is int or value[0] is float) or not (value[1] is int or value[1] is float) or value[0]<1 or value[0]>32 or value[1]<1 or value[1]>1024 or value[0]!=floor(value[0]) or value[1]!=floor(value[1]):
            import_grids=old_grids
            return false
        import_grids[id]=[int(value[0]),int(value[1])]
    candidate.version=2
    if not super.restore(candidate,false):
        import_grids=old_grids
        return false
    for item in items.values():
        if item.has("x"):
            item.x=int(item.x)
            item.y=int(item.y)
    import_report=report
    for id in world_containers:
        if world_containers[id].kind=="ground":
            _name_ground(id)
    if notify:
        changed.emit()
    return true
