extends "res://isometric_test.gd"
var shoulder: Node3D
var zombie_world: Node3D
var demo_ready=false
var demo_data: Dictionary
var loading_cover: CanvasLayer

func _ready() -> void:
    await super._ready()
    var args=OS.get_cmdline_user_args()
    # Keep the preserved laboratory suites running on their original fixtures.
    for arg in args:
        if (str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) and arg not in ["--qa-demo","--capture-demo","--qa-doors","--capture-doors","--qa-windows","--capture-windows","--qa-variants","--capture-variants","--qa-traversals","--capture-traversals","--qa-fences","--capture-fences","--qa-combat-map","--capture-combat-map","--qa-health-effects","--capture-health-effects","--qa-session","--capture-session","--qa-zombies","--capture-zombies","--qa-zombie-traversals","--capture-zombie-traversals","--qa-zombie-navigation","--capture-zombie-navigation","--qa-zombie-encounters","--capture-zombie-encounters","--qa-weapons","--capture-weapons","--qa-firearms","--capture-firearms","--qa-shoulder","--capture-shoulder","--qa-camera-world","--capture-camera-world","--qa-pistol-pose","--capture-pistol-pose","--qa-shots","--capture-shots","--qa-arsenal","--capture-arsenal","--qa-quickslots","--capture-quickslots","--qa-zombie-cycle","--capture-zombie-cycle","--qa-demo95","--capture-demo95","--qa-population98","--capture-population98"]:
            return
    var current_supplies112=not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-demo95" in args or "--capture-demo95" in args or "--qa-population98" in args or "--capture-population98" in args
    demo_data=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/demo_supplies112.json" if current_supplies112 else "res://personagem/demo_h01_73.json"))
    player.demo_mode=true
    demo_data.profile="user://demo_population_map117.json" if city.get_meta("spatial_revision_enabled",false) else "user://demo_population_r98.json"
    player.condition_path=demo_data.profile
    if not _new_inventory():
        push_error("Invalid H01 inventory configuration")
        return
    for fixture in fixtures.values():
        remove_child(fixture)
        fixture.queue_free()
    fixtures.clear()
    if is_instance_valid(training_target):
        remove_child(training_target)
        training_target.queue_free()
    player.combat_target=null
    hud.visible=false
    var house: Node3D=world_items.house
    var spawn_values: Array=house.spawn_local117 if city.get_meta("spatial_revision_enabled",false) else demo_data.spawn_local
    var point: Vector3=house.home.model.to_global(Vector3(spawn_values[0],spawn_values[1],spawn_values[2]))
    assert(house.standing_clear(point-Vector3.UP*.02))
    player.global_position=point
    player.velocity=Vector3.ZERO
    spawn=point
    var doors=load("res://personagem/aberturas113.gd").new()
    add_child(doors)
    doors.setup(self)
    if city.get_meta("spatial_revision_enabled",false):world_items.configure_windows117()
    await get_tree().physics_frame
    await get_tree().physics_frame
    doors.calibrate_map118()
    if not ("--qa-doors" in args or "--capture-doors" in args or "--qa-windows" in args or "--capture-windows" in args or "--qa-variants" in args or "--capture-variants" in args):
        var traversals=load("res://personagem/travessias77.gd").new()
        add_child(traversals)
        traversals.setup(self)
        var fences=load("res://personagem/cercamentos78.gd").new()
        fences.name="Cercamentos78"
        add_child(fences)
        fences.setup(self)
    var final_mode=not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-demo95" in args or "--capture-demo95" in args or "--current-demo95" in args or "--qa-population98" in args or "--capture-population98" in args
    var cycle_mode=final_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-zombie-cycle" in args or "--capture-zombie-cycle" in args or "--current-zombies" in args
    var quick_mode=cycle_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-quickslots" in args or "--capture-quickslots" in args
    var arsenal_mode=quick_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-arsenal" in args or "--capture-arsenal" in args
    var shots_mode=arsenal_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-shots" in args or "--capture-shots" in args
    var pose_mode=shots_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-pistol-pose" in args or "--capture-pistol-pose" in args
    var camera_world_mode=pose_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-camera-world" in args or "--capture-camera-world" in args
    var shoulder_mode=camera_world_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-shoulder" in args or "--capture-shoulder" in args
    var firearm_mode=shoulder_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-firearms" in args or "--capture-firearms" in args
    var weapon_mode=firearm_mode or not Array(args).any(func(arg):return str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) or "--qa-weapons" in args or "--capture-weapons" in args
    var combat_map=load("res://personagem/combate_mapa95.gd" if final_mode else "res://personagem/combate_mapa92.gd" if arsenal_mode else "res://personagem/combate_mapa91.gd" if shots_mode else "res://personagem/combate_mapa88.gd" if shoulder_mode else "res://personagem/combate_mapa87.gd" if firearm_mode else "res://personagem/combate_mapa86.gd" if weapon_mode else "res://personagem/combate_mapa79.gd").new()
    add_child(combat_map)
    combat_map.setup(self)
    var survival=load("res://personagem/sobrevivencia80.gd").new()
    add_child(survival)
    survival.setup(self)
    if weapon_mode:
        var weapons=load("res://personagem/armas92.gd" if arsenal_mode else "res://personagem/armas90.gd" if pose_mode else "res://personagem/armas87.gd" if firearm_mode else "res://personagem/armas86.gd").new();add_child(weapons);weapons.setup(self)
        var initial=player.bag_inventory.get_script().new();initial.house_anchors=player.bag_inventory.house_anchors.duplicate(true)
        var seeded=initial.restore(player.bag_inventory.snapshot(),false) and (city.get_meta("spatial_revision_enabled",false) or weapons.seed(initial))
        if not seeded:push_error("Could not seed melee items");return
        player.bag_inventory.restore(initial.snapshot(),false);player.bag_inventory.changed.emit()
    if shoulder_mode:
        shoulder=load("res://personagem/mira_armas92.gd" if arsenal_mode else "res://personagem/mira_tiros91.gd" if shots_mode else "res://personagem/mira_ambiente89.gd" if camera_world_mode else "res://personagem/mira_ombro88.gd").new();add_child(shoulder);shoulder.setup(self)
    var verification_mode=false
    for arg in args:
        if str(arg).begins_with("--qa") or str(arg).begins_with("--capture"):verification_mode=true
    var with_enemies=firearm_mode or not verification_mode or "--qa-zombies" in args or "--capture-zombies" in args or "--qa-zombie-traversals" in args or "--capture-zombie-traversals" in args or "--qa-zombie-navigation" in args or "--capture-zombie-navigation" in args or "--qa-zombie-encounters" in args or "--capture-zombie-encounters" in args or "--qa-weapons" in args or "--capture-weapons" in args
    if with_enemies:
        var crossings=firearm_mode or not verification_mode or "--qa-zombie-traversals" in args or "--capture-zombie-traversals" in args or "--qa-zombie-navigation" in args or "--capture-zombie-navigation" in args or "--qa-zombie-encounters" in args or "--capture-zombie-encounters" in args or "--qa-weapons" in args or "--capture-weapons" in args
        var routes=firearm_mode or not verification_mode or "--qa-zombie-navigation" in args or "--capture-zombie-navigation" in args or "--qa-zombie-encounters" in args or "--capture-zombie-encounters" in args or "--qa-weapons" in args or "--capture-weapons" in args
        var encounters=firearm_mode or not verification_mode or "--qa-zombie-encounters" in args or "--capture-zombie-encounters" in args or "--qa-weapons" in args or "--capture-weapons" in args
        zombie_world=load("res://personagem/zumbis98.gd" if final_mode else "res://personagem/zumbis94.gd" if cycle_mode else "res://personagem/zumbis91.gd" if shots_mode else "res://personagem/zumbis87.gd" if firearm_mode else "res://personagem/zumbis85.gd" if encounters else "res://personagem/zumbis84.gd" if routes else "res://personagem/zumbis83.gd" if crossings else "res://personagem/zumbis82.gd").new()
        add_child(zombie_world);zombie_world.setup(self)
    if quick_mode:
        var quick=load("res://personagem/atalhos_hud_r01.gd").new();quick.name="Atalhos93";player.add_child(quick);quick.setup(self)
    if final_mode:
        var characters=load("res://personagem/personagens109.gd").new();characters.name="Characters99";add_child(characters);characters.setup(self)
    var session_save=load("res://personagem/map117/session.gd" if city.get_meta("spatial_revision_enabled",false) else "res://personagem/partida107.gd" if final_mode else "res://personagem/partida93.gd" if quick_mode else "res://personagem/partida92.gd" if arsenal_mode else "res://personagem/partida87.gd" if firearm_mode else "res://personagem/partida86.gd" if weapon_mode else "res://personagem/partida82.gd" if with_enemies else "res://personagem/partida81.gd").new()
    if with_enemies:session_save.enemies=zombie_world
    add_child(session_save)
    session_save.setup(self)
    if city.get_meta("spatial_revision_enabled",false):
        await get_tree().physics_frame
        session_save.reconcile_population117()
    if final_mode:
        var demo=load("res://personagem/demo95.gd").new();demo.name="Demo95";player.add_child(demo);demo.setup(self)
    player.update_nearby()
    zoom=6.5
    focus=point+Vector3.UP*.95
    _update_camera()
    game_ui.personal.visible=false
    game_ui.nearby_wanted=false
    game_ui.nearby.visible=false
    game_ui.windows[1].visible=false
    game_ui.refresh()
    var help=Label.new()
    help.text="WASD · mover    Shift · correr    I · inventário    E · interagir    B · atravessar    Botão direito · mirar    Esquerdo · atirar    R · recarregar    Q/F · corpo a corpo    Espaço · empurrar"
    help.position=Vector2(20, get_viewport().get_visible_rect().size.y-34)
    help.mouse_filter=Control.MOUSE_FILTER_IGNORE
    game_ui.add_child(help)
    get_viewport().size_changed.connect(func():help.position.y=get_viewport().get_visible_rect().size.y-34)
    var verification=false
    for arg in args:
        if str(arg).begins_with("--qa") or str(arg).begins_with("--capture"):verification=true
    var supplies_preview112="--preview-supplies112" in args
    var fresh95=bool(get_tree().get_meta("demo95_fresh",false)) if final_mode else false
    var resume95=bool(get_tree().get_meta("demo95_resume",false)) if final_mode else false
    if final_mode:
        if get_tree().has_meta("demo95_fresh"):get_tree().remove_meta("demo95_fresh")
        if get_tree().has_meta("demo95_resume"):get_tree().remove_meta("demo95_resume")
        var override95=str(get_tree().get_meta("demo95_profile_override",""))
        if not override95.is_empty():player.condition_path=override95
    if supplies_preview112:player.condition_path="user://preview_supplies112.json"
    if final_mode and not verification and not fresh95 and not supplies_preview112 and not "--map117-test" in args and not FileAccess.file_exists(player.condition_path):
        var legacy_path="user://demo_population_r98.json" if city.get_meta("spatial_revision_enabled",false) else "user://demo_h01_inventory_r73.json"
        for candidate in [legacy_path,legacy_path+".bak"]:
            if not FileAccess.file_exists(candidate):continue
            if session_save.prepare(session_save._read(candidate)).is_empty():continue
            var legacy_file=FileAccess.open(player.condition_path,FileAccess.WRITE)
            if legacy_file!=null:legacy_file.store_string(FileAccess.get_file_as_string(candidate));legacy_file.close()
            break
    if not fresh95 and ((not verification and (FileAccess.file_exists(player.condition_path) or FileAccess.file_exists(player.condition_path+".bak"))) or resume95):
        if player.load_condition():game_ui.feedback.text=player.inventory_message
        else:
            game_ui.feedback.text=player.inventory_message
            if resume95:player.get_node("Demo95").load_failure(player.inventory_message)
    if loading_cover!=null:
        loading_cover.queue_free()
    demo_ready=true
    # Catalog snapshots accelerate assembly; gameplay owns the returned copies.
    if city.has_method("invalidate_catalogs114"):city.invalidate_catalogs114()
    if "--probe-route" in args:
        await get_tree().physics_frame
        for x in range(-280,90,10):
            var clear=true
            for z in [-.4,-.65,-.9]:
                if not house.standing_clear(house.home.model.to_global(Vector3(x/100.0,.255,z))):clear=false
            if clear:print("KITCHEN_GAP ",x/100.0)
        get_tree().quit()
        return
    if "--map117-test" in args:
        var qa=load("res://personagem/map117/qa.gd").new();add_child(qa);qa.run(self);return
    if "--supplies112-test" in args:
        var qa=load("res://personagem/qa_supplies112.gd").new();add_child(qa);qa.run(self)
        return
    if "--social109-test" in args:
        var qa=load("res://personagem/qa_social109.gd").new();add_child(qa);qa.run(self)
        return
    if "--menu108-test" in args:
        var qa=load("res://personagem/menu108/qa.gd").new();add_child(qa);qa.run(self)
        return
    if "--menu107-test" in args:
        var qa=load("res://personagem/menu107/qa.gd").new();add_child(qa);qa.run(self)
        return
    if "--characters106-test" in args:
        var qa=load("res://personagem/qa_characters106.gd").new();add_child(qa);qa.run(self)
        return
    if "--characters105-test" in args:
        var qa=load("res://personagem/qa_characters105.gd").new();add_child(qa);qa.run(self)
        return
    if "--characters104-test" in args:
        var qa=load("res://personagem/qa_characters104.gd").new();add_child(qa);qa.run(self)
        return
    if "--characters103-test" in args:
        var qa=load("res://personagem/qa_characters103.gd").new();add_child(qa);qa.run(self)
        return
    if "--learning102-test" in args:
        var qa=load("res://personagem/qa_learning102.gd").new();add_child(qa);qa.run(self)
        return
    if "--social101-test" in args:
        var qa=load("res://personagem/qa_social101.gd").new();add_child(qa);qa.run(self)
        return
    if "--dialogue-d02-test" in args:
        var qa=load("res://personagem/qa_dialogo_d02.gd").new();add_child(qa);qa.run(self)
        return
    if "--characters99-test" in args:
        var qa=load("res://personagem/qa_personagens99.gd").new();add_child(qa);qa.run(self)
        return
    if "--hud-r01-test" in args:
        var qa=load("res://personagem/qa_hud_r01.gd").new();add_child(qa);qa.run(self)
        return
    if "--qa-population98" in args or "--capture-population98" in args:
        var qa=load("res://personagem/qa_host98.gd").new();qa.name="QAHost98";add_child(qa);qa.setup(self)
        return
    if "--qa-demo95" in args or "--capture-demo95" in args:
        await load("res://personagem/revisao95.gd").new().run(self)
        return
    if "--qa-zombie-cycle" in args or "--capture-zombie-cycle" in args:
        await load("res://personagem/revisao94.gd").new().run(self)
        return
    if "--qa-quickslots" in args or "--capture-quickslots" in args:
        await load("res://personagem/revisao93.gd").new().run(self)
        return
    if "--qa-arsenal" in args or "--capture-arsenal" in args:
        await load("res://personagem/revisao92.gd").new().run(self)
        return
    if "--qa-shots" in args or "--capture-shots" in args:
        await load("res://personagem/revisao91.gd").new().run(self)
        return
    if "--qa-pistol-pose" in args or "--capture-pistol-pose" in args:
        await load("res://personagem/revisao90.gd").new().run(self)
        return
    if "--qa-camera-world" in args or "--capture-camera-world" in args:
        await load("res://personagem/revisao89.gd").new().run(self)
        return
    if "--qa-shoulder" in args or "--capture-shoulder" in args:
        await load("res://personagem/revisao88.gd").new().run(self)
        return
    if "--qa-firearms" in args or "--capture-firearms" in args:
        await load("res://personagem/revisao87.gd").new().run(self)
        return
    if "--qa-weapons" in args or "--capture-weapons" in args:
        await load("res://personagem/revisao86.gd").new().run(self)
        return
    if "--qa-zombie-encounters" in args or "--capture-zombie-encounters" in args:
        await load("res://personagem/revisao85.gd").new().run(self)
        return
    if "--qa-zombie-navigation" in args or "--capture-zombie-navigation" in args:
        await load("res://personagem/revisao94_navegacao.gd" if "--current-zombies" in args else "res://personagem/revisao84.gd").new().run(self)
        return
    if "--qa-zombie-traversals" in args or "--capture-zombie-traversals" in args:
        await load("res://personagem/revisao83.gd").new().run(self)
        return
    if "--qa-zombies" in args or "--capture-zombies" in args:
        await load("res://personagem/revisao82.gd").new().run(self)
        return
    if "--qa-session" in args or "--capture-session" in args:
        await load("res://personagem/revisao81.gd").new().run(self)
        return
    if "--qa-health-effects" in args or "--capture-health-effects" in args:
        await load("res://personagem/revisao80.gd").new().run(self)
        return
    if "--qa-combat-map" in args or "--capture-combat-map" in args:
        await load("res://personagem/revisao79.gd").new().run(self)
        return
    if "--qa-fences" in args or "--capture-fences" in args:
        await load("res://personagem/revisao78.gd").new().run(self)
        return
    if "--qa-traversals" in args or "--capture-traversals" in args:
        await load("res://personagem/revisao77.gd").new().run(self)
        return
    if "--qa-variants" in args or "--capture-variants" in args:
        await load("res://personagem/revisao76.gd").new().run(self)
        return
    if "--qa-windows" in args or "--capture-windows" in args:
        await load("res://personagem/revisao75.gd").new().run(self)
        return
    if "--qa-doors" in args or "--capture-doors" in args:
        await load("res://personagem/revisao74.gd").new().run(self)
        return
    if "--qa-demo" in args or "--capture-demo" in args:
        await load("res://personagem/revisao73.gd").new().run(self)

