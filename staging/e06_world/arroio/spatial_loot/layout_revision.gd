extends RefCounted
const B="res://staging/e06_world/arroio/"
var definitions=JSON.parse_string(FileAccess.get_file_as_string(B+"spatial_loot/layouts.json"))
func _point(p:Vector3,anchor:Vector3,factor:float)->Vector3:return anchor+(p-anchor)*Vector3(factor,1,factor)
func _aabb(a:Array,anchor:Vector3,factor:float)->Array:
 var lo=_point(Vector3(a[0][0],a[0][1],a[0][2]),anchor,factor);var hi=_point(Vector3(a[1][0],a[1][1],a[1][2]),anchor,factor);return [[lo.x,lo.y,lo.z],[hi.x,hi.y,hi.z]]
func expand(city:Node3D,rule:Dictionary,lot:String,building:Node3D,exterior:Node3D,model:Node3D,services:Node3D):
 var row:Dictionary=definitions.houses[lot];var f:float=row.factor_xz;var a=Vector3(row.anchor_xz[0],0,row.anchor_xz[1]);var scale_basis=Basis.from_scale(Vector3(f,1,f));var map=Transform3D(scale_basis,a-scale_basis*a);var worldmap:Transform3D=model.global_transform*map*model.global_transform.affine_inverse();var old_bounds:Array=rule.interior_bounds.duplicate(true)
 var defs={}
 for name in ["furniture_preparation","furniture_preparation_h06_h10","furniture_preparation_h11_h20","furniture_preparation_h21_h30","furniture_preparation_h31_h40"]:defs.merge(JSON.parse_string(FileAccess.get_file_as_string(B+"data/"+name+".json")).lots)
 var furniture={};var moved={}
 for item in defs[lot]:
  var nodes=[];var box:AABB;var first=true
  for name in item.source_meshes:
   var m:MeshInstance3D=model.find_child(name,true,false)
   if m==null:continue
   nodes.append(m);moved[str(m.name)]=true;var b:AABB=(model.global_transform.affine_inverse()*m.global_transform)*m.mesh.get_aabb();box=b if first else box.merge(b);first=false
  if nodes.is_empty():continue
  var center=box.get_center();var goal=_point(center,a,f)
  # Preserve small original wall gaps rather than leaving cabinets floating.
  for room in rule.rooms:
   var p=PackedVector2Array()
   for v in room.polygon_xz:p.append(Vector2(v[0],v[1]))
   if not Geometry2D.is_point_in_polygon(Vector2(center.x,center.z),p):continue
   var lo=Vector2(INF,INF);var hi=Vector2(-INF,-INF)
   for v in p:lo=lo.min(v);hi=hi.max(v)
   for axis in [0,2]:
    var ix=0 if axis==0 else 1;var lowgap:float=box.position[axis]-lo[ix];var highgap:float=hi[ix]-box.end[axis]
    if lowgap>=-.02 and lowgap<.22:goal[axis]=_point(Vector3(lo.x,0,lo.y),a,f)[axis]+lowgap+box.size[axis]*.5
    elif highgap>=-.02 and highgap<.22:goal[axis]=_point(Vector3(hi.x,0,hi.y),a,f)[axis]-highgap-box.size[axis]*.5
   break
  var delta=goal-center
  for m in nodes:m.global_position+=model.global_basis*delta
  furniture[item.id]={"translation":[delta.x,0,delta.z],"scale_preserved":true}
 for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  if not moved.has(str(mesh.name)):mesh.global_transform=worldmap*mesh.global_transform
 # Only the inhabited envelope is enlarged: ovens, sheds, walls and yards stay in place.
 var shell_bounds=AABB(Vector3(old_bounds[0][0],old_bounds[0][1],old_bounds[0][2]),Vector3(old_bounds[1][0]-old_bounds[0][0],old_bounds[1][1]-old_bounds[0][1],old_bounds[1][2]-old_bounds[0][2])).grow(.75)
 for mesh:MeshInstance3D in exterior.find_children("*","MeshInstance3D",true,false):
  var center:Vector3=model.to_local(mesh.global_transform*mesh.mesh.get_aabb().get_center());center.y=clampf(center.y,shell_bounds.position.y,shell_bounds.end.y)
  if shell_bounds.has_point(center):mesh.global_transform=worldmap*mesh.global_transform
 for hinge in building.get_children():
  if not str(hinge.name).begins_with("ReviewDoor_"):continue
  var p:Vector3=model.to_local(hinge.global_position);p.y=clampf(p.y,shell_bounds.position.y,shell_bounds.end.y)
  if shell_bounds.has_point(p):hinge.global_transform=worldmap*hinge.global_transform
 var faces=PackedVector3Array();_collision_faces(exterior,building,faces)
 var old=building.get_node_or_null("BuildingCollision")
 if old!=null and not faces.is_empty():var shape=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces);old.get_child(0).shape=shape
 if old!=null and old.get_child_count()>1:
  print("EXTERIOR_COLLIDERS ",lot," ",old.get_child_count())
  for index in range(1,old.get_child_count()):
   if old.get_child(index) is CollisionShape3D:old.get_child(index).disabled=true
 rule.interior_bounds=_aabb(old_bounds,a,f)
 for room in rule.rooms:
  for p in room.polygon_xz:var q=_point(Vector3(p[0],0,p[1]),a,f);p[0]=q.x;p[1]=q.z
  room.area_m2=float(room.get("area_m2",0))*f*f
 for door in rule.doors:
  var p:Array=door.hinge;var q=_point(Vector3(p[0],p[1],p[2]),a,f);door.hinge=[q.x,q.y,q.z]
  if door.has("width_m"):door.width_m=float(door.width_m)*f
  if door.has("source_bounds"):door.source_bounds=_aabb(door.source_bounds,a,f)
 for unit in rule.get("units",[]):
  unit.bounds=_aabb(unit.bounds,a,f)
  if unit.has("entry_local"):var p:Vector3=_point(Vector3(unit.entry_local[0],0,unit.entry_local[1]),a,f);unit.entry_local=[p.x,p.z]
 if is_instance_valid(services):
  for light in services.definitions.houses[lot].lighting:
   var p:Array=light.lamp_position;var q=_point(Vector3(p[0],p[1],p[2]),a,f);light.lamp_position=[q.x,q.y,q.z]
   if light.switch!=null:p=light.switch.position;q=_point(Vector3(p[0],p[1],p[2]),a,f);light.switch.position=[q.x,q.y,q.z]
 model.set_meta("spatial_revision",row);model.set_meta("rigid_furniture",furniture)

func _collision_faces(node:Node,building:Node3D,faces:PackedVector3Array):
 if str(node.name)=="_StaticRender" or str(node.name).begins_with("NEXT_SOFT_"):return
 if node is MeshInstance3D:
  var pose:Transform3D=building.global_transform.affine_inverse()*node.global_transform
  for vertex in node.mesh.get_faces():faces.append(pose*vertex)
 for child in node.get_children():_collision_faces(child,building,faces)
