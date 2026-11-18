extends RefCounted
## Provisional civic shells use the existing Z2 palette and shared primitives.
var dressing: Node3D

func configure(owner: Node3D) -> void:
	dressing = owner
	var data: Dictionary = dressing.city.catalog("civic_infrastructure")
	var source: Node3D = load(data.material_source).instantiate()
	for pair in [["civic_roof","ceramic"],["civic_glass","glass"],["civic_wall","plaster"],["civic_trim","concrete"]]:
		dressing.palette[pair[0]] = dressing._find_material(source,pair[1])
	source.free()
	dressing.palette.civic_roof = dressing.palette.civic_roof.duplicate(false)
	dressing.palette.civic_roof.uv1_scale = Vector3(4,4,1)
	for item in data.buildings:
		dressing._owner(item.sector,item.id+"_Civic")
		dressing.active_owner.set_meta("civic_candidate",item)
		building(item)
		dressing._flush()
	for pole in data.poles:
		dressing._owner(pole.sector,pole.id+"_Utility")
		var center := Vector3(pole.position[0],0,pole.position[1])
		if not pole.existing_lamp:
			dressing._part("masonry",center+Vector3.UP*3.2,Vector3(.18,6.4,.18))
			dressing._collision(center+Vector3.UP*3.2,Vector3(.22,6.4,.22))
		else:
			dressing._part("metal",center+Vector3.UP*5.8,Vector3(.1,1.2,.1))
		var arm := Vector3(pole.crossarm_xz[0],0,pole.crossarm_xz[1])
		dressing._part("metal",center+Vector3.UP*6.25,Vector3(1.05,.1,.12),atan2(-arm.z,arm.x))
		for offset in [-.42,0.0,.42]:
			dressing._part("civic_trim",center+Vector3.UP*6.35+arm*offset,Vector3(.09,.1,.09))
		dressing._flush()
	var wire_root := Node3D.new()
	wire_root.name = "UtilityWires"
	dressing.add_child(wire_root)
	var poles := {}
	for pole in data.poles: poles[pole.id] = pole
	for span in data.spans:
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES,dressing.palette.metal)
		var a: Dictionary = poles[span.a]
		var b: Dictionary = poles[span.b]
		for offset in [-.42,0.0,.42]:
			for index in range(16):
				for t in [index/16.0,(index+1)/16.0]:
					var p := Vector3(lerpf(a.position[0]+a.crossarm_xz[0]*offset,b.position[0]+b.crossarm_xz[0]*offset,t),span.height_m-4*span.sag_m*t*(1-t),lerpf(a.position[1]+a.crossarm_xz[1]*offset,b.position[1]+b.crossarm_xz[1]*offset,t))
					mesh.surface_add_vertex(p)
		mesh.surface_end()
		var visual := MeshInstance3D.new()
		visual.name = span.id
		visual.mesh = mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual.set_meta("utility_sectors",span.sectors)
		wire_root.add_child(visual)

func local_part(key: String, center: Vector3, yaw: float, offset: Vector3, dimensions: Vector3, roll: float = 0.0) -> void:
	dressing._local(key,center,yaw,offset,dimensions,roll)

