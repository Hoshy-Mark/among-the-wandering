extends "res://personagem/personagens104.gd"
func _init() -> void:
    encounter_catalog_path99="res://personagem/personagens105.json"
    social_catalog_path101="res://personagem/dialogos105.json"
    social_model_path102="res://personagem/social105.gd"

func public_role105(id: String) -> String:
    return str(config.get("presentation105",{}).get(id,{}).get("public_role",registry.definitions[id].role))

func _process(delta: float) -> void:
    super._process(delta)
    if prompt!=null and prompt.visible and not nearest.is_empty() and not registry.met[nearest]:
        prompt.text="E · Conversar com "+public_role105(nearest).to_lower()
