extends CharacterBody3D
## Inspection proxy, independent of the character team's assets and controller.
var camera: Camera3D
var input_enabled := true
var test_direction := Vector3.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.7
	var collider := CollisionShape3D.new()
	collider.shape = capsule
	collider.position.y = .85
	add_child(collider)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = .28
	mesh.height = 1.7
	body.mesh = mesh
	body.position.y = .85
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.12,.65,.78)
	body.material_override = material
	add_child(body)
	add_to_group("arroio_inspection_walker")

func _physics_process(delta: float) -> void:
	var direction := test_direction
	if input_enabled and is_instance_valid(camera):
		var x := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		var y := float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		var right := camera.global_basis.x
		var down := camera.global_basis.z
		right.y = 0
		down.y = 0
		direction = (right.normalized()*x+down.normalized()*y).normalized()
	var speed := 5.5 if input_enabled and Input.is_physical_key_pressed(KEY_SHIFT) else 3.0
	velocity.x = direction.x*speed
	velocity.z = direction.z*speed
	if not is_on_floor(): velocity.y -= 20*delta
	else: velocity.y = 0
	move_and_slide()
