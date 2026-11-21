extends Node3D
## Isolated five-container pilot. The regular map scene has no reference to this controller.
const BASE="res://staging/e06_world/arroio/"
var city:Node3D
var actor:CharacterBody3D
var camera:Camera3D
var manager:Node3D
var civic:Node3D
var config:Dictionary
var state:RefCounted
var targets={}
var moving={}
var pickup_meshes=[]
var pickup_shape:CollisionShape3D
var ui:CanvasLayer
var hud:Control
var feedback:Label
var hint:Label
var focused=""
var selected=""
var ready_state=false
var automated=false
var capture_mode=false
var last_motion={}
var last_access={}
var message=""
signal pilot_ready
func _ready():call_deferred("_start")
func _start():
	automated="--qa-loot" in OS.get_cmdline_user_args() or "--capture-loot" in OS.get_cmdline_user_args();capture_mode="--capture-loot" in OS.get_cmdline_user_args();config=JSON.parse_string(FileAccess.get_file_as_string(BASE+"loot_pilot/config.json"))
	await _load_world()
	state=load(BASE+"loot_pilot/loot_state.gd").new();var positions={}
	for id in targets:var p:Vector3=targets[id].point;positions[id]=[p.x,p.y,p.z]
	var save="user://arroio_loot_pilot_rev01/session.json"
	if automated:save="user://arroio_loot_pilot_rev01/qa_world_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+".json"
	state.initialize(config,save,positions,check_access);state.changed.connect(_changed);actor.bind(self);_build_ui();ready_state=true;teleport(str(config.containers[0].id));_changed();pilot_ready.emit()
	if automated:await load(BASE+"qa/audit_loot_hud_world.gd").new().run(self,capture_mode)
func _load_world():
	ready_state=false;moving.clear();targets.clear();pickup_meshes.clear();pickup_shape=null
	if is_instance_valid(city):city.free()
	if is_instance_valid(camera):camera.free()
	city=load(BASE+"scenes/arroio_reconstruction.tscn").instantiate();city.get_node("InspectionCamera").set_script(null)
	for flag in ["show_landscape","show_yard_details","terrain_variation","apply_civic_vegetation","apply_lrp01","apply_lrp02","apply_rural_models","apply_rural_network","enable_ambience"]:city.set(flag,false)
	add_child(city);await get_tree().process_frame;await get_tree().physics_frame
	manager=city.get_node("ResidentialInteriors");civic=city.get_node("CivicInteriors");var old_camera:Camera3D=city.get_node("InspectionCamera");old_camera.current=false;old_camera.set_process(false);old_camera.set_process_unhandled_input(false)
	camera=Camera3D.new();camera.name="PilotCamera";camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=10;camera.far=300;camera.current=true;add_child(camera)
	actor=CharacterBody3D.new();actor.set_script(load(BASE+"loot_pilot/hud_actor.gd"));actor.name="LootPilotWalker";actor.camera=camera;city.add_child(actor);actor.input_enabled=not automated;actor.set_physics_process(false)
	manager.review_focus=actor;civic.controller.review_focus=actor;manager.set_doors_open("H01",true);civic.controller.set_doors_open("EST05",true)
	_bind_targets();_setup_pickup();await get_tree().physics_frame;await get_tree().physics_frame;await _calibrate_stances();actor.set_physics_process(not automated)
func reload_region():
	if not ready_state:return
	var id=focused
	if is_instance_valid(ui):ui.free()
	hud=null;await _load_world();actor.bind(self);_build_ui();ready_state=true;teleport(id);_changed();message="Área recarregada; conteúdo preservado";refresh()
