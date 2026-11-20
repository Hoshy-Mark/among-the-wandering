extends "res://personagem/personagens102.gd"
func _init() -> void:
    encounter_catalog_path99="res://personagem/personagens103.json"
    social_catalog_path101="res://personagem/dialogos103.json"
    social_model_path102="res://personagem/social103.gd"

func _anchor(raw: Array) -> Variant:
    var frontage=false
    for definition in config.encounters.values():
        if definition.candidate==raw and definition.public_space=="EST01_frontage":frontage=true;break
    if not frontage:return super._anchor(raw)
    var center=Vector3(raw[0],raw[1],raw[2]);var motor=scene.zombie_world.motor
    # Candidate encounters stay outside the church, away from its entry route.
    for radius in [0.0,1.0,2.0,3.0,4.0]:
        for angle in [0,45,90,135,180,225,270,315]:
            var proposed=center+Vector3(cos(deg_to_rad(angle)),0,sin(deg_to_rad(angle)))*radius
            if not Rect2(320,154,24,9).has_point(Vector2(proposed.x,proposed.z)) or absf(proposed.x-332)<2.5:continue
            var point=motor._floor(proposed)
            if point==null or not motor._free(point) or not motor._separated("",point) or point.distance_to(scene.player.global_position)<.65:continue
            if actors.values().any(func(actor):return actor.global_position.distance_to(point)<1.0):continue
            return point
    return null
