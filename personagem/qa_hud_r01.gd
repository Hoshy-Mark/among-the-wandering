extends Node
var h=load("res://personagem/revisao98.gd").new()
var checks=[]
var captures=[]

func _key(scene: Node,code: int,echo: bool=false) -> void:
    var key=InputEventKey.new();key.physical_keycode=code;key.pressed=true;key.echo=echo
    Input.parse_input_event(key);await scene.get_tree().process_frame
    key=InputEventKey.new();key.physical_keycode=code;key.pressed=false
    Input.parse_input_event(key);await scene.get_tree().process_frame

func _check(value: bool,description: String) -> void:
    if not value:
        push_error("HUD_R01_FAIL "+description);get_tree().quit(1)
        assert(value,description)
    checks.append(description);print("HUD_R01_CHECK ",description)

func _capture(scene: Node,name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var image=scene.get_viewport().get_texture().get_image()
    captures.append({"name":name,"width":image.get_width(),"height":image.get_height()})
    _check(image.save_png("res://qa/hud_r01/"+name+".png")==OK,"capture "+name)

func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/hud_r01"))
    var p=scene.player;var bag=p.bag_inventory;var q=p.get_node("Atalhos93");var aim=scene.shoulder
    h._freeze98(scene);h._player_idle(p);q.scripted=false
    p.condition_path="res://qa/hud_r01/checkpoint.json"
    var initial_count=bag.items.size()
    _check(q.presentation_r01().active.uid.is_empty() and q.presentation_r01().active.ammo.is_empty(),"empty hands have no invented ammo")
    _check(q.presentation_r01().slots.left.state=="empty" and q.presentation_r01().slots.down.state=="unavailable","empty and unavailable are distinct")
    _check(q.buttons.is_empty() and not is_instance_valid(scene.game_ui.get_node_or_null("AtalhosArmas")),"old cards removed")
    await _key(scene,KEY_2)
    _check(bag.equipped("main_hand").is_empty() and bag.items.size()==initial_count,"empty shortcut does not fabricate or equip an item")
    var pistol=h._equip92(scene,"pistol")
    _check(q.presentation_r01().active.uid==pistol and not q.presentation_r01().slots.left.active,"equipped unregistered uses actual UID")
    _check(q.bind("left",pistol),"explicit pistol binding")
    var carbine=h._find_weapon(bag,"carbine");var baton=h._find_weapon(bag,"baton")
    _check(q.bind("up",carbine),"bind long through gameplay");h._settle93(scene)
    _check(q.bind("right",baton),"bind melee through gameplay");h._settle93(scene)
    var rounds=p.weapons.rounds.duplicate(true)
    await _key(scene,KEY_1);await _key(scene,KEY_3);h._settle93(scene)
    _check(bag.equipped("main_hand")==carbine,"rapid inputs preserve the first valid transaction")
    for pair in [[KEY_1,carbine],[KEY_2,pistol],[KEY_3,baton],[KEY_UP,carbine],[KEY_LEFT,pistol],[KEY_RIGHT,baton]]:
        await _key(scene,pair[0]);h._settle93(scene)
        _check(bag.equipped("main_hand")==pair[1],"real input "+OS.get_keycode_string(pair[0]))
    _check(q.presentation_r01().active.ammo.is_empty(),"melee has no bullet counter")
    var held=bag.equipped("main_hand");await _key(scene,KEY_4);await _key(scene,KEY_DOWN)
    _check(bag.equipped("main_hand")==held and q.presentation_r01().slots.down.state=="unavailable","reserved does not equip")
    await _key(scene,KEY_1,true)
    _check(p.action.state=="idle" and bag.equipped("main_hand")==held,"echo ignored")
    p.traversal.state="align";await _key(scene,KEY_1)
    _check(bag.equipped("main_hand")==held,"traversal blocks switching");p.traversal.state="idle"
    _check(p.reaction.begin("hit_front"),"begin real reaction");await _key(scene,KEY_1)
    _check(bag.equipped("main_hand")==held,"reaction blocks switching");h._player_idle(p)
    p.set_hud_open(true);await _key(scene,KEY_1)
    _check(bag.equipped("main_hand")==held and not q.view_r01.visible,"inventory suppresses shortcuts and weapon HUD")
    p.set_hud_open(false)
    await _key(scene,KEY_2);h._settle93(scene)
    _check(bag.equipped("main_hand")==pistol and p.weapons.rounds==rounds,"switching consumes no rounds")
    var confirmed=bag.items.duplicate(true)
    await _key(scene,KEY_2)
    _check(p.action.state=="idle" and bag.items==confirmed,"active shortcut confirms without duplicate equip or holster")
    _check(p.place_item(h._find_weapon(bag,"ammo_pistol"),"pockets",2,0,false),"ammo moved with existing manual placement");h._settle93(scene)
    await _key(scene,KEY_R)
    _check(not p.weapons.reload_job.is_empty(),"R starts real reload");await _key(scene,KEY_1)
    _check(bag.equipped("main_hand")==pistol,"reload blocks switching");h._settle93(scene)
    _check(q.presentation_r01().active.ammo=="6 / 6","HUD reads real loaded/capacity")
    # A safe existing map point, no replacement backdrop or invented weapon state.
    var pair=h._pair98(scene,[],true)
    _check(not pair.is_empty(),"current woodland capture location")
    p.global_position=pair.player;p.avatar.rotation.y=0;p.velocity=Vector3.ZERO
    scene.focus=p.global_position+Vector3.UP*.95;scene.zoom=6.5;scene._update_camera()
    for tick in 2:await scene.get_tree().physics_frame
    _check(aim.set_aim(true),"real shoulder aim")
    h._step88(scene,.6)
    _check(p.request_attack(),"real firearm shot starts")
    await _key(scene,KEY_1)
    _check(bag.equipped("main_hand")==pistol,"firing blocks switching")
    for frame in 60:h._step88(scene,1.0/60)
    _check(p.weapons.loaded(pistol)==5 and q.presentation_r01().active.ammo=="5 / 6","shot updates HUD without parallel counter")
    aim.set_aim(false);h._step88(scene,.6);h._player_idle(p)
    _check(p.weapons.reload_weapon(),"reload after shot");h._settle93(scene)
    _check(q.presentation_r01().active.ammo=="6 / 6","reload immediately reflected")
    p.global_position=scene.spawn;p.update_nearby()
    _check(p.save_condition(),"existing checkpoint save")
    var saved_bindings=q.bindings.duplicate(true);var saved_items=bag.items.duplicate(true)
    _check(p.load_condition(),"existing checkpoint load")
    _check(q.bindings==saved_bindings and bag.items==saved_items,"UID bindings and manual cells preserved by save/load")
    var corrupt=p.session_save.snapshot();corrupt.quick93.bindings.left="missing_uid"
    _check(p.session_save.prepare(corrupt,false).is_empty(),"invalid saved binding rejected by existing codec")
    # Dropping the actual weapon must clean its shortcut; restore via real checkpoint.
    _check(p.place_item(pistol,"drop_here",0,40,false),"real drop starts");h._settle93(scene);q.sync()
    _check(not q.bindings.has("left") and not q.presentation_r01().slots.left.active,"dropped UID no longer selectable")
    _check(p.load_condition(),"restore QA checkpoint")
    _check(bag.items.size()==initial_count,"no weapon generation or duplication")
    p.global_position=pair.player;scene.focus=p.global_position+Vector3.UP*.95;scene._update_camera()
    q.reveal_left_r01=0
    var alt=InputEventKey.new();alt.physical_keycode=KEY_ALT;alt.keycode=KEY_ALT;alt.alt_pressed=true;alt.pressed=true
    Input.parse_input_event(alt);await scene.get_tree().process_frame;q._process(0)
    _check(Input.is_action_pressed("weapon_quick_consult"),"Alt consult held action")
    _check(q.view_r01.cross_open==scene.get_window().has_focus(),"held consult respects window focus")
    alt=InputEventKey.new();alt.physical_keycode=KEY_ALT;alt.keycode=KEY_ALT;alt.pressed=false
    Input.parse_input_event(alt);await scene.get_tree().process_frame;q._process(0)
    _check(not q.view_r01.cross_open,"Alt release closes consultation")
    # Presentation/readability checks at required viewport sizes, native frames.
    for dimensions in [Vector2i(960,600),Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,768)]:
        scene.get_window().size=dimensions
        for tick in 3:await scene.get_tree().process_frame
        q.reveal_left_r01=0;q.consulted_r01=false;q._process(0)
        _check(not q.view_r01.cross_open,"compact default "+str(dimensions))
        await _capture(scene,"compact_%dx%d"%[dimensions.x,dimensions.y])
        q.reveal_r01();q._process(0)
        await _capture(scene,"selector_%dx%d"%[dimensions.x,dimensions.y])
        var bounds=Rect2(Vector2.ZERO,scene.get_viewport().get_visible_rect().size)
        _check(bounds.encloses(q.view_r01.compact_rect) and bounds.encloses(q.view_r01.cross_rect),"safe area "+str(dimensions))
        _check(not q.view_r01.cross_rect.has_point(bounds.size*.5),"reticle clear "+str(dimensions))
    q.reveal_r01();q._process(.9);q.reveal_r01();q._process(.8)
    _check(q.view_r01.cross_open,"rapid consultation renews timeout")
    q._process(.71);_check(not q.view_r01.cross_open,"cross disappears after timeout")
    _check(q.view_r01.mouse_filter==Control.MOUSE_FILTER_IGNORE,"HUD never captures combat mouse")
    _check(p.weapons.status.modulate.a==0,"no duplicated top-left ammo")
    p.paused=true;await _key(scene,KEY_1)
    _check(bag.equipped("main_hand")==pistol and not q.view_r01.visible,"pause suppresses weapon input and HUD")
    p.paused=false
    # Actual I/H open and close the unchanged C05 panels.
    p.scripted=false
    await _key(scene,KEY_I);_check(p.hud_open,"I inventory opens")
    await _key(scene,KEY_I);await _key(scene,KEY_H);_check(p.hud_open,"H body panel opens")
    await _key(scene,KEY_H);p.scripted=true
    _check(not p.hud_open,"panels close without sticking")
    FileAccess.open("res://qa/hud_r01/results.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info(),"checks":checks,"captures":captures,"passed":true,"profile":"QA only; gameplay save untouched","gamepad":"No physical controller tested"},"  "))
    print("HUD_R01_OK ",checks.size());get_tree().quit()
