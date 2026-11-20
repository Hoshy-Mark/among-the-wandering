extends "res://personagem/qa_characters106.gd"
func check(value: bool,message: String) -> void:
    if not value:push_error("R109_NATIVE_FAIL "+message);get_tree().quit(1);assert(value,message)
    checks.append(message);print("R109_NATIVE_CHECK ",message)
func shot109(scene: Node,name109: String) -> void:
    await frames(scene,6);await RenderingServer.frame_post_draw
    check(scene.get_viewport().get_texture().get_image().save_png("res://qa/social109/"+name109+".png")==OK,"capture "+name109)
func enter109(scene: Node3D,m: Node,id: String) -> void:
    check(await approach106(scene,m,id)!=null,"reachable "+id)
    await key(scene,KEY_E);await frames(scene,3);check(m.active==id,"real E opens "+id)
func choose109(scene: Node,m: Node,id: String) -> void:
    var index=-1
    for i in range(m.view_d02.current_options.size()):
        if m.view_d02.current_options[i].option_id==id:index=i;break
    check(index>=0 and m.view_d02.current_options[index].available,"available authored choice "+id)
    if index<0:return
    var choice=m.view_d02.choices.get_child(index);m.view_d02.choice_scroll.ensure_control_visible(choice);await frames(scene,4);await click_control(scene,choice);await frames(scene,3)
