extends "res://personagem/personagens_d02.gd"
var social=load("res://personagem/social101.gd").new()
var social_catalog_path101="res://personagem/dialogos101.json"
func setup(root_scene: Node3D) -> void:
    var catalog=JSON.parse_string(FileAccess.get_file_as_string(social_catalog_path101))
    var roster=JSON.parse_string(FileAccess.get_file_as_string(encounter_catalog_path99))
    if not social.configure(catalog,roster.characters.keys()):push_error("Invalid social dialogue catalog");return
    super.setup(root_scene)

func _interface() -> void:
    prompt=Label.new();prompt.mouse_filter=Control.MOUSE_FILTER_IGNORE;prompt.add_theme_font_size_override("font_size",15)
    prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;scene.game_ui.add_child(prompt);prompt.visible=false
    view_d02=load("res://personagem/dialogue_view101.gd").new();scene.game_ui.add_child(view_d02)
    panel=view_d02;speaker=view_d02.name_label;speech=view_d02.legacy_line;options=view_d02.choices
    view_d02.choice_requested.connect(_choose_d02);view_d02.exit_requested.connect(request_exit_d02)
    view_d02.set_options(_options_d02());get_viewport().size_changed.connect(_layout);_layout()

func _options_d02() -> Array:
    if social.active.is_empty():return super._options_d02()
    var rows=social.options(can_exit)
    for row in rows:
        var details=[]
        if row.has("check"):
            var label=str(social.config.skills[row.skill].label)
            row.text+="\n[%s · %d%%]"%[label,roundi(float(row.chance)*100/36)]
            details.append("2d6 + habilidade e modificadores · dificuldade %d"%row.difficulty)
            details.append("%d de 36 resultados possíveis são favoráveis."%row.chance)
            for modifier in row.modifiers:details.append("%+d · %s"%[modifier.value,modifier.label])
        if not row.reason.is_empty():row.text+="\n"+row.reason;details.append(row.reason)
        elif row.state=="visited":row.text+="\nJá perguntado."
        row.tooltip="\n".join(details)
    return rows

func open(id: String) -> bool:
    if not super.open(id):return false
    if not social.begin(id):close();return false
    var line=social.current_line();speech.text=line.text
    view_d02.begin_session({"npc_id":id,"name":registry.definitions[id].name,"context":"Arroio das Figueiras","portrait":portrait_d02(id)},[{"speaker":registry.definitions[id].name,"text":line.text,"kind":line.kind}],_options_d02(),can_exit)
    _relation_hint101()
    return true

func _relation_hint101() -> void:
    if active.is_empty():return
    var scores=social.relation(active,"player")
    var trust="inicial" if scores.trust<=0 else "em formação" if scores.trust==1 else "alguma abertura"
    var intimacy="distante" if scores.intimacy<=0 else "em aproximação"
    view_d02.relationship_hint.text="Confiança: %s · Intimidade: %s"%[trust,intimacy]

func _choose_d02(token: String) -> void:
    if active.is_empty() or not reachable(active) or scene.player.reaction.is_active() or scene.player.paused:return
    var result=social.choose(active,token,can_exit)
    if not result.ok:return
    if result.exit:request_exit_d02();return
    if not token.ends_with(":back"):view_d02.append_line({"speaker":"Você","text":result.player_text,"kind":"player"})
    if not result.check_result.is_empty():
        var roll=result.check_result
        var text="%s · %s\n%d + %d + %d = %d · dificuldade %d"%[roll.skill_label,"SUCESSO" if roll.success else "FALHA",roll.dice[0],roll.dice[1],roll.score,roll.dice[0]+roll.dice[1]+roll.score,roll.difficulty]
        view_d02.append_line({"speaker":"Teste","kind":"check","text":text,"dice":roll.dice,"success":roll.success})
    if social.node!=social.config.dialogues[active].start:
        speech.text=result.line.text
        view_d02.append_line({"speaker":registry.definitions[active].name if result.line.kind=="npc" else "Observação","text":result.line.text,"kind":result.line.kind})
    view_d02.set_options(_options_d02())
    _relation_hint101()

func _about() -> void:
    for row in social.options(can_exit):
        if row.option_id=="origin":_choose_d02(row.id);return

func close() -> void:
    social.end();super.close()
    if view_d02!=null:view_d02.set_options(super._options_d02())