func building(item: Dictionary) -> void:
	var c := Vector3(item.position[0],0,item.position[1])
	var yaw := deg_to_rad(item.yaw_degrees)
	var w: float = item.width_m
	var d: float = item.depth_m
	var h: float = item.wall_height_m
	var door_w := 1.7 if item.kind=="chapel" else 2.4
	local_part("civic_trim",c,yaw,Vector3(0,.09,0),Vector3(w+.25,.18,d+.25))
	# Four walls are separate, leaving an actual opening behind the closed door.
	for side in [-1.0,1.0]:
		local_part("civic_wall",c,yaw,Vector3(side*w/2,h/2,0),Vector3(.2,h,d))
		local_part("civic_wall",c,yaw,Vector3(side*(w+door_w)/4,h/2,-d/2),Vector3((w-door_w)/2,h,.2))
	local_part("civic_wall",c,yaw,Vector3(0,h/2,d/2),Vector3(w,h,.2))
	local_part("civic_wall",c,yaw,Vector3(0,(h+2.5)/2,-d/2),Vector3(door_w,h-2.5,.2))
	local_part("wood" if item.kind=="chapel" else "metal",c,yaw,Vector3(0,1.25,-d/2-.025),Vector3(door_w-.08,2.5,.08))
	local_part("civic_trim",c,yaw,Vector3(0,.1,-d/2-.38),Vector3(door_w+.6,.2,.7))
	for side in [-1.0,1.0]:
		for z in [-d*.23,d*.22]:
			local_part("wood",c,yaw,Vector3(side*(w/2+.11),2.0,z),Vector3(.08,1.4,1.15))
			local_part("civic_glass",c,yaw,Vector3(side*(w/2+.16),2.0,z),Vector3(.04,1.2,.95))
	var roof_half := w/2+.35
	var rise: float = item.roof_rise_m
	var angle := atan2(rise,roof_half)
	for side in [-1.0,1.0]:
		local_part("civic_roof",c,yaw,Vector3(side*roof_half/2,h+rise/2,0),Vector3(sqrt(roof_half*roof_half+rise*rise),.16,d+.7),-side*angle)
	# Gable infill is tiled with the same UV-bearing wall primitive.
	for index in range(12):
		var strip_h := rise/12
		var strip_w := w*(1-(index+.5)/12.0)
		for side in [-1.0,1.0]:
			local_part("civic_wall",c,yaw,Vector3(0,h+(index+.5)*strip_h,side*d/2),Vector3(strip_w,strip_h,.18))
	if item.kind=="chapel":
		# Small bell-cote, a cross and entrance surround distinguish the chapel.
		local_part("civic_wall",c,yaw,Vector3(0,h+rise+.35,-d/2+.6),Vector3(1.1,.9,.9))
		local_part("wood",c,yaw,Vector3(0,h+rise+1.35,-d/2+.6),Vector3(.12,1.35,.12))
		local_part("wood",c,yaw,Vector3(0,h+rise+1.55,-d/2+.6),Vector3(.75,.12,.12))
		local_part("wood",c,yaw,Vector3(0,2.8,-d/2-.13),Vector3(door_w+.4,.16,.18))
	else:
		local_part("civic_trim",c,yaw,Vector3(0,2.94,-d/2-.13),Vector3(w-.5,.5,.16))
		local_part("metal",c,yaw,Vector3(0,2.65,-d/2-.65),Vector3(w-.35,.12,1.3))
		var sign := Label3D.new()
		sign.name = "ProposedUse"
		sign.text = item.proposed_use.to_upper()
		sign.font_size = 48
		sign.pixel_size = .004
		sign.modulate = Color(.16,.21,.18)
		sign.outline_size = 0
		sign.position = c+Basis(Vector3.UP,yaw)*Vector3(0,2.94,-d/2-.23)
		sign.rotation.y = yaw+PI
		dressing.active_owner.add_child(sign)
	# Closed exterior shell, no explorable interior promised in this candidate.
	dressing._collision(c+Vector3.UP*h/2,Vector3(w,h,d),yaw)
	var apron := [Vector2(-w/2-.4,-d/2-1.3),Vector2(w/2+.4,-d/2-1.3),Vector2(w/2+.4,-d/2),Vector2(-w/2-.4,-d/2)]
	var polygon := PackedVector2Array()
	for p in apron:
		var v := c+Basis(Vector3.UP,yaw)*Vector3(p.x,0,p.y)
		polygon.append(Vector2(v.x,v.z))
	dressing.city._surface(dressing.active_owner,item.id+"_Apron",polygon,.028,dressing.city.material_cache.paving,2)
	dressing.city._buffer(dressing.active_owner,item.id+"_Access",item.access_path,1.8,.029,dressing.city.material_cache.paving)
