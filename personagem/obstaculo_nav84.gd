extends "res://personagem/obstaculo_zumbi83.gd"
func available() -> bool:
    return is_instance_valid(source)
