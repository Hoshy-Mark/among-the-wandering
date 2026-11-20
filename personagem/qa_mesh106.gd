extends SceneTree
var checks=0
var failed=false
var pose_pairs=0
var maximum_pose_error=0.0
var maximum_arm_error=0.0
var source_paths={}
const SOURCES=["r50/body.res","r51/actions.res","r53/actions.res","r54/combat.res","r55/reactions.res","r57/obstacles.res","r58/states.res","r59/flow.res"]
func _initialize() -> void:call_deferred("run")
func expect(value: bool,message: String) -> void:
    if not value:failed=true;push_error("R106_MESH_FAIL "+message)
    else:checks+=1
func paths(lib: AnimationLibrary) -> Dictionary:
    var result={}
    for id in lib.get_animation_list():
        var animation=lib.get_animation(id);var row=[]
        for t in animation.get_track_count():row.append(str(animation.track_get_path(t)))
        result[id]=row
    return result
func body_mesh(avatar: Node) -> MeshInstance3D:
    for mesh in avatar._all_meshes(avatar.body):
        if "CABECA_E_CORPO" in str(mesh.name):return mesh
    return null
func bindings(mesh: MeshInstance3D,skeleton: Skeleton3D) -> Array:
    var result=[]
    for n in mesh.skin.get_bind_count():
        var name=mesh.skin.get_bind_name(n);var id=skeleton.find_bone(name) if name!="" else mesh.skin.get_bind_bone(n)
        assert(id>=0);result.append(skeleton.get_bone_global_pose(id)*mesh.skin.get_bind_pose(n))
    return result
func samples(avatar: Node) -> Array:
    var instance=body_mesh(avatar);var mesh=avatar.original_body_mesh;var result=[]
    for surface in mesh.get_surface_count():
        var arrays=mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var selected=[]
        for v in vertices.size():
            if absf(vertices[v].x)>=.26:selected.append(v)
        var step=maxi(1,selected.size()/32)
        for n in range(0,selected.size(),step):
            result.append({"surface":surface,"index":selected[n]})
    return result
func mesh_cache(avatar: Node) -> Dictionary:
    var mesh=avatar.original_body_mesh;var result={"mode":mesh.blend_shape_mode,"surfaces":[]}
    for surface in mesh.get_surface_count():
        var arrays=mesh.surface_get_arrays(surface);var shapes=[]
        var targets=mesh.surface_get_blend_shape_arrays(surface)
        expect(targets.size()==mesh.get_blend_shape_count(),"native blendshape arrays available for measured surface "+str(surface))
        if targets.size()!=mesh.get_blend_shape_count():return {}
        for target in targets:shapes.append(target[Mesh.ARRAY_VERTEX])
        result.surfaces.append({"positions":arrays[Mesh.ARRAY_VERTEX],"bones":arrays[Mesh.ARRAY_BONES],"weights":arrays[Mesh.ARRAY_WEIGHTS],"shapes":shapes})
    return result
func active(avatar: Node) -> Dictionary:
    var instance=body_mesh(avatar);var result={}
    for k in instance.mesh.get_blend_shape_count():
        var value=instance.get_blend_shape_value(k)
        if absf(value)>.000001:result[k]=value
    return result
func correspondences(selected: Array,male_cache: Dictionary,female_cache: Dictionary) -> Array:
    var result=[];var error=0.0
    for sample in selected:
        var source=male_cache.surfaces[sample.surface];var target=female_cache.surfaces[sample.surface]
        var p=source.positions[sample.index];var best=-1;var closest=INF
        for n in target.positions.size():
            var distance=p.distance_squared_to(target.positions[n])
            if distance<closest:closest=distance;best=n
        assert(best>=0);error=maxf(error,sqrt(closest))
        result.append({"surface":sample.surface,"index":best})
    expect(error<.00001,"imported protected arm vertices match by bind position after vertex optimization")
    return result
func point(cache: Dictionary,sample: Dictionary,matrices: Array,blends: Dictionary) -> Vector3:
    var data=cache.surfaces[sample.surface];var v=sample.index
    var positions: PackedVector3Array=data.positions;var p=positions[v]
    for k in blends:
        var target: PackedVector3Array=data.shapes[k]
        p+=(target[v]-positions[v] if cache.mode==Mesh.BLEND_SHAPE_MODE_NORMALIZED else target[v])*float(blends[k])
    var bones: PackedInt32Array=data.bones;var weights: PackedFloat32Array=data.weights
    var count=int(bones.size()/positions.size());var value=Vector3.ZERO
    for n in count:
        var at=v*count+n
        if weights[at]>.000001:value+=(matrices[bones[at]]*p)*weights[at]
    return value
func pose(avatar: Node,id: String,phase: float) -> void:
    assert(avatar.set_motion(id));avatar.motion_source="";avatar.motion_blend=1.;avatar.motion_clock=phase*avatar.player.get_animation(avatar.clips[id]).length;avatar.motion_paused=false;avatar.advance(0);avatar.motion_paused=true
