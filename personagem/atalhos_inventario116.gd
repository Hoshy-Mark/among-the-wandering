extends RefCounted
## Choose a free destination for the requested item; never repack existing items.
var player: CharacterBody3D
func pickup(uid: String) -> bool:
    var model=player.bag_inventory
    if player.paused or not player._stack_action_ready():return false
    if not model.can_touch(uid):player.inventory_message="Item fora do alcance";return false
    if model.owned(uid):player.inventory_message="O item já está com você";return false
    var destination=model.equipped("backpack")
    if destination.is_empty():destination="pockets"
    var size=model.dimensions(destination)
    var orientation=bool(model.items[uid].get("rot",false))
    for rotated in [orientation,not orientation]:
        for y in size.y:
            for x in size.x:
                if model.preview(uid,destination,x,y,rotated):return player.place_item(uid,destination,x,y,rotated)
    player.inventory_message="Sem espaço livre na mochila" if destination!="pockets" else "Sem mochila e sem espaço livre nos bolsos"
    return false
