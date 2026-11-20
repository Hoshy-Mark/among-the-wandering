extends "res://personagem/personagens101.gd"
var skills_ui: Node
var social_model_path102="res://personagem/social102.gd"
func setup(root_scene: Node3D) -> void:
    social=load(social_model_path102).new()
    super.setup(root_scene)
    skills_ui=load("res://personagem/menu108/menu.gd").new();add_child(skills_ui);skills_ui.setup(self)

func _choose_d02(token: String) -> void:
    var before=social.available_points();super._choose_d02(token)
    if skills_ui!=null:skills_ui.refresh()
    var awarded=social.available_points()-before
    if awarded>0 and not active.is_empty():
        view_d02.append_line({"speaker":"Aprendizado","kind":"narration","text":"Você ganhou %d ponto de aprendizado. Use %s fora da conversa para desenvolver uma habilidade."%[awarded,skills_ui._hint()]})

func close() -> void:
    if skills_ui!=null:skills_ui.close()
    super.close()
