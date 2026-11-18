extends "res://player/character_base_r61.gd"

var damage_serial=0

func _ready() -> void:
    super._ready()
    condition_state=load("res://personagem/ferimentos62.gd").new()
    condition_path="user://character_condition_r62.json"
    condition_state.changed.connect(_sync_dressing)
    action.effect_applied.connect(func(_id: String,_succeeded: bool): _sync_dressing())
    action.effect_applied.connect(func(id: String,succeeded: bool):
        if id=="bandage":
            condition_message="Curativo aplicado" if succeeded else "Curativo não concluído"
    )

func _sync_dressing() -> void:
    if action!=null and action.props!=null:
        action.props.dressing.visible=condition_state.forearm_dressed

func _physics_process(delta: float) -> void:
    super._physics_process(delta)
    action._present()
    _sync_dressing()

func receive_damage(event_id: String, region: String, severity: float) -> bool:
    if not condition_state.receive_damage(event_id,region,severity):
        return false
    action.cancel()
    locomotion.cancel()
    if not paused:
        request_reaction("hit_front")
    return true

func test_damage(region: String) -> void:
    damage_serial+=1
    while condition_state.damage_events.has("test_%d"%damage_serial):
        damage_serial+=1
    receive_damage("test_%d"%damage_serial,region,.35)

func request_use(kind: String) -> bool:
    if kind!="bandage":
        return super.request_use(kind)
    var revision: int=condition_state.forearm_revision
    if not condition_state.can_dress(revision):
        condition_message="Antebraço sem ferida para novo curativo"
        return false
    if supplies.stock.get("bandage",0)<=0:
        condition_message="Bandagens esgotadas"
        return false
    if not _prepare_action():
        return false
    var expected: int=supplies.stock.bandage
    return action.begin(func() -> bool:
        if supplies.stock.bandage!=expected or not condition_state.can_dress(revision):
            return false
        if not supplies.apply("bandage",expected):
            return false
        return condition_state.dress(revision)
    ,"bandage")

func refill_supplies() -> void:
    super.refill_supplies()
    _sync_dressing()

func load_condition() -> bool:
    var current=condition_path
    if current=="user://character_condition_r62.json" and not FileAccess.file_exists(current) and FileAccess.file_exists("user://character_condition_r61.json"):
        condition_path="user://character_condition_r61.json"
    var loaded=super.load_condition()
    condition_path=current
    return loaded
