extends SceneTree
class Prey extends CharacterBody3D:
    var paused=false
    var crouched=false
    var reaction={"state":"idle"}
    var map_doors={"doors":{}}
    var map_traversals={"obstacles":[]}
class TestScene extends Node3D:
    var player: CharacterBody3D
    var city: Node3D
    var zombie_world: Node3D
func _initialize() -> void:call_deferred("run")
func run() -> void:
    Engine.physics_ticks_per_second=60;Engine.max_fps=60
    var scene=TestScene.new();root.add_child(scene);scene.city=Node3D.new();scene.add_child(scene.city)
    var base=Vector3(-5000,0,-5000)
    var ground=StaticBody3D.new();scene.add_child(ground);ground.position=base-Vector3.UP*.1
    var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(40,.2,40);shape.shape=box;ground.add_child(shape)
    var road=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(30,5.8);road.mesh=plane;road.position=base+Vector3.UP*.047;scene.add_child(road);road.create_trimesh_collision()
    scene.player=Prey.new();scene.player.collision_layer=2;scene.player.collision_mask=3;scene.add_child(scene.player);scene.player.position=base+Vector3(0,.003,4.7)
    var cap=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.23;capsule.height=1.84;cap.shape=capsule;cap.position.y=.92;scene.player.add_child(cap)
    scene.zombie_world=load("res://personagem/zumbis98.gd").new();scene.add_child(scene.zombie_world);scene.zombie_world.setup(scene);scene.zombie_world.set_physics_process(false)
    var w=scene.zombie_world;var id="arr96_outer_001";w._activate(id);var actor=w.actors[id];actor.ai_enabled=false;actor.global_position=base+Vector3(0,.003,-4.7);actor.avatar.rotation.y=0;w.sync_actor(actor)
    for frame in 3:await physics_frame
    actor.hear_shot(scene.player.position,12)
    var high=actor.position.y;var low=high
    for frame in range(1200):
        await physics_frame;actor.step(1.0/60);high=maxf(high,actor.position.y);low=minf(low,actor.position.y)
        if actor.position.distance_to(scene.player.position)<1.1:break
    var distance=actor.position.distance_to(scene.player.position)
    print("R98_CURB_RESULT ",JSON.stringify({"crossed":distance<1.1,"remaining_m":distance,"height_range":high-low,"nav_failures":actor.route_failures,"navigation":actor.navigation_stats}))
    quit(0 if distance<1.1 else 1)
