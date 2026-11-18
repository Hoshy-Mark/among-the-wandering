extends "res://isometric_base_r59.gd"

func _ready() -> void:
    await super._ready()
    var args=OS.get_cmdline_user_args()
    if "--qa-auto" in args or "--capture-auto" in args:
        player.global_position=spawn+Vector3(0,.03,-3)
        await load("res://personagem/revisao60.gd").new().run(self,"--capture-auto" in args,true)

func _interface() -> void:
    super._interface()
    var label=Label.new()
    label.text="R60 · Locomoção automática\nWASD · andar  |  Shift · correr\nShift + Ctrl · sprint  |  C · agachar"
    panel.get_child(0).get_child(0).add_child(label)
