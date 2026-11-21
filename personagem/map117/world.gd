extends Node3D
const B="res://staging/e06_world/arroio/"
var scene:Node3D
var player:CharacterBody3D
var ui:Control
var house:Node3D
var map:Node3D
var ready_map=false
var config={}
var allocation={}
var searched={}
var progress={}
var claimed={}
var key_to_native={}
var native_to_key={}
var cells={}
var grounds=[]
var pending_id=""
var active_id=""
var nearest_id=""
var chosen_drawer={}
var visuals={}
var prompt:Label3D
var dirty=false
var saving=false
var suppress_save=false
var save_clock=0.0
var door_cells118={}
func nearest_door118()->Dictionary:
 if not door_cells118 is Dictionary:return {}
 var cell=_cell(player.global_position);var best={};var distance=1.6*1.6
 for x in range(-1,2):
  for z in range(-1,2):
   for row in door_cells118.get(cell+Vector2i(x,z),[]):
    var point:Vector3=row.point
    if absf(point.y-player.global_position.y-1.1)>1.4:continue
    var d=Vector2(point.x-player.global_position.x,point.z-player.global_position.z).length_squared()
    if d>=distance:continue
    var body=row.door.hinge.get_node("DoorCollision")
    var ray=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*1.1,point,3,[player.get_rid(),body.get_rid()])
    if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():continue
    best=row;distance=d
 return best
func door_preferred118(row:Dictionary)->bool:
 if row.is_empty():return false
 if nearest_id.is_empty():return true
 var a:Vector3=row.point-player.global_position;var b:Vector3=player.bag_inventory.point(nearest_id)-player.global_position
 return Vector2(a.x,a.z).length_squared()<Vector2(b.x,b.z).length_squared()
func setup(body:CharacterBody3D,interface:Control):
 player=body;ui=interface;scene=get_parent();player.world_interaction=self
 prompt=Label3D.new();prompt.font_size=24;prompt.pixel_size=.003;prompt.billboard=BaseMaterial3D.BILLBOARD_ENABLED;prompt.no_depth_test=true;prompt.modulate=Color("f6df9e");add_child(prompt);prompt.visible=false
 player.bag_inventory.changed.connect(refresh)
func attach(adapter:Node3D):
 house=adapter;map=load("res://personagem/map117/map.gd").new();add_child(map);map.set_process(false);map.set_physics_process(false);map.set_process_input(false);map.set_process_unhandled_input(false);map.set_process_unhandled_key_input(false)
 map.city=scene.city;map.actor=player;map.camera=scene.camera;map.manager=scene.city.get_node("ResidentialInteriors");map.civic=scene.city.get_node("CivicInteriors");map.config=JSON.parse_string(FileAccess.get_file_as_string(B+"spatial_loot/config.json"))
 map.manager.review_focus=player;map.civic.controller.review_focus=player;map.manager.set_process_unhandled_key_input(false);map.civic.controller.set_process_unhandled_key_input(false)
 map._bind_targets();map._setup_pickup()
 for h in map.manager.homes.values():scene.city.static_batcher.restore_tree(h.instance)
 var moves:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(B+"spatial_loot/furniture_moves.json"))
 for fid in moves:
  var r:Dictionary=moves[fid];var h:Dictionary=map.manager.homes[r.home];var found=map.targets.values().filter(func(t):return t.row.owner==fid and t.row.site==r.home)
  var t:Dictionary=found[0] if not found.is_empty() else {"row":{"owner":fid,"site":r.home},"home":h}
  var p:Array=r.world_pivot;map._rotate_furniture(t,float(r.yaw_degrees),Vector3(p[0],p[1],p[2]));p=r.world_translation;map._move_furniture(t,Vector3(p[0],p[1],p[2]))
 for h in map.manager.homes.values():
  scene.city.static_batcher.batch_tree(h.instance)
  for door in h.doors:
   if door.exterior:door.hinge.set_meta("closed_basis",door.closed_basis)
 map.ready_state=true;config=map.config;var model:RefCounted=player.bag_inventory
 for id in map.targets:
  var t:Dictionary=map.targets[id];var key="world:arroio:"+id;key_to_native[key]=id;native_to_key[id]=key;var grid:Array=t.row.grid.duplicate();var row={"name":str(t.row.name).substr(0,80),"kind":"cabinet","capacity":int(grid[0])*int(grid[1]),"position":[t.stance.x,t.stance.y,t.stance.z],"native117":id,"loot_owner":t.row.owner,"house":t.row.site}
  if t.row.site=="H01":grid[0]=maxi(int(grid[0]),6 if "GUARDA" in t.row.owner else 4);grid[1]=maxi(int(grid[1]),6 if "GUARDA" in t.row.owner else 4)
  row.capacity=int(grid[0])*int(grid[1]);model.register_anchor(key,row,[]);model.import_grids[key]=grid;progress[key]=0.0
  var cell=_cell(t.point)
  if not cells.has(cell):cells[cell]=[]
  cells[cell].append(key)
 var generator=load(B+"spatial_loot/world_state.gd").new();generator._allocate(config);allocation=generator.allocation.duplicate(true)
 for pickup in config.pickups:allocation[pickup.container_id].push_front({"item":pickup.item,"count":1,"reserved_pickup117":pickup.id})
 for controller in [map.manager,map.civic.controller]:
  for lot in controller.homes:
   for door in controller.homes[lot].doors:
    var point:Vector3=door.leaf.global_transform*door.leaf.mesh.get_aabb().get_center();var cell=_cell(point)
    if not door_cells118.has(cell):door_cells118[cell]=[]
    door_cells118[cell].append({"door":door,"point":point,"lot":lot})
 ready_map=true;player.world_map117=self;refresh_access();refresh()
