extends RefCounted
## Split the received box panel in runtime; retain source assets and cropped UVs.
static var meshes={}
static var handle_meshes={}
var issues=[]
var generated=[]
func _half(source:Mesh,low:float,high:float,width:int)->ArrayMesh:
	var key=str(source.get_instance_id())+str(low)+str(high)+str(width)
	if meshes.has(key):return meshes[key]
	var b=source.get_aabb();var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arrays=source.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals=arrays[Mesh.ARRAY_NORMAL];var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for k in range(0,indices.size(),3):
		var gradient=Vector2.ZERO
		var face_normal:Vector3=(vertices[indices[k+2]]-vertices[indices[k]]).cross(vertices[indices[k+1]]-vertices[indices[k]]).normalized()
		for i in range(3):
			for j in range(i+1,3):
				var ia=indices[k+i];var ib=indices[k+j];var delta:Vector3=vertices[ib]-vertices[ia]
				if absf(delta[width])>.00001 and absf(delta.y)<.00001 and absf(delta[2-width])<.00001:gradient=(uvs[ib]-uvs[ia])/delta[width]
		for i in range(3):
			var index=indices[k+i];var point:Vector3=vertices[index];var coordinate:float=lerpf(low,high,(point[width]-b.position[width])/b.size[width]);var uv:Vector2=uvs[index]+gradient*(coordinate-point[width]);point[width]=coordinate
			tool.set_normal(normals[index] if normals!=null else face_normal);tool.set_uv(uv);tool.add_vertex(point)
	tool.generate_tangents();meshes[key]=tool.commit();return meshes[key]
func resolve(model:Node3D,source:Dictionary)->Dictionary:
	var d:Dictionary=source.duplicate(true)
	if d.role!="sink_cabinet":return d
	var candidates=[]
	for name in d.source_meshes:
		var node=model.find_child(str(name),true,false) as MeshInstance3D
		if node==null:continue
		var b:AABB=(model.global_transform.affine_inverse()*node.global_transform)*node.mesh.get_aabb()
		if b.size.y>.35 and minf(b.size.x,b.size.z)<.08 and maxf(b.size.x,b.size.z)>.35:candidates.append(node)
	if candidates.is_empty():return d # The open utility sink has no closed front.
	if candidates.size()!=1:issues.append({"id":d.id,"reason":"ambiguous_combined_front"});return d
	var original:MeshInstance3D=candidates[0];var b:AABB=original.mesh.get_aabb()
	if original.mesh.get_surface_count()!=1:issues.append({"id":d.id,"reason":"unsupported_panel_axes"});return d
	var physical_scale=Vector3(original.global_basis.x.length(),original.global_basis.y.length(),original.global_basis.z.length());var width:int=0 if b.size.x>b.size.z else 2;var depth:int=2-width;var middle:float=b.get_center()[width];var gap:float=.002/physical_scale[width]
	var mat:Material=original.get_active_material(0);var metal=StandardMaterial3D.new()
	for name in d.source_meshes:
		var node=model.find_child(str(name),true,false) as MeshInstance3D
		var material=node.get_active_material(0)
		if material is StandardMaterial3D and material.resource_name=="Z2_FURN_METAL_CROMADO":metal=material;break
	if not handle_meshes.has(width):
		var mesh=BoxMesh.new();var size=Vector3(.012,.085,.018);size[width]=.012;size[depth]=.018;mesh.size=size;handle_meshes[width]=mesh
	var total:AABB;var first=true
	for name in d.source_meshes:
		var node=model.find_child(str(name),true,false) as MeshInstance3D;var box:AABB=(model.global_transform.affine_inverse()*node.global_transform)*node.mesh.get_aabb();total=box if first else total.merge(box);first=false
	var front_sign:float=signf((b.get_center()-original.to_local(model.to_global(total.get_center())))[depth])
	d.parts=[];var leaves=[]
	for side in range(2):
		var low:float=b.position[width] if side==0 else middle+gap*.5;var high:float=middle-gap*.5 if side==0 else b.end[width]
		var leaf=MeshInstance3D.new();leaf.name=str(d.id)+("__SINK_LEAF_L" if side==0 else "__SINK_LEAF_R");leaf.mesh=_half(original.mesh,low,high,width);leaf.material_override=mat;model.add_child(leaf);leaf.global_transform=original.global_transform;leaf.set_meta("sink_split_generated",true)
		var handle=MeshInstance3D.new();handle.name=str(d.id)+("__SINK_HANDLE_L" if side==0 else "__SINK_HANDLE_R");handle.mesh=handle_meshes[width];handle.material_override=metal;model.add_child(handle)
		var point=b.get_center();point[width]=high-.035/physical_scale[width] if side==0 else low+.035/physical_scale[width];point.y=b.end.y-.12/physical_scale.y;point[depth]=(b.position[depth] if front_sign<0 else b.end[depth])+front_sign*.010/physical_scale[depth]
		handle.global_transform=Transform3D(original.global_basis.orthonormalized(),original.to_global(point));handle.set_meta("sink_split_generated",true)
		d.source_meshes.append(str(leaf.name));d.source_meshes.append(str(handle.name));leaves.append(str(leaf.name))
		d.parts.append({"id":str(d.id)+("/door_left" if side==0 else "/door_right"),"leaf_mesh":str(leaf.name),"attached_meshes":[str(handle.name)],"motion":"hinge_y","hinge_edge":"opposite_handle","preview_angle_degrees":90.0,"preview_travel_m":0.0,"mechanical_clearance":"pending_native_sweep","collision_enabled":false,"default_fraction":0.0})
	original.visible=false;original.layers=0;original.set_meta("keep_individual_visual",true);original.set_meta("sink_front_replaced",true)
	d.binding_resolved=true;d.binding_validation="split_source_box_panel_checked";d.sink_front_prepared=true;d.pending_model_work=["Activate compound moving collision only with the future furniture controller; storage and loot remain disabled"]
	generated.append({"id":d.id,"source":str(original.name),"leaves":leaves,"gap_m":.002});return d
