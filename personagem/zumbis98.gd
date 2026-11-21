extends Node3D
## All 480 individuals always exist in model/saved. actors contains presentation
## and full combat physics near the player, never newly generated identities.
const ENTER=36.0
const LEAVE=54.0
const LEGACY={"arroio82_01":"arr96_urban_001","arroio82_02":"arr96_urban_002"}
var scene: Node3D
var actors={}
var initial={}
var saved={}
var navigation: Node3D
var motor: Node3D
var model: RefCounted
var config={}
var accumulator=0.0
var rid_cache: Array[RID]=[]
var peak_live=0
var activations=0
var retirements=0
func setup(root_scene: Node3D) -> void:
    scene=root_scene;process_physics_priority=-10
    if not configure_population():push_error("Invalid fixed population catalog");return
    navigation=load("res://personagem/navegacao98.gd").new();add_child(navigation);navigation.setup(self)
    motor=load("res://personagem/motor_populacao98.gd").new();motor.set_meta("skip_setup97",true);add_child(motor)
    motor.manager=self;motor.city=scene.city;motor.config=config;motor.registry=model
    motor.shape=CapsuleShape3D.new();motor.shape.radius=.23;motor.shape.height=1.84
    motor.index_population();_reconcile(2)
func configure_population() -> bool:
    config=JSON.parse_string(FileAccess.get_file_as_string("res://population97/populacao97.json"))
    model=load("res://personagem/registro98.gd").new()
    if not model.configure(config):return false
    saved.clear()
    for id in model.definitions:
        var s=model.states[id]
        saved[id]={"position":s.position.duplicate(),"yaw":float(posmod(hash(id),628))*.01,"health":.48,"state":"idle","memory":0.0,"last_known":s.position.duplicate(),"cooldown":0.0,"search_remaining84":0.0,"variant85":variant(id),"ambient98":ambient(id)}
    initial=saved.duplicate(true);return valid(saved)
func variant(id: String) -> String:
    if id==LEGACY.arroio82_01:return "errante"
    if id==LEGACY.arroio82_02:return "alerta"
    return "errante" if posmod(hash(id),3)!=0 else "alerta"
func ambient(id: String) -> Dictionary:
    var s=model.states[id]
    return {"wait":s.wait97,"visits":s.visits97,"direction":s.direction97,"waypoint":s.waypoint}
func actor_rids() -> Array[RID]:return rid_cache
func _refresh_rids() -> void:
    rid_cache.clear()
    for actor in actors.values():rid_cache.append(actor.get_rid())
func _activate(id: String) -> void:
    if actors.has(id):return
    var actor=load("res://personagem/zumbi98.gd").new();actor.population=self;add_child(actor)
    var short=posmod(hash(id),2)==0
    if id==LEGACY.arroio82_01:short=true
    if id==LEGACY.arroio82_02:short=false
    actor.setup(scene,{"id":id,"hair":"curto_blocado" if short else "none","shirt":"camiseta_oliva" if short else "moletom_cinza","yaw":saved[id].yaw})
    actors[id]=actor;_refresh_rids();actor.restore(saved[id]);actor.changed.connect(func():sync_actor(actor))
    activations+=1;peak_live=maxi(peak_live,actors.size())
func sync_actor(actor: CharacterBody3D) -> void:
    var id=actor.identity;var entry=actor.snapshot();entry.ambient98=ambient(id);saved[id]=entry
    var s=model.states[id]
    motor.sync_position115(id,motor.point(s.position),s.mode!="dead",motor.point(entry.position),entry.health>.0001)
    s.position=entry.position.duplicate();s.health=entry.health
    s.mode="dead" if entry.health<=.0001 else "confined" if model.definitions[id].cohort=="house_residents" else "patrol"
func _retire(id: String) -> void:
    var actor=actors[id];sync_actor(actor);actor.clear_route();actors.erase(id);_refresh_rids()
    remove_child(actor);actor.queue_free();retirements+=1
func _reconcile(budget: int=2) -> void:
    var wanted=[];var p=scene.player.global_position
    for id in saved:
        var distance=motor.point(saved[id].position).distance_squared_to(p)
        var pursuing=saved[id].state in ["chase","search"] and saved[id].memory>0
        if not actors.has(id) and (distance<ENTER*ENTER or pursuing):wanted.append({"id":id,"d":distance,"pursuing":pursuing})
    wanted.sort_custom(func(a,b):return a.d<b.d)
    for row in wanted:
        if budget<=0 and row.d>15*15 and not row.pursuing:continue
        _activate(row.id);budget-=1
    for id in actors.keys():
        var actor=actors[id]
        if actor.global_position.distance_squared_to(p)>LEAVE*LEAVE and actor.state in ["idle","dead"] and not actor.crossing.is_active():_retire(id)
