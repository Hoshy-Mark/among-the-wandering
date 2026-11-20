extends Node3D
## Isolated civic staging adapter. No inventory, loot rolls, pickup or save operations.
const BASE="res://staging/e06_world/arroio/"
var city:Node3D
var controller:Node3D
var records={}
var hidden_sources=[]
var disabled_colliders=[]
var base_instances={}
var upper_meshes=[]
var source_state={}
var ground_cut_active=false
var roof_material_bindings=[]
var roof_materials_bound=false
func frame_from_rows(a:Array)->Transform3D:
	return Transform3D(Basis(Vector3(a[0][0],a[1][0],a[2][0]),Vector3(a[0][1],a[1][1],a[2][1]),Vector3(a[0][2],a[1][2],a[2][2])),Vector3(a[0][3],a[1][3],a[2][3]))
func configure(c:Node3D):
	city=c;controller=preload("res://staging/e06_world/arroio/scripts/civic_door_controller.gd").new();controller.name="CivicDoorAndOcclusionController";controller.city=city;controller.process_priority=-10;add_child(controller)
	var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/civic_interiors_return.json"))
	for id in definitions.sites:
		var rule:Dictionary=definitions.sites[id];records[id]=rule
		if not rule.has("model"):continue
		var site:Dictionary=rule.source_definition;var owner:Node3D=city.get_node("UrbanDressing/"+str(site.sector)+"/"+str(id)+("_Civic" if str(id).begins_with("C") else ""))
		city.static_batcher.restore_tree(owner)
		var original_nodes:Array=[];var by_name={}
		for node in owner.find_children("*","MeshInstance3D",true,false):
			if node.get_meta("vegetation_replaced",false):continue
			original_nodes.append(node);by_name[str(node.name)]=node;_remember(node)
		var model=Node3D.new();model.name="CivicInterior_"+str(id);owner.add_child(model);model.global_transform=frame_from_rows(rule.frame_to_world);base_instances[id]=model
		if str(id).begins_with("C"):
			# Procedural shells are batched MultiMesh instances in world coordinates.
			# Expand a reversible copy so individual leaves and walls can be controlled.
			var source:Node3D=load(BASE+"assets/civic_interiors_return_rev01/"+str(id)+"_source.glb").instantiate();model.add_child(source)
			for mesh in source.find_children("*","MeshInstance3D",true,false):
				original_nodes.append(mesh);by_name[str(mesh.name)]=mesh
				var palette_source=owner.get_node_or_null(str(mesh.name).split("_instance_")[0])
				if palette_source is MultiMeshInstance3D:mesh.material_override=palette_source.material_override
			for node in owner.get_children():
				if node is MultiMeshInstance3D:source_state[node]={"visible":node.visible};node.visible=false
		var addition:Node3D=load(rule.model).instantiate();addition.name="Revision";model.add_child(addition)
		if id=="EST01":roof_material_bindings.append({"source":by_name.get("ANEXO_TELHADO_AGUA_UNICA_COMPLETA"),"target":addition.find_child("ADAPT_EST01_NEW_ANNEX_ROOF_FROM_ORIGINAL",true,false)})
		for name in rule.hide_original_meshes:
			var mesh:MeshInstance3D=by_name.get(name)
			if mesh==null:push_error("Missing source mesh to replace "+str(id)+"/"+str(name));continue
			_remember(mesh);mesh.visible=false;mesh.set_meta("keep_individual_visual",true);mesh.set_meta("civic_replaced",true);hidden_sources.append(mesh)
		var home={"rule":rule.duplicate(true),"building":owner,"instance":model,"model":model,"roofs":[],"walls":[],"doors":[],"inside":false,"expected_world_transform":frame_from_rows(rule.frame_to_world)}
		var low=Vector3(INF,INF,INF);var high=Vector3(-INF,-INF,-INF)
		for u in rule.units:
			var a:Array=u.bounds[0];var b:Array=u.bounds[1];low=low.min(Vector3(a[0],a[1],a[2]));high=high.max(Vector3(b[0],b[1],b[2]))
		home.rule.interior_bounds=[[low.x,low.y,low.z],[high.x,high.y,high.z]];home.rule.exterior_rule={"door_xz":[0,0],"gate_center":[0,0],"front_vector":[0,1],"front_direction":1,"sector":site.sector}
		for room in home.rule.rooms:room["access_mode"]="enter_region"
		for u in home.rule.units:
			var e:Array=u.entry_local;var w:Vector3=model.to_global(Vector3(e[0],u.floor_local_y,e[1]));u["entry_world"]=[w.x,w.z]
			var b:Array=u.bounds;var center:Vector2=Vector2((float(b[0][0])+float(b[1][0]))/2,(float(b[0][2])+float(b[1][2]))/2);var delta=Vector2(e[0],e[1])-center;var outward:Vector3=Vector3(signf(delta.x),0,0) if absf(delta.x)>absf(delta.y) else Vector3(0,0,signf(delta.y));var n:Vector3=model.global_basis*outward;u["front_vector"]=[n.x,n.z];u["approach_world"]=[w.x+n.x*1.0,w.z+n.z*1.0]
		controller.homes[id]=home
		# Bind existing leaf nodes without duplicating them; originals stay byte-identical on disk.
		for definition in rule.doors:
			var mesh:MeshInstance3D=model.find_child(definition.mesh_name,true,false)
			if definition.scope=="original":
				mesh=by_name.get(definition.mesh_name)
				if mesh!=null:_remember(mesh);mesh.reparent(model,true)
				for name in definition.attached_meshes:
					var attached:MeshInstance3D=by_name.get(name)
					if attached!=null:_remember(attached);attached.reparent(model,true)
			if mesh==null:push_error("Civic leaf missing "+str(id)+"/"+str(definition.mesh_name));continue
			controller._install_door(home,definition);home.doors[-1].exterior=definition.scope=="original"
		for node in original_nodes+addition.find_children("*","MeshInstance3D",true,false):
			if node.get_meta("civic_replaced",false) or node.get_meta("interior_door_leaf",false) or node.get_meta("interior_door_handle",false):continue
			var title:String=str(node.name).to_upper();var pose:Transform3D=model.global_transform.affine_inverse()*node.global_transform;var a:AABB=pose*node.mesh.get_aabb();var top:float=a.end.y;var bottom:float=a.position.y
			var is_roof:bool="TELHA" in title or "COBERT" in title or "FORRO" in title or "ROOF" in title or "EAVES" in title or "_AGUA_" in title or "CUMEEIRA" in title or "EMPENA" in title or "CALHA" in title or "RUFO" in title or "MARQUISE" in title or "TESOURA" in title or "TIRANTE" in title or (title.begins_with("ADAPT_") and a.size.y<.3 and bottom>2.5)
			var is_wall:bool=not is_roof and ("PAREDE" in title or "WALL" in title or "DIVISORIA" in title or "INTERFLOOR" in title or "FACHADA" in title or (a.size.y>1.5 and minf(a.size.x,a.size.z)<.3 and maxf(a.size.x,a.size.z)>1.0) or (title.begins_with("ADAPT_") and a.size.y>1.0))
			if is_roof or is_wall:
				node.set_meta("keep_individual_visual",true);node.set_meta("interior_original_shadow",node.cast_shadow);var unit_id="main"
				if id=="EST01":unit_id="upper" if (bottom>3.8 or "INTERFLOOR" in title) and a.position.x>5.8 else "annex" if a.position.x>5.8 else "nave"
				elif rule.units.size()>1:
					var p=a.get_center()
					for u in rule.units:
						if p.x>=u.bounds[0][0] and p.x<=u.bounds[1][0] and p.z>=u.bounds[0][2] and p.z<=u.bounds[1][2]:unit_id=u.id;break
				node.set_meta("interior_unit",unit_id)
				if is_roof:home.roofs.append(node)
				else:home.walls.append(node)
			if id=="EST01" and (str(node.name).begins_with("U_") or "INTERFLOOR" in title or "EAVES" in title):upper_meshes.append({"node":node,"shadow":node.cast_shadow})
		# Replace the legacy solid proxy only; independent ramps and gate collisions remain.
		for name in ["BuildingCollision","DressingCollision"]:
			var body=owner.get_node_or_null(name)
			if body!=null:
				for shape in body.find_children("*","CollisionShape3D",true,false):disabled_colliders.append({"node":shape,"disabled":shape.disabled});shape.disabled=true
		var body=StaticBody3D.new();body.name="CivicInteriorCollision";model.add_child(body);var faces=PackedVector3Array()
		for mesh in original_nodes+addition.find_children("*","MeshInstance3D",true,false):
			if mesh.get_meta("civic_replaced",false) or mesh.get_meta("vegetation_replaced",false) or mesh.get_meta("interior_door_leaf",false) or mesh.get_meta("interior_door_handle",false):continue
			var title:String=str(mesh.name)
			if title in rule.collision_excluded_new_meshes or title.begins_with("EST_SOFT_"):continue
			if title in site.get("collision_excluded_meshes",[]):continue
			if "ESCADA_ENTRADA_DEGRAU" in title or "R05_DEGRAU_BOLEADO" in title:continue
			var pose:Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
			var mesh_faces=PackedVector3Array()
			for vertex in mesh.mesh.get_faces():mesh_faces.append(pose*vertex)
			if OS.get_cmdline_user_args().has("--collision-debug"):
				var mb=StaticBody3D.new();mb.name=str(mesh.name)+"_DebugCollider";model.add_child(mb);var cs=CollisionShape3D.new();var sh=ConcavePolygonShape3D.new();sh.set_faces(mesh_faces);cs.shape=sh;mb.add_child(cs)
			else:faces.append_array(mesh_faces)
		var shape=ConcavePolygonShape3D.new();if not faces.is_empty():shape.set_faces(faces)
		var collision=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
		for ramp in rule.get("stair_ramps",[]):_ramp(model,ramp)
		for b in rule.get("extra_support_boxes",[]):_box_support(model,b)
		for u in rule.units:
			if not u.independent_entry:continue
			var e:Array=u.entry_local;var bounds:Array=u.bounds;var cx:float=(float(bounds[0][0])+float(bounds[1][0]))/2;var cz:float=(float(bounds[0][2])+float(bounds[1][2]))/2;var axis:=0 if absf(float(e[0])-cx)>absf(float(e[1])-cz) else 2;var direction:=signf(float(e[0])-cx) if axis==0 else signf(float(e[1])-cz)
			var ramp={"axis":axis,"center":e,"width":1.25,"start":float(e[0 if axis==0 else 1])+direction*1.35,"end":float(e[0 if axis==0 else 1])+direction*.10,"y_start":.025,"y_end":float(u.get("entry_floor_y",u.floor_local_y))+.005};_entry_ramp(model,ramp)
		var prep=Node3D.new();prep.name="LootPreparation_DISABLED";prep.set_meta("gameplay_enabled",false);prep.set_meta("source_search_points",rule.loot_preparation.search_points);prep.set_meta("source_pickups",rule.loot_preparation.pickups);prep.set_meta("ledger_executed",false);model.add_child(prep)
		for category in ["search_points","pickups"]:
			for record in rule.loot_preparation[category]:
				var marker=Marker3D.new();marker.name=str(record.get("id","PreparedPoint"));marker.set_meta("enabled",false);marker.set_meta("category",category);marker.set_meta("source_contract",record);marker.set_meta("interaction_validation","pending_future_functional_pass")
				var xyz=record.get("initial_interaction_position_xyz",record.get("local_position_xyz",record.get("player_stance_local_xyz",record.get("local_xyz",record.get("posicao_xyz_local_m",[])))))
				if xyz.is_empty() and record.has("ponto_interacao_xz_local_m"):var xz=record.ponto_interacao_xz_local_m;xyz=[xz[0],rule.floor_local_y,xz[1]]
				if xyz.size()==3:marker.position=Vector3(xyz[0],xyz[1],xyz[2])
				prep.add_child(marker)
	set_meta("integration_count",controller.homes.size());set_meta("loot_gameplay_enabled",false)