func run() -> void:
    for source in SOURCES:source_paths[source]=paths(load("res://personagem/assets/motion/"+source))
    var male=load("res://personagem/personagem.tscn").instantiate();male.manual_update=true;root.add_child(male)
    var female=load("res://personagem/personagem_feminina106.tscn").instantiate();female.manual_update=true;root.add_child(female)
    male.hand_layer.set_pose("Relaxed");female.hand_layer.set_pose("Relaxed")
    expect(male.skeleton.get_bone_count()==58 and female.skeleton.get_bone_count()==58,"both variants retain fifty-eight bones")
    var rest_error=0.0
    for n in male.skeleton.get_bone_count():
        expect(male.skeleton.get_bone_name(n)==female.skeleton.get_bone_name(n),"bone identity "+str(n))
        var a=male.skeleton.get_bone_global_rest(n);var b=female.skeleton.get_bone_global_rest(n)
        rest_error=maxf(rest_error,a.origin.distance_to(b.origin))
        for k in 3:rest_error=maxf(rest_error,a.basis[k].distance_to(b.basis[k]))
    expect(rest_error<.000003,"global rest frames preserved")
    for name in male.player.get_animation_library_list():
        if not female.player.has_animation_library(name):continue
        var ml=male.player.get_animation_library(name);var fl=female.player.get_animation_library(name)
        for id in ml.get_animation_list():
            expect(ml.get_animation(id)!=fl.get_animation(id),"per-instance animation resource "+str(name)+"/"+id)
            for avatar in [male,female]:
                var animation=avatar.player.get_animation_library(name).get_animation(id)
                for t in animation.get_track_count():
                    var track=animation.track_get_path(t)
                    expect(avatar.has_node(NodePath(str(track).split(":")[0])),"resolvable animation target "+str(track))
    var selected=samples(male);expect(not selected.is_empty(),"actual arm vertex sample set")
    var male_cache=mesh_cache(male);var female_cache=mesh_cache(female)
    if male_cache.is_empty() or female_cache.is_empty():quit(1);return
    var matched=correspondences(selected,male_cache,female_cache)
    var motions=["idle","walk","run","crouch_idle","crouch","turn_left","inventory_access","equip_item","eat","drink","medicine","bandage","punch","push","strike_onehand","fall","get_up","open_window","vault_window","vault_fence"]
    var profile={"hair_id":"none","beard_id":"none","mustache_id":"none","pants_id":"calca_carvao","boots_id":"botas_escuras"}
    for shirt in ["camiseta_oliva","camisa_lisa_azul","moletom_cinza","paleto_areia"]:
        profile.shirt_id=shirt;assert(male.set_appearance(profile));assert(female.set_appearance(profile))
        for id in motions:
            expect(male.clips.has(id) and female.clips.has(id),"motion available "+id)
            for phase in [0.,.25,.5,.75]:
                pose(male,id,phase);pose(female,id,phase);pose_pairs+=1
                for n in male.skeleton.get_bone_count():
                    var a=male.skeleton.get_bone_global_pose(n);var b=female.skeleton.get_bone_global_pose(n)
                    maximum_pose_error=maxf(maximum_pose_error,a.origin.distance_to(b.origin))
                    for axis in 3:maximum_pose_error=maxf(maximum_pose_error,a.basis[axis].distance_to(b.basis[axis]))
                var ma=bindings(body_mesh(male),male.skeleton);var mb=bindings(body_mesh(female),female.skeleton)
                var ba=active(male);var bb=active(female)
                for i in selected.size():maximum_arm_error=maxf(maximum_arm_error,point(male_cache,selected[i],ma,ba).distance_to(point(female_cache,matched[i],mb,bb)))
    expect(maximum_pose_error<.00001,"all sampled native skeleton poses retained")
    expect(maximum_arm_error<.00001,"skinned protected arm vertices retained through sampled poses")
    for source in SOURCES:expect(paths(load("res://personagem/assets/motion/"+source))==source_paths[source],"source motion resource never mutated "+source)
    var report=female.appearance_report();expect(report.base=="female106" and female.load_report(report),"female report roundtrip has dedicated identity")
    var old=female.selection.duplicate(true);expect(not female.set_appearance({"hair_id":"unknown"}) and female.selection==old,"invalid female customization leaves visible state unchanged")
    expect(not female.set_appearance({"beard_id":"curta_ajustada"}) and female.selection==old,"unadapted male facial accessory is rejected before mutation")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/mesh106"))
    var output={"passed":not failed,"checks":checks,"pose_pairs":pose_pairs,"arm_vertex_samples_per_pose":selected.size(),"maximum_native_bone_pose_error":maximum_pose_error,"maximum_skinned_arm_error_m":maximum_arm_error,"maximum_rest_error":rest_error}
    FileAccess.open("res://qa/mesh106/results.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
    print(JSON.stringify(output));quit(1 if failed else 0)