func _bind_targets():
	var home:Dictionary=manager.homes.H01;var prep:RefCounted=home.preparation;var owners={}
	for row in config.containers:
		if row.site=="H01":
			var entry:Dictionary=prep.entries[row.owner];var item:Dictionary=prep.articulations[row.parts[0]];var normal:Vector3=(item.pivot.get_parent().global_basis*item.outward_local).normalized();var local_normal:Vector3=home.model.global_basis.inverse()*normal;var box:AABB=entry.bounds_model;var local=box.get_center();local.y=home.model.to_local(item.leaf.global_transform*item.leaf.mesh.get_aabb().get_center()).y
			if not item.definition.attached_meshes.is_empty():
				var handle:MeshInstance3D=entry.meshes[item.definition.attached_meshes[0]];local.y=home.model.to_local(handle.global_transform*handle.mesh.get_aabb().get_center()).y
			var distance:float=absf(local_normal.x)*box.size.x*.5+absf(local_normal.z)*box.size.z*.5+.045;local+=local_normal*distance;var point:Vector3=home.model.to_global(local);var stance:Vector3=point+normal*.95;stance.y=home.model.to_global(Vector3(0,home.rule.floor_local_y+.035,0)).y
			targets[row.id]={"row":row,"point":point,"normal":normal,"stance":stance,"home":home,"owner":row.owner}
			if not owners.has(row.owner):_activate_owner(home,str(row.owner));owners[row.owner]=true
			for part in row.parts:
				moving[part]={"prep":prep,"item":prep.articulations[part],"current":0.0,"goal":0.0,"container":row.id}
		else:
			var site:Dictionary=civic.controller.homes.EST05;var record:Dictionary=row.source_contract;var xyz:Array=record.ponto_visual_xyz_local_m;var xz:Array=record.ponto_interacao_xz_local_m;var point:Vector3=site.model.to_global(Vector3(xyz[0],xyz[1]+.05,xyz[2]));var stance:Vector3=site.model.to_global(Vector3(xz[0],site.rule.floor_local_y+.035,xz[1]));var normal:Vector3=stance-point;normal.y=0;normal=normal.normalized();targets[row.id]={"row":row,"point":point,"normal":normal,"stance":stance,"home":site,"owner":row.owner}
func _activate_owner(home:Dictionary,id:String):
	var prep:RefCounted=home.preparation;var row:Dictionary=prep.cavities.cases[id];var old=home.model.get_node("InteriorCollision/Furniture_"+id);old.set_deferred("disabled",true)
	for collider:CollisionShape3D in row.future_fixed_colliders:
		var body:StaticBody3D=collider.get_parent();body.collision_layer=1;body.collision_mask=2;collider.set_deferred("disabled",false)
	for part in prep.entries[id].definition.parts:
		var item:Dictionary=prep.articulations[part.id];var body:AnimatableBody3D=item.proxy.get_parent();body.collision_layer=1;body.collision_mask=2
		for collider in body.get_children():
			if collider is CollisionShape3D:collider.set_deferred("disabled",false)
func _calibrate_stances():
	var shape=CapsuleShape3D.new();shape.radius=.28;shape.height=1.7
	for id in targets:
		var t:Dictionary=targets[id];var found=false;var tangent:Vector3=Vector3.UP.cross(t.normal)
		for distance in [.65,.80,.95,1.15]:
			if found:break
			for side in [0.0,.35,-.35,.65,-.65,.9,-.9]:
				var point:Vector3=t.point+t.normal*distance+tangent*side;point.y=t.stance.y
				var local:Vector3=t.home.model.to_local(point);var floor_ok=false
				for room in t.home.rule.rooms:
					var polygon=PackedVector2Array()
					for v in room.polygon_xz:polygon.append(Vector2(v[0],v[1]))
					if Geometry2D.is_point_in_polygon(Vector2(local.x,local.z),polygon):floor_ok=true;break
				if not floor_ok:continue
				var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.85);query.collision_mask=1;query.margin=.001
				if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
				actor.global_position=point;await get_tree().physics_frame
				if not check_access(id,"open").is_empty():continue
				var clear=true
				for part in t.row.parts:
					if not sweep(part,1.0).is_empty():clear=false;break
				if not clear:continue
				t.stance=point;t["stance_calibrated"]=true;found=true;break
		if not found:t["stance_calibrated"]=false
func _face_key(a:Vector3,b:Vector3,c:Vector3)->String:
	var keys=[str(a.snapped(Vector3.ONE*.0001)),str(b.snapped(Vector3.ONE*.0001)),str(c.snapped(Vector3.ONE*.0001))];keys.sort();return "|".join(keys)
