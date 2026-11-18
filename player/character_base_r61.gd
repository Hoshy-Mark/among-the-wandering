extends "res://player/character_base_r60.gd"

var condition_state: RefCounted
var condition_message=""
var condition_path="user://character_condition_r61.json"

func _ready() -> void:
    super._ready()
    condition_state=load("res://personagem/condicao61.gd").new()

func _sync_condition() -> void:
    var desired: String=condition_state.condition()
    if movement_condition!=desired:
        super.set_movement_condition(desired)

func _physics_process(delta: float) -> void:
    _sync_condition()
    var free=not traversal.is_active() and not reaction.is_active() and flow.queue.is_empty() and action.state=="idle" and not combat.guarding
    if free:
        avatar.motion_rate=1.872/2.8333333 if movement_condition=="tired" and avatar.motion=="tired_run" else 1.0
    super._physics_process(delta)
    if free and avatar.motion_blend<1:
        locomotion.ground_pose()
    if paused or reaction.is_active() or traversal.is_active() or not flow.queue.is_empty() or action.state!="idle" or combat.guarding or not preview_motion.is_empty():
        return
    var moving=Vector2(velocity.x,velocity.z).length()>.05
    var sprinting=avatar.motion.contains("sprint") and not condition_state.exhausted
    var running=sprinting or avatar.motion in ["run","tired_run"] or avatar.motion.contains("jog")
    condition_state.advance(delta,moving,running,sprinting)

func _movement_speed(running: bool, guarding: bool) -> float:
    var speed: float=super._movement_speed(running,guarding)
    return minf(speed,1.872) if movement_condition=="tired" and running and not guarding and not crouched else speed

func set_movement_condition(value: String) -> bool:
    if condition_state==null:
        return super.set_movement_condition(value)
    if not super.set_movement_condition(value):
        return false
    condition_state.set_injury("L",.5 if value=="injured_left" else 0)
    condition_state.set_injury("R",.5 if value=="injured_right" else 0)
    condition_state.set_stamina(10 if value=="tired" else 100)
    return true

func save_condition() -> bool:
    var file=FileAccess.open(condition_path+".tmp",FileAccess.WRITE)
    if file==null:
        condition_message="Falha ao abrir o arquivo de condição"
        return false
    file.store_string(JSON.stringify(condition_state.snapshot()))
    file.flush()
    var error=file.get_error()
    file.close()
    if error!=OK:
        condition_message="Falha ao gravar a condição"
        return false
    var renamed=DirAccess.rename_absolute(ProjectSettings.globalize_path(condition_path+".tmp"),ProjectSettings.globalize_path(condition_path))
    condition_message="Condição salva" if renamed==OK else "Falha ao concluir a gravação"
    return renamed==OK

func load_condition() -> bool:
    if paused or traversal.is_active() or reaction.is_active() or not flow.queue.is_empty() or action.state!="idle" or combat.guarding:
        return false
    var data=JSON.parse_string(FileAccess.get_file_as_string(condition_path)) if FileAccess.file_exists(condition_path) else null
    if not condition_state.restore(data):
        condition_message="Arquivo ausente ou condição inválida"
        return false
    _sync_condition()
    condition_message="Condição carregada"
    return true
