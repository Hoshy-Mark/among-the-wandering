extends "res://personagem/partida107.gd"
var pending117={}
var proposed_states117={}
var proposed_parts118={}
var extra_parts117=[]
var relocated117=[]
func reconcile_population117():
 var data=enemies.snapshot();var parts=_parts(scene.player.map_doors.snapshot(),_world_snapshot())
 if not _relocate117(data,scene.player.global_position,parts):push_error("Map117: no safe population placement");return
 enemies.restore(data);enemies.initial=data.duplicate(true)
 print("MAP117 population relocated: ",relocated117.size())
func _relocate117(states:Dictionary,player_point:Vector3,parts:Array)->bool:
 var points=[player_point];relocated117=[]
 for id in states:
  var entry:Dictionary=states[id];var raw:Array=entry.position;var point=Vector3(raw[0],raw[1],raw[2]);var safe=_population_clear117(point,points,parts)
  if not safe:
   for ring in range(1,49):
    if safe:break
    for step in range(maxi(8,ring*8)):
     var angle=TAU*step/maxi(8,ring*8);var candidate=point+Vector3(cos(angle),0,sin(angle))*ring*.5
     var ray=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*1.0,candidate-Vector3.UP*1.5,3,_excluded(parts));var floor=get_world_3d().direct_space_state.intersect_ray(ray)
     if floor.is_empty() or floor.normal.y<.9:continue
     candidate.y=floor.position.y
     if _population_clear117(candidate,points,parts):point=candidate;safe=true;break
   if not safe:return false
   entry.position=[point.x,point.y,point.z];entry.last_known=entry.position.duplicate();relocated117.append(id)
  if entry.state!="dead":points.append(point)
 return true
func _population_clear117(point:Vector3,others:Array,parts:Array)->bool:
 for other in others:
  if absf(point.y-other.y)<1.84 and Vector2(point.x-other.x,point.z-other.z).length()<.52:return false
 return _space(point,false,parts)
func _idle()->bool:
 if not super._idle():return false
 for part in scene.world_items.map.moving.values():
  if absf(part.current-part.goal)>.0001 or (part.current>.0001 and part.current<.9999):return false
 return true
func _excluded(parts:Array)->Array[RID]:
 var result=super._excluded(parts)
 for part in extra_parts117:
  if part.rid.is_valid() and part.rid not in result:result.append(part.rid)
 return result
func _space(point:Vector3,crouched:bool,parts:Array)->bool:
 var w=scene.world_items;var origin:Vector2i=w._cell(point);var extra=[];var seen={}
 for x in range(-1,2):
  for z in range(-1,2):
   for key in w.cells.get(origin+Vector2i(x,z),[]):
    var target:Dictionary=w.map.targets[w.key_to_native[key]]
    if target.row.site=="H01":continue
    for name in target.row.parts:
     if seen.has(name):continue
     seen[name]=true;var p:Dictionary=w.map.moving[name].item;var f=1.0 if proposed_parts118.get(name,proposed_states117.get(key,w._opened(w.key_to_native[key]))) else 0.0;var local:Transform3D=p.closed_transform
     if p.definition.motion=="slide":local.origin+=p.outward_local*float(p.definition.preview_travel_m)*f
     else:local.basis=local.basis*Basis(p.axis,deg_to_rad(float(p.definition.preview_angle_degrees))*f*(-1 if p.edge=="max" else 1))
     var body:CollisionObject3D=p.proxy.get_parent();var pose:Transform3D=p.pivot.get_parent().global_transform*local*body.transform*p.proxy.transform
     extra.append({"shape":p.proxy.shape,"pose":pose,"rid":body.get_rid()})
 extra_parts117=extra
 var clear=super._space(point,crouched,parts+extra)
 extra_parts117=[];return clear
func _world_snapshot()->Dictionary:
 var w=scene.world_items;var states={};var opened=[];var chosen={}
 for id in w.house.bindings:
  var native:String=w.key_to_native[id];states[id]=w._opened(native) if not w.map.targets[native].row.parts.is_empty() else id==w.active_id
  if id in scene.player.bag_inventory.opened:opened.append(id)
 for id in w.chosen_drawer:
  if w.house.groups.has(id):chosen[id]=w.chosen_drawer[id]
 return {"states":states,"opened":opened,"active":w.active_id if w.house.bindings.has(w.active_id) else "","chosen":chosen}
