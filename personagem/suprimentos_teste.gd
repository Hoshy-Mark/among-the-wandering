extends RefCounted

var stock: Dictionary = {}
var effects: Dictionary = {}


func _init() -> void:
    refill()


func refill() -> void:
    stock = {"eat": 3, "drink": 3, "medicine": 3, "bandage": 3}
    effects = {"eat": 0, "drink": 0, "medicine": 0, "bandage": 0}


func apply(kind: String, expected_stock: int) -> bool:
    if not stock.has(kind) or expected_stock <= 0 or stock[kind] != expected_stock:
        return false
    stock[kind] -= 1
    effects[kind] += 1
    return true
