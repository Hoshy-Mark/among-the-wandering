extends RefCounted
# Small recoil sampled from the approved right punch, without changing bone lengths.
func setup(actor: Node3D) -> void:
    var source: Animation=actor.player.get_animation(actor.clips.punch)
    var library=AnimationLibrary.new()
    for id in ["firearm_idle","firearm_shot"]:
        var animation=Animation.new();animation.length=.48 if id=="firearm_shot" else 1.0
        animation.loop_mode=Animation.LOOP_NONE if id=="firearm_shot" else Animation.LOOP_LINEAR
        for track in source.get_track_count():
            var type=source.track_get_type(track)
            if type not in [Animation.TYPE_ROTATION_3D,Animation.TYPE_POSITION_3D,Animation.TYPE_SCALE_3D]:continue
            var added=animation.add_track(type);animation.track_set_path(added,source.track_get_path(track))
            for step in [[0.0,.38],[.10,.38],[.18,.34],[.32,.38],[animation.length,.38]]:
                var time=float(step[0]);var sample=.38 if id=="firearm_idle" else float(step[1])
                var value: Variant
                if type==Animation.TYPE_ROTATION_3D:value=source.rotation_track_interpolate(track,sample)
                elif type==Animation.TYPE_POSITION_3D:value=source.position_track_interpolate(track,sample)
                else:value=source.scale_track_interpolate(track,sample)
                animation.track_insert_key(added,time,value)
        library.add_animation(id,animation);actor.clips[id]="Firearms87/"+id
    actor.player.add_animation_library("Firearms87",library)
