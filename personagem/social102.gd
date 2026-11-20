extends "res://personagem/social101.gd"
var learning_rules=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/aprendizado102.json"))

func configure(catalog: Dictionary,ids: Array) -> bool:
    if not super.configure(catalog,ids):return false
    if learning_rules.get("version")!=1 or not _integer(learning_rules.get("experiences_per_point"),1,100) or learning_rules.get("max_rank")!=6:return false
    var seen=[]
    for skill in learning_rules.trainable:
        if not config.skills.has(skill) or skill in seen:return false
        seen.append(skill)
    var sources=[]
    for id in learning_rules.activities:
        var activity=learning_rules.activities[id];var npc=activity.get("npc")
        if npc not in actor_ids or not config.dialogues.has(npc):return false
        var source=""
        if activity.has("check"):
            if not config.checks.has(activity.check) or config.checks[activity.check].npc!=npc:return false
            source=npc+"/check/"+activity.check
        elif activity.has("visited"):
            var parts=str(activity.visited).split("/")
            if parts.size()!=2 or not config.dialogues[npc].nodes.has(parts[0]):return false
            if not config.dialogues[npc].nodes[parts[0]].options.any(func(option):return option.id==parts[1]):return false
            source=npc+"/visited/"+activity.visited
        else:return false
        if source in sources:return false
        sources.append(source)
    return true

func _defaults() -> Dictionary:
    var result=super._defaults();result.version=2;result.learning102=_new_learning(result)
    return result

func _eligible(value: Dictionary) -> Array:
    var earned=[]
    for id in learning_rules.activities:
        var activity=learning_rules.activities[id];var progress=value.progress[activity.npc]
        if activity.has("visited") and activity.visited in progress.visited:earned.append(id)
        elif activity.has("check") and not progress.checks.get(activity.check,[]).is_empty():earned.append(id)
    earned.sort();return earned

func _new_learning(value: Dictionary) -> Dictionary:
    var spent={}
    for skill in config.skills:spent[skill]=0
    return {"earned":_eligible(value),"baseline":value.skills.duplicate(true),"spent":spent}

func validate(value: Variant) -> Dictionary:
    if value==null:return _defaults()
    if not value is Dictionary or not _integer(value.get("version"),1,2):return {}
    var old=int(value.version)==1
    if old and value.has("learning102"):return {}
    var base=value.duplicate(true);base.version=1;base.erase("learning102")
    var checked=super.validate(base)
    if checked.is_empty():return {}
    checked.version=2
    if old:checked.learning102=_new_learning(checked);return checked
    var learning=value.get("learning102")
    if not learning is Dictionary or not learning.get("earned") is Array or not learning.get("baseline") is Dictionary or not learning.get("spent") is Dictionary:return {}
    if learning.baseline.size()!=config.skills.size() or learning.spent.size()!=config.skills.size():return {}
    var eligible=_eligible(checked);var seen=[]
    for id in learning.earned:
        if not id is String or id not in eligible or id in seen:return {}
        seen.append(id)
    var spent_total=0;var normalized={"earned":eligible,"baseline":{},"spent":{}}
    for skill in config.skills:
        if not _integer(learning.baseline.get(skill),0,6) or not _integer(learning.spent.get(skill),0,6):return {}
        var start=int(learning.baseline[skill]);var used=int(learning.spent[skill])
        if start+used!=int(checked.skills[skill]) or start+used>6:return {}
        if used>0 and skill not in learning_rules.trainable:return {}
        normalized.baseline[skill]=start;normalized.spent[skill]=used;spent_total+=used
    if spent_total>floori(float(eligible.size())/int(learning_rules.experiences_per_point)):return {}
    checked.learning102=normalized;return checked

func available_points() -> int:
    var learning=data.learning102;var spent_total=0
    for used in learning.spent.values():spent_total+=int(used)
    return floori(float(learning.earned.size())/int(learning_rules.experiences_per_point))-spent_total

func experience_progress() -> int:return data.learning102.earned.size()%int(learning_rules.experiences_per_point)

func train(skill: String) -> bool:
    if not active.is_empty() or skill not in learning_rules.trainable or available_points()<=0 or int(data.skills[skill])>=6:return false
    data.skills[skill]=int(data.skills[skill])+1;data.learning102.spent[skill]=int(data.learning102.spent[skill])+1
    return true

func choose(npc: String,token: String,exit_allowed: bool=true) -> Dictionary:
    var before=available_points();var result=super.choose(npc,token,exit_allowed)
    if not result.ok:return result
    data.learning102.earned=_eligible(data)
    result.learning_points_awarded=available_points()-before
    return result
