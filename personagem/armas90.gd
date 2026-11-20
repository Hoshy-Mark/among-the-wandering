extends "res://personagem/armas87.gd"
var presentation: Node3D
func setup(root_scene: Node3D) -> void:
    super.setup(root_scene)
    presentation=load("res://personagem/postura_pistola90.gd").new();add_child(presentation);presentation.setup(scene.player)
func reload_weapon() -> bool:
    if not super.reload_weapon():return false
    var p=scene.player
    p.action.motion_id="firearm_reload90";p.avatar.set_motion("firearm_reload90");p.avatar.motion_clock=0;p.avatar.motion_rate=0
    return true
func present() -> void:
    super.present()
    if scene==null:return
    var p=scene.player
    if not reload_job.is_empty() and p.action.state!="idle" and p.action.action_id=="equip" and not p.traversal.is_active() and not p.reaction.is_active():
        visual.visible=true;visual.attach(p.avatar)
    if presentation!=null and (reload_job.is_empty() or p.action.state=="idle"):presentation.magazine.visible=false
