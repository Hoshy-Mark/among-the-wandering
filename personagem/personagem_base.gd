extends Node3D
## Componente visual reutilizável. Não cria câmera, mundo, UI ou controlador.
signal appearance_changed(profile: Dictionary)
signal speech_finished
@export var manual_update := false
var base_dir: String
var catalog: Dictionary
var poses: Dictionary
var expressions: Dictionary
var combinations: Dictionary
var clip: Dictionary
var selection: Dictionary
var body: Node3D
var skeleton: Skeleton3D
var socket: Node3D
var visual: Node3D
var holders: Dictionary={}
var player: AnimationPlayer
var audio: AudioStreamPlayer
var meshes: Array[MeshInstance3D]=[]
var shape_maps: Array[Dictionary]=[]
var weights: Dictionary={}
var speech_weights: Dictionary={"Selar_Labios":1.0}
var emotion_weights: Dictionary={}
var emotion_from: Dictionary={}
var emotion_to: Dictionary={}
var transition_time:=1.0
var transition_duration:=0.0
var clock:=0.0
var motion_clock:=0.0
var motion:="idle"
var motion_from: Array[Transform3D]=[]
var motion_blend:=1.0
var motion_paused:=false
var motion_rate:=1.0
var motion_source:=""
var motion_source_clock:=0.0
var motion_transition_duration:=.20
var head_yaw:=0.0
var gaze:=Vector2.ZERO
var blink:=0.0
var life_enabled:=false
var speech_active:=false
var speech_time:=0.0
var speech_last_time:=0.0
var speech_paused:=false
var initialized:=false
var clips: Dictionary={"idle":"R08/EA_Idle_Candidate_R04","walk":"R08/EA_Walk_Forward_Candidate_R04","run":"R08/EA_Run_Forward_Candidate_R08","crouch":"R14/EA_Crouch_Walk_Candidate_R12","crouch_idle":"R14/EA_Crouch_Idle_Candidate_R11","backward":"R08/EA_Walk_Backward_Candidate_R05","left":"R08/EA_Strafe_Left_Candidate_R05","right":"R08/EA_Strafe_Right_Candidate_R05","turn_ready":"R16/EA_Turn_Ready_Candidate_R15","turn_left":"R16/EA_Turn_90_Left_Candidate_R15","turn_right":"R16/EA_Turn_90_Right_Candidate_R15"}
var floor_support: Dictionary = {}
var floor_garments: Dictionary = {}
var original_body_mesh: Mesh
var clothed_body_mesh: Mesh
var applied_weights: Dictionary={}
var appearance_ready:=false
var runtime_stats: Dictionary={"model_reloads":0,"profile_updates":0}
var base_motion_pose: Array[Transform3D]=[]
var arm_blend: RefCounted
var hand_layer: RefCounted
@export var life_seed:=0
var life_rng:=RandomNumberGenerator.new()
var life_was_enabled:=false
var life_blink_clock:=0.0
var life_blink_delay:=3.5
var life_gaze_clock:=0.0
var life_gaze_hold:=2.0
var life_gaze_from:=Vector2.ZERO
var life_gaze_target:=Vector2.ZERO

