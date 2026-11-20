extends Node
var h=load("res://personagem/revisao98.gd").new()
var checks=[]
func check(value: bool,message: String) -> void:
    if not value:push_error("R99_FAIL "+message);get_tree().quit(1);assert(value,message)
    checks.append(message);print("R99_CHECK ",message)
func key(scene: Node,code: int) -> void:
    var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
    Input.parse_input_event(event);await scene.get_tree().process_frame
    event=InputEventKey.new();event.physical_keycode=code;event.pressed=false
    Input.parse_input_event(event);await scene.get_tree().process_frame
func capture(scene: Node,name: String) -> void:
    await scene.get_tree().process_frame;await RenderingServer.frame_post_draw
    check(scene.get_viewport().get_texture().get_image().save_png("res://qa/characters99/"+name+".png")==OK,"native capture "+name)
func approach(scene: Node3D,manager: Node) -> Variant:
    var point=manager.actors.samuel_henrique.global_position
    for angle in [135,90,180,225,270,0,45,315]:
        var candidate=point+Vector3(cos(deg_to_rad(angle)),0,sin(deg_to_rad(angle)))*1.6
        var floor=scene.zombie_world.motor._floor(candidate)
        if floor==null or not scene.zombie_world.motor._free(floor):continue
        scene.player.global_position=floor;scene.player.velocity=Vector3.ZERO
        await scene.get_tree().physics_frame;await scene.get_tree().physics_frame
        if manager.reachable("samuel_henrique"):return floor
    return null
