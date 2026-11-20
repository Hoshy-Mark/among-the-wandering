extends "res://personagem/social102.gd"
const ADDED_FACTS103=["gabriel_mechanic","gabriel_church_helper","josue_priest"]
func _init() -> void:
    learning_rules=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/aprendizado103.json"))

func _defaults() -> Dictionary:
    var result=super._defaults();result.content_revision103=1;return result

func validate(value: Variant) -> Dictionary:
    if value==null:return _defaults()
    if not value is Dictionary:return {}
    var migrated=value.duplicate(true)
    if migrated.has("content_revision103"):
        if not _integer(migrated.content_revision103,1,1):return {}
    else:
        # Add only the new canonical holders, never facts to the player.
        if not migrated.get("knowledge") is Dictionary:return {}
        for fact in ADDED_FACTS103:
            for holder in config.facts[fact].known_by:
                if not migrated.knowledge.get(holder) is Array:return {}
                if fact not in migrated.knowledge[holder]:migrated.knowledge[holder].append(fact)
    migrated.content_revision103=1
    return super.validate(migrated)
