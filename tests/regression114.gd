extends RefCounted
func run(game: Node3D) -> bool:
    load("res://personagem/revisao98.gd").new()._freeze98(game)
    var p=game.player;var compare=load("res://personagem/revisao81.gd").new()
    var expected=p.bag_inventory.snapshot();var social=game.get_node("Characters99").social.snapshot()
    p.condition_path="res://qa/performance114/roundtrip.json"
    var checks=[]
    checks.append({"passed":p.save_condition(),"message":"optimized campaign saves"})
    checks.append({"passed":p.load_condition(),"message":"optimized campaign reloads"})
    checks.append({"passed":compare._same(expected,p.bag_inventory.snapshot()) and compare._same(social,game.get_node("Characters99").social.snapshot()),"message":"manual inventory and social data survive round trip"})
    p.condition_path="res://tests/fixtures114/publication_r112.json"
    checks.append({"passed":p.load_condition(),"message":"previous R112 campaign remains loadable"})
    p.condition_path="res://qa/performance114/roundtrip.json"
    checks.append({"passed":p.load_condition(),"message":"current campaign restores after legacy load"})
    var interactions=await load("res://tests/interactions113.gd").new().run(game)
    var guards=await load("res://tests/interaction_guards113.gd").new().run(game)
    var result={"passed":checks.all(func(v):return v.passed) and interactions.passed and guards.passed,"save_checks":checks,"interaction_checks":interactions.checks.size(),"guard_checks":guards.checks.size()}
    FileAccess.open("res://qa/performance114/regression.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("REGRESSION114 ",JSON.stringify(result));return result.passed
