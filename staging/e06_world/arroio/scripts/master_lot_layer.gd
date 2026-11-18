extends RefCounted
## Runtime-only derivatives of immutable baseline catalogs, scoped to H01-H10.
const DATA := "res://staging/e06_world/arroio/data/"
var city: Node3D
var layers: Dictionary = {}

static func rules(world: Node3D) -> Dictionary:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA+"lot_overrides.json"))
	if not world.apply_master_candidates:
		return {"schema_version":1,"lots":{"H01":JSON.parse_string(FileAccess.get_file_as_string(DATA+"master_previous_h01.json"))}}
	if world.h02_variant == "A" and doc.lots.has("H02"):
		var r: Dictionary = doc.lots.H02
		r.visual_path="res://staging/e06_world/arroio/assets/master_h01_h10_rev01/H02_A.gltf"
		r.visual_translation_world = [0,0,-1.5]
		r.door_xz[1] -= 1.5
		r.body_center_xz[1] -= 1.5
		r.body_bounds_xz[1] -= 1.5
		r.body_bounds_xz[3] -= 1.5
		r.access_path = [r.gate_center,r.door_xz]
	return doc

static func adjusted(world: Node3D, name: String, data: Variant) -> Variant:
	if not world.apply_lot_overrides or not world.apply_master_candidates: return data
	if name not in ["urban_dressing","landscape","yard_details"]:return data
	var overrides: Dictionary = rules(world).lots
	if name == "urban_dressing":
		for plot in data.plots:
			var r: Dictionary = overrides.get(plot.building_id,{})
			if not r.get("master_candidate",false) or not r.get("enabled",false):continue
			plot.gate.center = r.gate_center.duplicate()
			# Match the authored leaf's actual 0.2225m bottom edge, not its old
			# oversized invisible box extending down to 0.10m through low ramps.
			plot.gate.leaf_collision_height_m=.86
			plot.access_path = r.access_path.duplicate(true)
			plot.access_width_m = r.access_width_m
			plot.threshold_connector = [[r.door_xz[0],r.door_xz[1]+r.front_direction*1.3],r.door_xz]
			var road_end: Array = plot.road_connector[-1].duplicate()
			road_end[0] += r.gate_center[0]-r.gate_original.center[0]
			plot.road_connector = [r.gate_center,road_end]
			var world_door := Vector3(r.door_xz[0],r.floor_m,r.door_xz[1])
			var anchor := Vector3(r.building_position[0],r.building_position[1],r.building_position[2])
			var local_door: Vector3 = Basis(Vector3.UP,deg_to_rad(r.building_yaw)).inverse()*(world_door-anchor)
			plot.entry.local_anchor_xyz = [local_door.x,local_door.y,local_door.z]
			plot.entry.position = r.door_xz
			plot.entry.approach = [r.door_xz[0],r.door_xz[1]+r.front_direction*1.3]
			plot.entry.mesh_name = r.revision+"_SOLEIRA"
			if not r.front_walls_to_recompose.is_empty():
				for segment in plot.segments:
					for point in segment:
						if absf(point[1]-r.gate_original.center[1])>.001:continue
						if absf(point[0]-(r.gate_original.center[0]-1.8))<.001:point[0]=r.gate_center[0]-1.8
						elif absf(point[0]-(r.gate_original.center[0]+1.8))<.001:point[0]=r.gate_center[0]+1.8
			for wall in data.shared_walls:
				if wall.id not in r.front_walls_to_recompose:continue
				assert(wall.owners.size()==1 and wall.owners[0].building_id==plot.building_id)
				var old_left: float = r.gate_original.center[0]-1.8
				var old_right: float = r.gate_original.center[0]+1.8
				for key in ["a","b"]:
					if absf(wall[key][0]-old_left)<.001:wall[key][0]=r.gate_center[0]-1.8
					elif absf(wall[key][0]-old_right)<.001:wall[key][0]=r.gate_center[0]+1.8
		for item in data.yards:_move_item(item,overrides)
	elif name == "landscape":
		for zone in data.ground_zones:
			var r: Dictionary = overrides.get(zone.get("building_id",""),{})
			if not r.get("master_candidate",false) or not r.get("enabled",false):continue
			if zone.id.begins_with("ACCESS_"):
				zone.points = r.access_path
				zone.width_m = 1.9
			elif zone.id.begins_with("APRON_"):
				var b: Array = r.body_bounds_xz
				zone.polygon = [[b[0]-.65,b[1]-.65],[b[2]+.65,b[1]-.65],[b[2]+.65,b[3]+.65],[b[0]-.65,b[3]+.65]]
		for item in data.props:_move_item(item,overrides)
		for walk in data.walks:
			if walk.id=="SERVICE_WALK_H02" and overrides.get("H02",{}).get("enabled",false):
				walk.points[0][1]=overrides.H02.body_bounds_xz[3]+.7
	elif name == "yard_details":
		for item in data.items:_move_item(item,overrides)
	return data

