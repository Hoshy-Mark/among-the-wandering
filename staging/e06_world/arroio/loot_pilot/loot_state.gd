extends RefCounted
## Stateful loot adapter around the existing grid inventory. Only the isolated pilot uses it.
const ROOT="res://staging/e06_world/arroio/loot_pilot/"
var config:Dictionary
var inventory:RefCounted
var ledger={}
var claimed={}
var history={}
var minted={}
var actor_context={}
var registry={}
var descriptors={}
var world_seed=""
var save_path=""
var guard:Callable
var ready_state=false
var message=""
signal changed
func _integer(v:Variant)->bool:return (v is int or v is float) and is_finite(float(v)) and float(v)==floor(float(v))
func _fresh()->RefCounted:
	var model=load(ROOT+"vendor/inventario69.gd").new();model.catalog.merge(config.items,true);model.world_containers=registry.duplicate(true);model.house_anchors=registry.duplicate(true);model.items={};model.next_id=1;model.import_grids={}
	for row in config.containers:model.import_grids[_key(row.id)]=row.grid.duplicate()
	model.add_at("calca_terra",1,"slot:pants",0,0,false);model.add_at("bag_school",1,"slot:backpack",0,0,false);model.seeding=false;return model
func _key(id:String)->String:return "world:"+id
func initialize(settings:Dictionary,path:String,positions:Dictionary,access:Callable)->bool:
	config=settings.duplicate(true);save_path=path;guard=access;registry={};descriptors={};ledger={};claimed={};ready_state=false;world_seed=str(config.default_world_seed)
	for row in config.containers:
		row.grid=[int(row.grid[0]),int(row.grid[1])];descriptors[row.id]=row;registry[_key(row.id)]={"name":str(row.name).substr(0,80),"kind":"cabinet","capacity":int(row.grid[0])*int(row.grid[1]),"position":positions.get(row.id,[0.0,0.0,0.0]),"pilot_id":row.id}
	inventory=_fresh();history={};actor_context={};minted=_counts(inventory.items)
	for uid in inventory.items:history[uid]=inventory.items[uid].definition
	var actual=path if FileAccess.file_exists(path) else path+".bak" if FileAccess.file_exists(path+".bak") else ""
	if not actual.is_empty():
		var loaded=_decode(actual)
		if loaded.is_empty() or not _adopt(loaded):message="Save do piloto inválido; arquivo preservado";return false
	else:
		if not _write(_body(inventory,ledger,claimed)):return false
	ready_state=true;message="Piloto pronto";changed.emit();return true
func _rights(model:RefCounted):
	var ids:Array[String]=[]
	for id in descriptors:
		if guard.is_valid() and str(guard.call(id,"search")).is_empty():ids.append(_key(id))
	for id in model.world_containers:
		if not registry.has(id) and guard.is_valid() and str(guard.call("@ground:"+str(id),"search")).is_empty():ids.append(id)
	model.set_reachable(ids,Vector3.ZERO)
	for id in model.world_containers:model.set_open(id,id in ids)
func _candidate()->RefCounted:
	var model=_fresh()
	if not model.restore(inventory.snapshot(),false):return null
	_rights(model);return model
func _allow(id:String,operation:String)->bool:
	if not ready_state or not guard.is_valid() or not descriptors.has(id):message="Recipiente indisponível";return false
	message=str(guard.call(id,operation));return message.is_empty()
func search(id:String)->bool:
	if not _allow(id,"search"):return false
	if ledger.has(id):message="Já vasculhado";return true
	var model=_candidate();var state=ledger.duplicate(true);var row:Dictionary=descriptors[id];var rng=RandomNumberGenerator.new();rng.seed=(world_seed+"|"+id+"|"+str(config.table_revision)).sha256_text().substr(0,15).hex_to_int();var uids=[];var index=0
	for entry in config.profiles[row.profile]:
		if entry.item in row.get("excluded",[]):continue
		if rng.randf()>=float(entry.chance):continue
		var count=rng.randi_range(int(entry.min),int(entry.max));var x=index%int(row.grid[0]);var y=index/int(row.grid[0]);var uid=model.add_at(str(entry.item),count,_key(id),x,y,false)
		if uid.is_empty():message="Tabela do piloto não cabe na grade";return false
		uids.append(uid);index+=1
	state[id]={"profile":row.profile,"table_revision":int(config.table_revision),"uids":uids}
	return _commit(model,state,claimed.duplicate(true),"Busca concluída" if not uids.is_empty() else "Recipiente vazio",true)
func take(id:String,uid:String,x:int,y:int)->bool:
	if not _allow(id,"search") or not ledger.has(id):return false
	if not inventory.items.has(uid) or inventory.items[uid].location!=_key(id):message="Item indisponível";return false
	var model=_candidate();var bag:String=model.equipped("backpack")
	if not model.place(uid,bag,x,y,false):message=model.message;return false
	return _commit(model,ledger.duplicate(true),claimed.duplicate(true),"Item coletado")
