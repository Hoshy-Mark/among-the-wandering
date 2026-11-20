extends "personagem_base.gd"
const CLOTHING_SLOTS: Array[String]=["shirt","pants","boots","belt"]
var firearm_presentation: Node3D
var shoulder_pitch=0.0
var shoulder_pose_service: Node3D
var state_motion: RefCounted
var obstacle_path: RefCounted
var arm_articulation: RefCounted
var clothing: Dictionary={}
var segmented_body: ArrayMesh
var body_masks: Dictionary={}
var fit_from: Dictionary={}
var fit_enabled:=true

func set_motion(id: String) -> bool:
    var visible_pose: Array[Transform3D]=[]
    if shoulder_pose_service!=null and motion in ["firearm_idle","firearm_shot","firearm_reload90"] and id not in ["firearm_idle","firearm_shot","firearm_reload90"] and id!=motion:
        for bone in skeleton.get_bone_count():visible_pose.append(skeleton.get_bone_pose(bone))
    if motion!=id and clips.has(id):
        fit_from={}
        for key in weights:
            if str(key).begins_with("Fit_") and float(weights[key])>0:fit_from[key]=weights[key]
    var accepted=super.set_motion(id)
    if accepted and not visible_pose.is_empty():
        motion_source="";motion_from=visible_pose;base_motion_pose=visible_pose.duplicate()
    return accepted

func _apply_weights() -> void:
    super._apply_weights()
    if not initialized or player==null or not player.has_animation(clips[motion]):return
    var desired:=_fit_at(motion,motion_clock)
    if motion_blend<1:
        var blend:=smoothstep(0,1,motion_blend)
        var outgoing: Dictionary=fit_from if motion_source.is_empty() else _fit_at(motion_source,motion_source_clock)
        for key in desired:desired[key]*=blend
        for key in outgoing:desired[key]=float(desired.get(key,0))+float(outgoing[key])*(1-blend)
    if not fit_enabled:desired.clear()
    for i in meshes.size():
        for key in shape_maps[i]:
            if not str(key).begins_with("Fit_"):continue
            var value:=float(desired.get(key,0))
            meshes[i].set_blend_shape_value(shape_maps[i][key],value)
            weights[key]=value;applied_weights[key]=value

func _fit_at(id: String,seconds: float) -> Dictionary:
    if id.begins_with("flow_"):
        return {"Fit_crouch_idle_00":1.0} if "crouch" in id else {"Fit_idle_00":1.0}

    if state_motion != null and state_motion.definitions.has(id):
        var source: String = state_motion.definitions[id].source
        var length: float = player.get_animation(clips[source]).length
        return _fit_at(source, state_motion.source_time(id, seconds, length))
    if id in ["vault_fence", "vault_window", "open_window"]:
        var squat: float = obstacle_path.sample(id, seconds).crouch
        return {"Fit_idle_00": 1 - squat, "Fit_crouch_idle_00": squat}
    if id in ["fall", "down", "get_up", "death"]:
        var squat = 0.0
        if id in ["fall", "death"]:
            squat = smoothstep(.08, .48, seconds) * (1 - smoothstep(.58, 1.30, seconds)) * .85
        elif id == "get_up":
            squat = smoothstep(.10, .70, seconds) * (1 - smoothstep(1.35, 2.45, seconds))
        return {"Fit_idle_00": 1 - squat, "Fit_crouch_idle_00": squat}
    if id.begins_with("hit_"):
        return {"Fit_idle_00": 1.0}
    if id.begins_with("stagger"):
        return _fit_at("backward", seconds / 1.35 * player.get_animation(clips.backward).length)
    if id in ["firearm_idle","firearm_shot","firearm_reload90"]:return {"Fit_idle_00":1.0}
    if id in ["push", "push_armed", "punch", "strike_onehand", "combat_idle", "combat_idle_armed"]:
        return {"Fit_idle_00": 1.0}
    if id in ["inventory_access","equip_item","store_item","eat","drink","medicine","bandage"]:return {"Fit_idle_00":1.0}
    var length: float=player.get_animation(clips[id]).length
    if id.begins_with("combat_"):
        id = "walk"
    var key_id: String="walk" if id in ["backward","left","right"] else id
    var one_shot:=id in ["turn_left","turn_right"]
    var phase: float=clampf(seconds/length,0,1)*11 if one_shot else fposmod(seconds,length)/length*12
    var index:=mini(floori(phase),11)
    var amount: float=phase-floor(phase)
    var next:=mini(index+1,11) if one_shot else (index+1)%12
    var result: Dictionary={"Fit_%s_%02d"%[key_id,index]:1-amount}
    var next_key: String="Fit_%s_%02d"%[key_id,next]
    result[next_key]=float(result.get(next_key,0))+amount
    return result

