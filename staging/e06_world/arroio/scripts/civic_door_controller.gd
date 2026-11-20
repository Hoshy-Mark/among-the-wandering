extends "res://staging/e06_world/arroio/scripts/residential_interiors.gd"
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.physical_keycode!=KEY_E:return
	var target := _observer()
	if not is_instance_valid(target):return
	var best: Dictionary={};var distance := 1.8
	for home in homes.values():
		if not is_instance_valid(home.instance) or not home.instance.is_inside_tree():continue
		for door in home.doors:
			var center: Vector3=door.leaf.global_transform*door.leaf.mesh.get_aabb().get_center()
			if absf(center.y-target.global_position.y-1.0)>1.4:continue
			var d: float=Vector2(center.x-target.global_position.x,center.z-target.global_position.z).length()
			var closed_center:Vector3=door.hinge.get_parent().global_transform*Transform3D(door.closed_basis,door.hinge.position)*door.leaf.transform*door.leaf.mesh.get_aabb().get_center()
			d=minf(d,Vector2(closed_center.x-target.global_position.x,closed_center.z-target.global_position.z).length())
			if d<distance:best=door;distance=d
	if best.is_empty():return
	if _player_in_swing(best):
		last_door_result={"name":str(best.hinge.name),"blocked_by_actor":true}
		return
	# This laboratory interaction only changes door pose/collision; no inventory.
	best.hinge.basis=best.closed_basis
	if not best.open:best.hinge.rotate_y(best.angle)
	best.open=not best.open
	last_door_result={"name":str(best.hinge.name),"open":best.open}
	get_viewport().set_input_as_handled()


var ambient_source:Environment
var ambient_fallback:Environment
var previous_camera_environment:Environment
var using_fallback=false
func _process(delta:float):
	super._process(delta)
	var camera=get_viewport().get_camera_3d()
	if camera==null:return
	var inside=homes.values().any(func(h):return h.inside)
	if inside:
		var environments=city.find_children("*","WorldEnvironment",true,false)
		if environments.is_empty():return
		var source:Environment=environments[0].environment
		if source.ambient_light_source!=Environment.AMBIENT_SOURCE_SKY or source.sky!=null:
			if using_fallback:camera.environment=previous_camera_environment;using_fallback=false
			return
		if ambient_source!=source:
			ambient_source=source;ambient_fallback=source.duplicate();ambient_fallback.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		if not using_fallback:previous_camera_environment=camera.environment
		camera.environment=ambient_fallback;using_fallback=true
	elif using_fallback:
		camera.environment=previous_camera_environment;using_fallback=false
