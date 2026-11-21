extends StaticBody3D
## Stationary first-contact actor, using the approved human rig without zombie AI.
var identity=""
var avatar: Node3D
var manager: Node3D
var capsule: CollisionShape3D
var visual_budget=preload("res://personagem/visual_budget115.gd").new()
func setup(owner: Node3D,id: String,definition: Dictionary,point: Vector3) -> void:
    manager=owner;identity=id;name=id;collision_layer=3;collision_mask=0
    visual_budget.configure(hash(id))
    global_position=point
    capsule=CollisionShape3D.new();var shape=CapsuleShape3D.new();shape.radius=.23;shape.height=1.84
    capsule.shape=shape;capsule.position.y=.92;add_child(capsule)
    avatar=load(definition.get("avatar_scene","res://personagem/personagem.tscn")).instantiate();avatar.manual_update=true
    avatar.position.y=.006;add_child(avatar)
    if not avatar.set_appearance(definition.appearance):push_error("Invalid human appearance: "+id)
    avatar.hand_layer.set_pose("Relaxed");avatar.set_motion("idle");avatar.motion_rate=1;avatar.advance(0)
func _physics_process(delta: float) -> void:
    if manager==null or manager.scene.player.paused:return
    if manager.active==identity:
        var toward=manager.scene.player.global_position-global_position;toward.y=0
        if toward.length()>.1:avatar.rotation.y=lerp_angle(avatar.rotation.y,atan2(toward.x,toward.z),minf(1,delta*3))
    var elapsed=visual_budget.consume(delta,visual_budget.full_rate(global_position,manager.scene.player.global_position,get_viewport().get_camera_3d(),manager.active==identity))
    if elapsed>=0:avatar.advance(elapsed)