func pickup(id:String,x:int,y:int,destination:String="",rotated:bool=false,position:Vector3=Vector3.ZERO)->bool:
	var row:Dictionary={}
	for candidate in config.pickups:
		if candidate.id==id:row=candidate;break
	if row.is_empty() or not _allow(str(row.container_id),"pickup"):return false
	if claimed.has(id):message="Este objeto já foi coletado";return false
	var model=_candidate();model.actor_position=position
	if destination.is_empty():destination=model.equipped("backpack")
	elif destination=="drop_here":destination=model.ground_at(position)
	elif not _location_allowed(destination):message="Destino indisponível";return false
	var uid=model.add_at(str(row.item),1,destination,x,y,rotated)
	if uid.is_empty():message="O objeto não cabe nesta célula";return false
	var next=claimed.duplicate(true);next[id]=uid;return _commit(model,ledger.duplicate(true),next,"Objeto coletado",true)
func _body(model:RefCounted,state:Dictionary,picks:Dictionary)->Dictionary:return {"version":1,"world_seed":world_seed,"inventory":model.snapshot(),"ledger":state,"claimed":picks,"history":history.duplicate(true),"minted":minted.duplicate(true),"actor":_canonical(actor_context)}
func snapshot()->Dictionary:return _body(inventory,ledger,claimed).duplicate(true)
func _commit(model:RefCounted,state:Dictionary,picks:Dictionary,text:String,minting:bool=false)->bool:
	if model==null:return false
	var body=_body(model,state,picks);var totals=_counts(model.items)
	if not minting and totals!=minted:message="Quantidade inconsistente; ação cancelada";return false
	body.minted=totals
	for uid in model.items:body.history[uid]=model.items[uid].definition
	if not _valid(body):message="Estado do piloto inválido; ação cancelada";return false
	if not _write(body):return false
	inventory=model;ledger=state;claimed=picks;history=body.history;minted=body.minted;message=text;changed.emit();return true
func save()->bool:
	if not ready_state:return false
	return _write(snapshot())
func reload()->bool:
	var body=_decode(save_path)
	if body.is_empty() or not _adopt(body):message="Save inválido; estado atual preservado";return false
	ready_state=true;message="Conteúdo do piloto carregado";changed.emit();return true
func _adopt(body:Dictionary)->bool:
	body=body.duplicate(true)
	if not body.has("history") and body.get("inventory",{}).get("items") is Dictionary:
		body.history={};body.minted=_counts(body.inventory.items);body.actor={}
		for uid in body.inventory.items:body.history[uid]=body.inventory.items[uid].definition
	if not _valid(body):return false
	var model=_fresh()
	if not model.restore(body.inventory,false):return false
	inventory=model;ledger=body.ledger.duplicate(true);claimed=body.claimed.duplicate(true);world_seed=body.world_seed;history=body.history.duplicate(true);minted={};actor_context=body.get("actor",{}).duplicate(true)
	for definition in body.minted:minted[definition]=int(body.minted[definition])
	for row in ledger.values():row.table_revision=int(row.table_revision)
	return true
func _valid(body:Variant)->bool:
	if not body is Dictionary or body.get("version")!=1 or not body.get("world_seed") is String or body.world_seed.is_empty() or body.world_seed.length()>80:return false
	if not body.get("inventory") is Dictionary or not body.get("ledger") is Dictionary or not body.get("claimed") is Dictionary:return false
	var raw:Dictionary=body.inventory
	if not raw.get("world_containers") is Dictionary or not raw.get("import_grids") is Dictionary:return false
	for id in registry:
		if not raw.world_containers.has(id):return false
		var grid=raw.import_grids.get(id);var expected:Array=descriptors[registry[id].pilot_id].grid
		if not grid is Array or grid.size()!=2 or not _integer(grid[0]) or not _integer(grid[1]) or int(grid[0])!=expected[0] or int(grid[1])!=expected[1]:return false
	for id in raw.world_containers:
		if not registry.has(id) and (not str(id).begins_with("world:drop:") or not raw.world_containers[id] is Dictionary or raw.world_containers[id].get("kind")!="ground"):return false
	var model=_fresh()
	if not model.restore(raw,false):return false
	if not body.get("history") is Dictionary or not body.get("minted") is Dictionary or not body.get("actor",{}) is Dictionary:return false
	var maximum=0
	for uid in body.history:
		if not uid is String or not uid.begins_with("item_") or not uid.trim_prefix("item_").is_valid_int() or not model.catalog.has(body.history[uid]):return false
		maximum=maxi(maximum,int(uid.trim_prefix("item_")))
	if int(model.next_id)<=maximum:return false
	for uid in model.items:
		if body.history.get(uid)!=model.items[uid].definition:return false
	var totals=_counts(model.items)
	if totals.size()!=body.minted.size():return false
	for definition in body.minted:
		if not _integer(body.minted[definition]) or int(body.minted[definition])<1 or int(totals.get(definition,0))!=int(body.minted[definition]):return false
	if int(body.minted.get("calca_terra",0))<1 or int(body.minted.get("bag_school",0))<1:return false
	var tracked={}
	for id in body.ledger:
		if not descriptors.has(id) or not body.ledger[id] is Dictionary:return false
		var row:Dictionary=body.ledger[id]
		if not row.get("profile") is String or not _integer(row.get("table_revision")) or row.table_revision<1 or not row.get("uids") is Array or row.uids.size()>64:return false
		for uid in row.uids:
			if not uid is String or tracked.has(uid) or not body.history.has(uid) or body.history[uid] in descriptors[id].get("excluded",[]):return false
			tracked[uid]=true
	for id in body.claimed:
		var definition=""
		for pickup in config.pickups:
			if pickup.id==id:definition=pickup.item
		var uid=body.claimed[id]
		if definition.is_empty() or not uid is String or tracked.has(uid) or not model.items.has(uid) or model.items[uid].definition!=definition :return false
		tracked[uid]=true
	return true
