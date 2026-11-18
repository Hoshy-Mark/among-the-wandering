extends "res://player/character_base_r62.gd"
signal hud_requested(tab: int)

var bag_inventory: RefCounted
var body_health: RefCounted
var hud_open=false
var backpack_visual: Node3D
var inventory_message=""
var last_bag="uninitialized"

func _ready() -> void:
    super._ready()
    condition_path="user://character_profile_r77.json"
    bag_inventory=load("res://personagem/inventario69.gd").new()
    bag_inventory.configure(global_position)
    body_health=load("res://personagem/corpo63.gd").new()
    body_health.condition=condition_state
    for slot in ["shirt","pants","boots","belt"]:
        var definition: String=avatar.selection[slot+"_id"]
        if definition!="none":
            bag_inventory.add(definition,1,"slot:"+slot)
    bag_inventory.add("bag_canvas",1,"slot:backpack")
    var starter_bag: String=bag_inventory.equipped("backpack")
    for entry in [["water",1],["food",2],["moletom_cinza",1]]:
        bag_inventory.add(entry[0],entry[1],starter_bag)
    for entry in [["bandage",3],["food",2],["water",1],["medicine",3]]:
        bag_inventory.add(entry[0],entry[1],"pockets")
    for definition in ["bag_school","bag_hiking","moletom_cinza","baton"]:
        bag_inventory.add(definition,1,"world:crate")
    backpack_visual=Node3D.new()
    avatar.add_child(backpack_visual)
    bag_inventory.changed.connect(_inventory_changed)
    _inventory_changed()

func _inventory_changed() -> void:
    var profile: Dictionary={}
    for slot in ["shirt","pants","boots","belt"]:
        var uid: String=bag_inventory.equipped(slot)
        profile[slot+"_id"]="none" if uid.is_empty() else bag_inventory.items[uid].definition
    avatar.set_appearance(profile)
    var bag: String=bag_inventory.equipped("backpack")
    var bag_definition="" if bag.is_empty() else str(bag_inventory.items[bag].definition)
    if last_bag!=bag_definition:
        for child in backpack_visual.get_children():
            child.queue_free()
            child.visible=false
    if not bag.is_empty() and last_bag!=bag_definition:
        var definition: Dictionary=bag_inventory.catalog[bag_inventory.items[bag].definition]
        var factor=.85 if definition.capacity==8 else 1.15 if definition.capacity==24 else 1.0
        _bag_box(Vector3(.32,.42,.16)*factor,Vector3.ZERO,Color(definition.color))
        _bag_box(Vector3(.25,.17,.05)*factor,Vector3(0,-.07,-.10)*factor,Color(definition.color).darkened(.12))
        _bag_box(Vector3(.34,.08,.18)*factor,Vector3(0,.18,-.01)*factor,Color(definition.color).lightened(.08))
        _bag_box(Vector3(.12,.025,.04)*factor,Vector3(0,.24,0)*factor,Color(.16,.17,.14))
        for side in [-1,1]:
            _bag_box(Vector3(.035,.31,.025)*factor,Vector3(.13*side,.05,.35)*factor,Color(.16,.17,.14))
            _bag_box(Vector3(.035,.025,.34)*factor,Vector3(.13*side,.21,.18)*factor,Color(.16,.17,.14))
            _bag_box(Vector3(.04,.06,.025)*factor,Vector3(.09*side,-.06,-.135)*factor,Color(.14,.15,.13))
    last_bag=bag_definition
    var armed=not bag_inventory.equipped("main_hand").is_empty()
    if combat.armed!=armed:
        combat.set_armed(armed)
    _update_equipment()

func _bag_box(size: Vector3, position: Vector3, color: Color) -> void:
    var mesh=MeshInstance3D.new()
    var box=BoxMesh.new()
    box.size=size
    mesh.mesh=box
    mesh.position=position
    var material=StandardMaterial3D.new()
    material.albedo_color=color
    material.roughness=1
    mesh.material_override=material
    backpack_visual.add_child(mesh)

