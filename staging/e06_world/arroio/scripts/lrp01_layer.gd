extends RefCounted
const DATA := "res://staging/e06_world/arroio/data/lrp01.json"
var geometry = preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new()

static func adjusted(city: Node3D, name: String, data: Variant) -> Variant:
	if not city.apply_lrp01 or name not in ["city_master","landscape","ground_cover"]:return data
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if FileAccess.file_exists("res://staging/e06_world/arroio/data/lake_west.json"):
		definition=JSON.parse_string(FileAccess.get_file_as_string("res://staging/e06_world/arroio/data/lake_west.json"))
	match name:
		"city_master":data.extent_xz=definition.extent_xz
		"landscape":data.trees.append_array(definition.trees)
		"ground_cover":data.items.append_array(definition.ground_cover)
	return data

func configure(city: Node3D) -> void:
	if FileAccess.file_exists("res://staging/e06_world/arroio/data/lake_west.json"):
		load("res://staging/e06_world/arroio/scripts/lake_west_layer.gd").new().configure(city)
		return
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var site: Dictionary = definition.site
	var owner := Node3D.new()
	owner.name="LRP01"
	owner.position=Vector3(350,0,-150)
	city.add_child(owner)
	var visual: Node3D = load(site.visual_path).instantiate()
	visual.name="Visual"
	owner.add_child(visual)
	var ground: ShaderMaterial = city.get_node("Terrain/Ground/FlatSouthernGround").material_override
	ground.set_shader_parameter("exclude_lake_terrain",true)
	ground.set_shader_parameter("lake_terrain_rect",Vector4(225,-240,475,-60))
	var field: ShaderMaterial = ground.duplicate(false)
	field.set_shader_parameter("exclude_lake_terrain",false)
	field.set_shader_parameter("garden_wear",0.0)
	var mud: ShaderMaterial = field.duplicate(false)
	mud.set_shader_parameter("surface_kind",3.0)
	var water := ShaderMaterial.new()
	water.shader=load("res://staging/e06_world/arroio/scripts/lrp01_water.gdshader")
	var depth := Image.load_from_file("res://staging/e06_world/arroio/assets/lrp01_rev02/shore_depth.png")
	water.set_shader_parameter("shore_depth",ImageTexture.create_from_image(depth))
	var faces := PackedVector3Array()
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		var title := str(mesh.name)
		if title in site.hidden_meshes:
			mesh.visible=false
			mesh.set_meta("keep_individual_visual",true)
			continue
		if title=="LRP01_TERRENO_PAMPA_250x180":mesh.material_override=field
		if ("MARGEM" in title or "SOLO_SATURADO" in title) and not "GALHO" in title:mesh.material_override=mud
		if title=="LRP01_ESPELHO_DAGUA_PLANO" or "POCA_RASA" in title:mesh.material_override=water
		# R02 boards were 39.4 cm above the original porch. Align the finish.
		if title=="R02_VARANDA_TABUAS_PISO":mesh.position.y=-.394
		if title in site.collision_excluded_meshes:continue
		geometry._append_faces(mesh,owner,faces)
	geometry._collision(owner,faces,"LakeTerrainAndCabinCollision")
	_cut_ground(city)
	city._buffer(city.get_node("Terrain/Pavements"),"LRP01_RuralRoad",definition.access_road,4.5,.031,city.material_cache.dirt)
	city._buffer(city.get_node("Terrain/Pavements"),"LRP01_CabinAccess",site.routes[0].points,2.35,.106,city.material_cache.dirt)
	# Smooth pedestrian transitions retain the visible steps and original dock.
	var cabin_ramp := Node3D.new()
	cabin_ramp.rotation.y=PI/2
	owner.add_child(cabin_ramp)
	geometry._ramp(cabin_ramp,24,2.3,57,53,.585,.08,"CabinStairRamp")
	geometry._ramp(cabin_ramp,24,2.3,62,61.1,.535,.585,"CabinThresholdRamp")
	geometry._ramp(cabin_ramp,7.1,1.7,39,36.8,-.03,.31,"DockBankRamp")
	_boardwalk(owner,visual)
	_shore_barrier(owner,definition.shoreline)
	if definition.has("wetland"):_wetland(owner,definition)

