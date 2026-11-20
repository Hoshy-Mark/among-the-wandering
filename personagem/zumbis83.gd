extends "res://personagem/zumbis82.gd"
func setup(root_scene: Node3D) -> void:
    scene=root_scene
    var config=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/zumbis82.json"))
    for definition in config.actors:
        var raw=definition.local
        var point=scene.world_items.house.home.model.to_global(Vector3(raw[0],raw[1],raw[2]))
        var found=false
        for offset in [Vector3.ZERO,Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,1),Vector3(0,0,-1)]:
            var floor_query=PhysicsRayQueryParameters3D.create(point+offset+Vector3.UP*2,point+offset-Vector3.UP*2,1)
            var floor=get_world_3d().direct_space_state.intersect_ray(floor_query)
            if floor.is_empty():continue
            var candidate: Vector3=floor.position+Vector3.UP*.02
            if candidate.distance_to(scene.player.global_position)<7 or not scene.world_items.house.standing_clear(candidate):continue
            point=candidate;found=true;break
        assert(found,"No safe zombie spawn "+definition.id)
        if not found:continue
        var actor=_make_actor()
        add_child(actor);actor.setup(scene,definition);actor.global_position=point
        actors[definition.id]=actor
        initial[definition.id]=actor.snapshot()
func settled() -> bool:
    for actor in actors.values():
        if actor.crossing.is_active() or actor.state in ["attack","hit","dying","crossing"]:return false
    return true

func _make_actor() -> CharacterBody3D:
    return load("res://personagem/zumbi83.gd").new()