func _ready() -> void:
    base_dir=get_script().resource_path.get_base_dir()+"/"
    catalog=_json("catalogo.json")
    poses=_json("poses_fala.json")
    expressions=_json("expressoes.json")
    combinations=_json("combinacoes.json")
    clip=_json("frase_fala.json")
    visual=Node3D.new()
    visual.name="Visual"
    add_child(visual)
    body=load(base_dir+str(catalog.body)).instantiate()
    visual.add_child(body)
    skeleton=body.find_children("*","Skeleton3D",true,false)[0]
    arm_blend = load(base_dir + "transicao_articulada.gd").new()
    arm_blend.setup(self)
    var attachment:=BoneAttachment3D.new()
    attachment.bone_name="Head"
    skeleton.add_child(attachment)
    socket=Node3D.new()
    attachment.add_child(socket)
    socket.transform=skeleton.get_bone_global_rest(skeleton.find_bone("Head")).affine_inverse()*Transform3D(Basis.IDENTITY,Vector3(0,1.6,0))
    for family in ["hair","beard","mustache","brows","outfit"]:
        var holder:=Node3D.new()
        holder.name=family
        (visual if family=="outfit" else socket).add_child(holder)
        holders[family]=holder
    player=AnimationPlayer.new()
    player.root_node=NodePath("..")
    player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    add_child(player)
    for spec in [["base_r08","R08"],["crouch_r14","R14"],["turns_r16","R16"]]:
        var donor: Node=load(base_dir+"assets/motion/"+str(spec[0])+".glb").instantiate()
        var source: AnimationPlayer=donor.find_children("*","AnimationPlayer",true,false)[0]
        var source_library: AnimationLibrary=source.get_animation_library("")
        var library:=AnimationLibrary.new()
        for animation_id in source_library.get_animation_list():
            var copy_error:=library.add_animation(animation_id,source_library.get_animation(animation_id).duplicate(true))
            assert(copy_error==OK)
        if spec[1]=="R08":_lower_run_arms(library)
        for id in library.get_animation_list():
            var animation:=library.get_animation(id)
            for track in animation.get_track_count():
                var path:=animation.track_get_path(track)
                assert(path.get_subname_count()==1)
                var bone:=str(path.get_subname(0))
                assert(skeleton.find_bone(bone)>=0)
                animation.track_set_path(track,NodePath(str(get_path_to(skeleton))+":"+bone))
        var library_error:=player.add_animation_library(spec[1],library)
        assert(library_error==OK)
        donor.free()
    if ResourceLoader.exists(base_dir+"assets/motion/r50/body.res") and "--bake-base" not in OS.get_cmdline_user_args():
        var library: AnimationLibrary=load(base_dir+"assets/motion/r50/body.res").duplicate(true)
        for id in library.get_animation_list():
            var animation:=library.get_animation(id)
            for track in animation.get_track_count():
                var name:=str(animation.track_get_path(track).get_subname(0))
                animation.track_set_path(track,NodePath(str(get_path_to(skeleton))+":"+name))
        assert(player.add_animation_library("Body50",library)==OK)
        for id in library.get_animation_list():
            clips[id]="Body50/"+id
        hand_layer=load(base_dir+"maos.gd").new()
        hand_layer.setup(self)
    if ResourceLoader.exists(base_dir+"assets/motion/r51/actions.res") and "--bake-actions" not in OS.get_cmdline_user_args():
        var action_library: AnimationLibrary=load(base_dir+"assets/motion/r51/actions.res").duplicate(true)
        for id in action_library.get_animation_list():
            var animation:=action_library.get_animation(id)
            for track in animation.get_track_count():
                var name:=str(animation.track_get_path(track).get_subname(0))
                animation.track_set_path(track,NodePath(str(get_path_to(skeleton))+":"+name))
        assert(player.add_animation_library("Actions51",action_library)==OK)
        for id in action_library.get_animation_list():
            clips[id]="Actions51/"+id
    if ResourceLoader.exists(base_dir + "assets/motion/r53/actions.res") and "--bake-consumption" not in OS.get_cmdline_user_args():
        var consumption_library: AnimationLibrary = load(base_dir + "assets/motion/r53/actions.res").duplicate(true)
        for id in consumption_library.get_animation_list():
            var animation = consumption_library.get_animation(id)
            for track in animation.get_track_count():
                var bone_name = str(animation.track_get_path(track).get_subname(0))
                animation.track_set_path(track, NodePath(str(get_path_to(skeleton)) + ":" + bone_name))
            clips[id] = "Consumption53/" + id
        assert(player.add_animation_library("Consumption53", consumption_library) == OK)
    if ResourceLoader.exists(base_dir + "assets/motion/r54/combat.res") and "--bake-combat" not in OS.get_cmdline_user_args():
        var combat_library: AnimationLibrary = load(base_dir + "assets/motion/r54/combat.res").duplicate(true)
        for id in combat_library.get_animation_list():
            var animation = combat_library.get_animation(id)
            for track in animation.get_track_count():
                var name = str(animation.track_get_path(track).get_subname(0))
                animation.track_set_path(track, NodePath(str(get_path_to(skeleton)) + ":" + name))
            clips[id] = "Combat54/" + id
        assert(player.add_animation_library("Combat54", combat_library) == OK)
    if ResourceLoader.exists(base_dir + "assets/motion/r55/reactions.res") and "--bake-reactions" not in OS.get_cmdline_user_args():
        var reaction_library: AnimationLibrary = load(base_dir + "assets/motion/r55/reactions.res").duplicate(true)
        for id in reaction_library.get_animation_list():
            var animation = reaction_library.get_animation(id)
            for track in animation.get_track_count():
                var name = str(animation.track_get_path(track).get_subname(0))
                animation.track_set_path(track, NodePath(str(get_path_to(skeleton)) + ":" + name))
            clips[id] = "Reactions55/" + id
        assert(player.add_animation_library("Reactions55", reaction_library) == OK)
        if FileAccess.file_exists(base_dir + "apoios_reacoes.json"):
            floor_support = JSON.parse_string(FileAccess.get_file_as_string(base_dir + "apoios_reacoes.json"))
            for item in _json("roupas.json").items:
                floor_garments[item.id] = item.type_id
    if ResourceLoader.exists(base_dir + "assets/motion/r57/obstacles.res") and "--bake-obstacles" not in OS.get_cmdline_user_args():
        var obstacle_library: AnimationLibrary = load(base_dir + "assets/motion/r57/obstacles.res").duplicate(true)
        for id in obstacle_library.get_animation_list():
            var animation = obstacle_library.get_animation(id)
            for track in animation.get_track_count():
                var name = str(animation.track_get_path(track).get_subname(0))
                animation.track_set_path(track, NodePath(str(get_path_to(skeleton)) + ":" + name))
            clips[id] = "Obstacles57/" + id
        assert(player.add_animation_library("Obstacles57", obstacle_library) == OK)
        if FileAccess.file_exists(base_dir + "apoios_obstaculos.json"):
            floor_support.merge(JSON.parse_string(FileAccess.get_file_as_string(base_dir + "apoios_obstaculos.json")), true)
    if ResourceLoader.exists(base_dir + "assets/motion/r58/states.res"):
        var state_library: AnimationLibrary = load(base_dir + "assets/motion/r58/states.res").duplicate(true)
        for id in state_library.get_animation_list():
            var animation = state_library.get_animation(id)
            for track in animation.get_track_count():
                var name = str(animation.track_get_path(track).get_subname(0))
                animation.track_set_path(track, NodePath(str(get_path_to(skeleton)) + ":" + name))
            clips[id] = "States58/" + id
        assert(player.add_animation_library("States58", state_library) == OK)
        floor_support.merge(_json("apoios_estados.json"), true)
    if ResourceLoader.exists(base_dir + "assets/motion/r59/flow.res"):
        var library: AnimationLibrary = load(base_dir + "assets/motion/r59/flow.res").duplicate(true)
        for id in library.get_animation_list():
            var animation = library.get_animation(id)
            for track in animation.get_track_count():
                animation.track_set_path(track, NodePath(str(get_path_to(skeleton))+":"+str(animation.track_get_path(track).get_subname(0))))
            clips[id] = "Flow59/"+id
        player.add_animation_library("Flow59",library)
    audio=AudioStreamPlayer.new()
    audio.stream=load(base_dir+str(clip.audio))
    add_child(audio)
    audio.finished.connect(func(): stop_speech(); speech_finished.emit())
    initialized=true
    selection=catalog["default"].duplicate(true)
    var appearance_ok:=set_appearance(selection)
    assert(appearance_ok)
    advance(0)

