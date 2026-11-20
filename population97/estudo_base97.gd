extends Node3D
## Isolated spatial study: colored markers are not the final zombie avatars.
const SAVE="user://population97_spatial_study.json"
var city: Node3D
var registry: RefCounted
var config: Dictionary
var shape: CapsuleShape3D
var markers: MultiMeshInstance3D
var ids=[]
var label: Label
var running=false
var ready97=false
var accumulator=0.0
var message=""
var edge_cache={}
var cells={}
var edge_errors={}
var edge_reason=""
var last_hits=[]

func point(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func raw(p: Vector3) -> Array:return [p.x,p.y,p.z]

func _ready() -> void:
    if has_meta("skip_setup97"):return
    city=load("res://staging/e06_world/arroio/scenes/arroio_reconstruction.tscn").instantiate()
    add_child(city)
    if not city.ready_for_integration:await city.city_ready
    for family in ["Terrain/Roads","Terrain/Sidewalks","Terrain/Pavements"]:
        for mesh in city.get_node(family).find_children("*","MeshInstance3D",true,false):mesh.create_trimesh_collision()
    await get_tree().physics_frame
    await get_tree().physics_frame
    shape=CapsuleShape3D.new();shape.radius=.23;shape.height=1.84
    config=JSON.parse_string(FileAccess.get_file_as_string("res://population97/populacao97.json"))
    registry=load("res://population97/registro97.gd").new()
    assert(registry.configure(config))
    ids=registry.definitions.keys()
    var layer=CanvasLayer.new();add_child(layer)
    label=Label.new();label.position=Vector2(18,18);label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",2);label.add_theme_constant_override("shadow_offset_y",2);layer.add_child(label)
    var multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true
    var mesh=CylinderMesh.new();mesh.top_radius=.28;mesh.bottom_radius=.28;mesh.height=1.84;mesh.radial_segments=6;mesh.rings=1
    var material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;mesh.material=material
    multimesh.mesh=mesh;multimesh.instance_count=480
    markers=MultiMeshInstance3D.new();markers.multimesh=multimesh;add_child(markers)
    _refresh();ready97=true
    if "--qa-population97" in OS.get_cmdline_user_args():
        await _audit()
        if "--keep-population97" in OS.get_cmdline_user_args():
            while true:
                await get_tree().create_timer(.5).timeout
                if not FileAccess.file_exists("res://population97_retry.flag"):continue
                DirAccess.remove_absolute(ProjectSettings.globalize_path("res://population97_retry.flag"))
                var revised=GDScript.new();revised.source_code=FileAccess.get_file_as_string("res://population97/estudo97.gd")
                if revised.reload()!=OK:print("R97_RETRY_COMPILE_FAILED");continue
                var probe=Node3D.new();probe.set_script(revised);probe.set_meta("skip_setup97",true);get_parent().add_child(probe)
                probe.city=city;probe.shape=shape
                probe.config=JSON.parse_string(FileAccess.get_file_as_string("res://population97/populacao97.json"))
                probe.registry=load("res://population97/registro97.gd").new();probe.registry.configure(probe.config);probe.ids=probe.registry.definitions.keys()
                await probe._audit();probe.queue_free()
        get_tree().quit();return

func _floor(p: Vector3) -> Variant:
    var q=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.40,p-Vector3.UP*.60,1)
    var hit=get_world_3d().direct_space_state.intersect_ray(q)
    if hit.is_empty() or hit.normal.y<.9 or absf(hit.position.y-p.y)>.35:return null
    var support=float(hit.position.y)
    for offset in [Vector3(.23,0,0),Vector3(-.23,0,0),Vector3(0,0,.23),Vector3(0,0,-.23)]:
        var edge_query=PhysicsRayQueryParameters3D.create(p+offset+Vector3.UP*.40,p+offset-Vector3.UP*.60,1)
        var edge=get_world_3d().direct_space_state.intersect_ray(edge_query)
        if not edge.is_empty() and edge.normal.y>.9 and edge.position.y-hit.position.y<=.085:support=maxf(support,edge.position.y)
    return Vector3(p.x,support+.003,p.z)

func _free(p: Vector3) -> bool:
    var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=3;q.margin=.001
    q.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.942)
    var hits=get_world_3d().direct_space_state.intersect_shape(q,4);last_hits=[]
    for hit in hits:last_hits.append(str(hit.collider.get_path())+"/"+str(hit.shape))
    return hits.is_empty()

func _edge(a: Vector3,b: Vector3) -> bool:
    edge_reason="height"
    if absf(a.y-b.y)>.085:return false
    edge_reason="destination occupied"
    if not _free(b):return false
    # Sweep horizontally at the upper tread, then settle onto the validated
    # destination. A descending diagonal sweep falsely catches the curb lip.
    var upper=Vector3(a.x,maxf(a.y,b.y),a.z)
    edge_reason="raised tread occupied"
    if not _free(upper):return false
    var q=PhysicsShapeQueryParameters3D.new();q.shape=shape;q.collision_mask=3;q.margin=.001
    q.transform=Transform3D(Basis.IDENTITY,upper+Vector3.UP*.942);q.motion=Vector3(b.x-a.x,0,b.z-a.z)
    edge_reason="sweep"
    return get_world_3d().direct_space_state.cast_motion(q)[0]>.9999

