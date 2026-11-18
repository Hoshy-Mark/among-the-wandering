extends RefCounted
var body: CharacterBody3D
var job: Dictionary={}

func setup(actor: CharacterBody3D) -> void:
    body=actor
    body.action.effect_applied.connect(_effect)
    body.action.finished.connect(_finished)
    body.action.cancelled.connect(_cancelled)

func busy() -> bool:
    return not job.is_empty()

func _apply(model: RefCounted, data: Dictionary) -> bool:
    if data.kind=="equip":
        return model.equip(data.uid)
    if data.destination=="drop_here":
        return model.drop_at(data.uid,data.x,data.y,data.rot)
    return model.place(data.uid,data.destination,data.x,data.y,data.rot)

func begin(data: Dictionary) -> bool:
    if busy() or not body._prepare_action():
        body.inventory_message="Conclua a ação atual"
        return false
    var model: RefCounted=body.bag_inventory
    body.update_nearby()
    if not model.items.has(data.uid):
        body.inventory_message="Selecione um item"
        return false
    # Validate against an isolated copy. Preview never mutates the live stock,
    # access state, ground registry or ID allocator.
    var shadow: RefCounted=model.get_script().new()
    shadow.house_anchors=model.house_anchors.duplicate(true)
    if not shadow.restore(model.snapshot(),false):
        return false
    shadow.reachable=model.reachable.duplicate()
    shadow.opened=model.opened.duplicate()
    shadow.actor_position=model.actor_position
    shadow.seeding=false
    if not _apply(shadow,data):
        body.inventory_message=shadow.message if not shadow.message.is_empty() else "Destino inválido"
        return false
    job=data.duplicate(true)
    job.expected=model.items.duplicate(true)
    job.origin=body.global_position
    job.committed=false
    if not body.action.begin(_commit,"equip" if data.kind=="equip" else "store"):
        job.clear()
        return false
    _feedback("Equipando peça..." if data.kind=="equip" else "Guardando peça...")
    return true

func _commit() -> bool:
    var model: RefCounted=body.bag_inventory
    body.update_nearby()
    if job.is_empty() or model.items!=job.expected or body.global_position.distance_to(job.origin)>.05:
        body.inventory_message="A situação mudou; operação cancelada"
        return false
    # The model rechecks access, the selected cells, bag contents and equipment
    # at the effect boundary. No alternate cell or automatic packing is used.
    var accepted=_apply(model,job)
    if accepted:
        job.committed=true
    else:
        body.inventory_message=model.message if not model.message.is_empty() else "Operação indisponível"
    return accepted

func _feedback(message: String) -> void:
    var ui=body.get_tree().get_first_node_in_group("c05_hud")
    if ui!=null:
        ui.feedback.text=message

func _effect(kind: String, success: bool) -> void:
    if not busy() or kind not in ["equip","store"]:
        return
    var ui=body.get_tree().get_first_node_in_group("c05_hud")
    if success and job.get("destination","")=="drop_here" and ui!=null:
        ui.near_source=body.bag_inventory.items[job.uid].location
        ui.nearby_wanted=true
    if ui!=null:
        ui.refresh()
    _feedback(("Peça equipada" if job.kind=="equip" else "Peça guardada") if success else body.inventory_message)

func _finished() -> void:
    if busy():
        job.clear()

func _cancelled(kind: String, _effect_done: bool) -> void:
    if not busy() or kind not in ["equip","store"]:
        return
    var committed: bool=job.committed
    job.clear()
    _feedback("Troca concluída" if committed else "Operação cancelada")
