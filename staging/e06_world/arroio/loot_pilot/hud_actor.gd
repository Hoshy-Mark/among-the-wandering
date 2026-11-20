extends "res://staging/e06_world/arroio/scripts/test_walker.gd"
## Contract bridge for the approved hud68; no alternate inventory UI.
const VENDOR="res://staging/e06_world/arroio/loot_pilot/vendor/"
signal hud_requested(index:int)
var pilot:Node
var bag_inventory:RefCounted
var body_health:RefCounted
var condition_state:RefCounted
var inventory_actions:RefCounted
var action:RefCounted
var world_interaction:RefCounted
var inventory_message=""
var weapons:Node
var map_combat:Node
var damage_serial=0
var restoring=false
func _ready():
	super._ready();condition_state=load(VENDOR+"ferimentos62.gd").new();body_health=load(VENDOR+"corpo63.gd").new();body_health.condition=condition_state;inventory_actions=load("res://staging/e06_world/arroio/loot_pilot/instant_action.gd").new();action=inventory_actions
func bind(owner_pilot:Node):
	pilot=owner_pilot;bag_inventory=load("res://staging/e06_world/arroio/loot_pilot/inventory_view.gd").new();bag_inventory.pilot=pilot;bag_inventory.sync_from_state(false);world_interaction=load("res://staging/e06_world/arroio/loot_pilot/hud_interaction.gd").new();world_interaction.pilot=pilot
	_restore_context();condition_state.changed.connect(capture_context);body_health.changed.connect(capture_context)
func capture_context():
	if not restoring and pilot!=null and pilot.state!=null:pilot.state.actor_context={"condition":condition_state.snapshot(),"body":body_health.snapshot()}
func _restore_context()->bool:
	var data:Dictionary=pilot.state.actor_context
	if data.is_empty():return true
	restoring=true;var valid:bool=condition_state.restore(data.get("condition")) and body_health.restore(data.get("body"),false);restoring=false
	if valid:body_health.changed.emit()
	return valid
func set_hud_open(opened:bool)->bool:input_enabled=not opened and not pilot.automated;return true
func _finish(accepted:bool)->bool:
	inventory_message=pilot.state.message;return accepted
func place_item(uid:String,destination:String,x:int,y:int,rotated:bool,amount:int=0,split_only:bool=false)->bool:
	capture_context()
	if uid==bag_inventory.reserved_uid:return _finish(pilot.state.pickup("EST05_OBJ_01",x,y,destination,rotated,global_position))
	return _finish(pilot.state.mutate("place",uid,destination,x,y,rotated,amount,split_only,global_position))
func rotate_item(uid:String)->bool:capture_context();return _finish(pilot.state.mutate("rotate",uid))
func equip_item(uid:String)->bool:capture_context();return _finish(pilot.state.mutate("equip",uid))
func merge_items(uid:String,target:String,amount:int)->bool:capture_context();return _finish(pilot.state.mutate("merge",uid,target,0,0,false,amount))
func save_condition()->bool:
	capture_context();var accepted:bool=pilot.state.save();inventory_message="Progresso salvo" if accepted else pilot.state.message;return accepted
func load_condition()->bool:
	var before=pilot.state.snapshot()
	if not pilot.state.reload():return _finish(false)
	if not _restore_context():pilot.state._adopt(before);_restore_context();bag_inventory.sync_from_state();inventory_message="Estado do corpo inválido; progresso preservado";return false
	bag_inventory.sync_from_state();return _finish(true)
func receive_zone_damage(id:String,zone:String,kind:String,amount:float)->bool:return body_health.hit(id,zone,kind,amount)
func use_item(_uid:String)->bool:inventory_message="Os itens deste piloto não têm ação de consumo";return false
func request_use(_kind:String)->bool:inventory_message="Nenhum item de tratamento disponível neste piloto";return false
