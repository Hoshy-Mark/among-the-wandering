extends "res://personagem/qa_social101.gd"
func check(value: bool,message: String) -> void:
    if not value:push_error("R102_FAIL "+message);get_tree().quit(1);assert(value,message)
    checks.append(message);print("R102_CHECK ",message)
func key(scene: Node,code: int) -> void:
    for pressed in [true,false]:
        var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event);await frames(scene,1)
func learning_stream(model: RefCounted) -> String:
    for n in range(1,10000):
        var rng=RandomNumberGenerator.new();rng.seed=n;var before=str(rng.state)
        var a=model.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),2,10)
        var b=model.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),2,9)
        var c=model.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),3,10)
        if not a and not b and c:return before
    assert(false);return ""
func click_control(scene: Node,control: Control) -> void:
    var position=control.get_global_rect().get_center()
    var motion=InputEventMouseMotion.new();motion.position=position;motion.global_position=position;Input.parse_input_event(motion);await frames(scene,1)
    for pressed in [true,false]:
        var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=position;event.global_position=position;Input.parse_input_event(event);await frames(scene,1)
func capture102(scene: Node,name: String) -> void:
    await frames(scene,6);await RenderingServer.frame_post_draw
    check(scene.get_viewport().get_texture().get_image().save_png("res://qa/learning102/"+name+".png")==OK,"native capture "+name)
