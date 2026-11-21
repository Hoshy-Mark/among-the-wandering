extends Node3D
## Reversible staging adapter. Source exterior art and its collision stay intact.
const DATA := "res://staging/e06_world/arroio/data/interiors_h01_h05.json"
var city: Node3D
var homes := {}
var material_pool := {}
var mesh_pool := {}
var geometry_keys := {}
var forced_home := ""
var review_cut := false
var review_focus: Node3D
var last_door_result := {}
var services:Node3D

func configure(owner_city: Node3D) -> void:
	city=owner_city
	var definition: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var extra := "res://staging/e06_world/arroio/data/interiors_h06_h10.json"
	if FileAccess.file_exists(extra):definition.lots.merge(JSON.parse_string(FileAccess.get_file_as_string(extra)).lots)
	extra="res://staging/e06_world/arroio/data/interiors_h11_h20.json"
	if FileAccess.file_exists(extra):definition.lots.merge(JSON.parse_string(FileAccess.get_file_as_string(extra)).lots)
	extra="res://staging/e06_world/arroio/data/interiors_h21_h30.json"
	if FileAccess.file_exists(extra):definition.lots.merge(JSON.parse_string(FileAccess.get_file_as_string(extra)).lots)
	extra="res://staging/e06_world/arroio/data/interiors_h31_h40.json"
	if FileAccess.file_exists(extra):definition.lots.merge(JSON.parse_string(FileAccess.get_file_as_string(extra)).lots)
	var revision_path="res://staging/e06_world/arroio/data/residential_usability.json"
	if FileAccess.file_exists(revision_path):
		services=preload("res://staging/e06_world/arroio/scripts/residential_services.gd").new();services.name="ResidentialServices";services.city=city;services.controller=self;services.definitions=JSON.parse_string(FileAccess.get_file_as_string(revision_path));services.switch_input_enabled=services.definitions.defaults.switch_input_enabled;add_child(services)
	for lot in definition.lots:
		var rule: Dictionary=definition.lots[lot]
		if homes.has(lot) and is_instance_valid(homes[lot].instance) and homes[lot].instance.is_inside_tree():continue
		var building: Node3D=city.get_node_or_null("UrbanSectors/"+str(rule.exterior_rule.sector)+"/"+lot)
		if building==null:continue
		var exterior: Node3D=building.get_node("Visual")
		city.static_batcher.restore_tree(exterior)
		var instance: Node3D=load(rule.scene).instantiate()
		building.add_child(instance);instance.transform=exterior.transform
		var model: Node3D=instance.get_node("Model")
		for correction in rule.get("technical_adjustments",[]):
			var p: Array=correction.pivot;var v: Array=correction.translation
			var pivot := Vector3(p[0],p[1],p[2]);var rotation := Basis(Vector3.UP,deg_to_rad(float(correction.yaw_degrees)))
			var pose := Transform3D(rotation,pivot-rotation*pivot+Vector3(v[0],v[1],v[2]))
			for mesh in model.find_children(str(correction.prefix)+"*","MeshInstance3D",true,false):
				mesh.global_transform=model.global_transform*pose*model.global_transform.affine_inverse()*mesh.global_transform
		if is_instance_valid(services):services.apply_layout(model,lot)
		var home := {"rule":rule,"building":building,"instance":instance,"model":model,"roofs":[],"walls":[],"doors":[],"inside":false}
		homes[lot]=home
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var title := str(mesh.name).to_upper()
			if "FLOOR" in title or "PISO" in title:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if "WALL" in title or "PARTITION" in title or "LINTEL" in title or "PAREDE" in title or "HEADER" in title:
				mesh.set_meta("keep_individual_visual",true);home.walls.append(mesh)
				mesh.set_meta("interior_unit",_unit_for_mesh(home,mesh))
			for surface in mesh.mesh.get_surface_count():
				var mat: Material=mesh.get_active_material(surface)
				if mat==null:continue
				# Material equality includes texture paths and all imported PBR values.
				var key := _material_key(mat)
				if not material_pool.has(key):material_pool[key]=mat
				mesh.set_surface_override_material(surface,material_pool[key])
			if int(str(lot).trim_prefix("H"))>=11:
				# Keep per-instance material overrides while sharing exact prototype
				# geometry across independently imported house scenes.
				var resource: Mesh=mesh.mesh
				var overrides: Array[Material]=[]
				for surface in resource.get_surface_count():overrides.append(mesh.get_surface_override_material(surface))
				var resource_id: int=resource.get_instance_id()
				if not geometry_keys.has(resource_id):
					var digest := HashingContext.new();digest.start(HashingContext.HASH_SHA256)
					for surface in resource.get_surface_count():digest.update(var_to_bytes(resource.surface_get_arrays(surface)))
					geometry_keys[resource_id]=digest.finish().hex_encode()
				var geometry_key: String=geometry_keys[resource_id]
				if not mesh_pool.has(geometry_key):mesh_pool[geometry_key]=resource
				mesh.mesh=mesh_pool[geometry_key]
				for surface in overrides.size():mesh.set_surface_override_material(surface,overrides[surface])
		for door in rule.doors:_install_door(home,door)
		if FileAccess.file_exists("res://staging/e06_world/arroio/data/furniture_preparation.json"):
			home.preparation=preload("res://staging/e06_world/arroio/scripts/furniture_preparation.gd").new()
			home.preparation.configure(home,lot)
		var static_body := StaticBody3D.new();static_body.name="InteriorCollision";model.add_child(static_body)
		var faces := PackedVector3Array()
		var furniture := {}
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			if mesh.has_meta("interior_door_leaf") or mesh.has_meta("interior_door_handle"):continue
			var pose: Transform3D=model.global_transform.affine_inverse()*mesh.global_transform
			var title := str(mesh.name)
			if "_FURN_" in title or "_MOB_" in title:
				var key := title.get_slice("__",0)
				if home.has("preparation") and home.preparation.mesh_owners.has(title):key=home.preparation.mesh_owners[title]
				elif "__" not in title:
					key=title.rsplit("_",true,1)[0] if lot in ["H04","H05"] else lot+"_FURN_LAVADORA"
				var bounds: AABB=pose*mesh.mesh.get_aabb()
				furniture[key]=furniture[key].merge(bounds) if furniture.has(key) else bounds
				continue
			for vertex in mesh.mesh.get_faces():faces.append(pose*vertex)
		var shape := ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces)
		var collider := CollisionShape3D.new();collider.shape=shape;static_body.add_child(collider)
		for key in furniture:
			var bounds: AABB=furniture[key]
			var proxy := CollisionShape3D.new();proxy.name="Furniture_"+key;var box := BoxShape3D.new();box.size=bounds.size
			proxy.shape=box;proxy.position=bounds.get_center();static_body.add_child(proxy)
		for mesh in exterior.find_children("*","MeshInstance3D",true,false):
			var title := str(mesh.name).to_upper()
			var roof := "TELHAS" in title or "CUMEEIRA" in title or "BEIRAIS" in title or "OITOES" in title or "CHAPAS_ONDULADAS" in title
			var wall := "FACHADA" in title or "FUNDOS" in title or "LATERAIS" in title or "LATERAL" in title
			if roof or wall:
				var unit := _unit_for_mesh(home,mesh)
				if unit=="outside":continue
				mesh.set_meta("keep_individual_visual",true)
				mesh.set_meta("interior_unit",unit)
				mesh.set_meta("interior_original_shadow",mesh.cast_shadow)
				if roof:home.roofs.append(mesh)
				else:home.walls.append(mesh)
		for hinge in building.get_children():
			if str(hinge.name).begins_with("ReviewDoor_"):
				if (lot=="H10" and "OFICINA" in str(hinge.name)) or (lot=="H09" and "GALPAO" in str(hinge.name)):continue
				if int(str(lot).trim_prefix("H"))>=31:
					if str(hinge.name) not in ["ReviewDoor_"+lot+"_PORTA_FOLHA","ReviewDoor_"+lot+"_SERVICO_PORTA_FOLHA"]:continue
				elif int(str(lot).trim_prefix("H"))>=11 and str(hinge.name)!="ReviewDoor_"+lot+"_PORTA_FOLHA":continue
				var body: StaticBody3D=hinge.get_node("DoorCollision")
				var old: CollisionShape3D=body.get_child(0)
				if old.shape is ConcavePolygonShape3D:
					var solid := ConvexPolygonShape3D.new();solid.points=old.shape.get_faces();old.shape=solid
				home.doors.append({"hinge":hinge,"closed_basis":hinge.basis,"angle":deg_to_rad(float(rule.get("exterior_door_angles",{}).get(str(hinge.name),rule.get("exterior_open_degrees",90)))),"open":false,"leaf":hinge.get_child(0),"exterior":true,"unit":"wing" if "ALA_L" in str(hinge.name) else "main"})
		if is_instance_valid(services):services.register_home(home,lot)
		city.static_batcher.batch_tree(instance)
		city.static_batcher.batch_tree(exterior)
	set_meta("house_count",homes.size());set_meta("shared_material_count",material_pool.size())

