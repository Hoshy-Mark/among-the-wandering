extends RefCounted
static func characters(manager: Node) -> Array:
    var rows=preload("res://personagem/menu107/projection.gd").characters(manager)
    if not manager.social.has_method("known_profile109"):return rows
    for row in rows:
        var learned=manager.social.known_profile109(row.id)
        for paragraph in learned.biography:
            if paragraph not in row.biography:row.biography.append(paragraph)
        for category in ["secrets","events"]:
            row[category]=[]
            for item in learned[category]:
                var source=item.source
                var name109=manager.registry.definitions[source].name if manager.registry.met.get(source,false) else "Fonte não identificada"
                row[category].append({"id":item.id,"detail":item.detail,"source":name109,"kind":item.kind})
    return rows
