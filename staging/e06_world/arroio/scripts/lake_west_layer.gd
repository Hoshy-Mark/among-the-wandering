extends RefCounted
const BASE := "res://staging/e06_world/arroio/"
const DATA := BASE+"data/lake_west.json"
var geometry = preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new()
var cabin_shader: Shader
var cabin_materials: Dictionary = {}
var surface_details: Dictionary = {}

static func adjusted(city: Node3D, name: String, data: Variant) -> Variant:
	if not city.apply_lrp01 or name not in ["city_master","landscape","ground_cover"] or not FileAccess.file_exists(DATA):return data
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if name=="city_master":data.extent_xz=definition.extent_xz
	elif name=="landscape":
		data.trees=data.trees.filter(func(tree):return not definition.removed_tree_keys.has("%s:%.3f:%.3f" % [tree.asset,tree.position[0],tree.position[1]]))
	elif name=="ground_cover" and definition.has("removed_cover_keys"):
		data.items=data.items.filter(func(item):return not definition.removed_cover_keys.has("%s:%.3f:%.3f" % [item.asset,item.position[0],item.position[1]]))
	return data

func configure(city: Node3D) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/lrp01.json"))
	surface_details=JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/rural_lrp03_lrp05.json")).surface_details
	cabin_shader=Shader.new()
	# The supplied cabin uses two-sided roof sheets. Preserve that property in PBR.
	cabin_shader.code=FileAccess.get_file_as_string(BASE+"scripts/rural_surface.gdshader").replace("render_mode cull_back;","render_mode cull_disabled;")
	var owner := Node3D.new()
	owner.name="LRP01"
	city.add_child(owner)
	var ground: ShaderMaterial = city.get_node("Terrain/Ground/FlatSouthernGround").material_override
	var rectangle: Array = data.terrain_rect
	ground.set_shader_parameter("exclude_lake_terrain",true)
	ground.set_shader_parameter("lake_terrain_rect",Vector4(rectangle[0],rectangle[1],rectangle[2],rectangle[3]))
	var field: ShaderMaterial = ground.duplicate(false)
	field.set_shader_parameter("exclude_lake_terrain",false)
	var bank: ShaderMaterial = field.duplicate(false)
	bank.set_shader_parameter("surface_kind",3.0)
	bank.set_shader_parameter("surface_strength",.73)
	if data.has("shore_revision"):
		var shore_shader := Shader.new()
		shore_shader.code=field.shader.code.replace("surface_strength*regrowth","surface_strength*regrowth*smoothstep(0.02,0.9,COLOR.r)*(0.7+0.3*noise21(p/3.7))")
		bank.shader=shore_shader
		bank.set_shader_parameter("surface_strength",.86)
	var outer_faces := PackedVector3Array()
	var bank_faces := PackedVector3Array()
	for i in data.shoreline.size():
		var j: int = (i+1)%data.shoreline.size()
		var a := Vector2(data.shoreline[i][0],data.shoreline[i][1])
		var b := Vector2(data.shoreline[j][0],data.shoreline[j][1])
		var center := Vector2(data.center[0],data.center[1])
		var wa: float = float(data.bank_widths[i]) if data.has("bank_widths") else 7.0
		var wb: float = float(data.bank_widths[j]) if data.has("bank_widths") else 7.0
		var ma := a+(a-center).normalized()*wa
		var mb := b+(b-center).normalized()*wb
		var oa := Vector2(data.outer_ring[i][0],data.outer_ring[i][1])
		var ob := Vector2(data.outer_ring[j][0],data.outer_ring[j][1])
		_quad(bank_faces,Vector3(a.x,-.065,a.y),Vector3(b.x,-.065,b.y),Vector3(mb.x,-.02,mb.y),Vector3(ma.x,-.02,ma.y))
		_quad(outer_faces,Vector3(ma.x,-.02,ma.y),Vector3(mb.x,-.02,mb.y),Vector3(ob.x,-.02,ob.y),Vector3(oa.x,-.02,oa.y))
	_surface(owner,"NaturalShore",bank_faces,bank,data.has("shore_revision"))
	_surface(owner,"PampaBank",outer_faces,field)
	var terrain_faces := outer_faces.duplicate()
	terrain_faces.append_array(bank_faces)
	geometry._collision(owner,terrain_faces,"BankTerrainCollision")
	for island in data.get("islands",[]):
		var title: String = str(island.id)
		city._surface(owner,title,city._points(island.polygon),-.02,field,3.0)
		var mesh: MeshInstance3D = owner.get_node(title)
		var faces := PackedVector3Array()
		geometry._append_faces(mesh,owner,faces)
		geometry._collision(owner,faces,title+"Collision")
	_cut_ground(city,rectangle)
	var water := ShaderMaterial.new()
	water.shader=load(BASE+"scripts/lrp01_water.gdshader")
	water.set_shader_parameter("shore_depth",ImageTexture.create_from_image(Image.load_from_file(data.depth_texture)))
	water.set_shader_parameter("depth_origin",Vector2(rectangle[0],rectangle[1]))
	water.set_shader_parameter("depth_size",Vector2(rectangle[2]-rectangle[0],rectangle[3]-rectangle[1]))
	city._surface(owner,"WesternLakeWater",city._points(data.shoreline),-.092,water,3.0)
	preload("res://staging/e06_world/arroio/scripts/lrp01_layer.gd").new()._shore_barrier(owner,data.shoreline)
	var finish = preload("res://staging/e06_world/arroio/scripts/z2_finish.gd")
	var dirt: StandardMaterial3D = finish.soil(city,"dry").duplicate()
	dirt.albedo_color=Color(.5,.51,.45)
	city._buffer(city.get_node("Terrain/Pavements"),"WestLake_CoastRoad",data.road,float(data.get("road_width_m",4.5)),.035,dirt)
	city._buffer(city.get_node("Terrain/Pavements"),"WestLake_CityConnection",data.connection,4.8,.038,dirt)
	for cabin in data.cabins:
		_cabin(city,owner,cabin,data,original,dirt)
	if data.has("life_revision"):
		load(BASE+"scripts/lake_life_layer.gd").new().configure(city,owner,data,field,self)
	if data.has("regional_revision"):
		load(BASE+"scripts/regional_roads_layer.gd").new().configure(city)
	_wetland(owner,data)
	city.set_meta("western_lake_area_m2",data.water_area_m2)

