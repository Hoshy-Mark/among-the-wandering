extends "res://staging/e06_world/arroio/loot_pilot/vendor/inventario69.gd"
## Stable view object for the unmodified approved HUD. Mutations go through the durable state adapter.
var pilot:Node
var reserved_uid="pilot_pickup_EST05_OBJ_01"
var reserved_container="world:pilot_reserved_EST05_OBJ_01"
func sync_from_state(notify:bool=true):
	var source:RefCounted=pilot.state.inventory;catalog=source.catalog.duplicate(true);house_anchors=source.house_anchors.duplicate(true);restore(source.snapshot(),false);seeding=false
	refresh_access(false)
	if notify:changed.emit()
func refresh_access(notify:bool=true):
	var ids:Array[String]=[]
	for id in pilot.state.descriptors:
		if pilot.state.ledger.has(id) and pilot.check_access(id,"search").is_empty():ids.append("world:"+str(id))
	for id in world_containers.keys():
		if str(id).begins_with("world:drop:") and pilot.check_access("@ground:"+str(id),"search").is_empty():ids.append(id)
	items.erase(reserved_uid);world_containers.erase(reserved_container)
	if not pilot.state.claimed.has("EST05_OBJ_01") and pilot.check_access("EST05_MEC05","pickup").is_empty():
		var p:Vector3=pilot.targets.EST05_MEC05.pickup_point;world_containers[reserved_container]={"name":"Objeto na bancada","kind":"crate","capacity":1,"position":[p.x,p.y,p.z]};import_grids[reserved_container]=[1,1];items[reserved_uid]={"definition":"filtro_oleo","count":1,"location":reserved_container,"x":0,"y":0,"rot":false};ids.append(reserved_container)
	else:import_grids.erase(reserved_container)
	var dirty:bool=reachable!=ids or opened!=ids;reachable=ids;opened=ids.duplicate();actor_position=pilot.actor.global_position
	if dirty and notify:access_changed.emit()
