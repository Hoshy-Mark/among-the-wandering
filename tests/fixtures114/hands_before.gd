extends RefCounted

var actor: Node3D
var poses: Dictionary
var library: AnimationLibrary
var current: Dictionary={}
var outgoing: Dictionary={}
var label:="Relaxed"
var clip: Animation
var clock:=0.0
var blend_time:=.12

func setup(npc: Node3D) -> void:
    actor=npc
    poses=JSON.parse_string(FileAccess.get_file_as_string(actor.base_dir+"poses_maos.json"))
    library=load(actor.base_dir+"assets/motion/r50/fingers.res")
    current=decode(poses.Relaxed)
    apply()

func decode(data: Dictionary) -> Dictionary:
    var result: Dictionary={}
    for name in data:
        var position: Array=data[name].position
        var rotation: Array=data[name].rotation
        result[name]=Transform3D(Basis(Quaternion(rotation[0],rotation[1],rotation[2],rotation[3])),Vector3(position[0],position[1],position[2]))
    return result

func set_pose(id: String) -> bool:
    if not poses.has(id):
        return false
    outgoing=current.duplicate()
    label=id
    clip=null
    clock=0
    return true

func play(id: String) -> bool:
    if not library.has_animation(id):
        return false
    outgoing=current.duplicate()
    clip=library.get_animation(id)
    clock=0
    return true

func advance(delta: float) -> void:
    clock+=delta
    var target:=decode(poses[label])
    if clip!=null:
        for track in clip.get_track_count():
            var name:=str(clip.track_get_path(track).get_subname(0))
            var pose: Transform3D=target[name]
            if clip.track_get_type(track)==Animation.TYPE_ROTATION_3D:
                pose.basis=Basis(clip.rotation_track_interpolate(track,minf(clock,clip.length)))
            elif clip.track_get_type(track)==Animation.TYPE_POSITION_3D:
                pose.origin=clip.position_track_interpolate(track,minf(clock,clip.length))
            target[name]=pose
    var amount:=smoothstep(0,blend_time,clock)
    current=target
    if amount<1:
        for name in outgoing:
            current[name]=outgoing[name].interpolate_with(target[name],amount)
    apply()

func apply() -> void:
    for name in current:
        actor.skeleton.set_bone_pose(actor.skeleton.find_bone(name),current[name])