func _box_support(model:Node3D,b:Dictionary):
	var a:Array=b.min;var z:Array=b.max;var lo=Vector3(a[0],a[1],a[2]);var hi=Vector3(z[0],z[1],z[2]);var body=StaticBody3D.new();model.add_child(body);var node=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=hi-lo;node.shape=shape;node.position=(lo+hi)/2;body.add_child(node)
func _ramp(model:Node3D,r:Dictionary):
	var body=StaticBody3D.new();body.name="StairSlopeProxy";model.add_child(body);var points=PackedVector3Array();var low:float=minf(r.y_start,r.y_end)-.2
	for x in r.x:
		for row in [[r.z_start,r.y_start],[r.z_end,r.y_end]]:points.append(Vector3(x,row[1],row[0]));points.append(Vector3(x,low,row[0]))
	var shape=ConvexPolygonShape3D.new();shape.points=points;var node=CollisionShape3D.new();node.shape=shape;body.add_child(node)
func _entry_ramp(model:Node3D,r:Dictionary):
	var body=StaticBody3D.new();body.name="EntranceSlopeProxy";model.add_child(body);var points=PackedVector3Array()
	for width in [-float(r.width)/2,float(r.width)/2]:
		for p in [[r.start,r.y_start],[r.end,r.y_end]]:
			var v=Vector3(p[0],p[1],float(r.center[1])+width) if int(r.axis)==0 else Vector3(float(r.center[0])+width,p[1],p[0]);points.append(v);v.y=-.15;points.append(v)
	var shape=ConvexPolygonShape3D.new();shape.points=points;var node=CollisionShape3D.new();node.shape=shape;body.add_child(node)
