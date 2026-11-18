extends "res://isometric_base_r58.gd"

func _ready() -> void:
    await super._ready()
    if "--capture-flow" in OS.get_cmdline_user_args():
        for fixture in fixtures.values():
            fixture.position.x+=30
        training_target.position.x+=30
        player.global_position=spawn+Vector3(0,.003,-3)
        player.avatar.rotation.y=-PI/2
        await load("res://personagem/revisao59.gd").new().capture(self,player,camera,hud,true)

func _interface() -> void:
    super._interface()
    var tabs=panel.get_child(0)
    var column=VBoxContainer.new()
    column.name="Fluxo R59"
    tabs.add_child(column)
    tabs.move_child(column,0)
    tabs.current_tab=0
    for id in ["walk","run","changes","turn_left","turn_right","crouch","sprint"]:
        _button(column,str({"walk": "Caminhar e parar", "run": "Arrancar e frear a corrida", "changes": "Caminhada, corrida e sprint", "turn_left": "Meia-volta à esquerda", "turn_right": "Meia-volta à direita", "crouch": "Fluxo agachado e giro", "sprint": "Partida e frenagem do sprint"}[id]),func(): player.flow.begin(id))
