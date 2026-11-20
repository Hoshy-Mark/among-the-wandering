extends "res://personagem/qa_characters105.gd"
var failed106=false
func check(value: bool,message: String) -> void:
    if not value:failed106=true;push_error("R106_FAIL "+message);get_tree().quit(1);assert(value,message)
    checks.append(message);print("R106_CHECK ",message)
func capture106(scene: Node,name: String) -> void:
    await frames(scene,6);await RenderingServer.frame_post_draw
    check(scene.get_viewport().get_texture().get_image().save_png("res://qa/characters106/"+name+".png")==OK,"native capture "+name)
func approach106(scene: Node3D,m: Node,id: String) -> Variant:
    m.close();var actor=m.actors[id]
    for angle in [315,270,0,45,90,135,180,225]:
        var candidate=actor.global_position+Vector3(cos(deg_to_rad(angle)),0,sin(deg_to_rad(angle)))*1.6
        var floor=scene.zombie_world.motor._floor(candidate)
        if floor==null or not scene.zombie_world.motor._free(floor):continue
        scene.player.global_position=floor;scene.player.velocity=Vector3.ZERO
        await scene.get_tree().physics_frame;await scene.get_tree().physics_frame
        if not m.reachable(id):continue
        var toward=actor.global_position-floor;scene.player.avatar.rotation.y=atan2(toward.x,toward.z);actor.avatar.rotation.y=scene.player.avatar.rotation.y+PI
        scene.focus=(floor+actor.global_position)*.5+Vector3.UP*.85;scene.zoom=6;scene._update_camera();scene.player.update_nearby();m._process(0)
        if m.nearest==id:return floor
    return null
func female_portrait(m: Node,id: String) -> bool:
    return m.portraits_d02.has(id) and m.portraits_d02[id].avatar.catalog.body=="assets/female106/body.glb" and m.portraits_d02[id].avatar.selection==m.actors[id].avatar.selection
