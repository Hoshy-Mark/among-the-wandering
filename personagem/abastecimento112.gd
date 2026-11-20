extends RefCounted
## Stage an entire new campaign inventory. No writes/signals reach the live model.
func integer(value: Variant,minimum: int=0) -> bool:
    return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=minimum and value<1000000
func prepare(source: RefCounted,recipe: Variant) -> Dictionary:
    if not recipe is Dictionary or not recipe.get("pockets") is Array or not recipe.get("loot") is Array:return {"ok":false,"reason":"Formato de abastecimento inválido."}
    var staged=source.get_script().new();staged.catalog=source.catalog.duplicate(true);staged.house_anchors=source.house_anchors.duplicate(true);staged.actor_position=source.actor_position
    for uid in source.items:
        var entry=source.items[uid]
        if entry.location in ["slot:shirt","slot:pants","slot:boots","slot:belt"]:staged.items[uid]=entry.duplicate(true)
    staged.world_containers=staged.house_anchors.duplicate(true);staged.next_id=1
    for uid in staged.items:staged.next_id=maxi(staged.next_id,int(str(uid).trim_prefix("item_"))+1)
    var rows=[{"location":"pockets","items":recipe.pockets}];var seen=[]
    for container in recipe.loot:
        if not container is Dictionary or not container.get("furniture") is String or not container.get("items") is Array:return {"ok":false,"reason":"Fonte inicial inválida."}
        var id="world:arroio:"+container.furniture
        if id in seen or not staged.house_anchors.has(id):return {"ok":false,"reason":"Fonte ausente ou duplicada: "+id}
        seen.append(id);rows.append({"location":id,"items":container.items})
    for row in rows:
        for item in row.items:
            if not item is Dictionary or not item.get("definition") is String or not integer(item.get("count"),1) or not integer(item.get("x")) or not integer(item.get("y")) or not item.get("rot",false) is bool:return {"ok":false,"reason":"Item inicial inválido em "+row.location}
            if staged.add_at(item.definition,int(item.count),row.location,int(item.x),int(item.y),bool(item.get("rot",false))).is_empty():return {"ok":false,"reason":"Item sem espaço ou inválido: "+item.definition+" em "+row.location}
    staged.seeding=false
    if not staged.valid(staged.items):return {"ok":false,"reason":"Inventário inicial inconsistente."}
    return {"ok":true,"inventory":staged.snapshot(),"source_count":seen.size(),"item_instances":staged.items.size()}
func commit(source: RefCounted,prepared: Dictionary) -> bool:
    if not prepared.get("ok",false) or not prepared.get("inventory") is Dictionary:return false
    var previous=source.snapshot()
    if not source.restore(prepared.inventory,false):source.restore(previous,false);return false
    source.seeding=false;return true