func _update_equipment() -> void:
    if backpack_visual==null:
        return
    var rig: Skeleton3D=avatar.skeleton
    var index=rig.find_bone("Chest")
    backpack_visual.global_transform=rig.global_transform*rig.get_bone_global_pose(index)*rig.get_bone_global_rest(index).affine_inverse()*Transform3D(Basis.IDENTITY,Vector3(0,1.20,-.23))
    if not bag_inventory.equipped("main_hand").is_empty() and action.state=="idle":
        combat.weapon.attach(avatar)
        combat.weapon.visible=true
        if not combat.guarding and avatar.hand_layer.label!="R_Cylinder":
            avatar.hand_layer.set_pose("R_Cylinder")
    elif action.state!="idle":
        combat.weapon.visible=false
    elif bag_inventory.equipped("main_hand").is_empty() and not combat.guarding:
        combat.weapon.visible=false
        if avatar.hand_layer.label=="R_Cylinder":
            avatar.hand_layer.set_pose("Relaxed")

func _physics_process(delta: float) -> void:
    if hud_open and not traversal.is_active() and not reaction.is_active() and flow.queue.is_empty() and not combat.is_attacking():
        locomotion.cancel()
        velocity.x=0
        velocity.z=0
        velocity.y=-.2 if is_on_floor() else velocity.y-9.8*delta
        restore_collision()
        move_and_slide()
        _sync_condition()
        avatar.motion_paused=paused
        if action.state=="idle":
            avatar.set_motion(_movement_motion(false,false))
            if not paused:
                condition_state.advance(delta,false,false,false)
        action.advance(delta)
        action._present()
        _sync_dressing()
    else:
        super._physics_process(delta)
    _update_equipment()

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_I,KEY_H]:
        hud_requested.emit(0 if event.physical_keycode==KEY_I else 1)
        get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and event.physical_keycode==KEY_E:
        inventory_message="Equipe o bastão pelo inventário"
        return
    if hud_open:
        return
    super._unhandled_key_input(event)

func set_hud_open(value: bool) -> bool:
    if value and (traversal.is_active() or reaction.is_active() or not flow.queue.is_empty() or combat.is_attacking()):
        return false
    hud_open=value
    if value:
        locomotion.cancel()
        combat.set_guard(false)
    return true

func use_item(uid: String) -> bool:
    inventory_message=""
    if not bag_inventory.owned(uid):
        inventory_message="Guarde o item antes de usar"
        return false
    var item: Dictionary=bag_inventory.items[uid]
    var kind: String=bag_inventory.catalog[item.definition].get("use","")
    if kind.is_empty():
        return false
    var revision: int=condition_state.forearm_revision
    if kind=="bandage" and not condition_state.can_dress(revision):
        inventory_message="O curativo disponível trata o antebraço esquerdo"
        return false
    if not _prepare_action():
        return false
    var expected: int=item.count
    return action.begin(func() -> bool:
        if kind=="bandage" and not condition_state.can_dress(revision):
            return false
        var previous: Dictionary=bag_inventory.snapshot()
        if not bag_inventory.consume(uid,1,expected,false):
            return false
        if kind=="bandage" and not condition_state.dress(revision):
            bag_inventory.restore(previous,false)
            return false
        bag_inventory.changed.emit()
        return true
    ,kind)

func equip_item(uid: String) -> bool:
    inventory_message=""
    bag_inventory.message=""
    if not bag_inventory.items.has(uid):
        inventory_message="Selecione um item"
        return false
    if not _prepare_action():
        inventory_message="Conclua a ação atual"
        return false
    if bag_inventory.catalog[bag_inventory.items[uid].definition].get("slot","").is_empty():
        inventory_message="Este item é guardado em um contêiner"
        return false
    return bag_inventory.equip(uid)

