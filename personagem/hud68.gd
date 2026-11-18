extends Control

const LABELS={"shirt":"Tronco","pants":"Pernas","boots":"Pés","belt":"Cinto","backpack":"Costas","main_hand":"Mão principal"}
var player: CharacterBody3D
var windows: Array=[]
var personal: PanelContainer
var nearby: PanelContainer
var reopen: Button
var nearby_wanted=false
var near_source=""
var source_choice: OptionButton
var storage: VBoxContainer
var equipped: VBoxContainer
var nearby_storage: VBoxContainer
var inspection: Label
var feedback: Label
var actions: HFlowContainer
var grids: Array=[]
var selected_uid=""
var pending_mode=""
var pending_source: Dictionary={}
var drag_uid=""
var drag_source: Dictionary={}
var drag_grip=Vector2i.ZERO
var drag_rot=false
var hover_grid: Control
var hover_cell=Vector2i.ZERO
var hover_item=""
var health_ui: Control
var scroll: ScrollContainer
var workspace: Control
var cell_size=54
var icon_cache: Dictionary={}

func setup(body: CharacterBody3D) -> void:
    player=body
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    var theme_ui=Theme.new()
    theme_ui.default_font_size=12
    theme_ui.set_color("font_color","Label",Color("dce1db"))
    var style=StyleBoxFlat.new()
    style.bg_color=Color("19211ef2")
    style.border_color=Color("49564f")
    style.set_border_width_all(1)
    theme_ui.set_stylebox("panel","PanelContainer",style)
    var button=StyleBoxFlat.new()
    button.bg_color=Color("28372e")
    button.border_color=Color("49564f")
    button.set_border_width_all(1)
    button.set_content_margin_all(7)
    theme_ui.set_stylebox("normal","Button",button)
    var hover=button.duplicate()
    hover.bg_color=Color("384a3e")
    theme_ui.set_stylebox("hover","Button",hover)
    theme=theme_ui
    var toolbar=HBoxContainer.new()
    toolbar.position=Vector2(22,12)
    toolbar.add_theme_constant_override("separation",12)
    add_child(toolbar)
    _label(toolbar,"—  ENTRE OS ANDARILHOS",11,Color("96a49b"))
    _button(toolbar,"I  Inventário",func():toggle(0))
    _button(toolbar,"H  Corpo",func():toggle(1))
    _button(toolbar,"Salvar",func():_notify(player.save_condition(),"Estado salvo"))
    _button(toolbar,"Carregar",func():_notify(player.load_condition(),"Estado carregado"))
    scroll=ScrollContainer.new()
    add_child(scroll)
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_top=52
    scroll.offset_left=16
    scroll.offset_right=-16
    scroll.offset_bottom=-12
    workspace=Control.new()
    workspace.mouse_filter=Control.MOUSE_FILTER_IGNORE
    scroll.add_child(workspace)
    personal=_panel("01   INVENTÁRIO",func():toggle(0))
    var column=personal.get_child(0)
    var main=HBoxContainer.new()
    main.add_theme_constant_override("separation",0)
    column.add_child(main)
    storage=_column(main,Vector2(350,444))
    main.add_child(VSeparator.new())
    equipped=_column(main,Vector2(230,444))
    column.add_child(HSeparator.new())
    var detail=_column(column,Vector2(0,88))
    _label(detail,"INSPEÇÃO",10,Color("96a49b"))
    inspection=_label(detail,"Selecione um objeto",13)
    actions=HFlowContainer.new()
    detail.add_child(actions)
    feedback=_label(detail,"Arraste os itens para organizar a mochila e os bolsos.",11,Color("96a49b"))
    feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    column.add_child(HSeparator.new())
    var foot=_column(column,Vector2(0,28))
    _label(foot,"ARRASTAR   mover objeto       R   girar manualmente       ESC   cancelar seleção",10,Color("96a49b"))
    nearby=_panel("02   PRÓXIMO",func():close_nearby())
    var near_column=nearby.get_child(0)
    var near_body=_column(near_column,Vector2(340,100))
    source_choice=OptionButton.new()
    near_body.add_child(source_choice)
    source_choice.item_selected.connect(func(index:int):near_source=str(source_choice.get_item_metadata(index));refresh())
    nearby_storage=VBoxContainer.new()
    near_body.add_child(nearby_storage)
    near_column.add_child(HSeparator.new())
    var near_foot=_column(near_column,Vector2(0,45))
    _label(near_foot,"Arraste um objeto para a mochila ou os bolsos.",11,Color("96a49b"))
    reopen=Button.new()
    reopen.text="PRÓXIMO  —  Objetos ao alcance  +"
    reopen.pressed.connect(open_nearby)
    workspace.add_child(reopen)
    health_ui=load("res://personagem/health68.gd").new()
    add_child(health_ui)
    health_ui.setup(player)
    health_ui.owner_hud=self
    player.hud_requested.disconnect(health_ui.toggle)
    player.bag_inventory.changed.disconnect(health_ui.refresh)
    health_ui.get_child(0).hide()
    health_ui.windows[0].hide()
    health_ui.windows[1].hide()
    windows=[personal,health_ui.windows[1]]
    player.hud_requested.connect(toggle)
    player.bag_inventory.changed.connect(refresh)
    player.bag_inventory.access_changed.connect(refresh)
    get_viewport().size_changed.connect(_layout)
    refresh()

