extends Node3D
var scene: Node3D
var working=false
var restoring_ui=false
var reason=""
var closed_contacts={}
var geometry=load("res://personagem/geometria81.gd")
func setup(root_scene: Node3D) -> void:
    scene=root_scene
    scene.player.session_save=self
    var states=_world_snapshot()
    var parts=_parts(scene.player.map_doors.snapshot(),states)
    for part in parts:
        if not part.open:closed_contacts[part.id]=_hits(part,parts)
func _signature() -> String:
    var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://fontes.json"))
    return str(manifest.files.get("staging/e06_world/arroio/assets/current_h01_h20_rev01/H01.gltf",""))+FileAccess.get_sha256("res://personagem/cercamentos78.json")+FileAccess.get_sha256("res://personagem/h01_rule67.json")
func _idle() -> bool:
    var p=scene.player
    var ui=scene.game_ui
    if p.map_combat!=null and not p.map_combat.pending_reaction.is_empty():return false
    if working or restoring_ui or p.traversal.is_active() or p.reaction.is_active() or p.combat.guarding or p.combat.is_attacking() or not p.flow.queue.is_empty() or p.action.state!="idle" or p.inventory_actions.busy() or p.map_doors.busy() or not scene.world_items.pending_id.is_empty() or not ui.pending_mode.is_empty() or not ui.drag_uid.is_empty():return false
    var house=scene.world_items.house
    for group in house.groups:
        var data: Dictionary=house.groups[group]
        var fractions=[]
        if data.has("drawers"):
            for part in data.drawers.values():fractions.append(part.fraction)
        else:
            for part in data.parts:fractions.append(part.fraction)
        if fractions.is_empty():
            for id in house.bindings:
                if house.bindings[id]==group:fractions.append(float(scene.world_items.progress.get(id,0)))
        for f in fractions:
            if f>.0001 and f<.9999:return false
    return true
func _world_snapshot() -> Dictionary:
    var world=scene.world_items
    var house=world.house
    var states={}
    for id in house.bindings:
        var data: Dictionary=house.groups[house.bindings[id]]
        var f=float(world.progress.get(id,0))
        if data.has("drawers"):f=data.drawers[id].fraction
        elif not data.parts.is_empty():f=data.parts[0].fraction
        states[id]=f>.999
    return {"states":states,"opened":scene.player.bag_inventory.opened.duplicate(),"active":world.active_id,"chosen":world.chosen_drawer.duplicate(true)}
func snapshot() -> Dictionary:
    var p=scene.player
    var result=p._profile_data()
    result.session81={"version":1,"world":_signature(),"position":[p.global_position.x,p.global_position.y,p.global_position.z],"yaw":wrapf(p.avatar.rotation.y,-PI,PI),"crouched":p.crouched,"zoom":scene.zoom,"furniture":_world_snapshot()}
    return result
func _add(parts: Array,id: String,owner_id: String,shape_node: CollisionShape3D,pose: Transform3D,body: CollisionObject3D,own_fixed: RID,opened: bool,pivot: Node3D=null,local_pose: Transform3D=Transform3D.IDENTITY,part: Dictionary={}) -> void:
    parts.append({"id":id,"owner":owner_id,"shape":shape_node.shape,"pose":pose,"rid":body.get_rid() if body!=null and not shape_node.disabled else RID(),"fixed":own_fixed,"open":opened,"pivot":pivot,"local_pose":local_pose,"part":part})
