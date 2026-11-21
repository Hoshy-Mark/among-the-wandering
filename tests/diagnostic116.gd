extends SceneTree
var game: Node3D
var baseline_scripts116=[]
func _initialize() -> void:call_deferred("run")
func step(dt: float) -> void:
    game.shoulder._physics_process(dt);game.player._physics_process(dt);game.shoulder.advance(dt)
func run() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/r116"))
    if "--baseline116" in OS.get_cmdline_user_args():
        for name in ["personagem","mira_ombro88","mira_ambiente89","postura_armas92","combate_mapa92"]:
            var script=load("res://personagem/"+name+".gd")
            script.source_code=FileAccess.get_file_as_string("res://tests/fixtures116/"+name+"_r115.txt")
            if script.reload()!=OK:quit(1);return
            baseline_scripts116.append(script)
    set_meta("demo95_fresh",true);set_meta("demo95_profile_override","res://qa/r116/profile.json")
    game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
    while not game.demo_ready:await process_frame
    var p=game.player;var w=game.zombie_world;var aim=game.shoulder;var helper=load("res://personagem/revisao91.gd").new()
    load("res://personagem/revisao98.gd").new()._freeze98(game)
    for h in game.get_node("Characters99").actors.values():h.set_physics_process(false)
    var bag=p.bag_inventory;bag.seeding=true
    var gun=bag.add("pistol",1,"slot:main_hand");bag.seeding=false
    p.weapons.sync();p.weapons.rounds[gun]=6
    var pad=helper._field(game);p.global_position=pad;p.velocity=Vector3.ZERO;p.avatar.rotation.y=0
    game.focus=pad+Vector3.UP*.95;game._update_camera()
    var id=w.model.definitions.keys()[0];w._activate(id);var victim=w.actors[id];victim.ai_enabled=false
    victim.global_position=pad+Vector3(0,0,3);victim.avatar.rotation.y=PI;victim.avatar.advance(0)
    for i in 3:await physics_frame
    var accepted=aim.set_aim(true)
    for i in 45:step(1.0/60)
    helper._look88(game,victim.global_position+Vector3.UP*1.2)
    for i in 20:step(1.0/60)
    var attempted=p.request_attack()
    for i in 60:step(1.0/60)
    var shots={"aim":accepted,"attempt":attempted,"ready":aim.ready_to_fire(),"barrel":aim.barrel_obstructed(),"view_blocked":aim.view_blocked,"ammo":p.weapons.loaded(gun),"last_shot":str(p.map_combat.last_shot),"message":p.inventory_message,"motion":p.avatar.motion,"combat":p.combat.state,"action":p.action.state,"hud":p.hud_open,"flow":p.flow.queue}
    print("DIAG116_SHOT ",JSON.stringify(shots))
    var poses=[]
    for cycle in 80:
        aim.set_aim(false)
        p.command=Vector2(1,0)
        for i in 15:step(1.0/60)
        aim.set_aim(true);aim.pitch=.3
        for i in 15:step(1.0/60)
        var row={"cycle":cycle,"motion":p.avatar.motion,"bones":{}}
        for name in ["UpperArm.L","Forearm.L","Hand.L","UpperArm.R","Forearm.R","Hand.R"]:
            var rig=p.avatar.skeleton;var bone=rig.find_bone(name)
            row.bones[name]=str(rig.get_bone_pose(bone))
        poses.append(row)
    var distances=[]
    aim.set_aim(false)
    for i in 40:step(1.0/60)
    p.command=Vector2.ZERO;p.global_position=pad;p.avatar.rotation.y=0
    for distance in [.6,.9,1.2,2.0,3.0]:
        victim.global_position=pad+Vector3(0,0,distance);victim.state="idle";victim.health=.48;victim.seen.clear()
        if not victim.is_in_group("combat_receivers79"):victim.add_to_group("combat_receivers79")
        victim.avatar.advance(0)
        aim.set_aim(true)
        for i in 40:step(1.0/60)
        helper._look88(game,victim.global_position+Vector3.UP*1.2)
        var ray=aim.aim_ray()
        distances.append({"distance":distance,"ready":aim.ready_to_fire(),"barrel":aim.barrel_obstructed(),"zone":ray.get("zone",""),"collider":str(ray.get("collider")),"view_blocked":aim.view_blocked})
        aim.set_aim(false)
        for i in 40:step(1.0/60)
    print("DIAG116_CLOSE ",JSON.stringify(distances))
    FileAccess.open("res://qa/r116/diagnostic"+("_baseline" if "--baseline116" in OS.get_cmdline_user_args() else "")+".json",FileAccess.WRITE).store_string(JSON.stringify({"shots":shots,"poses":poses,"distances":distances},"  "))
    print("DIAGNOSTIC116_DONE");quit()
