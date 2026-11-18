extends "interacao_inventario.gd"

const PROP_BASIS = Basis(Vector3.FORWARD, Vector3.LEFT, Vector3.UP)

var definitions: Dictionary
var bindings: Dictionary
var props: Node3D
var visual_kind = ""
var previous_hand_pose = "Relaxed"
var previous_face: Dictionary = {}


func setup(npc: Node3D) -> void:
    super.setup(npc)
    definitions = JSON.parse_string(FileAccess.get_file_as_string(actor.base_dir + "acoes_consumo.json"))
    bindings = JSON.parse_string(FileAccess.get_file_as_string(actor.base_dir + "encaixes_consumo.json"))
    for grip in ["Box", "Cylinder", "Pinch"]:
        var combined: Dictionary = actor.hand_layer.poses.Relaxed.duplicate(true)
        for name in actor.hand_layer.poses[grip]:
            if str(name).ends_with(".R"):
                var source_grip = grip
                if grip == "Pinch" and str(name).split(".")[0] in ["Middle", "Ring", "Little"]:
                    source_grip = "Cylinder"
                combined[name] = actor.hand_layer.poses[source_grip][name].duplicate(true)
        actor.hand_layer.poses["R_" + grip] = combined
    props = load(actor.base_dir + "objetos_consumo.gd").new()
    props.name = "ObjetosConsumo"
    actor.add_child(props)
    var forearm: Array = bindings.bandage.forearm_center
    props.forearm_center = Vector3(forearm[0], forearm[1], forearm[2])
    effect_applied.connect(_on_effect_applied)


func _on_effect_applied(kind: String, succeeded: bool) -> void:
    if succeeded and definitions.has(kind):
        props.apply_effect(kind)


func begin(effect: Callable = Callable(), kind: String = "access") -> bool:
    if definitions.has(kind) and actor.speech_active:
        return false
    if not super.begin(effect, kind):
        return false
    if definitions.has(kind):
        visual_kind = kind
        previous_hand_pose = actor.hand_layer.label
        previous_face = actor.speech_weights.duplicate(true)
        actor.hand_layer.set_pose("R_" + str(definitions[kind].grip))
        props.show_kind(kind)
        _present()
    return true


func _release_visual() -> void:
    if visual_kind.is_empty():
        return
    props.hide_held()
    actor.hand_layer.set_pose(previous_hand_pose)
    actor.speech_weights = previous_face.duplicate(true)
    actor._apply_weights()
    visual_kind = ""


func cancel(resume: String = "idle") -> bool:
    var accepted = super.cancel(resume)
    if accepted:
        _release_visual()
    return accepted


func _grip_transform() -> Transform3D:
    if visual_kind.is_empty():
        return Transform3D.IDENTITY
    var point: Array = bindings[visual_kind].center
    return Transform3D(PROP_BASIS, Vector3(point[0], point[1], point[2]))


func _present() -> void:
    if not visual_kind.is_empty():
        var seconds = state_time if state == "gesture" else 0.0
        var contact = smoothstep(.85, 1.15, seconds) * (1 - smoothstep(2.0, 2.4, seconds))
        if visual_kind == "eat":
            actor.set_pose("A", .13 * contact * (.5 + .5 * sin(seconds * TAU * 2.8)))
        elif visual_kind == "drink":
            actor.set_pose("O", .08 * contact)
        elif visual_kind == "medicine":
            actor.set_pose("A", .10 * contact)
    props.update_attachments(actor, _grip_transform())


func advance(delta: float) -> void:
    super.advance(delta)
    if state == "idle":
        _release_visual()
    _present()


func clear_dressing() -> void:
    props.dressing.visible = false
