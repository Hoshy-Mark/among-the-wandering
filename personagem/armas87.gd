extends "res://personagem/armas86.gd"
const FIRE_CACHE="world:firearms87"
var rounds: Dictionary={}
var reload_job: Dictionary={}
var flash_left=0.0
var status: Label
var shot_audio: AudioStreamPlayer3D
func setup(root_scene: Node3D) -> void:
    super.setup(root_scene)
    visual.queue_free()
    visual=load("res://personagem/arma_visual87.gd").new();scene.player.avatar.add_child(visual);scene.player.combat.weapon=visual
    load("res://personagem/poses_fogo87.gd").new().setup(scene.player.avatar)
    scene.player.combat.definitions.firearm_shot={"duration":.48,"impact_time":.10,"right_pose":"Cylinder","left_pose":"Fist"}
    held_definition="";held_uid="";sync()
    scene.player.action.cancelled.connect(func(_kind,_done):reload_job.clear())
    scene.player.action.finished.connect(func():reload_job.clear())
    status=Label.new();status.position=Vector2(20,50);status.mouse_filter=Control.MOUSE_FILTER_IGNORE
    scene.game_ui.add_child(status)
    shot_audio=AudioStreamPlayer3D.new();shot_audio.volume_db=-12;shot_audio.max_distance=24
    var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_8_BITS;stream.mix_rate=22050
    var samples=PackedByteArray();samples.resize(3308)
    var random=RandomNumberGenerator.new();random.seed=87
    for index in samples.size():
        var seconds=index/22050.0
        var value=(random.randf_range(-1,1)*.8+sin(seconds*TAU*110)*.2)*exp(-seconds*42)
        samples[index]=clampi(roundi(128+value*110),0,255)
    stream.data=samples;shot_audio.stream=stream;scene.player.avatar.add_child(shot_audio)
func sync() -> void:
    if scene!=null:
        var bag=scene.player.bag_inventory
        for uid in rounds.keys():
            if not bag.items.has(uid) or bag.items[uid].definition!="pistol":rounds.erase(uid)
        for uid in bag.items:
            if bag.items[uid].definition=="pistol" and not rounds.has(uid):rounds[uid]=0
        scene.player.combat.firearm_mode=spec(bag.equipped("main_hand")).get("type","")=="firearm"
    super.sync()
func seed(model: RefCounted) -> bool:
    return super.seed(model) and seed_firearms(model)
func seed_firearms(model: RefCounted) -> bool:
    var missing=[]
    for id in ["pistol","ammo_pistol"]:
        if not model.items.values().any(func(item):return item.definition==id):missing.append(id)
    if missing.is_empty():return true
    if model.world_containers.has(FIRE_CACHE):return false
    var raw: Array=scene.demo_data.spawn_local
    var point=scene.world_items.house.home.model.to_global(Vector3(raw[0],raw[1],raw[2]))
    var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,point-Vector3.UP,1)
    var floor=get_world_3d().direct_space_state.intersect_ray(ray)
    if floor.is_empty():return false
    point.y=floor.position.y+.01
    model.world_containers[FIRE_CACHE]={"name":"Chão · Equipamento de tiro","kind":"ground","capacity":999,"position":[point.x,point.y,point.z]}
    for id in missing:
        if model.add_at(id,1 if id=="pistol" else 18,FIRE_CACHE,0 if id=="pistol" else 2,0,false).is_empty():return false
    return true
func loaded(uid: String) -> int:return int(rounds.get(uid,0))
func reload_weapon() -> bool:
    var p=scene.player;var bag=p.bag_inventory;var uid=bag.equipped("main_hand");var info=spec(uid)
    if not scene.player.map_combat.ready_to_act() or not reload_job.is_empty() or p.combat.is_attacking() or info.get("type","")!="firearm":return false
    var needed=int(info.capacity)-loaded(uid)
    if needed<=0:p.inventory_message="Arma carregada";return false
    var taken={}
    for key in bag.items:
        if bag.items[key].definition==info.ammo and bag.owned(key):
            var count=mini(needed,int(bag.items[key].count));taken[key]=count;needed-=count
            if needed==0:break
    if taken.is_empty():p.inventory_message="Leve munição nos bolsos ou na mochila";return false
    if not p._prepare_action():return false
    reload_job={"uid":uid,"rounds":loaded(uid),"items":bag.items.duplicate(true),"taken":taken,"origin":p.global_position}
    if not p.action.begin(_commit_reload,"equip"):reload_job.clear();return false
    p.inventory_message="Recarregando...";return true
func _commit_reload() -> bool:
    if reload_job.is_empty():return false
    var p=scene.player;var bag=p.bag_inventory;var job=reload_job
    if bag.equipped("main_hand")!=job.uid or bag.items!=job.items or loaded(job.uid)!=job.rounds or p.global_position.distance_to(job.origin)>.05:return false
    var staged=bag.items.duplicate(true);var added=0
    for uid in job.taken:
        if not bag.owned(uid):return false
        staged[uid].count-=job.taken[uid];added+=job.taken[uid]
        if staged[uid].count==0:staged.erase(uid)
    if not bag._commit(staged,false):return false
    rounds[job.uid]=int(job.rounds)+added
    bag.changed.emit();p.inventory_message="Arma carregada: %d/%d"%[loaded(job.uid),int(spec(job.uid).capacity)]
    return true
func flash() -> void:
    flash_left=.06
    if shot_audio!=null:shot_audio.play()
    if visual.muzzle!=null:visual.muzzle.visible=true
func _physics_process(delta: float) -> void:
    if scene==null or scene.player.paused:return
    if status!=null:
        status.visible=spec(held_uid).get("type","")=="firearm"
        status.text="Pistola · %d/6 · R recarregar"%loaded(held_uid)
    flash_left=maxf(0,flash_left-delta)
    if visual!=null and visual.muzzle!=null:visual.muzzle.visible=flash_left>0
