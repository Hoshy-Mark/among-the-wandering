extends RefCounted
## Read-only projection: never expose raw relations, private actors or unknown facts.
static func characters(manager: Node) -> Array:
    var rows=[]
    for id in manager.registry.met:
        if not manager.registry.met[id]:continue
        var row={"id":id,"name":manager.registry.definitions[id].name,"life":"Vivo · último encontro","bond":"Conhecido","biography":[],"secrets":[],"events":[],"relationship":{}}
        for dimension in ["Amizade","Confiança","Respeito","Medo","Ressentimento","Romance"]:row.relationship[dimension]=null
        for fact in manager.social.data.knowledge.player:
            var definition=manager.social.config.facts[fact]
            # Stable editorial subjects, rather than known_by (which can reveal holders).
            var subjects={"samuel_returned":["samuel_henrique"],"gabriel_mechanic":["gabriel_pimenta"],"gabriel_church_helper":["gabriel_pimenta"],"josue_priest":["josue_medeira"],"jorge_police":["jorge_luiz"],"jorge_confinement_rules":["jorge_luiz"],"ricardo_doctor":["ricardo_medeiro"],"ricardo_from_sorriso":["ricardo_medeiro"],"ricardo_helped_confinement":["ricardo_medeiro"],"farmer_food_production":["ricardo_alberto"],"farmer_born_arroio":["ricardo_alberto"],"farmer_cure_position":["ricardo_alberto"],"renata_public_identity":["renata_volker"],"renata_married_doctor":["renata_volker","ricardo_medeiro"],"pietra_religious":["pietra_dos_santos"],"pietra_sister_josue":["pietra_dos_santos","josue_medeira"],"pietra_grows_herbs":["pietra_dos_santos"],"ana_studied_sorriso":["ana_julia"],"ana_samuel_niece":["ana_julia","samuel_henrique"]}
            if id in subjects.get(fact,[]) and definition.has("label"):
                row.biography.append(definition.label)
        rows.append(row)
    return rows