func _new_inventory() -> bool:
    if city.get_meta("spatial_revision_enabled",false):return world_items.bootstrap(demo_data)
    var model: RefCounted=player.bag_inventory
    var service=load("res://personagem/abastecimento112.gd").new()
    var prepared=service.prepare(model,demo_data)
    if not prepared.ok:
        player.inventory_message=prepared.reason
        return false
    if not service.commit(model,prepared):return false
    world_items.close_interaction()
    model.changed.emit()
    player.update_nearby()
    game_ui.cancel_pending()
    game_ui.refresh()
    return true

func _unhandled_input(event: InputEvent) -> void:
    if demo_ready and event is InputEventKey and event.physical_keycode==KEY_F1:
        get_viewport().set_input_as_handled()
        return
    super._unhandled_input(event)

func _interface() -> void:
    super._interface()
    for arg in OS.get_cmdline_user_args():
        if (str(arg).begins_with("--qa") or str(arg).begins_with("--capture")) and arg not in ["--qa-demo","--capture-demo","--qa-doors","--capture-doors","--qa-windows","--capture-windows","--qa-variants","--capture-variants","--qa-traversals","--capture-traversals","--qa-fences","--capture-fences","--qa-combat-map","--capture-combat-map","--qa-health-effects","--capture-health-effects","--qa-session","--capture-session","--qa-zombies","--capture-zombies","--qa-zombie-traversals","--capture-zombie-traversals","--qa-zombie-navigation","--capture-zombie-navigation","--qa-zombie-encounters","--capture-zombie-encounters","--qa-weapons","--capture-weapons","--qa-firearms","--capture-firearms","--qa-shoulder","--capture-shoulder","--qa-camera-world","--capture-camera-world","--qa-pistol-pose","--capture-pistol-pose","--qa-shots","--capture-shots","--qa-arsenal","--capture-arsenal","--qa-quickslots","--capture-quickslots","--qa-zombie-cycle","--capture-zombie-cycle","--qa-demo95","--capture-demo95","--qa-population98","--capture-population98"]:
            return
    loading_cover=CanvasLayer.new()
    loading_cover.layer=90
    add_child(loading_cover)
    var cover=ColorRect.new()
    cover.color=Color("19211e")
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    loading_cover.add_child(cover)
    var label=Label.new()
    label.text="Carregando..."
    label.position=Vector2(28,28)
    cover.add_child(label)

func _update_camera() -> void:
    if shoulder!=null and shoulder.owns_camera():return
    super._update_camera()
