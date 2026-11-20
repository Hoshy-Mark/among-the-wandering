extends SceneTree
var profiles=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens106.json"))
var camera: Camera3D
var actors=[]
func _initialize() -> void:call_deferred("run")
func settle() -> void:
    for n in 6:await process_frame
func capture(name: String) -> void:
    await settle();await RenderingServer.frame_post_draw
    assert(root.get_texture().get_image().save_png("res://qa/visual106/"+name+".png")==OK)
func run() -> void:
    root.size=Vector2i(1440,900);DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/visual106"))
    var world=Node3D.new();root.add_child(world)
    var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("252d35");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("e0e3df");env.environment.ambient_light_energy=.65;world.add_child(env)
    var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-35,0);light.light_energy=1.15;world.add_child(light)
    camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.25;camera.near=.01;camera.far=100;world.add_child(camera);camera.current=true
    for n in 4:
        var female=n>0
        var avatar=load("res://personagem/personagem_feminina106.tscn" if female else "res://personagem/personagem.tscn").instantiate();avatar.manual_update=true;world.add_child(avatar)
        avatar.position.x=(n-1.5)*.78
        var profile=profiles.encounters[["samuel_henrique","renata_volker","pietra_dos_santos","ana_julia"][n]].appearance.duplicate(true)
        assert(avatar.set_appearance(profile));avatar.set_motion("idle");avatar.advance(.2);avatar.motion_paused=true;actors.append(avatar)
    camera.position=Vector3(0,1,5);camera.look_at(Vector3(0,.9,0));await capture("01_base_e_tres_perfis")
    for actor in actors:actor.visible=false
    var female=actors[1];female.visible=true;female.position.x=0
    # Prebake the two equipped mask combinations, retaining arbitrary fallback.
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://personagem/assets/female106/masks"))
    for flags in [7,15]:assert(ResourceSaver.save(female._body_mask(flags),"res://personagem/assets/female106/masks/corpo_%d.res"%flags)==OK)
    camera.size=.48;camera.position=Vector3(0,1.605,3);camera.look_at(Vector3(0,1.605,0));await capture("02_rosto_frente")
    female.rotation.y=PI*.5;await capture("03_rosto_perfil")
    female.rotation.y=0;camera.size=1.85;camera.position=Vector3(2,1.2,3);camera.look_at(Vector3(0,.95,0))
    assert(female.set_motion("walk"));female.motion_paused=false;female.advance(.32);female.motion_paused=true;await capture("04_caminhada")
    assert(female.set_motion("run"));female.motion_paused=false;female.advance(.32);female.motion_paused=true;await capture("05_corrida")
    assert(female.set_motion("crouch_idle"));female.motion_paused=false;female.advance(.3);female.motion_paused=true;await capture("06_agachamento")
    assert(female.set_motion("idle"));female.motion_paused=false;female.advance(.5);female.motion_paused=true
    camera.size=.48;camera.position=Vector3(0,1.605,3);camera.look_at(Vector3(0,1.605,0))
    female.seek_speech(float(female.clip.duration)*.35);await capture("07_fala")
    female.stop_speech();female.blink=1.;female._apply_weights();await capture("08_piscar")
    print("R106_VISUAL_OK");quit()