func _ready() -> void:
    base_dir=get_script().resource_path.get_base_dir()+"/"
    obstacle_path = load(base_dir + "percurso_obstaculos.gd").new()
    obstacle_path.setup(_json("obstaculos.json"))
    state_motion = load(base_dir + "estados_movimento.gd").new()
    state_motion.setup(_json("estados_movimento.json"))
    clothing=_json("roupas.json")
    for item in clothing.items:
        var type: Dictionary=clothing.types[item.type_id]
        item.merge({"slot":type.slot,"asset":type.asset,"coverage":type.coverage},true)
    runtime_stats["material_updates"]=0
    super._ready()
    arm_articulation = load(base_dir + "articulacao_bracos.gd").new()
    arm_articulation.setup(self)
    arm_articulation.apply()

func clothing_item(id: String) -> Dictionary:
    for item in clothing.items:
        if item.id==id:return item
    return {}

func _item(family: String,id: String) -> Dictionary:
    if family in CLOTHING_SLOTS:
        var item:=clothing_item(id)
        return item if item.get("slot","")==family else {}
    return super._item(family,id)

func set_appearance(profile: Dictionary) -> bool:
    if not initialized:return false
    var candidate: Dictionary=(selection if not selection.is_empty() else catalog["default"]).duplicate(true)
    for key in profile:
        if not candidate.has(key) or not profile[key] is String:return false
        candidate[key]=profile[key]
    for family in ["hair","beard","mustache"]:
        if candidate[family+"_id"]!="none" and _item(family,candidate[family+"_id"]).is_empty():return false
        var valid:=false
        for color in catalog.colors:
            if color.id==candidate[family+"_color"]:valid=true
        if not valid:return false
    for key in catalog.options:
        var valid:=false
        for item in catalog.options[key]:
            if item.id==candidate[key]:valid=true
        if not valid:return false
    if appearance_ready and candidate==selection:return true
    var changed: Dictionary={"_initial":not appearance_ready}
    for key in candidate:
        if not appearance_ready or candidate[key]!=selection.get(key):changed[key]=true
    # All IDs were checked before mutating the visible character.
    var previous: Dictionary=selection.duplicate(true)
    selection=candidate
    for slot in CLOTHING_SLOTS:
        if holders.has(slot):continue
        var holder:=Node3D.new();holder.name=slot;visual.add_child(holder);holders[slot]=holder
    var geometry_changed:=false
    var clothing_changed:=false
    for family in ["hair","beard","mustache","brows","shirt","pants","boots","belt"]:
        if appearance_ready and not changed.has(family+"_id"):continue
        if family in CLOTHING_SLOTS and appearance_ready and holders[family].get_child_count()>0:
            var old_item:=clothing_item(previous.get(family+"_id","none"))
            var new_item:=clothing_item(selection[family+"_id"])
            if not old_item.is_empty() and not new_item.is_empty() and old_item.type_id==new_item.type_id:
                _apply_item_material(family,new_item)
                continue
        geometry_changed=true
        if family in CLOTHING_SLOTS:clothing_changed=true
        for child in holders[family].get_children():
            holders[family].remove_child(child);child.queue_free()
        var id: String=selection.get(family+"_id","none")
        if (family=="brows" and id=="original") or id=="none":continue
        var item:=_item(family,id)
        if item.is_empty():continue
        var model: Node3D=load(base_dir+str(item.asset)).instantiate()
        runtime_stats.model_reloads+=1
        holders[family].add_child(model)
        if family in CLOTHING_SLOTS:
            for mesh in _all_meshes(model):
                retarget_mesh_skin(mesh)
                mesh.reparent(holders[family],true)
                mesh.skeleton=mesh.get_path_to(skeleton)
            holders[family].remove_child(model);model.queue_free()
            _apply_item_material(family,item)
    if geometry_changed:_cache_meshes()
    if clothing_changed or not appearance_ready:
        _apply_outfit_mask()
        changed["outfit_id"]=true # Refresh the skin tint after changing its mesh.
    _apply_colors(changed)
    _apply_weights()
    appearance_ready=true;runtime_stats.profile_updates+=1
    appearance_changed.emit(selection.duplicate(true))
    return true

