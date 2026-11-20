extends SceneTree
var count109=0
var failed109=false
var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos109.json"))
var roster=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens106.json"))
func _initialize() -> void:run()
func expect(value: bool,message: String) -> void:
    if value:count109+=1
    else:failed109=true;push_error("R109_FAIL "+message)
func model() -> RefCounted:
    var value=load("res://personagem/social109.gd").new();expect(value.configure(catalog,roster.characters.keys()),"catalog config");return value
func option(model109: RefCounted,id: String) -> Dictionary:
    for row in model109.options():
        if row.option_id==id:return row
    return {}
func pick(m: RefCounted,id: String) -> Dictionary:
    var row=option(m,id)
    if row.is_empty():return {"ok":false}
    return m.choose(m.active,row.id)
func root(m: RefCounted) -> void:
    if m.node!="root":expect(pick(m,"back").ok,"back to root")
func force_success(m: RefCounted,id: String) -> void:
    var definition=m.config.checks[id];var factors=m.factors(m.active,id)
    for seed in range(1,10000):
        var rng=RandomNumberGenerator.new();rng.seed=seed;var state=str(rng.state);var a=rng.randi_range(1,6);var b=rng.randi_range(1,6)
        if m.resolve_roll(a,b,factors.score,definition.difficulty):m.data.rng_state=state;return
func force_failure(m: RefCounted,id: String) -> void:
    var definition=m.config.checks[id];var factors=m.factors(m.active,id)
    for seed in range(1,10000):
        var rng=RandomNumberGenerator.new();rng.seed=seed;var state=str(rng.state);var a=rng.randi_range(1,6);var b=rng.randi_range(1,6)
        if not m.resolve_roll(a,b,factors.score,definition.difficulty):m.data.rng_state=state;return