func _json(path: String) -> Dictionary:
    return JSON.parse_string(FileAccess.get_file_as_string(base_dir+path))

func _item(family: String,id: String) -> Dictionary:
    for item in catalog.get(family,[]):
        if item.id==id:return item
    return {}

func _color(id: String) -> Color:
    for item in catalog.colors:
        if item.id==id:return Color(item.hex)
    return Color.WHITE

func set_appearance(profile: Dictionary) -> bool:
    if not initialized:return false
    var candidate: Dictionary=(selection if not selection.is_empty() else catalog["default"]).duplicate(true)
    for key in profile:
        if not candidate.has(key):return false
        if not profile[key] is String:return false
        candidate[key]=profile[key]
    for family in ["hair","beard","mustache"]:
        if candidate[family+"_id"]!="none" and _item(family,candidate[family+"_id"]).is_empty():return false
        var valid:=false
        for color in catalog.colors:
            if color.id==candidate[family+"_color"]:valid=true
        if not valid:return false
    for key in catalog.get("options",{}):
        var valid:=false
        for item in catalog.options[key]:
            if item.id==candidate[key]:valid=true
        if not valid:return false
    if appearance_ready and candidate==selection:return true
    var changed: Dictionary={"_initial":not appearance_ready}
    for key in candidate:
        if not appearance_ready or candidate[key]!=selection.get(key):changed[key]=true
    selection=candidate
    var geometry_changed:=false
    for family in ["hair","beard","mustache","brows","outfit"]:
        if appearance_ready and not changed.has(family+"_id"):continue
        geometry_changed=true
        for child in holders[family].get_children():
            holders[family].remove_child(child)
            child.queue_free()
        var id: String=selection.get(family+"_id","none")
        if family=="brows" and id=="original":continue
        if id=="none":continue
        var item:=_item(family,id)
        if item.is_empty():continue
        var model: Node3D=load(base_dir+str(item.asset)).instantiate()
        runtime_stats.model_reloads+=1
        holders[family].add_child(model)
        if family=="outfit":_redirect_skin(model)
    if geometry_changed:_cache_meshes()
    if changed.has("outfit_id") or not appearance_ready:_apply_outfit_mask()
    _apply_colors(changed)
    _apply_weights()
    appearance_ready=true
    runtime_stats.profile_updates+=1
    appearance_changed.emit(selection.duplicate(true))
    return true

