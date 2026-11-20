extends "res://staging/e06_world/arroio/loot_pilot/vendor/inventario65.gd"

var opened: Array[String]=[]

func is_open(id: String) -> bool:
    return world_containers.has(id) and (world_containers[id].kind=="ground" or id in opened)

func set_open(id: String, value: bool) -> bool:
    if not world_containers.has(id) or world_containers[id].kind=="ground":
        return false
    if value and id not in reachable:
        return false
    if value and id not in opened:
        opened.append(id)
    elif not value:
        opened.erase(id)
    changed.emit()
    return true

func accessible(location: String) -> bool:
    if world_containers.has(location):
        return location in reachable and is_open(location)
    if items.has(location):
        var owner: String=items[location].location
        return owner=="slot:backpack" or (owner in reachable and is_open(owner))
    return super.accessible(location)

func restore(data: Variant, notify: bool=true) -> bool:
    if not super.restore(data,false):
        return false
    opened.clear()
    if notify:
        changed.emit()
    return true