func move_item(uid: String, destination: String) -> bool:
    inventory_message=""
    bag_inventory.message=""
    if not bag_inventory.items.has(uid):
        inventory_message="Selecione um item"
        return false
    if not flow.queue.is_empty() or traversal.is_active() or reaction.is_active() or combat.is_attacking():
        return false
    return bag_inventory.move(uid,destination)

func request_use(kind: String) -> bool:
    for uid in bag_inventory.items:
        if bag_inventory.owned(uid) and bag_inventory.catalog[bag_inventory.items[uid].definition].get("use","")==kind:
            return use_item(uid)
    inventory_message="Item indisponível"
    return false

func request_equip(definition: String) -> bool:
    for uid in bag_inventory.items:
        if bag_inventory.items[uid].definition==definition:
            return equip_item(uid)
    return false

func request_store() -> bool:
    var uid: String=bag_inventory.equipped("shirt")
    return not uid.is_empty() and bag_inventory.move(uid,"pockets")

func receive_zone_damage(id: String, zone: String, kind: String, amount: float) -> bool:
    if not body_health.hit(id,zone,kind,amount):
        return false
    action.cancel()
    locomotion.cancel()
    if not paused:
        request_reaction("hit_front")
    return true

func _profile_data() -> Dictionary:
    return {"version":1,"inventory":bag_inventory.snapshot(),"condition":condition_state.snapshot(),"body":body_health.snapshot()}

func save_condition() -> bool:
    var data=_profile_data()
    var file=FileAccess.open(condition_path+".tmp",FileAccess.WRITE)
    if file==null:
        return false
    file.store_string(JSON.stringify(data,"",true,true))
    file.flush()
    var error=file.get_error()
    file.close()
    return error==OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(condition_path+".tmp"),ProjectSettings.globalize_path(condition_path))==OK

func load_condition() -> bool:
    if action.state!="idle" or traversal.is_active() or reaction.is_active() or combat.guarding or not flow.queue.is_empty():
        return false
    var source=condition_path
    if source=="user://character_profile_r77.json" and not FileAccess.file_exists(source):
        for legacy in ["user://character_profile_r76.json","user://character_profile_r75.json","user://character_profile_r74.json","user://character_profile_r73.json","user://character_profile_r72.json","user://character_profile_r71.json","user://character_profile_r70.json","user://character_profile_r69.json","user://character_profile_r68.json","user://character_profile_r67.json","user://character_profile_r66.json","user://character_profile_r65.json","user://character_profile_r64.json","user://character_profile_r63.json","user://character_condition_r62.json","user://character_condition_r61.json"]:
            if FileAccess.file_exists(legacy):
                source=legacy
                break
    var data=JSON.parse_string(FileAccess.get_file_as_string(source)) if FileAccess.file_exists(source) else null
    if not data is Dictionary:
        return false
    if not data.has("inventory"):
        if not condition_state.restore(data):
            return false
        body_health.records.clear()
        body_health.changed.emit()
        _sync_condition()
        return true
    if data.get("version")!=1:
        return false
    var inventory_shadow=load("res://personagem/inventario69.gd").new()
    inventory_shadow.house_anchors=bag_inventory.house_anchors.duplicate(true)
    var condition_shadow=load("res://personagem/ferimentos62.gd").new()
    var body_shadow=load("res://personagem/corpo63.gd").new()
    if not inventory_shadow.restore(data.get("inventory"),false) or not condition_shadow.restore(data.get("condition")) or not body_shadow.restore(data.get("body"),false):
        return false
    var forearm=0.0
    for wound in body_shadow.records.values():
        if wound.zone=="forearm_left":
            forearm+=wound.severity
    if condition_shadow.forearm_injury+.000001<minf(1,forearm):
        return false
    bag_inventory.restore(data.inventory,false)
    body_health.restore(data.body,false)
    condition_state.restore(data.condition)
    bag_inventory.changed.emit()
    body_health.changed.emit()
    _sync_condition()
    return true
