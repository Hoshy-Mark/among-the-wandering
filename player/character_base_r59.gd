extends "res://player/character_base_r58.gd"
var flow: RefCounted

func _ready() -> void:
    super._ready()
    flow=load("res://personagem/fluxo59.gd").new()
    flow.setup(self)

func _physics_process(delta: float) -> void:
    if flow!=null and not flow.queue.is_empty():
        flow.advance(delta)
        return
    super._physics_process(delta)

func _prepare_action() -> bool:
    return (flow==null or flow.queue.is_empty()) and super._prepare_action()

func request_reaction(id: String) -> bool:
    return (flow==null or flow.queue.is_empty()) and super.request_reaction(id)

func request_attack(id: String="") -> bool:
    return (flow==null or flow.queue.is_empty()) and super.request_attack(id)

func toggle_guard() -> bool:
    return (flow==null or flow.queue.is_empty()) and super.toggle_guard()

func request_cross(obstacle: Node3D=null) -> bool:
    return flow.queue.is_empty() and super.request_cross(obstacle)

func request_open(obstacle: Node3D=null) -> bool:
    return flow.queue.is_empty() and super.request_open(obstacle)

func set_preview(id: String) -> bool:
    return (flow==null or flow.queue.is_empty()) and super.set_preview(id)

func _unhandled_key_input(event: InputEvent) -> void:
    if flow!=null and not flow.queue.is_empty():
        return
    super._unhandled_key_input(event)
