extends RefCounted
## Metric modular props. All lots share mesh and texture resources.
var composer: Node3D
var center: Vector3
var yaw: float

static func leaf_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(0,0,0),Vector3(-0.5,0.38,0.12),Vector3(0,0.42,0.23),Vector3(0.5,0.38,0.12),Vector3(-0.32,0.75,0.42),Vector3(0,0.8,0.51),Vector3(0.32,0.75,0.42),Vector3(0,1,0.82)]
	for index in [0,1,2,0,2,3,1,4,5,1,5,2,2,5,6,2,6,3,4,7,5,5,7,6]:
		var point: Vector3 = points[index]
		tool.set_uv(Vector2(point.x+0.5,point.y))
		tool.add_vertex(point)
	tool.generate_normals()
	return tool.commit()

func configure(builder: Node3D) -> void:
	composer = builder
	for key in ["wood", "yard_concrete", "yard_ceramic", "yard_metal"]:
		var material: StandardMaterial3D = composer.palette[key].duplicate(false)
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3.ONE*1.3
		composer.palette["prop_"+key] = material
	for item in [["linen",Color(0.72,0.69,0.57)],["blue",Color(0.36,0.48,0.53)],["rust",Color(0.54,0.33,0.25)]]:
		var cloth := StandardMaterial3D.new()
		cloth.albedo_texture = composer.palette.masonry.albedo_texture
		cloth.albedo_color = item[1]
		cloth.roughness = 0.98
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
		composer.palette[item[0]] = cloth
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.28,0.43,0.40,0.68)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.15
	composer.palette.water = water
	composer.palette.blossom = composer._plain(Color(0.48,0.39,0.60))
	var pot := CylinderMesh.new()
	pot.top_radius = 0.5
	pot.bottom_radius = 0.32
	pot.height = 1
	pot.radial_segments = 12
	composer.detail_meshes.pot = pot
	composer.detail_meshes.cloth = _cloth_mesh()
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1
	rock.radial_segments = 7
	rock.rings = 3
	composer.detail_meshes.rock = rock
	composer.set_meta("yard_shared_pbr",true)

func _cloth_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(8):
		for y in range(6):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var uv := Vector2((x+corner.x)/8.0,(y+corner.y)/6.0)
				tool.set_uv(uv)
				tool.add_vertex(Vector3(uv.x-0.5,-uv.y-0.07*sin(uv.x*PI),0.055*sin(uv.x*PI*5)*uv.y+0.09*uv.y*uv.y))
	tool.generate_normals()
	return tool.commit()

func _part(material: String,offset: Vector3,size: Vector3,roll: float = 0,shape: String = "box") -> void:
	composer._local(material,center,yaw,offset,size,roll,shape)

func _solid(offset: Vector3,size: Vector3) -> void:
	composer._collision(center+Basis(Vector3.UP,yaw)*offset,size,yaw)

func _plant(offset: Vector3,height: float,seed: int) -> void:
	_part("green",offset+Vector3.UP*height/2,Vector3(0.025,height,0.025),0,"cylinder")
	for level in range(3):
		for side in range(3):
			var base := center+Basis(Vector3.UP,yaw)*(offset+Vector3.UP*(height*level/4))
			composer._part("green_light" if seed%2==0 else "green",base,Vector3(height*0.43,height*0.5,height*0.5),yaw+side*TAU/3+level*0.8+seed,0,"leaf")

func build(item: Dictionary) -> void:
	center = Vector3(item.position[0],0,item.position[1])
	yaw = deg_to_rad(item.rotation_degrees)
	_worn_ground(item)
	match item.kind:
		"wash_station": _wash_station()
		"clothesline": _clothesline(item.variant)
		"kitchen_garden": _garden()
		"compost_bin": _compost()
		"log_stack": _logs()
		"pot_cluster": _pots()
		"trellis": _trellis()
		"chicken_coop": _coop()
		"outdoor_table": _outdoor_table()
		"workbench": _workbench()
		"rain_barrel": _rain_barrel()
		"flower_border": _flower_border(item.variant)
		"rock_group": _rocks()
		"fallen_log": _fallen_log()