func _setup_pickup():
	var site:Dictionary=civic.controller.homes.EST05;city.static_batcher.restore_tree(site.building);var record:Dictionary=config.pickups[0];var faces={};var bounds:AABB;var first=true
	for mesh in site.model.find_children(str(record.mesh_prefix)+"*","MeshInstance3D",true,false):
		pickup_meshes.append(mesh);mesh.set_meta("keep_individual_visual",true);var pose:Transform3D=site.model.global_transform.affine_inverse()*mesh.global_transform;var b:AABB=pose*mesh.mesh.get_aabb();bounds=b if first else bounds.merge(b);first=false;var vertices:PackedVector3Array=mesh.mesh.get_faces()
		for i in range(0,vertices.size(),3):faces[_face_key(pose*vertices[i],pose*vertices[i+1],pose*vertices[i+2])]=true
	# High mortar joints belong to the gables; cut them with their roof, not as floating fragments.
	for mesh in site.building.find_children("*","MeshInstance3D",true,false):
		var name:String=str(mesh.name);var unit="bays" if name.begins_with("R02_OFICINA_JUNTA_") else "office" if name.begins_with("R02_ESCRITORIO_JUNTA_") else "depot" if name.begins_with("R02_DEPOSITO_JUNTA_") else ""
		if unit.is_empty():continue
		var bounds_local:AABB=(site.model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
		if bounds_local.position.y<2.4:continue
		if mesh not in site.roofs:
			mesh.set_meta("keep_individual_visual",true);mesh.set_meta("interior_original_shadow",mesh.cast_shadow);mesh.set_meta("interior_unit",unit);site.roofs.append(mesh)
	var body:StaticBody3D=site.model.get_node("CivicInteriorCollision");var removed=0
	for collider in body.get_children():
		if collider is CollisionShape3D and collider.shape is ConcavePolygonShape3D:
			var source:PackedVector3Array=collider.shape.get_faces();var keep=PackedVector3Array()
			for i in range(0,source.size(),3):
				if faces.has(_face_key(source[i],source[i+1],source[i+2])):removed+=1
				else:keep.append(source[i]);keep.append(source[i+1]);keep.append(source[i+2])
			var shape=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(keep);collider.shape=shape
	var pickup_body=StaticBody3D.new();pickup_body.name="PilotReservedPickup";pickup_body.collision_layer=1;pickup_body.collision_mask=2;site.model.add_child(pickup_body);pickup_shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=bounds.size;pickup_shape.shape=box;pickup_shape.position=bounds.get_center();pickup_body.add_child(pickup_shape);pickup_body.set_meta("removed_original_triangles",removed)
	targets.EST05_MEC05["pickup_point"]=site.model.to_global(bounds.get_center());targets.EST05_MEC05.point=targets.EST05_MEC05.pickup_point+Vector3.UP*.09;city.static_batcher.batch_tree(site.building)
func check_access(id:String,operation:String)->String:
	if id.begins_with("@ground:"):
		var key=id.trim_prefix("@ground:")
		if state==null or not state.inventory.world_containers.has(key):return "Objeto indisponível"
		var p:Array=state.inventory.world_containers[key].position;var point=Vector3(p[0],p[1],p[2]);var delta:Vector3=actor.global_position-point;delta.y=0
		if delta.length()>1.8:return "Fora de alcance"
		var ray=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.4,point+Vector3.UP*.15,1,[actor.get_rid()])
		return "" if get_world_3d().direct_space_state.intersect_ray(ray).is_empty() else "Obstáculo"
	if not targets.has(id):return "Recipiente não disponível neste piloto"
	var t:Dictionary=targets[id]
	if not is_instance_valid(t.home.instance) or not t.home.instance.is_inside_tree() or not t.home.instance.is_visible_in_tree():return "Área descarregada"
	var point:Vector3=t.get("pickup_point",t.point) if operation=="pickup" else t.point;var delta:Vector3=actor.global_position-point;var flat=Vector3(delta.x,0,delta.z)
	if flat.length()>(1.35 if t.row.site=="EST05" else 1.8):return "Aproxime-se do móvel"
	if flat.dot(t.normal)<.08:return "Acesse pela frente do móvel"
	var excluded:Array[RID]=[actor.get_rid()]
	if t.row.site=="EST05":excluded.append(pickup_shape.get_parent().get_rid())
	var ray=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.4,point,1,excluded)
	var hit=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():last_access={"id":id,"collider":str(hit.collider.name),"shape":str(hit.collider.shape_owner_get_owner(hit.collider.shape_find_owner(hit.shape)).name),"position":str(hit.position),"target":str(point),"actor":str(actor.global_position)};return "Há um obstáculo entre você e o alvo"
	if operation=="search" and not t.row.parts.is_empty():
		var opened=false
		for part in t.row.parts:opened=opened or moving[part].current>=.98
		if not opened:return "Abra a porta ou gaveta primeiro"
	return ""
