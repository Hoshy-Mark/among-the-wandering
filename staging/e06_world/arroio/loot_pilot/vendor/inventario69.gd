extends "res://staging/e06_world/arroio/loot_pilot/vendor/inventario68.gd"
func dimensions(container: String, staged: Dictionary={}) -> Vector2i:
    if world_containers.has(container) and world_containers[container].get("drawer",false):
        return Vector2i(4,2)
    return super.dimensions(container,staged)

func set_open(id: String, value: bool) -> bool:
    if world_containers.has(id) and world_containers[id].get("drawer",false):
        if value and id not in reachable:
            return false
        if value and id not in opened:
            opened.append(id)
        elif not value:
            opened.erase(id)
        changed.emit()
        return true
    return super.set_open(id,value)
