extends Node3D
var scene: Node3D
var models: Array=[]
var obstacles: Array=[]
func setup(root_scene: Node3D) -> void:
    scene=root_scene
    models=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/cercamentos78.json")).models
    var registry=scene.player.map_traversals
    var previous=registry.obstacles.duplicate()
    var index=0
    var dressing=scene.city.get_node("UrbanDressing")
    for old in previous:
        if old.kind!="fence":continue
        var model: Dictionary=models[index%6]
        var original=dressing.get_node_or_null("SharedWalls/"+str(old.opening_id))
        if original==null:continue
        original.get_parent().remove_child(original)
        original.queue_free()
        var visual=load("res://personagem/cerca_modelo78.gd").new()
        add_child(visual)
        visual.build(model,old.a,old.b)
        var adapter=load("res://personagem/obstaculo_cerca78.gd").new()
        add_child(adapter)
        adapter.scene=scene
        adapter.kind="fence"
        adapter.model=model
        adapter.opening_id=old.opening_id
        adapter.a=old.a
        adapter.b=old.b
        adapter.ledge_y=old.a.y+float(model.height)
        adapter.set_meta("map77",true)
        adapter.set_meta("fence78",true)
        adapter.locate(scene.player)
        registry.obstacles.erase(old)
        registry.obstacles.append(adapter)
        obstacles.append(adapter)
        old.queue_free()
        index+=1
    scene.player.traversal=load("res://personagem/travessia_cercas78.gd").new()
    scene.player.traversal.setup(scene.player)
