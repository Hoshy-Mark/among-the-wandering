extends RefCounted
## Fixed identities. Presentation and simulation never change membership.
var definitions={}
var states={}
var clock=0.0
var next_incursion=300.0
var cursor=0
var configuration={}
var signature=""

func configure(config: Dictionary) -> bool:
    if config.get("version")!=1 or config.get("actors",[]).size()!=480:return false
    if not config.get("paths") is Dictionary:return false
    for path in config.paths.values():
        if not path is Array or path.is_empty():return false
        for point in path:
            if not _point(point):return false
    var counts={"house_residents":0,"urban_roamers":0,"distant_roamers":0}
    var proposed={}
    for definition in config.actors:
        if not definition.get("id") is String or proposed.has(definition.id) or not counts.has(definition.get("cohort")):return false
        if not _point(definition.get("position")) or not config.paths.has(definition.get("patrol")):return false
        proposed[definition.id]=definition.duplicate(true);counts[definition.cohort]+=1
    if counts!={"house_residents":90,"urban_roamers":90,"distant_roamers":300}:return false
    configuration=config.duplicate(true);definitions=proposed;signature=JSON.stringify(config).sha256_text();reset();return true

func reset() -> void:
    states.clear();clock=0.0;cursor=0
    next_incursion=float(configuration.migration_tuning.first_after_seconds)
    for id in definitions:
        var d=definitions[id]
        states[id]={"position":d.position.duplicate(),"health":.48,"mode":"confined" if d.cohort=="house_residents" else "patrol","route":d.patrol,"waypoint":0,"blocked":0.0}

func _number(value: Variant,lo: float,hi: float) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and value>=lo and value<=hi

func _point(value: Variant) -> bool:
    if not value is Array or value.size()!=3:return false
    for n in value:
        if not _number(n,-10000,10000):return false
    return true

func snapshot() -> Dictionary:
    return {"version":1,"catalog":signature,"clock":clock,"next_incursion":next_incursion,"cursor":cursor,"individuals":states.duplicate(true)}

func valid(data: Variant) -> bool:
    if not data is Dictionary or data.get("version")!=1 or data.get("catalog")!=signature or not data.get("individuals") is Dictionary:return false
    if not _number(data.get("clock"),0,1e12) or not _number(data.get("next_incursion"),0,1e12):return false
    if not _number(data.get("cursor"),0,299) or data.cursor!=floor(data.cursor):return false
    if data.individuals.size()!=definitions.size():return false
    for id in definitions:
        if not data.individuals.has(id) or not data.individuals[id] is Dictionary:return false
        var s=data.individuals[id];var d=definitions[id]
        if not _point(s.get("position")) or not _number(s.get("health"),0,.48) or s.get("mode") not in ["confined","patrol","migrating","arrived","dead"]:return false
        if (s.mode=="dead")!=(s.health==0):return false
        if not _number(s.get("blocked"),0,1e12):return false
        if not s.get("route") is String or s.route not in [d.patrol,d.entry]:return false
        if s.route.is_empty() or not configuration.paths.has(s.route):return false
        if s.mode=="migrating" and (d.cohort!="distant_roamers" or s.route!=d.entry):return false
        if s.mode=="arrived" and (d.cohort!="distant_roamers" or s.route!=d.entry or s.waypoint!=configuration.paths[s.route].size()-1):return false
        if s.mode=="confined" and d.cohort!="house_residents":return false
        if s.mode=="patrol" and d.cohort=="house_residents":return false
        if not _number(s.get("waypoint"),0,configuration.paths[s.route].size()-1) or s.waypoint!=floor(s.waypoint):return false
    return true

func restore(data: Variant) -> bool:
    if not valid(data):return false
    var proposed=data.individuals.duplicate(true)
    for s in proposed.values():s.waypoint=int(s.waypoint)
    states=proposed;clock=float(data.clock);next_incursion=float(data.next_incursion);cursor=int(data.cursor)
    return true

func damage(id: String,amount: float) -> bool:
    if not states.has(id) or not is_finite(amount) or amount<=0 or states[id].mode=="dead":return false
    states[id].health=maxf(0,states[id].health-amount)
    if states[id].health<=.00001:states[id].health=0;states[id].mode="dead"
    return true

func begin_incursion(id: String) -> bool:
    if not states.has(id) or definitions[id].cohort!="distant_roamers" or states[id].mode!="patrol":return false
    var route=definitions[id].entry
    if route.is_empty() or not configuration.paths.has(route):return false
    # The entry route starts at the initial anchor. Walk back to it first;
    # never reposition the individual when its intention changes.
    states[id].mode="migrating";states[id].route=route;states[id].waypoint=0
    return true

func schedule(delta: float) -> void:
    if not is_finite(delta) or delta<=0:return
    clock+=delta
    if clock<next_incursion:return
    next_incursion=clock+float(configuration.migration_tuning.interval_seconds)
    var busy=0
    for s in states.values():
        if s.mode=="migrating":busy+=1
    if busy>=int(configuration.migration_tuning.max_concurrent):return
    var candidates=[];var zones={}
    for id in definitions:
        if definitions[id].cohort!="distant_roamers":continue
        var zone=definitions[id].zone
        if not zones.has(zone):zones[zone]=[]
        zones[zone].append(id)
    for index in range(100):
        for group in zones.values():
            if index<group.size():candidates.append(group[index])
    for attempt in range(candidates.size()):
        var id=candidates[cursor];cursor=(cursor+1)%candidates.size()
        if begin_incursion(id):return
