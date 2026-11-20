extends "res://personagem/qa_social109.gd"
func check(value: bool,message: String) -> void:
    if not value:push_error("R112_FAIL "+message);get_tree().quit(1);assert(value,message)
    checks.append(message);print("R112_CHECK ",message)
func find112(bag: RefCounted,id: String) -> String:
    for uid in bag.items:
        if bag.items[uid].definition==id:return uid
    return ""
func settle112(scene: Node3D,seconds: float=0) -> void:
    var p=scene.player
    for tick in range(600):
        p.action.advance(1.0/60);scene.world_items.advance(1.0/60);p.avatar.advance(0)
        var partial=scene.world_items.progress.values().any(func(value):return value>.0001 and value<.9999)
        if tick>=ceili(seconds*60) and p.action.state=="idle" and scene.world_items.pending_id.is_empty() and not partial:break
    check(p.action.state=="idle" and scene.world_items.pending_id.is_empty(),"action and furniture settle")
func open112(scene: Node3D,id: String,keyboard: bool=false) -> void:
    var w=scene.world_items;var p=scene.player;w.close_interaction();settle112(scene);h._player_idle(p);w.house.visit(id);p.update_nearby()
    var group=w.house.bindings[id]
    if w.house.groups[group].has("drawers"):w.chosen_drawer[group]=w.house.groups[group].drawers.keys().find(id)
    w._update_prompt();await frames(scene,3)
    check(id in p.bag_inventory.reachable,"physical source reachable "+id)
    if keyboard:
        await key(scene,KEY_E);check(w.pending_id==id or w.active_id==id,"E targets expected physical source")
    else:check(w.request_open(id),"source opens through authoritative interaction "+id)
    settle112(scene);await frames(scene,4);check(w.active_id==id and p.bag_inventory.accessible(id),"source contents accessible after opening")
func shot112(scene: Node,name112: String) -> void:
    await frames(scene,5);await RenderingServer.frame_post_draw
    check(scene.get_viewport().get_texture().get_image().save_png("res://qa/supplies112/"+name112+".png")==OK,"native capture "+name112)
