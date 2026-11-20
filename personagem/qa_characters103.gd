extends "res://personagem/qa_learning102.gd"
var failed103=false
func check(value: bool,message: String) -> void:
    if not value:failed103=true;push_error("R103_FAIL "+message);get_tree().quit(1);assert(value,message)
    checks.append(message);print("R103_CHECK ",message)
func capture103(scene: Node,name: String) -> void:
    await frames(scene,6);await RenderingServer.frame_post_draw
    check(scene.get_viewport().get_texture().get_image().save_png("res://qa/characters103/"+name+".png")==OK,"native capture "+name)
func approach103(scene: Node3D,m: Node,id: String) -> Variant:
    m.close();var actor=m.actors[id]
    for angle in [135,90,180,225,270,0,45,315]:
        var candidate=actor.global_position+Vector3(cos(deg_to_rad(angle)),0,sin(deg_to_rad(angle)))*1.6
        var floor=scene.zombie_world.motor._floor(candidate)
        if floor==null or not scene.zombie_world.motor._free(floor):continue
        scene.player.global_position=floor;scene.player.velocity=Vector3.ZERO
        await scene.get_tree().physics_frame;await scene.get_tree().physics_frame
        if not m.reachable(id):continue
        var toward=actor.global_position-floor
        scene.player.avatar.rotation.y=atan2(toward.x,toward.z);actor.avatar.rotation.y=scene.player.avatar.rotation.y+PI
        scene.focus=(floor+actor.global_position)*.5+Vector3.UP*.85;scene.zoom=6;scene._update_camera();scene.player.update_nearby();m._process(0)
        return floor
    return null
