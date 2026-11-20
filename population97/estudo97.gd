extends "res://population97/estudo_base97.gd"
var woods=[]
var woods_grid={}
var road_segments=[]
var waters=[]
var homes=[]
var occupied=[]
var rng=RandomNumberGenerator.new()
var placement_errors=[]

func _cell_woods(p: Vector2) -> Vector2i:return Vector2i(floori(p.x/32),floori(p.y/32))

func _environment() -> void:
    woods.clear();woods_grid.clear();road_segments.clear();waters.clear();homes.clear()
    for trunk in city.find_children("Trunk_*","StaticBody3D",true,false):
        var p=Vector2(trunk.global_position.x,trunk.global_position.z);var key=_cell_woods(p)
        woods.append(p)
        if not woods_grid.has(key):woods_grid[key]=[]
        woods_grid[key].append(p)
    for road in city.catalog("roads"):_add_road(road.geometry.coordinates)
    for road in city.catalog("regional_roads").links.values():_add_road(road.points)
    for road in city.catalog("rural_network").roads.values():_add_road(road)
    var west=city.catalog("lake_west");var poly=PackedVector2Array()
    for p in west.shoreline:poly.append(Vector2(p[0],p[1]))
    waters.append(poly)
    var lake=city.catalog("lrp01");poly=PackedVector2Array()
    for p in lake.shoreline:poly.append(Vector2(p[0]+lake.origin[0],p[1]+lake.origin[2]))
    waters.append(poly)
    for home in city.get_node("ResidentialInteriors").homes.values():
        var lo=point(home.rule.interior_bounds[0]);var hi=point(home.rule.interior_bounds[1])
        homes.append({"inverse":home.model.global_transform.affine_inverse(),"bounds":AABB(lo,hi-lo).grow(2.0)})
    var exported=[]
    for tree in woods:exported.append([snappedf(tree.x,.1),snappedf(tree.y,.1)])
    var water_export=[]
    for water in waters:
        var outline=[]
        for p in water:outline.append([p.x,p.y])
        water_export.append(outline)
    FileAccess.open("res://population97_habitats.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_tree_trunks":exported,"water_polygons":water_export}))

func _add_road(poly: Array) -> void:
    for i in range(poly.size()-1):road_segments.append([Vector2(poly[i][0],poly[i][1]),Vector2(poly[i+1][0],poly[i+1][1])])

func _city_distance(p: Vector2) -> float:
    return p.distance_to(Vector2(clampf(p.x,-13.333,426),clampf(p.y,-13.333,307)))

func _road_distance(p: Vector2) -> float:
    var result=1e9
    for edge in road_segments:result=minf(result,p.distance_to(Geometry2D.get_closest_point_to_segment(p,edge[0],edge[1])))
    return result

func _tree_context(p: Vector2) -> Dictionary:
    var key=_cell_woods(p);var count=0;var nearest=1e9
    for dx in range(-1,2):
        for dz in range(-1,2):
            for tree in woods_grid.get(key+Vector2i(dx,dz),[]):
                var distance=p.distance_to(tree);nearest=minf(nearest,distance)
                if distance<32:count+=1
    return {"count":count,"nearest":nearest}

func _habitat(p: Vector3,near_city: bool) -> bool:
    var flat=Vector2(p.x,p.z)
    if p.x< -1450 or p.x>1625 or p.z< -545 or p.z>955:return false
    var distance=_city_distance(flat)
    if near_city and distance>45:return false
    if not near_city and distance<90:return false
    for water in waters:
        if Geometry2D.is_point_in_polygon(flat,water):return false
    for home in homes:
        if home.bounds.has_point(home.inverse*p):return false
    if _road_distance(flat)<(6.0 if near_city else 12.0):return false
    var trees=_tree_context(flat)
    return trees.nearest<18 and trees.count>=2

func _land(p: Vector3,near_city: bool) -> Variant:
    if not _habitat(p,near_city):return null
    var floor=_floor(p)
    if floor==null or not _free(floor):return null
    var q=PhysicsRayQueryParameters3D.create(floor+Vector3.UP*.2,floor-Vector3.UP*.25,1)
    var hit=get_world_3d().direct_space_state.intersect_ray(q)
    if hit.is_empty():return null
    var title=str(hit.collider.get_path()).to_lower()
    if "pavements" in title or "sidewalks" in title or "/roads/" in title:return null
    return floor

func _habitat_route(path: Array,near_city: bool) -> bool:
    if not _route_valid(path):return false
    for i in range(path.size()-1):
        var a=point(path[i]);var b=point(path[i+1]);var count=maxi(1,ceili(a.distance_to(b)/2))
        for k in range(count+1):
            if not _habitat(a.lerp(b,float(k)/count),near_city):return false
    return true

func _pool(definition: Dictionary) -> Array:
    var result=[];var near=definition.cohort=="urban_roamers"
    for tree in woods:
        if near:
            if _city_distance(tree)<=35:result.append(tree)
        elif _city_distance(tree)>105:
            if definition.zone=="RG_E" and tree.x>500:result.append(tree)
            elif definition.zone=="RG_NW" and tree.y< -100:result.append(tree)
            elif definition.zone=="RG_SW" and tree.y>405:result.append(tree)
    return result

