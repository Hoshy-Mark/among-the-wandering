extends "res://staging/e06_world/arroio/loot_pilot/pilot.gd"
## Whole-world staging session. Keeps approved HUD; original five-container save is separate.
var survey=[]
var refresh_clock=0.0
var resolving=false
var resolved_moves={}
var unresolved_mechanics=[]
var fit_reason=""
func _start():
 automated="--qa-spatial-loot" in OS.get_cmdline_user_args() or "--capture-spatial-loot" in OS.get_cmdline_user_args();capture_mode="--capture-spatial-loot" in OS.get_cmdline_user_args();config=JSON.parse_string(FileAccess.get_file_as_string(BASE+"spatial_loot/config.json"))
 await _load_world()
 state=load(BASE+"spatial_loot/world_state.gd").new();var positions={}
 for id in targets:var p:Vector3=targets[id].point;positions[id]=[p.x,p.y,p.z]
 var save="user://arroio_loot_pilot_rev01/world_session.json"
 if automated:save="user://arroio_loot_pilot_rev01/qa_map_"+str(OS.get_process_id())+".json"
 if not state.initialize(config,save,positions,check_access):push_error(state.message);return
 state.changed.connect(_changed);actor.bind(self);_build_ui();ready_state=true;teleport(config.containers[0].id);_changed();pilot_ready.emit()
 if automated:await load(BASE+"qa/audit_spatial_loot.gd").new().run(self,capture_mode)
func _load_world():
 config=JSON.parse_string(FileAccess.get_file_as_string(BASE+"spatial_loot/config.json"));survey.clear();resolved_moves.clear();unresolved_mechanics.clear()
 ready_state=false;moving.clear();targets.clear();pickup_meshes.clear();pickup_shape=null
 if is_instance_valid(city):city.free()
 if is_instance_valid(camera):camera.free()
 city=load(BASE+"scenes/arroio_reconstruction.tscn").instantiate();city.get_node("InspectionCamera").set_script(null);city.set_meta("spatial_revision_enabled",true)
 if automated and not "--full-world" in OS.get_cmdline_user_args():
  # Keep all destinations instantiated; skip expensive peripheral ground dressing in QA.
  for flag in ["show_landscape","show_yard_details","terrain_variation","apply_civic_vegetation","enable_ambience"]:city.set(flag,false)
 add_child(city);await get_tree().process_frame;await get_tree().physics_frame
 manager=city.get_node("ResidentialInteriors");civic=city.get_node("CivicInteriors");var old:Camera3D=city.get_node("InspectionCamera");old.current=false
 camera=Camera3D.new();camera.name="ExplorationCamera";camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12;camera.far=2000;camera.current=true;add_child(camera)
 actor=CharacterBody3D.new();actor.set_script(load(BASE+"loot_pilot/hud_actor.gd"));actor.name="WorldLootWalker";actor.camera=camera;city.add_child(actor);actor.input_enabled=not automated;actor.set_physics_process(not automated)
 manager.review_focus=actor;civic.controller.review_focus=actor
 if city.has_node("Landscape"):city.get_node("Landscape").set_occlusion_target(actor)
 _bind_targets();_setup_pickup();await get_tree().physics_frame
 await _resolve_mechanics()
 if not "--skip-calibration" in OS.get_cmdline_user_args():await _calibrate_stances()
 print("WORLD_BOUND ",targets.size())
