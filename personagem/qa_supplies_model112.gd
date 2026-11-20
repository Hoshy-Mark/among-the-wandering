extends SceneTree
var count112=0
func expect(value: bool,message: String) -> void:
    assert(value,message);count112+=1
func _initialize() -> void:
    var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://qa/social109/checkpoint.json"))
    var bag=load("res://personagem/inventario69.gd").new()
    for id in fixture.inventory.world_containers:
        if fixture.inventory.world_containers[id].has("furniture"):bag.house_anchors[id]=fixture.inventory.world_containers[id].duplicate(true)
    expect(bag.restore(fixture.inventory,false),"real inventory fixture restores")
    var service=load("res://personagem/abastecimento112.gd").new();var recipe=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/demo_supplies112.json"))
    var before=bag.snapshot();var emitted=[0];bag.changed.connect(func():emitted[0]+=1)
    var prepared=service.prepare(bag,recipe)
    expect(prepared.ok,"all authored supplies fit real source grids")
    expect(bag.snapshot()==before and emitted[0]==0,"prepare never mutates or emits live state")
    var shadow=bag.get_script().new();shadow.house_anchors=bag.house_anchors.duplicate(true);expect(shadow.restore(prepared.inventory,false),"staged data validates independently")
    expect(shadow.world_containers.values().all(func(entry):return entry.has("furniture")),"new game has only physical source anchors")
    for id in ["world:weapons86","world:firearms87","world:arsenal92"]:expect(not shadow.world_containers.has(id),"no laboratory floor cache "+id)
    for definition in ["baton","metal_bar","pistol","revolver","carbine"]:
        var items=shadow.items.values().filter(func(item):return item.definition==definition)
        expect(items.size()==1 and shadow.world_containers[items[0].location].has("furniture"),"single physical weapon source "+definition)
    for pair in [["ammo_pistol",18],["ammo_carbine",16],["food",4],["water",1],["medicine",2],["bandage",3]]:
        var sum112=0
        for item in shadow.items.values():
            if item.definition==pair[0]:sum112+=int(item.count)
        expect(sum112==pair[1],"finite total "+pair[0])
    for slot in ["shirt","pants","boots","belt"]:expect(shadow.equipped(slot)==bag.equipped(slot),"equipped identity retained "+slot)
    var invalid=recipe.duplicate(true);invalid.loot[-1].items.append({"definition":"not_in_catalog","count":1,"x":0,"y":1})
    expect(not service.prepare(bag,invalid).ok and bag.snapshot()==before and emitted[0]==0,"late failure cannot partially wipe campaign")
    invalid=recipe.duplicate(true);invalid.pockets[0].count=1.5;expect(not service.prepare(bag,invalid).ok,"fractional counts rejected")
    invalid=recipe.duplicate(true);invalid.loot.append(invalid.loot[0].duplicate(true));expect(not service.prepare(bag,invalid).ok,"duplicate source rejected")
    invalid=recipe.duplicate(true);invalid.loot[0].items[1].x=0;invalid.loot[0].items[1].y=0;expect(not service.prepare(bag,invalid).ok,"overlap rejected without auto packing")
    invalid=recipe.duplicate(true);invalid.loot[-1].furniture="missing";expect(not service.prepare(bag,invalid).ok,"unknown physical source rejected")
    expect(service.commit(bag,prepared) and emitted[0]==0,"commit publishes complete valid data without intermediate signals")
    expect(bag.snapshot()==shadow.snapshot(),"committed state matches staged inventory exactly")
    expect(not service.commit(bag,{"ok":false}) and bag.snapshot()==shadow.snapshot(),"failed commit preserves state")
    var legacy=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/demo_h01_73.json"));expect(service.prepare(bag,legacy).ok,"historical lab recipe remains supported")
    print("R112_MODEL_OK ",count112);quit()
