extends Node3D
var scene: Node3D
var bursts=[]
func spawn(origin: Vector3,end: Vector3,normal: Vector3,kind: String) -> void:
    if bursts.size()>=24:_remove(0)
    var root=Node3D.new();add_child(root)
    var color=Color("903f3a") if kind=="flesh" else Color("a9a18e")
    if kind!="miss":
        for index in 5:
            var node=MeshInstance3D.new();var mesh=BoxMesh.new();mesh.size=Vector3.ONE*.018;node.mesh=mesh
            var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
            node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(node);node.global_position=end+normal*.012
            node.set_meta("velocity",(normal+Vector3(sin(index*2.4),.3+index*.12,cos(index*2.4))*.55)*.35)
    var tracer=MeshInstance3D.new();var cylinder=CylinderMesh.new();cylinder.top_radius=.002;cylinder.bottom_radius=.002;cylinder.height=maxf(.001,origin.distance_to(end));cylinder.radial_segments=4
    tracer.mesh=cylinder;var material=StandardMaterial3D.new();material.albedo_color=Color("b9ac78");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    tracer.material_override=material;tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(tracer);tracer.global_position=(origin+end)*.5
    if origin.distance_squared_to(end)>.000001:tracer.global_basis=Basis(Quaternion(Vector3.UP,(end-origin).normalized()))
    var valid_tracer=origin.distance_squared_to(end)>.000001;tracer.visible=valid_tracer
    bursts.append({"node":root,"elapsed":0.0,"tracer":tracer,"valid_tracer":valid_tracer})
func _remove(index: int) -> void:
    var entry=bursts[index];entry.node.queue_free();bursts.remove_at(index)
func advance(delta: float) -> void:
    if not is_finite(delta) or delta<0:return
    for index in range(bursts.size()-1,-1,-1):
        var entry=bursts[index];entry.elapsed+=delta;entry.tracer.visible=entry.valid_tracer and entry.elapsed<.065
        for child in entry.node.get_children():
            if child.has_meta("velocity"):child.global_position+=child.get_meta("velocity")*delta;child.scale=Vector3.ONE*maxf(.05,1-entry.elapsed/.26)
        if entry.elapsed>=.26:_remove(index)
func _physics_process(delta: float) -> void:
    if scene!=null and not scene.player.paused:advance(delta)
