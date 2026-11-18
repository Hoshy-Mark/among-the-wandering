extends RefCounted

func run(scene: Node3D, capture: bool=false, finish: bool=true) -> void:
    var body: CharacterBody3D=scene.player
    var model: RefCounted=body.bag_inventory
    var ui: Control=scene.game_ui
    body.scripted=true
    body.set_physics_process(false)
    for fixture in scene.fixtures.values():
        fixture.position.x+=30
    if "training_target" in scene:
        scene.training_target.position.x+=30
        body.global_position=scene.spawn+Vector3(0,.03,-3)
    await scene.get_tree().physics_frame
    var query=PhysicsRayQueryParameters3D.create(body.global_position+Vector3.UP,body.global_position-Vector3.UP,1)
    var hit=body.get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        body.global_position.y=hit.position.y+.01
    var origin=body.global_position
    model.configure(origin)
    model.changed.emit()
    body.update_nearby()
    assert("world:crate" in model.reachable and "world:cabinet" not in model.reachable)
    assert(model.capacity("world:crate")==12 and model.capacity("world:cabinet")==18)
    var original=model.snapshot()
    var health=body.condition_state.snapshot()
    var baton=_find(model,"baton","world:crate")
    var bag: String=model.equipped("backpack")
    var bandage=_find(model,"bandage","pockets")
    ui.container_id="world:crate"
    ui.refresh()
    assert(_listed(ui,"world:crate") and not _listed(ui,"world:cabinet"))
    # Real drop target routes through the player, which rechecks current distance.
    var drop=load("res://personagem/slot63.gd").new()
    drop.hud=ui
    drop.destination=bag
    drop._drop_data(Vector2.ZERO,{"item_uid":baton})
    assert(model.items[baton].location==bag)
    assert(body.move_item(baton,"world:crate"))
    body.global_position=origin+Vector3(-6,0,0)
    body.update_nearby()
    var before=model.snapshot()
    drop._drop_data(Vector2.ZERO,{"item_uid":baton})
    assert(model.snapshot()==before and not body.equip_item(baton))
    assert(not body.move_item(bandage,"world:crate"))
    assert(not _listed(ui,"world:crate"))
    drop.free()
    body.global_position=origin
    body.update_nearby()
    # A solid wall inside the radius blocks access independently of UI selection.
    var wall=StaticBody3D.new()
    var collider=CollisionShape3D.new()
    var shape=BoxShape3D.new()
    shape.size=Vector3(.1,2,2)
    collider.shape=shape
    wall.add_child(collider)
    scene.add_child(wall)
    wall.global_position=origin+Vector3(.55,.7,0)
    await scene.get_tree().physics_frame
    body.update_nearby()
    assert("world:crate" not in model.reachable and not body.equip_item(baton))
    wall.queue_free()
    await scene.get_tree().physics_frame
    body.update_nearby()
    assert("world:crate" in model.reachable)
    body.global_position=origin+Vector3(0,1.5,0)
    body.update_nearby()
    assert("world:crate" not in model.reachable)
    body.global_position=origin
    body.update_nearby()
    # Finite recipient capacity and failed transfers preserve both source and target.
    for index in 12-model.contents("world:crate").size():
        assert(not model.add("water",1,"world:crate").is_empty())
    before=model.snapshot()
    assert(not body.move_item(bandage,"world:crate") and model.snapshot()==before)
    assert(model.restore(original))
    body.update_nearby()
    var large=_find(model,"bag_hiking","world:crate")
    assert(body.equip_item(large))
    var dropped: String=model.items[bag].location
    assert(model.world_containers[dropped].kind=="ground")
    assert(model.point(dropped).distance_to(origin)<.01 and model.contents(bag).size()==3)
    assert(not model.owned(model.contents(bag)[0]))
    assert(model.can_touch(model.contents(bag)[0]))
    body.global_position=origin+Vector3(-6,0,0)
    body.update_nearby()
    before=model.snapshot()
    assert(not body.move_item(model.contents(bag)[0],"pockets"))
    assert(not body.equip_item(bag) and model.snapshot()==before)
    assert(not _listed(ui,bag))
    body.global_position=model.point("world:cabinet")+Vector3(-.9,0,0)
    body.update_nearby()
    assert("world:cabinet" in model.reachable and "world:crate" not in model.reachable)
    var water=_find(model,"water","world:cabinet")
    assert(body.move_item(water,large))
    assert(model.owned(water))
    # Ground drops stay where they were released, including after a save and load.
    assert(body.move_item(water,"ground"))
    var second_drop: String=model.items[water].location
    assert(second_drop!=dropped and model.point(second_drop).distance_to(body.global_position)<.01)
    body.condition_path="user://qa_profile64.json"
    assert(body.save_condition())
    var saved=model.snapshot()
    assert(body.move_item(water,large))
    assert(body.load_condition())
    assert(model.items==saved.items and model.next_id==saved.next_id)
    assert(model.world_containers.size()==saved.world_containers.size())
    for id in saved.world_containers:
        var expected: Array=saved.world_containers[id].position
        assert(model.point(id).distance_to(Vector3(expected[0],expected[1],expected[2]))<.00001)
        assert(model.world_containers[id].name==saved.world_containers[id].name)
        assert(model.world_containers[id].capacity==saved.world_containers[id].capacity)
    var invalid=saved.duplicate(true)
    invalid.world_containers[second_drop].position[0]="invalid"
    before=model.snapshot()
    assert(not model.restore(invalid) and model.snapshot()==before)
    var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(body.condition_path))
    data.inventory=invalid
    FileAccess.open(body.condition_path,FileAccess.WRITE).store_string(JSON.stringify(data))
    assert(not body.load_condition() and model.snapshot()==before and body.condition_state.snapshot()==health)
    # R63 profiles retain item IDs, quantities and bag contents during migration.
    var legacy=original.duplicate(true)
    legacy.version=1
    legacy.erase("world_containers")
    for item in legacy.items.values():
        if str(item.location).begins_with("world:"):
            item.location="ground"
    var shadow=load("res://personagem/inventario64.gd").new()
    assert(shadow.restore(legacy) and shadow.items.size()==original.items.size())
    # Consumables still resolve at the existing animation effect marker.
    assert(model.restore(original))
    body.global_position=origin
    body.update_nearby()
    assert(body.receive_zone_damage("world64_care","forearm_left","cut",.4))
    body.reaction.advance(2)
    assert(body.use_item(bandage))
    body.action.advance(.1)
    body.action.cancel()
    assert(model.items[bandage].count==3)
    assert(body.use_item(bandage))
    body.action.advance(10)
    assert(model.items[bandage].count==2 and body.condition_state.forearm_dressed)
    body.action.cancel()
    body.reaction.reset()
    body.condition_state.restore(health)
    body.body_health.records.clear()
    model.restore(original)
    body.update_nearby()
    scene.world_items.refresh()
    if capture:
        for view in ["crate","cabinet","ground","away"]:
            body.global_position=origin
            ui.container_id="world:crate"
            if view=="cabinet":
                body.global_position=model.point("world:cabinet")+Vector3(-.9,0,0)
                ui.container_id="world:cabinet"
            elif view=="ground":
                body.update_nearby()
                assert(body.equip_item(large))
                ui.container_id=model.items[bag].location
            elif view=="away":
                body.global_position=origin+Vector3(-4,0,0)
                ui.container_id=large
            body.update_nearby()
            ui.refresh()
            ui.feedback.text="Mochila anterior preserva seu conteúdo." if view=="ground" else "Apenas o inventário pessoal está ao alcance." if view=="away" else "Selecione uma pilha e mova para os bolsos ou a mochila."
            for frame in 6:
                await scene.get_tree().process_frame
            await RenderingServer.frame_post_draw
            DirAccess.make_dir_recursive_absolute("res://previews/world64")
            scene.get_viewport().get_texture().get_image().save_png("res://previews/world64/"+view+".png")
    FileAccess.open("res://qa/world64_capture.json" if capture else "res://qa/world64.json",FileAccess.WRITE).store_string(JSON.stringify({"distance":true,"wall":true,"height":true,"stale_drag":true,"container_capacity":true,"bag_contents_preserved":true,"drop_position":true,"save_load":true,"invalid_load_atomic":true,"legacy_migration":true,"care_regression":true},"  "))
    print("R64_WORLD_OK")
    if finish:
        scene.get_tree().quit()

func _find(model: RefCounted, definition: String, location: String) -> String:
    for uid in model.items:
        if model.items[uid].definition==definition and model.items[uid].location==location:
            return uid
    return ""

func _listed(ui: Control, id: String) -> bool:
    for index in ui.containers.item_count:
        if ui.containers.get_item_metadata(index)==id:
            return true
    return false
