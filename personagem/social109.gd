extends "res://personagem/social105.gd"
## Rules shared by every directed social edge. UI only receives projections.
var rules109=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/social_rules109.json"))
func _init() -> void:
    learning_rules=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/aprendizado109.json"))
func _defaults() -> Dictionary:
    var value=super._defaults();_migrate109(value);return value
func _migrate109(value: Dictionary) -> void:
    for edge in value.relations:
        for dimension in ["resentment","romance"]:
            if not value.relations[edge].has(dimension):value.relations[edge][dimension]=0
    for source in actor_ids:
        for target in actor_ids:
            if source==target:continue
            var edge=source+">"+target
            if value.relations.has(edge):continue
            value.relations[edge]=_zero_relation()
            for seed in rules109.seeds:
                if seed.source==source and seed.target==target:value.relations[edge].merge(seed.scores,true)
            for dimension in value.relations[edge]:value.relations[edge][dimension]=int(value.relations[edge][dimension])
    # New initial holders are narrative authorship, never player discoveries.
    for fact in config.facts:
        if config.facts[fact].has("subjects109"):
            for holder in config.facts[fact].known_by:
                if fact not in value.knowledge[holder]:value.knowledge[holder].append(fact)
    var ledger={}
    for actor in actor_ids+["player"]:
        ledger[actor]={}
        for fact in value.knowledge[actor]:
            var initial=actor in config.facts[fact].known_by
            ledger[actor][fact]={"source":actor if initial else "unknown","channel":"initial" if initial else "legacy","kind":"personal_knowledge" if initial else "reported","event":"baseline"}
    var bonds={}
    for seed in rules109.seeds:bonds[seed.source+">"+seed.target]=seed.bonds.duplicate()
    value.social109={"version":1,"npc_skills":rules109.npc_skills.duplicate(true),"ledger":ledger,"bonds":bonds,"events":[],"memories":{},"npc_checks":{}}
    for actor in actor_ids+["player"]:value.social109.memories[actor]=[]
    for actor in actor_ids:
        for skill in config.skills:value.social109.npc_skills[actor][skill]=int(value.social109.npc_skills[actor][skill])
func validate(value: Variant) -> Dictionary:
    if value==null:return _defaults()
    if not value is Dictionary:return {}
    var migrated=value.duplicate(true)
    if not migrated.has("social109"):
        if not migrated.get("relations") is Dictionary or not migrated.get("knowledge") is Dictionary:return {}
        for actor in actor_ids+["player"]:
            if not migrated.knowledge.get(actor) is Array:return {}
        for fact in migrated.knowledge.player:
            if config.facts.has(fact) and config.facts[fact].has("subjects109"):return {}
        for edge in migrated.relations:
            if not migrated.relations[edge] is Dictionary:return {}
        _migrate109(migrated)
    var checked=super.validate(migrated)
    if checked.is_empty() or checked.relations.size()!=90:return {}
    var state=checked.get("social109")
    if not state is Dictionary or state.get("version")!=1:return {}
    for key in ["npc_skills","ledger","bonds","memories","npc_checks"]:
        if not state.get(key) is Dictionary:return {}
    if state.npc_skills.size()!=actor_ids.size() or state.ledger.size()!=actor_ids.size()+1 or state.memories.size()!=actor_ids.size()+1:return {}
    for actor in actor_ids:
        if not state.npc_skills.get(actor) is Dictionary or state.npc_skills[actor].size()!=config.skills.size():return {}
        for skill in config.skills:
            if not _integer(state.npc_skills[actor].get(skill),0,6):return {}
            state.npc_skills[actor][skill]=int(state.npc_skills[actor][skill])
    if not state.get("events") is Array or state.events.size()>10000:return {}
    var seen=[]
    for event in state.events:
        if not event is String or event in seen or not valid_event109(event):return {}
        seen.append(event)
    for event in state.npc_checks:
        var parts=str(event).split("/")
        if event not in state.events or parts.size()!=4 or parts[0]!="interaction":return {}
        var rule=rules109.interactions.get(parts[3],{});var record=state.npc_checks[event]
        if not rule.has("skill") or not record is Dictionary or not record.get("dice") is Array or record.dice.size()!=2:return {}
        if not _integer(record.dice[0],1,6) or not _integer(record.dice[1],1,6) or not _integer(record.get("score"),0,6) or record.get("difficulty")!=rule.difficulty or record.get("skill")!=rule.skill:return {}
        if not record.get("success") is bool or record.success!=resolve_roll(int(record.dice[0]),int(record.dice[1]),int(record.score),int(record.difficulty)):return {}
        record.dice=[int(record.dice[0]),int(record.dice[1])];record.score=int(record.score);record.difficulty=int(record.difficulty)
    for event in state.events:
        var parts=str(event).split("/")
        if parts[0]=="interaction" and rules109.interactions[parts[3]].has("skill") and not state.npc_checks.has(event):return {}
    for actor in actor_ids+["player"]:
        if not state.ledger.get(actor) is Dictionary or state.ledger[actor].size()!=checked.knowledge[actor].size():return {}
        for fact in checked.knowledge[actor]:
            var record=state.ledger[actor].get(fact)
            if not record is Dictionary or record.get("source") not in actor_ids+["player","unknown"] or record.get("channel") not in ["initial","legacy","conversation"] or record.get("kind") not in ["personal_knowledge","reported","testimony"] or not record.get("event") is String:return {}
        if not state.memories.get(actor) is Array:return {}
        var remembered=[]
        for event in state.memories[actor]:
            if event not in state.events or event in remembered:return {}
            remembered.append(event)
    var expected_bonds={}
    for seed in rules109.seeds:expected_bonds[seed.source+">"+seed.target]=seed.bonds.duplicate()
    if state.bonds!=expected_bonds:return {}
    state.version=1;return checked
