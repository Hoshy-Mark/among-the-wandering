extends "res://personagem/mundo66.gd"

var house: Node3D
var blocked_message=""
var blocked_time=0.0

func request_open(id: String) -> bool:
    if house!=null and house.bindings.has(id):
        player.update_nearby()
        if id in player.bag_inventory.reachable and not house.clear_to_open(id):
            blocked_message="Libere espaço diante do móvel"
            blocked_time=2
            return false
    blocked_message=""
    var accepted=super.request_open(id)
    if accepted and house!=null and house.bindings.has(id):
        var bounds: AABB=house.groups[house.bindings[id]].bounds
        var direction: Vector3=house.home.model.to_global(bounds.get_center())-player.global_position
        player.avatar.rotation.y=atan2(direction.x,direction.z)
    return accepted

func advance(delta: float) -> void:
    blocked_time=maxf(0,blocked_time-delta)
    super.advance(delta)

func _update_prompt() -> void:
    super._update_prompt()
    if house!=null and house.bindings.has(nearest_id):
        var group: Dictionary=house.groups[house.bindings[nearest_id]]
        var bounds: AABB=group.bounds
        var center=bounds.get_center()
        prompt.global_position=house.home.model.to_global(Vector3(center.x,bounds.end.y+.18,center.z))
        prompt.text+="\n"+str(player.bag_inventory.world_containers[nearest_id].name)
    if blocked_time>0 and prompt.visible:
        prompt.text=blocked_message

func _build(id: String, kind: String) -> Node3D:
    if house==null or not house.bindings.has(id):
        return super._build(id,kind)
    var node=Node3D.new()
    add_child(node)
    var contents=Node3D.new()
    contents.name="Contents"
    contents.visible=false
    node.add_child(contents)
    var label=Label3D.new()
    label.name="Title"
    label.visible=false
    label.position.y=1.2
    label.font_size=22
    label.pixel_size=.003
    label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    node.add_child(label)
    return node

func _pose(id: String) -> void:
    if house==null or not house.bindings.has(id):
        super._pose(id)
        return
    var group: String=house.bindings[id]
    var fraction=0.0
    for candidate in house.bindings:
        if house.bindings[candidate]==group:
            fraction=maxf(fraction,float(progress.get(candidate,0)))
    house.apply_fraction(group,smoothstep(0,1,fraction))