static func _move_item(item: Dictionary, overrides: Dictionary) -> void:
	var r: Dictionary = overrides.get(item.get("building_id",""),{})
	if not r.get("master_candidate",false) or not r.get("enabled",false):return
	for move in r.object_moves:
		if move.id == item.id:
			item.position = move.candidate_xz.duplicate()
			item.candidate_move = move

func configure(world: Node3D) -> void:
	city = world
	for h in city.catalog("lot_overrides").lots:
		var r: Dictionary = city.catalog("lot_overrides").lots[h]
		if not r.get("master_candidate",false) or not r.get("enabled",false):continue
		var art := Node3D.new()
		art.name = h+"_MasterCandidate"
		art.set_meta("revision",r.revision)
		art.set_meta("visual_homologation",false)
		city.get_node("Landscape/"+r.sector).add_child(art)
		layers[h] = art
		_surfaces(h,r,art)
		_object_context(h,r,art)
		_cover(h,r,art)
		if h!="H01":
			_crown(h,r,art)
			_litter(h,r,art)
		_fruit_ground(h,r,art)

func _material(r: Dictionary, zone: float, polygon: PackedVector2Array = PackedVector2Array()) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://staging/e06_world/arroio/scripts/master_ground.gdshader")
	var base: ShaderMaterial = city.get_node("Terrain/Ground/FlatSouthernGround").material_override
	for key in ["grass_texture","dirt_texture","paving_texture","gravel_texture"]:material.set_shader_parameter(key,base.get_shader_parameter(key))
	material.set_shader_parameter("zone",zone)
	material.set_shader_parameter("lot_seed",float(r.gate_center[0]))
	var shade: Node3D = city.get_node_or_null("UrbanDressing/"+r.sector+"/SHADE_"+_id(r))
	if shade!=null:
		var original: Dictionary = {}
		for item in city.catalog("urban_dressing").yards:
			if item.id=="SHADE_"+_id(r):original = item
		if not original.is_empty():material.set_shader_parameter("shade_center",Vector2(original.position[0],original.position[1]))
	if not polygon.is_empty():
		material.set_shader_parameter("boundary_count",mini(polygon.size(),32))
		polygon=polygon.duplicate()
		polygon.resize(32)
		material.set_shader_parameter("boundary",polygon)
	return material

func _id(r: Dictionary) -> String:
	return str(r.visual_path).get_file().get_basename()

func _surfaces(h: String,r: Dictionary,art: Node3D) -> void:
	var count := 0
	for node in city.get_node("Terrain/Pavements").find_children("*","MeshInstance3D",true,false)+city.get_node("Landscape/"+r.sector).find_children("*","MeshInstance3D",true,false)+city.get_node("UrbanDressing/"+r.sector+"/"+h).find_children("*","MeshInstance3D",true,false):
		var title: String = node.name
		var zone := -1.0
		if title.begins_with(h+"_Garden"):zone=0
		if title.begins_with("APRON_"+h):zone=1
		if title.begins_with("ACCESS_"+h) or (str(node.get_path()).contains("/"+h+"/") and title.begins_with("ThresholdRoute")):zone=2
		if title.begins_with("COURTYARD_"+h):zone=3
		if zone<0:continue
		var m := _material(r,zone)
		if node.material_override is ShaderMaterial:
			for k in ["boundary","boundary_count"]:m.set_shader_parameter(k,node.material_override.get_shader_parameter(k))
		node.material_override=m
		count+=1
	art.set_meta("surfaces_refined",count)
	if r.has("service_path"):
		city._buffer(art,h+"_ServicePath",r.service_path,1.25,.031,_material(r,2))
	for ext in r.extra_structures:
		var b: Array = ext.bounds
		var p := PackedVector2Array([Vector2(b[0]-.5,b[1]-.7),Vector2(b[2]+.5,b[1]-.7),Vector2(b[2]+.5,b[3]+.5),Vector2(b[0]-.5,b[3]+.5)])
		city._surface(art,ext.id+"_DrainedGround",p,.029,_material(r,2,p),2)