func _cell(p:Vector3)->Vector2i:return Vector2i(floori(p.x/4),floori(p.z/4))
func is_map_key(id:String)->bool:return key_to_native.has(id)
func refresh_access():
 if not ready_map:return
 var model=player.bag_inventory;var ids:Array[String]=[];var origin=_cell(player.global_position)
 for x in range(-1,2):
  for z in range(-1,2):
   for key in cells.get(origin+Vector2i(x,z),[]):
    if map.check_access(key_to_native[key],"open").is_empty():ids.append(key)
 for id in grounds:
  var point:Vector3=model.point(id)
  if player.global_position.distance_to(point)<1.8:
   var ray=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*1.4,point+Vector3.UP*.1,1,[player.get_rid()])
   if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():ids.append(id)
 model.set_reachable(ids,player.global_position)
 var opened:Array[String]=[]
 for id in ids:
  if id in grounds:opened.append(id);continue
  var native:String=key_to_native[id]
  if searched.has(native) and _opened(native):opened.append(id)
 model.opened.assign(opened)
func _opened(id:String)->bool:
 var parts:Array=map.targets[id].row.parts
 return parts.is_empty() or parts.any(func(part):return map.moving[part].current>=.999)
func bootstrap(recipe:Dictionary)->bool:
 var model=player.bag_inventory;var keep={}
 for uid in model.items:
  if model.items[uid].location in ["slot:shirt","slot:pants","slot:boots","slot:belt"]:keep[uid]=model.items[uid].duplicate(true)
 model.items=keep;model.world_containers=model.house_anchors.duplicate(true);model.next_id=1
 for uid in model.items:model.next_id=maxi(model.next_id,int(str(uid).trim_prefix("item_"))+1)
 for source in recipe.loot:
  var id:String=source.furniture
  if not allocation.has(id):continue
  allocation[id]=[]
  for item in source.items:allocation[id].append({"item":item.definition,"count":int(item.count),"x":int(item.x),"y":int(item.y),"rot":bool(item.get("rot",false)),"condition":"authored_demo_stock"})
 for item in recipe.pockets:
  if model.add_at(item.definition,int(item.count),"pockets",int(item.x),int(item.y),bool(item.get("rot",false))).is_empty():return false
 model.seeding=false;dirty=false;model.changed.emit();dirty=false;return true
func has_interaction()->bool:return not pending_id.is_empty() or not active_id.is_empty()
func request_open(id:String)->bool:
 if id in grounds and player.bag_inventory.accessible(id):return ui.show_container(id)
 if not is_map_key(id) or has_interaction() or id not in player.bag_inventory.reachable:return false
 var native:String=key_to_native[id];var parts:Array=map.targets[native].row.parts
 var available=parts.filter(func(part):return map.sweep(part,1.0).is_empty())
 if not parts.is_empty() and available.is_empty():ui.feedback.text="Libere espaço para abrir o móvel";return false
 if not player.request_gesture() or not player.set_hud_open(true):return false
 player.velocity=Vector3.ZERO;pending_id=id
 for part in available:map.moving[part].goal=1.0
 return true