func valid_event109(event: String) -> bool:
    var parts=event.split("/")
    if parts.size()==3 and parts[0]=="dialogue":
        if not config.dialogues.has(parts[1]):return false
        return parts[2] in config.flags
    if parts.size()==4 and parts[0]=="interaction":return parts[1] in actor_ids and parts[2] in actor_ids and parts[1]!=parts[2] and rules109.interactions.has(parts[3])
    if parts.size()==4 and parts[0]=="transfer":return parts[1] in actor_ids and parts[2] in actor_ids and parts[1]!=parts[2] and config.facts.has(parts[3]) and not config.facts[parts[3]].get("private",false)
    return false
func _actor109(raw: String,context: Dictionary) -> String:
    if raw=="$npc":return context.get("npc","")
    if raw=="$source":return context.get("source","")
    if raw=="$target":return context.get("target","")
    return raw
func gate109(conditions: Array,context: Dictionary) -> Dictionary:
    for condition in conditions:
        var allowed=false
        match str(condition.get("type","")):
            "knows":allowed=knows(_actor109(condition.actor,context),condition.fact)
            "relation":
                var scores=relation(_actor109(condition.source,context),_actor109(condition.target,context))
                if scores.has(condition.dimension):allowed=int(scores[condition.dimension])>=int(condition.get("minimum",-100)) and int(scores[condition.dimension])<=int(condition.get("maximum",100))
            "bond":allowed=condition.bond in data.social109.bonds.get(_actor109(condition.source,context)+">"+_actor109(condition.target,context),[])
            "flag":allowed=bool(data.progress.get(_actor109(condition.actor,context),{}).get("flags",{}).get(condition.flag,false))
        if not allowed:return {"ok":false,"hidden":bool(condition.get("hidden",false)),"reason":"Ainda não há abertura para esse assunto." if condition.type!="knows" else "Ainda falta uma informação."}
    return {"ok":true}
func _description(npc: String,key: String,option: Dictionary,exit_allowed: bool) -> Dictionary:
    var row=super._description(npc,key,option,exit_allowed)
    var gate=gate109(option.get("requires109",[]),{"npc":npc,"source":npc,"target":"player"})
    if not gate.ok:row.state="hidden" if gate.hidden else "locked";row.available=false;row.reason=gate.reason
    return row
