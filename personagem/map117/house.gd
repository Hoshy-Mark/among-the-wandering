extends "res://personagem/casa71.gd"
var spawn_local117=[]
func setup(owner_scene:Node3D):
 scene=owner_scene;shell=scene.city.get_node("ResidentialInteriors");home=shell.homes.H01;shell.review_focus=scene.player
 var active=scene.player.is_physics_processing();scene.player.set_physics_process(false)
 scene.world_items.attach(self);var model=scene.player.bag_inventory;var map=scene.world_items.map
 for key in scene.world_items.key_to_native:
  var native:String=scene.world_items.key_to_native[key];var t:Dictionary=map.targets[native]
  if t.row.site!="H01":continue
  var fid:String=t.row.owner;bindings[key]=fid
  if not groups.has(fid):
   var entry:Dictionary=home.preparation.entries[fid];var body=home.model.get_node("InteriorCollision")
   if home.preparation.cavities.cases.has(fid):
    var fixed=home.preparation.cavities.cases[fid].future_fixed_colliders
    if not fixed.is_empty():body=fixed[0].get_parent()
   groups[fid]={"role":entry.definition.role,"bounds":entry.bounds_model,"point":t.stance,"front":t.normal,"parts":[],"drawers":{},"body":body,"materials":[],"faded":false}
  for id in t.row.parts:
   var p:Dictionary=home.preparation.articulations[id];p["sign"]=float(p.definition.preview_angle_degrees)/90.0*(-1 if p.edge=="max" else 1)
   if not groups[fid].parts.has(p):groups[fid].parts.append(p)
  groups[fid].drawers[key]={"fraction":0.0,"native":native}
 await get_tree().physics_frame
 var raw=Vector3(1.73,.29,.2);var layout:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORLD+"spatial_loot/layouts.json")).houses.H01;raw.x=layout.anchor_xz[0]+(raw.x-layout.anchor_xz[0])*layout.factor_xz;raw.z=layout.anchor_xz[1]+(raw.z-layout.anchor_xz[1])*layout.factor_xz
 var point=home.model.to_global(raw)
 if not standing_clear(point-Vector3.UP*.02):
  for key in bindings:
   var t:Dictionary=map.targets[scene.world_items.key_to_native[key]]
   if map._stance_available(t) and standing_clear(t.stance):point=t.stance+Vector3.UP*.02;break
 var local=home.model.to_local(point);spawn_local117=[local.x,local.y,local.z];scene.player.global_position=point;scene.player.set_physics_process(active);sync_parts()
func sync_parts():
 for fid in groups:
  for key in groups[fid].drawers:groups[fid].drawers[key].fraction=float(scene.world_items.progress.get(key,0))
func _drawer_pose(part:Dictionary,fraction:float)->Transform3D:return Transform3D.IDENTITY
func _process(_delta:float):pass
func visit(id:String):
 if not scene.world_items.is_map_key(id):return
 var map=scene.world_items.map;var t:Dictionary=map.targets[scene.world_items.key_to_native[id]]
 map._stance_available(t);scene.world_items.close_interaction();scene.player.global_position=t.stance+Vector3.UP*.02;scene.player.velocity=Vector3.ZERO;scene.player.update_nearby()
func visit_next():
 var keys=bindings.keys();visit(keys[visit_index%keys.size()]);visit_index+=1
func clear_to_open(id:String)->bool:
 for part in scene.world_items.map.targets[scene.world_items.key_to_native[id]].row.parts:
  if not scene.world_items.map.sweep(part,1.0).is_empty():return false
 return true
