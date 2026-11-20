extends Node3D
const CELL=.55
const MAX_NODES=2400
var world: Node3D
var jobs=[]
var serial=0
var max_slice_us=0
var completed=[]
var capsule: CapsuleShape3D
var foot: SphereShape3D
func setup(manager: Node3D) -> void:
    world=manager
    capsule=CapsuleShape3D.new();capsule.radius=.23;capsule.height=1.84
    foot=SphereShape3D.new();foot.radius=.07
func excludes() -> Array[RID]:
    var result: Array[RID]=[world.scene.player.get_rid()]
    for actor in world.actors.values():result.append(actor.get_rid())
    return result
func project(point: Vector3) -> Variant:
    var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.65,point-Vector3.UP*.9,1)
    var hit=get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty() or hit.normal.y<.85 or absf(hit.position.y-point.y)>.6:return null
    return hit.position+Vector3.UP*.003
func free_at(point: Vector3) -> bool:
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.942)
    query.exclude=excludes();query.collision_mask=3;query.margin=.0001
    return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func walk_clear(a: Vector3,b: Vector3) -> bool:
    if not free_at(a) or not free_at(b):return false
    if a.distance_to(b)<.00001:return true
    if absf(a.y-b.y)>.085:return false
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,a+Vector3.UP*.942)
    query.motion=b-a;query.exclude=excludes();query.collision_mask=3;query.margin=.0001
    var fraction=get_world_3d().direct_space_state.cast_motion(query)
    return fraction[0]>.9999
func local_clear(actor: CharacterBody3D,point: Vector3) -> bool:
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.942)
    query.exclude=[actor.get_rid()];query.collision_mask=3;query.margin=.0001
    return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func cancel(actor: CharacterBody3D) -> void:
    jobs=jobs.filter(func(job):return job.actor.get_ref()!=actor)
func _coord(point: Vector3) -> Vector2i:
    return Vector2i(roundi(point.x/CELL),roundi(point.z/CELL))
func _sample(job: Dictionary,key: Vector2i) -> Variant:
    if job.cells.has(key):return job.cells[key]
    var point=project(Vector3(key.x*CELL,job.height,key.y*CELL))
    if point!=null and not free_at(point):point=null
    job.cells[key]=point
    return point
func _near(job: Dictionary,point: Vector3) -> Array:
    var result=[];var origin=_coord(point)
    for x in range(-1,2):
        for y in range(-1,2):
            var key=origin+Vector2i(x,y)
            var candidate=_sample(job,key)
            if candidate!=null and walk_clear(point,candidate):result.append({"key":key,"point":candidate,"d":point.distance_squared_to(candidate)})
    result.sort_custom(func(a,b):return a.d<b.d)
    return result
func _push(heap: Array,item: Dictionary) -> void:
    heap.append(item)
    var i=heap.size()-1
    while i>0:
        var p=(i-1)/2
        if heap[p].f<=item.f:break
        heap[i]=heap[p];i=p
    heap[i]=item
func _pop(heap: Array) -> Dictionary:
    var result: Dictionary=heap[0]
    var last=heap.pop_back()
    if heap.is_empty():return result
    var i=0
    while i*2+1<heap.size():
        var child=i*2+1
        if child+1<heap.size() and heap[child+1].f<heap[child].f:child+=1
        if heap[child].f>=last.f:break
        heap[i]=heap[child];i=child
    heap[i]=last
    return result
