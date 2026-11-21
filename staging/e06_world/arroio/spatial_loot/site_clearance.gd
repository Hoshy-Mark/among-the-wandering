extends RefCounted
const PATH="res://staging/e06_world/arroio/spatial_loot/site_clearances.json"
static func adjust(city:Node3D,name:String,data:Variant)->Variant:
 if not city.get_meta("spatial_revision_enabled",false) or name not in ["landscape","environment"]:return data
 var footprints:Array=JSON.parse_string(FileAccess.get_file_as_string(PATH));var trees:Array=data.trees;var moves=[]
 for tree in trees:
  if name=="environment" and not tree.get("enabled",false):continue
  var a:Array=tree.position;var pos=Vector2(a[0],a[1] if a.size()==2 else a[2]);var home={}
  for footprint in footprints:
   var b:Array=footprint.bounds
   if pos.x>=b[0] and pos.y>=b[1] and pos.x<=b[2] and pos.y<=b[3]:home=footprint;break
  if home.is_empty():continue
  var b:Array=home.bounds;var polygon=PackedVector2Array()
  for p in home.parcel:polygon.append(Vector2(p[0],p[1]))
  var candidates=[Vector2(b[0]-.4,pos.y),Vector2(b[2]+.4,pos.y),Vector2(pos.x,b[1]-.4),Vector2(pos.x,b[3]+.4)]
  candidates.sort_custom(func(x,y):return x.distance_squared_to(pos)<y.distance_squared_to(pos));var found=false
  for candidate in candidates:
   if not Geometry2D.is_point_in_polygon(candidate,polygon):continue
   var valid=true
   for other in footprints:
    var rect:Array=other.bounds
    if candidate.x>=rect[0] and candidate.x<=rect[2] and candidate.y>=rect[1] and candidate.y<=rect[3]:valid=false;break
   if not valid:continue
   a[0]=candidate.x;a[1 if a.size()==2 else 2]=candidate.y;moves.append({"home":home.id,"old":[pos.x,pos.y],"new":[candidate.x,candidate.y]});found=true;break
  if not found:moves.append({"home":home.id,"unresolved":true,"old":[pos.x,pos.y]})
 city.set_meta("spatial_tree_moves_"+name,moves)
 return data
