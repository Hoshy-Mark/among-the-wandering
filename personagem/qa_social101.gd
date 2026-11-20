extends Node
var h=load("res://personagem/revisao98.gd").new()
var checks=[]
func check(value: bool,message: String) -> void:
    if not value:push_error("R101_FAIL "+message);get_tree().quit(1);assert(value,message)
    checks.append(message);print("R101_CHECK ",message)
func frames(scene: Node,n: int=4) -> void:
    for tick in n:await scene.get_tree().process_frame
func key(scene: Node,code: int) -> void:
    var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;Input.parse_input_event(event);await frames(scene,1)
    event=InputEventKey.new();event.physical_keycode=code;event.pressed=false;Input.parse_input_event(event);await frames(scene,1)
func capture(scene: Node,name: String) -> void:
    await frames(scene,6);await RenderingServer.frame_post_draw
    check(scene.get_viewport().get_texture().get_image().save_png("res://qa/social101/"+name+".png")==OK,"native capture "+name)
func option(m: Node,id: String) -> Dictionary:
    for row in m.view_d02.current_options:
        if row.option_id==id:return row
    return {}
func select(m: Node,id: String) -> void:
    var row=option(m,id);assert(not row.is_empty(),id);m._choose_d02(row.id)
func initial_roll_state(m: RefCounted) -> String:
    for n in range(1,1000):
        var rng=RandomNumberGenerator.new();rng.seed=n;var before=str(rng.state)
        var first=m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),2,10)
        var second=m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),3,10)
        if not first and second:return before
    assert(false);return ""
