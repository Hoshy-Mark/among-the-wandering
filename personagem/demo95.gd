extends Node3D
var scene: Node3D
var balance: Dictionary
var baseline=0.0
var grace=0.0
var state="alive"
var fallback=false
var deaths=0
var layer: CanvasLayer
var shade: ColorRect
var card: PanelContainer
var headline: Label
var detail: Label
var meter: Label
var resume_button: Button
var new_button: Button
var shade_amount=0.0
func setup(root_scene: Node3D) -> void:
    scene=root_scene;balance=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/demo_balance95.json"))
    scene.player.reaction.died.connect(_died)
    meter=Label.new();meter.add_theme_font_size_override("font_size",16);meter.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.game_ui.add_child(meter)
    scene.get_viewport().size_changed.connect(_layout)
    layer=CanvasLayer.new();layer.layer=80;add_child(layer)
    shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0,0,0,0);shade.mouse_filter=Control.MOUSE_FILTER_STOP;layer.add_child(shade)
    var center=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);center.mouse_filter=Control.MOUSE_FILTER_IGNORE;shade.add_child(center)
    card=PanelContainer.new();card.custom_minimum_size=Vector2(440,310);center.add_child(card)
    var style=StyleBoxFlat.new();style.bg_color=Color("1b2924");style.set_content_margin_all(26);style.set_corner_radius_all(12);card.add_theme_stylebox_override("panel",style)
    var column=VBoxContainer.new();column.add_theme_constant_override("separation",14);card.add_child(column)
    headline=Label.new();headline.text="Você morreu";headline.add_theme_font_size_override("font_size",32);headline.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;column.add_child(headline)
    detail=Label.new();detail.text="O último save permanece intacto.";detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(detail)
    resume_button=Button.new();resume_button.text="Retomar último save";resume_button.custom_minimum_size.y=48;resume_button.pressed.connect(request_resume);column.add_child(resume_button)
    new_button=Button.new();new_button.text="Nova tentativa · do início";new_button.custom_minimum_size.y=48;new_button.pressed.connect(request_new);column.add_child(new_button)
    shade.visible=false;process_priority=200;process_physics_priority=200;_layout();refresh()
func _layout() -> void:
    if scene==null:return
    var size=scene.get_viewport().get_visible_rect().size
    meter.position=Vector2(maxf(12,size.x-250),18)
    if card!=null:card.custom_minimum_size=Vector2(minf(440,size.x-20),310)
func raw_damage() -> float:
    var total=0.0
    for entry in scene.player.body_health.records.values():total+=float(entry.severity)
    return total
func integrity() -> float:return clampf(100*(1-(raw_damage()-baseline)*float(balance.damage_scale)),0,100)
func refresh() -> void:
    if scene==null:return
    var value=integrity();meter.text="Integridade %.0f/100"%value
    meter.modulate=Color("f2b18f") if value<=float(balance.critical_integrity) else Color("dbe6da")
func accepted_damage() -> void:
    if state!="alive":return
    grace=float(balance.impact_grace_seconds);refresh()
    if integrity()<=.00001:_begin_defeat()
func can_fall() -> bool:
    var p=scene.player
    if not p.can_fall():return false
    var query=PhysicsShapeQueryParameters3D.new();var box=BoxShape3D.new();box.size=Vector3(.90,1.90,2.30)
    query.shape=box;query.transform=Transform3D(p.avatar.global_basis,p.global_position+p.avatar.global_basis*Vector3(0,.98,-.90));query.exclude=[p.get_rid()];query.collision_mask=3
    return scene.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func _begin_defeat() -> void:
    if state!="alive":return
    state="dying";deaths+=1;var p=scene.player
    p.shoulder.set_aim(false);p.locomotion.cancel();p.velocity=Vector3.ZERO;p.map_combat.pending_reaction=""
    p.action.cancel();p.combat.set_guard(false);p.flow.queue.clear();scene.game_ui.cancel_pending();scene.world_items.close_interaction()
    scene.game_ui.personal.visible=false;scene.game_ui.nearby.visible=false;scene.game_ui.nearby_wanted=false;scene.game_ui.windows[1].visible=false;p.set_hud_open(false)
    for actor in scene.zombie_world.actors.values():actor.ai_enabled=false;actor.velocity=Vector3.ZERO
    scene.zombie_world.navigation.set_physics_process(false)
    shade.visible=true;card.visible=false;resume_button.disabled=true;new_button.disabled=true
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    if p.traversal.is_active():
        state="ending_traversal";p.traversal.cancel();return
    _presentation95()
func _presentation95() -> void:
    var p=scene.player;state="dying";p.reaction.reset();fallback=not can_fall()
    if not fallback and p.reaction.begin("death"):return
    fallback=true;p.avatar.set_motion("idle");p.avatar.motion_blend=1;p.avatar.motion_clock=0;p.avatar.motion_rate=0;p.avatar.advance(0)
    p.action.control_locked=true;p.combat.control_locked=true;_died()
func _died() -> void:
    if state!="dying":return
    state="defeated";scene.player.paused=true;scene.player.velocity=Vector3.ZERO
    scene.player.shoulder.set_aim(false);scene.player.shoulder.advance(1)
    card.visible=true;resume_button.disabled=not can_resume();new_button.disabled=false
    detail.text="Nenhum save válido encontrado. Comece uma nova tentativa." if resume_button.disabled else "O último save permanece intacto."
    _layout()
func advance(delta: float) -> void:
    if not is_finite(delta) or delta<0 or scene==null:return
    grace=maxf(0,grace-delta);refresh()
    if state=="ending_traversal" and not scene.player.traversal.is_active():_presentation95()
    if state=="alive" and integrity()<=.00001 and not scene.player.session_save.working:_begin_defeat()
    if state!="alive":
        shade_amount=move_toward(shade_amount,.72,delta*.8);shade.color=Color(0,0,0,shade_amount)
        scene.player.weapons.visual.visible=false;scene.player.weapons.presentation.magazine.visible=false
func _physics_process(delta: float) -> void:advance(delta)
func can_resume() -> bool:
    var p=scene.player;var service=p.session_save
    var prepared=service.prepare(service._read(p.condition_path),false)
    if not prepared.is_empty():return true
    return service.reason=="invalid" and not service.prepare(service._read(p.condition_path+".bak"),false).is_empty()
func request_resume() -> bool:
    if state not in ["defeated","resume_error"] or not can_resume():return false
    return _reload(false)
func request_new() -> bool:
    if state not in ["defeated","resume_error"]:return false
    return _reload(true)
func _reload(fresh: bool) -> bool:
    var tree=get_tree();state="restarting";resume_button.disabled=true;new_button.disabled=true
    tree.set_meta("demo95_fresh",fresh);tree.set_meta("demo95_resume",not fresh)
    call_deferred("_reload_now95");return true
func _reload_now95() -> void:
    var tree=get_tree();var error=tree.reload_current_scene()
    if error==OK:return
    if tree.has_meta("demo95_fresh"):tree.remove_meta("demo95_fresh")
    if tree.has_meta("demo95_resume"):tree.remove_meta("demo95_resume")
    load_failure("Não foi possível recarregar a cena")
func load_failure(message: String) -> void:
    state="resume_error";scene.player.paused=true
    for actor in scene.zombie_world.actors.values():actor.ai_enabled=false
    scene.zombie_world.navigation.set_physics_process(false)
    shade.visible=true;shade_amount=.72;shade.color=Color(0,0,0,.72);card.visible=true
    headline.text="Não foi possível retomar";detail.text=message;resume_button.disabled=not can_resume();new_button.disabled=false;_layout()