func _wetland(owner: Node3D, definition: Dictionary) -> void:
	for key in definition.wetland_assets:
		var source: Node3D = load(definition.wetland_assets[key].path).instantiate()
		var items: Array = definition.wetland.filter(func(item):return item.asset==key)
		for mesh in source.find_children("*","MeshInstance3D",true,false):
			var material := StandardMaterial3D.new()
			material.vertex_color_use_as_albedo=true
			material.cull_mode=BaseMaterial3D.CULL_DISABLED
			material.roughness=.95
			var multi := MultiMesh.new()
			multi.transform_format=MultiMesh.TRANSFORM_3D
			multi.mesh=mesh.mesh
			multi.instance_count=items.size()
			for i in items.size():
				var item: Dictionary = items[i]
				var p: Array = item.position
				var transform := Transform3D(Basis(Vector3.UP,deg_to_rad(item.yaw)).scaled(Vector3.ONE*item.scale),Vector3(p[0]-350,p[1],p[2]+150))
				multi.set_instance_transform(i,transform*mesh.transform)
			var instance := MultiMeshInstance3D.new()
			instance.name="Z2Wetland_"+str(key)
			instance.multimesh=multi
			instance.material_override=material
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			owner.add_child(instance)
		source.free()

func _boardwalk(owner: Node3D, visual: Node3D) -> void:
	var material: StandardMaterial3D = visual.get_node("CAB01_TRAPICHE_TABUAS").get_active_material(0).duplicate(false)
	material.vertex_color_use_as_albedo=false
	material.albedo_color=Color(.36,.28,.19)
	var entry := Vector3(54,0,-22)
	var top := Vector3(51,0,-20)
	var ramp := Node3D.new()
	ramp.name="WetlandWalkwayRamp"
	ramp.position=(entry+top)/2
	var direction := top-entry
	ramp.rotation.y=atan2(-direction.x,-direction.z)
	owner.add_child(ramp)
	geometry._ramp(ramp,0,1.9,direction.length()/2,-direction.length()/2,.08,.31,"WetlandTransition",material)
	var points := [top,Vector3(45,0,-15),Vector3(40,0,-11),Vector3(37,0,-7.1)]
	for i in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var length := a.distance_to(b)
		var segment := Node3D.new()
		segment.name="WetlandBoardwalk"+str(i)
		segment.position=(a+b)/2
		segment.rotation.y=atan2((b-a).x,(b-a).z)
		owner.add_child(segment)
		var shape := BoxShape3D.new()
		shape.size=Vector3(1.9,.12,length+.16)
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		collider.shape=shape
		body.add_child(collider)
		body.position.y=.25
		segment.add_child(body)
		var boards := ceili(length/.33)
		for j in boards:
			var mesh := BoxMesh.new()
			mesh.size=Vector3(1.9,.12,length/boards-.008)
			var plank := MeshInstance3D.new()
			plank.mesh=mesh
			plank.material_override=material
			plank.position=Vector3(0,.25,-length/2+(j+.5)*length/boards)
			segment.add_child(plank)

func _cut_ground(city: Node3D) -> void:
	var old: Node3D = city.get_node("Terrain/Ground/GroundCollision")
	for child in old.get_children():
		if child is CollisionShape3D:child.disabled=true
	# Four non-overlapping slabs leave the lake's own terrain basin in charge.
	var extent: Array = city.catalog("city_master").extent_xz
	for rectangle in [Vector4(extent[0],extent[1],225,extent[3]),Vector4(475,extent[1],extent[2],extent[3]),Vector4(225,extent[1],475,-240),Vector4(225,-60,475,extent[3])]:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size=Vector3(rectangle.z-rectangle.x,.2,rectangle.w-rectangle.y)
		var collider := CollisionShape3D.new()
		collider.shape=shape
		body.add_child(collider)
		old.add_child(body)
		body.position=Vector3((rectangle.x+rectangle.z)/2,0,(rectangle.y+rectangle.w)/2)-old.position
		body.position.y=-.1-old.position.y

func _shore_barrier(owner: Node3D, shoreline: Array) -> void:
	var faces := PackedVector3Array()
	for i in shoreline.size():
		var a: Array = shoreline[i]
		var b: Array = shoreline[(i+1)%shoreline.size()]
		for p in [Vector3(a[0],-.8,a[1]),Vector3(b[0],-.8,b[1]),Vector3(b[0],.13,b[1]),Vector3(a[0],-.8,a[1]),Vector3(b[0],.13,b[1]),Vector3(a[0],.13,a[1])]:faces.append(p)
	geometry._collision(owner,faces,"WaterBoundary")
