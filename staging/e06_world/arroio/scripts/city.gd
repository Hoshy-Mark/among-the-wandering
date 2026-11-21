extends Node3D
## Deterministic assembly from the audited metric catalog. No gameplay dependencies.
signal city_ready
@export var show_hydrology_reference: bool = false
@export var batch_static_visuals: bool = true
@export var show_yard_details: bool = true
@export var terrain_variation: bool = true
@export var show_landscape: bool = true
@export var apply_lot_overrides: bool = true
@export var apply_master_candidates: bool = true
@export var apply_h11_h20_candidates: bool = true
@export var apply_h21_h30_candidates: bool = true
@export var apply_h31_h40_candidates: bool = true
@export var apply_current_h01_h20_revisions: bool = true
@export var apply_est01_est03_models: bool = true
@export var apply_est04_est09_models: bool = true
@export var apply_civic_vegetation: bool = true
@export var apply_lrp01: bool = true
@export var apply_lrp02: bool = true
@export var apply_rural_models: bool = true
@export var apply_rural_network: bool = true
@export var enable_ambience: bool = true
@export var apply_residential_interiors: bool = true
@export var apply_civic_interiors: bool = true
@export_enum("A", "B") var h02_variant: String = "B"
var static_batcher = preload("res://staging/e06_world/arroio/scripts/static_visual_batcher.gd").new()
const DATA := "res://staging/e06_world/arroio/data/"
var ready_for_integration: bool = false
var material_cache: Dictionary = {}
var catalog_cache114=preload("res://staging/e06_world/arroio/scripts/catalog_cache114.gd").new()

func catalog(name: String) -> Variant:
	return catalog_cache114.fetch(self,name,_load_catalog114)

func invalidate_catalogs114() -> void:
	catalog_cache114.clear()

func _load_catalog114(name: String) -> Variant:
	if name=="lot_overrides":
		var rules: Dictionary = preload("res://staging/e06_world/arroio/scripts/master_lot_layer.gd").rules(self)
		if apply_h11_h20_candidates:rules.lots.merge(preload("res://staging/e06_world/arroio/scripts/h11_h20_layer.gd").rules().lots)
		if apply_h21_h30_candidates:rules.lots.merge(preload("res://staging/e06_world/arroio/scripts/h21_h30_layer.gd").rules().lots)
		if apply_h31_h40_candidates:rules.lots.merge(preload("res://staging/e06_world/arroio/scripts/h31_h40_layer.gd").rules().lots)
		if apply_current_h01_h20_revisions:rules.lots.merge(preload("res://staging/e06_world/arroio/scripts/current_h01_h20_layer.gd").rules(self).lots,true)
		return rules
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA + name + ".json"))
	data=preload("res://staging/e06_world/arroio/scripts/master_lot_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/h11_h20_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/h21_h30_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/h31_h40_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/current_h01_h20_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/est04_est09_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/civic_vegetation_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/lrp01_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/lrp02_layer.gd").adjusted(self,name,data)
	data=preload("res://staging/e06_world/arroio/scripts/rural_layer.gd").adjusted(self,name,data)
	return preload("res://staging/e06_world/arroio/scripts/rural_network_layer.gd").adjusted(self,name,data)

