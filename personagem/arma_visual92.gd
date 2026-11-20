extends "res://personagem/arma_visual87.gd"
var tip=Vector3(0,.042,.18)
var support_offset=Vector3(.08,-.025,-.16)
var long_gun=false
var cylinder: Node3D
func configure(id: String) -> void:
    if definition==id:return
    super.configure(id)
    tip=Vector3(0,.042,.18);support_offset=Vector3(.08,-.025,-.16);long_gun=id=="carbine";cylinder=null
    if id=="revolver":
        tip=Vector3(0,.047,.215)
        _box(Vector3(.04,.10,.055),Vector3(0,-.035,-.008),Color("594332"))
        _box(Vector3(.052,.052,.075),Vector3(0,.043,.008),Color("69736f"))
        _box(Vector3(.03,.03,.14),Vector3(0,.047,.135),Color("89928e"))
        cylinder=Node3D.new();add_child(cylinder);cylinder.position=Vector3(0,.043,.02).rotated(Vector3.UP,BARREL_YAW);cylinder.rotation.y=BARREL_YAW
        var piece=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=.033;mesh.bottom_radius=.033;mesh.height=.058;mesh.radial_segments=8
        piece.mesh=mesh;piece.rotation.x=PI/2;piece.material_override=_material(Color("929b95"),true);cylinder.add_child(piece)
        _box(Vector3(.012,.01,.01),Vector3(0,.069,.197),Color("222b28"))
    elif id=="carbine":
        tip=Vector3(0,.055,.46);support_offset=Vector3(.08,-.025,-.055)
        _box(Vector3(.038,.095,.055),Vector3(0,-.035,0),Color("493a2c"))
        _box(Vector3(.06,.065,.18),Vector3(0,.046,.045),Color("56625d"))
        _box(Vector3(.065,.075,.18),Vector3(0,.04,-.18),Color("68503a"))
        _box(Vector3(.065,.105,.035),Vector3(0,.025,-.28),Color("443c32"))
        _box(Vector3(.058,.055,.18),Vector3(0,.025,.14),Color("806347"))
        _box(Vector3(.023,.026,.26),Vector3(0,.055,.33),Color("75827b"))
        _box(Vector3(.036,.09,.065),Vector3(0,-.03,.10),Color("38433e"))
        _box(Vector3(.016,.022,.018),Vector3(0,.078,.43),Color("202a25"))
        _box(Vector3(.024,.022,.024),Vector3(0,.088,-.015),Color("202a25"))
    else:return
    muzzle=_box(Vector3(.06,.06,.07),tip,Color("ffd67b"));muzzle.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;muzzle.visible=false
func muzzle_position() -> Vector3:return to_global(tip.rotated(Vector3.UP,BARREL_YAW))
func reload_display(phase: float,loading: bool) -> void:
    if is_instance_valid(cylinder):cylinder.position=(Vector3(-.055*sin(phase*PI),.043,.02) if loading else Vector3(0,.043,.02)).rotated(Vector3.UP,BARREL_YAW)