func _signature()->String:
 return super._signature()+"|map117|"+FileAccess.get_sha256("res://staging/e06_world/arroio/spatial_loot/layouts.json")+FileAccess.get_sha256("res://staging/e06_world/arroio/spatial_loot/config.json")+FileAccess.get_sha256("res://staging/e06_world/arroio/spatial_loot/furniture_moves.json")
func snapshot()->Dictionary:
 var data=super.snapshot();data.world117=scene.world_items.snapshot117();return data
func _parts(doors:Dictionary,furniture:Dictionary)->Array:
 residential_parts98=residential98.parts(self)
 var result=[];var controller=scene.player.map_doors
 for id in controller.doors:
  var d:Dictionary=controller.doors[id];var f=1.0 if doors.states.get(id,false) else 0.0
  if d.has("parts"):
   for index in d.parts.size():
    var part:Dictionary=d.parts[index];var pose:Transform3D=part.hinge.get_parent().global_transform*controller._part_pose(part,f)*part.body.transform*part.collider.transform
    _add(result,id+"/"+str(index),id,part.collider,pose,part.body,RID(),f>0)
  else:
   var pose:Transform3D=d.hinge.get_parent().global_transform*controller._pose(d,f)*d.body.transform*d.collider.transform;_add(result,id,id,d.collider,pose,d.body,RID(),f>0)
 var w=scene.world_items
 for id in w.house.bindings:
  var native:String=w.key_to_native[id];var target:Dictionary=w.map.targets[native];var f=1.0 if furniture.states.get(id,false) else 0.0
  for name in target.row.parts:
   f=1.0 if proposed_parts118.get(name,f>0) else 0.0
   var p:Dictionary=w.map.moving[name].item;var local:Transform3D=p.closed_transform
   if p.definition.motion=="slide":local.origin+=p.outward_local*float(p.definition.preview_travel_m)*f
   else:local.basis=local.basis*Basis(p.axis,deg_to_rad(float(p.definition.preview_angle_degrees))*f*(-1 if p.edge=="max" else 1))
   var body:CollisionObject3D=p.proxy.get_parent();var pose:Transform3D=p.pivot.get_parent().global_transform*local*body.transform*p.proxy.transform
   var fixed:CollisionObject3D=w.house.groups[target.row.owner].body
   _add(result,name,target.row.owner,p.proxy,pose,body,fixed.get_rid(),f>0,p.pivot,local,p)
 return result
func _validate117(data:Variant)->bool:
 if not data is Dictionary or data.get("version")!=1 or not data.get("seed") is String or not data.get("allocation") is Dictionary or not data.get("searched") is Dictionary or not data.get("states") is Dictionary or not data.get("claimed") is Dictionary or not data.get("active") is String:return false
 var w=scene.world_items
 if not data.get("parts",{}) is Dictionary:return false
 for id in data.get("parts",{}):
  if not w.map.moving.has(id) or not data.parts[id] is bool:return false
 if data.allocation.size()!=w.allocation.size() or data.states.size()!=w.key_to_native.size():return false
 for id in w.allocation:
  if not data.allocation.get(id) is Array:return false
  for row in data.allocation[id]:
   if not row is Dictionary or not scene.player.bag_inventory.catalog.has(row.get("item","")) or not (row.get("count") is int or row.get("count") is float) or row.count<1 or row.count!=floor(row.count) or row.count>int(scene.player.bag_inventory.catalog[row.item].stack):return false
 for id in data.claimed:
  if not w.config.pickups.any(func(p):return p.id==id):return false
  var record=data.claimed[id]
  if not record is Dictionary or not record.get("uid") is String or not record.get("taken") is bool:return false
 for id in data.searched:
  if not w.allocation.has(id) or data.searched[id]!=true:return false
 for key in w.key_to_native:
  if not data.states.get(key) is bool:return false
 if not data.active.is_empty() and (not w.is_map_key(data.active) or not data.states.get(data.active,false)):return false
 return true
