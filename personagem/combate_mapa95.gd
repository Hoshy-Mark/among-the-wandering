extends "res://personagem/combate_mapa92.gd"
func ready_to_act() -> bool:
    var demo=scene.player.get_node_or_null("Demo95") if scene!=null else null
    return (demo==null or demo.state=="alive") and super.ready_to_act()
func receive(event: Dictionary) -> bool:
    var demo=scene.player.get_node_or_null("Demo95")
    if demo!=null and (demo.state!="alive" or demo.grace>0):return false
    if not super.receive(event):return false
    if demo!=null:demo.accepted_damage()
    return true