func _rocks() -> void:
	for index in range(5):
		var x := -0.85+(index%3)*0.72
		var z := -0.5+floori(index/3.0)*0.85
		var height := 0.35+0.12*(index%3)
		_part("prop_yard_concrete",Vector3(x,height*0.35,z),Vector3(0.8,height,0.65),0.12*(index-2),"rock")
	_solid(Vector3(0,0.25,0),Vector3(2.4,0.5,1.8))

func _fallen_log() -> void:
	_part("prop_wood",Vector3(0,0.23,0),Vector3(0.43,3.4,0.43),PI/2,"cylinder")
	_part("prop_wood",Vector3(0.3,0.4,0.12),Vector3(0.16,0.7,0.16),-0.6,"cylinder")
	_solid(Vector3(0,0.3,0),Vector3(3.4,0.6,0.7))

func _outdoor_table() -> void:
	for plank in range(5):
		_part("prop_wood",Vector3(0,0.78,-0.4+plank*0.2),Vector3(2.1,0.065,0.18))
	for x in [-0.75,0.75]:
		for z in [-0.3,0.3]:
			_part("prop_wood",Vector3(x,0.38,z),Vector3(0.09,0.76,0.09))
	for side in [-1,1]:
		_part("prop_wood",Vector3(0,0.44,side*0.95),Vector3(2.2,0.08,0.34))
		for x in [-0.78,0.78]:
			_part("prop_wood",Vector3(x,0.2,side*0.95),Vector3(0.1,0.4,0.25))
	_solid(Vector3(0,0.4,0),Vector3(2.2,0.8,2.25))

func _workbench() -> void:
	_part("prop_wood",Vector3(0,0.9,0),Vector3(1.9,0.1,0.8))
	for x in [-0.75,0.75]:
		for z in [-0.3,0.3]:
			_part("prop_wood",Vector3(x,0.45,z),Vector3(0.09,0.9,0.09))
	_part("prop_wood",Vector3(0,0.2,0),Vector3(1.65,0.07,0.65))
	for index in range(3):
		_part("prop_yard_ceramic",Vector3(-0.55+index*0.4,1.03,0),Vector3(0.24,0.18,0.24),0,"pot")
	_solid(Vector3(0,0.5,0),Vector3(1.9,1.0,0.8))

func _rain_barrel() -> void:
	_part("prop_wood",Vector3(0,0.11,0),Vector3(0.85,0.22,0.8))
	_part("prop_yard_metal",Vector3(0,0.71,0),Vector3(0.68,1.0,0.68),0,"cylinder")
	for level in [0.27,0.72,1.16]:
		_part("metal",Vector3(0,level,0),Vector3(0.7,0.045,0.7),0,"cylinder")
	_part("prop_yard_metal",Vector3(0,1.22,0),Vector3(0.73,0.045,0.73),0,"cylinder")
	_part("metal",Vector3(0,0.38,-0.4),Vector3(0.045,0.045,0.18))
	_solid(Vector3(0,0.65,0),Vector3(0.72,1.3,0.72))

func _flower_border(variant: int) -> void:
	_part("soil",Vector3(0,0.07,0),Vector3(2.5,0.14,0.65))
	for side in [-1,1]:
		_part("prop_yard_ceramic",Vector3(0,0.1,side*0.37),Vector3(2.65,0.2,0.09))
	for index in range(7):
		var offset := Vector3(-1.08+index*0.36,0.14,0)
		_plant(offset,0.43+0.06*(index%2),index)
		for petal in range(5):
			var angle := petal*TAU/5
			_part("blossom" if variant%2==0 else "linen",offset+Vector3(cos(angle)*0.07,0.48,sin(angle)*0.07),Vector3(0.13,0.07,0.13),0,"pot")