func teleport(id:String):
	if not targets.has(id):return
	if hud!=null:hud.personal.visible=false;hud.nearby_wanted=false;hud.nearby.visible=false;hud.windows[1].visible=false
	focused=id;selected="";actor.global_position=targets[id].stance;actor.velocity=Vector3.ZERO;actor.input_enabled=not automated;_update_camera()
func _update_camera():
	var center=actor.global_position+Vector3.UP*.9
	if hud!=null and hud.personal.visible!=hud.nearby.visible:center+=camera.global_basis.x*(-1.6 if hud.personal.visible else 1.6)
	camera.global_position=center+Vector3(8,8,8);camera.look_at(center)
func _process(_delta:float):
	if not ready_state:return
	_update_camera()
	var workshop_view:bool=focused=="EST05_MEC05" and actor.global_position.distance_to(targets.EST05_MEC05.stance)<35
	civic.controller.forced_home="EST05" if workshop_view else "";civic.controller.review_cut=workshop_view
	if actor.bag_inventory!=null:actor.bag_inventory.refresh_access()
	if hint!=null:hint.text="WASD · mover   E · abrir/fechar   G · outra porta   F · vasculhar   I · inventário   H · corpo   R · girar\n"+str(targets.get(focused,{}).get("row",{}).get("name",""))+" · "+message
func _physics_process(delta:float):
	if not ready_state:return
	for id in moving:
		var m:Dictionary=moving[id]
		if is_equal_approx(m.current,m.goal):continue
		var next:float=move_toward(m.current,m.goal,delta*1.5);var blocker:String=sweep(id,next)
		if not blocker.is_empty():m.goal=m.current;message="Movimento interrompido: caminho ocupado";last_motion={"id":id,"blocked":true,"collider":blocker};refresh();continue
		var was_open:bool=m.current>=.98;m.current=next;m.prep.set_review_fraction(id,next)
		if was_open!=(next>=.98) or is_equal_approx(next,m.goal):refresh()
func sweep(id:String,next:float)->String:
	var m:Dictionary=moving[id];var item:Dictionary=m.item;var body:AnimatableBody3D=item.proxy.get_parent();var old:float=m.current;var result=""
	for i in range(1,13):
		m.prep.set_review_fraction(id,lerpf(old,next,float(i)/12))
		for shape in body.get_children():
			if not shape is CollisionShape3D or shape.disabled:continue
			var query=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.collision_mask=3;query.margin=.0002;query.exclude=[body.get_rid()]
			var hits=get_world_3d().direct_space_state.intersect_shape(query,1)
			if not hits.is_empty():
				result=str(hits[0].collider.name);last_access={"sweep":id,"collider_path":str(hits[0].collider.get_path())}
				if result=="FutureMovingCollision":
					var other:CollisionShape3D=hits[0].collider.get_child(0);var a:AABB=query.transform*AABB(-shape.shape.size*.5,shape.shape.size);var b:AABB=other.global_transform*AABB(-other.shape.size*.5,other.shape.size);last_access["probe"]=str(a);last_access["other"]=str(b);last_access["aabb_overlap"]=a.intersects(b)
				break
		if not result.is_empty():break
	m.prep.set_review_fraction(id,old);return result