func _apply_item_material(slot: String,item: Dictionary) -> void:
    for mesh in _all_meshes(holders[slot]):
        for surface in mesh.mesh.get_surface_count():
            var source:=mesh.mesh.surface_get_material(surface)
            var name_text:=str(source.resource_name) if source!=null else ""
            if "Fivela" in name_text or "Botao" in str(mesh.name) or name_text=="Detalhe":continue
            var material: ShaderMaterial=mesh.get_surface_override_material(surface) as ShaderMaterial
            if material==null:
                material=ShaderMaterial.new();material.shader=load(base_dir+"tecido.gdshader");mesh.set_surface_override_material(surface,material)
            var color:=Color(str(item.appearance.color))
            if "Acabamento" in name_text or "Vista" in str(mesh.name):color=color.darkened(.20)
            material.set_shader_parameter("tint",color)
            material.set_shader_parameter("plaid",item.appearance.get("pattern","solid")=="plaid")
            var texture_path: String=item.appearance.get("texture","")
            material.set_shader_parameter("use_texture",not texture_path.is_empty())
            material.set_shader_parameter("fabric_texture",null if texture_path.is_empty() else load(base_dir+texture_path))
    runtime_stats.material_updates+=1

func coverage_flags() -> int:
    var flags:=0
    for slot in CLOTHING_SLOTS:
        flags|=int(clothing_item(selection.get(slot+"_id","none")).get("coverage",0))
    return flags

func _apply_outfit_mask() -> void:
    for instance in _all_meshes(body):
        if not "CABECA_E_CORPO" in str(instance.name):continue
        if original_body_mesh==null:original_body_mesh=instance.mesh
        var flags:=coverage_flags()
        instance.mesh=original_body_mesh if flags==0 else _body_mask(flags)
    _cache_meshes()

func _triangle_coverage(center: Vector3) -> int:
    var result:=0
    if center.y<1.455-0.000001 and center.y>.923+0.000001 and absf(center.x)<.401-0.000001:result|=1
    if center.y<.928-0.000001 and center.y>.153+0.000001:result|=2
    if center.y<.212-0.000001:result|=4
    if center.y<1.51 and absf(center.x)>.401+0.000001 and absf(center.x)<.697-0.000001:result|=8
    if center.y>.900+0.000001 and center.y<.923-0.000001 and absf(center.x)<.30:result|=16
    return result