func _object_context(h: String,r: Dictionary,art: Node3D) -> void:
	var items: Array = city.catalog("urban_dressing").yards+city.catalog("yard_details").items+city.catalog("landscape").props
	var count := 0
	for item in items:
		if item.get("building_id","")!=h or not item.get("enabled",true):continue
		var owner: Node3D = city.get_node_or_null("UrbanDressing/"+r.sector+"/"+str(item.id))
		if owner==null:continue
		var kind: String = item.kind
		var zone := 3.0
		var radius: float = float(item.get("clearance_radius_m",1.2))
		if kind=="shade_tree":zone=4;radius=3.8
		elif kind in ["kitchen_garden","compost_bin","flower_border","vegetable_beds"]:zone=5
		elif kind in ["rain_barrel","wash_station"]:zone=1;radius=.9 if kind=="rain_barrel" else 1.5
		elif kind=="outdoor_table":zone=2;radius=2.6
		var polygon := PackedVector2Array()
		for j in range(12):
			var angle := j*TAU/12
			var reach := radius*(.88+.08*sin(j*7.2+item.position[0]))
			polygon.append(Vector2(item.position[0],item.position[1])+Vector2(cos(angle),sin(angle))*reach)
		city._surface(art,str(item.id)+"_ContactGround",polygon,.036,_material(r,zone,polygon),2)
		for node in owner.get_children():
			if node is MultiMeshInstance3D:
				if node.material_override is StandardMaterial3D:
					node.material_override=node.material_override.duplicate(false)
					node.material_override.roughness=.97
					if "blossom" in node.name:node.multimesh.visible_instance_count=maxi(1,node.multimesh.instance_count/4)
					if kind=="wash_station" and "water" in node.name:node.visible=false
				if ("leaf" in node.name or "green" in node.name) and kind!="shade_tree":
					for i in node.multimesh.instance_count:
						var t: Transform3D = node.multimesh.get_instance_transform(i)
						t.basis=t.basis.scaled(Vector3.ONE*(.34+.60*absf(sin(i*2.17+item.position[0]))))
						node.multimesh.set_instance_transform(i,t)
		count+=1
	art.set_meta("objects_with_ground_context",count)

func _cover(h: String,r: Dictionary,art: Node3D) -> void:
	var sector: Node3D = city.get_node_or_null("GroundCover/"+r.sector)
	if sector==null:return
	var refined := 0
	var hidden := 0
	var shade_center := Vector2(-1000,-1000)
	var contacts: Array = []
	for yard in city.catalog("urban_dressing").yards:
		if yard.id=="SHADE_"+h:shade_center=Vector2(yard.position[0],yard.position[1])
	for item in city.catalog("yard_details").items+city.catalog("landscape").props:
		if item.building_id==h:contacts.append(item)
	for visual in sector.get_children():
		var items: Array = visual.get_meta("catalog_items",[])
		for i in items.size():
			var item: Dictionary = items[i]
			if item.get("building_id","")!=h:continue
			var p := Vector2(item.position[0],item.position[1])
			var bounds: Array = r.body_bounds_xz
			var occupied: bool = p.x>bounds[0]-.1 and p.x<bounds[2]+.1 and p.y>bounds[1]-.1 and p.y<bounds[3]+.1
			for ext in r.extra_structures:
				var b: Array = ext.bounds
				occupied=occupied or (p.x>b[0]-.1 and p.x<b[2]+.1 and p.y>b[1]-.1 and p.y<b[3]+.1)
			var route_distance := Geometry2D.get_closest_point_to_segment(p,Vector2(r.gate_center[0],r.gate_center[1]),Vector2(r.door_xz[0],r.door_xz[1])).distance_to(p)
			var t: Transform3D = visual.multimesh.get_instance_transform(i)
			var scale_factor := .62+.46*absf(sin(p.x*4.2+p.y*2.7))
			scale_factor *= 1.0-.50*exp(-pow(p.distance_to(shade_center)/3.8,2))
			if route_distance<1.03:scale_factor=.12
			if r.has("service_path"):
				for j in range(r.service_path.size()-1):
					var pa: Array = r.service_path[j]
					var pb: Array = r.service_path[j+1]
					if Geometry2D.get_closest_point_to_segment(p,Vector2(pa[0],pa[1]),Vector2(pb[0],pb[1])).distance_to(p)<.7:scale_factor=.12
			for contact in contacts:
				if p.distance_to(Vector2(contact.position[0],contact.position[1]))<float(contact.clearance_radius_m)*.65:scale_factor=minf(scale_factor,.15)
			if occupied:scale_factor=.001;hidden+=1
			t.basis=t.basis.scaled(Vector3.ONE*scale_factor)
			visual.multimesh.set_instance_transform(i,t)
			refined+=1
	art.set_meta("existing_clumps_refined",refined)
	art.set_meta("clumps_suppressed_under_new_structures",hidden)