func toggle_part(id:String)->bool:
	if not moving.has(id):return false
	var m:Dictionary=moving[id];var error=check_access(m.container,"open")
	if not error.is_empty():message=error;refresh();return false
	var goal:float=0.0 if m.goal>.5 else 1.0;var blocker=sweep(id,goal)
	if not blocker.is_empty():message="Não há espaço para mover esta peça";last_motion={"id":id,"blocked":true,"collider":blocker};refresh();return false
	m.goal=goal;last_motion={"id":id,"blocked":false};message="Abrindo" if goal>0 else "Fechando";refresh();return true
func _nearest()->String:
	if targets.has(focused) and actor.global_position.distance_to(targets[focused].stance)<1.4:return focused
	var best="";var distance=1.8
	for id in targets:
		var p:Vector3=targets[id].point;var d:float=Vector2(p.x,p.z).distance_to(Vector2(actor.global_position.x,actor.global_position.z))
		if d<distance:distance=d;best=id
	return best
func _input(event:InputEvent):
	if not ready_state:return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		if hud.personal.visible or hud.nearby.visible:return
		camera.size=clampf(camera.size+(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1),6,18);get_viewport().set_input_as_handled();return
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_I:actor.hud_requested.emit(0)
		KEY_H:actor.hud_requested.emit(1)
		KEY_E,KEY_G,KEY_F:
			var id=_nearest()
			if id.is_empty():return
			focused=id
			if event.physical_keycode==KEY_F or targets[id].row.parts.is_empty():search_focused()
			else:
				var parts:Array=targets[id].row.parts;toggle_part(parts[1] if event.physical_keycode==KEY_G and parts.size()>1 else parts[0])
		KEY_F5:actor.save_condition();message=actor.inventory_message;refresh()
		KEY_F9:actor.load_condition();message=actor.inventory_message;refresh()
		_:return
	get_viewport().set_input_as_handled()
func _build_ui():
	ui=CanvasLayer.new();ui.layer=20;add_child(ui);hud=load(BASE+"loot_pilot/vendor/hud68.gd").new();ui.add_child(hud);hud.setup(actor);hud.personal.visible=false;hud.nearby_wanted=false;hud.nearby.visible=false;hud.windows[1].visible=false;hud.refresh();feedback=hud.feedback
	var navigation=HBoxContainer.new();navigation.theme=hud.theme;navigation.position=Vector2(550,12);ui.add_child(navigation);var choices=OptionButton.new();choices.fit_to_longest_item=false;choices.custom_minimum_size.x=200;navigation.add_child(choices)
	for row in config.containers:choices.add_item(row.name);choices.set_item_metadata(choices.item_count-1,row.id)
	var go=Button.new();go.text="Ir";go.pressed.connect(func():teleport(str(choices.get_item_metadata(choices.selected))));navigation.add_child(go)
	var reload=Button.new();reload.text="Recarregar área";reload.pressed.connect(func():await reload_region());navigation.add_child(reload)
	hint=Label.new();hint.position=Vector2(20,get_viewport().get_visible_rect().size.y-42);hint.add_theme_font_size_override("font_size",11);hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(hint)
	if not get_viewport().size_changed.is_connected(_resize_hint):get_viewport().size_changed.connect(_resize_hint)
func refresh():
	if hud==null or not is_instance_valid(hud):return
	if actor.bag_inventory!=null:actor.bag_inventory.refresh_access(false)
	hud.refresh()
	if not message.is_empty():hud.feedback.text=message
func search_focused()->bool:
	actor.capture_context();var accepted:bool=state.search(focused);message=state.message
	actor.bag_inventory.sync_from_state();refresh()
	if accepted:hud.show_container("world:"+focused)
	return accepted
func show_inventory(id:String):
	focused=id;actor.bag_inventory.sync_from_state();hud.personal.visible=true;hud.show_container("world:"+id);hud.refresh()
func _changed():
	if state==null:return
	var taken:bool=state.claimed.has("EST05_OBJ_01")
	for mesh in pickup_meshes:mesh.visible=not taken;mesh.layers=0 if taken else 1
	if pickup_shape!=null:pickup_shape.set_deferred("disabled",taken)
	if actor!=null and actor.bag_inventory!=null:actor.bag_inventory.sync_from_state()
	message=state.message;refresh()

func _resize_hint():
	if is_instance_valid(hint):hint.position.y=get_viewport().get_visible_rect().size.y-42
