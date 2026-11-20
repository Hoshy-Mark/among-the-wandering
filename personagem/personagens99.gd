extends Node3D
const RANGE=2.3
var scene: Node3D
var registry=load("res://personagem/registro_personagens99.gd").new()
var config={}
var actors={}
var active=""
var panel: PanelContainer
var speaker: Label
var speech: Label
var prompt: Label
var options: BoxContainer
var nearest=""
var initial_body_records={}
var encounter_catalog_path99="res://personagem/personagens99.json"

func setup(root_scene: Node3D) -> void:
    scene=root_scene;process_priority=80
    config=JSON.parse_string(FileAccess.get_file_as_string(encounter_catalog_path99))
    if not registry.configure(config):push_error("Invalid character registry");return
    _interface()
    for id in config.encounters:
        var definition=config.encounters[id];var point=_anchor(definition.candidate)
        if point==null:push_warning("Character encounter has no safe anchor: "+id);continue
        var actor=load("res://personagem/humano99.gd").new();add_child(actor);actor.setup(self,id,definition,point);actors[id]=actor
    scene.player.reaction.started.connect(func(_kind):close())
    get_window().focus_exited.connect(close)

func _anchor(raw: Array) -> Variant:
    var center=Vector3(raw[0],raw[1],raw[2]);var motor=scene.zombie_world.motor
    for radius in [0.0,1.0,2.0,3.0,4.0,5.0]:
        for angle in [0,45,90,135,180,225,270,315]:
            var proposed=center+Vector3(cos(deg_to_rad(angle)),0,sin(deg_to_rad(angle)))*radius
            var point=motor._floor(proposed)
            if point!=null and motor._free(point) and motor._separated("",point) and point.distance_to(scene.player.global_position)>.65:return point
    return null

func reconcile_anchors() -> void:
    # Human encounter anchors are provisional, not persistent residences. A new
    # encounter must never invalidate an older checkpoint occupying that space.
    for id in actors.keys():
        var actor=actors[id];var blocked=actor.global_position.distance_to(scene.player.global_position)<.6
        for entry in scene.zombie_world.saved.values():
            if entry.health<=0:continue
            if actor.global_position.distance_to(Vector3(entry.position[0],entry.position[1],entry.position[2]))<.6:blocked=true;break
        if not blocked:continue
        var point=_anchor(config.encounters[id].candidate)
        if point!=null:actor.global_position=point
        else:
            actor.collision_layer=0;actor.visible=false
            close();actors.erase(id);actor.queue_free()

func _interface() -> void:
    prompt=Label.new();prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;prompt.add_theme_font_size_override("font_size",15)
    prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;scene.game_ui.add_child(prompt)
    panel=PanelContainer.new();panel.name="CharacterConversation99";scene.game_ui.add_child(panel)
    var style=StyleBoxFlat.new();style.bg_color=Color("141b1af5");style.border_color=Color("786e56");style.set_border_width_all(1);style.set_content_margin_all(20)
    panel.add_theme_stylebox_override("panel",style)
    var column=VBoxContainer.new();column.add_theme_constant_override("separation",12);panel.add_child(column)
    speaker=Label.new();speaker.add_theme_font_size_override("font_size",20);speaker.add_theme_color_override("font_color",Color("e3c997"));column.add_child(speaker)
    speech=Label.new();speech.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;speech.custom_minimum_size.y=48;column.add_child(speech)
    options=HBoxContainer.new();options.add_theme_constant_override("separation",12);column.add_child(options)
    var about=Button.new();about.text="Você é daqui?";about.pressed.connect(_about);options.add_child(about)
    var leave=Button.new();leave.text="Conversar depois";leave.pressed.connect(close);options.add_child(leave)
    var hint=Label.new();hint.text="Esc · encerrar";hint.add_theme_font_size_override("font_size",11);column.add_child(hint)
    panel.visible=false;prompt.visible=false
    get_viewport().size_changed.connect(_layout);_layout()

func _layout() -> void:
    var viewport=get_viewport().get_visible_rect().size;var width=minf(560,viewport.x-40)
    panel.position=Vector2((viewport.x-width)*.5,viewport.y-275);panel.size=Vector2(width,210)
    prompt.position=Vector2(20,viewport.y-82);prompt.size=Vector2(viewport.x-40,28)

