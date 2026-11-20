extends Node3D
## Original environmental layers. The listener follows the actor, not camera height.
const BASE := "res://staging/e06_world/arroio/"
const BUS := {"master":"EA_Ambiente","wind":"EA_Vento","water":"EA_Agua","fauna":"EA_Fauna","wood":"EA_Madeira"}
var definition: Dictionary = {}
var streams: Dictionary = {}
var loops: Dictionary = {}
var envelopes: Dictionary = {}
var events: Array[AudioStreamPlayer3D] = []
var listener: AudioListener3D
var lowpass: AudioEffectLowPassFilter
var period := "day"
var enabled := true
var master_db := -1.0
var fade := 0.0
var indoor := 0.0
var target_indoor := false
var focus := Vector3.ZERO
var review_focus := Vector3.ZERO
var review_override := false
var nearest_water := Vector3.ZERO
var nearest_forest := Vector3.ZERO
var nearest_wood := Vector3.ZERO
var water_distance := 100000.0
var forest_distance := 100000.0
var wood_distance := 100000.0
var current_gains: Dictionary = {}
var rng := RandomNumberGenerator.new()
var refresh := 0.0
var timers := {"birds":8.0,"frogs":15.0,"wood":19.0}
var automatic_events := true
var configured := false

func configure(_city: Node3D) -> void:
	definition=JSON.parse_string(FileAccess.get_file_as_string(BASE+"data/soundscape.json"))
	rng.randomize()
	period=definition.default_period;master_db=definition.master_db
	_setup_buses()
	for key in definition.assets:
		var asset: Dictionary = definition.assets[key]
		var stream := AudioStreamWAV.load_from_file(asset.path)
		assert(stream!=null,"Missing environmental audio: "+str(asset.path))
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD if asset.loop else AudioStreamWAV.LOOP_DISABLED
		if asset.loop:stream.loop_begin=0;stream.loop_end=int(asset.frames)
		streams[key]=stream
	listener=AudioListener3D.new();listener.name="ActorAudioListener";add_child(listener);listener.make_current()
	var wind := AudioStreamPlayer.new();wind.name="Wind";wind.stream=streams.wind;wind.bus=BUS.wind;add_child(wind);loops.wind=wind
	for key in ["water","leaves","insects"]:
		var source := AudioStreamPlayer3D.new();source.name=key.capitalize();source.stream=streams[key]
		source.bus=BUS.water if key=="water" else BUS.wind if key=="leaves" else BUS.fauna
		source.unit_size=18 if key=="water" else 16 if key=="leaves" else 24
		source.max_distance=100 if key=="water" else 80
		source.max_db=0;source.attenuation_filter_cutoff_hz=6500
		add_child(source);loops[key]=source
	for i in int(definition.budgets.event_voices):
		var source := AudioStreamPlayer3D.new();source.name="Event_"+str(i);source.unit_size=16;source.max_distance=120;source.max_db=0
		add_child(source);events.append(source)
	for key in loops:envelopes[key]=0.0
	for key in ["wind","water","leaves","insects","birds","frogs","wood"]:current_gains[key]=float(definition.profiles[period][key])
	configured=true
	_update_context()
	set_process(true)

func _setup_buses() -> void:
	for key in ["master","wind","water","fauna","wood"]:
		var bus_name: String = BUS[key]
		if AudioServer.get_bus_index(bus_name)==-1:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
		var index := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_send(index,"Master" if key=="master" else BUS.master)
		AudioServer.set_bus_volume_db(index,-80 if key=="master" else 0)
	var main := AudioServer.get_bus_index(BUS.master)
	for i in AudioServer.get_bus_effect_count(main):
		var effect := AudioServer.get_bus_effect(main,i)
		if effect is AudioEffectLowPassFilter:lowpass=effect;break
	if lowpass==null:
		lowpass=AudioEffectLowPassFilter.new();lowpass.cutoff_hz=18000
		AudioServer.add_bus_effect(main,lowpass)

func set_period(value: String) -> bool:
	if not definition.get("profiles",{}).has(value):return false
	period=value
	return true

func set_enabled(value: bool) -> void:enabled=value
func set_master_db(value: float) -> void:master_db=clampf(value,-40,0)
func set_review_focus(position: Vector3) -> void:review_focus=position;review_override=true;refresh=0
func clear_review_focus() -> void:review_override=false;refresh=0
func set_seed(value: int) -> void:rng.seed=value

func _observer() -> Vector3:
	if review_override:return review_focus
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):return player.global_position
	var walker := get_tree().get_first_node_in_group("arroio_inspection_walker") as Node3D
	if is_instance_valid(walker) and walker.process_mode!=Node.PROCESS_MODE_DISABLED:return walker.global_position
	var camera := get_viewport().get_camera_3d()
	if camera!=null:
		var forward: Vector3 = -camera.global_basis.z
		if forward.y<-.05:return camera.global_position+forward*((.1-camera.global_position.y)/forward.y)
		return camera.global_position
	return Vector3.ZERO