func interact_nearest()->bool:
 if has_interaction():close_interaction();return true
 refresh_access();_update_prompt()
 var door=nearest_door118()
 if door_preferred118(door):return player.map_doors.request_external118(door.door)
 if not nearest_id.is_empty():return request_open(nearest_id)
 # Residential and civic doors outside the H01 controller keep their map interaction.
 var event=InputEventKey.new();event.pressed=true;event.physical_keycode=KEY_E
 for controller in [map.manager,map.civic.controller]:controller._unhandled_key_input(event)
 return false
func close_interaction(hide_inventory:bool=true):
 for id in [pending_id,active_id]:
  if not is_map_key(id):continue
  for part in map.targets[key_to_native[id]].row.parts:map.moving[part].goal=0.0
 pending_id="";active_id=""
 if hide_inventory:ui.close_nearby(false)
 if player.action.state!="idle" and player.action.action_id=="access":player.action.cancel()
 player.set_hud_open(ui.windows.any(func(w):return w.visible));refresh_access()
func _physics_process(delta:float):advance(delta)
func advance(delta:float):
 if not ready_map or player.paused:return
 map._physics_process(delta)
 for key in key_to_native:
  var native:String=key_to_native[key];var parts:Array=map.targets[native].row.parts;var f=0.0
  for part in parts:f=maxf(f,map.moving[part].current)
  progress[key]=f if not parts.is_empty() else (1.0 if key==active_id else 0.0)
 house.sync_parts()
 refresh_access()
 if not pending_id.is_empty():
  if player.reaction.is_active() or pending_id not in player.bag_inventory.reachable:close_interaction()
  elif _opened(key_to_native[pending_id]) and player.action.state=="idle":
   var id=pending_id;pending_id="";active_id=id
   if search_once(id):refresh_access();ui.show_container(id)
   else:close_interaction()
  elif not _opened(key_to_native[pending_id]) and not map.targets[key_to_native[pending_id]].row.parts.is_empty() and map.targets[key_to_native[pending_id]].row.parts.all(func(part):return is_equal_approx(map.moving[part].current,map.moving[part].goal)):
   close_interaction();ui.feedback.text="Movimento interrompido: libere o caminho do móvel"
 if not active_id.is_empty() and active_id not in player.bag_inventory.reachable:close_interaction()
 save_clock+=delta
 if dirty and save_clock>.6 and scene.demo_ready and player.session_save!=null and player.session_save._idle():
  save_clock=0;saving=true
  if player.session_save.save():dirty=false
  saving=false
 _update_prompt()
func search_once(key:String)->bool:
 var id:String=key_to_native[key]
 if searched.has(id):return true
 if not _opened(id) or not map.check_access(id,"search").is_empty():return false
 var model=player.bag_inventory;var shadow=model.get_script().new();shadow.house_anchors=model.house_anchors.duplicate(true)
 if not shadow.restore(model.snapshot(),false):return false
 for row in allocation.get(id,[]):
  var placed=false
  if row.has("x"):
   placed=not shadow.add_at(row.item,int(row.count),key,int(row.x),int(row.y),bool(row.get("rot",false))).is_empty()
  else:
   var size:Vector2i=shadow.dimensions(key)
   for rotation in [false,true]:
    if placed:break
    for y in size.y:
     if placed:break
     for x in size.x:
      if not shadow.add_at(row.item,int(row.count),key,x,y,rotation).is_empty():placed=true;break
 for uid in shadow.items:
  if not model.items.has(uid):
   shadow.items[uid]["source_container"]=id
   for row in allocation.get(id,[]):
    if row.item==shadow.items[uid].definition:shadow.items[uid]["loot_condition"]=row.get("condition","reserved_authored");break
 var before_claimed=claimed.duplicate(true)
 for pickup in config.pickups:
  if pickup.container_id!=id:continue
  for uid in shadow.items:
   if shadow.items[uid].location==key and shadow.items[uid].definition==pickup.item:claimed[pickup.id]={"uid":uid,"taken":false};break
 var before=model.snapshot();var old_rounds=player.weapons.rounds.duplicate(true);model.restore(shadow.snapshot(),false);player.weapons.sync();searched[id]=true;refresh_access()
 saving=true;var ok=player.session_save!=null and player.session_save.save();saving=false
 if not ok:model.restore(before,false);player.weapons.rounds=old_rounds;player.weapons.sync();searched.erase(id);claimed=before_claimed;refresh_access();return false
 model.changed.emit();dirty=false;return true
func refresh():
 if player==null:return
 grounds.clear()
 for id in player.bag_inventory.world_containers:
  if player.bag_inventory.world_containers[id].kind=="ground":grounds.append(id)
 if ready_map:
  _sync_pickup117()
  if not suppress_save and not saving:dirty=true
