extends Control
var uid=""
var selected=false
var tint=Color("536463")
var icon_texture: Texture2D
var rotated=false
var with_name=false

func setup(id: String, item: Dictionary, definition: Dictionary, icon: Texture2D, shape: Vector2i) -> void:
    uid=id
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    clip_contents=true
    tooltip_text=definition.name
    icon_texture=icon
    rotated=bool(item.get("rot",false))
    with_name=shape!=Vector2i.ONE
    if shape!=Vector2i.ONE:
        var title=Label.new()
        title.text=str(definition.name)
        title.clip_text=true
        title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
        title.add_theme_font_size_override("font_size",11)
        title.mouse_filter=Control.MOUSE_FILTER_IGNORE
        add_child(title)
        title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        title.offset_left=5
        title.offset_right=-5
        title.offset_top=-19
    if item.count>1:
        var count=Label.new()
        count.text="×%d"%item.count
        count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
        count.add_theme_font_size_override("font_size",12)
        count.mouse_filter=Control.MOUSE_FILTER_IGNORE
        add_child(count)
        count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        count.offset_top=-19
        count.offset_right=-4

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size),tint.darkened(.3))
    draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),tint.darkened(.15))
    draw_rect(Rect2(Vector2.ONE,size-Vector2(2,2)),Color("c9bca1") if selected else tint.lightened(.2),false,2 if selected else 1)
    if icon_texture!=null:
        var available=size-Vector2(12,23 if with_name else 12)
        var intrinsic=icon_texture.get_size()
        var envelope=Vector2(intrinsic.y,intrinsic.x) if rotated else intrinsic
        var factor=minf(available.x/envelope.x,available.y/envelope.y)
        var rendered=intrinsic*factor
        draw_set_transform(Vector2(size.x/2,6+available.y/2),PI/2 if rotated else 0)
        draw_texture_rect(icon_texture,Rect2(-rendered/2,rendered),false)
        draw_set_transform(Vector2.ZERO)
