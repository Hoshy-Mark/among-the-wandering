extends "res://tests/diagnostic116.gd"
var checks=[]
var max_scale=0.0
var max_elbow=0.0
var max_wrist=0.0
var original_inventory={}
var original_rounds={}
func check(ok: bool,message: String) -> void:
    checks.append({"passed":ok,"message":message})
    if not ok:push_error("R116_FAIL "+message)
func settle() -> void:
    for i in 500:
        game.player.action.advance(1.0/60);game.world_items.advance(1.0/60)
        game.player._update_equipment()
        var partial=game.world_items.progress.values().any(func(v):return v>.0001 and v<.9999)
        if game.player.action.state=="idle" and game.world_items.pending_id.is_empty() and not partial:return
    check(false,"action settles")
func find_item(definition: String) -> String:
    for uid in game.player.bag_inventory.items:
        if game.player.bag_inventory.items[uid].definition==definition:return uid
    return ""
func open_source(id: String) -> void:
    var w=game.world_items;var p=game.player
    w.close_interaction();settle();p.action.cancel();p.combat.set_guard(false)
    w.house.visit(id);p.update_nearby()
    check(w.request_open(id),"open physical source "+id);settle()
    for i in 3:await process_frame
    check(p.bag_inventory.accessible(id) and game.game_ui.nearby.visible,"physical source accessible "+id)
func capture(name: String) -> void:
    for i in 3:await process_frame
    await RenderingServer.frame_post_draw
    check(game.get_viewport().get_texture().get_image().save_jpg("res://qa/r116/"+name+".jpg",.88)==OK,"capture "+name)
func key(code: int) -> void:
    var e=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=true
    Input.parse_input_event(e)
    await process_frame;e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await process_frame
func inventory_tests() -> void:
    var p=game.player;var bag=p.bag_inventory;var ui=game.game_ui
    await open_source("world:arroio:H01_FURN_GUARDA_CASAL/storage/main")
    var backpack=find_item("bag_school");ui.select_item(backpack)
    await key(KEY_E);settle()
    check(bag.equipped("backpack")==backpack,"E equips backpack directly from wardrobe")
    await open_source("world:arroio:H01_FURN_GELADEIRA/storage/cooler")
    var water=find_item("water");var food=find_item("food");var saved=bag.items.duplicate(true)
    var grid: Control
    for candidate in ui.grids:
        if candidate.container_id==bag.items[water].location:grid=candidate;break
    check(grid!=null,"source grid exists")
    if grid!=null:
        var item=bag.items[water];var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
        event.position=Vector2(item.x*(grid.cell+4)+10,item.y*(grid.cell+4)+10)
        grid._gui_input(event);event=event.duplicate();event.pressed=false;grid._gui_input(event)
        for i in 3:await process_frame
    check(bag.items[water].location==backpack,"single click picks up water into backpack")
    var others_unchanged=true
    for uid in saved:
        if uid!=water and bag.items[uid]!=saved[uid]:others_unchanged=false
    check(others_unchanged,"quick pickup never rearranges other cells")
    ui.select_item(food);await key(KEY_F)
    check(bag.items[food].location==backpack,"F picks up selected food into backpack")
    check(not p.inventory_actions.busy(),"pickup is immediate without an equipment job")
    var repeated=bag.snapshot();ui.quick_pickup(food)
    check(bag.snapshot()==repeated,"repeated pickup cannot duplicate owned items")
    ui.personal.visible=true;ui.refresh()
    for i in 3:await process_frame
    await drag_item(food,"world:arroio:H01_FURN_GELADEIRA/storage/cooler",3,1)
    check(bag.items[food].location=="world:arroio:H01_FURN_GELADEIRA/storage/cooler","manual drag can return food to source")
    await drag_item(food,backpack,3,1)
    check(bag.items[food].location==backpack and bag.items[food].x==3 and bag.items[food].y==1,"external drag keeps chosen cells without triggering click pickup")
    await capture("01_clique_e_f_mochila")
    await open_source("world:arroio:H01_FURN_GUARDA_CASAL/storage/main")
    var rifle=find_item("carbine");var before=bag.snapshot();ui.quick_pickup(rifle)
    check(bag.snapshot()==before and ui.feedback.text.contains("espaço"),"oversized item leaves full source and backpack intact")
    ui.select_item(rifle);await key(KEY_E);settle()
    check(bag.equipped("main_hand")==rifle,"E equips long gun directly from wardrobe")
    await capture("02_e_equipar_armario")
    game.world_items.close_interaction();settle()
    before=bag.snapshot();var unreachable=find_item("revolver");ui.quick_pickup(unreachable)
    check(bag.snapshot()==before,"closed source cannot be looted via shortcut")
    bag.restore(original_inventory);p.weapons.rounds=original_rounds.duplicate(true);p.weapons.sync()
    ui.personal.visible=false;ui.nearby_wanted=false;ui.windows[1].visible=false;ui.refresh();p.set_hud_open(false)