func _ready() -> void:
	var city: Dictionary = catalog("city_master")
	var environment: Dictionary = catalog("environment")
	for key in ["ground", "road", "sidewalk", "dirt", "mosaic", "paving"]:
		var instance: Node = load(environment.assets[key].path).instantiate()
		var material := _find_material(instance)
		if material != null:
			material_cache[key] = material
		else:
			push_error("E07 material not found: " + key)
		instance.free()
	# Keep E07 textures shared; soften only instance-local pavement color.
	for key in ["paving", "sidewalk"]:
		material_cache[key] = material_cache[key].duplicate(false)
		material_cache[key].albedo_color = Color(0.72,0.70,0.64,1.0)
	var e: Array = city.extent_xz
	var ground := PlaneMesh.new()
	# Decorative ground continues beyond the surveyed area; its physical bounds
	# and all urban coordinates remain those of the original metric catalog.
	ground.size = Vector2(e[2]-e[0]+600.0, e[3]-e[1]+600.0)
	var ground_node := MeshInstance3D.new()
	ground_node.name = "FlatSouthernGround"
	ground_node.mesh = ground
	ground_node.position = Vector3((e[0]+e[2])/2.0, -0.02, (e[1]+e[3])/2.0)
	var ground_material := ShaderMaterial.new()
	ground_material.shader = load("res://staging/e06_world/arroio/scripts/ground.gdshader")
	ground_material.set_shader_parameter("terrain_variation",1.0 if terrain_variation else 0.0)
	ground_material.set_shader_parameter("grass_texture", material_cache.ground.albedo_texture)
	ground_material.set_shader_parameter("dirt_texture", material_cache.dirt.albedo_texture)
	if show_landscape:
		var gravel_source: Node3D = load(catalog("landscape").assets.gravel.path).instantiate()
		ground_material.set_shader_parameter("gravel_texture",_find_material(gravel_source).albedo_texture)
		gravel_source.free()
	ground_material.set_shader_parameter("paving_texture",material_cache.paving.albedo_texture)
	ground_node.material_override = ground_material
	$Terrain/Ground.add_child(ground_node)
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundCollision"
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(e[2]-e[0], 0.2, e[3]-e[1])
	ground_shape.shape = box
	ground_body.position = Vector3(ground_node.position.x, -0.1, ground_node.position.z)
	ground_body.add_child(ground_shape)
	$Terrain/Ground.add_child(ground_body)
	for parcel in catalog("parcels"):
		var polygon := _points(parcel.geometry.coordinates[0])
		for inset in Geometry2D.offset_polygon(polygon,-0.6):
			var garden: ShaderMaterial = ground_material.duplicate(false)
			garden.set_shader_parameter("garden_wear",0.16)
			var ident: String = parcel.id
			garden.set_shader_parameter("parcel_tone",float(ident.hash()%7-3)*0.012 if terrain_variation else 0.0)
			garden.set_shader_parameter("boundary_count",mini(inset.size(),32))
			var boundary := PackedVector2Array(inset)
			boundary.resize(32)
			garden.set_shader_parameter("boundary",boundary)
			_surface($Terrain/Pavements,parcel.id + "_Garden",inset,0.002,garden,4.0)
	for road in catalog("roads"):
		var points: Array = road.geometry.coordinates
		var width: float = road.properties.road_width_m_proposed
		var sidewalk_width: float = road.properties.get("sidewalk_width_m_proposed", 0.0)
		# A complete buffered polyline closes corners. Shared world UVs make
		# overlapping junctions continuous; asphalt is above every pavement.
		if sidewalk_width > 0.0:
			_buffer($Terrain/Sidewalks,road.id+"_Sidewalk",points,width+2.0*sidewalk_width,0.014,material_cache.sidewalk)
		_buffer($Terrain/Roads,road.id,points,width,0.038,material_cache.road)
	for feature in catalog("public_spaces"):
		var marker := Node3D.new()
		marker.name = feature.id
		marker.set_meta("source_feature", feature)
		marker.set_meta("status", "original_reference_not_built_or_promoted")
		var coordinates: Array = feature.geometry.coordinates
		if feature.geometry.type == "Point":
			marker.position = Vector3(coordinates[0],0,coordinates[1])
		elif feature.geometry.type == "Polygon":
			var center := Vector3.ZERO
			for p in coordinates[0].slice(0,-1):
				center += Vector3(p[0],0,p[1])
			marker.position = center / float(coordinates[0].size()-1)
		elif feature.geometry.type == "LineString":
			marker.position = Vector3(coordinates[0][0],0,coordinates[0][1])
		$PublicSpaces.add_child(marker)
		if feature.properties["class"] == "public_reserve":
			var polygon := _points(coordinates[0])
			if feature.properties.get("kind","") == "praca":
				_surface($PublicSpaces,feature.id+"_PerimeterWalk",polygon,0.008,material_cache.paving,2.0)
				for garden in Geometry2D.offset_polygon(polygon,-3.0):
					_surface($PublicSpaces,feature.id+"_CentralGarden",garden,0.012,ground_material,4.0)
			else:
				var reserved: ShaderMaterial = ground_material.duplicate(false)
				reserved.set_shader_parameter("garden_wear",0.28)
				_surface($PublicSpaces,feature.id+"_ReservedGround",polygon,0.005,reserved,5.0)
		if feature.properties["class"] in ["pedestrian_route","public_pedestrian_access"]:
			_buffer($Terrain/Pavements,feature.id+"_Walk",coordinates,1.6,0.020,material_cache.paving)
	for tree in environment.trees + environment.placements:
		if not tree.enabled:
			continue
		var instance: Node3D = load(environment.assets[tree.asset].path).instantiate()
		instance.name = tree.id
		# Keep recorded positions and yaw, including the original E07 model pivot.
		instance.position = Vector3(tree.position[0], tree.position[1], tree.position[2])
		instance.rotation_degrees.y = tree.get("rotation_degrees",0)
		instance.set_meta("status", tree.status)
		$Vegetation.add_child(instance)
	$Navigation.set_meta("status", "reserved; NPC navmesh requires verified entrances and agent dimensions")
	var dressing := Node3D.new()
	dressing.set_script(load("res://staging/e06_world/arroio/scripts/urban_components.gd"))
	dressing.name = "UrbanDressing"
	add_child(dressing)
	dressing.configure(self,catalog("urban_dressing"),environment)
	if show_landscape:
		var landscape := Node3D.new()
		landscape.set_script(load("res://staging/e06_world/arroio/scripts/landscape_layer.gd"))
		landscape.name = "Landscape"
		add_child(landscape)
		landscape.configure(self)
	if terrain_variation:
		var cover := Node3D.new()
		cover.set_script(load("res://staging/e06_world/arroio/scripts/ground_cover.gd"))
		cover.name = "GroundCover"
		add_child(cover)
		cover.configure(self,environment)
	# Hydrology is a separate, reversible reference layer, not canonical terrain.
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.18,0.29,0.30,1)
	water.roughness = 0.32
	var wetlands := StandardMaterial3D.new()
	wetlands.albedo_color = Color(0.28,0.34,0.22,1)
	for feature in catalog("urban_dressing").hydrology_reference:
		if not show_hydrology_reference:
			continue
		if feature.geometry.type == "Polygon":
			_surface($PublicSpaces,feature.id+"_IllustrativeWater",_points(feature.geometry.coordinates[0]),0.001,water if "LAGOA" in feature.id else wetlands,8.0)
		else:
			_buffer($PublicSpaces,feature.id+"_IllustrativeCanal",feature.geometry.coordinates,1.8,0.001,water)
	$SpawnPoints.set_meta("status", "reserved; no approved character spawn in source")
	for road in catalog("roads"):
		if road.id != "V01":
			continue
		var coordinates: Array = road.geometry.coordinates
		for index in [0, coordinates.size()-1]:
			var anchor := Marker3D.new()
			anchor.name = "RoadEntry_" + road.id + ("_Start" if index == 0 else "_End")
			anchor.position = Vector3(coordinates[index][0],0,coordinates[index][1])
			anchor.set_meta("status", "source road endpoint; integration candidate; no approved character spawn")
			$SpawnPoints.add_child(anchor)
	if apply_lot_overrides and show_landscape and FileAccess.file_exists(DATA+"lot_overrides.json"):
		preload("res://staging/e06_world/arroio/scripts/lot_art_overrides.gd").new().configure(self)
		if apply_master_candidates:preload("res://staging/e06_world/arroio/scripts/master_lot_layer.gd").new().configure(self)
		if apply_master_candidates and apply_h11_h20_candidates:preload("res://staging/e06_world/arroio/scripts/h11_h20_layer.gd").new().configure(self)
		if apply_master_candidates and apply_h21_h30_candidates:preload("res://staging/e06_world/arroio/scripts/h21_h30_layer.gd").new().configure(self)
		if apply_master_candidates and apply_h31_h40_candidates:preload("res://staging/e06_world/arroio/scripts/h31_h40_layer.gd").new().configure(self)
		if apply_master_candidates and apply_current_h01_h20_revisions:preload("res://staging/e06_world/arroio/scripts/current_h01_h20_layer.gd").new().configure(self)
	if apply_est01_est03_models:preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new().configure(self)
	if apply_est04_est09_models:preload("res://staging/e06_world/arroio/scripts/est04_est09_layer.gd").new().configure(self)
	if apply_lrp01:preload("res://staging/e06_world/arroio/scripts/lrp01_layer.gd").new().configure(self)
	if apply_lrp02:preload("res://staging/e06_world/arroio/scripts/lrp02_layer.gd").new().configure(self)
	if apply_rural_models:preload("res://staging/e06_world/arroio/scripts/rural_layer.gd").new().configure(self)
	if apply_rural_network:preload("res://staging/e06_world/arroio/scripts/rural_network_layer.gd").new().configure(self)
	if apply_civic_interiors and FileAccess.file_exists(DATA+"civic_interiors_return.json"):
		var civic_interiors = preload("res://staging/e06_world/arroio/scripts/civic_interiors.gd").new()
		civic_interiors.name="CivicInteriors"
		add_child(civic_interiors)
		civic_interiors.configure(self)
	if apply_rural_models:preload("res://staging/e06_world/arroio/scripts/z2_finish.gd").new().configure(self)
	if apply_residential_interiors and apply_current_h01_h20_revisions and FileAccess.file_exists(DATA+"interiors_h01_h05.json"):
		var interiors = preload("res://staging/e06_world/arroio/scripts/residential_interiors.gd").new()
		interiors.name="ResidentialInteriors"
		add_child(interiors)
		interiors.configure(self)
	set_static_render_batching(batch_static_visuals)
	if enable_ambience and FileAccess.file_exists(DATA+"soundscape.json"):
		var ambience = preload("res://staging/e06_world/arroio/scripts/soundscape.gd").new()
		ambience.name="Soundscape"
		add_child(ambience)
		ambience.configure(self)
	ready_for_integration = true
	city_ready.emit()

