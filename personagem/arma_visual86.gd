extends Node3D
const GRIP=Transform3D(Basis(Vector3.FORWARD,Vector3.LEFT,Vector3.UP),Vector3(.073,.068,-.15))
var definition=""
func _ready() -> void:visible=false
func configure(id: String) -> void:
    if definition==id:return
    definition=id
    for child in get_children():child.visible=false;child.queue_free()
    if id=="baton":
        for entry in [[.0205,.18,-.035,Color(.24,.15,.08)],[.025,.31,.20,Color(.45,.29,.13)],[.029,.055,.383,Color(.38,.23,.10)]]:_cylinder(entry[0],entry[1],entry[2],entry[3],false)
    elif id=="metal_bar":
        _cylinder(.0205,.18,-.035,Color("303632"),false)
        var instance=MeshInstance3D.new();var box=BoxMesh.new();box.size=Vector3(.035,.355,.035)
        instance.mesh=box;instance.position.y=.2325;instance.material_override=_material(Color("7b8581"),true);add_child(instance)
        _cylinder(.024,.04,.43,Color("929b95"),true)
        _cylinder(.023,.03,-.14,Color("59635e"),true)
func _material(color: Color,metal: bool) -> StandardMaterial3D:
    var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.65 if metal else 1.0;mat.metallic=.65 if metal else 0.0
    return mat
func _cylinder(radius: float,height: float,y: float,color: Color,metal: bool) -> void:
    var instance=MeshInstance3D.new();var mesh=CylinderMesh.new()
    mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=8;mesh.rings=1
    instance.mesh=mesh;instance.position.y=y;instance.material_override=_material(color,metal);add_child(instance)
func attach(actor: Node3D) -> void:
    global_transform=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone("Hand.R"))*GRIP
