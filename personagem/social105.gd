extends "res://personagem/social104.gd"
const ADDED_FACTS105=["farmer_food_production","farmer_born_arroio","farmer_cure_position","renata_public_identity","renata_married_doctor","pietra_religious","pietra_sister_josue","pietra_grows_herbs","ana_studied_sorriso","ana_samuel_niece"]
func _init() -> void:
    learning_rules=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/aprendizado105.json"))

func _defaults() -> Dictionary:
    var result=super._defaults();result.content_revision105=1;return result

func validate(value: Variant) -> Dictionary:
    if value==null:return _defaults()
    if not value is Dictionary:return {}
    var migrated=value.duplicate(true)
    if migrated.has("content_revision105"):
        if not _integer(migrated.content_revision105,1,1):return {}
    else:
        if not migrated.get("knowledge") is Dictionary:return {}
        for fact in ADDED_FACTS105:
            for holder in config.facts[fact].known_by:
                if not migrated.knowledge.get(holder) is Array:return {}
                if fact not in migrated.knowledge[holder]:migrated.knowledge[holder].append(fact)
    migrated.content_revision105=1
    return super.validate(migrated)