func drag_item(uid: String,destination: String,x: int,y: int) -> void:
    var ui=game.game_ui;var item=game.player.bag_inventory.items[uid];var source: Control;var target: Control
    for grid in ui.grids:
        if grid.container_id==item.location:source=grid
        if grid.container_id==destination:target=grid
    check(source!=null and target!=null,"manual drag grids available")
    if source==null or target==null:return
    var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=Vector2(item.x*(source.cell+4)+10,item.y*(source.cell+4)+10)
    source._gui_input(press)
    var motion=InputEventMouseMotion.new();motion.position=press.position+Vector2(10,0);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;source._gui_input(motion)
    check(ui.drag_uid==uid,"drag threshold retains item operation")
    var release=InputEventMouseButton.new();release.button_index=MOUSE_BUTTON_LEFT;release.pressed=false;release.position=target.global_position+Vector2(x*(target.cell+4)+10,y*(target.cell+4)+10)
    ui._input(release)
    for i in 3:await process_frame
func measure_arms() -> void:
    var actor=game.player.avatar;var rig=actor.skeleton
    for side in ["L","R"]:
        for name in ["Clavicle.","UpperArm.","Forearm.","Hand."]:
            var basis=rig.get_bone_pose(rig.find_bone(name+side)).basis
            max_scale=maxf(max_scale,maxf(absf(basis.x.length()-1),maxf(absf(basis.y.length()-1),absf(basis.z.length()-1))))
        var values=actor.arm_articulation.joints[side];var e=Vector3(values.elbow[0],values.elbow[1],values.elbow[2]);var w=Vector3(values.wrist[0],values.wrist[1],values.wrist[2])
        max_elbow=maxf(max_elbow,(actor.arm_articulation._skin("UpperArm."+side)*e).distance_to(actor.arm_articulation._skin("Forearm."+side)*e))
        max_wrist=maxf(max_wrist,(actor.arm_articulation._skin("Forearm."+side)*w).distance_to(actor.arm_articulation._skin("Hand."+side)*w))