func _portal_index(job: Dictionary) -> Dictionary:
    var result={};var edges=[]
    for source in world.scene.player.map_traversals.obstacles:
        if not is_instance_valid(source):continue
        if source.has_meta("fence78") and not source.can_cross("zombie"):continue
        if source.kind=="window" and (not source.opening.open or source.opening.get("mechanism","") not in ["awning","casement_pair"]):continue
        var centers=[];var normal: Vector3=source.normal
        if source.kind=="fence":
            var segment: Vector3=source.b-source.a;var length=segment.length()
            normal=segment.normalized().cross(Vector3.UP)
            for distance in range(0,ceili((length-1.4)/1.8)+1):centers.append(source.a+segment.normalized()*minf(length-.7,.7+distance*1.8))
            for point in [job.start,job.goal]:
                centers.append(source.a+segment*clampf((point-source.a).dot(segment)/segment.length_squared(),.7/length,1-.7/length))
        else:centers.append(source.base_center)
        for center in centers:
            if not job.bounds.has_point(_coord(center)):continue
            if world.actors[job.identity].blocked_portals.has(source.get_instance_id()):continue
            for side in [-1,1]:edges.append({"kind":"vault","source":source,"a":center+normal*side*.65,"b":center-normal*side*.95})
    var doors=world.scene.player.map_doors
    for data in doors.doors.values():
        if data.get("kind","")=="window" or not data.open:continue
        var pose: Transform3D=data.hinge.get_parent().global_transform*doors._pose(data,0)*data.body.transform*data.collider.transform
        var normal=(pose.basis.x if data.collider.shape.size.x<data.collider.shape.size.z else pose.basis.z).normalized()
        var center: Vector3=pose.origin;center.y=job.height
        if not job.bounds.has_point(_coord(center)):continue
        for side in [-1,1]:edges.append({"kind":"door","a":center+normal*side*.65,"b":center-normal*side*.65})
    for edge in edges:
        var index=job.portals.size();job.portals.append(edge)
        var origin=_coord(edge.a)
        for x in range(-1,2):
            for y in range(-1,2):
                var key=origin+Vector2i(x,y)
                if not result.has(key):result[key]=[]
                result[key].append(index)
    return result
func request(actor: CharacterBody3D,goal: Vector3,ticket: int) -> void:
    cancel(actor);serial+=1
    var a=_coord(actor.global_position);var b=_coord(goal)
    var lower=Vector2i(mini(a.x,b.x)-14,mini(a.y,b.y)-14)
    var upper=Vector2i(maxi(a.x,b.x)+15,maxi(a.y,b.y)+15)
    var job={"actor":weakref(actor),"identity":actor.identity,"ticket":ticket,"start":actor.global_position,"goal":goal,"height":actor.global_position.y,"bounds":Rect2i(lower,upper-lower),"cells":{},"open":[],"g":{},"closed":{},"came":{},"portals":[],"portal_results":{},"expanded":0,"phase":"init","started":Time.get_ticks_msec()}
    job.index=_portal_index(job)
    jobs.append(job)
func _probe_portal(job: Dictionary,index: int) -> Dictionary:
    if job.portal_results.has(index):return job.portal_results[index]
    var edge: Dictionary=job.portals[index];var result={}
    var actor=job.actor.get_ref()
    if not is_instance_valid(actor):return {}
    if edge.kind=="door":
        var a=project(edge.a);var b=project(edge.b)
        if a!=null and b!=null and free_at(a) and free_at(b) and walk_clear(a,b):result={"a":a,"b":b,"steps":[{"kind":"walk","point":a},{"kind":"walk","point":b}],"cost":a.distance_to(b)}
    elif is_instance_valid(edge.source):
        var marker=Node3D.new();add_child(marker);marker.global_position=edge.a
        var proxy=load("res://personagem/obstaculo_nav84.gd").new();add_child(proxy);proxy.bind(edge.source,actor)
        if proxy.prepare(marker):
            var path=load("res://personagem/percurso_cercas78.gd" if edge.source.has_meta("fence78") else "res://personagem/percurso_mapa77.gd").new()
            path.setup(actor.crossing.definitions);var id="vault_window" if proxy.kind=="window" else "vault_fence"
            path.configure(id,proxy.rise,proxy.landing)
            var side=1 if proxy.to_local(marker.global_position).z<0 else -1
            var basis=Basis(Vector3.UP,proxy.global_rotation.y+(PI if side<0 else 0));var anchor=proxy.global_position+Vector3.UP*.003
            var length=float(actor.crossing.definitions.actions[id].duration)
            var a=Vector3.ZERO;var b=Vector3.ZERO;var clear=true
            var query=PhysicsShapeQueryParameters3D.new();query.exclude=excludes();query.collision_mask=3
            var compact=CapsuleShape3D.new();compact.radius=.23
            for frame in 61:
                var sample: Dictionary=path.sample(id,length*frame/60)
                var point=anchor+basis*Vector3(sample.x,sample.lift,sample.z)
                if frame==0:a=point
                if frame==60:b=point
                compact.height=sample.height;query.shape=compact;query.transform=Transform3D(Basis.IDENTITY,point+basis*sample.centre+Vector3.UP*.022)
                if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():clear=false;break
                query.shape=foot
                for leg in ["R","L"]:
                    query.transform=Transform3D(Basis.IDENTITY,anchor+basis*sample[leg]+Vector3.UP*.003)
                    if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():clear=false;break
                if not clear:break
            if clear:result={"a":a,"b":b,"steps":[{"kind":"walk","point":a},{"kind":"portal","source":edge.source,"point":a,"exit":b},{"kind":"walk","point":b}],"cost":3.2}
        proxy.free();marker.free()
    job.portal_results[index]=result
    return result