func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/characters103"))
    var p=scene.player;var m=scene.get_node("Characters99");var world=scene.zombie_world;var quick=p.get_node("Atalhos93")
    h._freeze98(scene);h._player_idle(p);quick.scripted=false;p.condition_path="res://qa/characters103/checkpoint.json"
    scene.get_window().size=Vector2i(1280,720)
    if "--characters103-reopen" in OS.get_cmdline_user_args():
        check(p.load_condition(),"fresh process loads multi-character checkpoint")
        var expected=m.social.validate(JSON.parse_string(FileAccess.get_file_as_string("res://qa/characters103/expected.json")))
        check(not expected.is_empty() and m.social.snapshot()==expected,"fresh process preserves multi-NPC facts relations attempts skills and RNG")
        check(m.registry.met.gabriel_pimenta and m.registry.met.josue_medeira and not m.registry.met.samuel_henrique,"fresh process records only actually introduced characters")
        check(m.social.available_points()==1 and m.social.data.skills.perception==3,"fresh process retains shared learning spending")
        check(m.actors.size()==3 and world.saved.size()==480 and p.weapons.loaded(p.bag_inventory.equipped("main_hand"))==6,"fresh process preserves three humans fixed population and firearm ammo")
        check(m.open("josue_medeira") and option(m,"gabriel").available and option(m,"calm").state=="exhausted","fresh process retains sourced cross-NPC topic and completed persuasion")
        m.close();FileAccess.open("res://qa/characters103/fresh.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed103,"checks":checks,"social":m.social.snapshot()},"  "))
        print("R103_FRESH_FAILED " if failed103 else "R103_FRESH_OK ",checks.size());get_tree().quit(1 if failed103 else 0);return
    check(m.registry.definitions.size()==9 and m.actors.size()==3,"nine registered identities with three authored public encounters")
    check(world.saved.size()==480 and scene.city.get_node("ResidentialInteriors").homes.size()==39,"current map fixed population and H01 compatibility preserved")
    for id in m.actors:
        var actor=m.actors[id]
        check(actor.avatar.skeleton.get_bone_count()==58 and not actor.is_in_group("combat_receivers79"),"preserved human rig without zombie combat AI: "+id)
        if id!="samuel_henrique":
            var pos=actor.global_position
            check(Rect2(320,154,24,9).has_point(Vector2(pos.x,pos.z)) and absf(pos.x-332)>=2.5,"safe church frontage anchor away from door: "+id)
    var baseline=m.social.snapshot();baseline.rng_state=learning_stream(m.social);check(m.social.restore(baseline),"controlled QA random stream")
    var inventory=p.bag_inventory.items.duplicate(true);var ammo=p.weapons.rounds.duplicate(true)
    check(await approach103(scene,m,"josue_medeira")!=null,"priest reachable outside current church")
    check(m.nearest=="josue_medeira" and m.prompt.text.contains("padre"),"unknown identity uses role in gameplay prompt")
    scene.zoom=16;scene._update_camera();await capture103(scene,"01_igreja_encontros");scene.zoom=6;scene._update_camera()
    await key(scene,KEY_E)
    check(m.active=="josue_medeira" and m.speaker.text=="Josué Medeira","actual E opens priest D02 and correct portrait context")
    check(option(m,"gabriel").is_empty() and option(m,"calm").is_empty(),"unknown cross-character fact and undiscovered role do not appear")
    await capture103(scene,"02_josue_inicio")
    await key(scene,KEY_1);await key(scene,KEY_ENTER);await key(scene,KEY_3)
    var first=m.social.data.progress.josue_medeira.checks.josue_calm[0].duplicate(true)
    check(not first.success,"priest first persuasion fails through actual numeric choice")
    await key(scene,KEY_ENTER);check(not option(m,"calm").available,"priest cannot immediately repeat unchanged failure")
    var stale=option(m,"occupation").id;m.close()
    check(await approach103(scene,m,"gabriel_pimenta")!=null,"mechanic reachable in separate frontage spot")
    await key(scene,KEY_E);check(m.active=="gabriel_pimenta" and m.speaker.text=="Gabriel Pimenta","actual E opens mechanic and switches speaker portrait")
    var before=m.social.snapshot();m._choose_d02(stale);check(m.social.snapshot()==before,"old priest callback cannot mutate mechanic conversation")
    await key(scene,KEY_1);await key(scene,KEY_ENTER)
    check(m.social.knows("player","gabriel_mechanic"),"mechanic public role learned from actual response")
    await key(scene,KEY_2);await key(scene,KEY_ENTER)
    check(m.social.knows("player","gabriel_church_helper") and m.social.data.knowledge.player.count("gabriel_church_helper")==1,"church assistance learned from Gabriel exactly once")
    await capture103(scene,"03_gabriel_fonte")
    await key(scene,KEY_3);await key(scene,KEY_ENTER);await key(scene,KEY_4);await key(scene,KEY_ENTER)
    check(m.social.available_points()==1 and m.social.experience_progress()==2,"five distinct experiences combine across characters without repeat farming")
    check(not m.social.data.progress.gabriel_pimenta.checks.gabriel_observe[0].success and option(m,"observe").state=="exhausted","failed observation is one completed attempt")
    check(m.social.relation("gabriel_pimenta","player").trust==1 and m.social.relation("josue_medeira","player").trust==0,"trust changes only for mechanic who received the respectful choice")
    await key(scene,KEY_5);check(m.social.current_line().text=="Por enquanto, prefiro ficar no trabalho.","mechanic keeps personal boundary despite rapport")
    await capture103(scene,"04_gabriel_limite");await key(scene,KEY_ENTER);m.close()
    var point=await approach103(scene,m,"josue_medeira");check(point!=null,"return to priest remains reachable")
    await key(scene,KEY_E)
    check(option(m,"gabriel").available and not option(m,"calm").available,"sourced topic appears on return, prior failure remains unchanged")
    await capture103(scene,"05_topico_desbloqueado")
    await key(scene,KEY_2);await key(scene,KEY_ENTER)
    before=m.social.snapshot();await key(scene,KEY_2);await key(scene,KEY_ENTER)
    check(m.social.snapshot()==before,"repeated corroboration cannot duplicate facts points or RNG")
    await key(scene,KEY_3);await key(scene,KEY_ENTER)
    check(option(m,"calm").available and option(m,"calm").text.contains("58%"),"priest own new context reopens failed persuasion at 58 percent")
    await key(scene,KEY_4)
    var attempts=m.social.data.progress.josue_medeira.checks.josue_calm
    check(attempts.size()==2 and attempts[0]==first and attempts[1].success,"second priest attempt succeeds while original failure remains intact")
    check(m.social.available_points()==2 and m.social.data.learning102.earned.size()==6,"six distinct experiences produce two shared learning points")
    await capture103(scene,"06_josue_dados")
    await key(scene,KEY_ENTER);await key(scene,KEY_5)
    check(m.social.current_line().text=="Prefiro deixar isso para outra hora.","priest personal answer remains bounded after successful persuasion")
    check(not m.social.knows("player","armacao_jean") and not m.social.knows("player","ricardo_alberto_criminal_past") and not m.social.knows("player","jorge_crimes_sorriso_feliz"),"no secret facts granted across either dialogue")
    m.close();await key(scene,KEY_P);await frames(scene)
    check(m.skills_ui.opened and m.skills_ui.panel.size.y<=400,"shared skills panel still opens compactly")
    await click_control(scene,m.skills_ui.buttons.perception)
    check(m.social.data.skills.perception==3 and m.social.available_points()==1,"actual GUI spends one shared point on perception")
    await capture103(scene,"07_aprendizado_compartilhado");await key(scene,KEY_ESCAPE)
    check(p.bag_inventory.items==inventory and p.weapons.rounds==ammo,"new conversations do not change manual inventory or ammunition")
    check(m.social.data.progress.samuel_henrique.visited.is_empty() and not m.registry.met.samuel_henrique,"new encounters invent no Samuel interaction history")
    p.global_position=scene.spawn;p.update_nearby();var pistol=h._equip92(scene,"pistol")
    check(quick.bind("left",pistol),"existing quickslot still binds pistol")
    check(p.place_item(h._find_weapon(p.bag_inventory,"ammo_pistol"),"pockets",2,0,false),"manual ammo placement preserved");h._settle93(scene)
    check(p.weapons.reload_weapon(),"firearm reload remains functional");h._settle93(scene)
    p.global_position=point;p.update_nearby();check(p.save_condition(),"full multi-character checkpoint saved")
    var expected=m.social.snapshot();FileAccess.open("res://qa/characters103/expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
    m.social.restore(null);check(p.load_condition() and m.social.snapshot()==expected,"actual load restores all character histories and skill ledger")
    check(p.weapons.loaded(pistol)==6 and quick.bindings.left==pistol and m.registry.met.values().count(true)==2,"checkpoint preserves ammo binding and only two real introductions")
    var invalid=p.session_save.snapshot();invalid.social101.content_revision103=99
    check(p.session_save.prepare(invalid,false).is_empty() and m.social.snapshot()==expected,"unsupported social content rejected before game mutation")
    p.condition_path="res://personagem/fixtures103/legacy102.json"
    var old=JSON.parse_string(FileAccess.get_file_as_string(p.condition_path));var migrated=m.social.validate(old.social101)
    check(p.load_condition() and m.social.snapshot()==migrated,"real R102 full checkpoint migrates to new public fact holders")
    check(not m.social.knows("player","gabriel_church_helper") and not m.registry.met.gabriel_pimenta and not m.registry.met.josue_medeira,"old checkpoint invents neither introductions nor player discoveries")
    p.condition_path="res://qa/characters103/checkpoint.json";check(p.load_condition() and m.social.snapshot()==expected,"restore completed multi-character checkpoint")
    check(m.open("josue_medeira") and option(m,"gabriel").available and option(m,"calm").state=="exhausted","loaded UI retains cross-NPC topic and resolved test")
    p.scripted=false;await key(scene,KEY_I)
    check(m.active.is_empty() and scene.game_ui.personal.visible,"unchanged C05 still opens from new conversation")
    await key(scene,KEY_I);await key(scene,KEY_H);check(scene.game_ui.windows[1].visible,"existing body HUD remains accessible")
    await key(scene,KEY_H);p.scripted=true;quick._process(0)
    check(not p.hud_open and quick.view_r01.visible and world.saved.size()==480,"return to gameplay preserves weapon HUD population and controls")
    FileAccess.open("res://qa/characters103/results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed103,"checks":checks,"content_status":"candidate public dialogues and temporary encounter anchors"},"  "))
    print("R103_FAILED " if failed103 else "R103_OK ",checks.size());get_tree().quit(1 if failed103 else 0)
