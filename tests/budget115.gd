extends RefCounted
var checks=[]
func check(ok: bool,message: String) -> void:
    checks.append({"passed":ok,"message":message})
    if not ok:push_error(message)
func run(host: Node) -> Dictionary:
    var budget=load("res://personagem/visual_budget115.gd").new();budget.configure(137)
    var total=0.0;var advanced=0.0;var rng=RandomNumberGenerator.new();rng.seed=115
    for i in 2000:
        var delta=rng.randf_range(.004,.04);total+=delta
        var elapsed=budget.consume(delta,false)
        if elapsed>=0:advanced+=elapsed
        check(absf(advanced+budget.pending-total)<.000001 and budget.pending<.241,"distant clock conservation %d"%i)
    advanced+=budget.consume(0,true)
    check(absf(advanced-total)<.000001 and budget.pending==0,"approach immediately flushes accumulated time")
    for i in 120:check(absf(budget.consume(1.0/60,true)-1.0/60)<.000001,"nearby actors retain native tick %d"%i)
    var camera=Camera3D.new();host.add_child(camera)
    camera.global_position=Vector3.ZERO;camera.far=140;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=10
    var observer=Vector3(0,0,200)
    check(budget.full_rate(Vector3(0,0,-60),observer,camera),"distant visible actor stays full rate")
    check(not budget.full_rate(Vector3(100,0,-60),observer,camera),"offscreen distant actor is budgeted")
    check(budget.full_rate(Vector3(100,0,-60),observer,camera,true),"dialogue overrides distance and frustum")
    check(budget.full_rate(Vector3(100,0,-60),Vector3(100,0,-59),camera),"nearby offscreen actor stays full rate")
    check(budget.full_rate(Vector3(0,0,100),observer,null),"missing camera safely keeps native rate")
    camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=60
    for x in range(-150,151,3):
        var point=Vector3(x,0,-60)
        if camera.is_position_in_frustum(point+Vector3.UP):check(budget.full_rate(point,observer,camera),"perspective visible point %d"%x)
    camera.queue_free()
    var motor=load("res://personagem/motor_populacao98.gd").new()
    motor.set_meta("skip_setup97",true)
    motor.registry=load("res://personagem/registro98.gd").new()
    motor.config=JSON.parse_string(FileAccess.get_file_as_string("res://population97/populacao97.json"))
    check(motor.registry.configure(motor.config),"all fixed identities configure")
    motor.index_population();var ids=motor.registry.states.keys()
    for i in 600:
        var id=ids[rng.randi_range(0,ids.size()-1)];var state=motor.registry.states[id]
        var before=motor.point(state.position);var after=before+Vector3(rng.randf_range(-2,2),0,rng.randf_range(-2,2))
        var alive=rng.randf()>.18
        motor.sync_position115(id,before,state.mode!="dead",after,alive)
        state.position=motor.raw(after);state.mode="patrol" if alive else "dead"
        # Independent full rebuild verifies movement, death, resurrection and negative cells.
        var expected={}
        for other in ids:
            var s=motor.registry.states[other]
            if s.mode=="dead":continue
            var cell=Vector2i(floori(s.position[0]),floori(s.position[2]))
            if not expected.has(cell):expected[cell]=[]
            expected[cell].append(other)
        var actual={}
        for cell in motor.cells:
            if motor.cells[cell].is_empty():continue
            actual[cell]=motor.cells[cell].duplicate();actual[cell].sort()
        for cell in expected:expected[cell].sort()
        check(actual==expected,"incremental spatial index equals rebuild %d"%i)
    check(motor.registry.states.size()==480,"index budgeting preserves 480 identities")
    motor.free()
    return {"passed":checks.all(func(v):return v.passed),"checks":checks}
