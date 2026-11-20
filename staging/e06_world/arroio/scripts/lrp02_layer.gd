extends RefCounted
const DATA := "res://staging/e06_world/arroio/data/lrp02.json"
var geometry = preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new()

static func adjusted(city: Node3D, name: String, data: Variant) -> Variant:
	if not city.apply_lrp02 or name not in ["city_master","landscape","ground_cover"]:return data
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	match name:
		"city_master":data.extent_xz=definition.extent_xz
		"landscape":data.trees.append_array(definition.trees)
		"ground_cover":data.items.append_array(definition.ground_cover)
	return data

func configure(city: Node3D) -> void:
	var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var owner := Node3D.new()
	owner.set_script(load("res://staging/e06_world/arroio/scripts/lrp02_runtime.gd"))
	owner.name="LRP02"
	owner.position=Vector3(950,0,500)
	city.add_child(owner)
	for key in definition.models:
		var model: Dictionary = definition.models[key]
		var visual: Node3D = load(model.visual_path).instantiate()
		visual.name=key
		owner.add_child(visual)
		var faces := PackedVector3Array()
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			var title := str(mesh.name)
			if title in model.hidden_meshes:
				mesh.visible=false;mesh.set_meta("keep_individual_visual",true)
				continue
			if "PLACAR_IDENTIFICACAO" in title:mesh.position.x+=6.0
			# Source service wings overlap the pavilion entry/upper floors.
			for prefix in {"LAVANDERIA_":12.0,"VISITAS_":11.0,"COZINHA_":5.0,"ENFERMARIA_":5.0}:
				if title.begins_with(prefix):mesh.position.z+={"LAVANDERIA_":12.0,"VISITAS_":11.0,"COZINHA_":5.0,"ENFERMARIA_":5.0}[prefix]
			if "_CELA_E" in title and title.ends_with("_PRATELEIRA"):mesh.position.x-=7.0
			if ("_SANITARIOS_E_LATERAL_DIR" in title or "_SANITARIOS_D_LATERAL_ESQ" in title):
				_portal_wall(mesh,owner,faces)
				continue
			if key=="exterior" and ("COBERTURA" in title or "TELHADO" in title):
				mesh.set_meta("prison_roof",true)
				mesh.set_meta("keep_individual_visual",true)
			if key in ["interior","frames"]:
				for floor_index in [1,2,3]:
					if "_P"+str(floor_index)+"_" in title:
						mesh.set_meta("prison_floor",floor_index)
						mesh.set_meta("keep_individual_visual",true)
			if key=="exterior" and title.begins_with("PAVILHAO_"):
				var box: AABB = mesh.mesh.get_aabb()
				if "_R02C_" in title and box.size.y>4.1:
					_shell_floors(mesh,owner)
				elif not mesh.has_meta("prison_roof"):
					mesh.set_meta("prison_floor",clampi(floori((box.get_center().y-.3)/4.05)+1,1,3))
					mesh.set_meta("keep_individual_visual",true)
			if key=="stairs":
				mesh.set_meta("prison_floor",1 if "_L1_" in title else 2)
				mesh.set_meta("keep_individual_visual",true)
			if title in model.step_meshes or (key=="stairs" and "PATAMAR" in title):continue
			geometry._append_faces(mesh,owner,faces)
		geometry._collision(owner,faces,key+"Collision")
	for x in [-58.0,58.0]:
		for floor_index in range(2):
			_stair_ramp(owner,x,.555+floor_index*4.05)
	# Source front gate was a closed proxy. Retain a clear portal in the review scene.
	_gate(owner)
	owner.configure_doors(definition.doors)
	city._buffer(city.get_node("Terrain/Pavements"),"LRP02_AccessRoad",definition.road,6,.035,city.material_cache.road)
	# Main gate approach has an explicit transition into the courtyard level.
	geometry._ramp(owner,0,7,104,79,-.025,.12,"PrisonGateApron",city.material_cache.paving)
	geometry._ramp(owner,0,7,114,111.7,-.025,.115,"RuralRoadCurb",city.material_cache.paving)
	geometry._ramp(owner,0,7,111.7,109,.115,.115,"RuralRoadLanding",city.material_cache.paving)
	for x in [-58.0,58.0]:
		geometry._ramp(owner,x,3,17,14,-.025,.555,"PavilionEntrance"+str(x),city.material_cache.paving)

