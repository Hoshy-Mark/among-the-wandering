extends RefCounted
## Passive mounts and identifiers only. No input, inventory or active animation.
const DATA := "res://personagem/h01_furniture67.json"
var entries := {}
var articulations := {}
var mesh_owners := {}
var root: Node3D

func configure(home: Dictionary,lot: String) -> void:
	var definitions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var extra := "res://staging/e06_world/arroio/data/furniture_preparation_h06_h10.json"
	if false and FileAccess.file_exists(extra):definitions.lots.merge(JSON.parse_string(FileAccess.get_file_as_string(extra)).lots)
	extra="res://staging/e06_world/arroio/data/furniture_preparation_h11_h20.json"
	if false and FileAccess.file_exists(extra):definitions.lots.merge(JSON.parse_string(FileAccess.get_file_as_string(extra)).lots)
	var model: Node3D=home.model
	root=Node3D.new();root.name="FurniturePreparation";root.set_meta("keep_individual_visual",true);model.add_child(root)
	for definition in definitions.lots.get(lot,[]):
		var furniture := Node3D.new();furniture.name=definition.id;root.add_child(furniture)
		furniture.set_meta("stable_id",definition.id);furniture.set_meta("family_id",definition.family);furniture.set_meta("gameplay_enabled",false)
		furniture.set_meta("pending_model_work",definition.pending_model_work)
		var meshes := {};var bounds: AABB;var first := true
		for name in definition.source_meshes:
			var mesh: MeshInstance3D=model.find_child(name,true,false)
			if mesh==null:push_error("Missing preparation mesh: "+str(name));continue
			meshes[name]=mesh
			mesh_owners[name]=definition.id
			if definition.get("preserve_mirrored_parts",false) and mesh.global_basis.determinant()<0:
				mesh.set_meta("keep_individual_visual",true)
				mesh.set_meta("batch_exclusion_reason","Preserve mirrored winding and normals")
			var box: AABB=(model.global_transform.affine_inverse()*mesh.global_transform)*mesh.mesh.get_aabb()
			bounds=box if first else bounds.merge(box);first=false
		var center := bounds.get_center();furniture.position=Vector3(center.x,bounds.position.y,center.z)
		var fixed_body_hint := Marker3D.new();fixed_body_hint.name="BodyAnchor";furniture.add_child(fixed_body_hint);fixed_body_hint.global_position=model.to_global(center)
		fixed_body_hint.set_meta("existing_collision_path","Model/InteriorCollision/Furniture_"+str(definition.id))
		var interaction := Marker3D.new();interaction.name="UseAnchor";furniture.add_child(interaction)
		interaction.global_position=model.to_global(Vector3(center.x,clampf(center.y,.6,1.3),center.z))
		interaction.set_meta("requires_reach_and_line_of_sight",true);interaction.set_meta("enabled",false)
		var storage := Node3D.new();storage.name="CompartmentAnchors";furniture.add_child(storage)
		for compartment in definition.compartments:
			var anchor := Marker3D.new();anchor.name=str(compartment.id).get_file();storage.add_child(anchor)
			anchor.global_position=model.to_global(center);anchor.set_meta("stable_id",compartment.id);anchor.set_meta("anchor_only",true);anchor.set_meta("capacity_configured",false)
		var moving := Node3D.new();moving.name="Articulations";furniture.add_child(moving)
		entries[definition.id]={"definition":definition,"node":furniture,"meshes":meshes,"bounds_model":bounds,"interaction_anchor":interaction}
		for part in definition.parts:
			var leaf: MeshInstance3D=meshes[part.leaf_mesh];var box: AABB=leaf.mesh.get_aabb()
			var pivot := Node3D.new();pivot.name=str(part.id).get_file();moving.add_child(pivot)
			var local := box.get_center()
			var width_x: bool=box.size.x>=box.size.z
			var edge: String=part.hinge_edge
			if edge=="opposite_handle" and not part.attached_meshes.is_empty():
				var handle: MeshInstance3D=meshes[part.attached_meshes[0]]
				var handle_local := leaf.to_local(handle.global_transform*handle.mesh.get_aabb().get_center())
				edge="max" if (handle_local.x<local.x if width_x else handle_local.z<local.z) else "min"
			if part.motion=="hinge_y":
				if width_x:local.x=box.position.x if edge=="min" else box.end.x
				else:local.z=box.position.z if edge=="min" else box.end.z
				local.y=box.position.y
			elif part.motion=="hinge_x":local.y=box.position.y
			pivot.global_transform=Transform3D(leaf.global_basis.orthonormalized(),leaf.to_global(local))
			var leaf_center: Vector3=leaf.global_transform*box.get_center()
			var outward := leaf_center-model.to_global(center);outward.y=0
			if not part.attached_meshes.is_empty():
				var handle: MeshInstance3D=meshes[part.attached_meshes[0]]
				outward=(handle.global_transform*handle.mesh.get_aabb().get_center())-leaf_center;outward.y=0
			if outward.length()<.001:outward=leaf.global_basis.z;outward.y=0
			outward=outward.normalized()
			leaf.reparent(pivot,true);leaf.set_meta("keep_individual_visual",true);leaf.set_meta("future_articulation_id",part.id)
			for name in part.attached_meshes:
				var handle: MeshInstance3D=meshes[name];handle.reparent(pivot,true);handle.set_meta("keep_individual_visual",true)
			var body := AnimatableBody3D.new();body.name="FutureMovingCollision";body.collision_layer=0;body.collision_mask=0;body.sync_to_physics=false;pivot.add_child(body)
			var proxy := CollisionShape3D.new();proxy.name="DisabledProxy";var shape := BoxShape3D.new()
			var leaf_box: AABB=(pivot.global_transform.affine_inverse()*leaf.global_transform)*box
			shape.size=leaf_box.size;proxy.shape=shape;proxy.position=leaf_box.get_center();proxy.disabled=true;body.add_child(proxy)
			pivot.set_meta("stable_id",part.id);pivot.set_meta("motion",part.motion);pivot.set_meta("mechanical_clearance","not_validated")
			pivot.set_meta("resolved_hinge_edge",edge)
			pivot.set_meta("preview_angle_degrees",part.preview_angle_degrees);pivot.set_meta("preview_travel_m",part.preview_travel_m)
			var axis := (Vector3.RIGHT if width_x else Vector3.BACK) if part.motion=="hinge_x" else Vector3.UP
			pivot.set_meta("motion_axis_local",axis)
			articulations[part.id]={"definition":part,"pivot":pivot,"closed_transform":pivot.transform,"outward_local":pivot.get_parent().global_basis.inverse()*outward,"leaf":leaf,"proxy":proxy,"fraction":0.0,"edge":edge,"axis":axis}
			if part==definition.parts[0]:
				var normal: Vector3=model.global_basis.inverse()*outward
				var distance: float=absf(normal.x)*bounds.size.x/2+absf(normal.z)*bounds.size.z/2+.35
				var front := Vector3(center.x,clampf(center.y,.6,1.3),center.z)+normal*distance
				interaction.global_position=model.to_global(front)
			var key: String=str(part.id).get_file().trim_prefix("door_")
			var anchor := storage.get_node_or_null(key) as Marker3D
			if anchor!=null:anchor.global_position=leaf.global_transform*leaf.mesh.get_aabb().get_center()
	root.set_meta("furniture_count",entries.size());root.set_meta("articulation_count",articulations.size());root.set_meta("gameplay_enabled",false)

func set_review_fraction(id: String,fraction: float) -> void:
	# Explicit QA-only preview. Physical clearances and hollow cabinetry must be
	# finished before any game controller is allowed to drive these mounts.
	var item: Dictionary=articulations[id];var t := clampf(fraction,0,1);var part: Dictionary=item.definition
	item.pivot.transform=item.closed_transform
	if part.motion=="slide":item.pivot.position+=item.outward_local*float(part.preview_travel_m)*t
	else:
		item.pivot.rotate_object_local(item.axis,deg_to_rad(float(part.preview_angle_degrees))*t*(-1 if item.edge=="max" else 1))
	item.fraction=t
