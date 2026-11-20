extends "res://personagem/revisao75.gd"
func run(scene: Node3D) -> void:
    var p=scene.player
    var c=p.map_combat
    p.scripted=true
    p.set_physics_process(false)
    scene.get_window().size=Vector2i(1440,900)
    var point=scene.world_items.house.home.model.to_global(Vector3(2.86,.01,-7))
    var ray=PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1)
    var floor=scene.get_world_3d().direct_space_state.intersect_ray(ray)
    assert(not floor.is_empty())
    point.y=floor.position.y+.01
    p.global_position=point
    p.avatar.rotation.y=0
    var target=load("res://personagem/alvo_contrato79.gd").new()
    scene.add_child(target)
    target.global_position=point+Vector3.BACK*.7
    await scene.get_tree().physics_frame
    await scene.get_tree().physics_frame
    p.scripted=false
    _key(KEY_Q)
    assert(p.combat.guarding)
    _key(KEY_F)
    assert(p.combat.is_attacking())
    p.scripted=true
    p.combat.advance(3)
    p.combat.set_guard(false)
    p.scripted=false
    _key(KEY_SPACE)
    assert(p.combat.is_attacking())
    p.scripted=true
    p.combat.advance(3)
    p.combat.set_guard(false)
    var cases=[]
    for fps in [30,60,120]:
        for kind in ["punch","push"]:
            p.combat.set_guard(false)
            p.condition_state.set_stamina(100)
            var before=target.events.size()
            assert(p.request_attack(kind))
            assert(not p.request_attack(kind))
            assert(not p.save_condition())
            for frame in fps*2:p.combat.advance(1.0/fps)
            assert(target.events.size()==before+1)
            p.combat.advance(10)
            assert(target.events.size()==before+1)
            assert(is_equal_approx(p.condition_state.stamina,100-c.costs[kind]))
            cases.append({"fps":fps,"kind":kind})
    p.combat.set_guard(false)
    target.global_position=point+Vector3.BACK*.7
    assert(p.request_attack("punch"))
    var number=target.events.size()
    target.global_position+=Vector3.BACK*2
    var alternative=load("res://personagem/alvo_contrato79.gd").new()
    scene.add_child(alternative)
    alternative.global_position=point+Vector3.BACK*.7
    await scene.get_tree().physics_frame
    p.combat.advance(3)
    assert(target.events.size()==number and not p.combat.effect_succeeded and alternative.events.is_empty())
    alternative.queue_free()
    await scene.get_tree().physics_frame
    p.combat.set_guard(false)
    target.global_position=point+Vector3.FORWARD*.7
    await scene.get_tree().physics_frame
    assert(p.request_attack("punch"))
    p.combat.advance(3)
    assert(target.events.size()==number)
    p.combat.set_guard(false)
    target.global_position=point+Vector3.BACK*.7
    var blocker=_blocker(scene,point+Vector3.BACK*.35+Vector3.UP*1.15)
    blocker.get_child(0).shape.size=Vector3(.6,1.8,.1)
    await scene.get_tree().physics_frame
    assert(p.request_attack("punch"))
    p.combat.advance(3)
    assert(target.events.size()==number)
    p.combat.set_guard(false)
    blocker.queue_free()
    await scene.get_tree().physics_frame
    assert(p.request_attack("punch"))
    blocker=_blocker(scene,point+Vector3.BACK*.35+Vector3.UP*1.15)
    blocker.get_child(0).shape.size=Vector3(.6,1.8,.1)
    await scene.get_tree().physics_frame
    p.combat.advance(3)
    assert(target.events.size()==number)
    p.combat.set_guard(false)
    blocker.queue_free()
    await scene.get_tree().physics_frame
    assert(p.request_attack("punch"))
    p.combat.advance(.03)
    p.combat.cancel()
    p.combat.advance(3)
    assert(target.events.size()==number)
    p.combat.set_guard(false)
    target.global_position=point+Vector3.BACK*.7
    assert(p.request_attack("punch"))
    target.queue_free()
    await scene.get_tree().physics_frame
    p.combat.advance(3)
    assert(not p.combat.effect_succeeded)
    target=load("res://personagem/alvo_contrato79.gd").new()
    scene.add_child(target)
    target.global_position=point+Vector3.BACK*.7
    await scene.get_tree().physics_frame
    p.combat.set_guard(false)
    p.condition_state.set_stamina(0)
    assert(not p.request_attack())
    p.condition_state.set_stamina(100)
    p.hud_open=true
    assert(not p.request_attack() and not p.toggle_guard())
    p.hud_open=false
    assert(p.toggle_guard())
    assert(p.request_attack())
    p.combat.advance(.02)
    var event={"id":"qa79_damage","zone":"forearm_left","kind":"cut","amount":.2,"source_position":point+Vector3.BACK}
    assert(p.receive_combat_hit(event))
    assert(p.body_health.records.has(event.id) and p.condition_state.forearm_injury>0)
    assert(not p.receive_combat_hit(event))
    assert(not p.combat.guarding and not p.combat.is_attacking() and p.reaction.is_active())
    assert(target.events.is_empty())
    p.reaction.reset()
    var before=p.body_health.snapshot()
    var invalid=event.duplicate(true)
    invalid.id="qa79_invalid";invalid.amount=NAN
    assert(not p.receive_combat_hit(invalid) and p.body_health.snapshot()==before)
    p.traversal.state="align"
    invalid=event.duplicate(true);invalid.id="qa79_deferred";invalid.zone="shin_left";invalid.source_position=point+p.avatar.global_basis*Vector3.LEFT
    assert(p.receive_combat_hit(invalid) and not p.reaction.is_active() and c.pending_reaction=="hit_right")
    p.traversal.state="idle"
    c._react()
    assert(p.reaction.is_active() and c.pending_reaction.is_empty())
    p.reaction.reset()
    if "--capture-combat-map" in OS.get_cmdline_user_args():
        scene.set_process(false)
        p.condition_state.set_stamina(100)
        scene.camera.size=3.5
        scene.camera.global_position=point+Vector3(-4,3,5)
        scene.camera.look_at(point+Vector3.UP*.9)
        for index in 2:
            p.combat.set_guard(false)
            assert(p.request_attack("punch" if index==0 else "push"))
            for frame in 32:
                p.combat.advance(.05)
                await _capture79(scene,"%d/%02d"%[index,frame])
    var result={"cases":cases,"effect_once":true,"reach_rechecked_at_impact":true,"facing":true,"wall_blocks":true,"cancel_before_impact":true,"no_stamina":true,"hud_blocks":true,"zone_damage":true,"duplicate_damage_rejected":true,"invalid_damage_atomic":true,"guard_cancelled_by_hit":true,"attack_interrupted_by_hit":true,"deleted_target_safe":true,"save_blocked_during_combat":true,"reaction_deferred_during_traversal":true,"physical_q_f_space":true,"target_not_reassigned":true,"wall_appearing_during_attack":true,"directional_reaction":true}
    FileAccess.open("res://qa/combat79.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
    print("R79_COMBAT_OK ",result)
    scene.get_tree().quit()
func _capture79(scene: Node3D, name: String) -> void:
    await scene.get_tree().process_frame
    await RenderingServer.frame_post_draw
    var path="res://previews/combat79/"+name+".png"
    DirAccess.make_dir_recursive_absolute(path.get_base_dir())
    scene.get_viewport().get_texture().get_image().save_png(path)
