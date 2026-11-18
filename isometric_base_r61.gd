extends "res://isometric_base_r60.gd"

var condition_label: Label

func _ready() -> void:
    await super._ready()
    var args=OS.get_cmdline_user_args()
    if "--qa-condition" in args or "--capture-condition" in args:
        player.global_position=spawn+Vector3(0,.03,-3)
        await load("res://personagem/revisao61.gd").new().run(self,"--capture-condition" in args,true)

func _interface() -> void:
    super._interface()
    var tabs=panel.get_child(0)
    var column=VBoxContainer.new()
    column.name="Fôlego R61"
    column.add_theme_constant_override("separation",9)
    tabs.add_child(column)
    tabs.move_child(column,0)
    tabs.current_tab=0
    condition_label=Label.new()
    column.add_child(condition_label)
    _button(column,"Restaurar fôlego",func(): player.condition_state.set_stamina(100))
    _button(column,"Fôlego baixo para teste",func(): player.condition_state.set_stamina(18))
    _button(column,"Lesão esquerda de teste",func(): player.condition_state.set_injury("L",.6))
    _button(column,"Lesão direita de teste",func(): player.condition_state.set_injury("R",.6))
    _button(column,"Limpar lesões de teste",func(): player.condition_state.set_injury("L",0); player.condition_state.set_injury("R",0))
    _button(column,"Salvar condição",func(): player.save_condition())
    _button(column,"Carregar condição",func(): player.load_condition())

func _process(delta: float) -> void:
    super._process(delta)
    if condition_label!=null and player!=null and player.condition_state!=null:
        var data: Dictionary=player.condition_state.snapshot()
        condition_label.text="Fôlego %.0f / 100\n%s\nLesão E %.2f · D %.2f\n%s" % [data.stamina,player.movement_condition,data.left_injury,data.right_injury,player.condition_message]
