extends SubViewport
## A portrait of the actual equipped character assets, in an isolated 3D world.
var avatar: Node3D
func configure(appearance: Dictionary,avatar_scene: String="res://personagem/personagem.tscn") -> void:
    size=Vector2i(312,352);transparent_bg=true;own_world_3d=true
    render_target_update_mode=SubViewport.UPDATE_ONCE
    var environment=WorldEnvironment.new();environment.environment=Environment.new()
    environment.environment.background_mode=Environment.BG_CLEAR_COLOR
    environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color=Color("d8ddd4");environment.environment.ambient_light_energy=.7
    add_child(environment)
    var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-25,-25,0);light.light_energy=1.2;add_child(light)
    avatar=load(avatar_scene).instantiate();avatar.manual_update=true;add_child(avatar)
    if not avatar.set_appearance(appearance):push_error("D02 portrait appearance invalid")
    avatar.set_motion("idle");avatar.motion_rate=0;avatar.advance(0)
    var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.53
    camera.near=.01;camera.far=10;add_child(camera)
    camera.position=Vector3(0,1.62,2.5);camera.look_at(Vector3(0,1.62,0));camera.current=true