func _relax(job: Dictionary,current: Vector2i,key: Vector2i,point: Vector3,cost: float,steps: Array) -> void:
    var g=float(job.g[current])+cost
    if g>=float(job.g.get(key,INF)):return
    job.g[key]=g;job.came[key]={"key":current,"steps":steps}
    _push(job.open,{"key":key,"g":g,"f":g+point.distance_to(job.goal)})
func _finish(job: Dictionary,key: Variant,reason: String) -> void:
    var route=[]
    if key!=null:
        var segments=[];var cursor: Vector2i=key
        while job.came.has(cursor):segments.push_front(job.came[cursor].steps);cursor=job.came[cursor].key
        route.append({"kind":"walk","point":_sample(job,cursor)})
        for segment in segments:route.append_array(segment)
        route.append({"kind":"walk","point":job.goal})
    var stats={"expanded":job.expanded,"reason":reason,"milliseconds":Time.get_ticks_msec()-job.started,"steps":route.size()}
    completed.append(stats)
    if completed.size()>50:completed.pop_front()
    var actor=job.actor.get_ref()
    if is_instance_valid(actor):actor.path_ready(job.ticket,route,stats)
    jobs.erase(job)
func _advance(job: Dictionary) -> void:
    if job.phase=="init":
        var start=_near(job,job.start);var goal=_near(job,job.goal)
        if start.is_empty() or goal.is_empty():_finish(job,null,"endpoint_blocked");return
        job.goal_keys={}
        for item in goal:job.goal_keys[item.key]=true
        for item in start:
            var g=job.start.distance_to(item.point);job.g[item.key]=g
            _push(job.open,{"key":item.key,"g":g,"f":g+item.point.distance_to(job.goal)})
        job.phase="search";return
    if job.open.is_empty():_finish(job,null,"no_route");return
    var item=_pop(job.open);var key: Vector2i=item.key
    if job.closed.has(key) or item.g>job.g[key]+.00001:return
    job.closed[key]=true;job.expanded+=1
    var point: Vector3=_sample(job,key)
    if job.goal_keys.has(key):_finish(job,key,"found");return
    if job.expanded>=MAX_NODES:_finish(job,null,"node_limit");return
    for offset in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
        var next=key+offset
        if not job.bounds.has_point(next) or job.closed.has(next):continue
        var target=_sample(job,next)
        if target==null or not walk_clear(point,target):continue
        _relax(job,key,next,target,point.distance_to(target),[{"kind":"walk","point":target}])
    for index in job.index.get(key,[]):
        var edge=_probe_portal(job,index)
        if edge.is_empty() or not walk_clear(point,edge.a):continue
        for item_b in _near(job,edge.b):
            if not job.bounds.has_point(item_b.key):continue
            var steps=edge.steps.duplicate();steps.append({"kind":"walk","point":item_b.point})
            _relax(job,key,item_b.key,item_b.point,point.distance_to(edge.a)+edge.cost+edge.b.distance_to(item_b.point),steps)
func _physics_process(_delta: float) -> void:
    if world==null or world.scene.player.paused or jobs.is_empty():return
    var started=Time.get_ticks_usec();var count=0
    while not jobs.is_empty() and count<32 and Time.get_ticks_usec()-started<2000:
        var job: Dictionary=jobs[0]
        if not is_instance_valid(job.actor.get_ref()):jobs.pop_front();continue
        _advance(job);count+=1
        if jobs.has(job):jobs.erase(job);jobs.append(job)
    max_slice_us=maxi(max_slice_us,Time.get_ticks_usec()-started)
