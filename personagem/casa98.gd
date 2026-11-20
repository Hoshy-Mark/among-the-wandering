extends "res://personagem/casa71.gd"
func setup(owner_scene: Node3D) -> void:
    var controller=owner_scene.city.get_node_or_null("ResidentialInteriors")
    if controller!=null and controller.homes.has("H01"):
        var old=controller.homes.H01
        controller.homes.erase("H01")
        owner_scene.city.static_batcher.restore_tree(old.instance)
        old.instance.get_parent().remove_child(old.instance);old.instance.queue_free()
        if controller.services!=null:
            for id in controller.services.circuits.keys():
                if controller.services.circuits[id].home=="H01":controller.services.circuits.erase(id)
            if controller.services.home_nodes.has("H01"):
                var lamps=controller.services.home_nodes.H01
                if is_instance_valid(lamps):lamps.queue_free()
                controller.services.home_nodes.erase("H01")
    await super.setup(owner_scene)
