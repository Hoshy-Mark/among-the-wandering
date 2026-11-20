extends RefCounted
## Resolve actual panels before creating pivots; legacy numeric mesh indices are not semantic IDs.
var changes=[]
var issues=[]
var sink_fronts=preload("res://staging/e06_world/arroio/scripts/sink_fronts.gd").new()
func resolve(model:Node3D,source:Dictionary)->Dictionary:
	var definition:Dictionary=sink_fronts.resolve(model,source)
	if definition.role=="sink_cabinet":
		issues.append_array(sink_fronts.issues);sink_fronts.issues.clear();return definition
	if definition.parts.is_empty():return definition
	var role:String=definition.role
	if role not in ["wardrobe","fridge","drawer_storage","cabinet_two_drawers","cabinet_three_drawers","stove"]:return definition
	var boxes={};var nodes={};var max_height=0.0;var low=INF;var high=-INF
	for name in definition.source_meshes:
		var node:MeshInstance3D=model.find_child(str(name),true,false)
		if node==null:continue
		var b:AABB=(model.global_transform.affine_inverse()*node.global_transform)*node.mesh.get_aabb();boxes[name]=b;nodes[name]=node;low=minf(low,b.position.y);high=maxf(high,b.end.y)
	max_height=high-low
	var fronts=[]
	for name in boxes:
		var b:AABB=boxes[name];var thin:float=minf(b.size.x,b.size.z);var wide:float=maxf(b.size.x,b.size.z);var accepted=false
		if role=="wardrobe":accepted=b.size.y>max_height*.60 and thin<.09 and wide>.18
		elif role=="fridge":accepted=b.size.y>.18 and thin<.13 and wide>.20
		elif role=="stove":accepted=b.size.y>.20 and thin<.09 and wide>.22
		else:accepted=b.size.y>.035 and b.size.y<.75 and thin<.10 and thin<wide*.25 and wide>.14 and b.get_center().y>low+.12
		if accepted:fronts.append(name)
	# This received utility unit is an open framed two-door cupboard, not two drawers.
	if definition.id=="H04_FURN_13_utility":
		definition.role="cabinet_hinged"
		fronts=["H04_FURN_13_utility_01","H04_FURN_13_utility_02"]
		for index in range(2):
			definition.parts[index].motion="hinge_y";definition.parts[index].hinge_edge="max" if index==0 else "min"
	if role=="stove" and not fronts.is_empty():
		fronts.sort_custom(func(a,b):return boxes[a].size.y*maxf(boxes[a].size.x,boxes[a].size.z)>boxes[b].size.y*maxf(boxes[b].size.x,boxes[b].size.z))
		fronts=[fronts[0]]
	if fronts.size()!=definition.parts.size():
		issues.append({"id":definition.id,"reason":"panel_count","expected":definition.parts.size(),"candidates":fronts});definition["binding_validation"]="manual_review_required";return definition
	var current_valid=true
	for part in definition.parts:
		if str(part.leaf_mesh) not in fronts:current_valid=false
	var selected=[]
	if current_valid:
		for part in definition.parts:selected.append(str(part.leaf_mesh))
	else:
		fronts.sort_custom(func(a,b):return boxes[a].get_center().y>boxes[b].get_center().y if absf(boxes[a].get_center().y-boxes[b].get_center().y)>.04 else boxes[a].get_center().x<boxes[b].get_center().x)
		selected=fronts.duplicate()
		if definition.role=="cabinet_hinged":selected=["H04_FURN_13_utility_01","H04_FURN_13_utility_02"]
		if role=="fridge" and str(definition.parts[0].id).contains("cooler"):selected.reverse()
	var handles=[]
	for name in boxes:
		if name in fronts:continue
		var b:AABB=boxes[name];var volume:float=b.size.x*b.size.y*b.size.z
		if volume<.003 and maxf(b.size.x,maxf(b.size.y,b.size.z))<.8:handles.append(name)
	var used=[];var changed=false;var rows=[]
	for index in range(definition.parts.size()):
		var part:Dictionary=definition.parts[index];var front:String=selected[index];var best="";var distance=INF
		for name in handles:
			if name in used:continue
			var d:float=boxes[name].get_center().distance_to(boxes[front].get_center())
			var panel:AABB=boxes[front].grow(.08)
			if d<distance and panel.has_point(boxes[name].get_center()):distance=d;best=name
		var attached:Array=[best] if not best.is_empty() and definition.role!="cabinet_hinged" else []
		if role=="stove":
			attached=[]
			for name in boxes:
				if name==front:continue
				var b:AABB=boxes[name];var d:Vector3=(b.get_center()-boxes[front].get_center()).abs()
				if b.size.y>.15 and b.size.y<boxes[front].size.y and minf(b.size.x,b.size.z)<.09 and d.y<.04 and d.x<.04 and d.z<.04:attached.append(name)
		if not best.is_empty():used.append(best)
		if part.leaf_mesh!=front or part.attached_meshes!=attached:
			rows.append({"id":part.id,"old_leaf":part.leaf_mesh,"leaf":front,"old_attached":part.attached_meshes.duplicate(),"attached":attached});changed=true
		part.leaf_mesh=front;part.attached_meshes=attached
	definition["binding_resolved"]=true;definition["binding_validation"]="geometry_panel_checked"
	if changed:changes.append({"furniture_id":definition.id,"parts":rows})
	return definition
