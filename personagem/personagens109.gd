extends "res://personagem/personagens106.gd"
var ambient_elapsed109=0.0
var ambient_notice109: Label
var notice_left109=0.0
func _init() -> void:
    encounter_catalog_path99="res://personagem/personagens106.json"
    social_catalog_path101="res://personagem/dialogos109.json"
    social_model_path102="res://personagem/social109.gd"
func setup(root_scene: Node3D) -> void:
    super.setup(root_scene)
    skills_ui.projection=load("res://personagem/projection109.gd");skills_ui.refresh()
    ambient_notice109=Label.new();ambient_notice109.mouse_filter=Control.MOUSE_FILTER_IGNORE;ambient_notice109.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ambient_notice109.add_theme_font_size_override("font_size",13);ambient_notice109.add_theme_color_override("font_color",Color("ddd1b4"));scene.game_ui.add_child(ambient_notice109);ambient_notice109.hide()
func ambient_pair109(source: String,target: String,interaction: String,fact: String="") -> Dictionary:
    if not actors.has(source) or not actors.has(target) or not active.is_empty() or skills_ui.opened:return {"ok":false}
    var a=actors[source];var b=actors[target]
    if not a.visible or not b.visible or a.global_position.distance_to(b.global_position)>4:return {"ok":false}
    var query=PhysicsRayQueryParameters3D.create(a.global_position+Vector3.UP*1.1,b.global_position+Vector3.UP*1.1,3,[a.get_rid()]);var hit=get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty() and hit.collider!=b:return {"ok":false}
    var result=social.transmit109(source,target,fact) if fact!="" else social.interact109(source,target,interaction)
    if result.ok:
        if not result.has("line"):result.line="Conversam sobre um assunto conhecido."
        a.avatar.rotation.y=atan2(b.global_position.x-a.global_position.x,b.global_position.z-a.global_position.z);b.avatar.rotation.y=a.avatar.rotation.y+PI
        # Witnessing a neutral greeting does not disclose private information.
        if scene.player.global_position.distance_to(a.global_position)<8:
            var look=PhysicsRayQueryParameters3D.create(scene.player.global_position+Vector3.UP*1.1,a.global_position+Vector3.UP*1.1,3,[scene.player.get_rid()]);var obstruction=get_world_3d().direct_space_state.intersect_ray(look)
            if obstruction.is_empty() or obstruction.collider==a:
                ambient_notice109.text=(registry.definitions[source].name+" e "+registry.definitions[target].name+": " if registry.met[source] and registry.met[target] else "Duas pessoas: ")+result.line;notice_left109=4;ambient_notice109.show()
    return result
func _process(delta: float) -> void:
    super._process(delta)
    if ambient_notice109==null:return
    var viewport=get_viewport().get_visible_rect().size;ambient_notice109.position=Vector2(20,viewport.y-108);ambient_notice109.size=Vector2(viewport.x-40,24)
    notice_left109-=delta
    if notice_left109<=0:ambient_notice109.hide()
    if not scene.demo_ready or scene.player.paused or scene.player.reaction.is_active() or scene.player.hud_open:return
    ambient_elapsed109+=delta
    if ambient_elapsed109<20:return
    ambient_elapsed109=0
    for exchange in social.rules109.ambient:
        ambient_pair109(exchange.source,exchange.target,exchange.interaction,str(exchange.get("fact","")))