func _crown(h: String,r: Dictionary,art: Node3D) -> void:
	var tree: Node3D = city.get_node_or_null("UrbanDressing/"+r.sector+"/SHADE_"+h)
	if tree==null:return
	# Clone only the lot's leaf surfaces; retain shared trunk meshes and collisions.
	var refined := 0
	for node in tree.find_children("*","MeshInstance3D",true,false):
		if not "leaf" in node.name.to_lower():continue
		var mesh := ArrayMesh.new()
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var neighbors := {}
			for j in range(0,indices.size(),3):
				for k in [indices[j],indices[j+1],indices[j+2]]:
					if not neighbors.has(k):neighbors[k]=[]
					neighbors[k].append_array([indices[j],indices[j+1],indices[j+2]])
			var seen := {}
			for j in vertices.size():
				if seen.has(j):continue
				var pending: Array = [j]
				var component: Array = []
				while not pending.is_empty():
					var k: int = pending.pop_back()
					if seen.has(k):continue
					seen[k]=true;component.append(k);pending.append_array(neighbors.get(k,[]))
				if component.size()>16:continue
				var anchor: Vector3 = vertices[component.min()]
				for k in component:vertices[k]=anchor+(vertices[k]-anchor)*2.25
			arrays[Mesh.ARRAY_VERTEX]=vertices
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			node.mesh=mesh
			node.set_meta("keep_individual_visual",true)
			refined+=1
	art.set_meta("leaf_nodes_refined",refined)

func _fruit_ground(h: String,r: Dictionary,art: Node3D) -> void:
	for tree in city.catalog("landscape").trees:
		if tree.get("building_id","")!=h:continue
		var p := PackedVector2Array()
		for j in range(15):
			var angle := j*TAU/15
			p.append(Vector2(tree.position[0],tree.position[1])+Vector2(cos(angle)*2.5,sin(angle)*2.2)*(1+.10*sin(j*7.8)))
		city._surface(art,h+"_FruitOrganicGround",p,.034,_material(r,4,p),2)

func _litter(h: String,r: Dictionary,art: Node3D) -> void:
	var center := Vector2.ZERO
	for yard in city.catalog("urban_dressing").yards:
		if yard.id=="SHADE_"+h:center=Vector2(yard.position[0],yard.position[1])
	if center==Vector2.ZERO:return
	var multi := MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	var blade := PlaneMesh.new()
	blade.size=Vector2(.11,.043)
	multi.mesh=blade
	multi.instance_count=110
	for i in multi.instance_count:
		var angle := i*2.3999632
		var reach := 3.3*sqrt(float(i+1)/multi.instance_count)*(.85+.15*sin(i*13.1))
		var point := center+Vector2(cos(angle),sin(angle)*.82)*reach
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,angle).scaled(Vector3.ONE*(.7+.5*absf(sin(i*4.3)))),Vector3(point.x,.044,point.y)))
		multi.set_instance_color(i,Color(.30+.10*absf(sin(i)),.24,.13))
	var visual := MultiMeshInstance3D.new()
	visual.name=h+"_DryLeafLitter"
	visual.multimesh=multi
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=.98
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	visual.material_override=material
	art.add_child(visual)