func _panel(title: String, close: Callable) -> PanelContainer:
    var panel=PanelContainer.new()
    workspace.add_child(panel)
    var content=VBoxContainer.new()
    content.add_theme_constant_override("separation",0)
    panel.add_child(content)
    var head=HBoxContainer.new()
    head.custom_minimum_size.y=52
    content.add_child(head)
    var name=_label(head,"    "+title,13)
    name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var exit=_button(head,"×",close)
    exit.custom_minimum_size=Vector2(35,26)
    exit.size_flags_vertical=Control.SIZE_SHRINK_CENTER
    exit.add_theme_font_size_override("font_size",21)
    exit.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
    content.add_child(HSeparator.new())
    return panel

func _column(parent: Node, minimum: Vector2) -> VBoxContainer:
    var margin=MarginContainer.new()
    margin.custom_minimum_size=minimum
    for side in ["left","right"]:
        margin.add_theme_constant_override("margin_"+side,18)
    for side in ["top","bottom"]:
        margin.add_theme_constant_override("margin_"+side,12)
    parent.add_child(margin)
    var column=VBoxContainer.new()
    column.add_theme_constant_override("separation",7)
    margin.add_child(column)
    return column

func _label(parent: Node, text: String, font: int=12, color: Color=Color("dce1db")) -> Label:
    var label=Label.new()
    label.text=text
    label.add_theme_font_size_override("font_size",font)
    label.add_theme_color_override("font_color",color)
    parent.add_child(label)
    return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
    var button=Button.new()
    button.text=text
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _clear(node: Node) -> void:
    for child in node.get_children():
        node.remove_child(child)
        child.queue_free()

func _grid(parent: Node, id: String, title: String, note: String="") -> void:
    if not title.is_empty():
        _label(parent,title,12)
    if not note.is_empty():
        _label(parent,note,11,Color("96a49b"))
    var model: RefCounted=player.bag_inventory
    var dimensions=Vector2i(5,4) if id=="drop_here" else model.dimensions(id)
    var view=ScrollContainer.new()
    view.custom_minimum_size=Vector2(dimensions.x*(cell_size+4)+12,mini(dimensions.y*(cell_size+4),4*(cell_size+4))+4)
    parent.add_child(view)
    var grid=load("res://personagem/grid68.gd").new()
    grid.hud=self
    grid.cell=cell_size
    grid.container_id=id
    view.add_child(grid)
    grids.append(grid)
    grid.refresh()