func run(scene: Node3D) -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/supplies112"))
    var p=scene.player;var bag=p.bag_inventory;var w=scene.world_items;var m=scene.get_node("Characters99");var quick=p.get_node("Atalhos93")
    if "--preview-supplies112" in OS.get_cmdline_user_args():check(p.condition_path=="user://preview_supplies112.json","review launcher selects isolated profile before gameplay")
    h._freeze98(scene);h._player_idle(p);quick.scripted=false;w.set_physics_process(false);m.ambient_elapsed109=-100000
    scene.get_window().size=Vector2i(1280,720);p.condition_path="res://qa/supplies112/checkpoint.json"
    if "--supplies112-reopen" in OS.get_cmdline_user_args():
        check(p.load_condition(),"fresh process loads depleted supply campaign")
        var expected=JSON.parse_string(FileAccess.get_file_as_string("res://qa/supplies112/expected.json"))
        check(h.helper._same(bag.snapshot(),expected.inventory),"fresh process keeps exact manual item layout and depletion")
        check(m.social.snapshot()==m.social.validate(expected.social),"fresh process retains nine-character knowledge and directional network")
        check(not bag.items.has(expected.water_uid) and int(bag.items[expected.food_uid].count)==1,"consumed resources never regenerate on restart")
        check(p.weapons.loaded(expected.weapon_uid)==6,"loaded ammunition survives restart")
        check(scene.zombie_world.saved.size()==480 and m.actors.size()==9,"fixed zombie population and nine current actors retained")
        await open112(scene,"world:arroio:H01_FURN_GELADEIRA/storage/cooler");check(bag.contents("world:arroio:H01_FURN_GELADEIRA/storage/cooler").is_empty(),"opening empty source after restart adds no loot")
        await shot112(scene,"07_geladeira_vazia_reaberta")
        await open112(scene,"world:arroio:H01_FURN_COMODA_CASAL/storage/drawer_2")
        check(bag.can_touch(find112(bag,"revolver")),"second dresser drawer makes revolver physically accessible")
        await shot112(scene,"08_revolver_na_gaveta")
        await open112(scene,"world:arroio:H01_FURN_RACK01/storage/drawer_2")
        check(bag.can_touch(find112(bag,"ammo_carbine")),"second rack drawer makes long-gun ammunition accessible")
        finish112(true);return
    check(scene.demo_data.get("supply_revision112")==1,"new physical-source recipe installed")
    check(bag.items.size()==20 and bag.valid(bag.items),"new game has complete valid initial inventory")
    check(bag.world_containers.values().all(func(entry):return entry.has("furniture")),"no laboratory floor arsenals remain in new game")
    var original_social=m.social.snapshot();var avatar=p.avatar.selection.duplicate(true)
    var groups=[]
    for source in scene.demo_data.loot:
        var id="world:arroio:"+source.furniture;var group=w.house.bindings[id]
        if group in groups:continue
        groups.append(group);await open112(scene,id,group=="H01_FURN_GUARDA_CASAL");w.close_interaction();settle112(scene)
    check(groups.size()==8,"all stocked furniture groups have physical access")
    var closet="world:arroio:H01_FURN_GUARDA_CASAL/storage/main";await open112(scene,closet,true)
    var backpack=find112(bag,"bag_school");var rifle=find112(bag,"carbine")
    check(bag.items[rifle].location==closet and bag.items[rifle].rot and bag.items[rifle].y==4,"long gun fits authored wardrobe cells without automatic packing")
    check(p.equip_item(backpack),"backpack equips from real wardrobe");settle112(scene);check(bag.equipped("backpack")==backpack,"backpack uses existing equipment authority")
    scene.game_ui.personal.visible=true;scene.game_ui.refresh();await shot112(scene,"01_mochila_e_armario")
    var fridge="world:arroio:H01_FURN_GELADEIRA/storage/cooler";await open112(scene,fridge)
    var water=find112(bag,"water");var food=""
    for uid in bag.contents(fridge):
        if bag.items[uid].definition=="food":food=uid
    check(p.place_item(water,backpack,0,0,false) and p.place_item(food,backpack,3,0,false),"player chooses manual backpack cells")
    check(bag.contents(fridge).is_empty(),"taking food and water depletes physical refrigerator")
    scene.game_ui.personal.visible=true;scene.game_ui.refresh();await shot112(scene,"02_recursos_transferidos")
    w.close_interaction();settle112(scene);scene.game_ui.personal.hide();scene.game_ui.sync_lock();p.condition_state.hunger=70;p.condition_state.thirst=80
    var stock=bag.snapshot();var condition=p.condition_state.snapshot();check(p.use_item(food),"food starts actual use action");p.action.advance(.03);p.action.cancel()
    check(bag.snapshot()==stock and p.condition_state.snapshot()==condition,"cancel before effect consumes nothing")
    check(p.use_item(food),"food use restarts deliberately");settle112(scene);check(bag.items[food].count==1 and p.condition_state.hunger==40,"food consumes once and reduces hunger")
    check(p.use_item(water),"water starts actual use action");settle112(scene);check(not bag.items.has(water) and p.condition_state.thirst==45,"last water unit consumed exactly once")
    var after_use=bag.snapshot();p.action.advance(10);check(bag.snapshot()==after_use,"completed action cannot consume twice")
    var rack="world:arroio:H01_FURN_RACK01/storage/drawer_1";await open112(scene,rack)
    var pistol=find112(bag,"pistol");var ammo=find112(bag,"ammo_pistol")
    check(p.place_item(ammo,"pockets",2,0,false),"ammo manually transferred from physical drawer to pockets")
    check(p.equip_item(pistol),"pistol equips through C05 from physical rack");settle112(scene);check(quick.bind("left",pistol),"existing quickslot binds physical weapon")
    scene.game_ui.personal.show();scene.game_ui.refresh();await shot112(scene,"03_arma_na_gaveta")
    w.close_interaction();settle112(scene);scene.game_ui.personal.hide();scene.game_ui.sync_lock()
    check(p.weapons.reload_weapon(),"reload uses owned finite ammo");settle112(scene);check(p.weapons.loaded(pistol)==6 and bag.items[ammo].count==12,"reload transfers six rounds without duplicating stock")
    check(m.social.snapshot()==original_social and p.avatar.selection==avatar,"supply work leaves social network and character appearance intact")
    var before=bag.snapshot();var recipe=scene.demo_data.duplicate(true);scene.demo_data.loot[-1].items.append({"definition":"missing112","count":1,"x":0,"y":1})
    check(not scene._new_inventory() and bag.snapshot()==before,"late invalid new-game recipe leaves live inventory untouched");scene.demo_data=recipe
    check(p.save_condition(),"complete supply campaign saves with open states and manual cells")
    var expected={"inventory":bag.snapshot(),"social":m.social.snapshot(),"food_uid":food,"water_uid":water,"weapon_uid":pistol}
    FileAccess.open("res://qa/supplies112/expected.json",FileAccess.WRITE).store_string(JSON.stringify(expected))
    check(p.load_condition() and h.helper._same(bag.snapshot(),expected.inventory),"reload reproduces depleted sources and manual positions")
    await open112(scene,fridge);check(bag.contents(fridge).is_empty(),"empty source stays empty when reopened");await shot112(scene,"04_estoque_finito");w.close_interaction();settle112(scene)
    var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://qa/social109/checkpoint.json"));var legacy_hash=FileAccess.get_sha256("res://qa/social109/checkpoint.json")
    p.condition_path="res://qa/social109/checkpoint.json";check(p.load_condition(),"real R109 full campaign remains loadable")
    check(bag.world_containers.has("world:weapons86") and h.helper._same(bag.snapshot(),legacy.inventory),"legacy ground arsenals and every saved item preserved")
    check(FileAccess.get_sha256(p.condition_path)==legacy_hash,"old checkpoint never rewritten by load")
    p.condition_path="res://qa/supplies112/checkpoint.json";check(p.load_condition() and h.helper._same(bag.snapshot(),expected.inventory),"R112 state restores after older save without merging loot")
    check(m.actors.size()==9 and scene.zombie_world.saved.size()==480,"current nine humans and fixed 480 population retained")
    await enter109(scene,m,"ana_julia");await shot112(scene,"05_personagens_preservados");m.close()
    await key(scene,KEY_P);m.skills_ui.select_tab(0);check(m.skills_ui.buttons.size()==4,"four active skills retained");await shot112(scene,"06_menu_preservado");await key(scene,KEY_ESCAPE)
    finish112(false)
func finish112(fresh112: bool) -> void:
    FileAccess.open("res://qa/supplies112/"+("fresh.json" if fresh112 else "results.json"),FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"checks":checks},"  "));get_tree().quit()
