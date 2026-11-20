extends "res://personagem/atalhos93.gd"
## Presentation adapter. R93 remains the authority for bindings and equipment.
const ACTIONS_R01={"up":"weapon_quick_up","left":"weapon_quick_left","right":"weapon_quick_right","down":"weapon_quick_down"}
const DEFAULTS_R01={"up":[KEY_UP,KEY_1],"left":[KEY_LEFT,KEY_2],"right":[KEY_RIGHT,KEY_3],"down":[KEY_DOWN,KEY_4]}
var view_r01: Control
var reveal_left_r01=0.0
var consulted_r01=false

func setup(root_scene: Node3D) -> void:
    super.setup(root_scene)
    # Remove only the old presentation; carry models and transactions remain R93.
    panel.get_parent().remove_child(panel);panel.queue_free();buttons.clear()
    view_r01=load("res://personagem/weapon_hud_r01.gd").new()
    view_r01.controller=self;scene.game_ui.add_child(view_r01);panel=view_r01
    for direction in DIRECTIONS:
        _default_action_r01(ACTIONS_R01[direction],DEFAULTS_R01[direction])
    _default_action_r01("weapon_quick_consult",[KEY_ALT])
    # The legacy service updates this Label every physics frame. Hide its canvas
    # once, without disabling weapon physics or changing the service's behavior.
    if scene.player.weapons.status!=null:scene.player.weapons.status.modulate.a=0
    sync()

func _default_action_r01(action: String,keys: Array) -> void:
    if InputMap.has_action(action):return
    InputMap.add_action(action)
    for code in keys:
        var key=InputEventKey.new();key.physical_keycode=code
        InputMap.action_add_event(action,key)

func reveal_r01() -> void:
    reveal_left_r01=1.5

func activate(direction: String,from_inventory: bool=false) -> bool:
    reveal_r01()
    # R01: selecting the registered active item confirms it without a second
    # equipment transaction. Stowing remains available in the existing inventory.
    var bag=scene.player.bag_inventory
    var uid=str(bindings.get(direction,""))
    if not uid.is_empty() and bag.owned(uid) and bag.equipped("main_hand")==uid and _ready_action(from_inventory):return true
    return super.activate(direction,from_inventory)

func sync() -> void:
    if scene==null:return
    var bag=scene.player.bag_inventory
    for direction in bindings.keys():
        var uid=str(bindings[direction])
        if not bag.owned(uid) or bag.quick_category(uid)!=direction:bindings.erase(direction)
    if view_r01!=null:view_r01.queue_redraw()
    _present()

func presentation_r01() -> Dictionary:
    var p=scene.player;var bag=p.bag_inventory;var uid=str(bag.equipped("main_hand"))
    var active={"uid":uid,"name":"Sem arma","definition":"","ammo":"","type":"empty"}
    if bag.items.has(uid):
        var item=bag.items[uid];var spec=p.weapons.spec(uid)
        active.name=str(bag.catalog[item.definition].name);active.definition=str(item.definition)
        active.type=str(spec.get("type","melee" if not spec.is_empty() else "item"))
        if active.type=="firearm":active.ammo="%d / %d"%[p.weapons.loaded(uid),int(spec.capacity)]
    var slots={}
    for direction in DIRECTIONS:
        var linked=str(bindings.get(direction,""))
        var valid=not linked.is_empty() and bag.owned(linked) and bag.quick_category(linked)==direction
        var row={"name":"Indisponível" if direction=="down" else "Não atribuído","definition":"","state":"unavailable" if direction=="down" else "empty","active":false}
        if valid and direction!="down":
            row.name=str(bag.catalog[bag.items[linked].definition].name)
            row.definition=str(bag.items[linked].definition);row.state="assigned";row.active=linked==uid
        slots[direction]=row
    return {"active":active,"slots":slots}

func _process(delta: float) -> void:
    if scene==null or view_r01==null:return
    var p=scene.player
    # Query held action instead of retaining a key-down flag across UI/focus changes.
    consulted_r01=Input.is_action_pressed("weapon_quick_consult") and get_window().has_focus()
    reveal_left_r01=maxf(0,reveal_left_r01-delta)
    view_r01.visible=not p.hud_open and not p.paused
    view_r01.cross_open=consulted_r01 or reveal_left_r01>0
    view_r01.queue_redraw();_present()

func _shortcut_input(event: InputEvent) -> void:
    if scene==null or scripted or scene.player.hud_open or scene.player.paused:return
    if event.is_action("weapon_quick_consult"):
        get_viewport().set_input_as_handled();return
    for direction in DIRECTIONS:
        if event.is_action(ACTIONS_R01[direction]):
            get_viewport().set_input_as_handled()
            if event.is_action_pressed(ACTIONS_R01[direction],false):activate(direction)
            return

func _unhandled_key_input(_event: InputEvent) -> void:
    pass # Handled in the shortcut stage, after GUI and before legacy unhandled keys.
