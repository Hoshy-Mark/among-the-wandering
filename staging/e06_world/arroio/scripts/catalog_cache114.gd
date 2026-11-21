extends RefCounted
## Scene-local immutable catalog snapshots; every caller receives its own copy.
var documents={}
var configuration=[]
var hits=0
var misses=0
var invalidations=0
const FLAGS=["show_hydrology_reference","batch_static_visuals","show_yard_details","terrain_variation","show_landscape","apply_lot_overrides","apply_master_candidates","apply_h11_h20_candidates","apply_h21_h30_candidates","apply_h31_h40_candidates","apply_current_h01_h20_revisions","apply_est01_est03_models","apply_est04_est09_models","apply_civic_vegetation","apply_lrp01","apply_lrp02","apply_rural_models","apply_rural_network","enable_ambience","apply_residential_interiors","apply_civic_interiors","h02_variant"]
func clear() -> void:
    documents.clear();configuration.clear();invalidations+=1
func fetch(world: Node3D,name: String,loader: Callable) -> Variant:
    var current=[]
    for flag in FLAGS:current.append(world.get(flag))
    if current!=configuration:
        documents.clear();configuration=current;invalidations+=1
    if documents.has(name):
        hits+=1
        return documents[name].duplicate(true)
    misses+=1
    var value=loader.call(name)
    if value is Dictionary or value is Array:documents[name]=value.duplicate(true)
    return value
