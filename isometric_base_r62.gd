extends "res://isometric_base_r61.gd"

var wound_label: Label

func _ready() -> void:
    await super._ready()
    var args=OS.get_cmdline_user_args()
    if "--qa-wounds" in args or "--capture-wounds" in args:
        player.global_position=spawn+Vector3(0,.03,-3)
        await load("res://personagem/revisao62.gd").new().run(self,"--capture-wounds" in args,true)

func _interface() -> void:
    super._interface()
    var tabs=panel.get_child(0)
    var column=VBoxContainer.new()
    column.name="Ferimentos R62"
    column.add_theme_constant_override("separation",9)
    tabs.add_child(column)
    tabs.move_child(column,0)
    tabs.current_tab=0
    wound_label=Label.new()
    column.add_child(wound_label)
    _button(column,"Impacto no antebraço esquerdo",func(): player.test_damage("forearm_left"))
    _button(column,"Impacto na perna esquerda",func(): player.test_damage("leg_left"))
    _button(column,"Impacto na perna direita",func(): player.test_damage("leg_right"))
    _button(column,"Curativo no antebraço",func(): player.request_use("bandage"))
    _button(column,"Repor bandagens de teste",func(): player.refill_supplies())
    _button(column,"Salvar condição",func(): player.save_condition())
    _button(column,"Carregar condição",func(): player.load_condition())

func _process(delta: float) -> void:
    super._process(delta)
    if wound_label!=null and player!=null and player.condition_state!=null:
        var data: Dictionary=player.condition_state.snapshot()
        wound_label.text="Antebraço %.2f · %s\nBandagens %d\n%s" % [data.forearm_injury,"Com curativo" if data.forearm_dressed else "Sem curativo",player.supplies.stock.bandage,player.condition_message]
