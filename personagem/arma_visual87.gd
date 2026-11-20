extends "res://personagem/arma_visual86.gd"
var muzzle: MeshInstance3D
const BARREL_YAW=.674
func configure(id: String) -> void:
    if definition==id:return
    super.configure(id)
    muzzle=null
    if id!="pistol":return
    _box(Vector3(.042,.105,.055),Vector3(0,-.035,0),Color("393d39"))
    _box(Vector3(.048,.048,.19),Vector3(0,.042,.06),Color("747e7b"))
    _box(Vector3(.025,.012,.025),Vector3(0,.073,-.012),Color("242c29"))
    _box(Vector3(.012,.012,.012),Vector3(0,.073,.135),Color("242c29"))
    muzzle=_box(Vector3(.06,.06,.07),Vector3(0,.042,.18),Color("ffd67b"))
    muzzle.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    muzzle.visible=false
func _box(size: Vector3,point: Vector3,color: Color) -> MeshInstance3D:
    var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=size
    node.mesh=mesh;node.position=point.rotated(Vector3.UP,BARREL_YAW);node.rotation.y=BARREL_YAW;node.material_override=_material(color,false);add_child(node)
    return node
func muzzle_position() -> Vector3:return to_global(Vector3(0,.042,.18).rotated(Vector3.UP,BARREL_YAW))
func barrel_direction() -> Vector3:return (global_basis*Vector3.FORWARD.rotated(Vector3.UP,BARREL_YAW)*-1).normalized()
