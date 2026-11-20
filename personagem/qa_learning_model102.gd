extends SceneTree
var checks=0
var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos101.json"))
var ids=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens99.json")).characters.keys()
func _initialize() -> void:run()
func expect(value: bool,message: String) -> void:
    assert(value,message);checks+=1
func model() -> RefCounted:
    var m=load("res://personagem/social102.gd").new();assert(m.configure(catalog,ids));return m
func row(m: RefCounted,id: String) -> Dictionary:
    for option in m.options():
        if option.option_id==id:return option
    return {}
func choose(m: RefCounted,id: String) -> Dictionary:
    var r=row(m,id);assert(not r.is_empty(),id);return m.choose("samuel_henrique",r.id)
func stream(m: RefCounted) -> String:
    for n in range(1,10000):
        var rng=RandomNumberGenerator.new();rng.seed=n;var before=str(rng.state)
        var a=m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),2,10)
        var b=m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),2,9)
        var c=m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),3,10)
        if not a and not b and c:return before
    assert(false);return ""
func run() -> void:
    var m=model();expect(m.data.version==2 and m.available_points()==0,"schema two starts without invented experience")
    expect(m.validate(m.snapshot())==m.snapshot(),"defaults validate")
    expect(not m.train("persuasion"),"no free training")
    var state=m.snapshot();state.rng_state=stream(m);expect(m.restore(state),"controlled test stream")
    m.begin("samuel_henrique");choose(m,"origin");choose(m,"back")
    expect(m.data.learning102.earned.size()==1 and m.available_points()==0,"one distinct topic gives one experience")
    choose(m,"origin");choose(m,"back")
    expect(m.data.learning102.earned.size()==1,"repeatable question cannot farm experience")
    expect(not choose(m,"calm").check_result.success,"first persuasion fails")
    choose(m,"back");expect(not row(m,"calm").available,"unchanged failed test stays locked")
    expect(not choose(m,"observe").check_result.success,"first observation fails")
    choose(m,"back")
    expect(m.available_points()==1 and m.experience_progress()==0,"three distinct experiences award one point even after failures")
    expect(not m.train("persuasion"),"no spending during conversation")
    var prior=m.snapshot();m.end()
    expect(not m.train("empathy") and not m.train("unknown"),"only skills with authored uses are trainable")
    expect(m.train("persuasion") and m.data.skills.persuasion==3 and m.available_points()==0,"explicit allocation raises chosen skill once")
    expect(m.data.rng_state==prior.rng_state and m.data.relations==prior.relations and m.data.progress==prior.progress,"training preserves dice relationships and past outcomes")
    expect(not m.train("persuasion"),"cannot spend point twice")
    m.begin("samuel_henrique")
    expect(row(m,"calm").available and row(m,"calm").chance==21,"actual relevant skill improvement reopens failed check at 58 percent")
    expect(choose(m,"calm").check_result.success,"improved retry succeeds using next original random roll")
    choose(m,"back")
    expect(m.data.learning102.earned.size()==3 and m.available_points()==0,"retry is not a second activity reward")
    choose(m,"privacy");choose(m,"back")
    expect(m.data.learning102.earned.size()==4 and m.experience_progress()==1,"fourth unique activity carries remainder")
    var encoded=JSON.parse_string(JSON.stringify(m.snapshot()));var copy=model()
    expect(copy.restore(encoded) and copy.snapshot()==m.snapshot(),"full JSON roundtrip keeps spending ranks credit and dice")
    expect(copy.available_points()==0 and not copy.train("perception"),"loading cannot refund spent point")
    expect(copy.validate(null).learning102.earned.is_empty(),"pre-social save does not invent activities")
    var legacy=m.snapshot();legacy.version=1;legacy.erase("learning102");var migrated=copy.validate(legacy)
    expect(migrated.skills==legacy.skills and migrated.learning102.baseline==legacy.skills,"R101 migration preserves current skills as baseline")
    expect(migrated.learning102.earned.size()==4 and migrated.learning102.spent.persuasion==0,"R101 completed activities credited once")
    expect(copy.restore(migrated) and copy.available_points()==1 and copy.restore(copy.snapshot()) and copy.available_points()==1,"migration normalization is idempotent")
    expect(copy.train("perception") and copy.data.skills.perception==3,"second trainable skill uses same point bank")
    var bad=m.snapshot();bad.learning102.earned.append(bad.learning102.earned[0]);expect(m.validate(bad).is_empty(),"duplicate reward rejected")
    bad=m.snapshot();bad.learning102.earned.append("invented");expect(m.validate(bad).is_empty(),"unknown reward rejected")
    bad=model().snapshot();bad.learning102.earned=["samuel_privacy"];expect(m.validate(bad).is_empty(),"unperformed reward rejected")
    bad=m.snapshot();bad.learning102.spent.persuasion=2;bad.skills.persuasion=4;expect(m.validate(bad).is_empty(),"overspending rejected")
    bad=m.snapshot();bad.skills.persuasion=4;expect(m.validate(bad).is_empty(),"rank and training ledger mismatch rejected")
    bad=m.snapshot();bad.learning102.baseline.erase("perception");expect(m.validate(bad).is_empty(),"incomplete baseline rejected")
    bad=m.snapshot();bad.learning102.spent.persuasion=-1;expect(m.validate(bad).is_empty(),"negative spending rejected")
    bad=m.snapshot();bad.learning102.spent.empathy=1;bad.skills.empathy=3;bad.learning102.spent.persuasion=0;bad.skills.persuasion=2;expect(m.validate(bad).is_empty(),"unavailable skill spending rejected")
    bad=m.snapshot();bad.learning102="bad";expect(m.validate(bad).is_empty(),"malformed ledger rejected")
    var cap=m.snapshot();cap.skills.persuasion=6;cap.learning102.baseline.persuasion=6;cap.learning102.spent.persuasion=0
    expect(copy.restore(cap) and copy.available_points()==1 and not copy.train("persuasion"),"maximum rank never spends point")
    print("R102_MODEL_OK ",checks);quit()
