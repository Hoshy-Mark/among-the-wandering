extends Control
var survey: RefCounted
var center=Vector2.ZERO
var zoom=3.0
var dragging=false
var roads=[]
var selected=""
signal picked(id: String)
func _ready() -> void:
    clip_contents=true;mouse_filter=Control.MOUSE_FILTER_STOP;custom_minimum_size=Vector2(200,240)
    roads=survey.roads
func project(point: Vector2) -> Vector2:return (point-center)*zoom+size*.5
func focus_player() -> void:center=survey.position;queue_redraw()
func set_zoom(value: float) -> void:zoom=clampf(value,1,14);queue_redraw()
func _draw() -> void:
    if survey==null:return
    draw_rect(Rect2(Vector2.ZERO,size),Color("d3c49a"))
    # Paper grain is deterministic and conveys print, not digital GPS.
    for y in range(0,int(size.y),7):
        for x in range(0,int(size.x),11):draw_circle(Vector2(x+(y%11),y),.55,Color(.31,.26,.15,.10))
    for tree in survey.trees:
        var p=project(tree)
        if Rect2(Vector2.ZERO,size).has_point(p):draw_arc(p,3,PI,TAU,6,Color(.29,.36,.22,.4),1,true)
    if survey.water.size()>2:
        var polygon=PackedVector2Array()
        for point in survey.water:polygon.append(project(Vector2(point[0],point[1])))
        draw_colored_polygon(polygon,Color("8eafb0"))
    for road in roads:
        var points=PackedVector2Array()
        for p in road.geometry.coordinates:points.append(project(Vector2(p[0],p[1])))
        if points.size()>1:
            var width=maxf(2,float(road.properties.get("road_width_m_proposed",4))*zoom)
            if road.properties.get("class","")=="trail":draw_polyline(points,Color("aa9470"),maxf(1,width*.3),true)
            else:draw_polyline(points,Color("968569"),width+2,true);draw_polyline(points,Color("eee1bb"),width,true)
    for id in survey.places:
        var place=survey.places[id];var p=project(place.point)
        if survey.cell(place.point) not in survey.data.cells:continue
        var footprint=Rect2(project(place.bounds.position),place.bounds.size*zoom)
        draw_rect(footprint,Color("ad9c79"));draw_rect(footprint,Color("7d7159"),false,1)
    # Opaque fog drawn last clips even long roads crossing unknown cells.
    var lo=center-size*.5/zoom;var hi=center+size*.5/zoom
    for x in range(floori(lo.x/8),ceili(hi.x/8)+1):
        for y in range(floori(lo.y/8),ceili(hi.y/8)+1):
            if "%d,%d"%[x,y] in survey.data.cells:continue
            var box=Rect2(project(Vector2(x,y)*8),Vector2.ONE*(8*zoom+.5));draw_rect(box,Color("bdb38e"))
            for stripe in range(0,ceili(box.size.x+box.size.y),10):
                var a=Vector2(maxf(0,stripe-box.size.y),minf(stripe,box.size.y));var b=Vector2(minf(stripe,box.size.x),maxf(0,stripe-box.size.x));draw_line(box.position+a,box.position+b,Color(.42,.40,.30,.25),1)
    for row in survey.known():
        var p=project(row.point);var color=Color("a45e3d") if row.marked else Color("56746b") if row.visited else Color("796a4a")
        draw_circle(p,5,color);draw_arc(p,8,0,TAU,24,Color("423c2c") if row.id==selected else Color("e7d9b1"),1.5,true)
    var here=project(survey.position);draw_circle(here,7,Color("f0e6c5"));draw_circle(here,4,Color("375d5b"));draw_arc(here,10,0,TAU,32,Color("375d5b"),1,true)
func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_WHEEL_UP:set_zoom(zoom*1.15)
        elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:set_zoom(zoom/1.15)
        elif event.button_index==MOUSE_BUTTON_LEFT:
            dragging=event.pressed
            if event.pressed:
                for row in survey.known():
                    if project(row.point).distance_to(event.position)<15:selected=row.id;picked.emit(row.id);break
        accept_event()
    elif event is InputEventMouseMotion and dragging:center-=event.relative/zoom;queue_redraw();accept_event()