func sources() -> Dictionary:
    var result: Dictionary={}
    var model: RefCounted=player.bag_inventory
    for id in model.reachable:
        if model.accessible(id) and (model.world_containers[id].kind!="ground" or not model.contents(id).is_empty()):
            result[id]=str(model.world_containers[id].name).replace("Itens no chão","Chão")
    for uid in model.items:
        if model.catalog[model.items[uid].definition].has("capacity") and model.items[uid].location!="slot:backpack" and model.can_touch(uid):
            var owner: String=model.items[uid].location
            result[uid]=model.catalog[model.items[uid].definition].name+(" · "+str(model.world_containers[owner].name) if model.world_containers.has(owner) else "")
    if pending_mode=="drop" and _drop_source()=="drop_here":
        result["drop_here"]="Chão aqui"
    return result

func _drop_source() -> String:
    var model: RefCounted=player.bag_inventory
    for id in model.reachable:
        if model.world_containers.has(id) and model.world_containers[id].kind=="ground" and model.point(id).distance_to(player.global_position)<.65:
            return id
    return "drop_here"

func refresh() -> void:
    if player==null or inspection==null:
        return
    var model: RefCounted=player.bag_inventory
    if not selected_uid.is_empty() and not model.can_touch(selected_uid):
        cancel_pending()
        feedback.text="Item fora do alcance"
    if not pending_source.is_empty() and (not model.items.has(selected_uid) or model.items[selected_uid]!=pending_source):
        cancel_pending()
    if not drag_source.is_empty() and (not model.items.has(drag_uid) or model.items[drag_uid]!=drag_source):
        cancel_pending()
    grids.clear()
    _clear(storage)
    _clear(equipped)
    _grid(storage,"pockets","Bolsos","Acesso imediato")
    storage.add_child(HSeparator.new())
    var bag: String=model.equipped("backpack")
    if not bag.is_empty():
        _grid(storage,bag,model.catalog[model.items[bag].definition].name,"Arraste para organizar")
    else:
        _label(storage,"Mochila não equipada",12,Color("96a49b"))
    _label(equipped,"Equipado no corpo",11,Color("96a49b"))
    for slot in model.SLOTS:
        equipped.add_child(HSeparator.new())
        var row=HBoxContainer.new()
        row.custom_minimum_size.y=49
        equipped.add_child(row)
        var uid: String=model.equipped(slot)
        var pic=TextureRect.new()
        pic.custom_minimum_size=Vector2(32,34)
        pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
        pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        pic.texture=icon(model.items[uid].definition) if not uid.is_empty() else null
        row.add_child(pic)
        var name=VBoxContainer.new()
        row.add_child(name)
        _label(name,LABELS[slot],10,Color("96a49b"))
        var button=_button(name,"Vazio" if uid.is_empty() else str(model.catalog[model.items[uid].definition].name),func():select_item(uid))
        button.add_theme_font_size_override("font_size",11)
        button.alignment=HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
        button.add_theme_stylebox_override("disabled",StyleBoxEmpty.new())
        button.disabled=uid.is_empty()
    var external=sources()
    if external.is_empty():
        nearby_wanted=false
        near_source=""
    elif not external.has(near_source):
        near_source=str(external.keys()[0])
    source_choice.clear()
    for id in external:
        source_choice.add_item(external[id])
        source_choice.set_item_metadata(source_choice.item_count-1,id)
        if id==near_source:
            source_choice.select(source_choice.item_count-1)
    _clear(nearby_storage)
    if not near_source.is_empty():
        _grid(nearby_storage,near_source,"")
    nearby.visible=nearby_wanted and not external.is_empty()
    reopen.visible=not nearby.visible and not external.is_empty()
    _inspection()
    _layout.call_deferred()
    sync_lock()

