extends RefCounted
var checks=[]
func check(ok:bool,message:String):
 checks.append({"passed":ok,"message":message})
 if not ok:push_error("R118 "+message)
func settle(game):
 for i in 240:game.player.action.advance(1.0/60);game.world_items.advance(1.0/60)
func capture(game,name):
 if DisplayServer.get_name()=="headless":return
 for i in 3:await game.get_tree().process_frame
 await RenderingServer.frame_post_draw
 game.get_viewport().get_texture().get_image().save_jpg("res://qa/map118/"+name+".jpg",.85)
func run(game):
 var p=game.player;var w=game.world_items;var d=p.map_doors
 p.set_physics_process(false);w.set_physics_process(false);d.set_physics_process(false)
 check(game.game_ui.nearby.visible and w.active_id!="","wardrobe shows real inventory after gesture")
 await capture(game,"wardrobe")
 var key=w.active_id;var bag=p.bag_inventory
 if not key.is_empty():
  var backpacks=bag.contents(key).filter(func(uid):return bag.catalog[bag.items[uid].definition].get("slot","")=="backpack")
  if not backpacks.is_empty():check(p.equip_item(backpacks[0]),"equip backpack from revised wardrobe");settle(game)
 w.close_interaction();settle(game);game.game_ui.personal.visible=false;game.game_ui.refresh()
 var ground=bag.ground_at(p.global_position);var uid=bag.add_at("food",1,ground,0,0,false)
 p.update_nearby();check(not uid.is_empty() and w.request_open(ground) and game.game_ui.nearby.visible,"ground item opens nearby HUD")
 await capture(game,"ground")
 game.game_ui.quick_pickup(uid);check(bag.owned(uid),"ground item transfers through approved quick pickup")
 w.close_interaction();settle(game)
 for lot in ["H02","H10","H40"]:
  var home=w.house.shell.homes[lot];var candidates=home.doors.filter(func(door):return door.exterior)
  if candidates.is_empty():check(false,"entry exists "+lot);continue
  var door=candidates[0];door.hinge.basis=door.closed_basis;door.open=false
  var collider=door.hinge.get_node("DoorCollision").get_child(0);var bounds:AABB
  if collider.shape is ConvexPolygonShape3D:
   var vertices=collider.shape.points;bounds=AABB(vertices[0],Vector3.ZERO)
   for vertex in vertices:bounds=bounds.expand(vertex)
  else:bounds=AABB(-collider.shape.size*.5,collider.shape.size)
  var transform=collider.global_transform;var centre=transform*bounds.get_center();var normal=(transform.basis.x if bounds.size.x<bounds.size.z else transform.basis.z).normalized()
  var position=centre+normal*1.25;position.y=centre.y-.3
  var ray=PhysicsRayQueryParameters3D.create(position,position-Vector3.UP*2,1,[p.get_rid(),collider.get_parent().get_rid()]);var hit=game.get_world_3d().direct_space_state.intersect_ray(ray)
  if hit.is_empty():check(false,"entry support "+lot);continue
  position.y=hit.position.y+.01;p.global_position=position;p.velocity=Vector3.ZERO;p.action.cancel();p.locomotion.cancel();p.combat.set_guard(false)
  await game.get_tree().physics_frame;await game.get_tree().physics_frame
  var accepted=false
  if lot=="H10":
   w.refresh_access();w._update_prompt();print("PROMPT118 ",w.prompt.text)
   var event=InputEventKey.new();event.pressed=true;event.physical_keycode=KEY_E;p._unhandled_key_input(event);accepted=d.busy()
  else:accepted=d.request_external118(door)
  print("FOREIGN118 ",lot," accepted=",accepted," hit=",d.last_hit," hud=",p.hud_open," interaction=",w.has_interaction()," action=",p.action.state," busy=",d.busy()," distance=",p.global_position.distance_to(centre))
  check(accepted,"outside H01 door accepted "+lot)
  for i in 180:
   if d.yielding113():d.advance_yield113(1.0/60)
   p.action.advance(1.0/60);d._physics_process(1.0/60)
   await game.get_tree().physics_frame
   if not d.busy() and p.action.state=="idle":break
  check(door.open and not d.busy(),"outside H01 door completes "+lot)
  print("FOREIGN_END118 ",lot," open=",door.open," fraction=",door.fraction," action=",p.action.state," effect=",p.action.effect_succeeded," hit=",d.last_hit)
 check(d.snapshot().states.keys().all(func(id):return str(id).begins_with("H01/")),"foreign doors do not alter legacy H01 save keys")
 w.close_interaction();settle(game);p.global_position=game.spawn;p.action.cancel();p.locomotion.cancel();p.command=Vector2.ZERO
 var saved=p.save_condition();check(saved,"revised map with independent leaves saves")
 if saved:check(p.load_condition(),"revised map with independent leaves reloads")
 var result={"passed":checks.all(func(c):return c.passed),"checks":checks,"houses":w.house.shell.homes.size(),"containers":w.key_to_native.size(),"controlled_windows":d.doors.values().filter(func(v):return v.get("kind","")=="window").size(),"window_scope":"H01 only; other houses require window integration"}
 FileAccess.open("res://qa/map118/integration.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("EXPLORATION118 ",JSON.stringify(result))