func _cabin(city: Node3D, lake: Node3D, cabin: Dictionary, data: Dictionary, original: Dictionary, dirt: Material) -> void:
	var owner := Node3D.new()
	owner.set_script(load(BASE+"scripts/rural_runtime.gd"))
	owner.name=cabin.id
	owner.position=Vector3(cabin.position[0],0,cabin.position[1])
	owner.rotation_degrees.y=cabin.yaw
	owner.add_to_group("z2_finish_owner")
	lake.add_child(owner)
	var visual: Node3D = load(data.cabin_source).instantiate()
	visual.name="Visual"
	# Source cabin stays at its original metric dimensions; only its origin changes.
	visual.position=Vector3(-67,-.13,24)
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name) not in data.cabin_meshes:
			mesh.get_parent().remove_child(mesh)
			mesh.free()
	owner.add_child(visual)
	var faces := PackedVector3Array()
	var roofs: Array = []
	var roof_zones: Dictionary = {}
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		var title := str(mesh.name)
		if title=="R02_VARANDA_TABUAS_PISO":mesh.position.y=-.394
		if title not in original.site.collision_excluded_meshes:
			geometry._append_faces(mesh,owner,faces)
		if any_roof(title):
			var group := "DEP" if "ABRIGO" in title else "CASA"
			var box: AABB = (owner.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
			var zone := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
			roof_zones[group]=zone if not roof_zones.has(group) else roof_zones[group].merge(zone)
			mesh.set_meta("keep_individual_visual",true)
			mesh.set_meta("roof_group",group)
			roofs.append(mesh)
		var source: Material = mesh.get_active_material(0)
		if source is StandardMaterial3D and source.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED:
			mesh.material_override=_cabin_material(source,int(cabin.variant))
	for mesh in roofs:
		mesh.set_meta("roof_zone",roof_zones[mesh.get_meta("roof_group")])
		owner.roofs.append(mesh)
	geometry._collision(owner,faces,"CabinCollision")
	var ramp := Node3D.new()
	ramp.name="PorchTransitions"
	ramp.rotation.y=-PI/2
	owner.add_child(ramp)
	geometry._ramp(ramp,0,2.3,16,9.3,-.02,.455,"PorchRamp",dirt)
	geometry._ramp(ramp,0,1.7,6,4.8,.455,.405,"DoorThreshold")
	var approach: Array = cabin.route.slice(0,cabin.route.size()-3)
	city._buffer(city.get_node("Terrain/Pavements"),str(cabin.id)+"_Approach",approach,1.7,.04,dirt)
	if cabin.dock:_dock(city,lake,cabin,data,dirt)

func _cabin_material(source: StandardMaterial3D, variant: int) -> Material:
	var key := str(source.get_instance_id())+":"+str(variant)
	if cabin_materials.has(key):return cabin_materials[key]
	if source.albedo_texture==null or source.normal_texture==null:return source
	var family: String = preload("res://staging/e06_world/arroio/scripts/z2_finish.gd").new()._family(source.resource_name)
	var material := ShaderMaterial.new()
	material.shader=cabin_shader
	material.set_shader_parameter("detail_texture",source.albedo_texture)
	material.set_shader_parameter("detail_mean",float(surface_details.get(family,{"mean":.5}).mean))
	material.set_shader_parameter("normal_texture",source.normal_texture)
	material.set_shader_parameter("roughness_texture",source.roughness_texture)
	var tint := Color(.90,.94,.87) if variant==1 else Color(.97,.90,.83) if variant==2 else Color.WHITE
	material.set_shader_parameter("base_tint",(source.albedo_color*tint).srgb_to_linear())
	material.set_shader_parameter("metalness",source.metallic)
	material.set_shader_parameter("age_strength",.12 if family=="timber" else .04)
	cabin_materials[key]=material
	return material

func any_roof(title: String) -> bool:
	return "TELHADO" in title or "COBERTURA" in title or "EMPENA" in title or "CUMEEIRA" in title or "ABRIGO_DEP_TELHA" in title

func _dock(city: Node3D, lake: Node3D, cabin: Dictionary, data: Dictionary, dirt: Material) -> void:
	var dock := Node3D.new()
	dock.name=str(cabin.id)+"_Dock"
	var start: Array = cabin.dock_route[1]
	dock.position=Vector3(start[0],0,start[1])
	dock.rotation_degrees.y=cabin.yaw
	lake.add_child(dock)
	var visual: Node3D = load(data.cabin_source).instantiate()
	visual.position=Vector3(-37,0,7.1)
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		var title := str(mesh.name)
		if not (title.begins_with("CAB01_TRAPICHE_") or title.begins_with("CAB01_CANOA_") or title=="CAB01_REMO" or title.begins_with("R02_TRAPICHE_")):
			mesh.get_parent().remove_child(mesh);mesh.free()
	dock.add_child(visual)
	var faces := PackedVector3Array()
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		if "TABUAS" in str(mesh.name):geometry._append_faces(mesh,dock,faces)
	geometry._collision(dock,faces,"DockCollision")
	var ramp := Node3D.new()
	ramp.rotation.y=-PI/2
	dock.add_child(ramp)
	geometry._ramp(ramp,0,1.8,-4,0,-.02,.31,"DockAccessRamp",dirt)
	city._buffer(city.get_node("Terrain/Pavements"),str(cabin.id)+"_FishingTrail",cabin.dock_route.slice(0,2),1.8,.045,dirt)

func _quad(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for triangle in [[a,b,c],[a,c,d]]:
		if (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).y>0:triangle.reverse()
		faces.append_array(PackedVector3Array(triangle))

func _surface(owner: Node3D, title: String, faces: PackedVector3Array, material: Material, colored_shore: bool=false) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in faces:
		tool.set_normal(Vector3.UP)
		tool.set_color(Color(clampf((-.02-point.y)/.045,0,1),0,0,1) if colored_shore else Color.WHITE)
		tool.set_uv(Vector2(point.x,point.z)/3)
		tool.add_vertex(point)
	var mesh := MeshInstance3D.new()
	mesh.name=title;mesh.mesh=tool.commit();mesh.material_override=material
	owner.add_child(mesh)

func _cut_ground(city: Node3D, rect: Array) -> void:
	var old: Node3D = city.get_node("Terrain/Ground/GroundCollision")
	for child in old.get_children():
		if child is CollisionShape3D:child.disabled=true
	var extent: Array = city.catalog("city_master").extent_xz
	for r in [Vector4(extent[0],extent[1],rect[0],extent[3]),Vector4(rect[2],extent[1],extent[2],extent[3]),Vector4(rect[0],extent[1],rect[2],rect[1]),Vector4(rect[0],rect[3],rect[2],extent[3])]:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size=Vector3(r.z-r.x,.2,r.w-r.y)
		var collider := CollisionShape3D.new();collider.shape=shape
		body.add_child(collider);old.add_child(body)
		body.position=Vector3((r.x+r.z)/2,-.1,(r.y+r.w)/2)-old.position

func _wetland(owner: Node3D, data: Dictionary) -> void:
	for key in data.wetland_assets:
		var source: Node3D = load(data.wetland_assets[key].path).instantiate()
		var items: Array = data.wetland.filter(func(item):return item.asset==key)
		for mesh in source.find_children("*","MeshInstance3D",true,false):
			var material := StandardMaterial3D.new()
			material.vertex_color_use_as_albedo=true
			material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=.95
			var multi := MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D
			multi.mesh=mesh.mesh;multi.instance_count=items.size()
			for i in items.size():
				var item: Dictionary = items[i]
				var p: Array = item.position
				multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,deg_to_rad(item.yaw)).scaled(Vector3.ONE*item.scale),Vector3(p[0],p[1],p[2]))*mesh.transform)
			var instance := MultiMeshInstance3D.new()
			instance.name="Z2Shore_"+str(key);instance.multimesh=multi;instance.material_override=material
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			owner.add_child(instance)
		source.free()
