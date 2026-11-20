extends SceneTree
func _initialize() -> void:
    var source: AnimationLibrary=load("res://personagem/assets/motion/r77/map_traversals.res")
    var library=AnimationLibrary.new()
    var reflection=Basis(Vector3(-1,0,0),Vector3.UP,Vector3.BACK)
    for name in ["window_in","window_out"]:
        var clip: Animation=source.get_animation(name).duplicate(true)
        for track in clip.get_track_count():
            var path=clip.track_get_path(track);var bone=str(path.get_subname(0))
            if bone.ends_with(".L"):bone=bone.trim_suffix(".L")+".R"
            elif bone.ends_with(".R"):bone=bone.trim_suffix(".R")+".L"
            clip.track_set_path(track,NodePath(str(path.get_concatenated_names())+":"+bone))
            for key in clip.track_get_key_count(track):
                var value=clip.track_get_key_value(track,key)
                if clip.track_get_type(track)==Animation.TYPE_POSITION_3D:value.x=-value.x
                elif clip.track_get_type(track)==Animation.TYPE_ROTATION_3D:value=(reflection*Basis(value)*reflection).get_rotation_quaternion().normalized()
                clip.track_set_key_value(track,key,value)
        library.add_animation(name+"_mirror",clip)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://personagem/assets/motion/r113"))
    assert(ResourceSaver.save(library,"res://personagem/assets/motion/r113/window_mirrors.res",ResourceSaver.FLAG_COMPRESS)==OK)
    print("MIRROR113_BAKED");quit()
