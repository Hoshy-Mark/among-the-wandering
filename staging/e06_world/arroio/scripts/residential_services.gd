extends Node3D
## Reusable physical fittings, isolated power channels and reversible layout revisions.
## No grid supply, inventory, loot or saved state is enabled here.
var city:Node3D
var controller:Node3D
var definitions={}
var circuits={}
var home_nodes={}
var meshes={}
var materials={}
var switch_input_enabled=false
var last_result={}
var preview_homes={}
var hint:Label
func apply_layout(model:Node3D,lot:String):
	var corrections:Array=definitions.houses.get(lot,{}).get("layout_corrections",[]).duplicate(true)
	var revision_path="res://staging/e06_world/arroio/data/furniture_cavities_revision.json"
	if FileAccess.file_exists(revision_path):corrections.append_array(JSON.parse_string(FileAccess.get_file_as_string(revision_path)).houses.get(lot,{}).get("layout_corrections",[]))
	var sink_path="res://staging/e06_world/arroio/data/sink_fronts_revision.json"
	if FileAccess.file_exists(sink_path):corrections.append_array(JSON.parse_string(FileAccess.get_file_as_string(sink_path)).houses.get(lot,{}).get("layout_corrections",[]))
	for correction in corrections:
		var p:Array=correction.pivot;var t:Array=correction.translation;var pivot=Vector3(p[0],p[1],p[2]);var basis=Basis(Vector3.UP,deg_to_rad(float(correction.yaw_degrees)));var pose=Transform3D(basis,pivot-basis*pivot+Vector3(t[0],t[1],t[2]))
		for name in correction.meshes:
			var mesh=model.find_child(str(name),true,false)
			if mesh==null:push_error("Usability revision missing mesh "+str(name));continue
			mesh.global_transform=model.global_transform*pose*model.global_transform.affine_inverse()*mesh.global_transform
func _material(key:String,color:Color,metallic:float=0.0)->StandardMaterial3D:
	if not materials.has(key):
		var mat=StandardMaterial3D.new()
		var families={"CERAMIC_CREAM":"Z2_FURN_CERAMICA_BRANCA","AGED_ENAMEL":"Z2_FURN_METAL_ENVELHECIDO","SWITCH_CHARCOAL":"Z2_FURN_METAL_PRETO","BULB_OFF":"Z2_FURN_PLASTICO_CREME"}
		if is_instance_valid(controller) and families.has(key):
			for sample in controller.material_pool.values():
				if sample is StandardMaterial3D and sample.resource_name==families[key]:mat=sample.duplicate();break
		mat.resource_name="Z2_HOME_SERVICE_"+key;mat.albedo_color=color;mat.roughness=.84;mat.metallic=metallic;materials[key]=mat
	return materials[key]
func _visual(parent:Node3D,key:String,mesh:Mesh,material:Material,position:Vector3=Vector3.ZERO)->MeshInstance3D:
	if not meshes.has(key):meshes[key]=mesh
	var node=MeshInstance3D.new();node.name=key;node.mesh=meshes[key];node.material_override=material;node.position=position;parent.add_child(node);return node
func _roof_height(home:Dictionary,position:Vector3,floor_y:float)->float:
	var result:float=INF
	for roof in home.get("roofs",[]):
		var pose:Transform3D=home.model.global_transform.affine_inverse()*roof.global_transform;var bounds:AABB=pose*roof.mesh.get_aabb()
		if position.x<bounds.position.x-.001 or position.x>bounds.end.x+.001 or position.z<bounds.position.z-.001 or position.z>bounds.end.z+.001:continue
		var vertices:PackedVector3Array=roof.mesh.get_faces()
		for i in range(0,vertices.size(),3):
			var a:Vector3=pose*vertices[i];var b:Vector3=pose*vertices[i+1];var c:Vector3=pose*vertices[i+2];var den:float=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
			if absf(den)<.000001:continue
			var u:float=((b.z-c.z)*(position.x-c.x)+(c.x-b.x)*(position.z-c.z))/den;var v:float=((c.z-a.z)*(position.x-c.x)+(a.x-c.x)*(position.z-c.z))/den;var w:float=1-u-v
			if minf(u,minf(v,w))<-.00001:continue
			var y:float=u*a.y+v*b.y+w*c.y
			if y>floor_y+2.05:result=minf(result,y)
	return result