func back109(scene: Node,m: Node) -> void:await choose109(scene,m,"back")
func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/social109"))
    var p=scene.player;var m=scene.get_node("Characters99");var ui=m.skills_ui;var quick=p.get_node("Atalhos93")
    h._freeze98(scene);h._player_idle(p);quick.scripted=false;m.ambient_elapsed109=-100000
    p.condition_path="res://qa/social109/checkpoint.json";scene.get_window().size=Vector2i(1280,720)
    if "--social109-reopen" in OS.get_cmdline_user_args():
        check(p.load_condition(),"new process loads actual R109 campaign")
        var expected=m.social.validate(JSON.parse_string(FileAccess.get_file_as_string("res://qa/social109/expected.json")))
        check(not expected.is_empty() and m.social.snapshot()==expected,"restart preserves facts provenance 90 relations memories NPC rolls and RNG")
        check(m.social.knows("renata_volker","ricardo_helped_confinement") and not m.social.knows("player","ricardo_helped_confinement"),"NPC-only knowledge survives restart without reaching player")
        check(m.social.knows("player","ana_igor_missing") and not m.social.knows("player","jorge_crimes_sorriso_feliz"),"known testimony and hidden crimes remain separated")
        var before=m.social.snapshot();await key(scene,KEY_P);ui.select_tab(1);ui.selected_npc="ana_julia";ui.refresh();await shot109(scene,"09_diario_reaberto");await key(scene,KEY_ESCAPE)
        check(m.social.snapshot()==before,"opening menu cannot generate information or rewards")
        check(scene.zombie_world.saved.size()==480 and not p.hud_open,"population and input preserved after restart")
        await enter109(scene,m,"ricardo_medeiro");m.close()
        check(await approach106(scene,m,"renata_volker")!=null,"player can observe nearby NPC pair")
        var player_facts=m.social.data.knowledge.player.duplicate()
        check(m.ambient_pair109("ricardo_medeiro","renata_volker","family_checkin").ok,"reverse NPC exchange occurs physically after restart")
        await shot109(scene,"10_conversa_entre_npcs")
        check(m.social.data.knowledge.player==player_facts,"witnessing greeting discloses no private content")
        p.condition_path="res://qa/social109/fresh_checkpoint.json";var fresh_state=m.social.snapshot()
        check(p.save_condition() and p.load_condition() and m.social.snapshot()==fresh_state,"new observed NPC memory saves and reloads in campaign")
        finish109(true);return
    var inventory=p.bag_inventory.items.duplicate(true);var ammo=p.weapons.rounds.duplicate(true);var appearance=p.avatar.selection.duplicate(true);var shortcuts=quick.bindings.duplicate(true)
    check(m.actors.size()==9 and m.social.data.relations.size()==90,"nine actors and all directed social edges installed")
    check(ui.projection.characters(m).is_empty(),"NPC social network not leaked before meeting")
    await enter109(scene,m,"ana_julia");check(option(m,"igor109").is_empty(),"missing source information hides Igor topic")
    await choose109(scene,m,"school");await back109(scene,m);m.close()
    await enter109(scene,m,"samuel_henrique");check(option(m,"sorriso109").is_empty(),"second prerequisite still required")
    await choose109(scene,m,"origin");await back109(scene,m);check(option(m,"sorriso109").available,"Ana information and Samuel origin unlock cross-character option")
    await shot109(scene,"01_informacao_libera_resposta");await choose109(scene,m,"sorriso109");check(m.social.knows("player","samuel_survivors_sorriso"),"Samuel testimony delivered through actual choice")
    await shot109(scene,"02_relato_samuel");m.close()
    await enter109(scene,m,"ana_julia");check(not option(m,"igor109").available and option(m,"igor109").state=="locked","knowledge alone cannot bypass trust")
    await shot109(scene,"03_vinculo_insuficiente");await choose109(scene,m,"privacy");await back109(scene,m)
    var rng_before=m.social.data.rng_state;await choose109(scene,m,"listen109");await back109(scene,m);check(m.social.data.rng_state==rng_before,"relationship-only dialogue does not roll dice")
    check(not option(m,"igor109").available,"sensitive testimony needs more than two polite answers");m.close()
    await enter109(scene,m,"renata_volker");await choose109(scene,m,"occupation");await back109(scene,m);await choose109(scene,m,"privacy");await back109(scene,m);await choose109(scene,m,"listen109");await back109(scene,m);await choose109(scene,m,"ana109");await back109(scene,m);m.close()
    await enter109(scene,m,"ana_julia");await choose109(scene,m,"renata109");await back109(scene,m)
    check(option(m,"igor109").available,"trust acquired by distinct respectful acts opens topic")
    await choose109(scene,m,"igor109");check(m.social.knows("player","ana_igor_missing"),"Ana consents to private testimony with facts and trust")
    check(not m.social.knows("samuel_henrique","ana_igor_missing"),"Ana conversation does not broadcast to uncle")
    await shot109(scene,"04_ana_relato_privado");await back109(scene,m);var learned=m.social.data.learning102.earned.size();var before=m.social.snapshot();check(not m.social.choose(m.active,option(m,"igor109").id).ok and m.social.snapshot()==before,"repeat disclosure cannot farm XP trust or dice");m.close()
    await key(scene,KEY_P);ui.select_tab(1);ui.selected_npc="ana_julia";ui.refresh();await shot109(scene,"05_ficha_com_fonte")
    var row=ui.projection.characters(m).filter(func(item):return item.id=="ana_julia")[0]
    check(row.secrets.size()==1 and row.secrets[0].source=="Ana Julia" and row.relationship.values().all(func(value):return value==null),"menu projects source and testimony without hidden numeric scores")
    await key(scene,KEY_ESCAPE)
    await enter109(scene,m,"gabriel_pimenta");await choose109(scene,m,"occupation");await back109(scene,m);await choose109(scene,m,"church");await back109(scene,m);await choose109(scene,m,"privacy");await back109(scene,m)
    check(option(m,"safe109").has("check") and option(m,"safe109").available,"uncertain empathy action shows real probability")
    # QA controls only the random stream to capture a known failure branch; no production guarantee.
    var check_id="r109_gabriel_pimenta_safe109"
    for seed in range(1,1000):
        var rng=RandomNumberGenerator.new();rng.seed=seed;var state=str(rng.state);var a=rng.randi_range(1,6);var b=rng.randi_range(1,6)
        if not m.social.resolve_roll(a,b,2,9):m.social.data.rng_state=state;break
    await choose109(scene,m,"safe109");var roll=m.social.data.progress.gabriel_pimenta.checks[check_id][0]
    check(not roll.success and m.social.node=="safe109_no","failed roll branches to refusal while conversation continues")
    await shot109(scene,"06_falha_com_continuidade");await back109(scene,m);check(not option(m,"safe109").available,"failed one-shot attempt cannot reroll")
    await choose109(scene,m,"occupation");check(m.active=="gabriel_pimenta","ordinary public topic remains after failure");m.close()
    # Real positions and LOS authorize autonomous NPC interactions; no teleporting NPCs.
    var renata=m.actors.renata_volker;var doctor=m.actors.ricardo_medeiro
    check(renata.global_position.distance_to(doctor.global_position)<4,"authored doctor and spouse actually near each other")
    var original_player=m.social.data.knowledge.player.duplicate();var doctor_trust=m.social.relation("ricardo_medeiro","renata_volker").trust
    check(m.ambient_pair109("renata_volker","ricardo_medeiro","family_checkin").ok,"nearby NPCs resolve physical checkin")
    check(m.social.relation("renata_volker","ricardo_medeiro").trust==66 and m.social.relation("ricardo_medeiro","renata_volker").trust==doctor_trust,"NPC relation changes only in authored direction")
    check(m.ambient_pair109("ricardo_medeiro","renata_volker","public_context","ricardo_helped_confinement").ok,"NPC testimony transfers in actual nearby conversation")
    check(m.social.knows("renata_volker","ricardo_helped_confinement") and m.social.data.knowledge.player==original_player,"NPC learned report does not become player knowledge")
    check(not m.ambient_pair109("pietra_dos_santos","ricardo_alberto","courteous_greeting").ok,"remote NPC interactions refused")
    check(m.social.relation("pietra_dos_santos","josue_medeira").resentment==85,"family relationship retains grievance independently of player")
    var npc_result=m.social.interact109("renata_volker","ana_julia","listening_request")
    check(npc_result.ok and npc_result.check_result.score==2,"NPC decision uses own empathy and shared dice service")
    check(m.social.available_points()==floori(float(m.social.data.learning102.earned.size())/3),"NPC encounters do not add player XP")
    p.global_position=scene.spawn;p.update_nearby();scene.focus=p.global_position+Vector3.UP*.85;scene.zoom=6;scene._update_camera()
    await key(scene,KEY_P);ui.select_tab(0);await shot109(scene,"07_progressao_real");await key(scene,KEY_ESCAPE)
    check(p.bag_inventory.items==inventory and p.weapons.rounds==ammo and quick.bindings==shortcuts and p.avatar.selection==appearance,"C05 weapons ammo quickslots and body remain unchanged")
    check(scene.zombie_world.saved.size()==480,"fixed population preserved")
    check(p.save_condition(),"official full campaign saves R109 network and knowledge")
    var expected=m.social.snapshot();FileAccess.open("res://qa/social109/expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
    check(p.load_condition() and m.social.snapshot()==expected,"actual campaign load restores directional network and provenance")
    p.condition_path="res://qa/menu107/checkpoint.json";check(p.load_condition(),"actual older R107 campaign migrates")
    check(not m.social.knows("player","ana_igor_missing") and m.social.data.relations.size()==90,"migration grants no new secrets")
    p.condition_path="res://qa/social109/checkpoint.json";check(p.load_condition() and m.social.snapshot()==expected,"R109 checkpoint remains reloadable after older save")
    await shot109(scene,"08_gameplay_preservado");finish109(false)
func finish109(fresh109: bool) -> void:
    FileAccess.open("res://qa/social109/"+("fresh.json" if fresh109 else "results.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks},"  "));get_tree().quit()