func _redirect_skin(model: Node3D) -> void:
    for mesh in _all_meshes(model):
        retarget_mesh_skin(mesh)
        mesh.reparent(holders.outfit,true)
        mesh.skeleton=mesh.get_path_to(skeleton)
    holders.outfit.remove_child(model)
    model.queue_free()

func _all_meshes(root: Node) -> Array[MeshInstance3D]:
    var result: Array[MeshInstance3D]=[]
    if root is MeshInstance3D:result.append(root)
    for child in root.get_children():result.append_array(_all_meshes(child))
    return result

func _cache_meshes() -> void:
    applied_weights.clear()
    meshes=_all_meshes(visual)
    shape_maps.clear()
    for mesh in meshes:
        var map: Dictionary={}
        for index in mesh.mesh.get_blend_shape_count():map[str(mesh.mesh.get_blend_shape_name(index))]=index
        shape_maps.append(map)

func _apply_colors(changed: Dictionary) -> void:
    var first: bool=changed.get("_initial",false)
    for family in ["hair","beard","mustache"]:
        if not first and not changed.has(family+"_id") and not changed.has(family+"_color"):continue
        var material:=StandardMaterial3D.new()
        material.albedo_color=_color(selection[family+"_color"])
        material.roughness=.95
        material.cull_mode=BaseMaterial3D.CULL_DISABLED
        for mesh in _all_meshes(holders[family]):mesh.material_override=material
    for mesh in meshes:
        var name_text:=str(mesh.name)
        var tint_brows: bool=first or changed.has("brows_id") or changed.has("hair_color")
        if name_text.begins_with("R26_Sobrancelha") and tint_brows:
            mesh.visible=selection.get("brows_id","original")=="original"
            var mat:=StandardMaterial3D.new()
            mat.albedo_color=_color(selection.hair_color)
            mat.roughness=.95
            mesh.material_override=mat
        elif name_text.begins_with("EA_Sobrancelha") and tint_brows:
            var mat:=StandardMaterial3D.new()
            mat.albedo_color=_color(selection.hair_color)
            mat.roughness=.95
            mesh.material_override=mat
        if name_text.begins_with("R26_Iris") and catalog.has("options") and (first or changed.has("iris_id")):
            for item in catalog.options.get("iris_id",[]):
                if item.id==selection.get("iris_id",""):
                    if item.id=="original":
                        mesh.material_override=null
                        continue
                    var mat:=StandardMaterial3D.new()
                    mat.albedo_color=Color(item.hex)
                    mat.roughness=.95
                    mesh.material_override=mat
        if "CABECA_E_CORPO" in name_text and catalog.has("options") and (first or changed.has("skin_id") or changed.has("outfit_id")):
            for surface in mesh.mesh.get_surface_count():
                var original:=mesh.mesh.surface_get_material(surface)
                if not original is StandardMaterial3D:continue
                var id:=str(original.resource_name)
                if id.begins_with("R22_Interior") or "Cavidade" in id:continue
                var mat: StandardMaterial3D=original.duplicate(true)
                for item in catalog.options.get("skin_id",[]):
                    if item.id==selection.get("skin_id",""):
                        var tint:=Color(item.hex)
                        mat.albedo_color=Color(original.albedo_color.r*tint.r,original.albedo_color.g*tint.g,original.albedo_color.b*tint.b,1)
                mesh.set_surface_override_material(surface,mat)
    if first or changed.has("outfit_id") or changed.has("cloth_palette_id"):
        for mesh in _all_meshes(holders.outfit):
            var part: String="shirt" if "Camisa" in str(mesh.name) else "pants" if "Calca" in str(mesh.name) else "belt" if "Cinto" in str(mesh.name) else "boots"
            for surface in mesh.mesh.get_surface_count():
                mesh.set_surface_override_material(surface,null)
                for palette in catalog.options.get("cloth_palette_id",[]):
                    if palette.id!=selection.get("cloth_palette_id","original") or palette.id=="original":continue
                    var original:=mesh.mesh.surface_get_material(surface)
                    if "Fivela" in str(original.resource_name):continue
                    var mat: StandardMaterial3D=original.duplicate(true)
                    mat.albedo_color=Color(palette.parts[part])
                    if "Acabamento" in str(original.resource_name):mat.albedo_color=mat.albedo_color.darkened(.20)
                    mesh.set_surface_override_material(surface,mat)

