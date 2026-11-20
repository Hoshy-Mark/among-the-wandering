extends "res://player/character_base_r63.gd"
var shoulder: Node3D
var weapons: Node3D
var session_save: Node3D
var survival: Node3D
var map_combat: Node3D
var demo_mode=false
var map_traversals: Node3D
var map_doors: Node3D
var world_interaction: Node3D
var inventory_actions: RefCounted

func _unhandled_key_input(event: InputEvent) -> void:
    if shoulder!=null and shoulder.is_firearm() and event is InputEventKey and event.physical_keycode in [KEY_Q,KEY_F]:
        get_viewport().set_input_as_handled();return
    if demo_mode and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_R and not hud_open and map_combat!=null and map_combat.has_method("reload_weapon"):
        map_combat.reload_weapon()
        get_viewport().set_input_as_handled()
        return
    if demo_mode and event is InputEventKey:
        if event.pressed and not event.echo and map_traversals!=null and event.physical_keycode in [KEY_B,KEY_V]:
            if event.physical_keycode==KEY_B:map_traversals.request()
            else:
                var window=map_traversals.closest(true)
                if window!=null:map_doors.request(window.opening_id)
            get_viewport().set_input_as_handled()
            return
        if event.physical_keycode==KEY_J:
            return # The furniture controller owns J, not the old stagger shortcut.
        if event.physical_keycode in [KEY_F7,KEY_1,KEY_2,KEY_3,KEY_4,KEY_K,KEY_L,KEY_M,KEY_V,KEY_B]:
            get_viewport().set_input_as_handled()
            return
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F7 and world_interaction!=null and world_interaction.house!=null:
        world_interaction.house.visit_next()
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and world_interaction!=null:
        if event.physical_keycode==KEY_E:
            if map_doors!=null and not world_interaction.has_interaction() and map_doors.prefers():
                map_doors.request(map_doors.nearest)
            else:
                world_interaction.interact_nearest()
            get_viewport().set_input_as_handled()
            return
        if event.physical_keycode==KEY_ESCAPE and world_interaction.has_interaction():
            world_interaction.close_interaction()
            get_viewport().set_input_as_handled()
            return
        if event.physical_keycode in [KEY_I,KEY_H] and not world_interaction.pending_id.is_empty():
            world_interaction.close_interaction()
            get_viewport().set_input_as_handled()
            return
    super._unhandled_key_input(event)

func _stack_action_ready() -> bool:
    update_nearby()
    inventory_message=""
    if inventory_actions!=null and inventory_actions.busy():
        inventory_message="Conclua a ação atual"
        return false
    bag_inventory.message=""
    if not flow.queue.is_empty() or traversal.is_active() or reaction.is_active() or combat.is_attacking():
        inventory_message="Conclua a ação atual"
        return false
    return true

func split_item(uid: String, amount: int) -> String:
    return bag_inventory.split(uid,amount) if _stack_action_ready() else ""

func merge_items(uid: String, target: String, amount: int) -> bool:
    return _stack_action_ready() and bag_inventory.merge(uid,target,amount)

func transfer_items(uid: String, destination: String, amount: int) -> bool:
    if not _stack_action_ready():
        return false
    if destination=="ground":
        return bag_inventory.transfer_to_ground(uid,amount,global_position)
    return bag_inventory.transfer(uid,destination,amount)

func _ready() -> void:
    super._ready()
    collision_mask|=2
    inventory_actions=load("res://personagem/acoes_inventario72.gd").new()
    inventory_actions.setup(self)

func _physics_process(delta: float) -> void:
    if map_doors!=null and map_doors.has_method("yielding113") and map_doors.yielding113():
        map_doors.advance_yield113(delta)
        update_nearby();_update_equipment();_sync_dressing()
        return
    _body_physics88(delta)
    update_nearby()

func update_nearby() -> void:
    var ids: Array[String]=[]
    var origin=global_position+Vector3.UP*.65
    for id in bag_inventory.world_containers:
        var target: Vector3=bag_inventory.point(id)
        var offset=target-global_position
        if Vector2(offset.x,offset.z).length()>bag_inventory.REACH or absf(offset.y)>1.1:
            continue
        var query=PhysicsRayQueryParameters3D.create(origin,target+Vector3.UP*.65,1,[get_rid()])
        if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
            ids.append(id)
    bag_inventory.set_reachable(ids,global_position)