func _inspection() -> void:
    _clear(actions)
    var model: RefCounted=player.bag_inventory
    if not model.items.has(selected_uid):
        inspection.text="Selecione um objeto"
        return
    var item: Dictionary=model.items[selected_uid]
    var definition: Dictionary=model.catalog[item.definition]
    inspection.text=definition.name
    if not pending_mode.is_empty():
        _button(actions,"Cancelar",cancel_pending)
        return
    var is_equipped=str(item.location).begins_with("slot:")
    if not is_equipped and model.owned(selected_uid) and definition.has("use"):
        _button(actions,"Usar",func():_notify(player.use_item(selected_uid),"Ação iniciada"))
    if not is_equipped and definition.has("slot"):
        _button(actions,"Equipar",func():_notify(player.equip_item(selected_uid),"Equipando peça..."))
    if is_equipped:
        _button(actions,"Retirar",func():begin_pending("unequip"))
    elif model.form(item.definition).x!=model.form(item.definition).y and bool(definition.get("can_rotate",true)):
        _button(actions,"Girar",rotate_selected)
    if not is_equipped and item.count>1:
        _button(actions,"Dividir",func():begin_pending("split"))
    if model.owned(selected_uid):
        _button(actions,"Soltar no chão",func():begin_pending("drop"))

func select_item(uid: String) -> void:
    if not pending_mode.is_empty():
        cancel_pending()
    selected_uid=uid
    for grid in grids:
        for tile in grid.get_children():
            if "uid" in tile:
                tile.selected=tile.uid==uid
                tile.queue_redraw()
    _inspection()

func begin_pending(mode: String) -> void:
    if player.inventory_actions.busy():
        feedback.text="Conclua a ação atual"
        return
    var model: RefCounted=player.bag_inventory
    if not model.can_touch(selected_uid):
        return
    if mode in ["drop","unequip"] and selected_uid==model.equipped("backpack") and not model.contents(selected_uid).is_empty():
        feedback.text="Esvazie a mochila antes de retirar"
        return
    if mode in ["drop","unequip"] and selected_uid==model.equipped("pants") and not model.contents("pockets").is_empty():
        feedback.text="Esvazie os bolsos antes de retirar"
        return
    if mode=="unequip" and selected_uid==model.equipped("backpack"):
        mode="drop"
    pending_mode=mode
    pending_source=model.items[selected_uid].duplicate(true)
    if mode=="drop":
        near_source=_drop_source()
        nearby_wanted=true
    feedback.text="Escolha uma célula livre"+(" no chão" if mode=="drop" else " para a nova pilha" if mode=="split" else " para retirar a peça")
    refresh()

func commit_target(grid: Control, at: Vector2i, rotated: Variant=null) -> void:
    var model: RefCounted=player.bag_inventory
    var uid=drag_uid if not drag_uid.is_empty() else selected_uid
    var expected=drag_source if not drag_uid.is_empty() else pending_source
    if not model.items.has(uid) or (not expected.is_empty() and model.items[uid]!=expected):
        cancel_pending()
        feedback.text="O item mudou durante a operação"
        return
    if pending_mode=="drop" and grid.container_id!="drop_here" and not (model.world_containers.has(grid.container_id) and model.world_containers[grid.container_id].kind=="ground"):
        feedback.text="Escolha uma célula no chão"
        return
    var orientation=bool(model.items[uid].get("rot",false)) if rotated==null else bool(rotated)
    var dropping=pending_mode=="drop"
    var accepted: bool=player.place_item(uid,grid.container_id,at.x,at.y,orientation,1 if pending_mode=="split" else 0,pending_mode=="split")
    if accepted:
        if dropping and model.items.has(uid):
            near_source=model.items[uid].location
        cancel_pending()
        refresh()
        feedback.text="Guardando peça..." if player.inventory_actions.busy() else "Objeto posicionado"
    else:
        feedback.text=player.inventory_message if not player.inventory_message.is_empty() else model.message

func start_drag(uid: String, grip: Vector2i) -> void:
    if player.inventory_actions.busy():
        feedback.text="Conclua a ação atual"
        return
    drag_uid=uid
    drag_grip=grip
    drag_source=player.bag_inventory.items[uid].duplicate(true)
    drag_rot=bool(drag_source.get("rot",false))
    for grid in grids:
        for tile in grid.get_children():
            if "uid" in tile and tile.uid==uid:
                tile.modulate.a=.25

