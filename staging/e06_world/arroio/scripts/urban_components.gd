extends Node3D
## New modular candidates, never historical E06 meshes. Parts are batched per lot.
var palette: Dictionary = {}
var batches: Dictionary = {}
var active_owner: Node3D
var active_body: StaticBody3D
var city: Node3D
var data: Dictionary
var assets: Dictionary
var box_mesh: BoxMesh
var leaf_mesh: ArrayMesh
var cylinder_mesh: CylinderMesh
var detail_meshes: Dictionary = {}
var sector_visibility: Dictionary = {}

func configure(world: Node3D, catalog_data: Dictionary, environment: Dictionary) -> void:
	city = world
	data = catalog_data
	assets = environment.assets
	box_mesh = BoxMesh.new()
	box_mesh.size = Vector3.ONE
	leaf_mesh = preload("res://staging/e06_world/arroio/scripts/yard_props.gd").leaf_mesh()
	cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.top_radius = 0.5
	cylinder_mesh.bottom_radius = 0.5
	cylinder_mesh.height = 1.0
	cylinder_mesh.radial_segments = 8
	var reference: Node = load(data.material_source).instantiate()
	palette.wood = _find_material(reference,"timber")
	palette.masonry = _find_material(reference,"plaster")
	for key in ["concrete", "ceramic", "metal"]:
		palette["yard_"+key] = _find_material(reference,key)
	set_meta("wood_uses_existing_material",palette.wood != null)
	set_meta("masonry_uses_existing_material",palette.masonry != null)
	reference.free()
	if palette.wood == null:
		palette.wood = _plain(Color(0.32,0.23,0.15))
	if palette.masonry == null:
		palette.masonry = _plain(Color(0.66,0.62,0.52))
	palette.masonry = palette.masonry.duplicate(false)
	palette.masonry.albedo_color = Color(0.70,0.67,0.58)
	palette.metal = _plain(Color(0.16,0.22,0.20))
	palette.soil = city.material_cache.dirt
	palette.green = _plain(Color(0.21,0.34,0.12))
	palette.green_light = _plain(Color(0.34,0.43,0.17))
	palette.lamp = _plain(Color(0.81,0.77,0.57))
	for key in ["green", "green_light"]:
		palette[key].cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(1,7):
		var sector := Node3D.new()
		sector.name = "S%02d" % i
		add_child(sector)
		sector_visibility[sector.name] = true
	var fields := Node3D.new()
	fields.name = "Fields"
	add_child(fields)
	if data.has("shared_walls"):
		var shared := Node3D.new()
		shared.name = "SharedWalls"
		add_child(shared)
		for wall in data.shared_walls:
			_owner("SharedWalls",wall.id)
			active_owner.set_meta("wall_owners",wall.owners)
			_fence(_v(wall.a),_v(wall.b),"muro",wall.height_m)
			_flush()
	for plot in data.plots:
		_owner(plot.sector,plot.building_id)
		active_owner.set_meta("urban_building_id",plot.building_id)
		active_owner.set_meta("source",plot.decision)
		if not data.has("shared_walls"):
			for segment in plot.segments:
				_fence(_v(segment[0]),_v(segment[1]),plot.style,plot.fence_height_m)
		if plot.gate != null:
			_gate(plot.gate)
			for extra_gate in plot.get("additional_gates",[]):_gate(extra_gate)
			var marker := Marker3D.new()
			marker.name = "PedestrianGate"
			marker.position = _v(plot.gate.center)
			marker.set_meta("opening_width_m",plot.gate.opening_width_m)
			marker.set_meta("status","candidate; not an interactive gate")
			active_owner.add_child(marker)
			city._buffer(active_owner,"ThresholdRoute",plot.access_path,plot.access_width_m,0.024,city.material_cache.paving)
			city._buffer(active_owner,"ThresholdConnector",plot.threshold_connector,plot.access_width_m,0.024,city.material_cache.paving)
			city._buffer(active_owner,"SidewalkConnector",plot.road_connector,2.6,0.025,city.material_cache.paving)
		_flush()
	for yard in data.yards:
		if not yard.enabled:
			continue
		_owner(yard.sector,yard.id)
		active_owner.set_meta("urban_building_id",yard.building_id)
		active_owner.set_meta("original_record",yard.source)
		var center := _v(yard.position)
		var yaw: float = deg_to_rad(yard.rotation_degrees)
		match yard.kind:
			"vegetable_beds": _garden(center,yaw)
			"orchard", "shrub", "shade_tree":
				var key: String = "shade_tree" if yard.kind == "shade_tree" else ("pitanga" if yard.kind == "orchard" else "arbusto")
				var instance: Node3D = load(assets[key].path).instantiate()
				instance.position = center
				instance.rotation.y = yaw
				active_owner.add_child(instance)
				if yard.kind == "shade_tree": _collision(center+Vector3.UP*1.5,Vector3(0.5,3.0,0.5))
			"shed": _shed(center,yaw)
		_flush()
	for lamp in data.street_lamps:
		_owner(lamp.sector,lamp.id)
		active_owner.set_meta("source",lamp)
		_lamp(_v(lamp.position),deg_to_rad(lamp.rotation_degrees))
		_flush()
	for item in data.civic_furniture:
		_owner(item.sector,item.id)
		active_owner.set_meta("source",item)
		if item.kind == "shade_tree":
			var tree: Node3D = load(assets.shade_tree.path).instantiate()
			tree.position = _v(item.position)
			active_owner.add_child(tree)
			_collision(tree.position+Vector3.UP*1.5,Vector3(0.5,3.0,0.5))
		elif item.kind == "bench":
			_bench(_v(item.position),deg_to_rad(item.rotation_degrees))
		else:
			_bin(_v(item.position))
		_flush()
	if city.show_yard_details:
		var props = preload("res://staging/e06_world/arroio/scripts/yard_props.gd").new()
		props.configure(self)
		var items: Array = city.catalog("yard_details").items.duplicate()
		if city.show_landscape: items.append_array(city.catalog("landscape").props)
		for item in items:
			_owner(item.sector,item.id)
			active_owner.set_meta("urban_building_id",item.building_id)
			active_owner.set_meta("yard_detail",item)
			props.build(item)
			_flush()
	preload("res://staging/e06_world/arroio/scripts/civic_infrastructure.gd").new().configure(self)
	set_meta("status","new modular candidates; no director approval or canonical POI assignment")
	install_threshold_anchors()

