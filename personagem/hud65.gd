extends Control

const SLOT_LABELS={"shirt":"Tronco","pants":"Pernas","boots":"Pés","belt":"Cinto","backpack":"Costas","main_hand":"Mão principal"}
var player: CharacterBody3D
var windows: Array=[]
var containers: OptionButton
var destination: OptionButton
var grid: GridContainer
var equipment: VBoxContainer
var capacity_label: Label
var details: Label
var feedback: Label
var amount: SpinBox
var divide_button: Button
var join_button: Button
var transfer_button: Button
var selected_uid=""
var container_id="pockets"
var zone_id="forearm_left"
var body_map: Control
var zone_choice: OptionButton
var zone_details: RichTextLabel
var damage_kind: OptionButton
var treatment: Button
var vitals: Label
var slot_script=load("res://personagem/slot65.gd")

func setup(body: CharacterBody3D) -> void:
    player=body
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var ui_theme=Theme.new()
    ui_theme.default_font_size=14
    var button_style=StyleBoxFlat.new()
    button_style.bg_color=Color("344440")
    button_style.set_corner_radius_all(4)
    button_style.set_content_margin_all(8)
    ui_theme.set_stylebox("normal","Button",button_style)
    var hover=button_style.duplicate()
    hover.bg_color=Color("4b6155")
    ui_theme.set_stylebox("hover","Button",hover)
    var panel_style=StyleBoxFlat.new()
    panel_style.bg_color=Color(.085,.12,.12,.97)
    panel_style.border_color=Color("50615a")
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(7)
    panel_style.set_content_margin_all(14)
    ui_theme.set_stylebox("panel","PanelContainer",panel_style)
    theme=ui_theme
    var toolbar=HBoxContainer.new()
    toolbar.position=Vector2(18,14)
    toolbar.add_theme_constant_override("separation",12)
    add_child(toolbar)
    _button(toolbar,"Inventário  [I]",func(): toggle(0))
    _button(toolbar,"Corpo  [H]",func(): toggle(1))
    _button(toolbar,"Salvar estado",_save)
    _button(toolbar,"Carregar",_load)
    vitals=_label(toolbar,"")
    var left=_window("INVENTÁRIO",0)
    _inventory(left)
    var right=_window("CONDIÇÃO DO CORPO",1)
    _body(right)
    player.bag_inventory.changed.connect(refresh)
    player.bag_inventory.access_changed.connect(refresh)
    player.body_health.changed.connect(_refresh_body)
    player.condition_state.changed.connect(_refresh_body)
    player.hud_requested.connect(toggle)
    get_viewport().size_changed.connect(_layout)
    _layout()
    refresh()
    windows[0].visible=true
    windows[1].visible=false
    player.set_hud_open(true)

func _window(title: String, index: int) -> VBoxContainer:
    var panel=PanelContainer.new()
    add_child(panel)
    windows.append(panel)
    var column=VBoxContainer.new()
    column.add_theme_constant_override("separation",10)
    panel.add_child(column)
    var row=HBoxContainer.new()
    column.add_child(row)
    var heading=_label(row,title)
    heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    heading.add_theme_color_override("font_color",Color("dfca8e"))
    _button(row,"×",func(): toggle(index))
    return column

func _layout() -> void:
    var viewport=get_viewport_rect().size
    var compact=viewport.x<1200
    var width=viewport.x-32 if compact else minf(610,(viewport.x-48)/2)
    for index in windows.size():
        windows[index].position=Vector2(16 if compact or index==0 else viewport.x-width-16,64)
        windows[index].size=Vector2(width,minf(620,viewport.y-80))
    if compact and windows[0].visible and windows[1].visible:
        windows[1].visible=false