func _apply_outfit_mask() -> void:
    for instance in _all_meshes(body):
        if not "CABECA_E_CORPO" in str(instance.name):continue
        if original_body_mesh==null:original_body_mesh=instance.mesh
        if selection.get("outfit_id","none")=="none":
            instance.mesh=original_body_mesh
            break
        if clothed_body_mesh==null:
            var donor: Node3D=load(base_dir+str(catalog.clothed_body)).instantiate()
            for mesh in _all_meshes(donor):
                if "CABECA_E_CORPO" in str(mesh.name):clothed_body_mesh=mesh.mesh
            donor.free()
        instance.mesh=clothed_body_mesh
    _cache_meshes()

func appearance_report() -> Dictionary:
    return {"schema":"ea.character.appearance.v1","base":"equilibrado_nariz_baixo_4mm","selection":selection.duplicate(true)}

func load_report(report: Variant) -> bool:
    if not report is Dictionary or report.get("schema","")!="ea.character.appearance.v1" or report.get("base","")!="equilibrado_nariz_baixo_4mm":return false
    if not report.get("selection") is Dictionary:return false
    var migrated: Dictionary=catalog["default"].duplicate(true)
    migrated.merge(report.selection,true)
    return set_appearance(migrated)

func save_appearance(path: String) -> Error:
    var file:=FileAccess.open(path,FileAccess.WRITE)
    if file==null:return FileAccess.get_open_error()
    file.store_string(JSON.stringify(appearance_report(),"  "))
    return OK

func set_expression(id: String,strength: float=1.0,duration: float=.22) -> bool:
    if not initialized or not is_finite(strength) or not is_finite(duration):return false
    if id!="" and not expressions.has(id):return false
    emotion_from=emotion_weights.duplicate(true)
    emotion_to={} if id=="" else {id:clampf(strength,0,1)}
    transition_duration=maxf(0,duration) if catalog.get("facial_life",false) else 0
    transition_time=0
    if transition_duration<=0:emotion_weights=emotion_to.duplicate(true)
    _apply_weights()
    return true

func set_pose(id: String,strength: float=1.0) -> bool:
    if not initialized or not is_finite(strength):return false
    var target: Dictionary={}
    for pose in poses.poses:
        if pose.id==id:target=pose.weights
    if target.is_empty():return false
    speech_weights={}
    for control in poses.controls:speech_weights[control]=float(target.get(control,0))*clampf(strength,0,1)
    speech_weights.Selar_Labios=float(speech_weights.get("Selar_Labios",0))+1-clampf(strength,0,1)
    _apply_weights()
    return true

