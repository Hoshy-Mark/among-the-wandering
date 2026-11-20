extends SceneTree
var checks=0
var catalog: Dictionary
var ids: Array
func _initialize() -> void:
    catalog=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos101.json"))
    ids=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens99.json")).characters.keys()
    run()
func expect(value: bool,message: String) -> void:
    assert(value,message);checks+=1
func model() -> RefCounted:
    var result=load("res://personagem/social101.gd").new();assert(result.configure(catalog,ids));return result
func row(m: RefCounted,id: String) -> Dictionary:
    for r in m.options():
        if r.option_id==id:return r
    return {}
func choose(m: RefCounted,id: String) -> Dictionary:
    var option=row(m,id);assert(not option.is_empty(),id);return m.choose("samuel_henrique",option.id)
func seed_case(m: RefCounted,success: bool,score: int,difficulty: int) -> void:
    for n in range(1,1000):
        var rng=RandomNumberGenerator.new();rng.seed=n;var state=str(rng.state)
        if m.resolve_roll(rng.randi_range(1,6),rng.randi_range(1,6),score,difficulty)==success:
            var snap=m.snapshot();snap.rng_state=state;assert(m.restore(snap));return
    assert(false)
func origin(m: RefCounted) -> void:
    assert(choose(m,"origin").ok);assert(choose(m,"back").ok)