func move_item(uid: String, destination: String) -> bool:
    update_nearby()
    if destination=="ground":
        inventory_message=""
        if not flow.queue.is_empty() or traversal.is_active() or reaction.is_active() or combat.is_attacking():
            return false
        return bag_inventory.move_to_ground(uid,global_position)
    return super.move_item(uid,destination)

func equip_item(uid: String) -> bool:
    update_nearby()
    return inventory_actions.begin({"kind":"equip","uid":uid})

func load_condition() -> bool:
    if session_save!=null:return session_save.load_game()
    var prepared: Dictionary={}
    if map_doors!=null:
        if action.state!="idle" or inventory_actions.busy() or map_doors.busy():return false
        var data=JSON.parse_string(FileAccess.get_file_as_string(condition_path)) if FileAccess.file_exists(condition_path) else null
        if not data is Dictionary:return false
        prepared=map_doors.prepare_restore(data.get("doors_h01"))
        if prepared.is_empty():
            inventory_message="Perfil inválido ou espaço da porta ocupado"
            return false
    var accepted=super.load_condition()
    if accepted and map_doors!=null:
        map_doors.apply_restore(prepared)
    if accepted:
        update_nearby()
    return accepted

func place_item(uid: String, destination: String, x: int, y: int, rotated: bool, amount: int=0, split: bool=false) -> bool:
    if not _stack_action_ready():
        return false
    if bag_inventory.items.has(uid) and str(bag_inventory.items[uid].location).begins_with("slot:"):
        if amount!=0 or split:
            return false
        return inventory_actions.begin({"kind":"store","uid":uid,"destination":destination,"x":x,"y":y,"rot":rotated})
    if destination=="drop_here":
        return bag_inventory.drop_at(uid,x,y,rotated)
    return bag_inventory.place(uid,destination,x,y,rotated,amount,split)

func rotate_item(uid: String) -> bool:
    return _stack_action_ready() and bag_inventory.rotate(uid)

func save_condition() -> bool:
    if session_save!=null:return session_save.save()
    if map_combat!=null and (combat.guarding or combat.is_attacking() or reaction.is_active()):
        inventory_message="Saia do combate e aguarde a reação antes de salvar"
        return false
    if map_doors!=null and map_doors.busy():
        inventory_message="Conclua o movimento da porta antes de salvar"
        return false
    if action.state!="idle" or inventory_actions.busy():
        inventory_message="Conclua ou cancele a ação antes de salvar"
        return false
    if get_tree().get_first_node_in_group("c05_hud")!=null:
        var ui=get_tree().get_first_node_in_group("c05_hud")
        if not ui.pending_mode.is_empty() or not ui.drag_uid.is_empty():
            inventory_message="Confirme ou cancele a operação antes de salvar"
            return false
    return super.save_condition()

func _profile_data() -> Dictionary:
    var data=super._profile_data()
    if map_doors!=null:data.doors_h01=map_doors.snapshot()
    return data

func nearest_obstacle(window_only: bool=false) -> Node3D:
    if map_traversals!=null:return map_traversals.closest(window_only)
    return super.nearest_obstacle(window_only)

func request_open(obstacle: Node3D=null) -> bool:
    if map_traversals!=null:
        if obstacle==null:obstacle=map_traversals.closest(true)
        if obstacle!=null and obstacle.has_meta("map77") and obstacle.kind=="window":
            if obstacle.opening.open:return false
            return map_doors.request(obstacle.opening_id)
    return super.request_open(obstacle)

func request_attack(kind: String="") -> bool:
    if map_combat!=null:return map_combat.request(kind)
    return super.request_attack(kind)
func toggle_guard() -> bool:
    if map_combat!=null and not map_combat.ready_to_act():return false
    return super.toggle_guard()
func receive_combat_hit(event: Dictionary) -> bool:
    return map_combat!=null and map_combat.receive(event)

func use_item(uid: String) -> bool:
    if survival!=null:return survival.use(uid)
    return super.use_item(uid)

func _present_hand_equipment() -> void:
    if weapons!=null:weapons.present()
    else:super._present_hand_equipment()

func _body_physics88(delta: float) -> void:
    if shoulder==null or not shoulder.holding:
        super._physics_process(delta);return
    # Classic RE4-style stationary aiming; no strained walking/aim blend.
    var was_scripted=scripted;var previous_command=command;var previous_run=command_run
    scripted=true;command=Vector2.ZERO;command_run=false;velocity.x=0;velocity.z=0
    super._physics_process(delta)
    scripted=was_scripted;command=previous_command;command_run=previous_run