func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/characters106"))
    var p=scene.player;var m=scene.get_node("Characters99");var world=scene.zombie_world;var quick=p.get_node("Atalhos93")
    h._freeze98(scene);h._player_idle(p);quick.scripted=false;p.condition_path="res://qa/characters106/checkpoint.json"
    scene.get_window().size=Vector2i(1280,720)
    if "--characters106-reopen" in OS.get_cmdline_user_args():
        check(p.load_condition(),"fresh process loads nine-character checkpoint")
        var expected=m.social.validate(JSON.parse_string(FileAccess.get_file_as_string("res://qa/characters106/expected.json")))
        check(not expected.is_empty() and m.social.snapshot()==expected,"fresh process preserves all conversation facts relationships spending and RNG")
        check(m.actors.size()==9 and m.registry.met.values().count(true)==6 and m.registry.met.renata_volker and m.registry.met.pietra_dos_santos and m.registry.met.ana_julia,"fresh process keeps only six actual introductions among nine actors")
        check(m.social.available_points()==2 and m.social.data.skills.empathy==3,"fresh process retains shared learning spending")
        check(world.saved.size()==480 and p.weapons.loaded(p.bag_inventory.equipped("main_hand"))==6,"fresh process retains fixed population and firearm ammo")
        check(await approach106(scene,m,"renata_volker")!=null,"fresh process reaches revised clear Renata frontage point")
        await key(scene,KEY_E)
        check(m.active=="renata_volker" and female_portrait(m,"renata_volker"),"revised Renata point opens correct actor and portrait near doctor")
        await key(scene,KEY_1);await capture106(scene,"01_renata_apresentacao");await key(scene,KEY_ENTER);await key(scene,KEY_2);await capture106(scene,"02_renata_vinculo");m.close()
        check(m.social.snapshot()==expected,"replayed public Renata topics preserve exact loaded social state")
        check(await approach106(scene,m,"ana_julia")!=null and m.open("ana_julia"),"fresh process opens actual Ana encounter")
        check(female_portrait(m,"ana_julia") and option(m,"samuel").available and option(m,"privacy").state=="exhausted","fresh process keeps female portrait sourced topic and single-use choice")
        m.close();FileAccess.open("res://qa/characters106/fresh.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed106,"checks":checks,"social":m.social.snapshot()},"  "))
        print("R106_FRESH_FAILED " if failed106 else "R106_FRESH_OK ",checks.size());get_tree().quit(1 if failed106 else 0);return
    check(m.actors.size()==9 and m.registry.definitions.size()==9 and m.social.config.dialogues.size()==9,"nine physical first-contact encounters with nine existing dialogue graphs")
    check(world.saved.size()==480 and scene.city.get_node("ResidentialInteriors").homes.size()==39,"current map fixed population and H01 compatibility retained")
    var girls=["renata_volker","pietra_dos_santos","ana_julia"]
    for id in m.actors:
        var avatar=m.actors[id].avatar
        check(avatar.skeleton.get_bone_count()==58 and not m.actors[id].is_in_group("combat_receivers79"),"same rig and stationary conversation authority: "+id)
        check(avatar.catalog.body==("assets/female106/body.glb" if id in girls else "assets/corpo_articulado_r53.glb"),"dedicated body selection without replacing existing males: "+id)
    var player_appearance=p.avatar.selection.duplicate(true);var inventory=p.bag_inventory.items.duplicate(true);var ammo=p.weapons.rounds.duplicate(true)
    for id in girls:
        var actor=m.actors[id];var guard=m.config.encounters[id].anchor_guard104;var a=guard.rect
        check(Rect2(a[0],a[1],a[2],a[3]).has_point(Vector2(actor.global_position.x,actor.global_position.z)),"female anchor remains inside proposed public area: "+id)
        if guard.has("door_x"):check(absf(actor.global_position.x-float(guard.door_x))>=float(guard.clearance),"female anchor leaves central entry route clear: "+id)
        check(actor.avatar.selection.beard_id=="none" and actor.avatar.selection.mustache_id=="none","female profile has explicit clean facial accessories: "+id)
    check(await approach106(scene,m,"renata_volker")!=null,"Renata reachable outside current pharmacy")
    check(m.prompt.text.contains("moradora") and not m.prompt.text.to_lower().contains("jornalista"),"unknown Renata prompt preserves public cover identity")
    await key(scene,KEY_E)
    check(m.active=="renata_volker" and female_portrait(m,"renata_volker") and option(m,"doctor").is_empty(),"actual E opens female Renata with matching portrait and undiscovered spouse topic hidden")
    await key(scene,KEY_1);check(m.social.knows("player","renata_public_identity"),"Renata's attributed public identity learned from real reply")
    await capture106(scene,"01_renata_apresentacao");await key(scene,KEY_ENTER);await key(scene,KEY_2);await key(scene,KEY_ENTER);await key(scene,KEY_3)
    check(m.social.current_line().text=="Prefiro deixar os assuntos pessoais para outro momento.","Renata preserves personal boundary after respectful approach")
    check(not m.social.knows("player","jorge_crimes_sorriso_feliz") and m.view_d02.lines.all(func(line):return not str(line.text).to_lower().contains("jornalista")),"Renata conversation exposes neither journalistic profession nor crime knowledge")
    m.close();check(await approach106(scene,m,"ricardo_medeiro")!=null,"existing doctor source reachable")
    await key(scene,KEY_E);await key(scene,KEY_1);await key(scene,KEY_ENTER);m.close()
    check(await approach106(scene,m,"renata_volker")!=null,"return to Renata remains reachable")
    await key(scene,KEY_E);check(option(m,"doctor").available,"actual doctor introduction opens Renata's spouse topic")
    await key(scene,KEY_2);check(m.social.knows("player","renata_married_doctor"),"spouse fact learned from actual Renata response")
    await capture106(scene,"02_renata_vinculo");m.close()
    check(await approach106(scene,m,"pietra_dos_santos")!=null,"Pietra reachable at separate church frontage point")
    await key(scene,KEY_E)
    check(m.active=="pietra_dos_santos" and female_portrait(m,"pietra_dos_santos") and option(m,"josue").is_empty(),"actual Pietra portrait matches female actor and priest topic starts hidden")
    await key(scene,KEY_1);await key(scene,KEY_ENTER);await key(scene,KEY_2)
    check(m.social.knows("player","pietra_religious") and m.social.knows("player","pietra_grows_herbs"),"Pietra discloses only public religious role and herbs")
    await capture106(scene,"03_pietra_ervas");await key(scene,KEY_ENTER);await key(scene,KEY_3);await key(scene,KEY_ENTER);await key(scene,KEY_4)
    check(m.social.current_line().text=="Por enquanto, prefiro não falar disso.","Pietra retains personal boundary")
    m.close();check(await approach106(scene,m,"josue_medeira")!=null,"existing priest source reachable")
    await key(scene,KEY_E);await key(scene,KEY_1);await key(scene,KEY_ENTER);m.close()
    check(await approach106(scene,m,"pietra_dos_santos")!=null,"return to Pietra remains reachable")
    await key(scene,KEY_E);check(option(m,"josue").available,"priest introduction opens Pietra's sibling topic")
    await key(scene,KEY_2);check(m.social.knows("player","pietra_sister_josue"),"sibling fact learned from actual Pietra reply")
    await capture106(scene,"04_pietra_vinculo");m.close()
    check(await approach106(scene,m,"ana_julia")!=null,"Ana reachable in separate public square point")
    await key(scene,KEY_E)
    check(m.active=="ana_julia" and female_portrait(m,"ana_julia") and option(m,"samuel").is_empty(),"actual Ana portrait matches female actor with unknown uncle topic hidden")
    await key(scene,KEY_1);check(m.social.knows("player","ana_studied_sorriso"),"Ana's school history learned from actual reply")
    await capture106(scene,"05_ana_estudos");await key(scene,KEY_ENTER);await key(scene,KEY_2);await key(scene,KEY_ENTER);await key(scene,KEY_3)
    check(m.social.current_line().text=="Agora prefiro deixar isso para depois.","Ana retains personal boundary without invented journey outcome")
    m.close();check(await approach106(scene,m,"samuel_henrique")!=null,"existing Samuel source reachable")
    await key(scene,KEY_E);await key(scene,KEY_1);await key(scene,KEY_ENTER);m.close()
    check(await approach106(scene,m,"ana_julia")!=null,"return to Ana remains reachable")
    await key(scene,KEY_E);check(option(m,"samuel").available,"actual Samuel conversation opens Ana's uncle topic")
    await key(scene,KEY_2);check(m.social.knows("player","ana_samuel_niece"),"niece fact learned from actual Ana response")
    await capture106(scene,"06_ana_vinculo")
    var before=m.social.snapshot();await key(scene,KEY_ENTER);await key(scene,KEY_2)
    check(m.social.snapshot()==before,"repeating kinship topic gives no duplicate credit or RNG")
    check(m.social.data.learning102.earned.size()==10 and m.social.available_points()==3 and m.social.experience_progress()==1,"ten distinct activities yield three shared points and one experience remainder")
    check(m.registry.met.values().count(true)==6 and not m.registry.met.gabriel_pimenta and not m.registry.met.jorge_luiz and not m.registry.met.ricardo_alberto,"only three women and their three actual conversation sources become introduced")
    check(not m.social.knows("player","armacao_jean") and not m.social.knows("player","jorge_crimes_sorriso_feliz") and not m.social.knows("player","ricardo_alberto_criminal_past"),"new physical integration does not reveal private narrative facts")
    m.close();await key(scene,KEY_P);await frames(scene);await click_control(scene,m.skills_ui.buttons.empathy)
    check(m.social.data.skills.empathy==3 and m.social.available_points()==2,"female conversations feed existing shared learning and GUI allocation")
    await key(scene,KEY_ESCAPE)
    check(p.bag_inventory.items==inventory and p.weapons.rounds==ammo and p.avatar.selection==player_appearance,"female geometry and dialogue do not mutate player's model inventory or ammunition")
    var old_point=p.global_position;var ana=m.actors.ana_julia
    p.global_position=ana.global_position;m.reconcile_anchors()
    check(ana.global_position.distance_to(p.global_position)>.6,"provisional female anchor moves safely when incoming player occupies candidate")
    p.global_position=old_point;var point=await approach106(scene,m,"ana_julia");check(point!=null,"reconciled Ana encounter still reachable")
    p.global_position=scene.spawn;p.update_nearby();var pistol=h._equip92(scene,"pistol")
    check(quick.bind("left",pistol),"existing firearm quickslot binds normally")
    check(p.place_item(h._find_weapon(p.bag_inventory,"ammo_pistol"),"pockets",2,0,false),"manual C05 ammo placement retained");h._settle93(scene)
    check(p.weapons.reload_weapon(),"existing firearm reload retained");h._settle93(scene)
    p.global_position=point;p.update_nearby();check(p.save_condition(),"full nine-character checkpoint saved")
    var expected=m.social.snapshot();FileAccess.open("res://qa/characters106/expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
    m.social.restore(null);check(p.load_condition() and m.social.snapshot()==expected,"actual load preserves new female histories and existing social schema")
    check(p.weapons.loaded(pistol)==6 and quick.bindings.left==pistol and m.registry.met.values().count(true)==6,"load keeps firearm ammo binding and exact introductions")
    p.condition_path="res://personagem/fixtures106/legacy105.json"
    var legacy=JSON.parse_string(FileAccess.get_file_as_string(p.condition_path));var normalized=m.social.validate(legacy.social101)
    check(p.load_condition() and m.social.snapshot()==normalized,"actual R105 full checkpoint loads without social schema conversion or loss")
    check(not m.registry.met.renata_volker and not m.registry.met.pietra_dos_santos and not m.registry.met.ana_julia and m.social.data.progress.renata_volker.visited.is_empty(),"placing three women invents no conversations in old checkpoint")
    p.condition_path="res://qa/characters106/checkpoint.json";check(p.load_condition() and m.social.snapshot()==expected,"restore completed R106 checkpoint")
    check(await approach106(scene,m,"ana_julia")!=null and m.open("ana_julia"),"loaded Ana conversation opens with real female portrait")
    p.scripted=false;await key(scene,KEY_I);check(m.active.is_empty() and scene.game_ui.personal.visible,"I still transitions to unchanged C05 inventory")
    await key(scene,KEY_I);await key(scene,KEY_H);check(scene.game_ui.windows[1].visible,"existing body health HUD accessible")
    await key(scene,KEY_H);p.scripted=true;quick._process(0)
    check(not p.hud_open and quick.view_r01.visible and world.saved.size()==480,"gameplay weapon HUD controls and fixed population restored")
    FileAccess.open("res://qa/characters106/results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed106,"checks":checks,"physical_actors":9,"dialogue_graphs":9,"female_visuals":"dedicated candidate geometry R106"},"  "))
    print("R106_FAILED " if failed106 else "R106_OK ",checks.size());get_tree().quit(1 if failed106 else 0)
