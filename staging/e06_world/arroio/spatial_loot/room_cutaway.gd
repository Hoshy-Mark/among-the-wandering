extends RefCounted
## Visual-only room cutaway. Physics and the original shadow caster remain full height.
var copies={}
var low_mesh_cache={}
var cut_height=.62
func update(home:Dictionary,wall:MeshInstance3D,active:bool,target:Node3D,camera:Camera3D,force:bool=false):
 if not is_instance_valid(wall):return
 var cut=false;var floor_y:float=home.rule.floor_local_y
 var room_center=home.model.to_local(target.global_position) if is_instance_valid(target) else Vector3.ZERO
 var room_box=AABB();var has_room=false
 if active and is_instance_valid(target):
  var point:Vector3=home.model.to_local(target.global_position)
  for room in home.rule.rooms:
   var poly=PackedVector2Array()
   for p in room.polygon_xz:poly.append(Vector2(p[0],p[1]))
   if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),poly):
    var lo=Vector3(INF,0,INF);var hi=Vector3(-INF,0,-INF)
    for p in poly:lo=lo.min(Vector3(p.x,0,p.y));hi=hi.max(Vector3(p.x,0,p.y))
    room_box=AABB(lo,hi-lo);room_center=room_box.get_center();has_room=true;break
  for unit in home.rule.get("units",[]):
   var b:Array=unit.bounds
   if point.x>=b[0][0] and point.x<=b[1][0] and point.z>=b[0][2] and point.z<=b[1][2]:floor_y=unit.floor_local_y;break
 if active and is_instance_valid(camera):
  var pose:Transform3D=home.model.global_transform.affine_inverse()*wall.global_transform;var bounds:AABB=pose*wall.mesh.get_aabb();var wcenter=bounds.get_center()
  var view:Vector3=home.model.global_basis.inverse()*(camera.global_position-home.model.to_global(room_center));view.y=0;view=view.normalized()
  var near_side:bool=Vector3(wcenter.x-room_center.x,0,wcenter.z-room_center.z).dot(view)>.05
  var adjacent:bool=has_room and bounds.position.x<=room_box.end.x+.22 and bounds.end.x>=room_box.position.x-.22 and bounds.position.z<=room_box.end.z+.22 and bounds.end.z>=room_box.position.z-.22
  var ray=false
  if is_instance_valid(target):
   var inv:Transform3D=wall.global_transform.affine_inverse();ray=wall.mesh.get_aabb().grow(.025).intersects_segment(inv*camera.global_position,inv*(target.global_position+Vector3.UP*1.1))!=null
  cut=force or (near_side and adjacent) or ray
 var key=wall.get_instance_id()
 if cut and not copies.has(key):
  var low=MeshInstance3D.new();low.name="ReadableWallBase";low.set_meta("keep_individual_visual",true);wall.add_child(low)
  low.mesh=_clipped(home,wall,floor_y+cut_height);low.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for s in low.mesh.get_surface_count():low.set_surface_override_material(s,wall.get_active_material(s))
  copies[key]=low
 wall.visible=true
 wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if cut else wall.get_meta("interior_original_shadow",GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
 if copies.has(key):copies[key].visible=cut
 wall.set_meta("room_cutaway_active",cut)
func _clipped(home:Dictionary,wall:MeshInstance3D,height:float)->ArrayMesh:
 var pose:Transform3D=home.model.global_transform.affine_inverse()*wall.global_transform
 var cache_key=str(wall.mesh.get_instance_id())+str(pose)+str(height)
 if low_mesh_cache.has(cache_key):return low_mesh_cache[cache_key]
 var result=ArrayMesh.new()
 for surface in wall.mesh.get_surface_count():
  var a=wall.mesh.surface_get_arrays(surface);var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL]!=null else PackedVector3Array();var uv:PackedVector2Array=a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array();var ids:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
  if ids.is_empty():
   for n in v.size():ids.append(n)
  var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);var count=0
  for j in range(0,ids.size(),3):
   var polygon=[]
   for k in 3:
    var ix=ids[j+k];polygon.append({"p":v[ix],"n":ns[ix] if ns.size()>ix else Vector3.UP,"uv":uv[ix] if uv.size()>ix else Vector2.ZERO})
   var clipped=[]
   for k in polygon.size():
    var x:Dictionary=polygon[k];var y:Dictionary=polygon[(k+1)%polygon.size()];var dx:float=(pose*x.p).y-height;var dy:float=(pose*y.p).y-height
    if dx<=.00001:clipped.append(x)
    if (dx<0 and dy>0) or (dx>0 and dy<0):
     var t:float=dx/(dx-dy);clipped.append({"p":x.p.lerp(y.p,t),"n":x.n.lerp(y.n,t).normalized(),"uv":x.uv.lerp(y.uv,t)})
   for k in range(1,clipped.size()-1):
    for row in [clipped[0],clipped[k],clipped[k+1]]:tool.set_normal(row.n);tool.set_uv(row.uv);tool.add_vertex(row.p);count+=1
  if count>0:tool.generate_tangents();tool.commit(result)
  else:
   # Keep material/surface indices stable even for a lintel entirely above the cut.
   tool.set_normal(Vector3.UP);tool.set_uv(Vector2.ZERO)
   for k in 3:tool.add_vertex(Vector3.ZERO)
   tool.commit(result)
 low_mesh_cache[cache_key]=result;return result
