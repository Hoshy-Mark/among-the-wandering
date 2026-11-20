extends RefCounted
var state="idle"
var action_id="access"
func busy()->bool:return false
func cancel()->bool:return true
