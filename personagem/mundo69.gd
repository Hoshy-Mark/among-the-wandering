extends "res://personagem/mundo68.gd"
var chosen_drawer: Dictionary={}
func _pose(id: String) -> void:
    if house!=null and house.bindings.has(id):
        var data: Dictionary=house.groups[house.bindings[id]]
        if data.has("drawers"):
            var part: Dictionary=data.drawers[id]
            if not house.apply_drawer(id,smoothstep(0,1,float(progress.get(id,0)))):
                # Preserve the last safe pose until the obstruction leaves.
                progress[id]=_inverse_ease(part.fraction)
            return
    super._pose(id)

func _inverse_ease(value: float) -> float:
    var low=0.0
    var high=1.0
    for step in 16:
        var mid=(low+high)/2
        if smoothstep(0,1,mid)<value:
            low=mid
        else:
            high=mid
    return (low+high)/2

func _update_prompt() -> void:
    super._update_prompt()
    if house==null or not house.bindings.has(nearest_id):
        return
    var group: String=house.bindings[nearest_id]
    var data: Dictionary=house.groups[group]
    if not data.has("drawers"):
        return
    var ids: Array=data.drawers.keys()
    nearest_id=str(ids[int(chosen_drawer.get(group,0))%ids.size()])
    if active_id in ids:
        nearest_id=active_id
    elif pending_id in ids:
        nearest_id=pending_id
    prompt.text=("E · Fechar" if has_interaction() else "E · Abrir · J · Escolher gaveta")+"\n"+str(player.bag_inventory.world_containers[nearest_id].name)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_J and not has_interaction() and house!=null and house.bindings.has(nearest_id):
        var group: String=house.bindings[nearest_id]
        if house.groups[group].has("drawers"):
            chosen_drawer[group]=int(chosen_drawer.get(group,0))+1
            _update_prompt()
            get_viewport().set_input_as_handled()
            return
    super._unhandled_input(event)
