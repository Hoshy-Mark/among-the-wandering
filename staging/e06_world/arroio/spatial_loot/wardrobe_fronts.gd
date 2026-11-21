extends RefCounted
## Correct sideways wardrobe fronts in staging instances, retaining source files and Z2 materials.
const B="res://staging/e06_world/arroio/"
func apply(model:Node3D,rule:Dictionary,lot:String):
 var definitions={}
 for tag in ["","_h06_h10","_h11_h20","_h21_h30","_h31_h40"]:definitions.merge(JSON.parse_string(FileAccess.get_file_as_string(B+"data/furniture_preparation"+tag+".json")).lots)
 var resolver=load(B+"scripts/furniture_part_resolver.gd").new();var fixed=[];var hinges={}
 for original in definitions[lot]:
  if original.role!="wardrobe":continue
  var definition:Dictionary=resolver.resolve(model,original);var source:MeshInstance3D;var volume=0.0;var panels=[];var names=[]
  for part in definition.parts:names.append(part.leaf_mesh)
  for name in definition.source_meshes:
   var mesh:MeshInstance3D=model.find_child(name,true,false)
   if mesh==null or name in names:continue
   var box:AABB=(model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb();var score=box.size.x*box.size.y*box.size.z
   if score>volume:volume=score;source=mesh
  if source==null:continue
  var body:AABB=(model.global_transform.affine_inverse()*source.global_transform)*source.mesh.get_aabb();var width=0 if body.size.x>=body.size.z else 2;var depth=2-width;var bad=false
  for name in names:
   var mesh:MeshInstance3D=model.find_child(name,true,false);var box:AABB=(model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
   if box.size[width]<body.size[width]*.34 or box.size[depth]>box.size[width]:bad=true
  var center=body.get_center();var roomcenter=center
  for room in rule.rooms:
   var polygon=PackedVector2Array();var c=Vector3.ZERO
   for p in room.polygon_xz:polygon.append(Vector2(p[0],p[1]));c+=Vector3(p[0],0,p[1])
   if Geometry2D.is_point_in_polygon(Vector2(center.x,center.z),polygon):roomcenter=c/room.polygon_xz.size();break
  var sign_front=signf(roomcenter[depth]-center[depth]);if sign_front==0:sign_front=1
  var panel_center=0.0
  for name in names:
   var mesh:MeshInstance3D=model.find_child(name,true,false);panel_center+=model.to_local(mesh.global_transform*mesh.mesh.get_aabb().get_center())[depth]
  panel_center/=maxi(1,names.size())
  if (panel_center-center[depth])*sign_front<-.02:bad=true
  if not bad:continue
  var normal=Vector3.ZERO;normal[depth]=sign_front;var tangent=Vector3.RIGHT if width==0 else Vector3.BACK;var basis=Basis(tangent,Vector3.UP,tangent.cross(Vector3.UP));var panel_width=(body.size[width]-.045)/2;var panel_height=body.size.y-.045
  for index in names.size():
   hinges[definition.parts[index].id]="min" if index==0 else "max"
   var mesh:MeshInstance3D=model.find_child(names[index],true,false);var material=mesh.get_active_material(0);var panel=BoxMesh.new();panel.size=Vector3(panel_width-.008,panel_height,.026);var p=center;p[width]=body.position[width]+.0225+panel_width*(index+.5);p[depth]=body.get_center()[depth]+sign_front*(body.size[depth]*.5+.014)
   mesh.mesh=panel;mesh.material_override=material;mesh.global_transform=model.global_transform*Transform3D(basis,p)
   for name in definition.parts[index].attached_meshes:
    var handle:MeshInstance3D=model.find_child(name,true,false)
    if handle!=null:var hp=p;hp[width]+=(1 if index==0 else -1)*panel_width*.30;hp+=normal*.035;handle.global_position=model.to_global(hp)
  fixed.append(definition.id)
 model.set_meta("wardrobe_fronts_corrected",fixed);model.set_meta("wardrobe_hinges",hinges)
