extends RefCounted
## Authoritative, synchronous dialogue transactions. No UI or inventory authority.
var config={}
var data={}
var actor_ids=[]
var active=""
var node=""
var generation=0

func configure(catalog: Dictionary,ids: Array) -> bool:
    if catalog.get("version")!=1 or not catalog.get("dialogues") is Dictionary or not catalog.get("dimensions") is Dictionary:return false
    config=catalog.duplicate(true);actor_ids=ids.duplicate();actor_ids.sort()
    if actor_ids.size()!=9 or config.characters.keys().size()!=9:return false
    for id in actor_ids:
        if not config.characters.has(id):return false
    for npc in config.dialogues:
        if npc not in actor_ids:return false
        var graph=config.dialogues[npc]
        if not graph.nodes.has(graph.start):return false
        for key in graph.nodes:
            for option in graph.nodes[key].options:
                for target in [option.get("target",""),option.get("success",""),option.get("failure","")]:
                    if target!="" and not graph.nodes.has(target):return false
                if option.has("check") and not config.checks.has(option.check):return false
    data=_defaults();return true

func _defaults() -> Dictionary:
    var result={"version":1,"skills":{},"relations":{},"knowledge":{},"progress":{}}
    var rng=RandomNumberGenerator.new();rng.randomize();result.rng_state=str(rng.state)
    for id in config.skills:result.skills[id]=int(config.skills[id].initial)
    for id in actor_ids+["player"]:result.knowledge[id]=[]
    for fact in config.facts:
        for id in config.facts[fact].known_by:result.knowledge[id].append(fact)
    for id in actor_ids:
        result.relations[id+">player"]=_zero_relation();result.relations["player>"+id]=_zero_relation()
        result.progress[id]={"visited":[],"flags":{},"checks":{}}
    return result

func _zero_relation() -> Dictionary:
    var result={}
    for key in config.dimensions:result[key]=0
    return result

func relation(source: String,target: String) -> Dictionary:
    return data.relations.get(source+">"+target,{}).duplicate(true)
func knows(actor: String,fact: String) -> bool:return data.knowledge.get(actor,[]).has(fact)
func snapshot() -> Dictionary:return data.duplicate(true)
func _integer(value: Variant,minimum: int,maximum: int) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=minimum and value<=maximum

func validate(value: Variant) -> Dictionary:
    if value==null:return _defaults()
    if not value is Dictionary or not _integer(value.get("version"),1,1):return {}
    for key in ["skills","relations","knowledge","progress"]:
        if not value.get(key) is Dictionary:return {}
    if not value.get("rng_state") is String:return {}
    var rng_text: String=value.rng_state
    if rng_text.length()>20 or not rng_text.is_valid_int() or str(int(rng_text))!=rng_text:return {}
    if value.skills.size()!=config.skills.size():return {}
    for id in config.skills:
        if not _integer(value.skills.get(id),0,6):return {}
    if value.relations.size()>90:return {}
    for edge in value.relations:
        if not edge is String:return {}
        var pair=edge.split(">")
        if pair.size()!=2 or pair[0]==pair[1] or pair[0] not in actor_ids+["player"] or pair[1] not in actor_ids+["player"]:return {}
        var scores=value.relations[edge]
        if not scores is Dictionary or scores.size()!=config.dimensions.size():return {}
        for dimension in config.dimensions:
            var limits=config.dimensions[dimension]
            if not _integer(scores.get(dimension),limits[0],limits[1]):return {}
    for id in actor_ids:
        if not value.relations.has(id+">player") or not value.relations.has("player>"+id):return {}
    if value.knowledge.size()!=actor_ids.size()+1 or value.progress.size()!=actor_ids.size():return {}
    for id in actor_ids+["player"]:
        var facts=value.knowledge.get(id)
        if not facts is Array or facts.size()>config.facts.size():return {}
        var seen=[]
        for fact in facts:
            if not fact is String or not config.facts.has(fact) or fact in seen:return {}
            seen.append(fact)
        for fact in config.facts:
            if id in config.facts[fact].known_by and fact not in facts:return {}
    for npc in actor_ids:
        var progress=value.progress.get(npc)
        if not progress is Dictionary or not progress.get("visited") is Array or not progress.get("flags") is Dictionary or not progress.get("checks") is Dictionary:return {}
        var allowed=[]
        if config.dialogues.has(npc):
            for key in config.dialogues[npc].nodes:
                for option in config.dialogues[npc].nodes[key].options:allowed.append(key+"/"+option.id)
        var seen=[]
        for visited in progress.visited:
            if not visited is String or visited not in allowed or visited in seen:return {}
            seen.append(visited)
        for flag in progress.flags:
            if flag not in config.flags or not progress.flags[flag] is bool:return {}
        for id in progress.checks:
            if not config.checks.has(id) or config.checks[id].npc!=npc:return {}
            var attempts=progress.checks[id]
            if not attempts is Array or attempts.is_empty() or attempts.size()>100:return {}
            if config.checks[id].retry=="once" and attempts.size()!=1:return {}
            var previous={}
            for record in attempts:
                if not record is Dictionary or not record.get("dice") is Array or record.dice.size()!=2:return {}
                if not _integer(record.dice[0],1,6) or not _integer(record.dice[1],1,6) or not _integer(record.get("score"),-30,30) or not _integer(record.get("difficulty"),1,40):return {}
                if not record.get("success") is bool or record.success!=resolve_roll(record.dice[0],record.dice[1],record.score,record.difficulty):return {}
                if not _integer(record.get("chance"),1,35) or record.chance!=chance(record.score,record.difficulty):return {}
                if not record.get("context") is Array:return {}
                var modifiers=[]
                for modifier in config.checks[id].modifiers:modifiers.append(modifier.id)
                var used=[]
                for modifier in record.context:
                    if modifier not in modifiers or modifier in used:return {}
                    used.append(modifier)
                if not previous.is_empty() and (previous.success or record.score<=previous.score):return {}
                previous=record
    var normalized=value.duplicate(true)
    normalized.version=1
    for id in normalized.skills:normalized.skills[id]=int(normalized.skills[id])
    for edge in normalized.relations:
        for dimension in normalized.relations[edge]:normalized.relations[edge][dimension]=int(normalized.relations[edge][dimension])
    for npc in normalized.progress:
        for id in normalized.progress[npc].checks:
            for record in normalized.progress[npc].checks[id]:
                record.dice=[int(record.dice[0]),int(record.dice[1])]
                record.score=int(record.score);record.difficulty=int(record.difficulty);record.chance=int(record.chance)
    return normalized