func _label(parent: Node, text: String) -> Label:
    var label=Label.new()
    label.text=text
    parent.add_child(label)
    return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
    var button=Button.new()
    button.text=text
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _inventory(parent: VBoxContainer) -> void:
    var columns=HBoxContainer.new()
    columns.add_theme_constant_override("separation",14)
    parent.add_child(columns)
    var left=VBoxContainer.new()
    left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    columns.add_child(left)
    containers=OptionButton.new()
    left.add_child(containers)
    containers.item_selected.connect(func(index: int): container_id=containers.get_item_metadata(index); refresh())
    capacity_label=_label(left,"")
    var scroll=ScrollContainer.new()
    scroll.custom_minimum_size=Vector2(315,270)
    left.add_child(scroll)
    grid=GridContainer.new()
    grid.columns=3
    grid.add_theme_constant_override("h_separation",5)
    grid.add_theme_constant_override("v_separation",5)
    scroll.add_child(grid)
    equipment=VBoxContainer.new()
    equipment.custom_minimum_size.x=205
    columns.add_child(equipment)
    details=_label(parent,"Selecione um item")
    details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    var quantities=HBoxContainer.new()
    parent.add_child(quantities)
    _label(quantities,"Qtd.")
    amount=SpinBox.new()
    amount.min_value=1
    amount.max_value=1
    amount.step=1
    amount.custom_minimum_size.x=85
    quantities.add_child(amount)
    amount.value_changed.connect(func(_value: float): _stack_buttons())
    divide_button=_button(quantities,"Dividir",_split_selected)
    transfer_button=_button(quantities,"Mover qtd.",_transfer_selected)
    transfer_button.tooltip_text="Move a quantidade para o destino escolhido na linha abaixo."
    join_button=_button(quantities,"Juntar",_merge_selected)
    var actions=HBoxContainer.new()
    parent.add_child(actions)
    _button(actions,"Usar",func(): _notify(player.use_item(selected_uid),"Ação iniciada"))
    _button(actions,"Equipar",func(): equip_uid(selected_uid))
    _button(actions,"Soltar",func(): move_uid(selected_uid,"ground"))
    destination=OptionButton.new()
    actions.add_child(destination)
    _button(actions,"Mover",func():
        if destination.selected>=0:
            move_uid(selected_uid,destination.get_item_metadata(destination.selected))
    )
    _label(parent,"Arraste sobre uma pilha igual para juntar. Use Qtd. para separar.").add_theme_color_override("font_color",Color("9daea5"))
    feedback=_label(parent,"")
    feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _body(parent: VBoxContainer) -> void:
    zone_choice=OptionButton.new()
    parent.add_child(zone_choice)
    for zone in player.body_health.regions:
        zone_choice.add_item(player.body_health.regions[zone].name)
        zone_choice.set_item_metadata(zone_choice.item_count-1,zone)
    zone_choice.item_selected.connect(func(index: int): select_zone(zone_choice.get_item_metadata(index)))
    var row=HBoxContainer.new()
    parent.add_child(row)
    body_map=load("res://personagem/mapa_corpo63.gd").new()
    body_map.health=player.body_health
    body_map.selected.connect(select_zone)
    row.add_child(body_map)
    zone_details=RichTextLabel.new()
    zone_details.bbcode_enabled=true
    zone_details.custom_minimum_size=Vector2(295,380)
    row.add_child(zone_details)
    treatment=_button(parent,"Aplicar curativo no antebraço E",func(): _notify(player.request_use("bandage"),"Tratamento iniciado"))
    var tester=HBoxContainer.new()
    parent.add_child(tester)
    _label(tester,"Dano de teste")
    damage_kind=OptionButton.new()
    for kind in player.body_health.TYPES:
        damage_kind.add_item(player.body_health.TYPES[kind].name)
        damage_kind.set_item_metadata(damage_kind.item_count-1,kind)
    tester.add_child(damage_kind)
    _button(tester,"Aplicar",_test_hit)
    _label(parent,"Fatores de dano e capacidades são experimentais.").add_theme_color_override("font_color",Color("9daea5"))

func _clear(parent: Node) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()

