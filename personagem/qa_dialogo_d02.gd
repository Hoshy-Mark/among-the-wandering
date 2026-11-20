extends Node
var h=load("res://personagem/revisao98.gd").new()
var checks=[]
var requests=[]
func check(value: bool,message: String) -> void:
    if not value:push_error("D02_FAIL "+message);get_tree().quit(1);assert(value,message)
    checks.append(message);print("D02_CHECK ",message)
func frames(scene: Node,count: int=4) -> void:
    for tick in count:await scene.get_tree().process_frame
func key(scene: Node,code: int,echo: bool=false) -> void:
    var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true;event.echo=echo
    Input.parse_input_event(event);await frames(scene,1)
    event=InputEventKey.new();event.physical_keycode=code;event.pressed=false
    Input.parse_input_event(event);await frames(scene,1)
func click(scene: Node,control: Control) -> void:
    var point=control.get_global_rect().get_center()
    var motion=InputEventMouseMotion.new();motion.position=point;Input.parse_input_event(motion);await frames(scene,1)
    for down in [true,false]:
        var event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
        Input.parse_input_event(event);await frames(scene,1)
func capture(scene: Node,name: String) -> void:
    await frames(scene);await RenderingServer.frame_post_draw
    check(scene.get_viewport().get_texture().get_image().save_png("res://qa/dialogue_d02/"+name+".png")==OK,"native capture "+name)