func restore(value: Variant) -> bool:
    var checked=validate(value)
    if checked.is_empty():return false
    data=checked;end();return true

func begin(npc: String) -> bool:
    if not active.is_empty() or not config.dialogues.has(npc):return false
    active=npc;node=config.dialogues[npc].start;generation+=1;return true
func end() -> void:active="";node="";generation+=1
func current_line() -> Dictionary:
    if active.is_empty():return {}
    var current=config.dialogues[active].nodes[node]
    return {"text":current.line,"kind":current.get("kind","npc")}

func factors(npc: String,id: String) -> Dictionary:
    var definition=config.checks[id];var score=int(data.skills[definition.skill]);var modifiers=[]
    var progress=data.progress[npc];var relation_to_player=relation(npc,"player")
    for modifier in definition.modifiers:
        var applies=false
        if modifier.has("flag"):applies=progress.flags.get(modifier.flag,false)
        elif modifier.has("check_success"):
            var attempts=progress.checks.get(modifier.check_success,[])
            applies=not attempts.is_empty() and attempts.back().success
        elif modifier.has("relation"):applies=relation_to_player[modifier.relation]>=int(modifier.minimum)
        if applies:score+=int(modifier.value);modifiers.append(modifier.duplicate(true))
    return {"score":score,"modifiers":modifiers,"skill":definition.skill,"difficulty":int(definition.difficulty),"chance":chance(score,int(definition.difficulty))}

func resolve_roll(a: int,b: int,score: int,difficulty: int) -> bool:
    if a==1 and b==1:return false
    if a==6 and b==6:return true
    return a+b+score>=difficulty
func chance(score: int,difficulty: int) -> int:
    var successes=0
    for a in range(1,7):
        for b in range(1,7):
            if resolve_roll(a,b,score,difficulty):successes+=1
    return successes