func register_home(home:Dictionary,lot:String):
	var group=Node3D.new();group.name="HomeServices";group.set_meta("keep_individual_visual",true);group.set_meta("grid_connected",false);home.model.add_child(group);home_nodes[lot]=group
	var cream=_material("CERAMIC_CREAM",Color(.76,.73,.65));var metal=_material("AGED_ENAMEL",Color(.35,.37,.32),.3);var dark=_material("SWITCH_CHARCOAL",Color(.12,.13,.12));var off=_material("BULB_OFF",Color(.81,.80,.72));var on=_material("BULB_ON",Color(1,.81,.51));on.emission_enabled=true;on.emission=Color(1,.65,.32);on.emission_energy_multiplier=1.2
	for rule in definitions.houses.get(lot,{}).get("lighting",[]):
		var fitting=Node3D.new();fitting.name=str(rule.id).replace("/","_");group.add_child(fitting);fitting.set_meta("stable_id",rule.id);var a:Array=rule.lamp_position;fitting.position=Vector3(a[0],a[1],a[2]);var bulb:MeshInstance3D
		var roof_y:float=_roof_height(home,fitting.position,float(rule.floor_local_y));var verified:bool=is_finite(roof_y)
		if not verified:roof_y=float(rule.floor_local_y)+2.44
		fitting.set_meta("ceiling_mount_verified",verified);fitting.set_meta("mount_height_model_m",roof_y)
		var drop:float=maxf(0,roof_y-(float(rule.floor_local_y)+2.43))
		if rule.fixture_type=="sealed_ceiling":fitting.position.y=roof_y-.135;drop=0

		var mount=CylinderMesh.new();mount.top_radius=.075;mount.bottom_radius=.075;mount.height=.035;mount.radial_segments=12;_visual(fitting,"CEILING_ROSETTE",mount,cream,Vector3(0,.112+drop,0))
		if rule.fixture_type=="sealed_ceiling":
			var diffuser=SphereMesh.new();diffuser.radius=.105;diffuser.height=.09;diffuser.radial_segments=16;diffuser.rings=8;bulb=_visual(fitting,"SEALED_DIFFUSER",diffuser,off,Vector3(0,.06,0))
		else:
			var stem=CylinderMesh.new();stem.top_radius=.013;stem.bottom_radius=.013;stem.height=.10;stem.radial_segments=8;var wire=_visual(fitting,"SHORT_PENDANT_STEM",stem,dark,Vector3(0,.045+drop*.5,0));wire.scale.y=1+drop/.10
			var shade=CylinderMesh.new();shade.top_radius=.035;shade.bottom_radius=.13;shade.height=.09;shade.radial_segments=16;_visual(fitting,"ENAMEL_SHADE",shade,metal,Vector3(0,-.032,0))
			var globe=SphereMesh.new();globe.radius=.033;globe.height=.07;globe.radial_segments=12;globe.rings=8;bulb=_visual(fitting,"CERAMIC_BULB",globe,off,Vector3(0,-.075,0))
		var light=OmniLight3D.new();light.name="RoomLamp_DISABLED_UNTIL_SUPPLIED";fitting.add_child(light);light.position.y=-.12;light.omni_range=rule.range_m;light.light_energy=0;var c:Array=rule.lamp_color;light.light_color=Color(c[0],c[1],c[2]);light.shadow_enabled=true;light.shadow_bias=.03;light.visible=false
		var rocker:MeshInstance3D;var switch_node:Node3D;var host:MeshInstance3D
		if rule.switch!=null:
			var sw:Dictionary=rule.switch;switch_node=Node3D.new();switch_node.name="Switch_"+str(rule.id).replace("/","_");group.add_child(switch_node);a=sw.position;switch_node.position=Vector3(a[0],a[1],a[2]);a=sw.normal;var normal=Vector3(a[0],a[1],a[2]);switch_node.basis=Basis(Vector3.UP.cross(normal),Vector3.UP,normal);host=home.model.find_child(str(sw.host_wall),true,false)
			var plate=BoxMesh.new();plate.size=Vector3(.075,.115,.012);_visual(switch_node,"SWITCH_PLATE",plate,cream)
			var lever=BoxMesh.new();lever.size=Vector3(.034,.052,.017);rocker=_visual(switch_node,"SWITCH_ROCKER",lever,dark,Vector3(0,0,.012));rocker.rotation_degrees.x=12
			switch_node.set_meta("stable_id",str(rule.id)+"/switch");switch_node.set_meta("circuit_id",rule.id);switch_node.set_meta("supply_available",false)
		circuits[rule.id]={"home":lot,"rule":rule,"fitting":fitting,"light":light,"bulb":bulb,"off_material":off,"on_material":on,"switch":switch_node,"rocker":rocker,"host":host,"supply":false,"requested_on":false}
func set_home_power(lot:String,available:bool):
	for id in circuits:
		if circuits[id].home==lot:circuits[id].supply=available;_update(id)
func toggle_switch(id:String)->Dictionary:
	if not circuits.has(id):return {"success":false,"reason":"unknown_circuit"}
	var row:Dictionary=circuits[id];row.requested_on=not row.requested_on;_update(id);last_result={"success":true,"circuit":id,"requested_on":row.requested_on,"energized":row.supply and row.requested_on,"grid_connected":false};return last_result