func _process(_delta):
	if controller==null:return
	if not roof_materials_bound and city.ready_for_integration:
		for binding in roof_material_bindings:
			if is_instance_valid(binding.source) and is_instance_valid(binding.target):
				for surface in binding.target.mesh.get_surface_count():binding.target.set_surface_override_material(surface,binding.source.get_active_material(mini(surface,binding.source.mesh.get_surface_count()-1)))
		roof_materials_bound=true
	var target:Node3D=controller._observer()
	if not is_instance_valid(target):return
	if controller.homes.has("EST01"):
		var home:Dictionary=controller.homes.EST01;var local:Vector3=home.model.to_local(target.global_position);var inside:bool=controller.contains_point("EST01",target.global_position) or controller.forced_home=="EST01";var ground:bool=inside and local.y<3.4
		for row in upper_meshes:
			if is_instance_valid(row.node):
				if ground:row.node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				elif ground_cut_active:row.node.cast_shadow=row.shadow
		if ground_cut_active and not ground:controller._process(0)
		ground_cut_active=ground
func _remember(node:MeshInstance3D):
	if source_state.has(node):return
	for model in base_instances.values():
		if model.is_ancestor_of(node):return
	var metadata={}
	for key in ["keep_individual_visual","civic_replaced","interior_door_leaf","interior_door_handle","interior_original_shadow","interior_unit"]:
		if node.has_meta(key):metadata[key]=node.get_meta(key)
	source_state[node]={"parent":node.get_parent(),"transform":node.transform,"visible":node.visible,"shadow":node.cast_shadow,"layers":node.layers,"metadata":metadata}
func rollback():
	for row in disabled_colliders:
		if is_instance_valid(row.node):row.node.disabled=row.disabled
	for node in source_state:
		if not is_instance_valid(node):continue
		var state:Dictionary=source_state[node]
		if state.has("parent") and is_instance_valid(state.parent):node.reparent(state.parent);node.transform=state.transform
		if state.has("visible"):node.visible=state.visible
		if state.has("shadow"):
			node.cast_shadow=state.shadow;node.layers=state.layers
			for key in ["keep_individual_visual","civic_replaced","interior_door_leaf","interior_door_handle","interior_original_shadow","interior_unit"]:
				if state.metadata.has(key):node.set_meta(key,state.metadata[key])
				elif node.has_meta(key):node.remove_meta(key)
	for model in base_instances.values():
		if is_instance_valid(model):model.queue_free()
	if controller!=null:controller.homes.clear();controller._process(0)