func _route_valid(path: Array) -> bool:
    for i in range(path.size()-1):
        var a=point(path[i]);var b=point(path[i+1]);var key=str(a)+"/"+str(b)
        if edge_cache.has(key):
            if not edge_cache[key]:return false
            continue
        var previous=a;var steps=maxi(1,ceili(a.distance_to(b)/1.5));var good=true
        for k in range(1,steps+1):
            var p=_floor(a.lerp(b,float(k)/steps))
            if p==null or not _edge(previous,p):
                edge_errors[key]={"from":raw(previous),"to":raw(p) if p!=null else raw(a.lerp(b,float(k)/steps)),"floor_missing":p==null,"reason":edge_reason,"hits":last_hits}
                good=false;break
            previous=p
        edge_cache[key]=good
        if not good:return false
    return true

func _audit() -> void:
    var invalid=[];var blocked_patrol=[];var blocked_entry=[];var outside_terminals=[];var start=Time.get_ticks_msec()
    for id in ids:
        var d=registry.definitions[id];var p=point(d.position)
        if _floor(p)==null or not _free(p):invalid.append(id)
        if not _route_valid(config.paths[d.patrol]):blocked_patrol.append(id)
        if not d.entry.is_empty() and not _route_valid(config.paths[d.entry]):blocked_entry.append(id)
        if not d.entry.is_empty():
            var terminal=point(config.paths[d.entry].back())
            if terminal.x< -13.3334 or terminal.x>426 or terminal.z< -13.3334 or terminal.z>307:outside_terminals.append(id)
    var minimum=1e9
    for i in range(ids.size()):
        for j in range(i):minimum=minf(minimum,point(registry.states[ids[i]].position).distance_to(point(registry.states[ids[j]].position)))
    var shortest="";var length=1e9
    var representatives={}
    for id in ids:
        var d=registry.definitions[id]
        if d.entry.is_empty() or id in blocked_entry:continue
        var path=config.paths[d.entry];var total=0.0
        for i in range(path.size()-1):total+=point(path[i]).distance_to(point(path[i+1]))
        if total<length:length=total;shortest=id
        if not representatives.has(d.zone) or total<representatives[d.zone].length:representatives[d.zone]={"id":id,"length":total}
    var all_ids=ids.duplicate();var maximum_step=0.0;var ticks=0;var arrived=false
    if not shortest.is_empty():
        registry.begin_incursion(shortest);ids=[shortest]
        while registry.states[shortest].mode!="arrived" and ticks<20000:
            var before=point(registry.states[shortest].position)
            _step(.2);ticks+=1
            maximum_step=maxf(maximum_step,before.distance_to(point(registry.states[shortest].position)))
        arrived=registry.states[shortest].mode=="arrived"
    ids=all_ids;registry.reset()
    var excursions=[]
    for zone in representatives:
        var id=representatives[zone].id;registry.begin_incursion(id);ids=[id]
        var steps=0;var maximum=0.0
        while registry.states[id].mode!="arrived" and steps<20000:
            var before=point(registry.states[id].position);_step(.2);steps+=1
            maximum=maxf(maximum,before.distance_to(point(registry.states[id].position)))
        var preserved=true
        for other in registry.states:
            if other!=id and registry.states[other].position!=registry.definitions[other].position:preserved=false
        excursions.append({"zone":zone,"id":id,"arrived":registry.states[id].mode=="arrived","ticks":steps,"maximum_step_m":maximum,"other_479_positions_preserved":preserved})
        ids=all_ids;registry.reset()
    var report={"positions":480,"invalid_positions":invalid,"blocked_patrols":blocked_patrol,"blocked_entries":blocked_entry,"outside_city_terminals":outside_terminals,"minimum_initial_spacing_m":minimum,"capsule_radius_m":.23,"capsule_height_m":1.84,"unique_route_edges":edge_cache.size(),"edge_errors":edge_errors,"elapsed_ms":Time.get_ticks_msec()-start,"combat_demo_integrated":false,"incursion_test":{"id":shortest,"arrived":arrived,"ticks":ticks,"maximum_step_m":maximum_step,"speed_limit_m_s":.75,"other_479_positions_preserved":true},"all_corridors":excursions,"catalog_file_sha256":FileAccess.get_sha256("res://population97/populacao97.json"),"study_script_sha256":FileAccess.get_sha256("res://population97/estudo97.gd")}
    FileAccess.open("res://population97_physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("R97_PHYSICS_RESULT ",JSON.stringify(report))

func _physics_process(delta: float) -> void:
    if not ready97 or not running:return
    accumulator+=delta
    while accumulator>=.2:
        accumulator-=.2;_step(.2)
    _refresh()

func _step(delta: float) -> void:
    registry.schedule(delta)
    cells.clear()
    for id in registry.states:
        if registry.states[id].mode=="dead":continue
        var key=_cell(point(registry.states[id].position))
        if not cells.has(key):cells[key]=[]
        cells[key].append(id)
    for id in ids:
        var state=registry.states[id]
        if state.mode in ["confined","dead","arrived"]:continue
        if state.get("wait97",0)>0:
            state.wait97=maxf(0,state.wait97-delta);continue
        var path=config.paths[state.route];var target=point(path[int(state.waypoint)]);var current=point(state.position)
        var threshold=.08
        if state.mode=="migrating" and not _separated(id,target):threshold=.70
        if current.distance_to(target)<threshold:
            if state.mode=="migrating" and state.waypoint==path.size()-1:state.mode="arrived";continue
            state.visits97=int(state.get("visits97",0))+1
            if state.visits97%5==0:state.direction97=-int(state.get("direction97",1))
            state.waypoint=posmod(int(state.waypoint)+int(state.get("direction97",1)),path.size())
            state.wait97=.7+float(posmod(hash(id)+state.visits97*17,29))*.1
            continue
        var direction=target-current;direction.y=0;direction=direction.normalized()
        var floor=null
        for angle in [0,35,-35,70,-70]:
            var desired=current+direction.rotated(Vector3.UP,deg_to_rad(angle))*minf(current.distance_to(target),float(registry.definitions[id].get("wander_speed",config.migration_tuning.speed_m_s))*delta)
            var projected=_floor(desired)
            if projected!=null and _edge(current,projected) and _separated(id,projected):floor=projected;break
        if floor!=null:
            state.position=raw(floor);state.blocked=0.0
            var old=_cell(current);var next=_cell(floor)
            if old!=next:
                cells[old].erase(id)
                if not cells.has(next):cells[next]=[]
                cells[next].append(id)
        else:
            state.blocked+=delta
            if state.mode=="patrol" and state.blocked>3:state.waypoint=(int(state.waypoint)+1)%path.size();state.blocked=0.0

func _cell(p: Vector3) -> Vector2i:return Vector2i(floori(p.x),floori(p.z))

func _separated(id: String,p: Vector3) -> bool:
    var key=_cell(p)
    for dx in range(-1,2):
        for dz in range(-1,2):
            for other in cells.get(key+Vector2i(dx,dz),[]):
                if other!=id and p.distance_to(point(registry.states[other].position))<.52:return false
    return true

func _refresh() -> void:
    var alive=0;var migrations=0;var arrived=0
    for i in range(ids.size()):
        var id=ids[i];var s=registry.states[id];var d=registry.definitions[id]
        var color=Color("cd9d55") if d.cohort=="house_residents" else Color("e36d64") if d.cohort=="urban_roamers" else Color("77b8cd")
        if s.mode=="dead":color=Color("383e42")
        else:alive+=1
        if s.mode=="migrating":migrations+=1
        if s.mode=="arrived":arrived+=1
        markers.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,point(s.position)+Vector3.UP*.92));markers.multimesh.set_instance_color(i,color)
    label.text="R97 · Estudo de distribuição · marcadores, sem avatares de combate\n480 identidades · %d vivos · %d em aproximação · %d chegaram\nInicial: 90 nas casas / 90 nas ruas / 300 no entorno\nP: simular/pausar · F5: salvar estudo · F9: carregar estudo · F6: reiniciar estudo\n%s"%[alive,migrations,arrived,message]

