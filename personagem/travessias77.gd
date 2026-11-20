extends Node3D
var scene: Node3D
var obstacles: Array[Node3D]=[]
var nearest: Node3D
var prompt: Label3D
func setup(root_scene: Node3D) -> void:
    scene=root_scene
    for id in scene.player.map_doors.doors:
        var data: Dictionary=scene.player.map_doors.doors[id]
        if data.get("kind","")!="window":continue
        var node=load("res://personagem/obstaculo_mapa113.gd").new()
        add_child(node)
        node.scene=scene
        node.opening=data
        node.opening_id=id
        var center: Vector3=data.get("aperture_point",data.hinge.get_parent().global_transform*scene.player.map_doors._pose(data,0)*data.leaf.position)
        node.ledge_y=center.y-(data.aperture_size.y if data.has("aperture_size") else data.collider.shape.size.y)/2-.005
        node.base_center=center
        node.base_center.y=scene.spawn.y
        var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/variacoes_janelas76.json"))
        for entry in config.windows:
            if entry.id==id:node.normal=data.hinge.get_parent().global_basis*Vector3(entry.normal[0],entry.normal[1],entry.normal[2])
        node.set_meta("map77",true)
        node.locate(scene.player)
        obstacles.append(node)
    var dressing: Node3D=scene.city.get_node("UrbanDressing")
    for wall in dressing.data.get("shared_walls",[]):
        if absf(float(wall.height_m)-1.15)>.01:continue
        var node=load("res://personagem/obstaculo_mapa77.gd").new()
        add_child(node)
        node.scene=scene
        node.kind="fence"
        node.opening_id=wall.id
        node.a=dressing.to_global(Vector3(wall.a[0],0,wall.a[1]))
        node.b=dressing.to_global(Vector3(wall.b[0],0,wall.b[1]))
        node.ledge_y=node.a.y+1.21
        if node.a.distance_to(node.b)<1.5:node.queue_free();continue
        node.set_meta("map77",true)
        node.locate(scene.player)
        obstacles.append(node)
    scene.player.traversal=load("res://personagem/travessia_mapa77.gd").new()
    scene.player.traversal.setup(scene.player)
    scene.player.map_traversals=self
    prompt=Label3D.new()
    prompt.font_size=26
    prompt.pixel_size=.002
    prompt.no_depth_test=true
    prompt.billboard=BaseMaterial3D.BILLBOARD_ENABLED
    add_child(prompt)
func closest(window_only: bool=false) -> Node3D:
    var candidate: Node3D
    var distance=1.6
    for obstacle in obstacles:
        if window_only and obstacle.kind!="window":continue
        obstacle.locate(scene.player)
        var delta=obstacle.global_position-scene.player.global_position
        var horizontal=Vector2(delta.x,delta.z).length()
        if horizontal<distance:candidate=obstacle;distance=horizontal
    return candidate
func request() -> bool:
    var obstacle=closest()
    if obstacle==null:return false
    var accepted=scene.player.request_cross(obstacle)
    if not accepted:scene.game_ui.feedback.text=scene.player.traversal.message
    return accepted
func _process(_delta: float) -> void:
    if prompt==null:return
    nearest=closest()
    prompt.visible=nearest!=null and not scene.player.hud_open and not scene.player.traversal.is_active()
    if prompt.visible:
        prompt.global_position=nearest.global_position+Vector3.UP*1.45
        prompt.text="B · Atravessar janela" if nearest.kind=="window" else "B · Transpor muro baixo"

    if nearest!=null and nearest.has_meta("fence78"):
        prompt.global_position=nearest.global_position+Vector3.UP*(float(nearest.model.height)+.25)
        prompt.text="B · Escalar · 12 de fôlego" if nearest.model.high else "B · Transpor · 3 de fôlego"
