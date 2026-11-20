extends RefCounted
var scene: Node3D
var regions=load("res://personagem/regioes_tiro91.gd").new()
func trace(origin: Vector3,end: Vector3) -> Dictionary:
    var vector=end-origin;var reach=vector.length()
    if reach<.000001:return {"position":origin,"normal":Vector3.UP,"collider":null,"zone":"","distance":0.0}
    var direction=vector/reach;var exclude: Array[RID]=[scene.player.get_rid()]
    if scene.zombie_world!=null:
        for actor in scene.zombie_world.actors.values():
            if actor.has_method("hit_regions91"):exclude.append(actor.get_rid())
    var query=PhysicsRayQueryParameters3D.create(origin,end,3,exclude);query.hit_from_inside=true
    var world=scene.get_world_3d().direct_space_state.intersect_ray(query)
    var result={"position":end,"normal":-direction,"collider":null,"zone":"","distance":reach}
    if not world.is_empty():result=world;result.zone="";result.distance=origin.distance_to(world.position)
    for actor in scene.get_tree().get_nodes_in_group("combat_receivers79"):
        if not actor.has_method("hit_regions91"):continue
        var hit=regions.intersect(origin,direction,minf(reach,float(result.distance)),actor.hit_regions91())
        if not hit.is_empty() and float(hit.distance)<float(result.distance)-.00001:
            result=hit;result.collider=actor
    return result