func _physics_process(delta: float) -> void:
    if scene==null or scene.player.paused:return
    var demo=scene.player.get_node_or_null("Demo95")
    if demo!=null and demo.state!="alive":return
    model.clock+=delta
    for actor in actors.values():sync_actor(actor)
    # The ambient step rebuilds once at 5 Hz; live actors update their cells on sync.
    accumulator+=delta
    if accumulator<.2:return
    var step=minf(accumulator,.4);accumulator=0
    var ids=[]
    for id in saved:
        if not actors.has(id):ids.append(id)
    motor.ids=ids;motor._step(step)
    for id in ids:saved[id].position=model.states[id].position.duplicate();saved[id].ambient98=ambient(id)
    _reconcile()
func wander_live(actor: CharacterBody3D,delta: float) -> void:
    sync_actor(actor)
    var before=actor.global_position;var proposed=motor.ambient_point(actor.identity,delta)
    actor.velocity.x=(proposed.x-before.x)/delta;actor.velocity.z=(proposed.z-before.z)/delta
    actor.velocity.y=-.2 if actor.is_on_floor() else actor.velocity.y-20*delta
    actor.move_and_slide()
    var direction=actor.global_position-before;direction.y=0
    if direction.length()>.0001:actor.avatar.rotation.y=lerp_angle(actor.avatar.rotation.y,atan2(direction.x,direction.z),minf(1,delta*4))
    sync_actor(actor)
func settled() -> bool:
    for actor in actors.values():
        if actor.crossing.is_active() or actor.state in ["attack","hit","dying","crossing"]:return false
    return true
func snapshot() -> Dictionary:
    for actor in actors.values():sync_actor(actor)
    for id in saved:saved[id].ambient98=ambient(id)
    return saved.duplicate(true)
func valid_entry(entry: Variant,id: String,with_ambient: bool=true) -> bool:
    if not entry is Dictionary or entry.get("state") not in ["idle","chase","search","dead"]:return false
    for key in ["position","last_known"]:
        if not model._point(entry.get(key)):return false
    for key in ["yaw","health","memory","cooldown"]:
        if not model._number(entry.get(key),-10000,10000):return false
    if entry.health<0 or entry.health>.48 or (entry.state=="dead")!=(entry.health<=.0001) or entry.memory<0 or entry.memory>4 or entry.cooldown<0 or entry.cooldown>1.2:return false
    if not model._number(entry.get("search_remaining84",0),0,12):return false
    if entry.get("variant85",variant(id)) not in ["errante","alerta"]:return false
    if not with_ambient:return true
    var a=entry.get("ambient98")
    if not a is Dictionary or not model._number(a.get("wait"),0,4) or not model._number(a.get("visits"),0,1e12) or a.visits!=floor(a.visits):return false
    if not model._number(a.get("direction"),-1,1) or absf(a.direction)!=1:return false
    return model._number(a.get("waypoint"),0,config.paths[model.definitions[id].patrol].size()-1) and a.waypoint==floor(a.waypoint)
func valid(data: Variant) -> bool:
    if not data is Dictionary or data.size()!=480:return false
    for id in model.definitions:
        if not data.has(id) or not valid_entry(data[id],id):return false
    return true
func expand_legacy(data: Variant) -> Dictionary:
    if not data is Dictionary or data.size()!=2:return {}
    var result=initial.duplicate(true)
    for legacy_id in LEGACY:
        var id=LEGACY[legacy_id]
        if not data.has(legacy_id) or not valid_entry(data[legacy_id],id,false):return {}
        var entry=data[legacy_id].duplicate(true);entry.ambient98=result[id].ambient98
        result[id]=entry
    return result
func restore(data: Dictionary) -> void:
    if not valid(data):return
    saved=data.duplicate(true)
    for id in saved:
        var entry=saved[id];var s=model.states[id];var a=entry.ambient98
        s.position=entry.position.duplicate();s.health=entry.health;s.wait97=float(a.wait);s.visits97=int(a.visits);s.direction97=int(a.direction);s.waypoint=int(a.waypoint)
        s.mode="dead" if entry.state=="dead" else "confined" if model.definitions[id].cohort=="house_residents" else "patrol"
    for id in actors:actors[id].restore(saved[id])
    if motor!=null:motor.index_population();_reconcile(480)