func _unit_for_mesh(home: Dictionary,mesh: MeshInstance3D) -> String:
	if not home.rule.has("units"):return "main"
	var box: AABB=(home.model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
	var center := box.get_center()
	for unit in home.rule.units:
		var low: Array=unit.bounds[0];var high: Array=unit.bounds[1]
		if center.x>=float(low[0])-.6 and center.x<=float(high[0])+.6 and center.z>=float(low[2])-.6 and center.z<=float(high[2])+.6:return unit.id
	return "outside"

func _material_key(mat: Material) -> String:
	if not mat is StandardMaterial3D:return str(mat.get_instance_id())
	var result := str(mat.albedo_color)+str(mat.roughness)+str(mat.metallic)+str(mat.cull_mode)+str(mat.transparency)+str(mat.normal_enabled)+str(mat.normal_scale)+str(mat.uv1_scale)+str(mat.uv1_offset)+str(mat.vertex_color_use_as_albedo)
	for slot in [BaseMaterial3D.TEXTURE_ALBEDO,BaseMaterial3D.TEXTURE_NORMAL,BaseMaterial3D.TEXTURE_ROUGHNESS,BaseMaterial3D.TEXTURE_METALLIC]:
		var texture: Texture2D=mat.get_texture(slot)
		result+="|"+(texture.resource_path if texture!=null else "")
	return result

func _install_door(home: Dictionary,definition: Dictionary) -> void:
	var model: Node3D=home.model
	var mesh: MeshInstance3D=model.find_child(str(definition.mesh_name),true,false)
	if mesh==null:push_error("Missing interior door "+str(definition.mesh_name));return
	var hinge := Node3D.new();hinge.name="Hinge_"+str(definition.mesh_name);model.add_child(hinge)
	var p: Array=definition.hinge;hinge.position=Vector3(p[0],p[1],p[2])
	mesh.reparent(hinge,true);mesh.set_meta("keep_individual_visual",true);mesh.set_meta("interior_door_leaf",true)
	var prefix := str(definition.mesh_name).trim_suffix("_FOLHA")
	for name in definition.get("attached_meshes",[]):
		var handle := model.find_child(str(name),true,false) as MeshInstance3D
		if handle!=null:handle.reparent(hinge,true);handle.set_meta("keep_individual_visual",true);handle.set_meta("interior_door_handle",true)
	if prefix!=str(definition.mesh_name):
		for handle in model.find_children(prefix+"*MACANETA*","MeshInstance3D",true,false):
			handle.reparent(hinge,true);handle.set_meta("keep_individual_visual",true);handle.set_meta("interior_door_handle",true)
	var body := StaticBody3D.new();body.name="DoorCollision";hinge.add_child(body)
	var collider := CollisionShape3D.new();var shape := ConvexPolygonShape3D.new();var vertices := PackedVector3Array()
	var pose: Transform3D=hinge.global_transform.affine_inverse()*mesh.global_transform
	for vertex in mesh.mesh.get_faces():
		var point: Vector3=pose*vertex
		# Supplied leaves extend a few millimetres into their floor finish.
		# Keep art unchanged; trim only the lower collision proxy above that finish.
		var floor_y: float=definition.get("floor_local_y",home.rule.floor_local_y)
		var local_floor: float=hinge.to_local(model.to_global(Vector3(0,floor_y+.015,0))).y
		point.y=maxf(point.y,local_floor)
		vertices.append(point)
	shape.points=vertices;collider.shape=shape;body.add_child(collider)
	hinge.rotate_y(deg_to_rad(float(definition.source_to_closed_degrees)))
	var data := {"hinge":hinge,"closed_basis":hinge.basis,"angle":deg_to_rad(float(definition.open_degrees)),"open":false,"leaf":mesh,"exterior":false,"source":definition,"unit":definition.get("unit","main")}
	home.doors.append(data)

func set_doors_open(lot: String,opened: bool) -> void:
	for door in homes[lot].doors:
		door.hinge.basis=door.closed_basis
		if opened:door.hinge.rotate_y(door.angle)
		door.open=opened

func contains_point(lot: String,world_point: Vector3) -> bool:
	var home: Dictionary=homes[lot]
	if not is_instance_valid(home.model) or not home.model.is_inside_tree():return false
	var point: Vector3=home.model.to_local(world_point)
	if home.rule.has("units"):
		for unit in home.rule.units:
			if _contains_unit(unit,point):return true
		return false
	var bounds: Array=home.rule.interior_bounds
	return point.x>float(bounds[0][0])+.05 and point.x<float(bounds[1][0])-.05 and point.z>float(bounds[0][2])+.05 and point.z<float(bounds[1][2])-.05 and point.y<float(home.rule.floor_local_y)+2.5 and point.y>float(home.rule.floor_local_y)-.6

func _contains_unit(unit: Dictionary,point: Vector3) -> bool:
	var b: Array=unit.bounds
	return point.x>float(b[0][0]) and point.x<float(b[1][0]) and point.z>float(b[0][2]) and point.z<float(b[1][2]) and point.y<float(unit.floor_local_y)+2.5 and point.y>float(unit.floor_local_y)-.6

func _observer() -> Node3D:
	if is_instance_valid(review_focus):return review_focus
	var landscape := city.get_node_or_null("Landscape")
	if landscape!=null and is_instance_valid(landscape.occlusion_target):return landscape.occlusion_target
	return get_tree().get_first_node_in_group("player") as Node3D

func _process(_delta: float) -> void:
	if city==null:return
	var target := _observer();var camera := get_viewport().get_camera_3d()
	for lot in homes:
		var home: Dictionary=homes[lot]
		if not is_instance_valid(home.instance) or not home.instance.is_inside_tree():continue
		var inside: bool=lot==forced_home or (is_instance_valid(target) and contains_point(lot,target.global_position))
		home.inside=inside
		for roof in home.roofs:
			# Camera cutaway must not turn the physical roof into an opening
			# for sunlight. Retain its shadow while excluding it from the view.
			roof.visible=true
			var active := inside
			if home.rule.has("units") and is_instance_valid(target) and forced_home!=lot:
				active=false
				for unit in home.rule.units:
					if unit.id==roof.get_meta("interior_unit","main"):active=_contains_unit(unit,home.model.to_local(target.global_position))
			roof.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if active else roof.get_meta("interior_original_shadow")
		for wall in home.walls:
			var blocked := false
			var active := inside
			if home.rule.has("units") and is_instance_valid(target) and forced_home!=lot:
				active=false
				for unit in home.rule.units:
					if unit.id==wall.get_meta("interior_unit","main"):active=_contains_unit(unit,home.model.to_local(target.global_position))
			if active and review_cut:blocked=true
			elif active and camera!=null and is_instance_valid(target):
				var inv: Transform3D=wall.global_transform.affine_inverse()
				blocked=wall.mesh.get_aabb().grow(.04).intersects_segment(inv*camera.global_position,inv*(target.global_position+Vector3.UP*1.2))!=null
			wall.visible=true
			wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if blocked else wall.get_meta("interior_original_shadow",GeometryInstance3D.SHADOW_CASTING_SETTING_ON)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_E:return
	var target := _observer()
	if not is_instance_valid(target):return
	if is_instance_valid(services) and services.try_handle_key(event,target):return
	var best: Dictionary={};var distance := 1.8
	for home in homes.values():
		if not is_instance_valid(home.instance) or not home.instance.is_inside_tree():continue
		for door in home.doors:
			var center: Vector3=door.leaf.global_transform*door.leaf.mesh.get_aabb().get_center()
			var d: float=Vector2(center.x-target.global_position.x,center.z-target.global_position.z).length()
			if d<distance:best=door;distance=d
	if best.is_empty():return
	if _player_in_swing(best):
		last_door_result={"name":str(best.hinge.name),"blocked_by_actor":true}
		return
	# This laboratory interaction only changes door pose/collision; no inventory.
	best.hinge.basis=best.closed_basis
	if not best.open:best.hinge.rotate_y(best.angle)
	best.open=not best.open
	last_door_result={"name":str(best.hinge.name),"open":best.open}
	get_viewport().set_input_as_handled()

func _player_in_swing(door: Dictionary) -> bool:
	var body := door.hinge.get_node_or_null("DoorCollision") as StaticBody3D
	if body==null:return false
	var collider: CollisionShape3D=body.get_child(0)
	var query := PhysicsShapeQueryParameters3D.new();query.shape=collider.shape;query.collision_mask=2;query.exclude=[body.get_rid()]
	if collider.shape is ConcavePolygonShape3D:
		var proxy := ConvexPolygonShape3D.new();proxy.points=collider.shape.get_faces();query.shape=proxy
	var old: Basis=door.hinge.basis
	for i in range(1,19):
		var t := float(i)/18
		door.hinge.basis=door.closed_basis
		door.hinge.rotate_y(door.angle*((1-t) if door.open else t))
		query.transform=collider.global_transform
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
			door.hinge.basis=old;return true
	door.hinge.basis=old
	return false
