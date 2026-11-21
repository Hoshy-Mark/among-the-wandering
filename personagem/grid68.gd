extends Control
var hud: Control
var container_id=""
var cell=54
var cols=4
var rows=4
var preview_cell=Vector2i(-1,-1)
var preview_size=Vector2i.ONE
var preview_valid=false
var preview_merge=false
var pressed_uid=""
var pressed_at=Vector2.ZERO
var grip=Vector2i.ZERO

func refresh() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    var model: RefCounted=hud.player.bag_inventory
    var dimensions=Vector2i(5,4) if container_id=="drop_here" else model.dimensions(container_id)
    cols=dimensions.x
    rows=dimensions.y
    custom_minimum_size=Vector2(cols*(cell+4)-4,rows*(cell+4)-4)
    size=custom_minimum_size
    if container_id!="drop_here":
        for uid in model.contents(container_id):
            var item: Dictionary=model.items[uid]
            var shape: Vector2i=model.form(item.definition,item.rot)
            var tile=load("res://personagem/tile68.gd").new()
            tile.size=Vector2(shape.x*(cell+4)-4,shape.y*(cell+4)-4)
            tile.position=Vector2(item.x*(cell+4),item.y*(cell+4))
            tile.selected=uid==hud.selected_uid
            tile.modulate.a=.25 if uid==hud.drag_uid else 1.0
            var kind=hud.icon_type(item.definition)
            tile.tint=Color("566c6e") if kind=="water" else Color("666452") if kind in ["food","bandage","medicine"] else Color("586469")
            add_child(tile)
            tile.setup(uid,item,model.catalog[item.definition],hud.icon(item.definition),shape)
    var overlay=load("res://personagem/preview68.gd").new()
    overlay.grid=self
    overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(overlay)
    queue_redraw()

func show_candidate(at: Vector2i, shape: Vector2i, valid: bool, merging: bool=false) -> void:
    preview_cell=at
    preview_size=shape
    preview_valid=valid
    preview_merge=merging
    get_child(get_child_count()-1).queue_redraw()

func item_at(point: Vector2) -> String:
    for child in get_children():
        if not "uid" in child:
            continue
        if Rect2(child.position,child.size).has_point(point):
            return child.uid
    return ""

func cell_at(point: Vector2) -> Vector2i:
    return Vector2i(floori(point.x/(cell+4)),floori(point.y/(cell+4)))

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if event.pressed:
            var target=item_at(event.position)
            if not hud.pending_mode.is_empty():
                hud.commit_target(self,cell_at(event.position))
            elif not target.is_empty():
                hud.select_item(target)
                pressed_uid=target
                pressed_at=event.position
                var item: Dictionary=hud.player.bag_inventory.items[target]
                grip=cell_at(event.position)-Vector2i(item.x,item.y)
            elif not hud.selected_uid.is_empty():
                hud.commit_target(self,cell_at(event.position))
            accept_event()
        else:
            var clicked=pressed_uid
            pressed_uid=""
            if not clicked.is_empty() and clicked==item_at(event.position) and hud.drag_uid.is_empty() and not hud.player.bag_inventory.owned(clicked):
                hud.quick_pickup.call_deferred(clicked)
    elif event is InputEventMouseMotion and not pressed_uid.is_empty() and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
        if event.position.distance_to(pressed_at)>5 and hud.drag_uid.is_empty():
            hud.start_drag(pressed_uid,grip)
            pressed_uid=""
        accept_event()

func _draw() -> void:
    for y in rows:
        for x in cols:
            var rect=Rect2(Vector2(x*(cell+4),y*(cell+4)),Vector2(cell,cell))
            draw_rect(rect,Color("25302b"))
            draw_rect(rect,Color("49594f"),false,1)
            draw_rect(rect.grow(-4),Color(.5,.6,.5,.05),false,1)

func _ready() -> void:
    mouse_filter=Control.MOUSE_FILTER_STOP