func run() -> void:
    var m=model()
    expect(m.data.relations.size()==90,"all ten actors have 90 directed edges")
    expect(m.data.relations.values().all(func(row):return row.size()==10),"ten dimensions on every edge")
    expect(m.relation("gabriel_pimenta","jorge_luiz").fear==80 and m.relation("jorge_luiz","gabriel_pimenta").fear==0,"coercion asymmetric")
    expect(m.relation("pietra_dos_santos","josue_medeira").resentment==85,"durable resentment seed")
    expect(m.data.social109.npc_skills.size()==9,"all NPCs have independent skill sets")
    expect(not m.validate(m.snapshot()).is_empty(),"new state validates")
    var old=JSON.parse_string(FileAccess.get_file_as_string("res://qa/characters106/checkpoint.json"));var migrated=m.validate(old.social101)
    expect(not migrated.is_empty(),"R106 social state migrates")
    expect(migrated.knowledge.player==old.social101.knowledge.player,"migration grants no player knowledge")
    var legacy=load("res://personagem/social105.gd").new();legacy.configure(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos105.json")),roster.characters.keys());var legacy_checked=legacy.validate(old.social101)
    expect(migrated.skills==legacy_checked.skills and migrated.learning102==legacy_checked.learning102 and migrated.rng_state==legacy_checked.rng_state,"migration preserves ranks learning and RNG")
    for edge in old.social101.relations:
        for key in old.social101.relations[edge]:expect(migrated.relations[edge][key]==old.social101.relations[edge][key],"old directed value retained "+edge+"/"+key)
    expect(m.restore(migrated),"migrated restore")
    var roundtrip=JSON.parse_string(JSON.stringify(m.snapshot()));expect(m.validate(roundtrip)==m.snapshot(),"JSON roundtrip normalizes schema")
    m=model();expect(m.begin("ana_julia"),"Ana begins")
    expect(option(m,"igor109").is_empty(),"unknown information hides topic")
    var before=m.snapshot();expect(not m.choose(m.active,str(m.generation)+":root:igor109").ok and m.snapshot()==before,"forged hidden token cannot mutate")
    expect(pick(m,"school").ok and m.knows("player","ana_studied_sorriso"),"conversation learns school fact")
    root(m);m.end();expect(m.begin("samuel_henrique"),"Samuel begins")
    expect(option(m,"sorriso109").is_empty(),"two fact prerequisites are cumulative")
    expect(pick(m,"origin").ok,"learn Samuel return");root(m)
    expect(pick(m,"sorriso109").ok and m.knows("player","samuel_survivors_sorriso"),"Ana information opens Samuel testimony")
    root(m);m.end();m.begin("ana_julia")
    expect(not option(m,"igor109").available,"fact alone cannot bypass trust gate")
    var rng=m.data.rng_state;pick(m,"privacy");root(m);pick(m,"listen109");root(m)
    expect(m.data.rng_state==rng,"deterministic relationship interactions use no dice")
    expect(not option(m,"igor109").available,"two polite acts are insufficient for sensitive disclosure")
    m.end();m.begin("renata_volker");pick(m,"occupation");root(m);pick(m,"privacy");root(m);pick(m,"listen109");root(m);pick(m,"ana109");root(m);m.end();m.begin("ana_julia");pick(m,"renata109");root(m)
    expect(option(m,"igor109").available,"trust and facts jointly open private testimony")
    expect(pick(m,"igor109").ok and m.knows("player","ana_igor_missing"),"private testimony disclosed under authored consent")
    expect(m.data.social109.ledger.player.ana_igor_missing.source=="ana_julia","provenance is actual speaker")
    expect(m.known_profile109("ana_julia").secrets.size()==1,"known private record projected")
    expect(m.known_profile109("renata_volker").secrets.is_empty(),"no unrelated secret projection")
    root(m);var learned=m.data.learning102.earned.size();before=m.snapshot();expect(not pick(m,"igor109").ok and m.snapshot()==before,"repeated disclosure grants no relation farming")
    m.end();expect(m.begin("samuel_henrique"),"start gate tests")
    before=m.snapshot();expect(not pick(m,"gabriel109").ok and m.snapshot()==before,"strong skill or RNG cannot bypass missing fact")
    m.end();m.begin("gabriel_pimenta");pick(m,"occupation");root(m);pick(m,"church");root(m);pick(m,"privacy");root(m)
    expect(option(m,"safe109").available,"authored uncertain action available with preconditions")
    force_success(m,"r109_gabriel_pimenta_safe109");var check=pick(m,"safe109");expect(check.ok and not check.check_result.is_empty() and check.check_result.success,"risky listening uses existing 2d6 result")
    root(m);before=m.snapshot();expect(not pick(m,"safe109").ok and m.snapshot()==before,"one shot roll is persistent not rerolled")
    m.end();var a="renata_volker";var b="ricardo_medeiro";var original_player=m.data.knowledge.player.duplicate();var old_points=m.available_points()
    expect(m.interact109(a,b,"family_checkin").ok,"NPC pair uses shared interaction rules")
    expect(m.relation(a,b).trust==66 and m.relation(b,a).trust==70,"NPC interaction directional not mirrored")
    expect(not m.interact109(a,b,"family_checkin").ok,"NPC interactions have anti-repeat memory")
    expect(m.interact109(b,a,"family_checkin").ok,"reverse direction independently resolved")
    expect(not m.interact109("pietra_dos_santos","ricardo_alberto","courteous_greeting").ok,"resentment prevents superficial reconciliation")
    expect(not m.interact109("gabriel_pimenta","jorge_luiz","courteous_greeting").ok,"fear does not imply consent or friendship")
    expect(m.transmit109("gabriel_pimenta","ana_julia","gabriel_mechanic").ok,"NPC learns a report from another NPC")
    expect(m.knows("ana_julia","gabriel_mechanic") and m.data.social109.ledger.ana_julia.gabriel_mechanic.kind=="reported","NPC receipt is reported information")
    expect(not m.knows("renata_volker","gabriel_mechanic"),"third party receives no telepathy")
    expect(not m.transmit109("samuel_henrique","jorge_luiz","gabriel_wants_leave").ok,"private confidences cannot auto gossip")
    expect(not m.transmit109("ana_julia","ricardo_alberto","gabriel_confirms_leave").ok,"unpossessed or private information refused")
    var npc_roll=m.interact109("renata_volker","ana_julia","listening_request")
    expect(npc_roll.ok and npc_roll.check_result.score==m.data.social109.npc_skills.renata_volker.empathy,"NPC uses own skill for shared 2d6 rule")
    expect(m.data.social109.npc_checks.has(npc_roll.event),"NPC dice outcome persisted")
    var roll_state=m.snapshot();expect(not m.interact109("renata_volker","ana_julia","listening_request").ok and m.snapshot()==roll_state,"NPC cannot reroll or farm repeated event")
    expect(m.data.knowledge.player==original_player and m.available_points()==old_points,"NPC events do not grant player information or XP")
    var state=m.snapshot();expect(not m.validate(state).is_empty(),"NPC and player event state validates")
    var bad=state.duplicate(true);bad.social109.events.append("interaction/player/ana_julia/family_checkin");expect(m.validate(bad).is_empty(),"forged NPC event rejected")
    bad=state.duplicate(true);bad.social109.bonds["ana_julia>player"]=["ally"];expect(m.validate(bad).is_empty(),"save cannot manufacture alliance")
    bad=state.duplicate(true);bad.social109.ledger.player.erase("ana_igor_missing");expect(m.validate(bad).is_empty(),"provenance cannot disappear from learned fact")
    var copy=model();var restored=copy.restore(JSON.parse_string(JSON.stringify(state)))
    if restored and copy.snapshot()!=state:diff109(state,copy.snapshot(),"")
    expect(restored and copy.snapshot()==state,"all directed relations NPC knowledge memories and attempts persist")
    var alternate=model();alternate.begin("ana_julia");pick(alternate,"school");root(alternate);alternate.end()
    alternate.begin("samuel_henrique");pick(alternate,"origin");root(alternate);pick(alternate,"privacy");root(alternate);force_success(alternate,"calm_request");pick(alternate,"calm");root(alternate);pick(alternate,"sorriso109");root(alternate);alternate.end()
    alternate.begin("gabriel_pimenta");pick(alternate,"occupation");root(alternate);pick(alternate,"church");root(alternate);pick(alternate,"privacy");root(alternate);force_failure(alternate,"r109_gabriel_pimenta_safe109");pick(alternate,"safe109");root(alternate)
    expect(option(alternate,"control109").is_empty(),"failed listening alone reveals no new confidential approach")
    pick(alternate,"respect109");root(alternate);alternate.end();alternate.begin("samuel_henrique")
    expect(pick(alternate,"gabriel109").ok and alternate.knows("player","gabriel_wants_leave"),"earned opening in Samuel yields attributed confidence")
    root(alternate);alternate.end();alternate.begin("gabriel_pimenta")
    var xp=alternate.data.learning102.earned.size();expect(pick(alternate,"control109").ok,"new evidence plus respectful memory supports different path after failure");root(alternate)
    expect(alternate.data.learning102.earned.size()==xp,"alternative courtesy grants no XP")
    expect(not option(alternate,"safe109").available and pick(alternate,"leave109").ok,"failed roll stays resolved while distinct consent path continues")
    expect(alternate.data.social109.ledger.player.gabriel_confirms_leave.source=="gabriel_pimenta","direct confirmation retains different source from Samuel report")
    expect(not alternate.validate(alternate.snapshot()).is_empty(),"alternative complete chain validates")
    var hostile=model();hostile.begin("jorge_luiz");pick(hostile,"rules");root(hostile);force_failure(hostile,"jorge_intimidate");pick(hostile,"intimidate");root(hostile)
    expect(hostile.relation("jorge_luiz","player").resentment==2,"failed coercion leaves resentment")
    expect(pick(hostile,"deescalate109").ok and hostile.relation("jorge_luiz","player").resentment==1,"de-escalation changes partial resentment")
    expect(hostile.data.progress.jorge_luiz.flags.jorge_rebuffed,"de-escalation never erases hostile memory")
    var f=FileAccess.open("res://qa/social109/model_results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"passed":not failed109,"checks":count109},"  "));f.close()
    print("R109_MODEL_", "OK " if not failed109 else "FAIL ",count109);quit(1 if failed109 else 0)
func diff109(a: Variant,b: Variant,path: String) -> void:
    if a is Dictionary and b is Dictionary:
        for key in a:
            if b.has(key):diff109(a[key],b[key],path+"/"+str(key))
            else:print("DIFF missing ",path,key)
    elif a!=b or typeof(a)!=typeof(b):print("DIFF ",path," ",a," :: ",b," types ",typeof(a),"/",typeof(b))
