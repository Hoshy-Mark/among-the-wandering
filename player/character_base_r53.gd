extends CharacterBody3D

var avatar: Node3D
var capsule: CollisionShape3D
var camera: Camera3D
var inventory: Node
var action: RefCounted
var test_items: Dictionary={}
var scripted:=false
var command:=Vector2.ZERO
var command_run:=false
var crouched:=false
var preview_motion:=""
var motion_id:="idle"
var paused:=false
var supplies: RefCounted

func _ready() -> void:
    collision_layer=2
    collision_mask=1
    floor_snap_length=.20
    floor_max_angle=deg_to_rad(45)
    add_to_group("player")
    capsule=CollisionShape3D.new()
    var shape:=CapsuleShape3D.new()
    shape.radius=.23
    shape.height=1.84
    capsule.shape=shape
    capsule.position.y=.92
    add_child(capsule)
    avatar=load("res://personagem/personagem.tscn").instantiate()
    avatar.position.y=.006
    add_child(avatar)
    avatar.set_appearance({"shirt_id":"camisa_xadrez_vinho","pants_id":"calca_carvao","boots_id":"botas_escuras"})
    inventory=load("res://personagem/inventario_roupas.gd").new()
    add_child(inventory)
    inventory.setup(avatar)
    test_items["camisa_xadrez_vinho"]=inventory.equipped.shirt
    for item in ["camiseta_oliva","moletom_cinza"]:
        test_items[item]=inventory.receive(item)
    var action_script = "res://personagem/interacao_inventario.gd"
    if ResourceLoader.exists("res://personagem/consumo66.gd"):
        action_script = "res://personagem/consumo66.gd"
        supplies = load("res://personagem/suprimentos_teste.gd").new()
    action=load(action_script).new()
    action.setup(avatar)

func set_crouch(value: bool) -> bool:
    if value==crouched:
        return true
    if not value:
        var query:=PhysicsShapeQueryParameters3D.new()
        var shape:=CapsuleShape3D.new()
        shape.radius=.23
        shape.height=1.84
        query.shape=shape
        query.transform=Transform3D(Basis.IDENTITY,global_position+Vector3(0,.94,0))
        query.exclude=[get_rid()]
        query.collision_mask=1
        if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
            return false
    crouched=value
    (capsule.shape as CapsuleShape3D).height=1.56 if value else 1.84
    capsule.position.y=.78 if value else .92
    return true

func set_preview(id: String) -> bool:
    if not id.is_empty() and not avatar.clips.has(id):
        return false
    if not set_crouch(id in ["crouch","crouch_idle"]):
        return false
    action.cancel()
    preview_motion=id
    paused=false
    avatar.motion_paused=false
    velocity.x=0
    velocity.z=0
    return true

func _prepare_action() -> bool:
    if paused or action.state!="idle" or not set_crouch(false):
        return false
    preview_motion=""
    return true

func request_gesture() -> bool:
    return _prepare_action() and action.begin()


func request_use(kind: String) -> bool:
    if supplies == null or not supplies.stock.has(kind) or supplies.stock[kind] <= 0:
        return false
    if not _prepare_action():
        return false
    var expected: int = supplies.stock[kind]
    return action.begin(func() -> bool: return supplies.apply(kind, expected), kind)


func refill_supplies() -> void:
    if supplies == null:
        return
    action.cancel()
    supplies.refill()
    action.clear_dressing()

func request_equip(item_id: String) -> bool:
    if not test_items.has(item_id) or not _prepare_action():
        return false
    var uid: String=test_items[item_id]
    if not inventory.instances.has(uid):
        return false
    var expected: Dictionary=inventory.instances[uid].duplicate(true)
    var previous: String=inventory.equipped.shirt
    if previous==uid:
        return false
    return action.begin(func() -> bool:
        if inventory.instances.get(uid,{})!=expected or inventory.equipped.shirt!=previous:
            return false
        return inventory.equip(uid),"equip")

func request_store() -> bool:
    if not _prepare_action():
        return false
    var uid: String=inventory.equipped.shirt
    if uid.is_empty():
        return false
    return action.begin(func() -> bool:
        if inventory.equipped.shirt!=uid or not inventory.instances.has(uid):
            return false
        return inventory.unequip("shirt"),"store")

func _physics_process(delta: float) -> void:
    var input:=command
    var run:=command_run
    if not scripted:
        var right_pressed = Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
        var left_pressed = Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
        var down_pressed = Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
        var up_pressed = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
        input = Vector2(float(right_pressed) - float(left_pressed), float(down_pressed) - float(up_pressed))
        run=Input.is_physical_key_pressed(KEY_SHIFT)
    if not input.is_finite():
        input=Vector2.ZERO
    if paused:
        input=Vector2.ZERO
        velocity.x=0
        velocity.z=0
    var direction:=Vector3.ZERO
    if not input.is_zero_approx():
        preview_motion=""
        var right:=camera.global_basis.x
        var down:=camera.global_basis.z
        right.y=0
        down.y=0
        direction=(right.normalized()*input.x+down.normalized()*input.y).limit_length(1)
        if action.state!="idle":
            action.cancel("walk")
    var speed := .65
    if run and not crouched:
        speed = 3.0
    velocity.x=move_toward(velocity.x,direction.x*speed,delta*8)
    velocity.z=move_toward(velocity.z,direction.z*speed,delta*8)
    velocity.y=-.2 if is_on_floor() else velocity.y-9.8*delta
    move_and_slide()
    var moving:=Vector2(velocity.x,velocity.z).length()>.05
    if crouched:
        motion_id = "crouch" if moving else "crouch_idle"
    elif moving:
        motion_id = "run" if run else "walk"
    else:
        motion_id = "idle"
    if not preview_motion.is_empty():
        motion_id=preview_motion
    if not paused and action.state=="idle":
        avatar.set_motion(motion_id)
    if moving:
        avatar.rotation.y=lerp_angle(avatar.rotation.y,atan2(velocity.x,velocity.z),minf(1,delta*12))
    avatar.motion_paused=paused
    action.advance(delta)

func _unhandled_key_input(event: InputEvent) -> void:
    if scripted or not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.physical_keycode==KEY_C and not paused:
        preview_motion=""
        if set_crouch(not crouched) and action.state!="idle":
            action.cancel("crouch_idle" if crouched else "idle")
    if event.physical_keycode==KEY_I:
        request_gesture()
    var shortcuts = {KEY_1: "eat", KEY_2: "drink", KEY_3: "medicine", KEY_4: "bandage"}
    if shortcuts.has(event.physical_keycode):
        request_use(shortcuts[event.physical_keycode])
    if event.physical_keycode == KEY_ESCAPE:
        action.cancel()