func _update_context() -> void:
	focus=_observer()
	listener.global_position=focus+Vector3(0,1.6,0)
	var camera := get_viewport().get_camera_3d()
	if camera!=null:listener.global_basis=camera.global_basis
	var point := Vector2(focus.x,focus.z)
	water_distance=100000;forest_distance=100000;wood_distance=100000
	for i in definition.shoreline.size():
		var a: Array = definition.shoreline[i]
		var b: Array = definition.shoreline[(i+1)%definition.shoreline.size()]
		var p := Geometry2D.get_closest_point_to_segment(point,Vector2(a[0],a[1]),Vector2(b[0],b[1]))
		var distance := point.distance_to(p)
		if distance<water_distance:water_distance=distance;nearest_water=Vector3(p.x,.12,p.y)
	for zone in definition.foliage_zones:
		var p := Vector2(zone.position[0],zone.position[1]);var distance := point.distance_to(p)
		if distance<forest_distance:forest_distance=distance;nearest_forest=Vector3(p.x,2.2,p.y)
	target_indoor=false
	for zone in definition.structures:
		var p := Vector2(zone.position[0],zone.position[1]);var distance := point.distance_to(p)
		if distance<wood_distance:wood_distance=distance;nearest_wood=Vector3(p.x,.8,p.y)
		if not zone.interior:continue
		var delta := point-p;var angle := deg_to_rad(float(zone.yaw))
		var x := cos(angle)*delta.x-sin(angle)*delta.y
		var z := sin(angle)*delta.x+cos(angle)*delta.y
		if absf(x)<5.1 and absf(z)<3.6 and focus.y<3.8:target_indoor=true
	var residential := get_parent().get_node_or_null("ResidentialInteriors")
	if residential!=null:
		for lot in residential.homes:
			if residential.contains_point(lot,focus):target_indoor=true
	loops.water.global_position=nearest_water
	loops.leaves.global_position=nearest_forest
	loops.insects.global_position=nearest_water if water_distance<85 else nearest_forest

func _process(delta: float) -> void:
	if not configured:return
	refresh-=delta
	if refresh<=0:_update_context();refresh=.20
	# Keep the head listener smooth between the cheaper environmental queries.
	listener.global_position=_observer()+Vector3(0,1.6,0)
	var response := 1-exp(-delta*2.0)
	fade=move_toward(fade,1.0 if enabled else 0.0,delta/float(definition.fade_seconds))
	indoor=lerpf(indoor,1.0 if target_indoor else 0.0,response)
	lowpass.cutoff_hz=lerpf(18000,float(definition.indoor_lowpass_hz),indoor)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS.master),master_db+linear_to_db(maxf(fade,.00001)))
	var profile: Dictionary = definition.profiles[period]
	for key in current_gains:current_gains[key]=lerpf(float(current_gains[key]),float(profile[key]),response)
	var context := {"wind":true,"water":water_distance<98,"leaves":forest_distance<76,"insects":minf(water_distance,forest_distance)<76}
	for key in loops:
		var source = loops[key]
		var wanted: bool = enabled and context[key]
		envelopes[key]=move_toward(float(envelopes[key]),1.0 if wanted else 0.0,delta*1.8)
		if wanted and not source.playing:source.play(rng.randf_range(0,20))
		var cover := float(definition.indoor_attenuation_db)*indoor*(1.0 if key in ["wind","leaves"] else .7)
		source.volume_db=float(current_gains[key])+linear_to_db(maxf(float(envelopes[key]),.00001))+cover
		if not wanted and float(envelopes[key])<.0001:source.stop()
	for source in events:
		if source.playing:
			var kind: String = source.get_meta("kind","birds")
			source.volume_db=float(current_gains[kind])+float(source.get_meta("trim_db",0))+float(definition.indoor_attenuation_db)*indoor*.6
	if automatic_events and enabled:
		for kind in timers:
			timers[kind]-=delta
			if float(timers[kind])>0:continue
			play_event(kind)
			var interval: Array = [20,48] if kind=="wood" else profile.bird_interval if kind=="birds" else profile.frog_interval
			timers[kind]=rng.randf_range(float(interval[0]),float(interval[1]))
	if not enabled and fade<.001:
		for source in events:source.stop()

func play_event(kind: String, variant: int=-1) -> bool:
	if not enabled or not configured or float(definition.profiles[period].get(kind,-80))<=-70:return false
	if kind=="birds" and forest_distance>115:return false
	if kind=="frogs" and water_distance>95:return false
	if kind=="wood" and wood_distance>28:return false
	var prefix := "bird_" if kind=="birds" else "frog_" if kind=="frogs" else "wood_"
	var options: Array = streams.keys().filter(func(key):return str(key).begins_with(prefix))
	var available: AudioStreamPlayer3D
	for source in events:
		if not source.playing:available=source;break
	if available==null:return false
	var index := rng.randi_range(0,options.size()-1) if variant<0 else variant%options.size()
	available.stream=streams[options[index]];available.bus=BUS.wood if kind=="wood" else BUS.fauna
	available.global_position=nearest_wood if kind=="wood" else nearest_water+Vector3(0,.4,0) if kind=="frogs" else nearest_forest+Vector3(rng.randf_range(-9,9),rng.randf_range(1,5),rng.randf_range(-9,9))
	available.pitch_scale=rng.randf_range(.97,1.035);available.set_meta("kind",kind);available.set_meta("trim_db",rng.randf_range(-2,0))
	available.volume_db=float(current_gains[kind])+float(available.get_meta("trim_db"))
	available.play()
	return true

func snapshot() -> Dictionary:
	var voices := 0;var active := {}
	for key in loops:
		active[key]=loops[key].playing
		if loops[key].playing:voices+=1
	for source in events:
		if source.playing:voices+=1
	return {"period":period,"enabled":enabled,"listener":listener.global_position,"focus":focus,"indoors":target_indoor,"indoor_mix":indoor,
		"water_distance_m":water_distance,"forest_distance_m":forest_distance,"wood_distance_m":wood_distance,"active_loops":active,"voices":voices,"voice_budget":8,"lowpass_hz":lowpass.cutoff_hz}

func _exit_tree() -> void:
	configured=false
	for source in loops.values():
		if is_instance_valid(source):source.stop()
	for source in events:
		if is_instance_valid(source):source.stop()
	if is_instance_valid(listener) and listener.is_current():listener.clear_current()