func set_motion(id: String) -> bool:
    if not initialized or not clips.has(id) or not player.has_animation(clips[id]):return false
    if motion==id:return true
    # A troca interrompida parte da pose visível, sem voltar a um clipe antigo.
    motion_source=motion if motion_blend>=1 else ""
    motion_source_clock=motion_clock
    motion_from=base_motion_pose.duplicate()
    if motion_from.is_empty():
        for bone in skeleton.get_bone_count():motion_from.append(skeleton.get_bone_pose(bone))
    motion_transition_duration=_motion_duration(motion,id)
    motion_blend=0
    var phase:=fposmod(motion_clock,player.get_animation(clips[motion]).length)/player.get_animation(clips[motion]).length
    motion_clock=phase*player.get_animation(clips[id]).length if motion in ["walk","run","crouch","backward","left","right","combat_forward","combat_back","combat_left","combat_right","combat_forward_armed","combat_back_armed","combat_left_armed","combat_right_armed"] and id in ["walk","run","crouch","backward","left","right","combat_forward","combat_back","combat_left","combat_right","combat_forward_armed","combat_back_armed","combat_left_armed","combat_right_armed"] else 0.0
    motion=id
    return true

func _motion_duration(source: String,target: String) -> float:
    var source_low:=source in ["crouch","crouch_idle"]
    var target_low:=target in ["crouch","crouch_idle"]
    if source_low!=target_low:return .34 if target_low else .38
    if target=="idle":return .26
    if source=="idle":return .24
    return .20

func _sample_motion(id: String,seconds: float) -> void:
    var root_index = skeleton.find_bone("Root")
    skeleton.set_bone_pose(root_index, skeleton.get_bone_rest(root_index))
    if hand_layer!=null:hand_layer.apply()
    var animation_id: String=clips[id]
    if player.current_animation!=animation_id:player.play(animation_id)
    var length:=player.get_animation(animation_id).length
    player.seek(clampf(seconds,0,length) if id in ["turn_left","turn_right","inventory_access","equip_item","store_item","eat","drink","medicine","bandage","push","push_armed","punch","strike_onehand","hit_front","hit_back","hit_left","hit_right","stagger","hit_front_armed","hit_back_armed","hit_left_armed","hit_right_armed","stagger_armed","fall","get_up","death","vault_fence","vault_window","open_window"] or id.begins_with("flow_") else fposmod(seconds,length),true)
    var root_position = skeleton.get_bone_pose_position(root_index)
    root_position.y += _floor_offset(id, seconds)
    skeleton.set_bone_pose_position(root_index, root_position)

func _floor_offset(id: String, seconds: float) -> float:
    if not floor_support.has(id):
        return 0
    if id in ["injured_idle", "limp_left", "limp_right", "tired_idle", "tired_walk", "tired_run"]:
        seconds = fposmod(seconds, player.get_animation(clips[id]).length)
    var rows: Array = floor_support[id]
    var garment: String = floor_garments.get(selection.get("shirt_id", "none"), "none")
    var key = garment + ("_bare" if selection.get("boots_id", "none") == "none" else "_boots")
    var frame = clampf(seconds * 60, 0, rows.size() - 1)
    if id in ["injured_idle", "limp_left", "limp_right", "tired_idle", "tired_walk", "tired_run"]:
        frame = seconds / player.get_animation(clips[id]).length * (rows.size()-1)
    var index = floori(frame)
    var next = mini(index + 1, rows.size() - 1)
    return lerpf(rows[index].offsets[key], rows[next].offsets[key], frame - index)

func _advance_motion(delta: float) -> void:
    var step:=0.0 if motion_paused else delta
    motion_clock+=step*motion_rate
    if motion_blend<1:
        motion_source_clock+=step
        motion_blend=minf(1,motion_blend+step/motion_transition_duration)
    var source_pose: Array[Transform3D]=motion_from
    if motion_blend<1 and not motion_source.is_empty():
        # Os dois ciclos continuam vivos e usam a mesma mistura que o tecido.
        _sample_motion(motion_source,motion_source_clock)
        source_pose=[]
        for bone in skeleton.get_bone_count():source_pose.append(skeleton.get_bone_pose(bone))
    var source_joints: Dictionary = {}
    if motion_blend < 1:
        if motion_source.is_empty():
            for bone in source_pose.size():
                skeleton.set_bone_pose(bone, source_pose[bone])
        source_joints = arm_blend.capture()
    _sample_motion(motion,motion_clock)
    var target_joints: Dictionary = arm_blend.capture() if motion_blend < 1 else {}
    if motion_blend<1:
        var u:=smoothstep(0,1,motion_blend)
        for bone in skeleton.get_bone_count():skeleton.set_bone_pose(bone,source_pose[bone].interpolate_with(skeleton.get_bone_pose(bone),u))
        arm_blend.correct(source_joints, target_joints, u)
    else:motion_source=""

