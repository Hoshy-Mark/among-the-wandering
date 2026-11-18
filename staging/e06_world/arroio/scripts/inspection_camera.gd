extends Camera3D
## Inspection only. No Preview 2 characters or gameplay scripts.
var focus := Vector3(90, 0, 235)
var canopy_probe: MeshInstance3D
var layout_factor := 1.0
var walker: CharacterBody3D
var walking_mode := false
var controls_label: Label

func set_walking_mode(enabled: bool) -> void:
	if enabled and is_instance_valid(canopy_probe):
		canopy_probe.queue_free()
		canopy_probe = null
	walking_mode = enabled
	if not is_instance_valid(walker):
		walker = CharacterBody3D.new()
		walker.set_script(preload("res://staging/e06_world/arroio/scripts/test_walker.gd"))
		walker.name = "InspectionWalker"
		walker.camera = self
		get_parent().add_child(walker)
		var road: Dictionary = get_parent().catalog("roads")[0]
		var p: Array = road.geometry.coordinates[4]
		walker.position = Vector3(p[0],.15,p[1])
	walker.visible = enabled
	walker.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if enabled:
		size = 22
		focus = walker.position+Vector3.UP
	get_parent().get_node("Landscape").set_occlusion_target(walker if enabled else null)
	if not is_instance_valid(controls_label):
		var hud := CanvasLayer.new()
		hud.name = "InspectionControls"
		add_child(hud)
		var panel := PanelContainer.new()
		panel.position = Vector2(12,12)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.06,.09,.08,.87)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel",style)
		controls_label = Label.new()
		controls_label.add_theme_font_size_override("font_size",15)
		panel.add_child(controls_label)
		hud.add_child(panel)
	controls_label.text = ("VISTA ISOMÉTRICA • marcador de teste\nWASD / setas  mover   Shift  correr   Roda  zoom\nF7  alternar caminhada / mapa   Home  panorama" if enabled else "INSPEÇÃO DO MAPA\nWASD  mover câmera   Roda  zoom   1–6  setores\nF7  voltar à caminhada   F8  testar copas   Home  panorama")
	_update_view()

func toggle_canopy_probe() -> void:
	var landscape := get_parent().get_node_or_null("Landscape")
	if landscape == null: return
	if is_instance_valid(canopy_probe):
		landscape.set_occlusion_target(null)
		canopy_probe.queue_free()
		canopy_probe = null
		return
	var trees: Array = get_parent().catalog("landscape").trees
	var nearest: Dictionary = trees[0]
	for tree in trees:
		if Vector2(tree.position[0]-focus.x,tree.position[1]-focus.z).length() < Vector2(nearest.position[0]-focus.x,nearest.position[1]-focus.z).length(): nearest = tree
	canopy_probe = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	canopy_probe.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05,0.85,0.95)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	canopy_probe.material_override = material
	get_parent().add_child(canopy_probe)
	canopy_probe.position = Vector3(nearest.position[0]-2,0.85,nearest.position[1]-2)
	landscape.set_occlusion_target(canopy_probe)
	size = 24
var sectors: Array[Vector3] = [Vector3(180,0,235),Vector3(260,0,175),Vector3(280,0,390),Vector3(250,0,105),Vector3(450,0,100),Vector3(550,0,370)]

func _ready() -> void:
	layout_factor = get_parent().catalog("city_master").get("layout_compaction",{}).get("distance_factor",1.0)
	focus *= layout_factor
	for index in sectors.size(): sectors[index] *= layout_factor
	# Script-based QA keeps its explicit camera/probe setup. Normal play starts
	# in the requested orthographic, fixed-angle walking inspection mode.
	if OS.get_cmdline_args().find("--script") == -1 and not DisplayServer.get_name()=="headless":
		set_walking_mode.call_deferred(true)
	_update_view()

func _process(delta: float) -> void:
	if walking_mode and is_instance_valid(walker):
		focus = walker.position+Vector3.UP
		_update_view()
		return
	if is_instance_valid(canopy_probe):
		var movement := Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)),0,float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP)))
		canopy_probe.position += movement.normalized()*delta*3
		focus = canopy_probe.position
		_update_view()
		return
	var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	focus += direction.normalized()*delta*size*0.6
	_update_view()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F7: set_walking_mode(not walking_mode)
		if event.physical_keycode == KEY_F8:
			if walking_mode: set_walking_mode(false)
			toggle_canopy_probe()
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_6:
			focus = sectors[event.physical_keycode - KEY_1]
		if event.physical_keycode == KEY_HOME:
			if walking_mode: set_walking_mode(false)
			focus = Vector3(310,0,230)*layout_factor
			size = 700*layout_factor

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			size = maxf(20.0, size*0.85)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			size = minf(900.0, size/0.85)

func _update_view() -> void:
	# 45-degree azimuth and 30-degree elevation, dimetric isometric-game view.
	projection = Camera3D.PROJECTION_ORTHOGONAL
	position = focus + Vector3(220,179.6292478,220)
	look_at(focus, Vector3.UP)
