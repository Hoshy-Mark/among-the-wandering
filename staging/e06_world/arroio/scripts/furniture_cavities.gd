extends RefCounted
## Reversible inner geometry only. Source files and active circulation proxies stay intact.
static var mesh_cache={}
static var material_cache={}
var cases={}
var stats={"hollow_cases":0,"drawer_boxes":0,"existing_open":0,"sink_fronts_pending":0}
var unit_box=BoxMesh.new()
func _material(home:Dictionary,key:String,color:Color)->StandardMaterial3D:
	if material_cache.has(key):return material_cache[key]
	var result=StandardMaterial3D.new()
	for mesh in home.model.find_children("*","MeshInstance3D",true,false):
		var mat=mesh.get_active_material(0)
		if mat is StandardMaterial3D and mat.resource_name in (["Z2_FURN_METAL_CROMADO","Z2_FURN_METAL_CINZA"] if key=="metal" else ["Z2_FURN_PLASTICO_CREME","Z2_FURN_CERAMICA_BRANCA"]):result=mat.duplicate();break
	result.resource_name="Z2_CAVITY_"+key;result.albedo_color=color;result.roughness=.85
	if key=="glass":result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;result.roughness=.35
	material_cache[key]=result;return result
func _box(lo:Vector3,hi:Vector3)->AABB:return AABB(lo,hi-lo)
func _render(parent:Node3D,name:String,boxes:Array,material:Material,prep:RefCounted,fid:String)->MeshInstance3D:
	var physical_scale=Vector3(parent.global_basis.x.length(),parent.global_basis.y.length(),parent.global_basis.z.length())
	var key=str(boxes)+str(physical_scale)+str(material.get_instance_id())
	if not mesh_cache.has(key):
		var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_material(material)
		var arrays=unit_box.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		# Match the received Z2 furniture UV density: one repeat per .65 metres.
		# Each thin board uses physical planar UVs, never one stretched tile per face.
		for b:AABB in boxes:
			for index in indices:
				var point:Vector3=vertices[index]*b.size+b.get_center();var meters:Vector3=point*physical_scale;var normal:Vector3=normals[index];var uv:Vector2
				if absf(normal.x)>.5:uv=Vector2(meters.z,meters.y)
				elif absf(normal.y)>.5:uv=Vector2(meters.x,meters.z)
				else:uv=Vector2(meters.x,meters.y)
				tool.set_normal(normal);tool.set_uv(uv/.65);tool.add_vertex(point)
		tool.generate_tangents();mesh_cache[key]=tool.commit()
	var node=MeshInstance3D.new();node.name=name;node.mesh=mesh_cache[key];node.material_override=material;
	if str(parent.name)=="DrawerBox":node.set_meta("keep_individual_visual",true)
	node.set_meta("cavity_generated",true);parent.add_child(node);prep.mesh_owners[str(node.name)]=fid;return node
func _shell(bounds:AABB,thickness:Vector3,depth:int,sign_front:float)->Array:
	var a=bounds.position;var b=bounds.end;var width=2-depth;var boxes=[];var lo=a;var hi=b;hi[width]=lo[width]+thickness[width];boxes.append(_box(lo,hi));lo=a;hi=b;lo[width]=hi[width]-thickness[width];boxes.append(_box(lo,hi));lo=a;hi=b;hi.y=lo.y+thickness.y;boxes.append(_box(lo,hi));lo=a;hi=b;lo.y=hi.y-thickness.y;boxes.append(_box(lo,hi));lo=a;hi=b
	if sign_front>0:hi[depth]=lo[depth]+thickness[depth]
	else:lo[depth]=hi[depth]-thickness[depth]
	boxes.append(_box(lo,hi));return boxes
