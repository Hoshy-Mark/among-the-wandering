extends Node3D
const DIRECTIONS=["left","up","right","down"]
const GLYPHS={"left":"←","up":"↑","right":"→","down":"↓"}
const LABELS={"left":"Arma curta","up":"Arma longa","right":"Arma branca","down":"Arremessável"}
const KEYS={KEY_LEFT:"left",KEY_UP:"up",KEY_RIGHT:"right",KEY_DOWN:"down"}
var scene: Node3D
var bindings={}
var job={}
var panel: Control
var buttons={}
var carried={}
var scripted=false
func setup(root_scene: Node3D) -> void:
    scene=root_scene;var p=scene.player;p.quick_slots_enabled=true
    var clip: Animation=p.avatar.player.get_animation(p.avatar.clips.equip_item).duplicate(true)
    var ratio=.45/clip.length
    for track in clip.get_track_count():
        for key in clip.track_get_key_count(track):clip.track_set_key_time(track,key,clip.track_get_key_time(track,key)*ratio)
    clip.length=.45;clip.loop_mode=Animation.LOOP_NONE
    var library=AnimationLibrary.new();library.add_animation("switch",clip);p.avatar.player.add_animation_library("Quick93",library);p.avatar.clips.weapon_switch93="Quick93/switch"
    p.bag_inventory.changed.connect(sync)
    p.action.cancelled.connect(func(_kind,_done):job.clear();sync())
    p.action.finished.connect(_finished)
    panel=Control.new();panel.name="AtalhosArmas";panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    panel.offset_left=-330;panel.offset_top=-280;panel.offset_right=-16;panel.offset_bottom=-55
    panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.game_ui.add_child(panel)
    var places={"up":Vector2(107,0),"left":Vector2(0,76),"right":Vector2(214,76),"down":Vector2(107,152)}
    for direction in DIRECTIONS:
        var button=Button.new();button.position=places[direction];button.size=Vector2(104,70);button.focus_mode=Control.FOCUS_NONE
        button.add_theme_font_size_override("font_size",10);button.pressed.connect(func():activate(direction));panel.add_child(button);buttons[direction]=button
        if direction!="down":
            var model=load("res://personagem/arma_visual92.gd").new();p.avatar.add_child(model);model.visible=false;carried[direction]=model
    process_priority=110;sync()
func bound_direction(uid: String) -> String:
    for direction in bindings:
        if bindings[direction]==uid:return direction
    return ""
func _notice(message: String) -> bool:
    scene.player.inventory_message=message;scene.game_ui.feedback.text=message;return false
func _ready_action(allow_hud: bool) -> bool:
    var p=scene.player
    return not p.paused and (allow_hud or not p.hud_open) and p.action.state=="idle" and not p.inventory_actions.busy() and not p.combat.is_attacking() and not p.reaction.is_active() and not p.traversal.is_active() and p.flow.queue.is_empty() and not p.map_doors.busy() and (allow_hud or not scene.world_items.has_interaction()) and job.is_empty()
func bind(direction: String,uid: String) -> bool:
    var p=scene.player;var bag=p.bag_inventory
    if direction not in DIRECTIONS or not _ready_action(true):return _notice("Conclua a ação atual")
    p.update_nearby()
    if not bag.can_touch(uid) or bag.quick_category(uid)!=direction:return _notice("Item incompatível com esse atalho")
    if bindings.get(direction,"")==uid:return true
    var next=bindings.duplicate(true);var staged=bag.items.duplicate(true);var previous=str(next.get(direction,""))
    var target="slot:quick_"+direction;var source: Dictionary=staged[uid].duplicate(true)
    if not previous.is_empty() and bag.items.has(previous) and bag.items[previous].location=="slot:main_hand":return _notice("Guarde a arma atual com a seta antes de substituir o atalho")
    if not previous.is_empty() and bag.items.has(previous) and bag.items[previous].location==target:
        if str(source.location).begins_with("slot:"):return _notice("Guarde o item anterior no inventário antes de substituir")
        staged[previous].location=source.location;staged[previous].x=source.x;staged[previous].y=source.y;staged[previous].rot=source.rot
    next[direction]=uid
    if source.location=="slot:main_hand":
        bindings=next;sync();return true
    staged[uid].location=target
    if not bag.valid(staged):return _notice("A arma anterior não cabe no espaço do novo item")
    return _begin(staged,next,"Preparando "+GLYPHS[direction]+" · "+LABELS[direction])
func unbind(direction: String) -> bool:
    if not _ready_action(true):return _notice("Conclua a ação atual")
    var bag=scene.player.bag_inventory;var uid=str(bindings.get(direction,""))
    if bag.items.has(uid) and str(bag.items[uid].location).begins_with("slot:quick_"):return _notice("Retire o item para uma célula do inventário ou para o chão antes de limpar")
    bindings.erase(direction);sync();return true
