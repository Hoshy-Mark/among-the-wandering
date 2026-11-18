extends "res://personagem/travessia_mapa77.gd"
var base_path: RefCounted
var base_definition: Dictionary
var fence_mode=false
func setup(player: CharacterBody3D) -> void:
    if player.avatar.player.has_animation_library("Map77"):player.avatar.player.remove_animation_library("Map77")
    super.setup(player)
    base_path=path
    base_definition=definitions.duplicate(true)
    var library: AnimationLibrary=load("res://personagem/assets/motion/r78/fences.res").duplicate(true)
    for clip in library.get_animation_list():
        var animation=library.get_animation(clip)
        for track in animation.get_track_count():
            var bone=str(animation.track_get_path(track).get_subname(0))
            animation.track_set_path(track,NodePath(str(actor.get_path_to(actor.skeleton))+":"+bone))
    assert(actor.player.add_animation_library("Fences78",library)==OK)
func begin(obstacle: Node3D, action_id: String) -> bool:
    if is_active():return false
    if not is_instance_valid(obstacle) or not obstacle.has_meta("fence78"):
        path=base_path
        definitions=base_definition.duplicate(true)
        return super.begin(obstacle,action_id)
    if action_id!="vault_fence" or body.hud_open or body.action.state!="idle" or body.inventory_actions.busy() or body.map_doors.busy() or body.world_interaction.has_interaction():return false
    if not obstacle.prepare(body):message=obstacle.reason;return false
    path=load("res://personagem/percurso_cercas78.gd").new()
    definitions=base_definition.duplicate(true)
    definitions.actions.vault_fence.duration=5.45 if obstacle.model.high else 4.3
    definitions.actions.vault_fence.effect_time=definitions.actions.vault_fence.duration
    path.setup(definitions)
    path.high=obstacle.model.high
    path.configure(action_id,obstacle.rise,0)
    playback_rate=1.3 if obstacle.model.high else 2.0
    old_clip=actor.clips[action_id]
    actor.clips[action_id]="Fences78/"+obstacle.variant
    map_action=true
    fence_mode=true
    # The original state machine owns movement, reservation and collision checks.
    var accepted=_start_fence(obstacle,action_id)
    if not accepted:
        actor.clips[action_id]=old_clip
        map_action=false
        fence_mode=false
    return accepted
func _start_fence(obstacle: Node3D, action_id: String) -> bool:
    return _begin_original(obstacle,action_id)
func _finish(success: bool) -> void:
    super._finish(success)
    if fence_mode:
        path=base_path
        definitions=base_definition.duplicate(true)
        playback_rate=2.0
        fence_mode=false

func reset_test() -> void:
    super.reset_test()
    path=base_path
    definitions=base_definition.duplicate(true)
    playback_rate=2.0
    fence_mode=false
