extends SceneTree
var checks=0
var failed=false
var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos103.json"))
var ids=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens103.json")).characters.keys()
func _initialize() -> void:run()
func expect(value: bool,message: String) -> void:
    if not value:failed=true;push_error("R103_MODEL_FAIL "+message)
    else:checks+=1
func model() -> RefCounted:
    var m=load("res://personagem/social103.gd").new();assert(m.configure(catalog,ids));return m
func row(m: RefCounted,id: String) -> Dictionary:
    for option in m.options():
        if option.option_id==id:return option
    return {}
func choose(m: RefCounted,id: String) -> Dictionary:
    var r=row(m,id);assert(not r.is_empty(),id);return m.choose(m.active,r.id)
func run() -> void:
    var m=model();expect(m.data.content_revision103==1 and m.validate(m.snapshot())==m.snapshot(),"current defaults validate with additive content revision")
    expect(m.config.dialogues.size()==3 and m.learning_rules.activities.size()==10,"three authored conversations and ten distinct learning activities")
    expect(not m.knows("player","gabriel_church_helper") and m.knows("gabriel_pimenta","gabriel_church_helper") and m.knows("josue_medeira","gabriel_church_helper"),"public fact has explicit holders, not player omniscience")
    m.begin("josue_medeira");expect(row(m,"gabriel").is_empty() and row(m,"calm").is_empty(),"topics require knowledge before appearing")
    var stale=row(m,"occupation").id;m.end();m.begin("gabriel_pimenta")
    expect(not m.choose("gabriel_pimenta",stale).ok and not m.choose("josue_medeira",row(m,"occupation").id).ok,"cross-NPC stale and wrong-speaker callbacks rejected")
    choose(m,"occupation");choose(m,"back")
    expect(m.knows("player","gabriel_mechanic") and m.data.learning102.earned==["gabriel_occupation"],"Gabriel profession gives sourced knowledge and single experience")
    var before=m.snapshot();choose(m,"occupation");choose(m,"back")
    expect(m.snapshot()==before,"repeatable profession cannot farm any state or RNG")
    choose(m,"church");choose(m,"back");expect(m.knows("player","gabriel_church_helper"),"learning church assistance through its actual source")
    expect(not row(m,"personal").available,"personal question initially requires actual rapport")
    choose(m,"privacy");choose(m,"back")
    expect(row(m,"privacy").state=="exhausted" and row(m,"personal").available,"one respectful choice changes only its authored gate")
    expect(m.relation("gabriel_pimenta","player").trust==1 and m.relation("josue_medeira","player").trust==0 and m.relation("player","gabriel_pimenta").trust==0,"relationships remain directional and NPC-local")
    choose(m,"personal");expect(m.current_line().text=="Por enquanto, prefiro ficar no trabalho.","rapport permits question, not private biography disclosure")
    choose(m,"back");choose(m,"observe");choose(m,"back")
    expect(row(m,"observe").state=="exhausted" and m.available_points()==1,"first observation earns third experience once regardless of outcome")
    m.end();m.begin("josue_medeira")
    expect(row(m,"gabriel").available and m.data.progress.josue_medeira.visited.is_empty(),"learned fact unlocks topic with another NPC without fabricating his decisions")
    before=m.snapshot();choose(m,"gabriel");choose(m,"back")
    expect(m.data.knowledge.player==before.knowledge.player and m.data.learning102.earned==before.learning102.earned,"corroborating same fact duplicates neither fact nor reward")
    choose(m,"occupation");choose(m,"back");expect(m.knows("player","josue_priest") and row(m,"calm").available,"priest role opens his own persuasion attempt")
    expect(m.data.progress.samuel_henrique.visited.is_empty() and m.data.progress.samuel_henrique.checks.is_empty(),"Samuel not changed by other conversations")
    choose(m,"privacy");choose(m,"back")
    expect(row(m,"calm").chance==21 and m.relation("josue_medeira","player").trust==1,"priest modifiers use his own context")
    choose(m,"calm");choose(m,"back")
    expect(m.available_points()==2 and m.experience_progress()==0,"learning combines six distinct activities across two characters")
    var encoded=JSON.parse_string(JSON.stringify(m.snapshot()));var copy=model()
    expect(copy.restore(encoded) and copy.snapshot()==m.snapshot(),"multi-NPC JSON roundtrip keeps facts relationships checks and experience")
    expect(copy.train("perception") and copy.data.skills.perception==3 and copy.available_points()==1,"shared point bank still allocates once")
    expect(not copy.knows("player","armacao_jean") and not copy.knows("player","jorge_crimes_sorriso_feliz") and not copy.knows("player","ricardo_alberto_criminal_past"),"no secrets leaked by dialogue gates or rolls")
    var legacy=load("res://personagem/social102.gd").new();assert(legacy.configure(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos101.json")),ids))
    var old=legacy.snapshot();var migrated=m.validate(old)
    expect(not migrated.is_empty() and migrated.skills==old.skills and migrated.rng_state==old.rng_state and migrated.learning102==old.learning102,"R102 migration preserves levels RNG and learning ledger")
    expect(migrated.knowledge.player==old.knowledge.player and migrated.progress==old.progress,"migration invents no player facts or NPC interactions")
    expect("gabriel_church_helper" in migrated.knowledge.josue_medeira and "gabriel_mechanic" in migrated.knowledge.gabriel_pimenta,"only authored new fact holders seeded on legacy migration")
    expect(m.validate(migrated)==migrated,"content migration is idempotent")
    old.version=1;old.erase("learning102");expect(not m.validate(old).is_empty(),"R101 version one still migrates")
    expect(m.validate(null).learning102.earned.is_empty(),"pre-social save starts without fictional experiences")
    var bad=m.snapshot();bad.content_revision103=2;expect(m.validate(bad).is_empty(),"unknown content version rejected")
    bad=m.snapshot();bad.knowledge.josue_medeira.erase("gabriel_church_helper");expect(m.validate(bad).is_empty(),"damaged current canonical holder cannot masquerade as migration")
    bad=m.snapshot();bad.progress.samuel_henrique.checks.gabriel_observe=bad.progress.gabriel_pimenta.checks.gabriel_observe;expect(m.validate(bad).is_empty(),"check attempts cannot move between NPCs")
    bad=m.snapshot();bad.learning102.earned.append("josue_calm_attempt");expect(m.validate(bad).is_empty(),"duplicate cross-character credit rejected")
    print("R103_MODEL_FAILED " if failed else "R103_MODEL_OK ",checks);quit(1 if failed else 0)
