extends Node3D
var scene: Node3D
var stats: Label
func setup(root_scene: Node3D) -> void:
    scene=root_scene
    var p=scene.player
    var condition=load("res://personagem/condicao80.gd").new()
    assert(condition.restore(p.condition_state.snapshot()))
    p.condition_state=condition
    p.body_health.condition=condition
    condition.changed.connect(p._sync_dressing)
    condition.changed.connect(scene.game_ui.health_ui._refresh_body)
    p.survival=self
    scene.game_ui.health_ui.damage_kind.get_parent().hide()
    for child in scene.game_ui.windows[1].get_child(0).get_children():
        if child is Label and child.text.begins_with("Fatores de dano"):child.hide()
    stats=Label.new()
    stats.name="Necessidades80"
    stats.add_theme_font_size_override("font_size",12)
    var column=scene.game_ui.windows[1].get_child(0)
    column.add_child(stats)
    column.move_child(stats,1)
    update_pain()
    refresh()
func update_pain() -> void:
    var p=scene.player
    var worst=0.0
    for zone in p.body_health.regions:
        var amount: float=p.body_health.severity(zone)
        if zone=="forearm_left" and p.condition_state.forearm_dressed:amount*=.5
        worst=maxf(worst,amount)
    p.condition_state.pain_base=worst*100
func refresh() -> void:
    var c=scene.player.condition_state
    stats.text="Fome %.0f/100 · Sede %.0f/100 · Fôlego %.0f/100
Dor %.0f/100 · Alívio %s"%[c.hunger,c.thirst,c.stamina,c.pain(),("%ds"%ceili(c.medicine_remaining)) if c.medicine_remaining>0 else "inativo"]
func _physics_process(delta: float) -> void:
    if scene==null:return
    update_pain()
    var p=scene.player
    if not p.paused and p.reaction.state!="dead":p.condition_state.tick_needs(delta)
    refresh()
func use(uid: String) -> bool:
    var p=scene.player
    var bag=p.bag_inventory
    update_pain()
    if not bag.items.has(uid) or not bag.owned(uid):return false
    var item: Dictionary=bag.items[uid]
    var kind: String=bag.catalog[item.definition].get("use","")
    var revision: int=p.condition_state.forearm_revision
    if not p.condition_state.can_use(kind,revision):
        p.inventory_message="Sem necessidade deste efeito agora; o curativo atende ao antebraço esquerdo"
        return false
    if p.action.state!="idle" or p.inventory_actions.busy() or p.map_doors.busy() or not p._prepare_action():return false
    var expected: int=item.count
    var definition: String=item.definition
    return p.action.begin(func() -> bool:
        update_pain()
        if not bag.owned(uid) or not bag.items.has(uid) or bag.items[uid].definition!=definition or not p.condition_state.can_use(kind,revision):return false
        var before: Dictionary=bag.snapshot()
        if not bag.consume(uid,1,expected,false):return false
        if not p.condition_state.apply_use(kind,revision):
            bag.restore(before,false)
            return false
        update_pain()
        bag.changed.emit()
        refresh()
        return true
    ,kind)