func prepare(value:Variant,spatial:bool=true)->Dictionary:
 pending117={};proposed_states117={};proposed_parts118={}
 if not value is Dictionary:return {}
 var data:Dictionary=value.duplicate(true);var w=scene.world_items;var migrated=not data.has("world117")
 if migrated:
  if data.get("session81") is Dictionary:
   if data.session81.get("world") not in [super._signature(),_signature()]:reason="world";return {}
   data.session81.world=_signature()
   var p:Array=data.session81.position;var oldpoint=w.house.home.model.to_local(Vector3(p[0],p[1],p[2]));var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/h01_rule67.json")).lots.H01;var b:Array=old.interior_bounds
   if oldpoint.x>=b[0][0] and oldpoint.x<=b[1][0] and oldpoint.z>=b[0][2] and oldpoint.z<=b[1][2]:
    var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://staging/e06_world/arroio/spatial_loot/layouts.json")).houses.H01;oldpoint.x=layout.anchor_xz[0]+(oldpoint.x-layout.anchor_xz[0])*layout.factor_xz;oldpoint.z=layout.anchor_xz[1]+(oldpoint.z-layout.anchor_xz[1])*layout.factor_xz;var point=w.house.home.model.to_global(oldpoint)
    if not w.house.standing_clear(point):point=w.house.home.model.to_global(Vector3(w.house.spawn_local117[0],w.house.spawn_local117[1],w.house.spawn_local117[2]))
    data.session81.position=[point.x,point.y,point.z]
  data.world117=w.snapshot117();data.world117.erase("parts");data.world117.active=""
  for key in data.world117.states:data.world117.states[key]=false
  for key in w.house.bindings:
   data.world117.searched[w.key_to_native[key]]=true;data.world117.allocation[w.key_to_native[key]]=[]
   if data.get("session81") is Dictionary:data.world117.states[key]=bool(data.session81.furniture.states.get(key,false))
 if not _validate117(data.get("world117")):reason="invalid";return {}
 proposed_states117=data.world117.states.duplicate(true)
 proposed_parts118=data.world117.get("parts",{}).duplicate(true)
 if not data.get("inventory") is Dictionary:reason="invalid";return {}
 if not data.inventory.get("import_grids") is Dictionary:data.inventory.import_grids={}
 for id in scene.player.bag_inventory.import_grids:
  var grid:Array=scene.player.bag_inventory.import_grids[id];var old=data.inventory.import_grids.get(id,grid);data.inventory.import_grids[id]=[maxi(int(grid[0]),int(old[0])),maxi(int(grid[1]),int(old[1]))]
 if migrated and spatial and data.get("enemies82") is Dictionary and enemies.valid(data.enemies82):
  var pos:Array=data.session81.position
  if not _relocate117(data.enemies82,Vector3(pos[0],pos[1],pos[2]),_parts(data.doors_h01,data.session81.furniture)):reason="occupied";return {}
 var prepared=super.prepare(data,spatial)
 if prepared.is_empty() and migrated and spatial and reason=="occupied":
  var spawn:Array=w.house.spawn_local117;var safe=w.house.home.model.to_global(Vector3(spawn[0],spawn[1],spawn[2]));data.session81.position=[safe.x,safe.y,safe.z]
  if data.get("enemies82") is Dictionary and enemies.valid(data.enemies82):_relocate117(data.enemies82,safe,_parts(data.doors_h01,data.session81.furniture))
  prepared=super.prepare(data,spatial)
 if not prepared.is_empty():pending117=data.world117.duplicate(true)
 return prepared
func load_game()->bool:
 var w=scene.world_items;w.suppress_save=true
 var accepted=super.load_game()
 if accepted:
  w.apply117(pending117)
  if not pending117.active.is_empty() and pending117.active in scene.player.bag_inventory.reachable:
   w.active_id=pending117.active;scene.game_ui.show_container(w.active_id)
 w.dirty=false;w.suppress_save=false;return accepted