func _bind_targets():
 var activated={};var retained=[]
 for row in config.containers:
  if row.kind=="residential":
   var home:Dictionary=manager.homes[row.site];var prep:RefCounted=home.preparation;var entry:Dictionary=prep.entries[row.owner];var box:AABB=entry.bounds_model;var center=box.get_center();var normal=Vector3.ZERO
   if row.parts.is_empty() and not entry.definition.parts.is_empty():
    row.parts=[]
    for part in entry.definition.parts:row.parts.append(part.id)
   if not row.parts.is_empty():
    var first:Dictionary=prep.articulations[row.parts[0]];normal=(first.pivot.get_parent().global_basis*first.outward_local).normalized();center.y=home.model.to_local(first.leaf.global_transform*first.leaf.mesh.get_aabb().get_center()).y
   else:
    var room_center=Vector3.ZERO;var best=INF
    for room in home.rule.rooms:
     var c=Vector3.ZERO
     for p in room.polygon_xz:c+=Vector3(p[0],0,p[1])
     c/=room.polygon_xz.size();var distance=Vector2(c.x-center.x,c.z-center.z).length()
     if distance<best:best=distance;room_center=c
    normal=home.model.global_basis*(room_center-center);normal.y=0
    if absf(normal.x)>absf(normal.z):normal=Vector3(signf(normal.x),0,0)
    else:normal=Vector3(0,0,signf(normal.z))
    var back_score=0.0
    for mesh in entry.meshes.values():
     var b:AABB=(home.model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb();var score:float=b.size.y*maxf(b.size.x,b.size.z)
     if b.size.y>.35 and minf(b.size.x,b.size.z)<.08 and score>back_score:
      var candidate:Vector3=center-b.get_center();candidate.y=0
      if candidate.length()>.03:
       var axis=0 if b.size.x<b.size.z else 2;var facing=Vector3.ZERO;facing[axis]=signf(candidate[axis])
       if facing.length()>.5:normal=home.model.global_basis*facing;back_score=score
   var ln:Vector3=home.model.global_basis.inverse()*normal;var depth:float=absf(ln.x)*box.size.x*.5+absf(ln.z)*box.size.z*.5;center+=ln*(depth+.07);center.y=clampf(center.y,.15,2.0)
   var point:Vector3=home.model.to_global(center)
   if not row.parts.is_empty():
    var leaf:MeshInstance3D=prep.articulations[row.parts[0]].leaf;point=leaf.global_transform*leaf.mesh.get_aabb().get_center()+normal*.20
   var stance:Vector3=point+normal*.85;stance.y=home.model.to_global(Vector3(0,home.rule.floor_local_y+.035,0)).y
   targets[row.id]={"row":row,"point":point,"normal":normal,"stance":stance,"home":home,"owner":row.owner};retained.append(row)
   if not row.parts.is_empty() and not activated.has(row.owner):
    if prep.cavities.cases.has(row.owner):_activate_owner(home,row.owner)
    activated[row.owner]=true
   for part in row.parts:moving[part]={"prep":prep,"item":prep.articulations[part],"current":0.0,"goal":0.0,"container":row.id}
  else:
   if not civic.controller.homes.has(row.site):continue
   var h:Dictionary=civic.controller.homes[row.site];var source:Dictionary=row.source_contract;var point=Vector3.ZERO;var stance=Vector3.ZERO;var valid=false
   if source.has("ponto_visual_xyz_local_m"):
    var p:Array=source.ponto_visual_xyz_local_m;point=h.model.to_global(Vector3(p[0],p[1]+.05,p[2]));p=source.ponto_interacao_xz_local_m;stance=h.model.to_global(Vector3(p[0],h.rule.floor_local_y+.035,p[1]));valid=true
   else:
    var owner=row.owner;var meshes=h.model.find_children(str(owner)+"*","MeshInstance3D",true,false)
    if not meshes.is_empty():
     var box:AABB;var first=true
     for mesh in meshes:var b:AABB=(h.model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb();box=b if first else box.merge(b);first=false
     var p=box.get_center();p.y=box.end.y+.04;point=h.model.to_global(p)
     var sp:Array=source.get("player_stance_local_xyz",source.get("initial_interaction_position_xyz",source.get("local_position_xyz",[p.x,0,p.z+1])))
     stance=h.model.to_global(Vector3(sp[0],h.rule.floor_local_y+.035,sp[2]));valid=true
   if not valid:survey.append({"id":row.id,"status":"missing_target_mesh"});continue
   var normal:Vector3=stance-point;normal.y=0;normal=normal.normalized()
   targets[row.id]={"row":row,"point":point,"normal":normal,"stance":stance,"home":h,"owner":row.owner};retained.append(row)
 config.containers=retained
 _survey_open_surfaces()
func _survey_open_surfaces():
 # Survey only open shelves and work surfaces, never invent an opening inside a solid cabinet.
 var roots={}
 for id in civic.controller.homes:roots[id]=civic.controller.homes[id].model
 for node in city.get_children():
  if str(node.name).begins_with("LRP") or str(node.name).begins_with("Rural") or str(node.name).begins_with("Lake"):roots[str(node.name)]=node
 var dressing=city.get_node_or_null("UrbanDressing")
 if dressing!=null:
  for sector in dressing.get_children():
   for node in sector.get_children():
    if str(node.name).begins_with("EST") and not roots.has(str(node.name)):roots[str(node.name)]=node
 var known_positions=[]
 for t in targets.values():known_positions.append(t.point)
 for site in roots:
  var owner:Node3D=roots[site];var cap=0
  for mesh:MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
   var name:String=str(mesh.name).to_upper()
   if not ("PRATELEIRA" in name or "ESTANTE" in name or "BANCADA" in name or "BALCAO" in name or "WORKBENCH" in name or "SHELF" in name or ("MESA" in name and site in ["EST01","EST02"])):continue
   if "PUXADOR" in name or "PORTA" in name or "FOLHA" in name or "PE_" in name or "LOOT_PICKUP" in name:continue
   var box:AABB=mesh.global_transform*mesh.mesh.get_aabb()
   if maxf(box.size.x,box.size.z)<.5 or box.size.y<.03:continue
   var p=box.get_center();p.y=box.end.y+.05
   if known_positions.any(func(v):return Vector2(v.x,v.z).distance_to(Vector2(p.x,p.z))<1.15):continue
   var id:String=site+"/surface/"+str(owner.get_path_to(mesh)).sha256_text().substr(0,16);var profile="oficina_ferramentas" if site=="EST05" else "farmacia" if site=="EST07" else "escola_armario" if site=="EST08" else "rodoviaria_balcao" if site=="EST09" else "igreja_sacristia" if site=="EST01" else "zeladoria_cemiterio" if site=="EST02" else "mercado" if site=="EST03" else "cabana_pesca" if "LAKE" in site.to_upper() or site=="LRP01" else "galpao"
   if site=="LRP02":profile="prisao_enfermaria" if "ENFERMAR" in name else "prisao_seguranca" if "SEGUR" in name or "GUARDA" in name else "prisao_administracao" if "ADMIN" in name or "BIBLIO" in name else "prisao_manutencao" if "MANUT" in name else "prisao_alojamento"
   elif site=="LRP01":profile="cabana_cozinha" if "COZ" in name else "cabana_pesca"
   elif site in ["C01","C02","C03"]:profile="escritorio"
   var normal=Vector3(0,0,1) if box.size.x>=box.size.z else Vector3(1,0,0);p+=normal*(minf(box.size.x,box.size.z)*.5+.08)
   var stance=p+normal*.9;stance.y=box.position.y+.04
   var h={"instance":owner,"model":owner,"rule":{"floor_local_y":owner.to_local(stance).y,"rooms":[]}}
   var row={"id":id,"site":site,"owner":str(mesh.name),"name":site+" · superfície acessível · "+str(mesh.name),"parts":[],"profile":profile,"grid":[6,4],"excluded":[],"kind":"surveyed_open_surface"}
   targets[id]={"row":row,"point":p,"normal":normal,"stance":stance,"home":h,"owner":str(mesh.name)};config.containers.append(row);config.site_budgets[site]=28;known_positions.append(p);cap+=1;survey.append({"id":id,"status":"surface_search_only","mesh":str(mesh.name)})
func check_access(id:String,operation:String)->String:
 if id.begins_with("@ground:"):return super.check_access(id,operation)
 if not targets.has(id):return "Recipiente indisponível"
 var t:Dictionary=targets[id]
 if not is_instance_valid(t.home.instance) or not t.home.instance.is_inside_tree():return "Área descarregada"
 var point:Vector3=t.get("pickup_point",t.point) if operation=="pickup" else t.point;var flat=actor.global_position-point;flat.y=0
 if flat.length()>1.8:return "Aproxime-se"
 if flat.dot(t.normal)<.03:return "Acesse pela frente"
 if absf(actor.global_position.y-t.stance.y)>.65:return "Outro pavimento"
 var excluded:Array[RID]=[actor.get_rid()]
 if id=="EST05_MEC05" and pickup_shape!=null:excluded.append(pickup_shape.get_parent().get_rid())
 var ray=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.4,point,1,excluded);var hit=get_world_3d().direct_space_state.intersect_ray(ray)
 if not hit.is_empty():
  var own=false
  if t.row.kind=="residential":
   var entry:Dictionary=t.home.preparation.entries[t.row.owner];own=entry.node.is_ancestor_of(hit.collider) or str(hit.collider.name)==str(t.row.owner)+"__FutureCaseCollision"
   if hit.collider.name=="InteriorCollision":
    var shape_owner=hit.collider.shape_owner_get_owner(hit.collider.shape_find_owner(hit.shape));own=str(shape_owner.name)=="Furniture_"+str(t.row.owner)
  if not own:last_access={"target":id,"collider":str(hit.collider.get_path())};return "Obstáculo entre você e o alvo"
 if operation=="search" and not t.row.parts.is_empty():
  if not t.row.parts.any(func(part):return moving[part].current>=.98):return "Abra a porta ou gaveta primeiro"
 return ""
func _process(delta:float):
 if not ready_state:return
 _update_camera();refresh_clock+=delta
 if refresh_clock>.15:
  refresh_clock=0;var id=_nearest()
  if not id.is_empty():focused=id
  if actor.bag_inventory!=null:actor.bag_inventory.refresh_access()
 if hint!=null:hint.text="WASD mover · E abrir · G outra porta · F vasculhar · I inventário · H corpo\n"+str(targets.get(focused,{}).get("row",{}).get("name",""))+" · "+message
func _update_camera():
 var center=actor.global_position+Vector3.UP*.9
 camera.global_position=center+Vector3(12,9.79795897,12);camera.look_at(center)

func sweep(id:String,next:float)->String:
 var hit=super.sweep(id,next)
 if not resolving and not hit.is_empty() and hit=="BuildingCollision":
  var m:Dictionary=moving[id];var t:Dictionary=targets[m.container];var model:Node3D=t.home.model;var box:AABB;var first=true
  for frac in [0.0,.5,1.0]:
   m.prep.set_review_fraction(id,frac);var b:AABB=(model.global_transform.affine_inverse()*m.item.leaf.global_transform)*m.item.leaf.mesh.get_aabb();box=b if first else box.merge(b);first=false
  m.prep.set_review_fraction(id,m.current)
  var names=[]
  for mesh:MeshInstance3D in t.home.building.get_node("Visual").find_children("*","MeshInstance3D",true,false):
   var a:AABB=(model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
   if box.grow(.006).intersects(a):names.append(str(mesh.name))
  m["debug_sources"]=names
 return hit

func _move_furniture(t:Dictionary,delta:Vector3):
 var home:Dictionary=t.home;var entry:Dictionary=home.preparation.entries[t.row.owner]
 for mesh in entry.meshes.values():
  if not entry.node.is_ancestor_of(mesh):mesh.global_position+=delta
 entry.node.global_position+=delta
 var local:Vector3=home.model.global_basis.inverse()*delta;entry.bounds_model.position+=local
 if home.preparation.cavities.cases.has(t.row.owner):
  var fixed=home.preparation.cavities.cases[t.row.owner].future_fixed_colliders
  if not fixed.is_empty():fixed[0].get_parent().position+=local
 var original=home.model.get_node_or_null("InteriorCollision/Furniture_"+str(t.row.owner))
 if original!=null:original.position+=local
 for other in targets.values():
  if other.row.owner==t.row.owner and other.row.site==t.row.site:other.point+=delta;other.stance+=delta
func _body_fits(t:Dictionary)->bool:
 var h:Dictionary=t.home;var e:Dictionary=h.preparation.entries[t.row.owner];var b:AABB=e.bounds_model;var corners=[b.position,Vector3(b.end.x,b.position.y,b.position.z),b.end,Vector3(b.position.x,b.position.y,b.end.z)]
 for c in corners:
  var contained=false
  for room in h.rule.rooms:
   var poly=PackedVector2Array()
   for p in room.polygon_xz:poly.append(Vector2(p[0],p[1]))
   var padded=Geometry2D.offset_polygon(poly,.045)
   if not padded.is_empty() and Geometry2D.is_point_in_polygon(Vector2(c.x,c.z),padded[0]):contained=true;break
  if not contained:fit_reason="room_bounds";return false
 var shape=BoxShape3D.new();shape.size=Vector3(maxf(.02,b.size.x-.02),maxf(.02,b.size.y-.08),maxf(.02,b.size.z-.02));var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(h.model.global_basis,h.model.to_global(b.get_center()+Vector3.UP*.025));query.collision_mask=1;query.margin=0.0
 var excluded:Array[RID]=[]
 for body in e.node.find_children("*","PhysicsBody3D",true,false):excluded.append(body.get_rid())
 if h.preparation.cavities.cases.has(t.row.owner):
  var fixed=h.preparation.cavities.cases[t.row.owner].future_fixed_colliders
  if not fixed.is_empty():excluded.append(fixed[0].get_parent().get_rid())
 query.exclude=excluded
 var contacts=get_world_3d().direct_space_state.intersect_shape(query,32);var hits=[]
 for contact in contacts:
  var own=false
  if contact.collider.name=="InteriorCollision":
   var owner=contact.collider.shape_owner_get_owner(contact.collider.shape_find_owner(contact.shape));own=str(owner.name)=="Furniture_"+str(t.row.owner)
  if not own:hits.append(contact)
 fit_reason="clear" if hits.is_empty() else str(hits[0].collider.name)
 return hits.is_empty()
func _resolve_mechanics():
 resolving=true;var initial_poses={}
 for site in manager.homes:
  for fid in manager.homes[site].preparation.entries:initial_poses[fid]=manager.homes[site].preparation.entries[fid].node.global_transform
 for home in manager.homes.values():city.static_batcher.restore_tree(home.instance)
 var baked_path=BASE+"spatial_loot/furniture_moves.json"
 if FileAccess.file_exists(baked_path):
  var baked:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(baked_path))
  for fid in baked:
   var row:Dictionary=baked[fid];var found=targets.values().filter(func(t):return t.row.owner==fid and t.row.site==row.home)
   if found.is_empty():
    if not manager.homes.has(row.home) or not manager.homes[row.home].preparation.entries.has(fid):continue
    found=[{"row":{"owner":fid,"site":row.home},"home":manager.homes[row.home]}]
   var v:Array=row.world_pivot;_rotate_furniture(found[0],row.yaw_degrees,Vector3(v[0],v[1],v[2]));v=row.world_translation;_move_furniture(found[0],Vector3(v[0],v[1],v[2]));resolved_moves[fid]=row
  await get_tree().physics_frame
 for revision_pass in 3:
  var examined={};unresolved_mechanics.clear();actor.global_position=Vector3(-100,10,-100)
  for t in targets.values():
   if t.row.kind!="residential":continue
   var fid:String=t.row.owner
   if examined.has(fid):continue
   examined[fid]=true;var parts=[]
   for part in t.home.preparation.entries[fid].definition.parts:
    if moving.has(part.id):parts.append(part.id)
   var clear=true
   for part in parts:clear=clear and sweep(part,1.0).is_empty()
   if clear and _stance_available(t):continue
   var applied=false;var center:Vector3=t.home.model.to_global(t.home.preparation.entries[fid].bounds_model.get_center())
   for angle in ([0.0] if "--inspect-only" in OS.get_cmdline_user_args() else [0.0,180.0,90.0,-90.0]):
    if angle!=0:_rotate_furniture(t,angle,center);await get_tree().physics_frame
    var front:Vector3=t.normal;var side=Vector3.UP.cross(front);var candidates=[Vector3.ZERO]
    for f in ([] if "--inspect-only" in OS.get_cmdline_user_args() else [.12,.24,.36,.50,.70,.90,1.10]):
     for offset in [0.0,.2,-.2,.4,-.4,.7,-.7,1.0,-1.0]:candidates.append(front*f+side*offset)
    candidates.sort_custom(func(x,y):return x.length_squared()<y.length_squared())
    for delta in candidates:
     _move_furniture(t,delta);await get_tree().physics_frame
     var accepted=_body_fits(t) and _stance_available(t)
     if accepted:
      for part in parts:
       if not sweep(part,1.0).is_empty():accepted=false;break
     if accepted:
      resolved_moves[fid]={"world_translation":[delta.x,delta.y,delta.z],"world_pivot":[center.x,center.y,center.z],"yaw_degrees":angle,"home":t.row.site};applied=true;break
     _move_furniture(t,-delta);await get_tree().physics_frame
    if applied:break
    if angle!=0:_rotate_furniture(t,-angle,center);await get_tree().physics_frame
   if not applied:unresolved_mechanics.append(fid)
 resolved_moves={}
 for site in manager.homes:
  for fid in manager.homes[site].preparation.entries:
   var pose:Transform3D=manager.homes[site].preparation.entries[fid].node.global_transform;var delta:Transform3D=pose*initial_poses[fid].affine_inverse()
   if not pose.is_equal_approx(initial_poses[fid]):resolved_moves[fid]={"home":site,"world_pivot":[0,0,0],"world_translation":[delta.origin.x,delta.origin.y,delta.origin.z],"yaw_degrees":rad_to_deg(atan2(delta.basis.z.x,delta.basis.z.z))}
 for home in manager.homes.values():city.static_batcher.batch_tree(home.instance)
 resolving=false;print("MECHANICAL_LAYOUT ",resolved_moves.size()," fixes; pending ",unresolved_mechanics)

func _rotate_furniture(t:Dictionary,degrees:float,center:Vector3):
 var h:Dictionary=t.home;var e:Dictionary=h.preparation.entries[t.row.owner];var basis=Basis(Vector3.UP,deg_to_rad(degrees));var pose=Transform3D(basis,center-basis*center)
 for mesh in e.meshes.values():
  if not e.node.is_ancestor_of(mesh):mesh.global_transform=pose*mesh.global_transform
 e.node.global_transform=pose*e.node.global_transform
 if h.preparation.cavities.cases.has(t.row.owner):
  var fixed=h.preparation.cavities.cases[t.row.owner].future_fixed_colliders
  if not fixed.is_empty():fixed[0].get_parent().global_transform=pose*fixed[0].get_parent().global_transform
 var bounds:AABB;var first=true
 for mesh in e.meshes.values():var b:AABB=(h.model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false
 e.bounds_model=bounds
 var proxy=h.model.get_node_or_null("InteriorCollision/Furniture_"+str(t.row.owner))
 if proxy!=null and not proxy.disabled:
  var shape=BoxShape3D.new();shape.size=bounds.size;proxy.shape=shape;proxy.position=bounds.get_center()
 for other in targets.values():
  if other.row.owner==t.row.owner and other.row.site==t.row.site:other.point=pose*other.point;other.stance=pose*other.stance;other.normal=basis*other.normal

func _input(event:InputEvent):
 if ready_state and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
  if manager.services!=null and manager.services.try_handle_key(event,actor):get_viewport().set_input_as_handled();return
  var storage=_nearest();var distance:float=Vector2(actor.global_position.x,actor.global_position.z).distance_to(Vector2(targets[storage].point.x,targets[storage].point.z)) if not storage.is_empty() else INF
  var door_controller:Node3D;var door_distance=minf(1.8,distance)
  for controller in [manager,civic.controller]:
   for home in controller.homes.values():
    for door in home.doors:
     var center:Vector3=door.leaf.global_transform*door.leaf.mesh.get_aabb().get_center();var d:float=Vector2(center.x,center.z).distance_to(Vector2(actor.global_position.x,actor.global_position.z))
     if d<door_distance:door_controller=controller;door_distance=d
  if door_controller!=null:door_controller._unhandled_key_input(event);return
  if storage.is_empty() or targets[storage].row.parts.is_empty():return
 super._input(event)

func _stance_available(t:Dictionary)->bool:
 var h:Dictionary=t.home;var old=actor.global_position;var capsule=CapsuleShape3D.new();capsule.radius=.28;capsule.height=1.7;var side=Vector3.UP.cross(t.normal)
 for distance in [.6,.85,1.1,1.35,1.55]:
  for lateral in [0.0,.35,-.35,.7,-.7,1.0,-1.0]:
   var p:Vector3=t.point+t.normal*distance+side*lateral;p.y=h.model.to_global(Vector3(0,h.rule.floor_local_y+.035,0)).y;var local=h.model.to_local(p);var floor_ok=false
   for room in h.rule.rooms:
    var poly=PackedVector2Array()
    for v in room.polygon_xz:poly.append(Vector2(v[0],v[1]))
    if Geometry2D.is_point_in_polygon(Vector2(local.x,local.z),poly):floor_ok=true;break
   if not floor_ok:continue
   var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.85);query.collision_mask=1;query.margin=.001
   if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
   actor.global_position=p
   if check_access(t.row.id,"open").is_empty():t.stance=p;actor.global_position=old;return true
 actor.global_position=old;return false

func _build_ui():
 super._build_ui()
 for child in ui.get_children():
  if child is HBoxContainer:child.queue_free()
 var navigation=HBoxContainer.new();navigation.theme=hud.theme;navigation.position=Vector2(550,12);ui.add_child(navigation)
 var sites=OptionButton.new();sites.fit_to_longest_item=false;sites.custom_minimum_size.x=90;navigation.add_child(sites)
 var choices=OptionButton.new();choices.fit_to_longest_item=false;choices.custom_minimum_size.x=200;navigation.add_child(choices)
 var groups={}
 for row in config.containers:
  if not groups.has(row.site):groups[row.site]=[]
  groups[row.site].append(row)
 var keys=groups.keys();keys.sort()
 for site in keys:sites.add_item(site)
 var populate=func(index):
  choices.clear()
  for row in groups[keys[index]]:choices.add_item(row.name);choices.set_item_metadata(choices.item_count-1,row.id)
 sites.item_selected.connect(populate);var first=maxi(0,keys.find("H01"));sites.select(first);populate.call(first)
 var go=Button.new();go.text="Ir";go.pressed.connect(func():teleport(str(choices.get_item_metadata(choices.selected))));navigation.add_child(go)
 var reload=Button.new();reload.text="Recarregar área";reload.pressed.connect(func():await reload_region());navigation.add_child(reload)
