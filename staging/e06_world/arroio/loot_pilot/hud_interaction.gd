extends RefCounted
var pilot:Node
var pending_id=""
func has_interaction()->bool:return pilot.hud!=null and pilot.hud.nearby.visible
func close_interaction(_hide:bool=true):
	if pilot.hud!=null:pilot.hud.nearby_wanted=false;pilot.hud.refresh()