func _stair_ramp(owner: Node3D, x: float, low: float) -> void:
	var high := low+4.05
	var points := PackedVector3Array()
	for side in [-1,1]:
		points.append(Vector3(x+side*1.15,low-.15,13.5))
		points.append(Vector3(x+side*1.15,low,13.5))
		points.append(Vector3(x+side*1.15,high-.15,8.1))
		points.append(Vector3(x+side*1.15,high,8.1))
	var shape := ConvexPolygonShape3D.new()
	shape.points=points
	var body := StaticBody3D.new()
	body.name="StairRamp_"+str(x)+"_"+str(low)
	var collider := CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	owner.add_child(body)
	geometry._ramp(owner,x,2.3,8.1,6.5,high,high,"StairLanding"+str(x)+str(low))

func _gate(owner: Node3D) -> void:
	var pivot := Node3D.new()
	pivot.name="MainGateOpen"
	pivot.position=Vector3(-6.5,0,82.5)
	pivot.rotation.y=-PI/2
	owner.add_child(pivot)
	var body := StaticBody3D.new()
	body.position=Vector3(6.5,3.3,0)
	pivot.add_child(body)
	var shape := BoxShape3D.new()
	shape.size=Vector3(13,6.6,.25)
	var collider := CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size=shape.size
	mesh.mesh=box
	var material := StandardMaterial3D.new()
	material.albedo_color=Color(.23,.29,.27)
	material.metallic=.6;material.roughness=.72
	mesh.material_override=material
	body.add_child(mesh)

func _portal_wall(source: MeshInstance3D, owner: Node3D, faces: PackedVector3Array) -> void:
	var box := source.mesh.get_aabb()
	var low := box.position
	var high := box.end
	var z0 := -38.35
	var z1 := -36.93
	var top := low.y+2.34
	var pieces: Array = []
	if low.z<z0:pieces.append(AABB(low,Vector3(box.size.x,box.size.y,z0-low.z)))
	if high.z>z1:pieces.append(AABB(Vector3(low.x,low.y,z1),Vector3(box.size.x,box.size.y,high.z-z1)))
	pieces.append(AABB(Vector3(low.x,top,maxf(low.z,z0)),Vector3(box.size.x,high.y-top,minf(high.z,z1)-maxf(low.z,z0))))
	for index in pieces.size():
		var part: AABB = pieces[index]
		var mesh := MeshInstance3D.new()
		mesh.name=str(source.name)+"_Portal_"+str(index)
		var shape := BoxMesh.new()
		shape.size=part.size
		mesh.mesh=shape
		mesh.position=part.get_center()
		mesh.material_override=source.get_active_material(0)
		for level in [1,2,3]:
			if "_P"+str(level)+"_" in str(source.name):mesh.set_meta("prison_floor",level)
		mesh.set_meta("keep_individual_visual",true)
		owner.add_child(mesh)
		geometry._append_faces(mesh,owner,faces)
	source.visible=false
	source.set_meta("keep_individual_visual",true)

func _shell_floors(source: MeshInstance3D, owner: Node3D) -> void:
	var box := source.mesh.get_aabb()
	var material: StandardMaterial3D = source.get_active_material(0).duplicate()
	var arrays := source.mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	if not colors.is_empty():material.albedo_color*=colors[0]
	material.vertex_color_use_as_albedo=false
	for level in [1,2,3]:
		var bottom := maxf(box.position.y,.26+(level-1)*4.05)
		var top := minf(box.end.y,.26+level*4.05)
		if top<=bottom:continue
		var mesh := MeshInstance3D.new()
		mesh.name=str(source.name)+"_Level"+str(level)
		var shape := BoxMesh.new()
		shape.size=Vector3(box.size.x,top-bottom,box.size.z)
		mesh.mesh=shape
		mesh.position=Vector3(box.get_center().x,(bottom+top)/2,box.get_center().z)
		mesh.material_override=material
		mesh.set_meta("prison_floor",level)
		mesh.set_meta("keep_individual_visual",true)
		owner.add_child(mesh)
	source.visible=false
	source.set_meta("keep_individual_visual",true)
