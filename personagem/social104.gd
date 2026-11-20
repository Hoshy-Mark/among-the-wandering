extends "res://personagem/social103.gd"
const ADDED_FACTS104=["jorge_police","jorge_confinement_rules","ricardo_doctor","ricardo_from_sorriso","ricardo_helped_confinement"]
func _init() -> void:
    learning_rules=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/aprendizado104.json"))

func _defaults() -> Dictionary:
    var result=super._defaults();result.content_revision104=1;return result

func validate(value: Variant) -> Dictionary:
    if value==null:return _defaults()
    if not value is Dictionary:return {}
    var migrated=value.duplicate(true)
    if migrated.has("content_revision104"):
        if not _integer(migrated.content_revision104,1,1):return {}
    else:
        if not migrated.get("knowledge") is Dictionary:return {}
        for fact in ADDED_FACTS104:
            for holder in config.facts[fact].known_by:
                if not migrated.knowledge.get(holder) is Array:return {}
                if fact not in migrated.knowledge[holder]:migrated.knowledge[holder].append(fact)
    migrated.content_revision104=1
    return super.validate(migrated)