func _weights_at(seconds: float) -> Dictionary:
    var knots: Array=clip.knots
    if seconds<=float(knots[0].time):return knots[0].weights.duplicate(true)
    if seconds>=float(knots[-1].time):return knots[-1].weights.duplicate(true)
    var left:=0
    var right:=knots.size()-1
    while right-left>1:
        var middle:=int((left+right)/2)
        if float(knots[middle].time)<=seconds:left=middle
        else:right=middle
    var u: float=smoothstep(float(knots[left].time),float(knots[right].time),seconds)
    var result: Dictionary={}
    for control in poses.controls:result[control]=lerpf(float(knots[left].weights.get(control,0)),float(knots[right].weights.get(control,0)),u)
    return result

func seek_speech(seconds: float) -> void:
    if not is_finite(seconds):return
    speech_time=clampf(seconds,0,float(clip.duration))
    speech_last_time=speech_time
    if speech_active:audio.seek(speech_time)
    speech_weights=_weights_at(speech_time)
    _apply_weights()

func play_speech() -> void:
    audio.stream_paused=false
    speech_active=true
    speech_paused=false
    speech_last_time=speech_time
    audio.play(speech_time)

func pause_speech(paused: bool) -> void:
    speech_paused=paused
    audio.stream_paused=paused

func stop_speech() -> void:
    audio.stream_paused=false
    audio.stop()
    speech_active=false
    speech_time=0
    speech_last_time=0
    set_pose("neutro")

func _process(delta: float) -> void:
    if initialized and not manual_update:advance(delta)

func advance(delta: float) -> void:
    if not is_finite(delta) or delta<0:return
    clock+=delta
    if transition_duration>0 and transition_time<transition_duration:
        transition_time+=delta
        var u:=smoothstep(0,transition_duration,transition_time)
        emotion_weights={}
        for id in expressions:emotion_weights[id]=lerpf(float(emotion_from.get(id,0)),float(emotion_to.get(id,0)),u)
    if life_enabled and catalog.get("facial_life",false):
        if not life_was_enabled:reset_life()
        _update_life(delta)
    life_was_enabled=life_enabled
    if speech_active:
        if not speech_paused:
            var seconds:=audio.get_playback_position()+AudioServer.get_time_since_last_mix()-AudioServer.get_output_latency()
            speech_time=clampf(maxf(speech_last_time,seconds),0,float(clip.duration))
            speech_last_time=speech_time
        speech_weights=_weights_at(speech_time)
    _advance_motion(delta)
    if hand_layer!=null:hand_layer.advance(0.0 if motion_paused else delta)
    base_motion_pose.clear()
    for bone in skeleton.get_bone_count():base_motion_pose.append(skeleton.get_bone_pose(bone))
    for entry in [["Neck",.65],["Head",.35]]:
        var bone:=skeleton.find_bone(entry[0])
        var axis:=skeleton.get_bone_global_rest(bone).basis.inverse()*Vector3.UP
        skeleton.set_bone_pose_rotation(bone,skeleton.get_bone_pose_rotation(bone)*Quaternion(axis.normalized(),deg_to_rad(head_yaw*entry[1])))
    skeleton.force_update_all_bone_transforms()
    _apply_weights()

func reset_life(seed_value: int=0) -> void:
    if seed_value!=0:life_seed=seed_value
    life_rng.seed=life_seed if life_seed!=0 else int(get_instance_id()*7919)
    life_blink_clock=0
    life_blink_delay=life_rng.randf_range(2.8,4.8)
    life_gaze_clock=0
    life_gaze_hold=life_rng.randf_range(1.5,2.5)
    life_gaze_from=gaze
    life_gaze_target=gaze
    blink=0