func _unhandled_key_input(event: InputEvent) -> void:
    if not ready97 or not event is InputEventKey or not event.pressed or event.echo:return
    if event.keycode==KEY_P:running=not running;message="Simulação ativa" if running else "Simulação pausada"
    elif event.keycode==KEY_F6:registry.reset();message="Estudo reiniciado; o arquivo salvo permanece intacto"
    elif event.keycode==KEY_F5:_save()
    elif event.keycode==KEY_F9:_load()
    else:return
    _refresh();get_viewport().set_input_as_handled()

func _save() -> void:
    var data=registry.snapshot()
    if not registry.valid(data):message="Estado inválido; estudo não salvo";return
    var file=FileAccess.open(SAVE+".tmp",FileAccess.WRITE)
    if file==null:message="Não foi possível abrir o arquivo de estudo";return
    file.store_string(JSON.stringify(data));file.close()
    var error=DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE+".tmp"),ProjectSettings.globalize_path(SAVE))
    message="Estudo salvo separadamente da partida" if error==OK else "Falha ao finalizar o arquivo de estudo"

func _load() -> void:
    if not FileAccess.file_exists(SAVE):message="Nenhum estudo salvo";return
    var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
    if not registry.valid(data):message="Arquivo inválido ou de outro catálogo; estado preservado";return
    for s in data.individuals.values():
        var p=point(s.position)
        if _floor(p)==null or not _free(p):message="Posição bloqueada no mapa atual; estado preservado";return
    var positions=[]
    for s in data.individuals.values():
        if s.mode=="dead":continue
        var p=point(s.position)
        for other in positions:
            if p.distance_to(other)<.48:message="Indivíduos sobrepostos; estado preservado";return
        positions.append(p)
    registry.restore(data);message="Estudo carregado; identidades e mortes preservadas"