func refresh() -> void:
    if player==null:
        return
    var model: RefCounted=player.bag_inventory
    var destinations={"pockets":"Bolsos"}
    for id in model.reachable:
        if model.is_open(id):
            destinations[id]=model.world_containers[id].name
    for uid in model.items:
        var definition: Dictionary=model.catalog[model.items[uid].definition]
        if definition.has("capacity") and model.can_touch(uid):
            destinations[uid]=definition.name
    if not destinations.has(container_id):
        container_id="pockets"
    var previous_target=""
    if destination.selected>=0:
        previous_target=str(destination.get_item_metadata(destination.selected))
    containers.clear()
    destination.clear()
    for id in destinations:
        containers.add_item(destinations[id])
        containers.set_item_metadata(containers.item_count-1,id)
        destination.add_item(destinations[id])
        destination.set_item_metadata(destination.item_count-1,id)
        if id==previous_target:
            destination.select(destination.item_count-1)
        if id==container_id:
            containers.select(containers.item_count-1)
    destination.add_item("Chão aqui")
    destination.set_item_metadata(destination.item_count-1,"ground")
    if previous_target=="ground":
        destination.select(destination.item_count-1)
    var contents: Array=model.contents(container_id)
    if model.items.has(selected_uid) and selected_uid not in contents and not str(model.items[selected_uid].location).begins_with("slot:"):
        selected_uid=""
    var capacity: int=model.capacity(container_id)
    capacity_label.text="%d / %d slots"%[contents.size(),capacity] if not (model.world_containers.has(container_id) and model.world_containers[container_id].kind=="ground") else "%d pilha(s) no chão"%contents.size()
    _clear(grid)
    var cells=capacity if not (model.world_containers.has(container_id) and model.world_containers[container_id].kind=="ground") else maxi(9,contents.size()+3)
    for index in cells:
        var button=slot_script.new()
        button.hud=self
        button.destination=container_id
        button.custom_minimum_size=Vector2(100,65)
        button.add_theme_font_size_override("font_size",12)
        if index<contents.size():
            var uid: String=contents[index]
            var item: Dictionary=model.items[uid]
            button.uid=uid
            button.text=model.catalog[item.definition].name
            button.text=button.text.left(17)+("\n× %d"%item.count)
            button.tooltip_text=model.catalog[item.definition].name
            button.pressed.connect(func(): select_item(uid))
        else:
            button.text="·"
        grid.add_child(button)
    _clear(equipment)
    _label(equipment,"NO CORPO")
    for slot in model.SLOTS:
        var button=slot_script.new()
        button.hud=self
        button.equipment=true
        button.destination=slot
        button.uid=model.equipped(slot)
        button.text=SLOT_LABELS.get(slot,slot)+"\n"+("Vazio" if button.uid.is_empty() else model.catalog[model.items[button.uid].definition].name)
        button.add_theme_font_size_override("font_size",12)
        button.custom_minimum_size.y=44
        var uid: String=button.uid
        button.pressed.connect(func(): select_item(uid))
        equipment.add_child(button)
    var quick=HBoxContainer.new()
    equipment.add_child(quick)
    for entry in [["pockets","Bolsos"],[model.equipped("backpack"),"Mochila"],["ground","Chão"]]:
        var button=slot_script.new()
        button.hud=self
        button.destination=entry[0]
        button.text=entry[1]
        button.disabled=str(entry[0]).is_empty()
        button.add_theme_font_size_override("font_size",11)
        quick.add_child(button)
    select_item(selected_uid)
    _refresh_body()

func select_item(uid: String) -> void:
    selected_uid=uid
    for child in grid.get_children():
        child.self_modulate=Color(1,.91,.66) if child.uid==uid and not uid.is_empty() else Color.WHITE
    var model: RefCounted=player.bag_inventory
    if not model.items.has(uid):
        selected_uid=""
        details.text="Selecione um item"
        amount.max_value=1
        _stack_buttons()
        return
    var item: Dictionary=model.items[uid]
    details.text=model.catalog[item.definition].name+"  ·  %d unidade(s)  ·  limite %d"%[item.count,model.catalog[item.definition].stack]
    amount.max_value=item.count
    _stack_buttons()

func move_uid(uid: String, target: String) -> void:
    _notify(player.move_item(uid,target),"Item movido")

func equip_uid(uid: String, slot: String="") -> void:
    var model: RefCounted=player.bag_inventory
    if not model.items.has(uid) or (not slot.is_empty() and model.catalog[model.items[uid].definition].get("slot","")!=slot):
        _notify(false,"")
        return
    _notify(player.equip_item(uid),"Equipamento atualizado")

func _notify(accepted: bool, success: String) -> void:
    feedback.text=success if accepted else (player.inventory_message if not player.inventory_message.is_empty() else player.bag_inventory.message if not player.bag_inventory.message.is_empty() else "Ação indisponível")

