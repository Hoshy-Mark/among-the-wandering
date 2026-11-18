extends "res://isometric_base_r62.gd"
var game_ui: Control
var world_items: Node3D

func _ready() -> void:
    await super._ready()
    player.bag_inventory.configure(player.global_position)
    for entry in [["water",1],["food",3],["medicine",2]]:
        player.bag_inventory.add(entry[0],entry[1],"world:cabinet")
    world_items=load("res://personagem/mundo71.gd").new()
    add_child(world_items)
    world_items.setup(player,game_ui)
    var house=load("res://personagem/casa71.gd").new()
    add_child(house)
    await house.setup(self)
    player.update_nearby()
    player.bag_inventory.seeding=false
    var args=OS.get_cmdline_user_args()
    if "--qa-layout" in args:
        for key in house.home.preparation.entries:
            var entry: Dictionary=house.home.preparation.entries[key]
            if key not in ["H01_FURN_PIA_COZ","H01_FURN_ESTANTE_Q2","H01_FURN_DESPENSA"]:
                continue
            for mesh in entry.meshes.values():
                print("LAYOUT ",mesh.name," ",(house.home.model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb())
        get_tree().quit()
        return
    if "--qa-equipment" in args or "--capture-equipment" in args:
        await load("res://personagem/revisao72.gd").new().run(self)
        return
    if "--qa-storage" in args or "--capture-storage" in args:
        await load("res://personagem/revisao71.gd").new().run(self)
        return
    if "--qa-drawers" in args or "--capture-drawers" in args:
        await load("res://personagem/revisao70.gd").new().run(self)
        return
    if "--qa-c05" in args or "--capture-c05" in args:
        await load("res://personagem/revisao68.gd").new().run(self,"--capture-c05" in args)

func _interface() -> void:
    super._interface()
    panel.visible=false
    var layer=CanvasLayer.new()
    layer.layer=20
    add_child(layer)
    game_ui=load("res://personagem/hud68.gd").new()
    layer.add_child(game_ui)
    game_ui.setup(player)
    game_ui.add_to_group("c05_hud")

func _process(delta: float) -> void:
    super._process(delta)
    if game_ui!=null and game_ui.visible:
        var left: bool=game_ui.windows[0].visible
        var right: bool=game_ui.windows[1].visible
        if left or right:
            zoom=4.5
            focus=player.global_position+Vector3.UP*.95
            if left!=right:
                focus+=camera.global_basis.x*(-1.6 if left else 1.6)
            _update_camera()
