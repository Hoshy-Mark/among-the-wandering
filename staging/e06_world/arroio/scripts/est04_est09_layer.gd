extends RefCounted
## Reversible placement of the remaining six approved establishments.
const DATA := "res://staging/e06_world/arroio/data/est04_est09_part02_part03.json"
var geometry = preload("res://staging/e06_world/arroio/scripts/est01_est03_layer.gd").new()

static func adjusted(city: Node3D, name: String, data: Variant) -> Variant:
	if not city.apply_est04_est09_models or name not in ["landscape","civic_infrastructure","parcels","roads","city_master"]:
		return data
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	match name:
		"parcels":data.append_array(definitions.new_parcels)
		"roads":
			data[0].geometry.coordinates.insert(0,definitions.v01_west_connection)
			data.append_array(definitions.new_roads)
		"city_master":data.extent_xz=definitions.extent_xz
		"civic_infrastructure":
			var replaced: Array = []
			for site in definitions.sites.values():
				if site.replaces!=null:replaced.append(site.replaces)
			data.buildings=data.buildings.filter(func(building):return building.id not in replaced)
			data.poles.append_array(definitions.new_poles)
			data.spans.append_array(definitions.new_spans)
		"landscape":
			for move in definitions.relocated_trees:data.trees[int(move.source_index)].position=move.position
	return data

func configure(city: Node3D) -> void:
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for identifier in definitions.sites:
		var site: Dictionary = definitions.sites[identifier]
		var owner := Node3D.new()
		owner.name=identifier
		owner.position=Vector3(site.position[0],site.position[1],site.position[2])
		owner.rotation_degrees.y=site.yaw_degrees
		owner.set_meta("establishment",site)
		city.get_node("UrbanDressing/"+site.sector).add_child(owner)
		var visual: Node3D = load(site.visual_path).instantiate()
		visual.name="Visual"
		owner.add_child(visual)
		preload("res://staging/e06_world/arroio/scripts/civic_vegetation_layer.gd").prepare(city,identifier,visual)
		if identifier=="EST08":
			geometry._install_gate(owner,visual,"PORTAO_entrada_folha_E",true)
			geometry._install_gate(owner,visual,"PORTAO_entrada_folha_D",false)
		var faces := PackedVector3Array()
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			if mesh.has_meta("vegetation_replaced"):continue
			if str(mesh.name).begins_with("EST_SOFT_"):continue
			if str(mesh.name) in site.collision_excluded_meshes:continue
			geometry._append_faces(mesh,owner,faces)
		geometry._collision(owner,faces,"BuildingCollision")
		var paving: Material = city.material_cache.paving
		match identifier:
			"EST04":
				geometry._ramp(owner,2,2.4,21.5,14.7,-.025,.10,"BarApproach",paving)
				geometry._ramp(owner,2,2.4,14.7,14.2,.1,.1,"BarLanding",paving)
				geometry._ramp(owner,11,1.4,15.8,14.7,-.025,.1,"BarSidewalkTransition",paving)
				geometry._ramp(owner,11,1.4,14.7,13.7,.1,.1,"BarSidewalkLanding",paving)
			"EST05":
				geometry._ramp(owner,0,17.5,24,17.2,-.025,.15,"WorkshopApproach",paving)
				for x in [-4.0,4.0]:geometry._ramp(owner,x,3.4,12,9,.15,.22,"BayRamp"+str(x))
			"EST06":
				geometry._ramp(owner,0,7,33,20.8,-.025,.095,"StationApproach",paving)
				geometry._ramp(owner,0,7,20.8,19,.095,.013,"StationCurbTransition",paving)
				geometry._ramp(owner,0,7,16.6,16,.013,.129,"StationDrainApproach",paving)
				geometry._ramp(owner,0,7,16,15.7,.129,.129,"StationDrainCover",paving)
				geometry._ramp(owner,0,7,15.7,15,.129,.013,"StationDrainExit",paving)
			"EST07":geometry._ramp(owner,-.72,2.4,22,14,-.025,.14,"PharmacyApproach",paving)
			"EST08":
				geometry._ramp(owner,-18,2,30,20.8,-.025,.07,"SchoolApproach",paving)
				geometry._ramp(owner,-18,1.6,20.8,17,.07,.135,"SchoolGateTransition",paving)
				geometry._ramp(owner,-18,1.6,4,-3,.135,.215,"SchoolAdminApproach",paving)
				geometry._ramp(owner,-10.5,1.6,1.4,-2,-.025,.16,"SchoolVerandaApproach",paving)
				geometry._ramp(owner,-10.5,1.6,-2,-3,.16,.16,"SchoolVerandaLanding",paving)
				geometry._ramp(owner,5,2,19,16.2,-.025,.205,"SchoolCourtApproach",paving)
				geometry._ramp(owner,5,2,16.2,15,.205,.205,"SchoolCourtLanding",paving)
				var veranda_link := NavigationLink3D.new()
				veranda_link.name="SchoolVerandaNavigation"
				veranda_link.start_position=Vector3(-10.5,.085,1.8)
				veranda_link.end_position=Vector3(-10.5,.16,-3.5)
				veranda_link.bidirectional=true
				owner.add_child(veranda_link)
			"EST09":
				for x in [-12.0,12.0]:geometry._ramp(owner,x,8,34,22,-.025,.035,"BusDriveway"+str(x),paving)
				geometry._ramp(owner,0,2.4,34,22,-.025,.035,"TerminalPedestrianApproach",paving)
				geometry._ramp(owner,0,3,2.5,.2,.035,.3,"PlatformApproach",paving)
				geometry._ramp(owner,0,3,.2,-1,.3,.3,"PlatformLanding",paving)