func cancel_pending() -> void:
    selected_uid=""
    pending_mode=""
    pending_source={}
    drag_uid=""
    drag_source={}
    hover_grid=null
    for grid in grids:
        if is_instance_valid(grid):
            grid.show_candidate(Vector2i(-1,-1),Vector2i.ONE,false)
            for tile in grid.get_children():
                if "uid" in tile:
                    tile.modulate.a=1
    if inspection!=null:
        _inspection()
        refresh.call_deferred()

func rotate_selected() -> void:
    var id=drag_uid if not drag_uid.is_empty() else selected_uid
    var model: RefCounted=player.bag_inventory
    if not model.items.has(id) or not bool(model.catalog[model.items[id].definition].get("can_rotate",true)):
        return
    if not drag_uid.is_empty():
        var old_size: Vector2i=model.form(model.items[id].definition,drag_rot)
        drag_grip=Vector2i(drag_grip.y,old_size.x-1-drag_grip.x) if drag_rot else Vector2i(old_size.y-1-drag_grip.y,drag_grip.x)
        drag_rot=not drag_rot
        _hover(get_viewport().get_mouse_position())
        return
    if not selected_uid.is_empty():
        _notify(player.rotate_item(selected_uid),"Objeto girado")

func _hover(point: Vector2) -> void:
    hover_grid=null
    hover_item=""
    var model: RefCounted=player.bag_inventory
    if not model.items.has(drag_uid):
        return
    for grid in grids:
        grid.show_candidate(Vector2i(-1,-1),Vector2i.ONE,false)
    if not scroll.get_global_rect().has_point(point):
        return
    for grid in grids:
        if not grid.is_visible_in_tree() or not grid.get_global_rect().has_point(point):
            continue
        var clip=grid.get_parent().get_global_rect()
        if not clip.has_point(point):
            continue
        var local=grid.get_global_transform().affine_inverse()*point
        if not Rect2(Vector2.ZERO,Vector2(grid.cols*(grid.cell+4)-4,grid.rows*(grid.cell+4)-4)).has_point(local):
            continue
        hover_grid=grid
        hover_cell=grid.cell_at(local)-drag_grip
        hover_item=grid.item_at(local)
        var shape: Vector2i=model.form(model.items[drag_uid].definition,drag_rot)
        var valid=hover_cell.x>=0 and hover_cell.x+shape.x<=5 and hover_cell.y>=0 if grid.container_id=="drop_here" else model.preview(drag_uid,grid.container_id,hover_cell.x,hover_cell.y,drag_rot)
        var merging=not hover_item.is_empty() and hover_item!=drag_uid and model.items[hover_item].definition==model.items[drag_uid].definition and model.catalog[model.items[drag_uid].definition].stack>1 and model.items[hover_item].count<model.catalog[model.items[hover_item].definition].stack
        grid.show_candidate(hover_cell,shape,valid or merging,merging)
        break

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and (personal.visible or nearby.visible):
        var focus=get_viewport().gui_get_focus_owner()
        if focus is LineEdit or focus is TextEdit:
            return
        if event.physical_keycode==KEY_R and not selected_uid.is_empty():
            rotate_selected()
            get_viewport().set_input_as_handled()
        elif event.physical_keycode==KEY_ESCAPE:
            if player.world_interaction!=null and not player.world_interaction.pending_id.is_empty():
                player.world_interaction.close_interaction()
                cancel_pending()
                get_viewport().set_input_as_handled()
                return
            if player.action.state!="idle" and player.action.action_id!="access":
                player.action.cancel()
            if not selected_uid.is_empty() or not drag_uid.is_empty() or not pending_mode.is_empty():
                cancel_pending()
            elif nearby.visible:
                close_nearby()
            else:
                toggle(0)
            get_viewport().set_input_as_handled()
    if drag_uid.is_empty():
        return
    if event is InputEventMouseMotion:
        _hover(event.position)
    elif event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
        _hover(event.position)
        if hover_grid!=null:
            if not hover_item.is_empty() and hover_grid.preview_merge:
                _notify(player.merge_items(drag_uid,hover_item,int(drag_source.count)),"Pilhas unidas")
                cancel_pending()
            else:
                commit_target(hover_grid,hover_cell,drag_rot)
        drag_uid=""
        drag_source={}
        for grid in grids:
            grid.show_candidate(Vector2i(-1,-1),Vector2i.ONE,false)
            for tile in grid.get_children():
                if "uid" in tile:
                    tile.modulate.a=1
        get_viewport().set_input_as_handled()