func configure(home:Dictionary,prep:RefCounted):
	for fid in prep.entries:
		var entry:Dictionary=prep.entries[fid];var role:String=entry.definition.role
		if role not in ["wardrobe","fridge","drawer_storage","cabinet_two_drawers","cabinet_three_drawers","sink_cabinet","cabinet_hinged"]:continue
		var movable=[]
		for part in entry.definition.parts:movable.append(part.leaf_mesh);movable.append_array(part.attached_meshes)
		var source:MeshInstance3D;var volume=0.0
		for name in entry.meshes:
			if name in movable:continue
			var mesh:MeshInstance3D=entry.meshes[name];var box=mesh.mesh.get_aabb();var score:float=box.size.x*box.size.y*box.size.z*absf(mesh.global_basis.determinant())
			if score>volume:volume=score;source=mesh
		if source==null:continue
		var size:Vector3=source.mesh.get_aabb().size;var scale:Vector3=Vector3(source.global_basis.x.length(),source.global_basis.y.length(),source.global_basis.z.length());var physical:Vector3=size*scale
		var already_open:bool=role=="cabinet_hinged" or minf(physical.x,physical.z)<.07 or physical.y<.055
		if already_open:
			stats.existing_open+=1;entry.node.set_meta("cavity_stage","existing_open_assembly")
			if role!="cabinet_hinged" and not entry.definition.parts.any(func(p):return p.motion=="slide"):continue
		var frame=Node3D.new();frame.name="CavityFrame";entry.node.add_child(frame);frame.global_transform=source.global_transform*Transform3D(Basis.IDENTITY,source.mesh.get_aabb().get_center())
		if already_open:
			var first:Dictionary=prep.articulations[entry.definition.parts[0].id];frame.global_transform=Transform3D(first.leaf.global_basis.orthonormalized(),home.model.to_global(entry.bounds_model.get_center()));var total:AABB;var first_box=true
			for mesh:MeshInstance3D in entry.meshes.values():
				var fitted:AABB=(frame.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb();total=fitted if first_box else total.merge(fitted);first_box=false
			size=total.size;frame.global_position=frame.to_global(total.get_center());scale=Vector3.ONE
		var outward:Vector3=Vector3.ZERO
		if not entry.definition.parts.is_empty():
			var part:Dictionary=prep.articulations[entry.definition.parts[0].id];outward=part.pivot.get_parent().global_basis*part.outward_local
		else:
			for mesh:MeshInstance3D in entry.meshes.values():
				var b:AABB=(frame.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
				if b.size.y>.35 and minf(b.size.x,b.size.z)<.08 and maxf(b.size.x,b.size.z)>.35:outward=mesh.global_transform*mesh.mesh.get_aabb().get_center()-source.global_transform*source.mesh.get_aabb().get_center();outward.y=0;break
		if outward.length()<.0001:frame.queue_free();continue
		outward=frame.global_basis.inverse()*outward;var depth:int=0 if absf(outward.x)>absf(outward.z) else 2;var width:int=2-depth;var front:float=signf(outward[depth]);var bounds=AABB(-size*.5,size)
		# The original panels overlay the solid body. Set the new case back behind their inner faces.
		var lo:Vector3=bounds.position;var hi:Vector3=bounds.end
		for part in entry.definition.parts:
			var leaf:MeshInstance3D=entry.meshes[part.leaf_mesh];var face:AABB=(frame.global_transform.affine_inverse()*leaf.global_transform)*leaf.mesh.get_aabb();var gap:float=.006/scale[depth]
			if front>0:hi[depth]=minf(hi[depth],face.position[depth]-gap)
			else:lo[depth]=maxf(lo[depth],face.end[depth]+gap)
		bounds=_box(lo,hi)
		var wall_m:float=.035 if role=="fridge" else .018;var thick:Vector3=(Vector3.ONE*wall_m/scale).min(size*.075);var inner=AABB(bounds.position+thick,bounds.size-thick*2);var il=inner.position;var ih=inner.end
		if front>0:ih[depth]=bounds.end[depth]-.003/scale[depth]
		else:il[depth]=bounds.position[depth]+.003/scale[depth]
		inner=_box(il,ih)
		var fixed:Array=[] if already_open else _shell(bounds,thick,depth,front);var material:Material=source.get_active_material(0)
		if not already_open:source.visible=false;source.layers=0;source.set_meta("keep_individual_visual",true);source.set_meta("cavity_body_replaced",true)
		var row={"id":fid,"role":role,"frame":frame,"source":source,"outer":bounds,"inner":inner,"depth_axis":depth,"front_sign":front,"fixed_boxes":[],"generated":[],"drawers":[],"shelves":[],"skipped_drawers":[]};cases[fid]=row
		if not already_open:stats.hollow_cases+=1
		if already_open:
			for name in entry.meshes:
				if name not in movable:
					var mesh:MeshInstance3D=entry.meshes[name];row.fixed_boxes.append((frame.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb())
		row["existing_open_frame"]=already_open
		if role=="wardrobe":
			var shelf_y:float=inner.end.y-minf(.38/scale.y,inner.size.y*.24);var a=inner.position;var b=inner.end;b.y=shelf_y+thick.y*.5;a.y=shelf_y-thick.y*.5;var shelf=_box(a,b);fixed.append(shelf);row.shelves.append(shelf)
			a=inner.position;b=inner.end;a[width]=-thick[width]*.5;b[width]=thick[width]*.5;b.y=shelf_y-thick.y;fixed.append(_box(a,b))
			for fraction in [.25,.50,.75]:
				a=inner.position;b=inner.end;a[width]=thick[width]*.5;a.y=lerpf(inner.position.y,shelf_y,fraction);b.y=a.y+thick.y;var board=_box(a,b);fixed.append(board);row.shelves.append(board)
			var bar=CylinderMesh.new();bar.top_radius=.007;bar.bottom_radius=.007;bar.height=maxf(.02,inner.size[width]*.5-.03/scale[width]);bar.radial_segments=10
			var rod=MeshInstance3D.new();rod.name=str(fid)+"__CAVITY_RAIL";rod.mesh=bar;rod.material_override=_material(home,"metal",Color(.30,.31,.29));frame.add_child(rod);rod.position=inner.get_center();rod.position.y=shelf_y-.13/scale.y;rod.position[width]=(inner.position[width]-thick[width]*.5)*.5
			if width==0:rod.rotation.z=PI*.5
			else:rod.rotation.x=PI*.5
			prep.mesh_owners[str(rod.name)]=fid;row.generated.append(rod)
		elif role=="fridge":
			var split:float=inner.position.y+inner.size.y*.72
			if entry.definition.parts.size()>=2:
				var levels=[]
				for part in entry.definition.parts:
					var leaf:MeshInstance3D=entry.meshes[part.leaf_mesh];levels.append((frame.global_transform.affine_inverse()*leaf.global_transform)*leaf.mesh.get_aabb())
				levels.sort_custom(func(a,b):return a.get_center().y<b.get_center().y);split=(levels[0].end.y+levels[1].position.y)*.5
			split=clampf(split,inner.position.y+inner.size.y*.5,inner.end.y-.18/scale.y)
			row["freezer_split"]=split
			var a=inner.position;var b=inner.end;a.y=split-.015/scale.y;b.y=split+.015/scale.y;var divider=_box(a,b);fixed.append(divider);row.shelves.append(divider)
			var liner:Vector3=Vector3.ONE*.003/scale;var lined=_shell(inner,liner,depth,front);var mesh=_render(frame,str(fid)+"__CAVITY_LINER",lined,_material(home,"liner",Color(.81,.82,.76)),prep,fid);row.generated.append(mesh);row.fixed_boxes.append_array(lined)
			var boards=[]
			for fraction in [.25,.50,.75]:
				a=inner.position+liner*2;b=inner.end-liner*2;a.y=lerpf(inner.position.y+.04/scale.y,split-.04/scale.y,fraction);b.y=a.y+.009/scale.y;var board=_box(a,b);boards.append(board);row.shelves.append(board);row.fixed_boxes.append(board)
			mesh=_render(frame,str(fid)+"__CAVITY_GLASS_SHELVES",boards,_material(home,"glass",Color(.65,.76,.70,.42)),prep,fid);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;row.generated.append(mesh)
		else:
			for part in entry.definition.parts:
				if not prep.articulations.has(part.id):continue
				var item:Dictionary=prep.articulations[part.id]
				if item.definition.motion!="slide":continue
				var leaf:MeshInstance3D=item.leaf;var face:AABB=(frame.global_transform.affine_inverse()*leaf.global_transform)*leaf.mesh.get_aabb();var a=inner.position;var b=inner.end;var gap=Vector3.ONE*.006/scale;a[width]=maxf(a[width],face.position[width]+gap[width]);b[width]=minf(b[width],face.end[width]-gap[width]);a.y=maxf(a.y+gap.y,face.position.y+gap.y);b.y=minf(b.y-gap.y,face.end.y-gap.y);a[depth]+=gap[depth];b[depth]-=gap[depth]
				if already_open:
					for panel:AABB in row.fixed_boxes:
						if panel.size.y<.07 and panel.size[width]>face.size[width]*.7 and panel.size[depth]>inner.size[depth]*.65:
							if panel.get_center().y>face.get_center().y:b.y=minf(b.y,panel.position.y-gap.y)
							else:a.y=maxf(a.y,panel.end.y+gap.y)
						if panel.size[width]<.07 and panel.size.y>face.size.y*.7 and panel.size[depth]>inner.size[depth]*.65:
							if panel.get_center()[width]>face.get_center()[width]:b[width]=minf(b[width],panel.position[width]-gap[width])
							else:a[width]=maxf(a[width],panel.end[width]+gap[width])
				if minf((b-a).x,minf((b-a).y,(b-a).z))<.008:
					row.skipped_drawers.append({"id":part.id,"face":face,"a":a,"b":b,"inner":inner});continue
				var drawer=_box(a,b);var board_t=(Vector3.ONE*.012/scale).min(drawer.size*.15);var pieces=_shell(drawer,board_t,depth,front);pieces.remove_at(3)
				var assembly=Node3D.new();assembly.name="DrawerBox";item.pivot.add_child(assembly);assembly.global_transform=frame.global_transform;var mesh=_render(assembly,str(fid)+"__CAVITY_DRAWER_"+str(row.drawers.size()),pieces,material,prep,fid)
				var future=[]
				for panel:AABB in pieces:
					var node=CollisionShape3D.new();var shape=BoxShape3D.new();var pose:Transform3D=item.pivot.global_transform.affine_inverse()*frame.global_transform;var fitted:AABB=pose*panel;shape.size=fitted.size;node.shape=shape;node.position=fitted.get_center();node.disabled=true;item.proxy.get_parent().add_child(node);future.append(node)
				item.definition.preview_travel_m=minf(.30,drawer.size[depth]*scale[depth]*.78);item.pivot.set_meta("preview_travel_m",item.definition.preview_travel_m);row.drawers.append({"part_id":part.id,"root":assembly,"mesh":mesh,"bounds":drawer,"panels":pieces,"colliders":future,"travel_m":item.definition.preview_travel_m});stats.drawer_boxes+=1
			if role=="sink_cabinet" and not entry.definition.get("sink_front_prepared",false):stats.sink_fronts_pending+=1
		row.fixed_boxes.append_array(fixed)
		if not fixed.is_empty():
			var shell=_render(frame,str(fid)+"__CAVITY_FIXED",fixed,material,prep,fid);row.generated.append(shell)
		frame.reparent(home.model,true);frame.name=str(fid)+"__CavityFrame"
		if frame.global_basis.determinant()<0:frame.set_meta("keep_individual_visual",true)
		var future_body=StaticBody3D.new();future_body.name=str(fid)+"__FutureCaseCollision";future_body.collision_layer=0;future_body.collision_mask=0;home.model.add_child(future_body);var future_panels=[]
		for panel:AABB in row.fixed_boxes:
			var collider=CollisionShape3D.new();var shape=BoxShape3D.new();var model_box:AABB=(home.model.global_transform.affine_inverse()*frame.global_transform)*panel;shape.size=model_box.size;collider.shape=shape;collider.position=model_box.get_center();collider.disabled=true;future_body.add_child(collider);future_panels.append(collider)
		row["future_fixed_colliders"]=future_panels;future_body.set_meta("gameplay_enabled",false)
		var anchor_root:Node3D=entry.node.get_node("CompartmentAnchors")
		var anchors=anchor_root.get_children()
		# Keep received storage IDs; add passive sub-anchors when older contracts only have main.
		for drawer in row.drawers:
			var key:String=str(drawer.part_id).get_file()
			if not anchor_root.has_node(NodePath(key)):
				var anchor=Marker3D.new();anchor.name=key;anchor_root.add_child(anchor);anchor.set_meta("stable_id",str(fid)+"/storage/"+key);anchor.set_meta("capacity_configured",false);anchors.append(anchor)
		for anchor in anchors:
			var envelope:AABB=inner;var anchor_frame:Node3D=frame;var key:String=str(anchor.name)
			for drawer in row.drawers:
				if key==str(drawer.part_id).get_file():envelope=drawer.bounds;anchor_frame=drawer.root;anchor.reparent(drawer.root,true);break
			var point:Vector3=envelope.get_center()
			if role=="fridge":
				var a:Vector3=inner.position;var b:Vector3=inner.end
				if key=="freezer":a.y=float(row.freezer_split)+.02/scale.y
				else:b.y=float(row.freezer_split)-.02/scale.y
				envelope=_box(a,b);point=envelope.get_center()
				if key!="freezer":point.y=lerpf(inner.position.y,float(row.freezer_split),.375)
			elif role=="cabinet_hinged":point.y=lerpf(inner.position.y,inner.end.y,.25)
			elif role=="wardrobe":point[width]=lerpf(inner.position[width],inner.end[width],.25);point.y=lerpf(inner.position.y,inner.end.y,.40)
			anchor.global_position=anchor_frame.to_global(point);anchor.set_meta("cavity_bounds_local",envelope);anchor.set_meta("cavity_frame",anchor_frame.get_path());anchor.set_meta("anchor_only",true);anchor.set_meta("envelope_is_not_capacity",true)
		entry.definition=entry.definition.duplicate(true);entry["cavity"]=row
		entry.node.set_meta("cavity_stage","geometry_prepared_gameplay_disabled");entry.node.set_meta("pending_model_work",["Validate item placement, capacities, gameplay collision activation and persistence"] if role!="sink_cabinet" or entry.definition.get("sink_front_prepared",false) else ["Separate combined sink-cabinet front into real leaves before activation"])
		entry.definition.pending_model_work=entry.node.get_meta("pending_model_work")