func _apply(npc: String,definition: Dictionary) -> void:
    var before=data.knowledge.player.duplicate();var flag=str(definition.get("flag",""));var first=flag!="" and not data.progress[npc].flags.get(flag,false)
    super._apply(npc,definition)
    for fact in data.knowledge.player:
        if fact not in before:data.social109.ledger.player[fact]={"source":npc,"channel":"conversation","kind":"testimony","event":"dialogue/"+npc+"/"+flag}
    if first:
        var event="dialogue/"+npc+"/"+flag
        if event not in data.social109.events:
            data.social109.events.append(event);data.social109.memories[npc].append(event);data.social109.memories.player.append(event)
func interact109(source: String,target: String,interaction: String) -> Dictionary:
    # Caller authorizes physical meeting. No player shortcut or unrestricted fact export.
    if source not in actor_ids or target not in actor_ids or source==target or not rules109.interactions.has(interaction):return {"ok":false}
    if active!="":return {"ok":false}
    var rule=rules109.interactions[interaction];var event="interaction/"+source+"/"+target+"/"+interaction
    if event in data.social109.events:return {"ok":false,"reason":"already_resolved"}
    var gate=gate109(rule.get("gates",[]),{"source":source,"target":target})
    if not gate.ok:return {"ok":false,"reason":"boundary"}
    var outcome={"ok":true,"source":source,"target":target,"event":event,"line":rule.line,"check_result":{}}
    var success=true
    if rule.has("skill"):
        var score=int(data.social109.npc_skills[source][rule.skill]);var rng=RandomNumberGenerator.new();rng.state=int(data.rng_state)
        var a=rng.randi_range(1,6);var b=rng.randi_range(1,6);success=resolve_roll(a,b,score,int(rule.difficulty));data.rng_state=str(rng.state)
        outcome.check_result={"dice":[a,b],"score":score,"difficulty":int(rule.difficulty),"success":success,"skill":rule.skill};outcome.line=rule.line if success else rule.failure_line
        data.social109.npc_checks[event]=outcome.check_result.duplicate(true)
    if success:
        for dimension in rule.effects:
            var limits=config.dimensions[dimension];var scores=data.relations[source+">"+target]
            scores[dimension]=clampi(int(scores[dimension])+int(rule.effects[dimension]),limits[0],limits[1])
    data.social109.events.append(event);data.social109.memories[source].append(event);data.social109.memories[target].append(event)
    return outcome
func transmit109(source: String,target: String,fact: String) -> Dictionary:
    # A legitimate physical interaction must call this service. No broadcast/world reputation.
    if not active.is_empty() or source not in actor_ids or target not in actor_ids or source==target or not config.facts.has(fact):return {"ok":false}
    if config.facts[fact].get("private",false) or not knows(source,fact) or knows(target,fact):return {"ok":false}
    if int(relation(target,source).trust)<0:return {"ok":false,"reason":"source_not_trusted"}
    var event="transfer/"+source+"/"+target+"/"+fact
    if event in data.social109.events:return {"ok":false}
    data.knowledge[target].append(fact)
    data.social109.ledger[target][fact]={"source":source,"channel":"conversation","kind":"reported","event":event}
    data.social109.events.append(event);data.social109.memories[source].append(event);data.social109.memories[target].append(event)
    return {"ok":true,"source":source,"target":target,"fact":fact,"event":event}
func known_profile109(npc: String) -> Dictionary:
    # Only testimony that actually reached the player. Names of hidden holders are absent.
    var result={"biography":[],"secrets":[],"events":[]}
    for fact in data.knowledge.player:
        var definition=config.facts[fact]
        if npc not in definition.get("subjects109",[]):continue
        var record=data.social109.ledger.player.get(fact,{})
        var entry={"id":fact,"detail":definition.get("label","Informação recebida."),"source":record.get("source","unknown"),"kind":"relato"}
        if definition.get("private",false):result.secrets.append(entry)
        else:result.biography.append(entry.detail)
    return result
