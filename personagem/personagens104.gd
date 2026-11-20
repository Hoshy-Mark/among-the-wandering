extends "res://personagem/personagens103.gd"
func _init() -> void:
    encounter_catalog_path99="res://personagem/personagens104.json"
    social_catalog_path101="res://personagem/dialogos104.json"
    social_model_path102="res://personagem/social104.gd"

func _relation_hint101() -> void:
    super._relation_hint101()
    if not active.is_empty() and social.relation(active,"player").trust<0:
        view_d02.relationship_hint.text=view_d02.relationship_hint.text.replace("Confiança: inicial","Confiança: abalada")

func _anchor(raw: Array) -> Variant:
    var guard={}
    for definition in config.encounters.values():
        if definition.candidate==raw:guard=definition.get("anchor_guard104",{});break
    if guard.is_empty():return super._anchor(raw)
    var values=guard.rect;var area=Rect2(values[0],values[1],values[2],values[3])
    var center=Vector3(raw[0],raw[1],raw[2]);var motor=scene.zombie_world.motor
    for radius in [0.0,1.0,2.0,3.0,4.0]:
        for angle in [0,45,90,135,180,225,270,315]:
            var proposed=center+Vector3(cos(deg_to_rad(angle)),0,sin(deg_to_rad(angle)))*radius
            if not area.has_point(Vector2(proposed.x,proposed.z)):continue
            if guard.has("door_x") and absf(proposed.x-float(guard.door_x))<float(guard.clearance):continue
            var point=motor._floor(proposed)
            if point==null or not motor._free(point) or not motor._separated("",point) or point.distance_to(scene.player.global_position)<.65:continue
            if actors.values().any(func(actor):return actor.global_position.distance_to(point)<1.0):continue
            return point
    return null