func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/characters99"))
    var p=scene.player;var world=scene.zombie_world;var m=scene.get_node("Characters99");var quick=p.get_node("Atalhos93")
    h._freeze98(scene);h._player_idle(p);quick.scripted=false
    scene.get_window().size=Vector2i(1280,720);p.condition_path="res://qa/characters99/checkpoint.json"
    check(m.registry.definitions.size()==9 and m.actors.size()==1,"nine identities, one provisional encounter")
    check(world.saved.size()==480 and world.model.definitions.size()==480,"fixed zombie population unchanged")
    var samuel=m.actors.samuel_henrique
    check(samuel.avatar.skeleton.get_bone_count()==58 and not samuel.is_in_group("combat_receivers79"),"approved human rig, independent of zombie AI")
    if "--characters99-reopen" in OS.get_cmdline_user_args():
        check(p.load_condition(),"fresh process restores checkpoint")
        check(m.registry.met.samuel_henrique and m.registry.met.values().count(true)==1,"fresh process preserves only actual introduction")
        check(quick.bindings.size()==1 and p.weapons.loaded(p.bag_inventory.equipped("main_hand"))==6,"fresh process preserves gun ammo and quickslot")
        FileAccess.open("res://qa/characters99/fresh.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks},"  "))
        print("R99_FRESH_OK");get_tree().quit();return
    var position=await approach(scene,m);check(position!=null,"safe actual-map approach")
    p.update_nearby();scene.focus=(p.global_position+samuel.global_position)*.5+Vector3.UP*.85;scene.zoom=6.0;scene._update_camera()
    var toward=samuel.global_position-p.global_position;p.avatar.rotation.y=atan2(toward.x,toward.z)
    samuel.avatar.rotation.y=p.avatar.rotation.y+PI;m._process(0)
    check(m.nearest=="samuel_henrique" and m.prompt.visible and not m.registry.met.samuel_henrique,"first encounter uses role without automatic discovery")
    await capture(scene,"01_encontro")
    await key(scene,KEY_E)
    check(m.active=="samuel_henrique" and p.hud_open and m.registry.met.samuel_henrique,"E starts real introduction and records identity")
    check(m.speaker.text=="Samuel Henrique" and m.speech.text==m.config.encounters.samuel_henrique.introduction,"public introduction from separate authored data")
    quick._process(0);check(not quick.view_r01.visible,"approved weapon HUD hides while conversing")
    var clock=world.model.clock;world._physics_process(.2)
    check(world.model.clock>clock and not scene.get_tree().paused and not p.paused,"dialogue does not pause world simulation")
    for actor in world.actors.values():actor.ai_enabled=false
    check(not p.request_attack() and not quick.activate("left"),"dialogue blocks firearm and equipment actions")
    m.options.get_child(0).pressed.emit();check(m.speech.text==m.config.encounters.samuel_henrique.about,"dialogue choice shows only established public fact")
    await capture(scene,"02_conversa")
    await key(scene,KEY_ESCAPE);check(m.active.is_empty() and not p.hud_open,"Escape releases gameplay controls")
    check(m.open("samuel_henrique"),"reopen conversation")
    p.scripted=false;await key(scene,KEY_I)
    check(m.active.is_empty() and p.hud_open and scene.game_ui.personal.visible,"I switches to unchanged inventory without lock leakage")
    await key(scene,KEY_I);p.scripted=true
    check(not p.hud_open,"inventory closes normally")
    check(m.open("samuel_henrique"),"conversation before damage")
    check(p.reaction.begin("hit_front"),"real reaction begins")
    check(m.active.is_empty() and not p.hud_open,"reaction interrupts conversation immediately")
    h._player_idle(p)
    check(m.open("samuel_henrique"),"conversation before distance interruption")
    p.global_position+=Vector3(5,0,0);m._process(0)
    check(m.active.is_empty() and not m.open("samuel_henrique"),"out of range closes and cannot reopen")
    p.global_position=position;await scene.get_tree().physics_frame
    var barrier=StaticBody3D.new();barrier.collision_layer=1
    var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.8,2.1,.8);collider.shape=box;barrier.add_child(collider)
    scene.add_child(barrier);barrier.global_position=(position+samuel.global_position)*.5+Vector3.UP*1.05
    await scene.get_tree().physics_frame;await scene.get_tree().physics_frame
    check(not m.reachable("samuel_henrique") and not m.open("samuel_henrique"),"physical wall prevents through-wall conversation")
    barrier.queue_free();await scene.get_tree().physics_frame;await scene.get_tree().physics_frame
    p.paused=true;check(not m.open("samuel_henrique"),"paused player cannot start dialogue");p.paused=false
    p.traversal.state="align";check(not m.open("samuel_henrique"),"traversal cannot start dialogue");p.traversal.state="idle"
    # Existing equipment/save services, with the human-state block added only once.
    p.global_position=scene.spawn;p.update_nearby();var pistol=h._equip92(scene,"pistol")
    check(quick.bind("left",pistol),"existing explicit weapon binding")
    check(p.place_item(h._find_weapon(p.bag_inventory,"ammo_pistol"),"pockets",2,0,false),"existing manual ammunition placement");h._settle93(scene)
    check(p.weapons.reload_weapon(),"existing reload after dialogue");h._settle93(scene)
    p.global_position=position;p.update_nearby()
    check(p.shoulder.set_aim(true),"existing shoulder camera still enters");h._step88(scene,.5)
    check(not m.open("samuel_henrique"),"aiming cannot begin conversation")
    p.shoulder.set_aim(false);h._step88(scene,.5);h._player_idle(p)
    check(p.save_condition(),"current complete world checkpoint saved")
    var inventory=p.bag_inventory.items.duplicate(true);var baseline=p.session_save.snapshot()
    m.registry.met.samuel_henrique=false
    check(p.load_condition(),"current complete world checkpoint restored")
    check(m.registry.met.samuel_henrique and m.registry.met.values().count(true)==1,"introduction persisted without discovering other people")
    check(p.bag_inventory.items==inventory and quick.bindings.left==pistol and p.weapons.loaded(pistol)==6 and world.saved.size()==480,"manual inventory, quickslot, ammo and population preserved")
    var legacy=baseline.duplicate(true);legacy.erase("characters99")
    check(not p.session_save.prepare(legacy,false).is_empty() and not p.session_save.pending_characters99.met.samuel_henrique,"legacy R98 block absent migrates without fabricated meetings")
    var invalid=baseline.duplicate(true);invalid.characters99.met.samuel_henrique="true"
    check(p.session_save.prepare(invalid,false).is_empty() and m.registry.met.samuel_henrique,"invalid NPC save rejected before mutation")
    FileAccess.open("res://qa/characters99/legacy.json",FileAccess.WRITE).store_string(JSON.stringify(legacy))
    p.condition_path="res://qa/characters99/legacy.json";check(p.load_condition() and not m.registry.met.samuel_henrique,"real legacy checkpoint load")
    var occupied_legacy=legacy.duplicate(true);var old_anchor=samuel.global_position
    occupied_legacy.session81.position=[old_anchor.x,old_anchor.y,old_anchor.z]
    FileAccess.open("res://qa/characters99/occupied_legacy.json",FileAccess.WRITE).store_string(JSON.stringify(occupied_legacy))
    p.condition_path="res://qa/characters99/occupied_legacy.json"
    check(p.load_condition() and samuel.global_position.distance_to(p.global_position)>.6,"new encounter never blocks an old player checkpoint at its anchor")
    p.condition_path="res://qa/characters99/checkpoint.json";check(p.load_condition(),"restore new-format checkpoint")
    quick.reveal_left_r01=0;quick._process(0);check(quick.view_r01.visible and not quick.view_r01.cross_open,"approved R01 compact returns after dialogue")
    m.open("samuel_henrique");m.options.get_child(1).pressed.emit()
    check(m.active.is_empty() and not p.hud_open,"leave button releases dialogue")
    await capture(scene,"03_retorno_gameplay")
    FileAccess.open("res://qa/characters99/results.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks,"human_count":m.registry.definitions.size(),"physical_humans":m.actors.size(),"zombies":world.saved.size(),"anchor":[samuel.global_position.x,samuel.global_position.y,samuel.global_position.z]},"  "))
    print("R99_OK ",checks.size());get_tree().quit()
