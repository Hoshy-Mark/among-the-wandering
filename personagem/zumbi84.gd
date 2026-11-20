extends "res://personagem/zumbi83.gd"
var route=[]
var path_pending=false
var path_ticket=0
var planned_goal=Vector3.ZERO
var replan_delay=0.0
var route_age=0.0
var search_remaining=0.0
var blocked_portals={}
var navigation_stats={}
var visible_now=false
var route_failures=0
var portal_wait=0.0
func navigator() -> Node3D:
    return scene.zombie_world.navigation
func clear_route() -> void:
    path_ticket+=1;path_pending=false;route.clear();route_age=0
    if scene!=null and scene.zombie_world!=null and scene.zombie_world.navigation!=null:navigator().cancel(self)
func ensure_route(goal: Vector3) -> void:
    if (path_pending or not route.is_empty()) and planned_goal.distance_to(goal)>.8:clear_route()
    if route_age>2.5 and not path_pending and not route.is_empty() and route[0].kind!="portal":clear_route()
    if path_pending or not route.is_empty() or replan_delay>0:return
    path_ticket+=1;path_pending=true;planned_goal=goal;route_age=0
    navigator().request(self,goal,path_ticket)
func path_ready(ticket: int,result: Array,stats: Dictionary) -> void:
    if ticket!=path_ticket or state in ["dead","dying"]:return
    route=result;path_pending=false;navigation_stats=stats;route_age=0
    if result.is_empty():replan_delay=.8;route_failures+=1
func should_pursue() -> bool:
    return memory>0 and (_distance(last_known)>.95 or not clear_line(last_known,scene.player))
func try_cross(goal: Vector3) -> bool:
    if visible_now and _distance(scene.player.global_position)<1.25 and clear_line(scene.player.global_position,scene.player):return false
    ensure_route(goal)
    _consume_walks()
    if route.is_empty() or route[0].kind!="portal":return false
    var edge: Dictionary=route[0]
    if not is_instance_valid(edge.source):clear_route();return false
    if global_position.distance_to(edge.point)>.2:return false
    if edge.source.owner_ref!=null and is_instance_valid(edge.source.owner_ref.get_ref()):return false
    if request_cross(edge.source):
        navigator().cancel(self);path_pending=false;portal_wait=0
        return true
    portal_wait+=.4
    if portal_wait>1.2:
        blocked_portals[edge.source.get_instance_id()]=3.0;clear_route();replan_delay=.2;portal_wait=0
    return false
func _consume_walks() -> void:
    while not route.is_empty() and route[0].kind=="walk" and global_position.distance_to(route[0].point)<.18:
        var distance=global_position.distance_to(route[0].point)
        if route.size()>1:
            if route[1].kind=="portal" and distance>.1:break
            if route[1].kind=="walk" and distance>.035 and not navigator().walk_clear(global_position,route[1].point):break
        route.pop_front()
func steer(goal: Vector3) -> Vector3:
    ensure_route(goal);_consume_walks()
    if route.is_empty():return Vector3.ZERO
    var target: Vector3=route[0].point
    if route[0].kind=="portal" and global_position.distance_to(target)<.2:return Vector3.ZERO
    # Skip visible walking points without crossing a portal or cutting a corner.
    for index in range(mini(5,route.size())-1,0,-1):
        if route[index].kind!="walk":continue
        var walk_only=true
        for earlier in range(index):
            if route[earlier].kind!="walk":walk_only=false
        if walk_only and navigator().walk_clear(global_position,route[index].point):
            for earlier in index:route.pop_front()
            target=route[0].point;break
    if not navigator().walk_clear(global_position,target):
        clear_route();replan_delay=.15;return Vector3.ZERO
    var direction=target-global_position;direction.y=0
    if direction.length()<.015:return Vector3.ZERO
    direction=direction.normalized()
    for angle in [0,30,-30]:
        var candidate=direction.rotated(Vector3.UP,deg_to_rad(angle))
        var point=global_position+candidate*minf(.3,global_position.distance_to(target))
        var floor=navigator().project(point)
        if floor!=null and navigator().walk_clear(global_position,floor) and navigator().local_clear(self,floor):return candidate
    return Vector3.ZERO
func _crossed(action_id: String,success: bool) -> void:
    super._crossed(action_id,success)
    if success and not route.is_empty() and route[0].kind=="portal":route.pop_front();route_age=0
    else:clear_route();replan_delay=.3
    if state in ["hit","dying","dead"]:clear_route()
func step(delta: float) -> void:
    if not is_finite(delta) or delta<=0:return
    replan_delay=maxf(0,replan_delay-delta)
    for key in blocked_portals.keys():
        blocked_portals[key]-=delta
        if blocked_portals[key]<=0:blocked_portals.erase(key)
    if not crossing.is_active() and state not in ["hit","dying","dead","attack"]:
        visible_now=sees_player() or hears_player()
        if visible_now:search_remaining=12;last_known=scene.player.global_position
        else:
            search_remaining=maxf(0,search_remaining-delta)
            if search_remaining>0 and memory>0:memory=maxf(memory,.15)
            elif search_remaining<=0:
                memory=0
                if path_pending or not route.is_empty():clear_route()
        if path_pending or not route.is_empty():route_age+=delta
    super.step(delta)
func receive_combat_hit(event: Dictionary) -> bool:
    if not super.receive_combat_hit(event):return false
    search_remaining=12
    if not crossing.is_active():clear_route();replan_delay=0
    return true
func snapshot() -> Dictionary:
    var data=super.snapshot();data.search_remaining84=search_remaining
    return data
func restore(data: Dictionary) -> void:
    clear_route();blocked_portals.clear();replan_delay=0;portal_wait=0
    search_remaining=float(data.get("search_remaining84",minf(12,float(data.memory)*3)))
    super.restore(data)