func show_container(id: String) -> bool:
    if not player.bag_inventory.accessible(id):
        return false
    nearby_wanted=true
    near_source=id
    refresh()
    return true

func open_nearby() -> void:
    if not player.set_hud_open(true):
        feedback.text="Conclua a ação atual"
        return
    nearby_wanted=true
    refresh()

func close_nearby(close_world: bool=true) -> void:
    cancel_pending()
    nearby_wanted=false
    if close_world and player.world_interaction!=null and player.world_interaction.has_interaction():
        player.world_interaction.close_interaction(false)
    refresh()

func toggle(index: int) -> void:
    var panel=personal if index==0 else windows[1]
    if not panel.visible and not player.set_hud_open(true):
        feedback.text="Conclua a ação atual"
        return
    cancel_pending()
    if index==0:
        personal.visible=not personal.visible
    else:
        windows[1].visible=not windows[1].visible
    refresh()

func sync_lock() -> void:
    player.set_hud_open(personal.visible or nearby.visible or windows[1].visible)

func _layout() -> void:
    if personal==null:
        return
    var viewport=get_viewport_rect().size
    size=viewport
    var desired=63 if viewport.y>=850 else 54
    if cell_size!=desired:
        cell_size=desired
        refresh.call_deferred()
    var stacked=viewport.x<1000
    var personal_width=646 if viewport.y>=850 else 600
    personal.size.x=personal_width
    storage.get_parent().custom_minimum_size.x=420 if viewport.y>=850 else 350
    equipped.get_parent().custom_minimum_size.x=222 if viewport.y>=850 else 230
    var near_width=394 if viewport.y>=850 else 340
    nearby.size.x=near_width
    scroll.offset_top=70 if viewport.y>=850 else 52
    var left=maxf(0,(viewport.x-32-(personal_width if stacked else personal_width+14+near_width))/2)
    personal.position=Vector2(left,0)
    var x=left if stacked else left+(personal_width+14 if personal.visible else 0)
    var y=personal.size.y+14 if stacked and personal.visible else 0
    nearby.position=Vector2(x,y)
    reopen.position=Vector2(x,y)
    reopen.size.x=340
    var bottom=maxf(personal.size.y if personal.visible else 0,y+(nearby.size.y if nearby.visible else 50 if reopen.visible else 0))
    workspace.custom_minimum_size=Vector2(maxf(viewport.x-48,600),bottom+10)

func _notify(accepted: bool, text: String) -> void:
    feedback.text=text if accepted else (player.inventory_message if not player.inventory_message.is_empty() else player.bag_inventory.message if not player.bag_inventory.message.is_empty() else "Ação indisponível")

func icon_type(definition: String) -> String:
    if definition in ["water","food","bandage"]:
        return definition
    if definition=="medicine":
        return "medicine"
    if definition=="moletom_cinza":
        return "hoodie"
    if definition=="baton":
        return "baton"
    var slot: String=player.bag_inventory.catalog[definition].get("slot","")
    return {"shirt":"shirt","pants":"pants","boots":"boots","belt":"belt","backpack":"bag"}.get(slot,"tools")

func icon(definition: String) -> Texture2D:
    var type=icon_type(definition)
    if not icon_cache.has(type):
        var path="res://personagem/c05_icons/"+str(type)+".svg"
        icon_cache[type]=load(path) if ResourceLoader.exists(path) else null
    return icon_cache[type]