func _parts(doors: Dictionary,furniture: Dictionary) -> Array:
    var result=[]
    var controller=scene.player.map_doors
    for id in controller.doors:
        var data: Dictionary=controller.doors[id]
        var f=1.0 if doors.states[id] else 0.0
        if data.has("parts"):
            var n=0
            for part in data.parts:
                var pose: Transform3D=part.hinge.get_parent().global_transform*controller._part_pose(part,f)*part.body.transform*part.collider.transform
                _add(result,id+"/%d"%n,id,part.collider,pose,part.body,RID(),f>0)
                n+=1
        else:
            var pose: Transform3D=data.hinge.get_parent().global_transform*controller._pose(data,f)*data.body.transform*data.collider.transform
            _add(result,id,id,data.collider,pose,data.body,RID(),f>0)
    var house=scene.world_items.house
    for group in house.groups:
        var data: Dictionary=house.groups[group]
        if data.has("drawers"):
            for id in data.drawers:
                var part: Dictionary=data.drawers[id]
                var f=1.0 if furniture.states[id] else 0.0
                var local_pose: Transform3D=house._drawer_pose(part,f)
                var relative: Transform3D=part.pivot.global_transform.affine_inverse()*part.drawer_collision.global_transform
                _add(result,id,group,part.drawer_collision,part.pivot.get_parent().global_transform*local_pose*relative,part.drawer_solid,data.body.get_rid(),f>0,part.pivot,local_pose,part)
        else:
            var flag=false
            for id in house.bindings:
                if house.bindings[id]==group:flag=furniture.states[id];break
            for part in data.parts:
                var local_pose: Transform3D=part.closed_transform*Transform3D(Basis(part.axis,deg_to_rad(90)*part.sign*(1.0 if flag else 0.0)),Vector3.ZERO)
                var relative: Transform3D=part.pivot.global_transform.affine_inverse()*part.proxy.global_transform
                var parent=part.proxy.get_parent()
                _add(result,str(part.definition.id),group,part.proxy,part.pivot.get_parent().global_transform*local_pose*relative,parent if parent is CollisionObject3D else null,data.body.get_rid(),flag,part.pivot,local_pose,part)
    return result
func _excluded(parts: Array) -> Array[RID]:
    var result: Array[RID]=[scene.player.get_rid()]
    for part in parts:
        if part.rid.is_valid() and part.rid not in result:result.append(part.rid)
    return result
func _hits(part: Dictionary,parts: Array) -> Array:
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=part.shape
    query.transform=part.pose
    query.collision_mask=3
    query.exclude=_excluded(parts)
    if part.fixed.is_valid():query.exclude=query.exclude+[part.fixed]
    query.margin=.001
    var result=[]
    for hit in get_world_3d().direct_space_state.intersect_shape(query,32):result.append(str(hit.rid.get_id())+"/"+str(hit.shape))
    return result
func _space(point: Vector3,crouched: bool,parts: Array) -> bool:
    var height=1.56 if crouched else 1.84
    var excludes=_excluded(parts)
    var floor_ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.12,point-Vector3.UP*.15,3,excludes)
    var floor=get_world_3d().direct_space_state.intersect_ray(floor_ray)
    if floor.is_empty() or floor.normal.y<.9 or absf(floor.position.y-point.y)>.06:return false
    var capsule=CapsuleShape3D.new();capsule.radius=.23;capsule.height=height
    var query=PhysicsShapeQueryParameters3D.new()
    query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(height/2+.02));query.exclude=excludes;query.collision_mask=3;query.margin=.001
    if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
    for part in parts:
        if geometry.capsule_box(point,height,part):return false
    return true
