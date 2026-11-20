extends RefCounted
## Campaign-owned survey, independent from menu visibility. Old saves migrate empty.
const CELL=8.0
var data={"version":1,"cells":[],"visited":[],"marked":[]}
var places={}
var position=Vector2.ZERO
var roads=[]
var trees=[]
var water=[]
func setup(scene: Node) -> void:
    # Use actual final instantiated building origins, after all placement overrides.
    for node in scene.find_children("*","Node3D",true,false):
        if node.has_method("catalog") and "apply_current_h01_h20_revisions" in node:
            roads=node.catalog("roads")
            var landscape=node.catalog("landscape")
            for tree in landscape.get("trees",[]):
                if tree.get("enabled",true):trees.append(Vector2(tree.position[0],tree.position[2] if tree.position.size()>2 else tree.position[1]))
            for zone in landscape.get("ground_zones",[]):
                if zone.has("points"):roads.append({"geometry":{"coordinates":zone.points},"properties":{"class":"trail","road_width_m_proposed":zone.get("width_m",1.5)}})
        if node.get_script()!=null and "building_id" in node and str(node.building_id)!="":
            var id=str(node.building_id)
            var bounds=AABB(node.global_position,Vector3.ZERO)
            for mesh in node.find_children("*","MeshInstance3D",true,false):
                if mesh.mesh!=null:bounds=bounds.merge(mesh.global_transform*mesh.mesh.get_aabb())
            places[id]={"id":id,"name":"Construção "+id,"point":Vector2(node.global_position.x,node.global_position.z),"bounds":Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))}
    if scene.find_child("WesternLakeWater",true,false)!=null:
        var lake=JSON.parse_string(FileAccess.get_file_as_string("res://staging/e06_world/arroio/data/lake_west.json"))
        water=lake.shoreline
    if scene.find_child("RegionalRoads",true,false)!=null:
        var regional=JSON.parse_string(FileAccess.get_file_as_string("res://staging/e06_world/arroio/data/regional_roads.json"))
        for link in regional.links.values():roads.append({"geometry":{"coordinates":link.points},"properties":{"road_width_m_proposed":link.width}})
func cell(point: Vector2) -> String:return "%d,%d"%[floori(point.x/CELL),floori(point.y/CELL)]
func update(point: Vector2) -> void:
    position=point
    for x in range(-2,3):
        for y in range(-2,3):
            var sample=point+Vector2(x,y)*CELL
            if sample.distance_to(point)>17:continue
            var key=cell(sample)
            if key not in data.cells:data.cells.append(key)
    for id in places:
        if places[id].point.distance_to(point)<7 and id not in data.visited:data.visited.append(id)
func known() -> Array:
    var rows=[]
    for id in places:
        var item=places[id]
        if cell(item.point) not in data.cells:continue
        var row=item.duplicate();row.visited=id in data.visited;row.marked=id in data.marked;rows.append(row)
    return rows
func mark(id: String) -> bool:
    if not known().any(func(row):return row.id==id):return false
    if id in data.marked:data.marked.erase(id)
    else:data.marked.append(id)
    return true
func snapshot() -> Dictionary:return data.duplicate(true)
func validate(value: Variant) -> Dictionary:
    if value==null:return {"version":1,"cells":[],"visited":[],"marked":[]}
    if not value is Dictionary or value.get("version")!=1:return {}
    for key in ["cells","visited","marked"]:
        if not value.get(key) is Array or value[key].size()>100000:return {}
        var seen=[]
        for id in value[key]:
            if not id is String or id in seen:return {}
            seen.append(id)
            if key=="cells":
                var pair=id.split(",")
                if pair.size()!=2 or not pair[0].is_valid_int() or not pair[1].is_valid_int() or abs(int(pair[0]))>10000 or abs(int(pair[1]))>10000:return {}
            elif not places.has(id) or cell(places[id].point) not in value.cells:return {}
    var result=value.duplicate(true);result.version=1;return result