func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/social101"))
    var p=scene.player;var m=scene.get_node("Characters99");var quick=p.get_node("Atalhos93");var world=scene.zombie_world
    h._freeze98(scene);h._player_idle(p);quick.scripted=false
    p.condition_path="res://qa/social101/checkpoint.json";scene.get_window().size=Vector2i(1280,720)
    if "--social101-reopen" in OS.get_cmdline_user_args():
        check(p.load_condition(),"fresh process loads full social checkpoint")
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/social101/expected.json"))
        expected=m.social.validate(expected)
        check(not expected.is_empty() and m.social.snapshot()==expected,"fresh process keeps knowledge relations attempts and RNG state")
        check(m.open("samuel_henrique"),"fresh process opens conversation")
        check(option(m,"calm").state=="exhausted" and option(m,"observe").state=="exhausted" and option(m,"privacy").state=="exhausted","fresh process cannot reroll or farm completed actions")
        check(world.saved.size()==480 and p.weapons.loaded(p.bag_inventory.equipped("main_hand"))==6 and quick.bindings.size()==1,"fresh process preserves population weapon ammo and quickslot")
        m.close();FileAccess.open("res://qa/social101/fresh.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks},"  "))
        print("R101_FRESH_OK");get_tree().quit();return
    # A test seed with failure followed by success. Production never forces dice.
    var baseline=m.social.snapshot();baseline.rng_state=initial_roll_state(m.social);check(m.social.restore(baseline),"controlled QA random stream")
    var helper=load("res://personagem/qa_personagens99.gd").new();add_child(helper)
    var point=await helper.approach(scene,m);check(point!=null,"current-map encounter reachable")
    var samuel=m.actors.samuel_henrique;var facing=samuel.global_position-p.global_position
    p.avatar.rotation.y=atan2(facing.x,facing.z);samuel.avatar.rotation.y=p.avatar.rotation.y+PI
    scene.focus=(p.global_position+samuel.global_position)*.5+Vector3.UP*.85;scene.zoom=6;scene._update_camera();m._process(0)
    var inventory=p.bag_inventory.items.duplicate(true);var ammo=p.weapons.rounds.duplicate(true)
    await key(scene,KEY_E)
    check(m.active=="samuel_henrique" and not m.prompt.visible and p.hud_open,"actual E opens social conversation in D02")
    check(option(m,"calm").is_empty() and option(m,"personal").state=="locked","unknown topic hidden, personal topic visibly blocked")
    check(m.view_d02.relationship_hint.text.contains("Intimidade"),"relationship context displayed")
    await capture(scene,"01_inicio")
    await key(scene,KEY_1)
    check(m.social.node=="origin" and m.social.knows("player","samuel_returned"),"actual numeric reply transitions and learns public fact")
    await key(scene,KEY_ENTER)
    check(option(m,"origin").state=="visited" and option(m,"origin").available and option(m,"calm").available and option(m,"calm").text.contains("42%"),"repeatable topic marked used and discovered check shows actual odds")
    await key(scene,KEY_1);await key(scene,KEY_ENTER)
    check(m.social.data.knowledge.player.count("samuel_returned")==1 and m.social.relation("samuel_henrique","player").trust==0,"public topic can be reread without farming facts or trust")
    await key(scene,KEY_3)
    var first=m.social.data.progress.samuel_henrique.checks.calm_request[0].duplicate(true)
    check(not first.success and m.social.node=="calm_no","actual failed dice enter failure branch")
    check(m.view_d02.lines.any(func(line):return line.has("dice") and line.text.contains("FALHA")),"dice and resolved failure displayed in chronological history")
    await capture(scene,"02_falha_dados")
    await key(scene,KEY_ENTER)
    check(not option(m,"calm").available,"failure cannot immediately retry")
    var blocked=option(m,"calm").id;var before=m.social.snapshot();m._choose_d02(blocked)
    check(m.social.snapshot()==before,"direct stale or locked callback cannot reroll")
    await key(scene,KEY_ESCAPE);await key(scene,KEY_E)
    check(not option(m,"calm").available and m.social.data.progress.samuel_henrique.checks.calm_request[0]==first,"closing and reopening preserve failed attempt")
    await capture(scene,"03_tentativa_bloqueada")
    var privacy_token=option(m,"privacy").id
    await key(scene,KEY_2);await key(scene,KEY_ENTER)
    check(m.social.relation("samuel_henrique","player").trust==1 and m.social.relation("samuel_henrique","player").respect==2,"authored respectful choice changes distinct relationship dimensions")
    check(m.social.relation("player","samuel_henrique").trust==0 and m.social.relation("jorge_luiz","player").trust==0,"changes do not spread to reverse edge or other NPC")
    check(option(m,"calm").available and option(m,"calm").text.contains("58%"),"new relevant context reopens check with improved exact chance")
    before=m.social.snapshot();m._choose_d02(privacy_token);check(m.social.snapshot()==before,"replayed choice cannot duplicate social effects")
    await capture(scene,"04_chance_melhorada")
    await key(scene,KEY_3)
    var attempts=m.social.data.progress.samuel_henrique.checks.calm_request
    check(attempts.size()==2 and not attempts[0].success and attempts[1].success and attempts[1].score>attempts[0].score,"second actual roll succeeds once with improved context")
    check(m.social.relation("samuel_henrique","player").trust==2 and m.social.relation("samuel_henrique","player").intimacy==1,"successful branch evolves trust and intimacy separately")
    await frames(scene,6)
    var scroll=m.view_d02.history_scroll.get_v_scroll_bar()
    check(scroll.value>=scroll.max_value-scroll.page-1,"latest dice result remains visible after response-area resizing")
    await capture(scene,"05_sucesso_dados")
    await key(scene,KEY_ENTER)
    check(option(m,"calm").state=="exhausted" and option(m,"personal").available,"completed check stays resolved; relationship unlocks personal question")
    select(m,"personal");check(m.social.current_line().text=="Prefiro deixar esse assunto para outro momento.","unlocked question still respects NPC disclosure boundary")
    check(not m.social.knows("player","ricardo_alberto_criminal_past") and not m.social.knows("player","jorge_crimes_sorriso_feliz"),"no private narrative facts leaked by dice or intimacy")
    await capture(scene,"06_assunto_pessoal")
    select(m,"back");select(m,"observe");select(m,"back")
    check(option(m,"observe").state=="exhausted","single-attempt perception check stays resolved")
    check(m.social.validate(m.social.snapshot())==m.social.snapshot(),"current social state passes full validation")
    m.close();quick._process(0)
    check(not p.hud_open and quick.view_r01.visible and not p.paused,"gameplay and approved weapon HUD return")
    check(p.bag_inventory.items==inventory and p.weapons.rounds==ammo,"dialogue choices consume no inventory or ammunition")
    # Existing equipment and save flow; no parallel gameplay inventory.
    p.global_position=scene.spawn;p.update_nearby();var pistol=h._equip92(scene,"pistol")
    check(quick.bind("left",pistol),"existing explicit weapon shortcut")
    check(p.place_item(h._find_weapon(p.bag_inventory,"ammo_pistol"),"pockets",2,0,false),"existing manual ammo placement");h._settle93(scene)
    check(p.weapons.reload_weapon(),"existing reload after conversation");h._settle93(scene)
    p.global_position=point;p.update_nearby();check(p.save_condition(),"full social and world checkpoint saved")
    var expected=m.social.snapshot();FileAccess.open("res://qa/social101/expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
    var saved_inventory=p.bag_inventory.items.duplicate(true)
    check(m.social.restore(null) and m.social.relation("samuel_henrique","player").trust==0,"QA reset uses valid defaults")
    check(p.load_condition() and m.social.snapshot()==expected,"actual load restores directed relationships knowledge attempts and RNG")
    check(p.bag_inventory.items==saved_inventory and p.weapons.loaded(pistol)==6 and quick.bindings.left==pistol,"inventory ammo and quickslots survive social save extension")
    var current=p.session_save.snapshot();var invalid=current.duplicate(true);invalid.social101.progress.samuel_henrique.checks.calm_request[0].dice=[7,0]
    check(p.session_save.prepare(invalid,false).is_empty() and m.social.snapshot()==expected,"invalid social data rejected before mutation")
    var legacy=current.duplicate(true);legacy.erase("social101")
    FileAccess.open("res://qa/social101/legacy.json",FileAccess.WRITE).store_string(JSON.stringify(legacy));p.condition_path="res://qa/social101/legacy.json"
    check(p.load_condition() and m.registry.met.samuel_henrique and m.social.data.progress.samuel_henrique.visited.is_empty(),"real R99/R100 checkpoint migrates without fabricated social history")
    p.condition_path="res://qa/social101/checkpoint.json";check(p.load_condition(),"restore complete new checkpoint")
    check(world.saved.size()==480 and m.actors.size()==1 and m.registry.definitions.size()==9,"fixed population and existing human placement preserved")
    check(m.open("samuel_henrique") and option(m,"calm").state=="exhausted","loaded completed check remains completed in real UI")
    await capture(scene,"07_retomada")
    p.scripted=false;await key(scene,KEY_I)
    check(m.active.is_empty() and scene.game_ui.personal.visible and p.hud_open,"I transitions to unchanged C05 inventory")
    await key(scene,KEY_I);await key(scene,KEY_H)
    check(scene.game_ui.windows[1].visible,"body HUD preserved");await key(scene,KEY_H);p.scripted=true
    check(not p.hud_open,"no residual interface control lock")
    FileAccess.open("res://qa/social101/results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks,"balance":"provisional","random_fixture":"QA seed; actual backend dice throughout"},"  "))
    print("R101_OK ",checks.size());get_tree().quit()
