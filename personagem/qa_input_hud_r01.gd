extends SceneTree
func _initialize() -> void:
    var controller=load("res://personagem/atalhos_hud_r01.gd").new()
    var view=load("res://personagem/weapon_hud_r01.gd").new();view.controller=controller
    for direction in controller.DEFAULTS_R01:
        var action=controller.ACTIONS_R01[direction]
        assert(InputMap.has_action(action))
        assert(InputMap.action_get_events(action).size()==2)
        for code in controller.DEFAULTS_R01[direction]:
            var key=InputEventKey.new();key.physical_keycode=code;key.pressed=true
            assert(key.is_action_pressed(action))
        controller._default_action_r01(action,controller.DEFAULTS_R01[direction])
        assert(InputMap.action_get_events(action).size()==2)
    InputMap.action_erase_events("weapon_quick_up")
    var remap=InputEventKey.new();remap.physical_keycode=KEY_F9
    InputMap.action_add_event("weapon_quick_up",remap)
    controller._default_action_r01("weapon_quick_up",controller.DEFAULTS_R01.up)
    assert(view._hint("up")=="F9" and InputMap.action_get_events("weapon_quick_up").size()==1)
    var pad=InputEventJoypadButton.new();pad.button_index=JOY_BUTTON_DPAD_UP
    InputMap.action_add_event("weapon_quick_up",pad);pad.pressed=true
    assert(pad.is_action_pressed("weapon_quick_up") and view._hint("up").contains("J"))
    controller.free();view.free()
    print("HUD_R01_INPUT_OK defaults, aliases, no duplication, keyboard remap and synthetic gamepad")
    quit()