func toggle_test_power117(event:InputEvent):
 if is_instance_valid(map.manager.services):map.manager.services._unhandled_key_input(event)
func _sync_pickup117():
 for pickup in config.pickups:
  var taken=false
  if claimed.has(pickup.id):
   var record:Dictionary=claimed[pickup.id];var model=player.bag_inventory
   if not record.taken and (not model.items.has(record.uid) or model.items[record.uid].location!=native_to_key[pickup.container_id]):record.taken=true
   taken=record.taken
  for mesh in map.pickup_meshes:mesh.visible=not taken
  if is_instance_valid(map.pickup_shape):map.pickup_shape.set_deferred("disabled",taken)
func _update_prompt():
 if not ready_map:return
 var ids=player.bag_inventory.reachable.filter(func(id):return is_map_key(id) or (id in grounds and not player.bag_inventory.contents(id).is_empty()));nearest_id="";var best=INF
 for id in ids:
  var d:float=player.global_position.distance_squared_to(player.bag_inventory.point(id))
  if d<best:best=d;nearest_id=id
 if not nearest_id.is_empty():
  var group:String=map.targets[key_to_native[nearest_id]].row.owner if is_map_key(nearest_id) else ""
  if chosen_drawer.has(group):
   var candidates=ids.filter(func(id):return map.targets[key_to_native[id]].row.owner==group)
   if not candidates.is_empty():nearest_id=candidates[int(chosen_drawer[group])%candidates.size()]
 prompt.visible=not nearest_id.is_empty() and not player.hud_open
 if prompt.visible:
  prompt.global_position=(map.targets[key_to_native[nearest_id]].point if is_map_key(nearest_id) else player.bag_inventory.point(nearest_id))+Vector3.UP*.3
  prompt.text=("E · Abrir e vasculhar   J · Compartimento\n" if is_map_key(nearest_id) else "E · Ver itens no chão\n")+str(player.bag_inventory.world_containers[nearest_id].name)
 var door=nearest_door118()
 if door_preferred118(door) and not player.hud_open:
  prompt.visible=true;prompt.global_position=door.point+Vector3.UP*.35;prompt.text=("E · Fechar porta\n" if door.door.open else "E · Abrir porta\n")+str(door.lot)
func _unhandled_input(event:InputEvent):
 if ready_map and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_J and is_map_key(nearest_id) and not has_interaction():
  var group:String=map.targets[key_to_native[nearest_id]].row.owner;chosen_drawer[group]=int(chosen_drawer.get(group,0))+1;_update_prompt();get_viewport().set_input_as_handled()
func _pose(key:String):
 if not is_map_key(key):return
 var f:float=progress.get(key,0.0)
 for part in map.targets[key_to_native[key]].row.parts:map.moving[part].prep.set_review_fraction(part,f);map.moving[part].current=f;map.moving[part].goal=f
func snapshot117()->Dictionary:
 var states={};var parts={}
 for id in map.moving:parts[id]=map.moving[id].current>=.999
 for key in key_to_native:states[key]=_opened(key_to_native[key]) if not map.targets[key_to_native[key]].row.parts.is_empty() else key==active_id
 return {"version":1,"seed":config.default_world_seed,"allocation":allocation.duplicate(true),"searched":searched.duplicate(true),"claimed":claimed.duplicate(true),"states":states,"parts":parts,"active":active_id}
func apply117(data:Dictionary):
 allocation=data.allocation.duplicate(true);searched=data.searched.duplicate(true);claimed=data.claimed.duplicate(true)
 for key in key_to_native:progress[key]=1.0 if data.states.get(key,false) else 0.0;_pose(key)
 for id in data.get("parts",{}):
  var fraction=1.0 if data.parts[id] else 0.0;map.moving[id].prep.set_review_fraction(id,fraction);map.moving[id].current=fraction;map.moving[id].goal=fraction
 _sync_pickup117();refresh_access();house.sync_parts();dirty=false

func configure_windows117():
 var home:Dictionary=house.home
 for data in player.map_doors.doors.values():
  if data.get("kind","")!="window":continue
  var roots=[]
  if data.has("parts"):
   for part in data.parts:roots.append(part.hinge)
  else:roots.append(data.hinge)
  for root in roots:
   for mesh:MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
    mesh.set_meta("interior_original_shadow",mesh.cast_shadow);mesh.set_meta("interior_unit","main");mesh.set_meta("keep_individual_visual",true)
    if mesh not in home.walls:home.walls.append(mesh)
