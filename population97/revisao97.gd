extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var config=JSON.parse_string(FileAccess.get_file_as_string("res://population97/populacao97.json"))
    assert(config.get("habitat_revision")==97)
    var model=load("res://population97/registro97.gd").new();assert(model.configure(config))
    var initial=model.snapshot();assert(model.valid(initial));assert(model.states.size()==480)
    var id="arr96_outer_001";var p=model.states[id].position.duplicate()
    model.schedule(100000);assert(model.states[id].position==p and model.states[id].mode=="patrol")
    assert(not model.begin_incursion(id));assert(model.damage(id,1.0))
    model.states["arr96_urban_001"].wait97=2.3;model.states["arr96_urban_001"].visits97=7;model.states["arr96_urban_001"].direction97=-1
    var saved=model.snapshot();var disk="res://population97_state_fixture.json"
    if "--reopen-pop97" in OS.get_cmdline_user_args():
        assert(model.restore(JSON.parse_string(FileAccess.get_file_as_string(disk))))
        assert(model.states[id].mode=="dead" and model.states["arr96_urban_001"].wait97==2.3 and model.states["arr96_urban_001"].direction97==-1)
        print("R97_FRESH_PROCESS_OK")
    else:FileAccess.open(disk,FileAccess.WRITE).store_string(JSON.stringify(saved))
    var fresh=model.get_script().new();assert(fresh.configure(config));assert(fresh.restore(JSON.parse_string(JSON.stringify(saved))))
    var before=fresh.snapshot()
    for kind in ["missing","extra","wait","direction","visits","health","catalog"]:
        var bad=before.duplicate(true)
        if kind=="missing":bad.individuals.erase(id)
        elif kind=="extra":bad.individuals.new_zombie=bad.individuals[id].duplicate(true)
        elif kind=="wait":bad.individuals[id].wait97=NAN
        elif kind=="direction":bad.individuals[id].direction97=0
        elif kind=="visits":bad.individuals[id].visits97=-1
        elif kind=="health":bad.individuals[id].health=-1
        else:bad.catalog="other"
        assert(not fresh.restore(bad));assert(fresh.snapshot()==before)
    for zombie in fresh.states:fresh.damage(zombie,1.0)
    fresh.schedule(100000);assert(fresh.states.size()==480)
    for state in fresh.states.values():assert(state.mode=="dead")
    print("R97_REGISTRY_OK fixed=480 wander_state_persisted=true no_forced_city_incursion=true no_replenishment=true")
    quit()