func prepare(value: Variant, spatial: bool=true) -> Dictionary:
    reason="invalid"
    if not value is Dictionary or value.get("version")!=1:return {}
    var p=scene.player
    var inventory=load("res://personagem/inventario69.gd").new();inventory.house_anchors=p.bag_inventory.house_anchors.duplicate(true)
    var condition=p.condition_state.get_script().new()
    var body=load("res://personagem/corpo63.gd").new()
    if not inventory.restore(value.get("inventory"),false) or not condition.restore(value.get("condition")) or not body.restore(value.get("body"),false):return {}
    var forearm=0.0
    for wound in body.records.values():
        if wound.zone=="forearm_left":forearm+=wound.severity
    if condition.forearm_injury+.000001<minf(1,forearm):return {}
    var controller=p.map_doors
    var doors={"version":2,"states":{}}
    for id in controller.doors:doors.states[id]=false
    var raw=value.get("doors_h01")
    if raw!=null:
        if not raw is Dictionary or raw.get("version") not in [1.0,2.0,1,2] or not raw.get("states") is Dictionary:return {}
        var expected=11 if raw.version==2 else 4
        if raw.states.size()!=expected:return {}
        for id in doors.states:
            if raw.version==1 and str(id).contains("/window/"):continue
            if not raw.states.has(id) or not raw.states[id] is bool:return {}
            doors.states[id]=raw.states[id]
    var legacy=not value.has("session81")
    var session={"position":[p.global_position.x,p.global_position.y,p.global_position.z],"yaw":p.avatar.rotation.y,"crouched":p.crouched,"zoom":scene.zoom,"furniture":{"states":{},"opened":[],"active":"","chosen":{}}}
    var house=scene.world_items.house
    for id in house.bindings:session.furniture.states[id]=false
    if not legacy:
        session=value.session81
        if not session is Dictionary or session.get("version")!=1:return {}
        if session.get("world")!=_signature():reason="world";return {}
    if not session.get("position") is Array or session.position.size()!=3 or not session.get("crouched") is bool:return {}
    for number in session.position:
        if not (number is int or number is float) or not is_finite(float(number)) or absf(number)>10000:return {}
    for key in ["yaw","zoom"]:
        var number=session.get(key)
        if not (number is int or number is float) or not is_finite(float(number)):return {}
    if session.zoom<4.5 or session.zoom>18:return {}
    var furniture=session.get("furniture")
    if not furniture is Dictionary or not furniture.get("states") is Dictionary or furniture.states.size()!=house.bindings.size() or not furniture.get("opened") is Array or not furniture.get("active") is String or not furniture.get("chosen") is Dictionary:return {}
    for id in house.bindings:
        if not furniture.states.has(id) or not furniture.states[id] is bool:return {}
    for id in furniture.opened:
        if not id is String or not furniture.states.has(id) or not furniture.states[id]:return {}
    if not furniture.active.is_empty() and (not house.bindings.has(furniture.active) or furniture.active not in furniture.opened):return {}
    for group in furniture.chosen:
        var n=furniture.chosen[group]
        if not house.groups.has(group) or not house.groups[group].has("drawers") or not (n is int or n is float) or not is_finite(float(n)) or n<0 or n!=floor(n) or n>2147483647:return {}
    for group in house.groups:
        if house.groups[group].has("drawers"):continue
        var flags=[]
        for id in house.bindings:
            if house.bindings[id]==group:flags.append(furniture.states[id])
        for flag in flags:
            if flag!=flags[0]:return {}
    if not spatial:return {"validated":true}
    var point=Vector3(session.position[0],session.position[1],session.position[2])
    var parts=_parts(doors,furniture)
    reason="occupied"
    if not _space(point,session.crouched,parts):return {}
    for i in parts.size():
        var part: Dictionary=parts[i]
        for hit in _hits(part,parts):
            if part.open or hit not in closed_contacts.get(part.id,[]):return {}
        for j in range(i):
            if part.owner!=parts[j].owner and geometry.boxes(part,parts[j]):return {}
    reason=""
    return {"data":value.duplicate(true),"doors":doors,"session":session.duplicate(true),"parts":parts,"legacy":legacy}
func _read(path: String) -> Variant:
    if not FileAccess.file_exists(path):return null
    var parser=JSON.new()
    if parser.parse(FileAccess.get_file_as_string(path))!=OK:return null
    return parser.data
