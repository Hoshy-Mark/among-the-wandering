extends SceneTree
var checks=0
var failed=false
var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos104.json"))
var ids=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens104.json")).characters.keys()
func _initialize() -> void:run()
func expect(value: bool,message: String) -> void:
    if not value:failed=true;push_error("R104_MODEL_FAIL "+message)
    else:checks+=1
func model() -> RefCounted:
    var m=load("res://personagem/social104.gd").new();assert(m.configure(catalog,ids));return m
func row(m: RefCounted,id: String) -> Dictionary:
    for option in m.options():
        if option.option_id==id:return option
    return {}
func choose(m: RefCounted,id: String) -> Dictionary:
    var r=row(m,id);assert(not r.is_empty(),id);return m.choose(m.active,r.id)
func seed_case(m: RefCounted,success: bool,score: int,difficulty: int) -> void:
    for n in range(1,1000):
        var rng=RandomNumberGenerator.new();rng.seed=n;var state=str(rng.state)
        if m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),score,difficulty)==success:
            var snap=m.snapshot();snap.rng_state=state;assert(m.restore(snap));return
    assert(false)
func topic(m: RefCounted,id: String) -> void:
    assert(choose(m,id).ok);assert(choose(m,"back").ok)
func run() -> void:
    var m=model();expect(m.data.content_revision104==1 and m.validate(m.snapshot())==m.snapshot(),"new content defaults validate")
    expect(m.config.dialogues.size()==5 and m.learning_rules.activities.size()==18 and m.learning_rules.trainable.size()==4,"five conversations eighteen distinct experiences four trainable skills")
    expect(m.chance(2,11)==10 and m.chance(2,9)==21 and m.chance(3,9)==26,"exact intimidation and empathy odds")
    m.begin("ricardo_medeiro");expect(row(m,"confinement").is_empty(),"doctor cannot reference unheard police rule")
    m.end();m.begin("jorge_luiz");topic(m,"rules");expect(m.knows("player","jorge_confinement_rules"),"rules learned directly from police source")
    m.end();m.begin("ricardo_medeiro");expect(row(m,"confinement").available,"sourced rule opens doctor's response")
    topic(m,"confinement");expect(m.knows("player","ricardo_helped_confinement"),"doctor discloses own established confinement involvement")
    var before=m.snapshot();topic(m,"confinement")
    expect(m.snapshot()==before,"repeated corroboration gives no duplicated fact experience or RNG")
    expect(not m.knows("player","ricardo_alberto_criminal_past") and m.data.progress.ricardo_alberto.visited.is_empty(),"doctor is distinct from Ricardo Alberto")
    var hostile=model();seed_case(hostile,false,2,11);hostile.begin("jorge_luiz")
    expect(row(hostile,"intimidate").skill=="intimidation" and row(hostile,"intimidate").chance==10,"pressure uses intimidation only")
    var roll=choose(hostile,"intimidate").check_result;expect(not roll.success and hostile.current_line().text=="Baixe o tom.","failed pressure has authored response")
    choose(hostile,"back");expect(row(hostile,"intimidate").state=="exhausted","intimidation attempt stays resolved")
    expect(hostile.relation("jorge_luiz","player").trust==-1 and hostile.relation("jorge_luiz","player").respect==-1 and hostile.relation("jorge_luiz","player").fear==0,"failed pressure changes only authored dimensions")
    expect(hostile.relation("ricardo_medeiro","player").trust==0 and hostile.relation("player","jorge_luiz").trust==0,"hostility does not spread to doctor or reverse edge")
    var pressure=model();seed_case(pressure,true,2,11);pressure.begin("jorge_luiz");expect(choose(pressure,"intimidate").check_result.success,"successful intimidation uses real roll")
    expect(pressure.relation("jorge_luiz","player").fear==1 and pressure.relation("jorge_luiz","player").respect==-1 and pressure.relation("jorge_luiz","player").trust==0,"successful pressure creates no blanket trust or alliance")
    choose(pressure,"back");topic(pressure,"personal")
    expect(not pressure.knows("player","jorge_crimes_sorriso_feliz") and not pressure.knows("player","armacao_jean"),"successful pressure cannot force secret disclosure")
    var empathetic=model();seed_case(empathetic,true,2,9);empathetic.begin("ricardo_medeiro")
    expect(row(empathetic,"empathy").skill=="empathy" and not row(empathetic,"personal").available,"empathy is separate and personal gate starts blocked")
    topic(empathetic,"privacy");expect(choose(empathetic,"empathy").check_result.success,"successful listening uses empathy roll")
    choose(empathetic,"back")
    expect(empathetic.relation("ricardo_medeiro","player").trust==2 and empathetic.relation("ricardo_medeiro","player").intimacy==1 and row(empathetic,"personal").available,"distinct respectful and empathetic choices create limited rapport")
    choose(empathetic,"personal");expect(empathetic.current_line().text=="Prefiro deixar isso para outro momento.","rapport allows asking without granting private family or illness details")
    var cautious=model();seed_case(cautious,false,2,9);cautious.begin("ricardo_medeiro");topic(cautious,"occupation");topic(cautious,"origin");topic(cautious,"privacy")
    expect(cautious.available_points()==1,"three distinct doctor activities award one point")
    expect(not choose(cautious,"empathy").check_result.success,"failed listening uses failure branch")
    choose(cautious,"back");var prior=cautious.snapshot();cautious.end()
    expect(cautious.train("empathy") and cautious.data.skills.empathy==3 and cautious.available_points()==0,"earned point can develop newly usable empathy")
    expect(cautious.data.rng_state==prior.rng_state and cautious.data.progress==prior.progress,"training does not alter past result or RNG")
    cautious.begin("ricardo_medeiro");expect(row(cautious,"empathy").state=="exhausted" and row(cautious,"empathy").chance==26,"one-shot empathy cannot reroll after skill improvement")
    var encoded=JSON.parse_string(JSON.stringify(cautious.snapshot()));var copy=model()
    expect(copy.restore(encoded) and copy.snapshot()==cautious.snapshot(),"new markers and new skill spending survive JSON roundtrip")
    var trained=model();trained.begin("jorge_luiz");topic(trained,"occupation");topic(trained,"rules");topic(trained,"acknowledge");trained.end()
    expect(trained.train("intimidation") and trained.data.skills.intimidation==3 and trained.available_points()==0,"new intimidation training consumes same point bank")
    expect(not trained.train("unknown") and not trained.train("intimidation"),"invalid skill or double spending rejected")
    var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/fixtures104/legacy103.json")).social101
    var legacy_model=load("res://personagem/social103.gd").new();assert(legacy_model.configure(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos103.json")),ids))
    legacy=legacy_model.validate(legacy);assert(not legacy.is_empty())
    var migrated=m.validate(legacy)
    expect(not migrated.is_empty() and migrated.skills==legacy.skills and migrated.learning102==legacy.learning102 and migrated.rng_state==legacy.rng_state,"actual R103 migration retains levels spending and RNG")
    expect(migrated.progress==legacy.progress and migrated.knowledge.player==legacy.knowledge.player,"migration invents no new player knowledge or dialogue choices")
    expect("jorge_confinement_rules" in migrated.knowledge.jorge_luiz and "ricardo_doctor" in migrated.knowledge.ricardo_medeiro,"migration seeds only new authored fact holders")
    expect(m.validate(migrated)==migrated,"content migration is idempotent")
    var older=load("res://personagem/social102.gd").new();assert(older.configure(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos101.json")),ids))
    expect(not m.validate(older.snapshot()).is_empty() and m.validate(null).learning102.earned.is_empty(),"older schema and missing social history still supported")
    var bad=cautious.snapshot();bad.content_revision104=2;expect(m.validate(bad).is_empty(),"unknown content marker rejected")
    bad=cautious.snapshot();bad.knowledge.ricardo_medeiro.erase("ricardo_doctor");expect(m.validate(bad).is_empty(),"damaged current canonical holder rejected")
    bad=cautious.snapshot();bad.learning102.spent.empathy=2;bad.skills.empathy=4;expect(m.validate(bad).is_empty(),"overspending new skill rejected")
    bad=cautious.snapshot();bad.progress.jorge_luiz.checks.doctor_empathy=bad.progress.ricardo_medeiro.checks.doctor_empathy;expect(m.validate(bad).is_empty(),"new checks cannot move between characters")
    print("R104_MODEL_FAILED " if failed else "R104_MODEL_OK ",checks);quit(1 if failed else 0)
