extends SceneTree
class LegacyPlayer extends Node3D:
    var hud_open=false
    var paused=false
    var consumed=0
    func _unhandled_key_input(event: InputEvent) -> void:
        if event is InputEventKey and event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:
            consumed+=1;get_viewport().set_input_as_handled()
class World extends Node3D:
    var player: Node3D
class Probe extends "res://personagem/atalhos_hud_r01.gd":
    var seen=[]
    func activate(direction: String,_from_inventory: bool=false) -> bool:
        seen.append(direction);return true
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var world=World.new();root.add_child(world)
    var player=LegacyPlayer.new();world.add_child(player);world.player=player
    var controller=Probe.new();player.add_child(controller);controller.scene=world
    await process_frame
    for code in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_UP,KEY_LEFT,KEY_RIGHT,KEY_DOWN]:
        var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
        Input.parse_input_event(event);await process_frame
        event=InputEventKey.new();event.physical_keycode=code;event.pressed=false
        Input.parse_input_event(event);await process_frame
    assert(controller.seen==["up","left","right","down","up","left","right","down"],str(controller.seen))
    assert(player.consumed==0)
    var alt=InputEventKey.new();alt.physical_keycode=KEY_ALT;alt.keycode=KEY_ALT;alt.alt_pressed=true;alt.pressed=true
    Input.parse_input_event(alt);await process_frame
    assert(Input.is_action_pressed("weapon_quick_consult"),"Alt actual modifier event")
    alt=InputEventKey.new();alt.physical_keycode=KEY_ALT;alt.keycode=KEY_ALT;alt.pressed=false
    Input.parse_input_event(alt);await process_frame
    assert(not Input.is_action_pressed("weapon_quick_consult"))
    player.hud_open=true
    var blocked=InputEventKey.new();blocked.physical_keycode=KEY_1;blocked.pressed=true
    Input.parse_input_event(blocked);await process_frame
    assert(controller.seen.size()==8)
    world.queue_free();await process_frame
    print("HUD_R01_ROUTE_OK actual SceneTree input dispatch precedes legacy keys and respects UI")
    quit()