func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/dialogue_d02"))
    var p=scene.player;var m=scene.get_node("Characters99");var view=m.view_d02;var quick=p.get_node("Atalhos93")
    h._freeze98(scene);h._player_idle(p);quick.scripted=false
    scene.get_window().size=Vector2i(1280,720);p.condition_path="res://qa/dialogue_d02/checkpoint.json"
    var helper=load("res://personagem/qa_personagens99.gd").new();add_child(helper)
    var position=await helper.approach(scene,m);check(position!=null,"real map encounter reachable")
    var samuel=m.actors.samuel_henrique
    scene.focus=(p.global_position+samuel.global_position)*.5+Vector3.UP*.85;scene.zoom=6;scene._update_camera()
    var direction=samuel.global_position-p.global_position;p.avatar.rotation.y=atan2(direction.x,direction.z);samuel.avatar.rotation.y=p.avatar.rotation.y+PI
    var inventory=p.bag_inventory.items.duplicate(true);var rounds=p.weapons.rounds.duplicate(true);var bindings=quick.bindings.duplicate(true)
    m._process(0);await key(scene,KEY_E);await frames(scene)
    check(m.active=="samuel_henrique" and view.visible and not m.prompt.visible,"E opens D02 and removes world prompt")
    check(view.lines.size()==1 and view.lines[0].text==m.config.encounters.samuel_henrique.introduction,"official initial line only, no demonstration dialogue")
    check(scene.get_viewport().gui_get_focus_owner()==view.choices.get_child(0),"keyboard focus starts on first available choice")
    var portrait_view=m.portraits_d02.samuel_henrique
    await RenderingServer.frame_post_draw
    var portrait=portrait_view.get_texture().get_image()
    check(portrait.get_used_rect().size.x>20 and portrait_view.avatar.skeleton.get_bone_count()==58,"portrait rendered from approved live character assets")
    portrait.save_png("res://qa/dialogue_d02/portrait_samuel.png")
    await capture(scene,"01_inicial_1280x720")
    await key(scene,KEY_1)
    check(view.lines.size()==3 and view.lines[1].kind=="player" and view.lines[1].text=="Você é daqui?" and view.lines[2].text==m.config.encounters.samuel_henrique.about,"numeric choice routes existing backend and appends chronological transcript")
    check(p.weapons.rounds==rounds and quick.bindings==bindings and quick.job.is_empty(),"dialogue number never activates weapon quickslots")
    var count=view.lines.size();await key(scene,KEY_1,true)
    check(view.lines.size()==count,"key echoes do not repeat answers")
    await key(scene,KEY_DOWN);check(view.selected_index==1,"down selects next response")
    await key(scene,KEY_UP);await key(scene,KEY_ENTER)
    check(view.lines.size()==count+2,"up and Enter confirm one response")
    p.scripted=false;scene.shoulder.scripted=false
    count=view.lines.size();await click(scene,view.choices.get_child(0))
    check(view.lines.size()==count+2 and not p.combat.is_attacking() and p.weapons.rounds==rounds,"actual GUI click answers without firing or attacking")
    p.scripted=true;scene.shoulder.scripted=true
    await capture(scene,"02_historico_oficial")
    m.can_exit=false
    check(view.close_button.disabled and view.choices.get_child(1).disabled,"backend exit restriction reflected in controls")
    await key(scene,KEY_ESCAPE);await key(scene,KEY_E);await key(scene,KEY_I);await key(scene,KEY_H)
    check(not m.active.is_empty() and view.visible and not scene.game_ui.personal.visible,"blocked exit cannot be bypassed by Escape E I or H")
    await key(scene,KEY_2);check(not m.active.is_empty(),"unavailable response does not execute")
    check(p.reaction.begin("hit_front"),"real reaction starts")
    check(m.active.is_empty() and not view.visible and not p.hud_open,"gameplay interruption force-closes even exit-locked dialogue")
    await capture(scene,"03_interrompido")
    h._player_idle(p);m.can_exit=true;check(m.open("samuel_henrique"),"reopen after interruption")
    check(view.lines.size()==1,"new conversation rebuilds session transcript")
    view.choice_requested.connect(func(id):requests.append(id))
    # Explicit QA fixtures: none of these lines/options are in the runtime catalog.
    for n in 18:view.append_line({"speaker":"QA · teste de rolagem","text":"Linha de teste %02d. Verificação de leitura e quebra de linha em uma conversa extensa, sem conteúdo narrativo de produção."%(n+1),"kind":"player" if n%2==0 else "npc"})
    await frames(scene,6)
    check(view.history_scroll.get_v_scroll_bar().max_value>view.history_scroll.size.y,"long transcript scrolls independently")
    view.history_scroll.scroll_vertical=0;await frames(scene)
    view.append_line({"speaker":"QA","text":"Nova linha de teste enquanto o leitor consulta entradas anteriores.","kind":"npc"})
    await frames(scene,6)
    check(view.history_scroll.scroll_vertical==0,"append respects reader's earlier scroll position")
    await capture(scene,"04_historico_longo_QA")
    var rows=[]
    for n in 9:rows.append({"id":"qa_"+str(n+1),"text":"QA · resposta %d para verificação de navegação."%(n+1),"available":n!=2})
    rows[8].text="QA · resposta 9 com texto extenso para verificar uma opção com várias linhas, mantendo a leitura, a numeração e a área de escolhas dentro da janela, sem truncar o conteúdo da resposta."
    view.set_options(rows);await frames(scene)
    await key(scene,KEY_DOWN);await key(scene,KEY_DOWN)
    check(view.selected_index==3,"arrow navigation skips unavailable choices")
    var request_count=requests.size();await key(scene,KEY_3)
    check(requests.size()==request_count,"disabled numeric choice publishes no request")
    await key(scene,KEY_9);await frames(scene)
    check(requests.back()=="qa_9" and view.selected_index==8 and view.choice_scroll.scroll_vertical>0,"key 9 selects and reveals ninth multiline response")
    var text: Label=view.choices.get_child(8).get_child(1)
    check(text.size.y+.5>=text.get_minimum_size().y and text.get_line_count()>=3 and text.get_rect().end.x<=text.get_parent().size.x,"multiline choice visibly wraps within button and gets sufficient height")
    await capture(scene,"05_nove_respostas_QA")
    # Isolated header-switch test uses a second rendering of existing model assets.
    var alternate=load("res://personagem/retrato_d02.gd").new();add_child(alternate)
    var appearance=m.config.encounters.samuel_henrique.appearance.duplicate(true);appearance.skin_id="escura_quente";appearance.hair_id="none";alternate.configure(appearance)
    view.begin_session({"npc_id":"qa_second","name":"QA · Segundo interlocutor","portrait":alternate.get_texture()},[{"speaker":"QA","text":"Sessão isolada para teste de troca de interlocutor.","kind":"npc"}],rows)
    check(view.npc_id=="qa_second" and view.lines.size()==1 and view.portrait.texture==alternate.get_texture() and view.name_label.text=="QA · Segundo interlocutor","NPC switch replaces header portrait and transcript")
    m.close();check(m.open("samuel_henrique"),"restore official Samuel session after UI fixtures")
    for dimensions in [Vector2i(1280,720),Vector2i(1366,768),Vector2i(1920,1080),Vector2i(960,600)]:
        scene.get_window().size=dimensions;await frames(scene,6);scene._update_camera()
        var viewport=scene.get_viewport().get_visible_rect();var rectangle=view.get_global_rect()
        check(viewport.encloses(rectangle) and not rectangle.has_point(viewport.size*.5),"panel bounds and clear center "+str(dimensions))
        var player_screen=scene.camera.unproject_position(p.global_position+Vector3.UP)
        var npc_screen=scene.camera.unproject_position(samuel.global_position+Vector3.UP)
        check(not rectangle.has_point(player_screen) and not rectangle.has_point(npc_screen),"characters unobstructed "+str(dimensions))
        await capture(scene,"06_oficial_%dx%d"%[dimensions.x,dimensions.y])
    scene.get_window().size=Vector2i(1280,720);await frames(scene)
    m.close();m._process(0);quick._process(0)
    check(not view.visible and not p.hud_open and m.prompt.visible,"closing restores nearby prompt and gameplay")
    var focused=scene.get_viewport().gui_get_focus_owner()
    check(focused==null or not view.is_ancestor_of(focused),"dialogue releases keyboard focus on close")
    await capture(scene,"07_fechado")
    check(m.open("samuel_henrique"),"reopen for inventory transition")
    p.scripted=false;await key(scene,KEY_I)
    check(m.active.is_empty() and scene.game_ui.personal.visible and p.hud_open,"I opens unchanged C05 after allowed conversation exit")
    await key(scene,KEY_I);await key(scene,KEY_H)
    check(scene.game_ui.windows[1].visible and p.hud_open,"body HUD preserved")
    await key(scene,KEY_H);p.scripted=true
    check(not p.hud_open and p.bag_inventory.items==inventory and p.weapons.rounds==rounds and quick.bindings==bindings,"UI and input tests preserve equipment ammo and manual inventory")
    check(p.save_condition(),"existing full checkpoint saves known character")
    var saved=p.session_save.snapshot();check(not saved.has("dialogue_d02"),"HUD adds no parallel persistence schema")
    m.registry.met.samuel_henrique=false
    check(p.load_condition() and m.registry.met.samuel_henrique,"existing narrative introduction survives load")
    check(scene.zombie_world.saved.size()==480,"fixed zombie identities preserved")
    FileAccess.open("res://qa/dialogue_d02/results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks,"engine":Engine.get_version_info(),"gamepad":"No physical gamepad tested","stress_fixtures":"QA only, absent from production dialogue"},"  "))
    print("D02_OK ",checks.size());get_tree().quit()