func _find_material(node: Node) -> Material:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var material: Material = node.get_active_material(i)
			if material != null:
				return material
	for child in node.get_children():
		var found := _find_material(child)
		if found != null:
			return found
	return null

func _points(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		var p := Vector2(point[0],point[1])
		if result.is_empty() or p.distance_to(result[-1]) > 0.0001:
			result.append(p)
	if result.size() > 2 and result[0].distance_to(result[-1]) < 0.0001:
		result.remove_at(result.size()-1)
	return result

func _buffer(parent: Node3D,id: String,points: Array,width: float,elevation: float,material: Material) -> void:
	var polygons := Geometry2D.offset_polyline(_points(points),width/2.0,Geometry2D.JOIN_ROUND,Geometry2D.END_ROUND)
	for index in polygons.size():
		_surface(parent,id+"_"+str(index),polygons[index],elevation,material,3.0)

func _surface(parent: Node3D,id: String,polygon: PackedVector2Array,elevation: float,material: Material,tile_m: float) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	if indices.is_empty():
		push_error("Surface triangulation failed: " + id)
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var point := polygon[index]
		tool.set_normal(Vector3.UP)
		tool.set_uv(point/tile_m)
		tool.add_vertex(Vector3(point.x,elevation,point.y))
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = id
	mesh_node.mesh = tool.commit()
	mesh_node.material_override = material
	mesh_node.set_meta("status","reversible_surface_candidate; original metric coordinates preserved")
	parent.add_child(mesh_node)

func set_sector_enabled(sector_id: String, enabled: bool) -> bool:
	# Unload/reload PackedScenes to remove visuals AND physics together.
	if sector_id not in ["S01", "S02", "S03", "S04", "S05", "S06"]:
		return false
	var current := $UrbanSectors.get_node_or_null(sector_id)
	if enabled and current == null:
		var scene: PackedScene = load("res://staging/e06_world/arroio/scenes/sectors/" + sector_id + ".tscn")
		$UrbanSectors.add_child(scene.instantiate())
	elif not enabled and current != null:
		$UrbanSectors.remove_child(current)
		current.queue_free()
	if has_node("UrbanDressing"):
		$UrbanDressing.set_sector_enabled(sector_id,enabled)
		if enabled: $UrbanDressing.install_threshold_anchors(sector_id)
	if has_node("GroundCover/"+sector_id): get_node("GroundCover/"+sector_id).visible = enabled
	if has_node("Landscape"): $Landscape.set_sector_enabled(sector_id,enabled)
	if enabled and batch_static_visuals:
		static_batcher.batch_tree($UrbanSectors.get_node(sector_id))
	if has_node("ResidentialInteriors"):$ResidentialInteriors.configure(self)
	return true

func set_static_render_batching(enabled: bool) -> void:
	batch_static_visuals = enabled
	if enabled:
		static_batcher.batch_tree($UrbanSectors)
		static_batcher.batch_tree($Vegetation)
		if has_node("UrbanDressing"): static_batcher.batch_tree($UrbanDressing)
	else:
		static_batcher.restore_tree($UrbanSectors)
		static_batcher.restore_tree($Vegetation)
		if has_node("UrbanDressing"): static_batcher.restore_tree($UrbanDressing)