func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/learning102"))
    var p=scene.player;var m=scene.get_node("Characters99");var ui=m.skills_ui;var quick=p.get_node("Atalhos93");var world=scene.zombie_world
    h._freeze98(scene);h._player_idle(p);quick.scripted=false
    p.condition_path="res://qa/learning102/checkpoint.json";scene.get_window().size=Vector2i(1280,720)
    if "--learning102-reopen" in OS.get_cmdline_user_args():
        check(p.load_condition(),"fresh process loads full checkpoint")
        var expected=m.social.validate(JSON.parse_string(FileAccess.get_file_as_string("res://qa/learning102/expected.json")))
        check(not expected.is_empty() and m.social.snapshot()==expected,"fresh process keeps skill ledger relationships outcomes and RNG")
        check(m.social.data.skills.persuasion==3 and m.social.available_points()==0 and m.social.experience_progress()==1,"fresh process cannot refund learning point")
        check(world.saved.size()==480 and p.weapons.loaded(p.bag_inventory.equipped("main_hand"))==6 and quick.bindings.size()==1,"fresh process preserves population ammo and quickslot")
        check(m.open("samuel_henrique") and option(m,"calm").state=="exhausted" and option(m,"observe").state=="exhausted","fresh process cannot repeat completed checks")
        m.close();FileAccess.open("res://qa/learning102/fresh.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks},"  "))
        print("R102_FRESH_OK ",checks.size());get_tree().quit();return
    var initial=m.social.snapshot();initial.rng_state=learning_stream(m.social)
    check(m.social.restore(initial),"controlled random stream for native UI")
    check(scene.city.get_node("ResidentialInteriors").homes.size()==39 and scene.world_items.house!=null,"current map contains 39 current homes plus H01 compatibility adapter")
    check(world.saved.size()==480 and m.actors.size()==1 and m.registry.definitions.size()==9,"fixed population and existing NPC roster preserved")
    var helper=load("res://personagem/qa_personagens99.gd").new();add_child(helper)
    var point=await helper.approach(scene,m);check(point!=null,"Samuel reachable on current map")
    var samuel=m.actors.samuel_henrique;var facing=samuel.global_position-p.global_position
    p.avatar.rotation.y=atan2(facing.x,facing.z);samuel.avatar.rotation.y=p.avatar.rotation.y+PI
    scene.focus=(p.global_position+samuel.global_position)*.5+Vector3.UP*.85;scene.zoom=6;scene._update_camera();m._process(0)
    var inventory=p.bag_inventory.items.duplicate(true);var ammo=p.weapons.rounds.duplicate(true);var running=world.motor.running
    await key(scene,KEY_E)
    check(m.active=="samuel_henrique" and p.hud_open,"actual E opens D02 conversation")
    await key(scene,KEY_P)
    check(not ui.opened and world.motor.running==running,"P during conversation cannot open skill screen or pause population")
    await key(scene,KEY_1);await key(scene,KEY_ENTER)
    check(m.social.data.learning102.earned.size()==1,"actual first topic earns one experience")
    await key(scene,KEY_1);await key(scene,KEY_ENTER)
    check(m.social.data.learning102.earned.size()==1,"repeat question gives no extra experience")
    await key(scene,KEY_3)
    var first=m.social.data.progress.samuel_henrique.checks.calm_request[0].duplicate(true)
    check(not first.success,"actual first persuasion roll fails")
    await key(scene,KEY_ENTER);await key(scene,KEY_4);await key(scene,KEY_ENTER)
    check(not m.social.data.progress.samuel_henrique.checks.observe[0].success and m.social.available_points()==1,"third distinct experience grants point after observation failure")
    check(not option(m,"calm").available,"unchanged failed check remains unavailable")
    check(m.view_d02.lines.any(func(line):return line.speaker=="Aprendizado"),"point award appears in chronological D02 history")
    await capture102(scene,"01_aprendizado")
    await key(scene,KEY_ESCAPE);await key(scene,KEY_P);await frames(scene)
    quick._process(0)
    check(ui.opened and p.hud_open and not p.paused and not quick.view_r01.visible,"actual P opens skills and blocks combat without pausing world")
    check(world.motor.running==running,"P does not trigger inherited laboratory population pause")
    check(ui.summary.text.contains("1") and not ui.buttons.persuasion.disabled,"real model point shown with enabled training")
    check(ui.panel.size.y<=400 and ui.panel.get_global_rect().end.y<=680,"first opening settles wrapped text into compact centered panel")
    await capture102(scene,"02_habilidades")
    var before=m.social.snapshot()
    await click_control(scene,ui.buttons.persuasion)
    check(m.social.data.skills.persuasion==3 and m.social.available_points()==0 and ui.buttons.persuasion.disabled,"actual GUI click spends exactly one point on persuasion")
    check(m.social.data.rng_state==before.rng_state and m.social.data.progress==before.progress and m.social.data.relations==before.relations,"allocation does not rewrite dice or relationships")
    check(not ui.train("perception"),"no second allocation without another point")
    check(p.bag_inventory.items==inventory and p.weapons.rounds==ammo,"skill panel click does not fire or modify manual inventory")
    await capture102(scene,"03_ponto_aplicado")
    scene.get_window().size=Vector2i(960,640);await frames(scene,8)
    check(ui.panel.get_global_rect().end.x<=960 and ui.panel.get_global_rect().end.y<=640,"skills fit smaller native viewport")
    await capture102(scene,"04_habilidades_960")
    scene.get_window().size=Vector2i(1280,720);await frames(scene,8)
    await key(scene,KEY_P);await key(scene,KEY_E)
    check(option(m,"calm").available and option(m,"calm").text.contains("58%"),"training reopens failed persuasion at improved 58 percent")
    await capture102(scene,"05_chance_melhorada")
    await key(scene,KEY_3)
    var attempts=m.social.data.progress.samuel_henrique.checks.calm_request
    check(attempts.size()==2 and attempts[0]==first and attempts[1].success and attempts[1].score==3,"actual retry succeeds while preserving original failed outcome")
    check(m.social.data.learning102.earned.size()==3 and m.social.available_points()==0,"retry cannot farm another experience")
    await capture102(scene,"06_sucesso")
    await key(scene,KEY_ENTER);await key(scene,KEY_2);await key(scene,KEY_ENTER)
    check(m.social.experience_progress()==1 and m.social.available_points()==0,"fourth unique activity carries experience remainder")
    check(not m.social.knows("player","ricardo_alberto_criminal_past"),"learning never discloses private narrative facts")
    m.close();p.scripted=false;await key(scene,KEY_P);await key(scene,KEY_I)
    check(not ui.opened and scene.game_ui.personal.visible,"I transitions from skills to unchanged C05 inventory")
    await key(scene,KEY_I);await key(scene,KEY_P);await key(scene,KEY_H)
    check(not ui.opened and scene.game_ui.windows[1].visible,"H transitions from skills to existing body HUD")
    await key(scene,KEY_H);p.scripted=true;await key(scene,KEY_P)
    p.reaction.started.emit("hit");await frames(scene)
    check(not ui.opened and not p.hud_open,"reaction closes skills without residual control lock")
    p.global_position=scene.spawn;p.update_nearby();var pistol=h._equip92(scene,"pistol")
    check(quick.bind("left",pistol),"existing weapon shortcut accepts pistol")
    check(p.place_item(h._find_weapon(p.bag_inventory,"ammo_pistol"),"pockets",2,0,false),"manual C05 ammo placement preserved");h._settle93(scene)
    check(p.weapons.reload_weapon(),"existing firearm reload works");h._settle93(scene)
    p.global_position=point;p.update_nearby();check(p.save_condition(),"full game checkpoint saves learning ledger")
    var expected=m.social.snapshot();FileAccess.open("res://qa/learning102/expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
    var saved_inventory=p.bag_inventory.items.duplicate(true)
    m.social.restore(null);check(p.load_condition() and m.social.snapshot()==expected,"actual load restores skills spent point and resolved history")
    check(p.bag_inventory.items==saved_inventory and p.weapons.loaded(pistol)==6 and quick.bindings.left==pistol,"load preserves manual inventory ammunition and equipment")
    var current=p.session_save.snapshot();var invalid=current.duplicate(true);invalid.social101.learning102.spent.persuasion=9
    check(p.session_save.prepare(invalid,false).is_empty() and m.social.snapshot()==expected,"invalid learning ledger rejected before mutation")
    var legacy=current.duplicate(true);legacy.social101.version=1;legacy.social101.erase("learning102")
    FileAccess.open("res://qa/learning102/legacy101.json",FileAccess.WRITE).store_string(JSON.stringify(legacy));p.condition_path="res://qa/learning102/legacy101.json"
    check(p.load_condition() and m.social.data.skills.persuasion==3 and m.social.available_points()==1,"actual R101 migration credits performed history without changing skill baseline")
    check(m.social.restore(m.social.snapshot()) and m.social.available_points()==1,"migration cannot double reward on repeated normalization")
    p.condition_path="res://qa/learning102/checkpoint.json";check(p.load_condition() and m.social.snapshot()==expected,"restore paid checkpoint after migration test")
    await key(scene,KEY_P);await key(scene,KEY_ESCAPE);quick._process(0)
    check(not ui.opened and not p.hud_open and quick.view_r01.visible and world.motor.running==running,"Escape returns gameplay weapon HUD and population without residual locks")
    FileAccess.open("res://qa/learning102/results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks,"balance":"candidate: three distinct activities per point","map":"current map lab; H01 compatibility adapter preserved"},"  "))
    print("R102_OK ",checks.size());get_tree().quit()
