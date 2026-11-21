extends SceneTree
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("res://qa/map118")
 set_meta("demo95_fresh",true);set_meta("demo95_profile_override","res://qa/map118/profile.json")
 var game=load("res://demo_inventory.tscn").instantiate();root.add_child(game)
 while not game.demo_ready:await process_frame
 var p=game.player;var w=game.world_items;var d=p.map_doors
 game.zombie_world.set_physics_process(false);game.zombie_world.navigation.set_physics_process(false)
 p.scripted=true
 for a in game.zombie_world.actors.values():a.ai_enabled=false
 var rows=[];var walking=[]
 for id in d.doors:
  var door=d.doors[id]
  if door.get("kind","")=="window":continue
  var clear=d._world_sweep113(door,1)
  d.clear_path(id,1)
  var angles=[];var original_angle=door.angle
  for scale in [.95,.9,.85,.8]:door.angle=original_angle*scale;angles.append([scale,d._world_sweep113(door,1)])
  door.angle=original_angle
  rows.append({"id":id,"world_clear":clear,"angles":angles,"hit":d.last_hit.duplicate(),"centre":str(door.leaf.global_transform*door.leaf.mesh.get_aabb().get_center())})
 print("DOORS118 ",JSON.stringify(rows))
 for door in d.doors.values():
  if not door.get("exterior",false) or door.get("kind","")=="window":continue
  var closed=door.hinge.get_parent().global_transform*d._pose(door,0)*door.body.transform*door.collider.transform
  var normal=(closed.basis.z if door.collider.shape.size.z<door.collider.shape.size.x else closed.basis.x).normalized()
  door.hinge.transform=d._pose(door,1);door.fraction=1;door.open=true
  await physics_frame;await physics_frame
  for sign_value in [-1,1]:
   var point=closed.origin+normal*sign_value*.8
   point.y=closed.origin.y-.5
   var ray=PhysicsRayQueryParameters3D.create(point,point-Vector3.UP*2,1,[p.get_rid()])
   var floor=game.get_world_3d().direct_space_state.intersect_ray(ray)
   if floor.is_empty():continue
   p.global_position=Vector3(point.x,floor.position.y+.004,point.z)
   await physics_frame
   var hit=p.move_and_collide(-normal*sign_value*1.6)
   print("EXIT118 ",sign_value," hit=",str(hit.get_collider().get_path()) if hit!=null else "clear"," position=",p.global_position)
   var start=Vector3(point.x,floor.position.y+.01,point.z)
   p.set_physics_process(false);p.global_position=start;p.velocity=Vector3.ZERO;p.locomotion.cancel();p.action.cancel();p.combat.set_guard(false)
   var direction=-normal*sign_value;var right=game.camera.global_basis.x;right.y=0;right=right.normalized();var down=game.camera.global_basis.z;down.y=0;down=down.normalized()
   p.command=Vector2(direction.dot(right),direction.dot(down))
   for i in 160:p._physics_process(1.0/60)
   walking.append({"side":sign_value,"start":str(start),"end":str(p.global_position),"distance":start.distance_to(p.global_position),"blocked":p.locomotion.blocked})
   p.command=Vector2.ZERO;p.locomotion.cancel();p.set_physics_process(true)
  door.hinge.transform=d._pose(door,0);door.fraction=0;door.open=false
 var key="world:arroio:H01_FURN_GUARDA_CASAL/storage/main"
 w.house.visit(key);await physics_frame;await physics_frame
 var native=w.key_to_native[key];var blocks=[]
 for part in w.map.targets[native].row.parts:blocks.append({"part":part,"hit":w.map.sweep(part,1),"detail":w.map.last_access.duplicate()})
 print("FURN118 ",JSON.stringify(blocks))
 var accepted=w.request_open(key)
 for i in 240:await physics_frame
 var result={"doors":rows,"opened":accepted,"active":w.active_id,"pending":w.pending_id,"searched":w.searched.has(w.key_to_native[key]),"hud":game.game_ui.nearby.visible,"message":game.game_ui.feedback.text,"save_reason":p.session_save.reason,"items":p.bag_inventory.contents(key).size()}
 FileAccess.open("res://qa/map118/probe.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("MAP118 ",JSON.stringify(result))
 FileAccess.open("res://qa/map118/walk.json",FileAccess.WRITE).store_string(JSON.stringify(walking,"  "))
 if "--full118" in OS.get_cmdline_user_args():await load("res://tests/exploration118.gd").new().run(game)
 if "--keep118" in OS.get_cmdline_user_args():
  while not FileAccess.file_exists("res://qa/map118/finish.flag"):
   await create_timer(.5).timeout
   if not FileAccess.file_exists("res://qa/map118/run.flag"):continue
   DirAccess.remove_absolute("res://qa/map118/run.flag")
   var script=GDScript.new();script.source_code=FileAccess.get_file_as_string("res://qa/map118/extension.gd")
   if script.reload()==OK:await script.new().run(game)
 quit()