func _body_mask(flags: int) -> ArrayMesh:
    if body_masks.has(flags):return body_masks[flags]
    var path:=base_dir+"assets/clothing/masks_r53/corpo_%d.res"%flags
    if ResourceLoader.exists(path):
        body_masks[flags]=load(path)
        return body_masks[flags]
    if segmented_body==null:
        var donor: Node3D=load(base_dir+str(clothing.body_mask_source)).instantiate()
        for mesh in _all_meshes(donor):
            if "CABECA_E_CORPO" in str(mesh.name):segmented_body=mesh.mesh
        donor.free()
    var result:=ArrayMesh.new()
    result.blend_shape_mode=segmented_body.blend_shape_mode
    for i in segmented_body.get_blend_shape_count():result.add_blend_shape(segmented_body.get_blend_shape_name(i))
    for surface in segmented_body.get_surface_count():
        var arrays:=segmented_body.surface_get_arrays(surface)
        var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        if indices.is_empty():
            for i in positions.size():indices.append(i)
        var kept:=PackedInt32Array()
        for triangle in range(0,indices.size(),3):
            var center: Vector3=(positions[indices[triangle]]+positions[indices[triangle+1]]+positions[indices[triangle+2]])/3
            if (_triangle_coverage(center)&flags)!=0:continue
            kept.append_array(indices.slice(triangle,triangle+3))
        if kept.is_empty():continue
        arrays[Mesh.ARRAY_INDEX]=kept
        result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,segmented_body.surface_get_blend_shape_arrays(surface))
        result.surface_set_material(result.get_surface_count()-1,segmented_body.surface_get_material(surface))
    body_masks[flags]=result
    return result

func appearance_report() -> Dictionary:
    return {"schema":"ea.character.appearance.v2","base":"equilibrado_nariz_baixo_4mm","selection":selection.duplicate(true)}

func load_report(report: Variant) -> bool:
    if not report is Dictionary or report.get("base","")!="equilibrado_nariz_baixo_4mm" or not report.get("selection") is Dictionary:return false
    if report.get("schema","") not in ["ea.character.appearance.v1","ea.character.appearance.v2"]:return false
    var incoming: Dictionary=report.selection.duplicate(true)
    if report.schema=="ea.character.appearance.v1":
        var outfit: Variant=incoming.get("outfit_id","viajante")
        var palette: Variant=incoming.get("cloth_palette_id","original")
        if outfit not in ["none","viajante"] or palette not in ["original","azul","terra"]:return false
        incoming.erase("outfit_id");incoming.erase("cloth_palette_id")
        incoming.merge({"shirt_id":"camiseta_azul" if palette=="azul" else "camiseta_oliva","pants_id":"calca_carvao" if palette=="terra" else "calca_terra","boots_id":"botas_escuras","belt_id":"cinto_couro"},true)
        if outfit=="none":
            for slot in CLOTHING_SLOTS:incoming[slot+"_id"]="none"
    var migrated: Dictionary=catalog["default"].duplicate(true);migrated.merge(incoming,true)
    return set_appearance(migrated)

func _json(path: String) -> Dictionary:
    var data:=super._json(path)
    if path=="catalogo.json" and "--export-poses" in OS.get_cmdline_user_args():
        for slot in CLOTHING_SLOTS:data["default"][slot+"_id"]="none"
    return data

func advance(delta: float) -> void:
    super.advance(delta)
    if absf(shoulder_pitch)>.00001 and motion in ["firearm_idle","firearm_shot"]:
        for side in ["R","L"]:
            var index=skeleton.find_bone("UpperArm."+side)
            var parent=skeleton.get_bone_parent(index)
            var world_axis=global_basis.x.normalized()
            var local_axis=(skeleton.global_basis*skeleton.get_bone_global_pose(parent).basis).inverse()*world_axis
            skeleton.set_bone_pose_rotation(index,Quaternion(local_axis.normalized(),-shoulder_pitch)*skeleton.get_bone_pose_rotation(index))
            skeleton.force_update_all_bone_transforms()
    if shoulder_pose_service!=null and motion in ["firearm_idle","firearm_shot"]:
        shoulder_pose_service.align_pose(self)
    if firearm_presentation!=null:firearm_presentation.apply(delta)
    if arm_articulation != null:
        arm_articulation.apply()
