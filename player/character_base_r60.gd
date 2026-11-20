extends "res://player/character_base_r59.gd"

var locomotion: RefCounted
var command_sprint=false

func _ready() -> void:
    super._ready()
    locomotion=load("res://personagem/locomocao60.gd").new()
    locomotion.setup(self)

func _physics_process(delta: float) -> void:
    var excluded=not flow.queue.is_empty() or traversal.is_active() or reaction.is_active() or combat.guarding or action.state!="idle" or movement_condition!="normal" or not preview_motion.is_empty()
    if excluded:
        locomotion.cancel()
        super._physics_process(delta)
        return
    restore_collision()
    var floor_query=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.12,global_position-Vector3.UP*.12,1)
    var support=get_world_3d().direct_space_state.intersect_ray(floor_query)
    if support.is_empty() or support.normal.y<.8:
        locomotion.cancel()
        super._physics_process(delta)
        return
    var input=command
    var running=command_run
    var sprinting=command_sprint
    if not scripted:
        input=Vector2(float(Input.is_physical_key_pressed(KEY_D) or (not quick_slots_enabled and Input.is_physical_key_pressed(KEY_RIGHT)))-float(Input.is_physical_key_pressed(KEY_A) or (not quick_slots_enabled and Input.is_physical_key_pressed(KEY_LEFT))),float(Input.is_physical_key_pressed(KEY_S) or (not quick_slots_enabled and Input.is_physical_key_pressed(KEY_DOWN)))-float(Input.is_physical_key_pressed(KEY_W) or (not quick_slots_enabled and Input.is_physical_key_pressed(KEY_UP))))
        running=Input.is_physical_key_pressed(KEY_SHIFT)
        sprinting=running and Input.is_physical_key_pressed(KEY_CTRL)
    var previous=global_position
    if locomotion.update(delta,input,running,sprinting):
        locomotion.ground_pose()
        velocity=(global_position-previous)/maxf(delta,.000001) if not locomotion.queue.is_empty() else Vector3.ZERO
        motion_id=avatar.motion
        return
    super._physics_process(delta)

func _prepare_action() -> bool:
    if locomotion!=null:
        locomotion.cancel()
    return super._prepare_action()

func request_reaction(id: String) -> bool:
    if locomotion!=null:
        locomotion.cancel()
    return super.request_reaction(id)

func request_attack(id: String="") -> bool:
    if locomotion!=null:
        locomotion.cancel()
    return super.request_attack(id)

func toggle_guard() -> bool:
    if locomotion!=null:
        locomotion.cancel()
    return super.toggle_guard()

func set_preview(id: String) -> bool:
    if locomotion!=null:
        locomotion.cancel()
    return super.set_preview(id)

func request_cross(obstacle: Node3D=null) -> bool:
    if locomotion!=null:
        locomotion.cancel()
    return super.request_cross(obstacle)

func request_open(obstacle: Node3D=null) -> bool:
    if locomotion!=null:
        locomotion.cancel()
    return super.request_open(obstacle)

func set_movement_condition(value: String) -> bool:
    var accepted=super.set_movement_condition(value)
    if accepted and locomotion!=null:
        locomotion.cancel()
    return accepted
