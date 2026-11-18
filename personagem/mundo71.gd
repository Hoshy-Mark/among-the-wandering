extends "res://personagem/mundo69.gd"
func _pose(id: String) -> void:
    if house!=null and house.bindings.has(id):
        var group: String=house.bindings[id]
        var data: Dictionary=house.groups[group]
        if data.role=="sink_cabinet":
            if not house.apply_sink(group,smoothstep(0,1,float(progress.get(id,0)))):
                progress[id]=_inverse_ease(data.parts[0].fraction)
            return
    super._pose(id)

func _update_prompt() -> void:
    super._update_prompt()
    if house!=null and house.bindings.has(nearest_id):
        var data: Dictionary=house.groups[house.bindings[nearest_id]]
        if data.role=="shelf":
            prompt.text=("E · Fechar" if has_interaction() else "E · Acessar")+"\n"+str(player.bag_inventory.world_containers[nearest_id].name)
