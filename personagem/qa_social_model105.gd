extends SceneTree
var checks=0
var failed=false
var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos105.json"))
var roster=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens105.json"))
func _initialize() -> void:run()
func expect(value: bool,message: String) -> void:
    if not value:failed=true;push_error("R105_MODEL_FAIL "+message)
    else:checks+=1
func model() -> RefCounted:
    var m=load("res://personagem/social105.gd").new();assert(m.configure(catalog,roster.characters.keys()));return m
func row(m: RefCounted,id: String) -> Dictionary:
    for option in m.options():
        if option.option_id==id:return option
    return {}
func choose(m: RefCounted,id: String) -> Dictionary:
    var r=row(m,id);assert(not r.is_empty(),id);return m.choose(m.active,r.id)
func topic(m: RefCounted,id: String) -> void:
    assert(choose(m,id).ok);assert(choose(m,"back").ok)
func stream105(m: RefCounted) -> String:
    for n in range(1,10000):
        var rng=RandomNumberGenerator.new();rng.seed=n;var state=str(rng.state)
        var first=m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),2,10)
        var second=m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),3,10)
        if not first and second:return state
    assert(false);return ""
func run() -> void:
    var m=model();expect(m.data.content_revision105==1 and m.validate(m.snapshot())==m.snapshot(),"current defaults normalize and validate")
    expect(catalog.dialogues.size()==9 and roster.encounters.size()==6 and m.learning_rules.activities.size()==30,"nine prepared graphs six actual encounters thirty distinct activities")
    for id in ["renata_volker","pietra_dos_santos","ana_julia"]:
        expect(not roster.encounters.has(id) and roster.presentation105[id].visual_status=="pending dedicated female base","female dialogue prepared without fabricated visual integration: "+id)
    expect(roster.presentation105.renata_volker.public_role=="Moradora","public role alias never exposes hidden journalism")
    expect(catalog.facts.farmer_cure_position.epistemic_kind=="attributed_statement_not_proof_of_cure" and not catalog.facts.has("cure_works"),"farmer position is testimony rather than proven cure")
    var start=m.snapshot();start.rng_state=stream105(m);expect(m.restore(start),"controlled model roll stream")
    m.begin("ricardo_alberto");expect(row(m,"calm").is_empty() and row(m,"rules").is_empty(),"farmer topics require actual prior discoveries")
    topic(m,"occupation");topic(m,"origin");topic(m,"cure")
    expect(m.knows("player","farmer_food_production") and m.knows("player","farmer_born_arroio") and m.knows("player","farmer_cure_position"),"public biography and attributed position learned from farmer")
    expect(m.available_points()==1 and m.experience_progress()==0,"three distinct farmer topics award one point")
    var before=m.snapshot();topic(m,"cure");topic(m,"origin")
    expect(m.snapshot()==before,"repeatable public statements do not farm state or RNG")
    expect(not choose(m,"calm").check_result.success,"first real persuasion fails")
    choose(m,"back");expect(not row(m,"calm").available,"unchanged failure remains blocked")
    m.end();m.begin("ricardo_alberto");expect(not row(m,"calm").available,"reopening cannot reroll failure")
    topic(m,"privacy");expect(row(m,"calm").available and row(m,"calm").chance==21,"farmer's own respectful context reopens improved attempt")
    expect(choose(m,"calm").check_result.success,"improved real roll succeeds")
    choose(m,"back");expect(m.data.learning102.earned.size()==5 and m.available_points()==1 and m.experience_progress()==2,"retry gives no second experience")
    expect(m.relation("ricardo_alberto","player").trust==2 and m.relation("ricardo_medeiro","player").trust==0 and m.relation("jorge_luiz","player").trust==0,"farmer rapport does not leak to namesake doctor or police")
    expect(row(m,"personal").available,"rapport permits a personal question")
    choose(m,"personal");expect(m.current_line().text=="Prefiro deixar isso para outra hora." and not m.knows("player","ricardo_alberto_criminal_past"),"personal boundary and private criminal past preserved")
    m.end();m.begin("jorge_luiz");topic(m,"rules");m.end();m.begin("ricardo_alberto")
    expect(row(m,"rules").available,"actual police source opens farmer confinement topic")
    before=m.snapshot();topic(m,"rules");expect(m.data.learning102.earned==before.learning102.earned,"cross-source context is not a duplicate experience reward")
    var copy=model();expect(copy.restore(JSON.parse_string(JSON.stringify(m.snapshot()))) and copy.snapshot()==m.snapshot(),"farmer history and content markers roundtrip through JSON")
    var prepared=model();prepared.begin("renata_volker")
    expect(row(prepared,"doctor").is_empty() and not row(prepared,"personal").available,"prepared Renata graph starts without unknown husband or private details")
    topic(prepared,"occupation")
    expect(prepared.knows("player","renata_public_identity") and catalog.facts.renata_public_identity.epistemic_kind=="public_self_presentation_not_verified_profession","Renata cover identity remains attributed self-presentation")
    expect(not prepared.knows("player","jorge_crimes_sorriso_feliz") and prepared.knows("renata_volker","jorge_crimes_sorriso_feliz"),"hidden journalistic knowledge stays with its canonical holder")
    prepared.end();prepared.begin("ricardo_medeiro");topic(prepared,"occupation");prepared.end();prepared.begin("renata_volker")
    expect(row(prepared,"doctor").available,"doctor introduction opens prepared spouse topic")
    topic(prepared,"doctor");topic(prepared,"privacy");choose(prepared,"personal")
    expect(prepared.knows("player","renata_married_doctor") and prepared.current_line().text.contains("outro momento"),"prepared spouse topic gives no illness medicine letter or crime disclosure")
    prepared.end();prepared.begin("pietra_dos_santos");expect(row(prepared,"josue").is_empty(),"prepared sister topic requires priest source")
    topic(prepared,"occupation");topic(prepared,"herbs")
    expect(prepared.knows("player","pietra_grows_herbs") and not prepared.knows("player","ricardo_alberto_criminal_past"),"herbs topic does not grant poisoning plans or unrelated secrets")
    prepared.end();prepared.begin("josue_medeira");topic(prepared,"occupation");prepared.end();prepared.begin("pietra_dos_santos")
    expect(row(prepared,"josue").available,"actual priest role discovery opens prepared sibling topic")
    topic(prepared,"josue");expect(prepared.knows("player","pietra_sister_josue"),"sibling fact learned from Pietra's own dialogue")
    prepared.end();prepared.begin("ana_julia");expect(row(prepared,"samuel").is_empty(),"prepared niece topic requires Samuel source")
    topic(prepared,"school");prepared.end();prepared.begin("samuel_henrique");topic(prepared,"origin");prepared.end();prepared.begin("ana_julia")
    expect(row(prepared,"samuel").available,"Samuel conversation opens prepared niece topic")
    topic(prepared,"samuel");expect(prepared.knows("player","ana_studied_sorriso") and prepared.knows("player","ana_samuel_niece"),"Ana's public facts do not assert Igor's fate or a journey outcome")
    expect(prepared.validate(prepared.snapshot())==prepared.snapshot(),"all nine graph histories remain valid")
    var old=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/fixtures105/legacy104.json")).social101
    var legacy=load("res://personagem/social104.gd").new();assert(legacy.configure(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos104.json")),roster.characters.keys()))
    old=legacy.validate(old);assert(not old.is_empty());var migrated=m.validate(old)
    expect(not migrated.is_empty() and migrated.skills==old.skills and migrated.learning102==old.learning102 and migrated.rng_state==old.rng_state,"R104 migration keeps skill spending and RNG")
    expect(migrated.progress==old.progress and migrated.knowledge.player==old.knowledge.player,"migration invents no farmer or female dialogue histories")
    expect(m.validate(migrated)==migrated and m.validate(null).learning102.earned.is_empty(),"migration idempotent and absent history not fabricated")
    var bad=m.snapshot();bad.content_revision105=2;expect(m.validate(bad).is_empty(),"unknown content version rejected")
    bad=m.snapshot();bad.knowledge.ricardo_alberto.erase("farmer_cure_position");expect(m.validate(bad).is_empty(),"damaged current holder rejected")
    bad=m.snapshot();bad.learning102.earned.append("renata_privacy");expect(m.validate(bad).is_empty(),"unperformed prepared activity cannot award point")
    print("R105_MODEL_FAILED " if failed else "R105_MODEL_OK ",checks);quit(1 if failed else 0)