func _update_life(delta: float) -> void:
    life_blink_clock+=delta
    var phase:=life_blink_clock-life_blink_delay
    blink=0 if phase<0 else smoothstep(0,.075,phase)*(1-smoothstep(.115,.23,phase))
    if phase>=.23:
        life_blink_clock=0
        life_blink_delay=life_rng.randf_range(2.8,5.2)
        blink=0
    life_gaze_clock+=delta
    if life_gaze_clock>=life_gaze_hold+.09:
        life_gaze_from=gaze
        life_gaze_target=Vector2(life_rng.randf_range(-.28,.28),life_rng.randf_range(-.10,.10))
        life_gaze_clock=0
        life_gaze_hold=life_rng.randf_range(1.6,3.4)
    gaze=life_gaze_from.lerp(life_gaze_target,smoothstep(0,.09,life_gaze_clock))

func _apply_weights() -> void:
    if not initialized:return
    var total:=0.0
    var emotional_blink:=0.0
    for id in emotion_weights:
        total+=float(emotion_weights[id])
        emotional_blink+=float(emotion_weights[id])*float(expressions[id].blink)
    weights={}
    for control in poses.controls:
        var amount:=float(speech_weights.get(control,0))
        weights[control]=amount*(1-total)
        for id in emotion_weights:weights[combinations[id][control]]=amount*float(emotion_weights[id])
    weights.Piscar=(1-emotional_blink)*clampf(blink,0,1)
    weights.Olhar_X_Positivo=maxf(gaze.x,0)
    weights.Olhar_X_Negativo=maxf(-gaze.x,0)
    weights.Olhar_Alto=maxf(gaze.y,0)
    weights.Olhar_Baixo=maxf(-gaze.y,0)
    var next_applied: Dictionary={}
    for i in meshes.size():
        for id in shape_maps[i]:
            var value:=float(weights.get(id,0))
            if not applied_weights.has(id) or not is_equal_approx(float(applied_weights[id]),value):meshes[i].set_blend_shape_value(shape_maps[i][id],value)
            next_applied[id]=value
    applied_weights=next_applied

func _exit_tree() -> void:
    if is_instance_valid(audio):
        audio.stream_paused=false
        audio.stop()
        audio.stream=null

func head_transform() -> Transform3D:
    var bone:=skeleton.find_bone("Head")
    return skeleton.global_transform*skeleton.get_bone_global_pose(bone)*skeleton.get_bone_global_rest(bone).affine_inverse()

# Ajuste local da biblioteca clonada. Os GLBs e as bibliotecas de origem ficam intactos.
func _lower_run_arms(library: AnimationLibrary) -> void:
    var run:=library.get_animation("EA_Run_Forward_Candidate_R08")
    var idle:=library.get_animation("EA_Idle_Candidate_R04")
    for track in run.get_track_count():
        if run.track_get_type(track)!=Animation.TYPE_ROTATION_3D:continue
        var path:=run.track_get_path(track)
        var bone:=str(path.get_subname(0))
        var factor:=1.0
        if bone.begins_with("Clavicle."):factor=.85
        elif bone.begins_with("UpperArm."):factor=.65
        elif bone.begins_with("Forearm."):factor=.62
        elif bone.begins_with("Hand."):factor=.75
        else:continue
        var reference_track:=idle.find_track(path,Animation.TYPE_ROTATION_3D)
        if reference_track<0:continue
        var reference: Quaternion=idle.rotation_track_interpolate(reference_track,0)
        for key in run.track_get_key_count(track):
            var original: Quaternion=run.track_get_key_value(track,key)
            run.track_set_key_value(track,key,reference.slerp(original,factor))

func retarget_mesh_skin(mesh: MeshInstance3D) -> void:
    if mesh.skin==null:
        return
    var source_skeleton: Skeleton3D=mesh.get_node_or_null(mesh.skeleton) as Skeleton3D
    var corrected:=Skin.new()
    for index in range(mesh.skin.get_bind_count()):
        var name: String=mesh.skin.get_bind_name(index)
        if name.is_empty():
            assert(source_skeleton!=null)
            name=source_skeleton.get_bone_name(mesh.skin.get_bind_bone(index))
        assert(skeleton.find_bone(name)>=0)
        corrected.add_named_bind(name,mesh.skin.get_bind_pose(index))
    mesh.skin=corrected