func install_threshold_anchors(sector_id: String = "") -> void:
	for plot in data.plots:
		if plot.entry == null or (not sector_id.is_empty() and plot.sector != sector_id): continue
		var parent: Node3D = city.get_node_or_null("UrbanSectors/"+plot.sector+"/"+plot.building_id+"/IntegrationAnchors")
		if parent == null or parent.has_node("FrontThreshold"): continue
		var marker := Marker3D.new()
		marker.name = "FrontThreshold"
		var p: Array = plot.entry.local_anchor_xyz
		marker.position = Vector3(p[0],p[1],p[2])
		marker.set_meta("source_mesh",plot.entry.mesh_name)
		marker.set_meta("status","measured current Z2 threshold; hinge, door and gameplay pending")
		parent.add_child(marker)

func _v(p: Array) -> Vector3:
	return Vector3(p[0],0,p[1])

func _plain(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

func _find_material(node: Node, word: String) -> Material:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(i)
			if material != null and word in material.resource_name.to_lower():
				return material
	for child in node.get_children():
		var found := _find_material(child,word)
		if found != null:
			return found
	return null

func _owner(sector: String, id: String) -> void:
	active_owner = Node3D.new()
	active_owner.name = id
	get_node(sector).add_child(active_owner)
	active_owner.set_meta("status","candidate urban dressing")
	active_body = StaticBody3D.new()
	active_body.name = "DressingCollision"
	active_owner.add_child(active_body)
	batches = {}

func _part(material: String,position: Vector3,size: Vector3,yaw: float = 0.0,roll: float = 0.0,shape: String = "box") -> void:
	var key := material+"/"+shape
	if not batches.has(key): batches[key] = []
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3(0,0,1),roll)
	batches[key].append(Transform3D(Basis(basis.x*size.x,basis.y*size.y,basis.z*size.z),position))

func _local(material: String,center: Vector3,yaw: float,offset: Vector3,size: Vector3,roll: float = 0.0,shape: String = "box") -> void:
	_part(material,center+Basis(Vector3.UP,yaw)*offset,size,yaw,roll,shape)