func firing_tests(pad: Vector3,gun: String,victim: CharacterBody3D) -> void:
    var p=game.player;var aim=game.shoulder;var helper=load("res://personagem/revisao91.gd").new()
    for distance in [.6,.9,1.2,3.0]:
        p.command=Vector2.ZERO;p.global_position=pad;p.avatar.rotation.y=0;p.condition_state.set_stamina(100)
        victim.restore(game.zombie_world.initial[victim.identity]);victim.ai_enabled=false
        victim.global_position=pad+Vector3(0,0,distance);victim.avatar.rotation.y=PI;victim.avatar.advance(0)
        for i in 2:await physics_frame
        check(aim.set_aim(true),"aim enters at distance "+str(distance))
        for i in 40:step(1.0/60)
        helper._look88(game,victim.global_position+Vector3.UP*1.2)
        p.weapons.rounds[gun]=6;aim.rng.seed=116
        check(aim.ready_to_fire(),"close zombie never acts as barrel obstruction "+str(distance))
        check(p.request_attack(),"shot accepted "+str(distance))
        for i in 65:step(1.0/60)
        check(p.weapons.loaded(gun)==5 and p.map_combat.last_shot.get("hit",false) and victim.health<.48,"shot damages zombie and consumes one round "+str(distance))
        var health=victim.health
        for i in 30:step(1.0/60)
        check(victim.health==health and p.weapons.loaded(gun)==5,"shot effect occurs once "+str(distance))
        if distance==.9:await capture("03_tiro_zumbi_proximo")
        aim.set_aim(false)
        for i in 40:step(1.0/60)
    victim.global_position=pad+Vector3(0,0,3);victim.state="idle";victim.health=.48;victim.seen.clear()
    p.global_position=pad;p.avatar.rotation.y=0;p.weapons.rounds[gun]=6
    var human=game.get_node("Characters99").actors.values()[0];var original_position=human.global_position;human.global_position=pad+Vector3(0,0,1.4)
    for i in 2:await physics_frame
    check(aim.set_aim(true),"aim can target protected human")
    for i in 45:step(1.0/60)
    helper._look88(game,human.global_position+Vector3.UP*1.2)
    var hit=aim.aim_ray();check(hit.get("collider")==human and str(hit.get("zone","")).is_empty(),"human intercepts ray without a damage region")
    check(p.request_attack(),"firing toward protected human is accepted")
    for i in 65:step(1.0/60)
    check(not p.map_combat.last_shot.hit and victim.health==.48 and not human.has_method("receive_combat_hit"),"protected human blocks damage and penetration to zombie")
    human.global_position=original_position;aim.set_aim(false)
    for i in 40:step(1.0/60)
    var wall=StaticBody3D.new();var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(3,2,.12);shape.shape=box;wall.add_child(shape);game.add_child(wall);wall.global_position=pad+Vector3(0,1,1.5)
    for i in 2:await physics_frame
    p.global_position=pad;p.avatar.rotation.y=0;p.weapons.rounds[gun]=6
    check(aim.set_aim(true),"wall scenario enters aim")
    for i in 45:step(1.0/60)
    helper._look88(game,victim.global_position+Vector3.UP*1.2)
    check(p.request_attack(),"shot against distant wall is allowed")
    for i in 65:step(1.0/60)
    check(not p.map_combat.last_shot.hit and victim.health==.48 and p.weapons.loaded(gun)==5,"solid wall still intercepts bullet")
    aim.set_aim(false)
    for i in 40:step(1.0/60)
    wall.queue_free();for i in 2:await physics_frame
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/r116"));DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/performance114"))
    set_meta("demo95_fresh",true);set_meta("demo95_profile_override","res://qa/r116/profile.json")
    game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
    while not game.demo_ready:await process_frame
    game.get_window().size=Vector2i(1280,720)
    var p=game.player;var aim=game.shoulder;var w=game.zombie_world
    load("res://personagem/revisao98.gd").new()._freeze98(game)
    game.world_items.set_physics_process(false);game.get_node("Characters99").ambient_elapsed109=-100000
    for h in game.get_node("Characters99").actors.values():h.set_physics_process(false)
    original_inventory=p.bag_inventory.snapshot();original_rounds=p.weapons.rounds.duplicate(true)
    await inventory_tests()
    var helper=load("res://personagem/revisao91.gd").new();var pad=helper._field(game)
    p.global_position=pad;p.avatar.rotation.y=0;p.bag_inventory.seeding=true
    var gun=p.bag_inventory.add("pistol",1,"slot:main_hand");p.bag_inventory.seeding=false;p.weapons.sync()
    check(not gun.is_empty(),"QA pistol equips")
    game.focus=pad+Vector3.UP*.95;game._update_camera()
    var id=w.model.definitions.keys()[0];w._activate(id);var victim=w.actors[id];victim.ai_enabled=false
    victim.global_position=pad+Vector3(0,0,3);victim.avatar.advance(0)
    for fps in [30,60,120]:
        for cycle in 30:
            aim.set_aim(false);p.command=Vector2(1,0)
            for i in 8:step(1.0/fps);measure_arms()
            p.global_position=pad;p.avatar.rotation.y=0
            check(aim.set_aim(true),"repeat aim enters %d/%d"%[fps,cycle]);aim.pitch=.3
            for i in 12:step(1.0/fps);measure_arms()
        aim.set_aim(false);p.command=Vector2.ZERO
        for i in fps:step(1.0/fps);measure_arms()
    check(max_scale<.002,"repeated aim has no residual scale/shear")
    check(max_elbow<.04 and max_wrist<.015,"elbow and wrist seams remain coherent")
    await capture("04_bracos_apos_90_transicoes")
    await firing_tests(pad,gun,victim)
    aim.set_aim(false);for i in 40:step(1.0/60)
    for definition in ["revolver","carbine"]:
        p.bag_inventory.items.erase(gun);p.bag_inventory.seeding=true;gun=p.bag_inventory.add(definition,1,"slot:main_hand");p.bag_inventory.seeding=false;p.weapons.sync()
        for cycle in 30:
            p.global_position=pad;p.avatar.rotation.y=0;p.command=Vector2.ZERO
            check(aim.set_aim(true),"arsenal repeated aim "+definition+" "+str(cycle))
            aim.pitch=.3
            for i in 15:step(1.0/60);measure_arms()
            aim.set_aim(false);p.command=Vector2(1,0)
            for i in 10:step(1.0/60);measure_arms()
        p.command=Vector2.ZERO
        for i in 60:step(1.0/60)
    check(max_scale<.002 and max_elbow<.04 and max_wrist<.015,"three firearm types preserve scale and arm seams")
    game.world_items.close_interaction();settle();p.locomotion.cancel();p.combat.set_guard(false);p.action.cancel();p.flow.queue.clear()
    p.global_position=game.spawn;p.bag_inventory.restore(original_inventory);p.weapons.rounds=original_rounds.duplicate(true);p.weapons.sync();w.restore(w.initial)
    print("R116_SAVE_PREFLIGHT ",p.session_save._idle()," ",p.action.state," ",p.combat.state)
    var regression=await load("res://tests/regression114.gd").new().run(game)
    check(regression,"previous doors/windows/fences/save regression")
    var result={"passed":checks.all(func(c):return c.passed),"checks":checks,"max_scale_error":max_scale,"max_elbow_m":max_elbow,"max_wrist_m":max_wrist,"population":w.saved.size(),"humans":game.get_node("Characters99").actors.size()}
    FileAccess.open("res://qa/r116/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("REVIEW116_DONE ",JSON.stringify(result));quit(0 if result.passed else 1)