func save() -> bool:
    var p=scene.player
    if not _idle():p.inventory_message="Conclua a ação e o movimento dos móveis antes de salvar";return false
    var data=snapshot()
    if prepare(data).is_empty():p.inventory_message="Não há uma configuração segura para salvar aqui";return false
    working=true
    var file=FileAccess.open(p.condition_path+".tmp",FileAccess.WRITE)
    if file==null:working=false;p.inventory_message="Não foi possível abrir o arquivo da partida";return false
    file.store_string(JSON.stringify(data,"",true,true));file.flush()
    var error=file.get_error();file.close()
    if error!=OK:working=false;p.inventory_message="Não foi possível gravar a partida";return false
    if FileAccess.file_exists(p.condition_path):
        var previous=_read(p.condition_path)
        if not prepare(previous,false).is_empty():
            if DirAccess.copy_absolute(p.condition_path,p.condition_path+".bak.tmp")!=OK or DirAccess.rename_absolute(p.condition_path+".bak.tmp",p.condition_path+".bak")!=OK:
                working=false;p.inventory_message="Não foi possível preservar o backup";return false
    var accepted=DirAccess.rename_absolute(p.condition_path+".tmp",p.condition_path)==OK
    working=false
    p.inventory_message="Partida salva" if accepted else "Não foi possível gravar a partida"
    return accepted
func load_game() -> bool:
    var p=scene.player
    if not _idle():p.inventory_message="Conclua a ação atual antes de retomar";return false
    var prepared=prepare(_read(p.condition_path))
    var backup=false
    if prepared.is_empty() and reason=="invalid" and FileAccess.file_exists(p.condition_path+".bak"):
        prepared=prepare(_read(p.condition_path+".bak"));backup=not prepared.is_empty()
    if prepared.is_empty():
        p.inventory_message="Posição ou cenário de retorno ocupado" if reason=="occupied" else "Save de outra versão do cenário" if reason=="world" else "Não foi possível ler a partida"
        return false
    working=true
    var data: Dictionary=prepared.data
    var state: Dictionary=prepared.session
    var world=scene.world_items
    world.close_interaction()
    scene.game_ui.cancel_pending()
    p.map_doors.apply_restore(prepared.doors)
    for part in prepared.parts:
        if part.pivot!=null:
            part.pivot.transform=part.local_pose;part.part.fraction=1.0 if part.open else 0.0
    world.progress.clear()
    for id in state.furniture.states:world.progress[id]=1.0 if state.furniture.states[id] else 0.0
    world.chosen_drawer=state.furniture.chosen.duplicate(true)
    p.global_position=Vector3(state.position[0],state.position[1],state.position[2])
    p.velocity=Vector3.ZERO;p.crouched=state.crouched
    p.capsule.shape.height=1.56 if p.crouched else 1.84
    p.capsule.position.y=.78 if p.crouched else .92
    p.avatar.rotation.y=state.yaw;p.preview_motion=""
    p.bag_inventory.restore(data.inventory,false)
    p.body_health.restore(data.body,false)
    p.condition_state.restore(data.condition)
    p.bag_inventory.opened.assign(state.furniture.opened)
    p._sync_condition();p._sync_dressing()
    p.avatar.motion_rate=1
    p.avatar.set_motion("crouch_idle" if p.crouched else p.avatar.state_motion.motion_for(p.movement_condition,false,false))
    p.avatar.motion_blend=1;p.avatar.motion_clock=0;p.avatar.advance(0)
    scene.zoom=state.zoom;scene.focus=p.global_position+Vector3.UP*.95;scene._update_camera()
    p.bag_inventory.changed.emit();p.body_health.changed.emit()
    p.update_nearby()
    p.survival.update_pain();p.survival.refresh()
    scene.game_ui.personal.visible=false;scene.game_ui.nearby_wanted=false;scene.game_ui.windows[1].visible=false
    p.set_hud_open(false);scene.game_ui.refresh()
    if not state.furniture.active.is_empty():
        restoring_ui=true
        world.set_physics_process(false)
        p.set_hud_open(true)
        _resume_ui(state.furniture.active)
    working=false
    p.inventory_message="Backup da partida retomado" if backup else "Perfil anterior retomado na posição atual" if prepared.legacy else "Partida retomada"
    return true
func _resume_ui(id: String) -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    var p=scene.player
    p.update_nearby()
    scene.world_items.active_id=id
    if id in p.bag_inventory.reachable:scene.game_ui.show_container(id)
    else:scene.world_items.close_interaction()
    scene.world_items.set_physics_process(true)
    restoring_ui=false