func activate(direction: String,from_inventory: bool=false) -> bool:
    var p=scene.player;var bag=p.bag_inventory
    if direction not in DIRECTIONS or not _ready_action(from_inventory):return _notice("Conclua a ação atual")
    sync();var uid=str(bindings.get(direction,""))
    if not bag.owned(uid):return _notice("Arremessáveis ainda não disponíveis" if direction=="down" else "Atalho vazio · escolha um item no inventário")
    var staged=bag.items.duplicate(true);var held=bag.equipped("main_hand")
    if not held.is_empty():
        var old_direction=bound_direction(held)
        if old_direction.is_empty():return _notice("Vincule ou guarde a arma da mão antes de trocar")
        var occupied=bag.equipped("quick_"+old_direction)
        if not occupied.is_empty() and occupied!=held:return _notice("O espaço de porte está ocupado")
        staged[held].location="slot:quick_"+old_direction
    if uid!=held:staged[uid].location="slot:main_hand"
    if not bag.valid(staged):return _notice("Não foi possível trocar o equipamento")
    return _begin(staged,bindings.duplicate(true),"Guardando arma" if uid==held else "Equipando "+bag.catalog[bag.items[uid].definition].name)
func _begin(staged: Dictionary,next: Dictionary,message: String) -> bool:
    var p=scene.player;var was_aiming=p.shoulder.holding
    if was_aiming:p.shoulder.set_aim(false)
    if not p._prepare_action():return false
    job={"expected":p.bag_inventory.items.duplicate(true),"old_bindings":bindings.duplicate(true),"items":staged,"bindings":next,"origin":p.global_position,"resume":was_aiming}
    if not p.action.begin(_commit,"equip"):job.clear();return false
    p.action.motion_id="weapon_switch93";p.avatar.set_motion("weapon_switch93");p.avatar.motion_clock=0;p.avatar.motion_rate=0
    p.inventory_message=message;return true
func _commit() -> bool:
    if job.is_empty():return false
    var p=scene.player;var bag=p.bag_inventory
    if bag.items!=job.expected or bindings!=job.old_bindings or p.global_position.distance_to(job.origin)>.05:return false
    for uid in job.items:
        if job.items[uid].location!=job.expected[uid].location and not bag.can_touch(uid):return false
    var old=bindings;bindings=job.bindings.duplicate(true)
    if not bag._commit(job.items,false):bindings=old;sync();return false
    bag.changed.emit()
    p.inventory_message="Equipamento pronto";sync();return true
func _finished() -> void:
    var resume=bool(job.get("resume",false));job.clear();sync()
    if resume and not scripted and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and scene.player.shoulder.is_firearm():scene.player.shoulder.set_aim(true)
func sync() -> void:
    if scene==null:return
    var p=scene.player;var bag=p.bag_inventory
    for direction in bindings.keys():
        var uid=str(bindings[direction])
        if not bag.owned(uid) or bag.quick_category(uid)!=direction:bindings.erase(direction)
    for direction in DIRECTIONS:
        var uid=str(bindings.get(direction,""));var name="Reservado" if direction=="down" else "Vazio"
        if bag.items.has(uid):name=str(bag.catalog[bag.items[uid].definition].name)
        var active=uid!="" and uid==bag.equipped("main_hand")
        var lines=PackedStringArray();var line=""
        for word in name.split(" "):
            if not line.is_empty() and line.length()+word.length()+1>16:lines.append(line);line=word
            else:line+=(" " if not line.is_empty() else "")+word
        lines.append(line)
        buttons[direction].text=GLYPHS[direction]+" "+LABELS[direction]+"\n"+"\n".join(lines)+("\nEm uso" if active else "")
        buttons[direction].modulate=Color("b9e6bc") if active else Color.WHITE
        buttons[direction].tooltip_text="Pressione novamente para guardar. Defina o item no inventário."
    _present()
func _present() -> void:
    if scene==null:return
    var p=scene.player;var rig=p.avatar.skeleton;var bag=p.bag_inventory
    for direction in carried:
        var model=carried[direction];var uid=str(bindings.get(direction,""))
        model.visible=bag.items.has(uid) and bag.items[uid].location=="slot:quick_"+direction
        if not model.visible:continue
        model.configure(str(bag.items[uid].definition));model.visible=true
        if direction=="up":
            var neck=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("Neck"))
            var back=.34 if not bag.equipped("backpack").is_empty() else .18
            var offset=Transform3D(Basis(Vector3.RIGHT,-PI/2)*Basis(Vector3.UP,-model.BARREL_YAW),Vector3(.14,-.30,-back))
            model.global_transform=neck*offset
        else:
            var hip=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("Hips"))
            var side=.24 if direction=="left" else -.24
            var basis=Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.UP,-model.BARREL_YAW) if direction=="left" else Basis.IDENTITY
            model.global_transform=hip*Transform3D(basis,Vector3(side,.03,-.04))
        if model.muzzle!=null:model.muzzle.visible=false
func _process(_delta: float) -> void:
    if scene==null:return
    panel.visible=not scene.player.hud_open;_present()
func _unhandled_key_input(event: InputEvent) -> void:
    if scene==null or not event is InputEventKey or event.physical_keycode not in KEYS or scene.player.hud_open:return
    get_viewport().set_input_as_handled()
    if event.pressed and not event.echo:activate(KEYS[event.physical_keycode])
