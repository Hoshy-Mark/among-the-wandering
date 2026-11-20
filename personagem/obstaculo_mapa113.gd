extends "res://personagem/obstaculo_mapa77.gd"
var mirrored113=false
func prepare(actor: Node3D) -> bool:
    if not super.prepare(actor):return false
    if mirrored113:variant+="_mirror"
    return true