func _worn_ground(item: Dictionary) -> void:
	var polygon := PackedVector2Array()
	for index in range(12):
		var angle := index*TAU/12
		var radius: float = item.clearance_radius_m*(0.82+0.1*cos(angle*3+item.variant))
		polygon.append(Vector2(center.x,center.z)+Vector2(cos(angle),sin(angle))*radius)
	var source: MeshInstance3D = composer.city.get_node("Terrain/Ground/FlatSouthernGround")
	var material: ShaderMaterial = source.material_override.duplicate(false)
	if composer.city.show_landscape:
		var floor_kind: String = composer.city.catalog("landscape").lot_surfaces.get(item.building_id,"grass")
		material.set_shader_parameter("underlay_kind",{"grass":0.0,"dirt":1.0,"gravel":2.0,"litter":3.0,"mixed":4.0}[floor_kind])
		material.set_shader_parameter("surface_kind",1.0)
	material.set_shader_parameter("garden_wear",0.78)
	material.set_shader_parameter("wear_edge_m",0.6)
	material.set_shader_parameter("boundary_count",polygon.size())
	var boundary := polygon.duplicate()
	boundary.resize(32)
	material.set_shader_parameter("boundary",boundary)
	composer.city._surface(composer.active_owner,"WornGround",polygon,0.009,material,4.0)

func _wash_station() -> void:
	_part("prop_yard_concrete",Vector3(0,0.035,0),Vector3(1.8,0.07,1.5))
	for x in [-0.5,0.5]:
		_part("prop_yard_concrete",Vector3(x,0.4,0),Vector3(0.18,0.8,0.65))
	_part("prop_yard_concrete",Vector3(0,0.82,0),Vector3(1.35,0.15,0.85))
	for x in [-0.62,0.62]:
		_part("prop_yard_concrete",Vector3(x,1.0,0),Vector3(0.12,0.35,0.85))
	for z in [-0.37,0.37]:
		_part("prop_yard_concrete",Vector3(0,1.0,z),Vector3(1.2,0.35,0.12))
	_part("water",Vector3(0,0.96,0),Vector3(1.1,0.012,0.62))
	_part("prop_yard_metal",Vector3(0,1.18,0.37),Vector3(0.035,0.45,0.035),0,"cylinder")
	_part("prop_yard_metal",Vector3(0,1.38,0.24),Vector3(0.045,0.045,0.28))
	_part("water",Vector3(0,1.16,0.12),Vector3(0.018,0.4,0.018),0,"cylinder")
	_part("prop_wood",Vector3(0.86,0.33,0.2),Vector3(0.08,0.66,0.08))
	_part("prop_wood",Vector3(0.86,0.55,-0.05),Vector3(0.07,0.08,0.58))
	_solid(Vector3(0,0.58,0),Vector3(1.4,1.16,0.85))

func _clothesline(variant: int) -> void:
	for x in [-2.3,2.3]:
		_part("prop_wood",Vector3(x,1.1,0),Vector3(0.12,2.2,0.12))
		_part("prop_wood",Vector3(x,2.05,0),Vector3(0.09,0.09,1.5))
		_solid(Vector3(x,1.1,0),Vector3(0.14,2.2,0.14))
	for row in range(3):
		var z := (row-1)*0.6
		_part("prop_yard_metal",Vector3(0,2.04,z),Vector3(4.6,0.012,0.012))
		for index in range(3+(row+variant)%2):
			var x := -1.6+index*1.05
			var material: String = ["linen","blue","rust"][(index+row+variant)%3]
			_part(material,Vector3(x,2.04,z),Vector3(0.67,0.85+0.12*(index%2),1),0,"cloth")
			for side in [-1,1]:
				_part("prop_wood",Vector3(x+side*0.27,2.04,z),Vector3(0.025,0.075,0.035))

func _garden() -> void:
	for row in range(3):
		var x := (row-1)*1.1
		_part("soil",Vector3(x,0.09,0),Vector3(0.82,0.18,3.8))
		for side in [-1,1]:
			_part("prop_wood",Vector3(x+side*0.44,0.12,0),Vector3(0.055,0.24,3.9))
		for index in range(6):
			var offset := Vector3(x,0.18,-1.5+index*0.6)
			_plant(offset,0.5 if row==0 else 0.85,index+row)
			if row == 2:
				_part("prop_wood",offset+Vector3.UP*0.5,Vector3(0.025,1.0,0.025))
				_part("rust",offset+Vector3(0.12,0.62,0),Vector3(0.12,0.12,0.10),0,"pot")

