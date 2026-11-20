extends RefCounted
const BASE := "res://staging/e06_world/arroio/"
var finish = preload("res://staging/e06_world/arroio/scripts/z2_finish.gd")

func configure(city: Node3D) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/regional_roads.json"))
	var owner := Node3D.new();owner.name="RegionalRoads";city.add_child(owner)
	var rural: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/rural_lrp03_lrp05.json"))
	var sample: Node3D = load(rural.props.cerca_rustica.path).instantiate()
	var wood: StandardMaterial3D = city._find_material(sample).duplicate()
	wood.vertex_color_use_as_albedo=false;wood.albedo_color=Color(.38,.32,.23);wood.roughness=.97
	sample.free()
	var concrete: StandardMaterial3D = finish.soil(city,"service").duplicate()
	concrete.albedo_color=Color(.45,.44,.39)
	var wire := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code="shader_type spatial; render_mode cull_disabled; void fragment(){vec2 cell=abs(fract(UV*5.0)-vec2(.5));if(max(cell.x,cell.y)<.477){discard;}ALBEDO=vec3(.23,.22,.17);ROUGHNESS=.92;METALLIC=.35;}"
	wire.shader=shader
	for key in data.links:
		var link: Dictionary = data.links[key]
		city._buffer(city.get_node("Terrain/Pavements"),key,link.points,float(link.width),.047,finish.soil(city,link.material))
	var r: Array = data.playable_rect
	for edge in [
		["North",Vector2(r[0],r[1]),Vector2(r[2],r[1])],
		["East",Vector2(r[2],r[1]),Vector2(r[2],r[3])],
		["South",Vector2(r[2],r[3]),Vector2(r[0],r[3])],
		["West",Vector2(r[0],r[3]),Vector2(r[0],r[1])]]:
		_fence(owner,edge[0],edge[1],edge[2],float(data.fence_height_m),wood,wire)
	for key in data.links:
		var link: Dictionary = data.links[key]
		var gate := Node3D.new();gate.name=key+"_Blockade";owner.add_child(gate)
		gate.position=Vector3(link.gate[0],0,link.gate[1])
		var normal := Vector3(link.normal[0],0,link.normal[1])
		var side := Vector3(-normal.z,0,normal.x)
		gate.rotation.y=atan2(side.x,side.z)
		# Four concrete modules and the continuous fence close the road and shoulders.
		for offset in [-4.05,-1.35,1.35,4.05]:
			_box(gate,"ConcreteBlock",Vector3(0,.6,offset),Vector3(1.05,1.2,2.55),concrete,true)
		var sign := Node3D.new();sign.name="InterdictionSign";owner.add_child(sign)
		sign.position=Vector3(link.gate[0],0,link.gate[1])-normal*7+side*8
		sign.rotation.y=atan2(-normal.x,-normal.z)
		_box(sign,"SignPost",Vector3(-1.7,1.5,0),Vector3(.14,3,.14),wood,true)
		_box(sign,"SignPost",Vector3(1.7,1.5,0),Vector3(.14,3,.14),wood,true)
		_box(sign,"SignBoard",Vector3(0,2.5,0),Vector3(4.8,1.6,.10),wood,false)
		var label := Label3D.new()
		label.name="Destination";label.text=str(link.destination)+"\nESTRADA INTERDITADA"
		label.position=Vector3(0,2.5,.065);label.font_size=42;label.pixel_size=.006
		label.modulate=Color(.92,.89,.72);label.outline_size=4;label.no_depth_test=false
		sign.add_child(label)
	city.set_meta("regional_road_count",data.links.size())

func _box(owner: Node3D, title: String, center: Vector3, size: Vector3, material: Material, collision: bool) -> void:
	var mesh := BoxMesh.new();mesh.size=size
	var node := MeshInstance3D.new();node.name=title;node.mesh=mesh;node.material_override=material;node.position=center;owner.add_child(node)
	if collision:
		var body := StaticBody3D.new();body.name=title+"Collision";body.position=center;body.collision_layer=1
		body.add_to_group("regional_progression_barrier");body.set_meta("climbable",false);body.set_meta("locked",true)
		var shape := BoxShape3D.new();shape.size=size
		var collider := CollisionShape3D.new();collider.shape=shape;body.add_child(collider);owner.add_child(body)

func _fence(owner: Node3D, title: String, a: Vector2, b: Vector2, height: float, wood: Material, wire: Material) -> void:
	var edge := Node3D.new();edge.name=title+"Boundary";owner.add_child(edge)
	var length := a.distance_to(b)
	edge.position=Vector3((a.x+b.x)/2,0,(a.y+b.y)/2)
	edge.rotation.y=atan2(b.x-a.x,b.y-a.y)
	var shape := BoxShape3D.new();shape.size=Vector3(.18,height,length+.3)
	var body := StaticBody3D.new();body.name="RegionalBoundaryCollision";body.position.y=height/2;body.collision_layer=1
	body.add_to_group("regional_progression_barrier");body.set_meta("climbable",false);body.set_meta("locked",true)
	var collider := CollisionShape3D.new();collider.shape=shape;body.add_child(collider);edge.add_child(body)
	var posts := MultiMesh.new();posts.transform_format=MultiMesh.TRANSFORM_3D
	var post := BoxMesh.new();post.size=Vector3(.14,height+.15,.14)
	posts.mesh=post;posts.instance_count=ceili(length/6)+1
	for i in posts.instance_count:
		posts.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,height/2,-length/2+length*i/(posts.instance_count-1))))
	var instances := MultiMeshInstance3D.new();instances.name="FencePosts";instances.multimesh=posts;instances.material_override=wood;edge.add_child(instances)
	var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(0,0,-length/2),Vector3(0,0,length/2),Vector3(0,height,length/2),Vector3(0,height,-length/2)]
	var uvs := [Vector2(0,0),Vector2(length,0),Vector2(length,height),Vector2(0,height)]
	for i in [0,1,2,0,2,3]:
		tool.set_normal(Vector3.RIGHT);tool.set_uv(uvs[i]);tool.add_vertex(points[i])
	var mesh := MeshInstance3D.new();mesh.name="WireFence";mesh.mesh=tool.commit();mesh.material_override=wire;edge.add_child(mesh)