func _description(npc: String,key: String,option: Dictionary,exit_allowed: bool) -> Dictionary:
    var row={"option_id":option.id,"text":option.text,"state":"available","available":true,"reason":""}
    var progress=data.progress[npc];var visited=key+"/"+option.id in progress.visited and not option.get("exit",false) and option.id!="back"
    if option.get("exit",false) and not exit_allowed:row.state="locked";row.available=false;row.reason="Não é possível encerrar agora."
    if option.has("learn") and not knows(npc,option.learn):row.state="hidden";row.available=false
    if option.has("learn") and config.facts[option.learn].get("private",false):
        if not option.has("disclosure_flag") or not progress.flags.get(option.disclosure_flag,false):row.state="hidden";row.available=false
    if option.has("requires_fact") and not knows("player",option.requires_fact):
        row.state="hidden" if option.get("hide_unmet",false) else "locked";row.available=false;row.reason="Ainda falta uma informação."
    for dimension in option.get("requires_relations",{}):
        if relation(npc,"player")[dimension]<int(option.requires_relations[dimension]):row.state="locked";row.available=false;row.reason="Requer mais confiança e proximidade."
    if row.state=="hidden":return row
    if visited:row.state="visited" if row.available else row.state
    if visited and option.get("once",false):row.state="exhausted";row.available=false;row.reason="Esse assunto já foi conversado."
    if option.has("check"):
        var info=factors(npc,option.check);row.merge(info);row.check=option.check
        var attempts=progress.checks.get(option.check,[])
        if not attempts.is_empty():
            if attempts.back().success:row.state="exhausted";row.available=false;row.reason="Concluído."
            elif config.checks[option.check].retry=="once":row.state="exhausted";row.available=false;row.reason="Esta tentativa já foi resolvida."
            elif info.score<=int(attempts.back().score):row.state="locked";row.available=false;row.reason="Uma nova tentativa exige melhorar as condições."
        if row.available:row.state="check"
    return row

func options(exit_allowed: bool=true) -> Array:
    var rows=[]
    if active.is_empty():return rows
    for option in config.dialogues[active].nodes[node].options:
        var row=_description(active,node,option,exit_allowed)
        if row.state=="hidden":continue
        row.id=str(generation)+":"+node+":"+option.id;rows.append(row)
    return rows

func _apply(npc: String,definition: Dictionary) -> void:
    var progress=data.progress[npc]
    if definition.has("flag"):
        if progress.flags.get(definition.flag,false):return
        progress.flags[definition.flag]=true
    if definition.has("learn") and knows(npc,definition.learn) and not knows("player",definition.learn):
        var private_fact=config.facts[definition.learn].get("private",false)
        var authorized=definition.has("disclosure_flag") and progress.flags.get(definition.disclosure_flag,false)
        if not private_fact or authorized:data.knowledge.player.append(definition.learn)
    var edge=npc+">player"
    for dimension in definition.get("effects",{}):
        var limits=config.dimensions[dimension]
        data.relations[edge][dimension]=clampi(int(data.relations[edge][dimension])+int(definition.effects[dimension]),limits[0],limits[1])

func choose(npc: String,token: String,exit_allowed: bool=true) -> Dictionary:
    if npc!=active or active.is_empty():return {"ok":false}
    var selected={}
    for row in options(exit_allowed):
        if row.id==token:selected=row;break
    if selected.is_empty() or not selected.available:return {"ok":false}
    var definition={}
    for option in config.dialogues[active].nodes[node].options:
        if option.id==selected.option_id:definition=option;break
    if definition.is_empty():return {"ok":false}
    var visited=node+"/"+definition.id;var target=str(definition.get("target",node))
    var result={"ok":true,"player_text":definition.text,"exit":bool(definition.get("exit",false)),"check_result":{}}
    if definition.has("check"):
        var id=str(definition.check);var info=factors(npc,id);var rng=RandomNumberGenerator.new();rng.state=int(data.rng_state)
        var a=rng.randi_range(1,6);var b=rng.randi_range(1,6);var success=resolve_roll(a,b,info.score,info.difficulty)
        var context=[]
        for modifier in info.modifiers:context.append(modifier.id)
        var record={"dice":[a,b],"score":info.score,"difficulty":info.difficulty,"chance":info.chance,"context":context,"success":success}
        if not data.progress[npc].checks.has(id):data.progress[npc].checks[id]=[]
        data.progress[npc].checks[id].append(record);data.rng_state=str(rng.state)
        result.check_result=record.duplicate(true);result.check_result.skill_label=config.skills[info.skill].label
        target=definition.success if success else definition.failure
    if not definition.get("exit",false) and definition.id!="back" and visited not in data.progress[npc].visited:data.progress[npc].visited.append(visited)
    _apply(npc,definition)
    generation+=1
    if not result.exit:
        node=target;var current=config.dialogues[npc].nodes[node]
        if current.has("on_enter"):_apply(npc,current.on_enter)
        result.line=current_line()
    return result
