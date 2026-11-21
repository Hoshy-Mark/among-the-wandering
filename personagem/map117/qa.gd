extends Node
var checks=[]
var errors=[]
func check(id:String,ok:bool):checks.append({"id":id,"passed":ok});if not ok:errors.append(id)
func run(scene:Node):
 DirAccess.make_dir_recursive_absolute("res://qa/map117")
 var w=scene.world_items;var p=scene.player;p.scripted=true;scene.zombie_world.navigation.set_physics_process(false)
 scene.zombie_world.set_physics_process(false);scene.zombie_world.motor.set_physics_process(false)
 for actor in scene.zombie_world.actors.values():actor.ai_enabled=false;actor.set_physics_process(false)
 check("real_character_preserved",p.avatar!=null and p.weapons!=null and p.shoulder!=null)
 check("social_and_population_preserved",scene.get_node_or_null("Characters99")!=null and scene.zombie_world.model!=null)
 check("all_40_revised_homes",scene.city.get_node("ResidentialInteriors").homes.size()==40 and w.house.home.model.has_meta("spatial_revision"))
 check("whole_map_registry",w.key_to_native.size()>=590)
 check("H01_not_legacy_replacement",w.house.shell==scene.city.get_node("ResidentialInteriors"))
 check("approved_hud_preserved",scene.game_ui.get_script().resource_path=="res://personagem/hud68.gd")
 check("no_legacy_weapon_caches",not p.bag_inventory.world_containers.has("world:weapons86") and not p.bag_inventory.world_containers.has("world:firearms87") and not p.bag_inventory.world_containers.has("world:arsenal92"))
 check("spawn_clear",w.house.standing_clear(p.global_position))
 var path=p.condition_path;p.condition_path="user://qa_map117_"+str(OS.get_process_id())+".json"
 # Finish any introductory action before exercising real saves.
 p.action.cancel();p.inventory_actions.job.clear();p.preview_motion="";p.velocity=Vector3.ZERO
 var prepared=p.session_save.prepare(p.session_save.snapshot(),false);check("complete_session_validates",not prepared.is_empty())
 var snap=p.session_save.snapshot();var probe=p.session_save.prepare(snap,true)
 if probe.is_empty():
  var parts=p.session_save._parts(snap.doors_h01,snap.session81.furniture);var bad=[];var overlaps=[]
  for part in parts:
   for hit in p.session_save._hits(part,parts):
    if part.open or hit not in p.session_save.closed_contacts.get(part.id,[]):bad.append(part.id+":"+hit)
  for i in parts.size():
   for j in range(i):
    if parts[i].owner!=parts[j].owner and p.session_save.geometry.boxes(parts[i],parts[j]):overlaps.append([parts[i].id,parts[j].id])
  print("SESSION_PROBE ",p.session_save.reason," space=",p.session_save._space(p.global_position,p.crouched,parts)," hits=",bad," overlap=",overlaps)
 var saved=p.session_save.save();check("complete_session_saves",saved)
 var searched=false;var chosen=""
 if saved:
  for key in w.house.bindings:
   var native:String=w.key_to_native[key]
   if w.allocation[native].is_empty():continue
   w.house.visit(key);await get_tree().physics_frame
   for part in w.map.targets[native].row.parts:w.map.moving[part].prep.set_review_fraction(part,1);w.map.moving[part].current=1;w.map.moving[part].goal=1
   for k in w.key_to_native:
    if w.key_to_native[k]==native:w.progress[k]=1.0
   w.house.sync_parts();p.action.cancel();w.refresh_access();searched=w.search_once(key);chosen=key
   if searched:break
 check("world_loot_search_commits",searched)
 if searched:
  var before=p.bag_inventory.snapshot();check("same_container_no_refill",w.search_once(chosen) and before==p.bag_inventory.snapshot())
  var keep=w.searched.duplicate(true);w.close_interaction(false)
  for part in w.map.moving:w.map.moving[part].prep.set_review_fraction(part,0);w.map.moving[part].current=0;w.map.moving[part].goal=0
  w.house.sync_parts();w.progress.clear();p.action.cancel();w.dirty=false
  check("full_save_load_preserves_loot",p.load_condition() and w.searched==keep)
 var legacy=p.session_save.snapshot();legacy.erase("world117");legacy.session81.world=legacy.session81.world.split("|map117|")[0]
 var migration=p.session_save.prepare(legacy,false)
 check("legacy_profile_migrates_without_refill",not migration.is_empty() and w.house.bindings.keys().all(func(key):return p.session_save.pending117.searched.get(w.key_to_native[key],false) and p.session_save.pending117.allocation[w.key_to_native[key]].is_empty()))
 w.close_interaction();p.action.cancel()
 for part in w.map.moving:w.map.moving[part].prep.set_review_fraction(part,0);w.map.moving[part].current=0;w.map.moving[part].goal=0
 w.house.sync_parts();w.progress.clear()
 var other=false;var other_key=""
 for key in w.key_to_native:
  var native:String=w.key_to_native[key];var target:Dictionary=w.map.targets[native]
  if target.row.site!="H02" or w.allocation[native].is_empty():continue
  w.house.visit(key);await get_tree().physics_frame;p.action.cancel();w.refresh_access()
  if not w.request_open(key):continue
  for frame in range(240):
   await get_tree().physics_frame
   if w.searched.has(native) or w.pending_id.is_empty():break
  if w.searched.has(native):other=true;other_key=key;break
  w.close_interaction();p.action.cancel()
 check("H02_real_open_and_search",other)
 if other:
  var uid=""
  for item in p.bag_inventory.items:
   if p.bag_inventory.items[item].location==other_key and p.bag_inventory.form(p.bag_inventory.items[item].definition)==Vector2i.ONE:uid=item;break
  if not uid.is_empty():
   scene.game_ui.quick_pickup(uid)
   for frame in range(240):
    await get_tree().physics_frame
    if p.bag_inventory.owned(uid):break
   check("approved_HUD_collects_world_loot",p.bag_inventory.owned(uid))
  w.close_interaction();p.action.cancel()
  for frame in range(160):
   await get_tree().physics_frame
   if p.session_save._idle():break
  check("outside_H01_save",p.session_save.save())
  check("outside_H01_load",p.load_condition())
  var services=w.map.manager.services;var was=services.preview_homes.get("H02",false);var event=InputEventKey.new();event.pressed=true;event.physical_keycode=KEY_L;p._unhandled_key_input(event)
  check("test_power_key_remains_available",services.preview_homes.get("H02",false)!=was);p._unhandled_key_input(event)
 if "--map117-render" in OS.get_cmdline_user_args():
  w.close_interaction();p.action.cancel();scene.zoom=8;scene.focus=p.global_position+Vector3.UP*.95;scene._update_camera()
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://qa/map117/H02_interior.png")
  if not other_key.is_empty():
   w.request_open(other_key)
   for frame in range(160):
    await get_tree().physics_frame
    if not w.active_id.is_empty():break
   scene.game_ui.personal.visible=true;scene.game_ui.nearby_wanted=true;p.set_hud_open(true);scene.game_ui.show_container(other_key);scene.game_ui.refresh()
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  check("approved_HUD_visible_in_render",scene.game_ui.personal.visible and scene.game_ui.nearby.visible)
  get_viewport().get_texture().get_image().save_png("res://qa/map117/H02_loot_HUD.png")
  w.close_interaction();p.global_position=w.house.home.model.to_global(Vector3(0,.27,-9));scene.zoom=16;scene.focus=p.global_position+Vector3.UP*.95;scene._update_camera()
  await get_tree().process_frame;await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("res://qa/map117/city.png")
 w.close_interaction();p.action.cancel()
 for frame in range(160):
  await get_tree().physics_frame
  if p.session_save._idle():break
 var workshop:String=w.native_to_key.EST05_MEC05;w.house.visit(workshop);await get_tree().physics_frame;p.action.cancel();w.refresh_access()
 var requested=w.request_open(workshop)
 if requested:
  for frame in range(160):
   await get_tree().physics_frame
   if w.searched.has("EST05_MEC05") or w.pending_id.is_empty():break
 check("workshop_search",w.searched.has("EST05_MEC05"))
 var pickup=w.claimed.get("EST05_OBJ_01",{});var pickup_uid:String=pickup.get("uid","")
 if not pickup_uid.is_empty():
  scene.game_ui.quick_pickup(pickup_uid)
  for frame in range(240):
   await get_tree().physics_frame
   if p.bag_inventory.owned(pickup_uid):break
 check("reserved_pickup_removed_after_collect",not pickup_uid.is_empty() and p.bag_inventory.owned(pickup_uid) and w.claimed.EST05_OBJ_01.taken and w.map.pickup_meshes.all(func(mesh):return not mesh.visible))
 w.close_interaction();p.action.cancel()
 for frame in range(160):
  await get_tree().physics_frame
  if p.session_save._idle():break
 check("workshop_pickup_save_load",p.session_save.save() and p.load_condition() and w.claimed.get("EST05_OBJ_01",{}).get("taken",false))
 check("reserved_workshop_item_is_unique",w.allocation.EST05_MEC05.filter(func(row):return row.item=="filtro_oleo").size()==1)
 var old_session=p.session_save.snapshot();old_session.erase("world117");old_session.session81.world=old_session.session81.world.split("|map117|")[0]
 var kept_items=p.bag_inventory.items.duplicate(true);var kept_body=p.body_health.snapshot();var file=FileAccess.open(p.condition_path,FileAccess.WRITE);file.store_string(JSON.stringify(old_session));file.close()
 var migrated=p.load_condition()
 check("legacy_campaign_load_preserves_inventory",migrated and p.bag_inventory.items==kept_items and p.body_health.snapshot()==kept_body and w.house.bindings.keys().all(func(key):return w.searched.get(w.key_to_native[key],false) and w.allocation[w.key_to_native[key]].is_empty()))
 check("legacy_campaign_saves_revised_format",migrated and p.session_save.save() and p.session_save._read(p.condition_path).has("world117"))
 var status="passed" if errors.is_empty() else "failed";DirAccess.make_dir_recursive_absolute("res://qa/map117");FileAccess.open("res://qa/map117/native.json",FileAccess.WRITE).store_string(JSON.stringify({"status":status,"container_count":w.key_to_native.size(),"houses":w.map.manager.homes.size(),"moving_parts":w.map.moving.size(),"checks":checks,"errors":errors},"  "));print("DEMO_MAP117 ",status," ",errors," message=",p.inventory_message)
 for suffix in ["",".bak",".tmp"]:if FileAccess.file_exists(p.condition_path+suffix):DirAccess.remove_absolute(p.condition_path+suffix)
 p.condition_path=path;get_tree().quit(0 if errors.is_empty() else 1)
