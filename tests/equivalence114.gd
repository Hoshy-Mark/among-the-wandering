extends SceneTree
var checks114=0
var error114=0.0
var failures114=[]
func check(value: bool,message: String) -> void:
    if not value:failures114.append(message);push_error(message)
    checks114+=1
func pose_error(a: Transform3D,b: Transform3D) -> float:
    return maxf(a.origin.distance_to(b.origin),maxf(a.basis.x.distance_to(b.basis.x),maxf(a.basis.y.distance_to(b.basis.y),a.basis.z.distance_to(b.basis.z))))
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var old_city=load("res://tests/fixtures114/city_before.gd").new()
    var city=load("res://staging/e06_world/arroio/scripts/city.gd").new()
    var names=["city_master","environment","landscape","urban_dressing","yard_details","lot_overrides","parcels","roads","public_spaces","ground_cover"]
    for option in [{},{"h02_variant":"A"},{"apply_current_h01_h20_revisions":false},{"apply_h11_h20_candidates":false,"apply_h31_h40_candidates":false},{"apply_lot_overrides":false}]:
        for flag in city.catalog_cache114.FLAGS:
            var value=option.get(flag,"B" if flag=="h02_variant" else false if flag=="show_hydrology_reference" else true)
            old_city.set(flag,value);city.set(flag,value)
        for name in names:
            var reference=old_city.catalog(name);var value=city.catalog(name)
            check(value==reference,"catalog value unchanged "+name)
            check(city.catalog(name)==reference,"catalog cache hit unchanged "+name)
    var mutated=city.catalog("lot_overrides");mutated.lots.clear()
    check(not city.catalog("lot_overrides").lots.is_empty(),"caller cannot corrupt cached data")
    var arrays=city.catalog("parcels");arrays.clear()
    check(not city.catalog("parcels").is_empty(),"array caller cannot corrupt cached data")
    var hits=city.catalog_cache114.hits;city.catalog("landscape")
    check(city.catalog_cache114.hits==hits+1,"cached catalog actually reused")
    city.invalidate_catalogs114();check(city.catalog_cache114.documents.is_empty(),"explicit reload clears snapshots")
    old_city.free();city.free()
    var counts={};var timings={}
    for scene_path in ["res://personagem/personagem.tscn","res://personagem/personagem_feminina106.tscn"]:
        if not ResourceLoader.exists(scene_path):
            check(false,"female base fixture missing");continue
        var actor=load(scene_path).instantiate();actor.manual_update=true;root.add_child(actor)
        var rig=actor.skeleton
        var old_hand=load("res://tests/fixtures114/hands_before.gd").new();old_hand.setup(actor)
        var hand=actor.hand_layer
        load("res://personagem/maos_apoio.gd").register(old_hand);load("res://personagem/maos_apoio.gd").register(hand)
        var hand_ids=old_hand.poses.keys()
        var poses=0
        for motion in actor.clips:
            if not actor.player.has_animation(actor.clips[motion]):continue
            var length=actor.player.get_animation(actor.clips[motion]).length
            actor.set_motion(motion);actor.motion_blend=1;actor.motion_rate=0
            for fraction in [0.0,.125,.25,.5,.75,1.0]:
                var hand_id=hand_ids[poses%hand_ids.size()]
                old_hand.set_pose(hand_id);hand.set_pose(hand_id);old_hand.advance(.15);hand.advance(.15)
                actor.motion_clock=length*fraction;actor.advance(0)
                var before=[]
                for bone in rig.get_bone_count():before.append(rig.get_bone_pose(bone))
                old_hand.apply();var reference=[]
                for bone in rig.get_bone_count():reference.append(rig.get_bone_global_pose(bone))
                for bone in rig.get_bone_count():rig.set_bone_pose(bone,before[bone])
                hand.apply()
                for bone in rig.get_bone_count():error114=maxf(error114,pose_error(reference[bone],rig.get_bone_global_pose(bone)))
                check(error114<.00001,"identical skeleton pose with cached hand controls");poses+=1
        for id in old_hand.poses:
            old_hand.set_pose(id);hand.set_pose(id)
            for delta in [.0,.016,.033,.05,.1,.5]:
                old_hand.advance(delta);hand.advance(delta)
                for bone in old_hand.current:check(pose_error(old_hand.current[bone],hand.current[bone])<.000001,"hand pose unchanged")
        for clip in old_hand.library.get_animation_list():
            old_hand.play(clip);hand.play(clip)
            for frame in 30:
                old_hand.advance(.033);hand.advance(.033)
                for bone in old_hand.current:check(pose_error(old_hand.current[bone],hand.current[bone])<.000001,"finger animation unchanged")
        old_hand.set_pose("Relaxed");hand.set_pose("Relaxed");old_hand.advance(1);hand.advance(1)
        var time=Time.get_ticks_usec()
        for i in 2000:old_hand.advance(1.0/60)
        var old_hands=Time.get_ticks_usec()-time;time=Time.get_ticks_usec()
        for i in 2000:hand.advance(1.0/60)
        var new_hands=Time.get_ticks_usec()-time
        timings[scene_path]={"old_hands_usec":old_hands,"new_hands_usec":new_hands}
        counts[scene_path]=poses;actor.free()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/performance114"))
    var result={"passed":failures114.is_empty(),"failures":failures114,"checks":checks114,"poses":counts,"max_skeleton_error":error114,"microbench":timings}
    FileAccess.open("res://qa/performance114/equivalence.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("EQUIVALENCE114 ",JSON.stringify(result));quit(0 if result.passed else 1)
