extends "res://staging/e06_world/arroio/loot_pilot/loot_state.gd"
## One saved world allocation: quotas are independent of the order of searches.
var allocation={}
func initialize(settings:Dictionary,path:String,positions:Dictionary,access:Callable)->bool:
 _allocate(settings)
 return super.initialize(settings,path,positions,access)
func _allocate(settings:Dictionary):
 allocation={};var site_used={};var region_used={};var site_states={};var ordered=settings.containers.duplicate(true);var seedtext:String=settings.default_world_seed
 for pickup in settings.pickups:
  region_used[pickup.item]=int(region_used.get(pickup.item,0))+1
  for row in settings.containers:
   if row.id==pickup.container_id:site_used[row.site]=int(site_used.get(row.site,0))+1;break
 ordered.sort_custom(func(a,b):return (seedtext+str(a.id)).sha256_text()<(seedtext+str(b.id)).sha256_text())
 for row in ordered:
  var rng=RandomNumberGenerator.new();rng.seed=(seedtext+"|"+str(row.id)+"|"+str(settings.table_revision)).sha256_text().substr(0,15).hex_to_int()
  if not site_states.has(row.site):
   var site_rng=RandomNumberGenerator.new();site_rng.seed=(seedtext+"|site|"+str(row.site)).sha256_text().substr(0,15).hex_to_int();var chance=site_rng.randf();site_states[row.site]="saqueado" if chance<.40 else "abandonado" if chance<.85 else "preservado"
  var state_rule:Dictionary=settings.catalog_rules.site_states[site_states[row.site]]
  var profile:Dictionary=settings.profiles[row.profile];var plan=[];var choices:Array=profile.entries.duplicate(true);var budget:int=int(settings.site_budgets.get(row.site,18)*float(state_rule.count_multiplier));var used:int=site_used.get(row.site,0)
  if rng.randf()>=clampf(float(profile.empty_probability)+float(state_rule.empty_probability_delta),0,1):
   var draws:int=rng.randi_range(1,maxi(1,int(profile.max_draws)))
   for draw in draws:
    if used>=budget:break
    var valid=[];var total=0
    for entry in choices:
     if entry.item in row.get("excluded",[]):continue
     var cap=3 if entry.rarity=="E" else 10 if entry.rarity=="R" else 1000000
     if int(region_used.get(entry.item,0))>=cap:continue
     valid.append(entry);total+=int(entry.weight)
    if valid.is_empty() or total<1:break
    var n:int=rng.randi_range(1,total);var selected:Dictionary=valid[0]
    for entry in valid:
     n-=int(entry.weight)
     if n<=0:selected=entry;break
    choices.erase(selected);var iid:String=selected.item;var variants:Array=settings.variants.get(iid,[])
    if not variants.is_empty():iid=variants[rng.randi_range(0,variants.size()-1)]
    var cap=3 if selected.rarity=="E" else 10 if selected.rarity=="R" else 1000000
    var qty:int=mini(rng.randi_range(int(selected.min),int(selected.max)),mini(int(settings.items[iid].get("stack",1)),cap-int(region_used.get(selected.item,0))))
    if qty<1:continue
    plan.append({"item":iid,"family":selected.item,"count":qty,"condition":selected.condition_policy,"rarity":selected.rarity});region_used[selected.item]=int(region_used.get(selected.item,0))+qty;used+=1
  site_used[row.site]=used;allocation[row.id]=plan
func _body(model:RefCounted,state:Dictionary,picked:Dictionary)->Dictionary:
 var result=super._body(model,state,picked);result.world_allocation=_canonical(allocation);return result
func _adopt(body:Dictionary)->bool:
 if not body.get("world_allocation") is Dictionary:return false
 var previous=allocation;allocation=_canonical(body.world_allocation)
 if not super._adopt(body):allocation=previous;return false
 return true
func _valid(body:Variant)->bool:
 if not super._valid(body) or not body.get("world_allocation") is Dictionary:return false
 for id in descriptors:
  if not body.world_allocation.get(id) is Array:return false
  var seen={}
  for row in body.world_allocation[id]:
   if not row is Dictionary or not config.items.has(row.get("item","")) or not _integer(row.get("count")) or row.count<1 or row.count>int(config.items[row.item].get("stack",1)) or seen.has(row.item):return false
   seen[row.item]=true
 return true
func search(id:String)->bool:
 if not _allow(id,"search"):return false
 if ledger.has(id):message="Já vasculhado";return true
 var model=_candidate();var record=ledger.duplicate(true);var uids=[];var row:Dictionary=descriptors[id]
 for planned in allocation.get(id,[]):
  var found=false
  for rotation in [false,true]:
   if found:break
   for y in int(row.grid[1]):
    if found:break
    for x in int(row.grid[0]):
     var uid:String=model.add_at(planned.item,int(planned.count),_key(id),x,y,rotation)
     if uid.is_empty():continue
     # Metadata is persisted by the existing inventory snapshots and split/merge rules.
     model.items[uid]["loot_condition"]=planned.condition;model.items[uid]["source_container"]=id;uids.append(uid);found=true;break
  # No fit means no replacement roll and no overflow on the floor.
 record[id]={"profile":row.profile,"table_revision":int(config.table_revision),"uids":uids}
 return _commit(model,record,claimed.duplicate(true),"Busca concluída" if not uids.is_empty() else "Recipiente vazio",true)