func _compost() -> void:
	for level in range(6):
		var y := 0.1+level*0.15
		for side in [-1,1]:
			_part("prop_wood",Vector3(side*0.62,y,0),Vector3(0.065,0.11,1.2))
		_part("prop_wood",Vector3(0,y,0.58),Vector3(1.3,0.11,0.065))
		if level < 3:
			_part("prop_wood",Vector3(0,y,-0.58),Vector3(1.3,0.11,0.065))
	_part("soil",Vector3(0,0.28,0),Vector3(1.1,0.5,1.05))
	for index in range(12):
		_part("green_light",Vector3(-0.4+(index%4)*0.26,0.54,-0.3+floori(index/4.0)*0.25),Vector3(0.16,0.12,0.25),PI/2,"leaf")
	_solid(Vector3(0,0.46,0),Vector3(1.3,0.92,1.3))

func _logs() -> void:
	for row in range(3):
		for index in range(5-row):
			_part("prop_wood",Vector3(0,0.2+row*0.24,-0.55+index*0.28+row*0.14),Vector3(0.25,1.7,0.25),PI/2,"cylinder")
	for side in [-1,1]:
		for z in [-0.65,0.65]:
			_part("prop_wood",Vector3(side*0.94,0.57,z),Vector3(0.10,1.14,0.10))
	_part("prop_yard_metal",Vector3(0,1.23,0),Vector3(2.15,0.045,1.65),0.1)
	_solid(Vector3(0,0.6,0),Vector3(2.15,1.2,1.65))

func _pots() -> void:
	for index in range(3):
		var offset := Vector3(-0.5+index*0.48,0,0.18*(index%2))
		var height := 0.34+index*0.06
		_part("prop_yard_ceramic",offset+Vector3.UP*height/2,Vector3(0.4,height,0.4),0,"pot")
		_part("soil",offset+Vector3.UP*(height+0.002),Vector3(0.34,0.018,0.34),0,"cylinder")
		_plant(offset+Vector3.UP*height,0.55,index)
	_solid(Vector3(0,0.22,0),Vector3(1.5,0.44,0.65))

func _trellis() -> void:
	for side in [-1,1]:
		_part("prop_wood",Vector3(side*1.2,1.15,0),Vector3(0.10,2.3,0.10))
		_solid(Vector3(side*1.2,1.15,0),Vector3(0.12,2.3,0.12))
	for level in range(6):
		_part("prop_wood",Vector3(0,0.35+level*0.35,0),Vector3(2.5,0.035,0.035))
	for index in range(9):
		var x := -1.08+index*0.27
		_part("prop_wood",Vector3(x,1.3,0),Vector3(0.025,2.05,0.035))
		_plant(Vector3(x,0,0),1.7+0.2*(index%3),index)

func _coop() -> void:
	for x in [-0.8,0.8]:
		for z in [-0.65,0.65]:
			_part("prop_wood",Vector3(x,0.5,z),Vector3(0.12,1.0,0.12))
	_part("prop_wood",Vector3(0,0.65,0),Vector3(1.9,0.1,1.6))
	for index in range(12):
		var x := -0.85+index*0.155
		_part("prop_wood",Vector3(x,1.25,0.75),Vector3(0.14,1.1,0.06))
		if index < 4 or index > 7:
			_part("prop_wood",Vector3(x,1.25,-0.75),Vector3(0.14,1.1,0.06))
	for side in [-1,1]:
		_part("prop_wood",Vector3(side*0.9,1.25,0),Vector3(0.07,1.1,1.5))
		_part("prop_yard_metal",Vector3(side*0.51,1.94,0),Vector3(1.16,0.05,1.95),-side*0.4)
	composer._part("prop_wood",center+Basis(Vector3.UP,yaw)*Vector3(0,0.35,-1.23),Vector3(1.32,0.07,0.55),yaw+PI/2,atan2(0.65,1.15))
	for index in range(5):
		_part("prop_wood",Vector3(0,0.09+index*0.13,-1.79+index*0.23),Vector3(0.6,0.05,0.06))
	_solid(Vector3(0,1.0,0),Vector3(1.9,2.0,1.6))