func _update(id:String):
	var row:Dictionary=circuits[id];var active:bool=row.supply and row.requested_on;row.light.visible=active;row.light.light_energy=float(row.rule.lamp_energy) if active else 0;row.bulb.material_override=row.on_material if active else row.off_material
	if is_instance_valid(row.rocker):row.rocker.rotation_degrees.x=-12 if row.requested_on else 12
	if is_instance_valid(row.switch):row.switch.set_meta("supply_available",row.supply)
func try_handle_key(event:InputEvent,target:Node3D)->bool:
	if not switch_input_enabled or not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_E or not is_instance_valid(target):return false
	var closest="";var distance=.95
	for id in circuits:
		var row:Dictionary=circuits[id]
		if not is_instance_valid(row.switch) or not _switch_reachable(row,target):continue
		var local:Vector3=controller.homes[row.home].model.to_local(target.global_position)
		if absf(local.y-float(row.rule.floor_local_y))>.45:continue
		var p:Vector3=row.switch.global_position;var d:float=Vector2(p.x-target.global_position.x,p.z-target.global_position.z).length()
		if d<distance:closest=id;distance=d
	if closest.is_empty():return false
	for home in controller.homes.values():
		for door in home.doors:
			var p:Vector3=door.leaf.global_transform*door.leaf.mesh.get_aabb().get_center()
			if Vector2(p.x-target.global_position.x,p.z-target.global_position.z).length()<distance-.10:return false
	toggle_switch(closest);get_viewport().set_input_as_handled();return true
func _process(_delta:float):
	if DisplayServer.get_name()=="headless":return
	var powered_homes={}
	for row in circuits.values():
		if row.supply and row.requested_on:powered_homes[row.home]=true
	for lot in home_nodes:
		if not is_instance_valid(home_nodes[lot]) or not controller.homes.has(lot):continue
		home_nodes[lot].visible=controller.homes[lot].inside or powered_homes.has(lot)
	_update_hint()
	for row in circuits.values():
		if is_instance_valid(row.host) and is_instance_valid(row.switch):
			for mesh in row.switch.get_children():mesh.cast_shadow=row.host.cast_shadow

func _unhandled_key_input(event:InputEvent):
	if not definitions.get("defaults",{}).get("preview_power_toggle_enabled",false) or not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_L:return
	var target=controller._observer()
	if not is_instance_valid(target):return
	for lot in home_nodes:
		if controller.contains_point(lot,target.global_position):
			preview_homes[lot]=not preview_homes.get(lot,false);set_home_power(lot,preview_homes[lot]);last_result={"home":lot,"test_supply":preview_homes[lot],"grid_connected":false};get_viewport().set_input_as_handled();return
func _update_hint():
	if not switch_input_enabled:return
	if not is_instance_valid(hint):
		var layer=CanvasLayer.new();layer.name="ElectricalInspectionHint";add_child(layer);hint=Label.new();hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",16);hint.add_theme_color_override("font_shadow_color",Color.BLACK);hint.add_theme_constant_override("shadow_offset_x",1);hint.add_theme_constant_override("shadow_offset_y",1);layer.add_child(hint)
	var target=controller._observer();hint.visible=false
	if not is_instance_valid(target):return
	var home_id=""
	for lot in home_nodes:
		if controller.contains_point(lot,target.global_position):home_id=lot;break
	if home_id.is_empty():return
	var status="Alimentação de TESTE ligada" if preview_homes.get(home_id,false) else "Sem energia"
	hint.text=status+" · L: ligar/desligar alimentação de teste desta casa"
	for row in circuits.values():
		if row.home!=home_id or not is_instance_valid(row.switch) or not _switch_reachable(row,target):continue
		var p:Vector3=row.switch.global_position
		if Vector2(p.x-target.global_position.x,p.z-target.global_position.z).length()<1.2:
			hint.text="E: interruptor — "+str(row.rule.get("room_display",row.rule.room_name))+" · "+("ligado" if row.requested_on else "desligado")+"\n"+hint.text;break
	hint.position=Vector2(24,get_viewport().get_visible_rect().size.y-76);hint.size.x=get_viewport().get_visible_rect().size.x-48;hint.visible=true

func _switch_reachable(row:Dictionary,target:Node3D)->bool:
	if not is_instance_valid(row.switch) or not is_instance_valid(target):return false
	var normal:Vector3=row.switch.global_basis.z;var difference:Vector3=target.global_position-row.switch.global_position;difference.y=0
	if normal.dot(difference)<.05:return false
	var excluded:Array[RID]=[]
	if target is CollisionObject3D:excluded.append(target.get_rid())
	var ray=PhysicsRayQueryParameters3D.create(target.global_position+Vector3.UP*1.15,row.switch.global_position+normal*.025,1,excluded)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