func _decode(path:String)->Dictionary:
	var f=FileAccess.open(path,FileAccess.READ)
	if f==null or f.get_length()>4000000:return {}
	var decoder=JSON.new();var error=decoder.parse(f.get_as_text());f.close()
	if error!=OK:return {}
	var envelope=decoder.data
	if not envelope is Dictionary or not envelope.get("payload") is String or not envelope.get("sha256") is String or envelope.payload.sha256_text()!=envelope.sha256:return {}
	if decoder.parse(envelope.payload)!=OK:return {}
	var data=decoder.data;return data if data is Dictionary else {}
func _write(body:Dictionary)->bool:
	if not save_path.begins_with("user://arroio_loot_pilot_rev01/") or ".." in save_path or not save_path.ends_with(".json"):message="Destino do piloto inválido";return false
	var path=ProjectSettings.globalize_path(save_path);var tmp=path+".tmp";var backup=path+".bak"
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK:message="Não foi possível salvar; ação cancelada";return false
	var payload=JSON.stringify(body);var f=FileAccess.open(tmp,FileAccess.WRITE)
	if f==null:message="Não foi possível salvar; ação cancelada";return false
	f.store_string(JSON.stringify({"payload":payload,"sha256":payload.sha256_text()}));f.flush();var error=f.get_error();f.close()
	if error!=OK or _decode(tmp).is_empty():message="Falha ao verificar o save; ação cancelada";return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup)!=OK:return false
		if DirAccess.rename_absolute(path,backup)!=OK:return false
	if DirAccess.rename_absolute(tmp,path)!=OK:
		if FileAccess.file_exists(backup):DirAccess.rename_absolute(backup,path)
		message="Falha ao concluir o save; ação cancelada";return false
	return true

func _counts(items:Dictionary)->Dictionary:
	var totals={}
	for item in items.values():totals[item.definition]=int(totals.get(item.definition,0))+int(item.count)
	return totals
func _location_allowed(location:String)->bool:
	if registry.has(location):return ledger.has(registry[location].pilot_id) and _allow(str(registry[location].pilot_id),"search")
	if inventory.world_containers.has(location):return guard.is_valid() and str(guard.call("@ground:"+location,"search")).is_empty()
	if location=="pockets" or location.begins_with("slot:"):return true
	if inventory.items.has(location):return _location_allowed(str(inventory.items[location].location))
	return false
func mutate(operation:String,uid:String,destination:String="",x:int=0,y:int=0,rotated:bool=false,amount:int=0,split_only:bool=false,position:Vector3=Vector3.ZERO)->bool:
	if not ready_state or not inventory.items.has(uid) or not _location_allowed(str(inventory.items[uid].location)):message="Item fora de alcance";return false
	if operation=="place" and destination!="drop_here" and not _location_allowed(destination):message="Destino indisponível";return false
	var model=_candidate();model.actor_position=position;var accepted=false
	match operation:
		"place":accepted=model.drop_at(uid,x,y,rotated) if destination=="drop_here" else model.place(uid,destination,x,y,rotated,amount,split_only)
		"rotate":accepted=model.rotate(uid)
		"equip":accepted=model.equip(uid)
		"merge":
			if model.items.has(destination) and _location_allowed(str(model.items[destination].location)):accepted=model.merge(uid,destination,amount)
	if not accepted:message=model.message;return false
	return _commit(model,ledger.duplicate(true),claimed.duplicate(true),"Inventário atualizado")

func _canonical(value:Variant)->Variant:
	if value is Dictionary:
		var result={}
		for key in value:result[key]=_canonical(value[key])
		return result
	if value is Array:return value.map(_canonical)
	if value is float and is_finite(value) and value==floor(value):return int(value)
	return value