func run() -> void:
    var m=model();expect(m.chance(2,10)==15 and m.chance(3,10)==21,"exact 2d6 odds")
    expect(m.chance(30,1)==35 and m.chance(-30,40)==1,"critical probabilities bounded at 1/36 and 35/36")
    expect(not m.resolve_roll(1,1,30,1) and m.resolve_roll(6,6,-30,40),"critical outcome independent of score")
    expect(m.snapshot().relations.size()==18 and m.relation("samuel_henrique","player").size()==8,"nine bidirectional relationships with independent dimensions")
    expect(m.knows("renata_volker","jorge_crimes_sorriso_feliz") and not m.knows("player","jorge_crimes_sorriso_feliz") and not m.knows("samuel_henrique","jorge_crimes_sorriso_feliz"),"asymmetric canonical knowledge")
    expect(m.validate(m.snapshot())==m.snapshot(),"initial complete state valid")
    expect(m.relation("samuel_henrique","gabriel_pimenta").is_empty(),"unauthored NPC-to-NPC values remain undefined, not fabricated zero scores")
    seed_case(m,false,2,10);expect(m.begin("samuel_henrique"),"start session")
    expect(row(m,"calm").is_empty() and row(m,"personal").state=="locked","hidden and visible locked options distinct")
    origin(m);expect(m.knows("player","samuel_returned") and row(m,"origin").state=="visited" and row(m,"origin").available,"public fact learned and repeatable topic marked visited")
    var public_before=m.snapshot();origin(m)
    expect(m.data.knowledge==public_before.knowledge and m.data.relations==public_before.relations and m.data.rng_state==public_before.rng_state,"revisiting public topic grants no duplicate knowledge social reward or reroll")
    expect(row(m,"calm").available and row(m,"calm").chance==15,"discovery unlocks check")
    var token=row(m,"calm").id;var result=m.choose("samuel_henrique",token)
    expect(result.ok and not result.check_result.success,"seeded failure follows failure branch")
    var after=m.snapshot();expect(not m.choose("samuel_henrique",token).ok and after==m.snapshot(),"stale double submission has no effect or RNG advancement")
    choose(m,"back");expect(not row(m,"calm").available,"failure blocks unchanged retry")
    m.end();m.begin("samuel_henrique");expect(not row(m,"calm").available,"reopening does not reroll")
    var privacy=row(m,"privacy").id;expect(m.choose("samuel_henrique",privacy).ok,"respectful branch accepted")
    expect(m.relation("samuel_henrique","player").trust==1 and m.relation("player","samuel_henrique").trust==0 and m.relation("jorge_luiz","player").trust==0,"effects directional and actor-specific")
    choose(m,"back");expect(row(m,"calm").available and row(m,"calm").chance==21,"relevant new context reopens improved chance")
    after=m.snapshot();expect(not m.choose("samuel_henrique",privacy).ok and m.snapshot()==after,"replayed respectful choice cannot farm relationship")
    expect(choose(m,"calm").ok,"retry after actual improvement")
    expect(m.data.progress.samuel_henrique.checks.calm_request.size()==2,"both attempts recorded once")
    choose(m,"back");expect(choose(m,"observe").ok,"one-shot perception test")
    choose(m,"back");expect(row(m,"observe").state=="exhausted","single attempt is permanent regardless of outcome")
    var encoded=JSON.parse_string(JSON.stringify(m.snapshot()));var copy=model()
    expect(copy.restore(encoded) and copy.snapshot()==m.snapshot() and copy.data.skills.persuasion is int,"JSON preserves RNG and resolved attempts")
    copy.begin("samuel_henrique");expect(row(copy,"observe").state=="exhausted","load cannot reopen one-shot test")
    expect(copy.validate(null).progress.samuel_henrique.visited.is_empty(),"legacy profile starts without fabricated choices")
    var bad=m.snapshot();bad.skills.persuasion=999;expect(m.validate(bad).is_empty(),"invalid ability rejected")
    bad=m.snapshot();bad.relations["samuel_henrique>player"].intimacy=-1;expect(m.validate(bad).is_empty(),"invalid intimacy rejected")
    bad=m.snapshot();bad.knowledge.player.append("invented_secret");expect(m.validate(bad).is_empty(),"unknown fact rejected")
    bad=m.snapshot();bad.progress.samuel_henrique.checks.observe[0].dice=[0,7];expect(m.validate(bad).is_empty(),"invalid dice rejected")
    bad=m.snapshot();bad.progress.samuel_henrique.checks.observe[0].success=not bad.progress.samuel_henrique.checks.observe[0].success;expect(m.validate(bad).is_empty(),"inconsistent resolved outcome rejected")
    bad=m.snapshot();bad.rng_state="broken";expect(m.validate(bad).is_empty(),"invalid random state rejected")
    var complete=model();seed_case(complete,true,3,10);complete.begin("samuel_henrique");origin(complete)
    choose(complete,"privacy");choose(complete,"back");expect(choose(complete,"calm").check_result.success,"successful full route")
    choose(complete,"back");expect(complete.relation("samuel_henrique","player").trust==2 and complete.relation("samuel_henrique","player").intimacy==1,"trust and intimacy evolve through distinct authored actions")
    expect(row(complete,"personal").available,"social prerequisites unlock personal topic")
    expect(choose(complete,"personal").ok and complete.current_line().text=="Prefiro deixar esse assunto para outro momento.","openness permits question without guaranteeing secret disclosure")
    expect(not complete.knows("player","ricardo_alberto_criminal_past"),"no private fact granted by successful persuasion")
    choose(complete,"back");expect(row(complete,"calm").state=="exhausted","successful check completed permanently")
    expect(complete.validate(complete.snapshot())==complete.snapshot(),"successful final state validates")
    var fixture=catalog.duplicate(true)
    fixture.dialogues.samuel_henrique.nodes.root.options.append({"id":"qa_unknown","text":"QA","learn":"jorge_crimes_sorriso_feliz","target":"root"})
    fixture.dialogues.samuel_henrique.nodes.root.options.append({"id":"qa_private","text":"QA","learn":"ricardo_alberto_criminal_past","target":"root"})
    var gated=load("res://personagem/social101.gd").new();expect(gated.configure(fixture,ids) and gated.begin("samuel_henrique"),"isolated disclosure fixture")
    expect(row(gated,"qa_unknown").is_empty() and row(gated,"qa_private").is_empty(),"unknown source and unauthorized private disclosure remain hidden")
    print("R101_MODEL_OK ",checks);quit()