func select_zone(zone: String) -> void:
    zone_id=zone
    body_map.current=zone
    for index in zone_choice.item_count:
        if zone_choice.get_item_metadata(index)==zone:
            zone_choice.select(index)
    _refresh_body()

func _refresh_body() -> void:
    if zone_details==null:
        return
    var health: RefCounted=player.body_health
    for index in zone_choice.item_count:
        if zone_choice.get_item_metadata(index)==zone_id:
            zone_choice.select(index)
    var entries: Array=health.wounds(zone_id)
    var text="[b]"+health.regions[zone_id].name+"[/b]\n\nSeveridade  %.0f%%\n"%(health.severity(zone_id)*100)
    for entry in entries:
        text+="\n• "+health.TYPES[entry.kind].name+"  %.0f%%"%(entry.severity*100)
    if entries.is_empty():
        text+="\nLesão anterior · tipo não informado" if health.severity(zone_id)>0 else "\nSem ferimento registrado"
    if zone_id=="forearm_left" and player.condition_state.forearm_dressed:
        text+="\n\n[color=#acd3a7]Curativo aplicado[/color]"
    if zone_id!="forearm_left":
        text+="\n\nTratamento animado desta região será integrado."
    zone_details.text=text
    treatment.disabled=zone_id!="forearm_left" or not player.condition_state.can_dress(player.condition_state.forearm_revision)
    body_map.queue_redraw()

func _test_hit() -> void:
    player.damage_serial+=1
    var id="hud_%d"%player.damage_serial
    while player.body_health.records.has(id) or player.condition_state.damage_events.has(id):
        player.damage_serial+=1
        id="hud_%d"%player.damage_serial
    player.receive_zone_damage(id,zone_id,damage_kind.get_item_metadata(damage_kind.selected),.25)
    _refresh_body()

func toggle(index: int) -> void:
    var opening=not windows[index].visible
    if opening and not player.set_hud_open(true):
        return
    if opening and get_viewport_rect().size.x<1200:
        windows[1-index].visible=false
    windows[index].visible=opening
    player.set_hud_open(windows.any(func(window):return window.visible))
    if opening:
        refresh()

func _save() -> void:
    _notify(player.save_condition(),"Personagem salvo")

func _load() -> void:
    _notify(player.load_condition(),"Personagem carregado")

func _process(_delta: float) -> void:
    if player!=null:
        vitals.text="Fôlego  %.0f / 100"%player.condition_state.stamina

func _merge_target() -> String:
    var model: RefCounted=player.bag_inventory
    if not model.items.has(selected_uid):
        return ""
    var item: Dictionary=model.items[selected_uid]
    for uid in model.contents(item.location):
        if uid!=selected_uid and model.items[uid].definition==item.definition and model.items[uid].count<model.catalog[item.definition].stack:
            return uid
    return ""

func _stack_buttons() -> void:
    if divide_button==null or join_button==null or transfer_button==null:
        return
    var model: RefCounted=player.bag_inventory
    var usable=model.can_touch(selected_uid)
    divide_button.disabled=true
    if usable:
        divide_button.disabled=int(amount.value)>=int(model.items[selected_uid].count)
    join_button.disabled=not usable or _merge_target().is_empty()
    transfer_button.disabled=not usable

func _split_selected() -> void:
    var created: String=player.split_item(selected_uid,int(amount.value))
    if not created.is_empty():
        select_item(created)
    _notify(not created.is_empty(),player.bag_inventory.message)

func _transfer_selected() -> void:
    if destination.selected<0:
        return
    var accepted: bool=player.transfer_items(selected_uid,str(destination.get_item_metadata(destination.selected)),int(amount.value))
    _notify(accepted,player.bag_inventory.message)

func _merge_selected() -> void:
    merge_uid(selected_uid,_merge_target(),int(amount.value))

func merge_uid(uid: String, target: String, count: int) -> void:
    var accepted: bool=player.merge_items(uid,target,count)
    if accepted and player.bag_inventory.items.has(target) and player.bag_inventory.items[target].location==container_id:
        select_item(target)
    _notify(accepted,player.bag_inventory.message)