func _collision(position: Vector3,size: Vector3,yaw: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = position
	collider.rotation.y = yaw
	active_body.add_child(collider)

func _flush() -> void:
	var visual_radius := 0.0
	var detail: Dictionary = active_owner.get_meta("yard_detail",{})
	for key in batches:
		var parts: PackedStringArray = key.split("/")
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var meshes := {"box":box_mesh, "leaf":leaf_mesh, "cylinder":cylinder_mesh}
		multi.mesh = detail_meshes.get(parts[1],meshes.get(parts[1]))
		multi.instance_count = batches[key].size()
		for i in batches[key].size():
			var transform: Transform3D = batches[key][i]
			multi.set_instance_transform(i,transform)
			if not detail.is_empty():
				for corner in range(8):
					var point: Vector3 = transform*multi.mesh.get_aabb().get_endpoint(corner)
					visual_radius = maxf(visual_radius,Vector2(point.x,point.z).distance_to(Vector2(detail.position[0],detail.position[1])))
		var instance := MultiMeshInstance3D.new()
		instance.name = parts[0]+"_"+parts[1]
		instance.multimesh = multi
		instance.material_override = palette[parts[0]]
		active_owner.add_child(instance)
	if not detail.is_empty(): active_owner.set_meta("visual_radius_m",visual_radius)
	if active_body.get_child_count() == 0:
		active_owner.remove_child(active_body)
		active_body.queue_free()

func _fence(a: Vector3,b: Vector3,style: String,height: float) -> void:
	var length_m := a.distance_to(b)
	if length_m < 0.1: return
	var d := (b-a).normalized()
	var yaw := atan2(-d.z,d.x)
	var center := (a+b)/2.0
	if style == "muro":
		_part("masonry",center+Vector3.UP*height/2,Vector3(length_m,height,0.16),yaw)
		_part("masonry",center+Vector3.UP*(height+0.03),Vector3(length_m,0.06,0.23),yaw)
	else:
		if style == "cerca_ripas":
			for level in [0.32,0.83]:
				_part("wood",center+Vector3.UP*level,Vector3(length_m,0.08,0.06),yaw)
			var count := maxi(1,int(ceil(length_m/0.20)))
			for i in range(count):
				_part("wood",a+d*(length_m*(i+0.5)/count)+Vector3.UP*height/2,Vector3(0.11,height,0.055),yaw)
		else:
			for level in [0.28,0.61,0.96]:
				_part("metal",center+Vector3.UP*level,Vector3(length_m,0.018,0.018),yaw)
	var posts := maxi(1,int(ceil(length_m/2.8)))
	for i in range(posts+1):
		var p := a+d*(length_m*i/posts)
		_part("masonry" if style == "muro" else "wood",p+Vector3.UP*(height+0.08)/2,Vector3(0.24 if style=="muro" else 0.13,height+0.08,0.24 if style=="muro" else 0.13),yaw)
	_collision(center+Vector3.UP*height/2,Vector3(length_m,height,0.16),yaw)

func _gate(gate: Dictionary) -> void:
	var center := _v(gate.center)
	var along := Vector3(gate.along[0],0,gate.along[1])
	var inward := Vector3(gate.inward[0],0,gate.inward[1])
	if gate.has("inner_pedestrian_width_m"):
		var inner: float = gate.inner_pedestrian_width_m
		var outer: float = gate.opening_width_m
		var along_yaw := atan2(-along.z,along.x)
		for side in [-1.0,1.0]:
			var post: Vector3 = center+along*side*outer/2
			_part("masonry",post+Vector3.UP*.7,Vector3(.24,1.4,.24))
			_collision(post+Vector3.UP*.7,Vector3(.24,1.4,.24))
			var panel: Vector3 = center+along*side*(inner+outer)/4
			_part("metal",panel+Vector3.UP*.65,Vector3((outer-inner)/2,.86,.055),along_yaw)
			_collision(panel+Vector3.UP*.65,Vector3((outer-inner)/2,.86,.055),along_yaw)
		var pedestrian: Dictionary = gate.duplicate(true)
		pedestrian.erase("inner_pedestrian_width_m")
		pedestrian.opening_width_m=inner;pedestrian.leaf_length_m=inner/2-.12
		_gate(pedestrian)
		return
	var yaw := atan2(-inward.z,inward.x)
	var leaf_length: float = gate.get("leaf_length_m",1.55)
	for side in [-1.0,1.0]:
		var post: Vector3 = center+along*side*gate.opening_width_m/2.0
		_part("masonry",post+Vector3.UP*0.7,Vector3(0.24,1.4,0.24))
		_collision(post+Vector3.UP*0.7,Vector3(0.24,1.4,0.24))
		var leaf_direction: Vector3 = along*side if gate.get("folded_open",false) else inward
		var leaf_origin: Vector3 = post+inward*.125 if gate.get("folded_open",false) else post
		var leaf_yaw := atan2(-leaf_direction.z,leaf_direction.x)
		var leaf: Vector3 = leaf_origin+leaf_direction*leaf_length/2.0
		for level in [0.25,1.05]: _part("metal",leaf+Vector3.UP*level,Vector3(leaf_length,0.055,0.055),leaf_yaw)
		for i in range(8): _part("metal",leaf_origin+leaf_direction*(i*leaf_length/7)+Vector3.UP*0.65,Vector3(0.025,0.85,0.025),leaf_yaw)
		_collision(leaf+Vector3.UP*0.65,Vector3(leaf_length,gate.get("leaf_collision_height_m",1.1),0.055),leaf_yaw)
	var mailbox: Vector3 = center-along*(gate.opening_width_m/2.0+0.3)
	mailbox+=inward*float(gate.get("mailbox_offset_m",0.0))
	_part("metal",mailbox+Vector3.UP*0.7,Vector3(0.045,1.4,0.045))
	_part("metal",mailbox+Vector3.UP*1.3,Vector3(0.32,0.22,0.24))

func _garden(center: Vector3,yaw: float) -> void:
	for row in range(3):
		var x := (row-1)*0.75
		_local("soil",center,yaw,Vector3(x,0.09,0),Vector3(0.58,0.18,3.7))
		for side in [-1.0,1.0]: _local("wood",center,yaw,Vector3(x+side*0.32,0.13,0),Vector3(0.045,0.26,3.9))
		for plant in range(7):
			var base := center+Basis(Vector3.UP,yaw)*Vector3(x,0.16,-1.5+plant*0.5)
			for leaf in range(6):
				_part("green" if row%2==0 else "green_light",base,Vector3(0.25,0.42,0.40),yaw+leaf*TAU/6,0,"leaf")

func _shed(center: Vector3,yaw: float) -> void:
	_local("wood",center,yaw,Vector3(0,0.95,0),Vector3(2.2,1.9,2.6))
	_local("metal",center,yaw,Vector3(0,0.85,-1.31),Vector3(0.78,1.7,0.04))
	var roof_angle := atan2(0.5,1.25)
	for side in [-1.0,1.0]:
		_local("metal",center,yaw,Vector3(side*0.625,2.15,0),Vector3(sqrt(1.25*1.25+0.25),0.06,2.9),-side*roof_angle)
	_collision(center+Vector3.UP*0.95,Vector3(2.2,1.9,2.6),yaw)

func _lamp(center: Vector3,yaw: float) -> void:
	_part("masonry",center+Vector3.UP*0.18,Vector3(0.30,0.36,0.30))
	_part("metal",center+Vector3.UP*2.6,Vector3(0.10,5.2,0.10),0,0,"cylinder")
	_local("metal",center,yaw,Vector3(0.4,5.15,0),Vector3(0.9,0.09,0.09))
	_local("metal",center,yaw,Vector3(0.8,5.1,0),Vector3(0.43,0.12,0.24))
	_local("lamp",center,yaw,Vector3(0.8,5.02,0),Vector3(0.35,0.025,0.19))
	_collision(center+Vector3.UP*2.5,Vector3(0.18,5,0.18))

func _bench(center: Vector3,yaw: float) -> void:
	for plank in range(4):
		_local("wood",center,yaw,Vector3(0,0.47,-0.22+plank*0.14),Vector3(1.9,0.07,0.12))
	for plank in range(3):
		_local("wood",center,yaw,Vector3(0,0.69+plank*0.13,0.28),Vector3(1.9,0.10,0.055))
	for x in [-0.72,0.72]:
		for z in [-0.19,0.19]:
			_local("metal",center,yaw,Vector3(x,0.23,z),Vector3(0.055,0.46,0.055))
		_local("metal",center,yaw,Vector3(x,0.68,0.28),Vector3(0.055,0.70,0.055))
	_collision(center+Vector3.UP*0.48,Vector3(1.9,0.96,0.58),yaw)

func _bin(center: Vector3) -> void:
	_part("metal",center+Vector3.UP*0.40,Vector3(0.42,0.80,0.42),0,0,"cylinder")
	_part("masonry",center+Vector3.UP*0.04,Vector3(0.46,0.08,0.46))
	_collision(center+Vector3.UP*0.4,Vector3(0.42,0.80,0.42))

func set_sector_enabled(sector_id: String,enabled: bool) -> void:
	sector_visibility[sector_id] = enabled
	var sector := get_node_or_null(sector_id)
	if sector == null: return
	sector.visible = enabled
	sector.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if has_node("UtilityWires"):
		for span in $UtilityWires.get_children():
			var active := false
			for owner_sector in span.get_meta("utility_sectors"):
				if sector_visibility.get(owner_sector,true): active = true
			span.visible = active
	if has_node("SharedWalls"):
		for wall in $SharedWalls.get_children():
			var active := false
			for owner in wall.get_meta("wall_owners"):
				if sector_visibility.get(owner.sector,true): active = true
			wall.visible = active
			wall.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