func reachable(id: String) -> bool:
    if not actors.has(id) or not is_instance_valid(actors[id]):return false
    var p=scene.player;var actor=actors[id];var delta=actor.global_position-p.global_position
    if Vector2(delta.x,delta.z).length()>RANGE or absf(delta.y)>.6:return false
    var query=PhysicsRayQueryParameters3D.create(p.global_position+Vector3.UP*1.15,actor.global_position+Vector3.UP*1.15,3,[p.get_rid()])
    var hit=get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty() or hit.collider==actor

func ready() -> bool:
    var p=scene.player;var demo=p.get_node_or_null("Demo95")
    return not p.paused and not p.hud_open and (demo==null or demo.state=="alive") and p.action.state=="idle" and not p.inventory_actions.busy() and not p.combat.is_attacking() and not p.reaction.is_active() and not p.traversal.is_active() and not p.map_doors.busy() and p.flow.queue.is_empty() and not scene.world_items.has_interaction() and scene.world_items.pending_id.is_empty() and not p.shoulder.holding

func open(id: String) -> bool:
    if not active.is_empty() or not ready() or not reachable(id):return false
    if not scene.player.set_hud_open(true):return false
    active=id;registry.met[id]=true;initial_body_records=scene.player.body_health.records.duplicate(true)
    scene.player.velocity=Vector3.ZERO;scene.player.avatar.set_motion("crouch_idle" if scene.player.crouched else "idle");scene.player.avatar.motion_rate=1
    speaker.text=registry.definitions[id].name;speech.text=config.encounters[id].introduction
    panel.visible=true;prompt.visible=false;options.get_child(0).grab_focus();return true

func _about() -> void:
    if active.is_empty() or not reachable(active):close();return
    speech.text=config.encounters[active].about

func close() -> void:
    if active.is_empty():return
    active="";panel.visible=false
    # Respect the independent C05 panels if the player switched to them.
    scene.game_ui.sync_lock()

func _process(_delta: float) -> void:
    if scene==null or panel==null:return
    var p=scene.player
    if not active.is_empty():
        var demo=p.get_node_or_null("Demo95")
        if p.paused or p.reaction.is_active() or (demo!=null and demo.state!="alive") or p.body_health.records!=initial_body_records or not reachable(active) or scene.game_ui.personal.visible or scene.game_ui.nearby.visible or scene.game_ui.windows[1].visible:
            close()
        else:p.set_hud_open(true)
    nearest="";var distance=INF
    if active.is_empty() and ready():
        for id in actors:
            if reachable(id):
                var d=p.global_position.distance_squared_to(actors[id].global_position)
                if d<distance:nearest=id;distance=d
    prompt.visible=not nearest.is_empty() and active.is_empty()
    if prompt.visible:prompt.text="E · Conversar com "+(str(registry.definitions[nearest].name) if registry.met[nearest] else str(registry.definitions[nearest].role).to_lower())

func _input(event: InputEvent) -> void:
    if active.is_empty() or not event is InputEventMouseButton:return
    if event.button_index==MOUSE_BUTTON_RIGHT or (event.button_index==MOUSE_BUTTON_LEFT and not panel.get_global_rect().has_point(event.position)):
        get_viewport().set_input_as_handled()

func _shortcut_input(event: InputEvent) -> void:
    if not event is InputEventKey or event.echo or not event.pressed:return
    if not active.is_empty():
        if event.physical_keycode in [KEY_ESCAPE,KEY_E]:close();get_viewport().set_input_as_handled();return
        if event.physical_keycode in [KEY_I,KEY_H]:close();return
        if event.physical_keycode in [KEY_R,KEY_1,KEY_2,KEY_3,KEY_4]:get_viewport().set_input_as_handled();return
    elif event.physical_keycode==KEY_E:
        # Preserve nearby furniture and doorway interaction priority.
        if scene.player.map_doors.prefers() or scene.world_items.has_interaction():return
        _process(0)
        if not nearest.is_empty() and open(nearest):get_viewport().set_input_as_handled()
