extends Node3D
var batches={}
var colors={"reboco":Color(.66,.64,.57),"cap":Color(.40,.41,.38),"tijolo":Color(.48,.24,.15),"argamassa":Color(.63,.57,.46),"madeira":Color(.30,.23,.14),"poste":Color(.22,.18,.12),"metal":Color(.32,.38,.37)}
func part(key: String, size: Vector3, at: Vector3) -> void:
    if not batches.has(key):batches[key]=[]
    batches[key].append(Transform3D(Basis.from_scale(size),at))
func build(model: Dictionary, a: Vector3, b: Vector3) -> void:
    global_position=(a+b)/2
    var d=(b-a).normalized()
    rotation.y=atan2(-d.z,d.x)
    var length=a.distance_to(b)
    var h: float=model.height
    var t: float=model.thickness
    if model.id in ["reboco","muro_alto"]:
        part("reboco",Vector3(length,h-.045,t),Vector3(0,(h-.045)/2,0))
        part("cap",Vector3(length,.045,t if model.high else t+.035),Vector3(0,h-.0225,0))
        var count=maxi(1,ceili(length/3))
        for i in count+1:part("cap",Vector3(.13,h,t+.025),Vector3(-length/2+length*i/count,h/2,0))
    elif model.id=="tijolo":
        part("argamassa",Vector3(length,h,t-.025),Vector3(0,h/2,0))
        var rows=6
        var count=maxi(1,ceili(length/.48))
        for row in rows:
            for i in count:
                var left=-length/2+length*i/count
                part("tijolo",Vector3(length/count-.012,h/rows-.012,t),Vector3(left+length/count/2+(0.0 if row%2==0 else .005),h/rows*(row+.5),0))
    elif model.id in ["ripas","madeira_alta"]:
        var count=maxi(1,ceili(length/.17))
        for i in count:part("madeira",Vector3(length/count-(.028 if not model.high else .008),h,.055),Vector3(-length/2+length*(i+.5)/count,h/2,0))
        for y in [.25,h-.25]:part("poste",Vector3(length,.08,.08),Vector3(0,y,0))
    else:
        for y in [.05,h-.025]:part("metal",Vector3(length,.03,.035),Vector3(0,y,0))
        var count=maxi(1,ceili(length/.16))
        for i in count+1:part("metal",Vector3(.009,h,.009),Vector3(-length/2+length*i/count,h/2,0))
        for j in range(1,7):part("metal",Vector3(length,.009,.009),Vector3(0,h*j/7,0))
    if model.id in ["ripas","madeira_alta","tela"]:
        var count=maxi(1,ceili(length/2.5))
        for i in count+1:part("metal" if model.id=="tela" else "poste",Vector3(.075,h,.075),Vector3(-length/2+length*i/count,h/2,0))
    for key in batches:
        var mm=MultiMesh.new()
        mm.transform_format=MultiMesh.TRANSFORM_3D
        mm.mesh=BoxMesh.new()
        mm.mesh.size=Vector3.ONE
        mm.instance_count=batches[key].size()
        for i in batches[key].size():mm.set_instance_transform(i,batches[key][i])
        var visual=MultiMeshInstance3D.new()
        visual.multimesh=mm
        var material=StandardMaterial3D.new()
        material.albedo_color=colors[key]
        material.roughness=.9
        visual.material_override=material
        add_child(visual)
    var body=StaticBody3D.new()
    var collision=CollisionShape3D.new()
    collision.shape=BoxShape3D.new()
    collision.shape.size=Vector3(length,h,t)
    collision.shape.margin=.001
    collision.position=Vector3(0,h/2,0)
    body.add_child(collision)
    add_child(body)
    set_meta("model_id",model.id)
    set_meta("zombies_can_cross",model.zombies_can_cross)
