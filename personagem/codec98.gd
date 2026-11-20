extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var m=load("res://personagem/zumbis98.gd").new();assert(m.configure_population())
    assert(m.saved.size()==480 and m.valid(m.snapshot()))
    var old={}
    old.arroio82_01=m.initial.arr96_urban_001.duplicate(true);old.arroio82_01.erase("ambient98");old.arroio82_01.state="dead";old.arroio82_01.health=0;old.arroio82_01.position=[22,.28,160]
    old.arroio82_02=m.initial.arr96_urban_002.duplicate(true);old.arroio82_02.erase("ambient98");old.arroio82_02.health=.23;old.arroio82_02.memory=2;old.arroio82_02.state="search";old.arroio82_02.search_remaining84=7.1
    var expanded=m.expand_legacy(old);assert(m.valid(expanded));assert(expanded.size()==480 and not expanded.has("arroio82_01"))
    assert(expanded.arr96_urban_001.state=="dead" and expanded.arr96_urban_001.position==old.arroio82_01.position and expanded.arr96_urban_002.health==.23)
    m.restore(JSON.parse_string(JSON.stringify(expanded)));assert(m.saved.arr96_urban_001.state=="dead")
    var before=m.snapshot()
    for kind in ["missing","extra","revive","wait","direction","coordinate","unknown_profile"]:
        var bad=before.duplicate(true)
        if kind=="missing":bad.erase("arr96_outer_001")
        elif kind=="extra":bad.extra=bad.arr96_outer_001
        elif kind=="revive":bad.arr96_urban_001.health=.48
        elif kind=="wait":bad.arr96_outer_001.ambient98.wait=NAN
        elif kind=="direction":bad.arr96_outer_001.ambient98.direction=0
        elif kind=="coordinate":bad.arr96_outer_001.position[0]=NAN
        else:bad.arr96_outer_001.variant85="unknown"
        assert(not m.valid(bad),kind);m.restore(bad);assert(m.snapshot()==before)
    assert(m.expand_legacy({}).is_empty())
    print("R98_CODEC_OK total=480 aliases=2 legacy_death_and_position_preserved=true atomic_invalid_restore=true")
    m.free();quit()