func _generate() -> bool:
    rng.seed=970819;occupied.clear();var paths={};var pools={}
    for d in config.actors:
        if d.cohort=="house_residents":
            paths[d.patrol]=config.paths[d.patrol];occupied.append(point(d.position));continue
        var pool_key=d.cohort+"/"+d.zone if d.cohort=="distant_roamers" else "near"
        if not pools.has(pool_key):pools[pool_key]=_pool(d)
        var pool: Array=pools[pool_key];var placed=false;var near=d.cohort=="urban_roamers"
        if pool.is_empty():placement_errors.append(d.id+": no woodland pool");continue
        for attempt in range(2200):
            var tree=pool[rng.randi_range(0,pool.size()-1)];var angle=rng.randf_range(0,TAU)
            var anchor=Vector3(tree.x+cos(angle)*rng.randf_range(3,10),0,tree.y+sin(angle)*rng.randf_range(3,10))
            var start=_land(anchor,near)
            if start==null:continue
            var separated=true
            for other in occupied:
                if start.distance_to(other)<6:separated=false;break
            if not separated:continue
            var path=[raw(start)];var good=true
            for corner in range(1,5):
                var theta=angle+corner*TAU/5;var radius=rng.randf_range(3,6)
                var p=_land(start+Vector3(cos(theta)*radius,0,sin(theta)*radius),near)
                if p==null:good=false;break
                path.append(raw(p))
            if not good:continue
            path.append(raw(start))
            if not _habitat_route(path,near):continue
            paths[d.patrol]=path;d.entry="";d.position=raw(start);d.habitat="woodland_fringe" if near else "distant_woodland"
            d.tree_distance_m=_tree_context(Vector2(start.x,start.z)).nearest
            d.road_distance_m=_road_distance(Vector2(start.x,start.z));d.wander_speed=rng.randf_range(.52,.78)
            occupied.append(start);placed=true;break
        if not placed:placement_errors.append(d.id+": exhausted woodland candidates")
    if not placement_errors.is_empty():return false
    config.paths=paths;config.revision=97;config.habitat_revision=97
    config.behavior={"ambient":"wander_pause_reverse","scheduled_city_incursions":false,"prey_entities_implemented":false,"perception_integration_pending":true}
    config.status="isolated_woodland_study_not_combat_demo"
    FileAccess.open("res://population97/populacao97.json",FileAccess.WRITE).store_string(JSON.stringify(config,"  "))
    return registry.configure(config)

func _audit() -> void:
    _environment()
    if config.get("habitat_revision")!=97 and not _generate():
        print("R97_FOREST_GENERATION_FAILED ",placement_errors);get_tree().quit(1);return
    ids=registry.definitions.keys()
    var invalid=[];var bad_routes=[];var road_min=1e9;var exterior=0;var trees_max=0.0
    edge_cache.clear();edge_errors.clear()
    for d in config.actors:
        var p=point(d.position)
        if _floor(p)==null or not _free(p):invalid.append(d.id)
        if not _route_valid(config.paths[d.patrol]):bad_routes.append(d.id)
        if d.cohort=="house_residents":continue
        exterior+=1
        if not _habitat(p,d.cohort=="urban_roamers"):invalid.append(d.id+" habitat")
        road_min=minf(road_min,_road_distance(Vector2(p.x,p.z)));trees_max=maxf(trees_max,_tree_context(Vector2(p.x,p.z)).nearest)
    var before=registry.snapshot();var moved={};var rests={};var maximum=0.0
    for frame in range(80):
        var previous={}
        for id in ids:previous[id]=point(registry.states[id].position)
        _step(.2)
        for id in ids:
            var delta=point(registry.states[id].position).distance_to(previous[id]);maximum=maxf(maximum,delta)
            if delta>.01:moved[id]=true
            if registry.definitions[id].cohort!="house_residents" and registry.states[id].get("wait97",0)>0:rests[id]=true
    var checkpoint=registry.snapshot();var resume=registry.get_script().new();resume.configure(config)
    var restored=resume.restore(JSON.parse_string(JSON.stringify(checkpoint)))
    registry.restore(before);_refresh()
    var report={"revision":97,"identities":480,"indoor":90,"woodland_fringe":90,"distant_woodland":300,"actual_tree_colliders":woods.size(),"exterior_in_habitats":exterior,"invalid_positions":invalid,"blocked_local_routes":bad_routes,"minimum_road_center_distance_m":road_min,"maximum_nearest_tree_distance_m":trees_max,"simulation_seconds":16,"individuals_moving":moved.size(),"individuals_pausing":rests.size(),"maximum_step_m":maximum,"roundtrip_wander_state":restored,"forced_city_schedule":false,"animals_or_hunting_implemented":false,"combat_demo_integrated":false}
    FileAccess.open("res://population97_physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("R97_FOREST_RESULT ",JSON.stringify(report))
    if not invalid.is_empty() or not bad_routes.is_empty() or moved.size()<380 or not restored:get_tree().quit(1)

func _refresh() -> void:
    super._refresh()
    if label!=null:label.text=label.text.replace("90 nas ruas / 300 no entorno","90 nas bordas vegetadas / 300 nas matas afastadas")
