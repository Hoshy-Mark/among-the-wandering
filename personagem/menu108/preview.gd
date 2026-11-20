extends SceneTree
## Fast UI boundary test. Map/gameplay acceptance remains the full native suite.
class Reaction extends RefCounted:
    signal started(kind)
    func is_active() -> bool:return false
class Player extends Node3D:
    var reaction=Reaction.new()
    var paused=false
    var hud_open=false
    var velocity=Vector3.ZERO
    func set_hud_open(value: bool) -> bool:hud_open=value;return true
class UI extends Control:
    var player: Node
    func sync_lock() -> void:player.hud_open=false
class World extends Node3D:
    var game_ui: Control
    var player: Node3D
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var scene=World.new();root.add_child(scene);scene.player=Player.new();scene.add_child(scene.player);scene.game_ui=UI.new();scene.game_ui.player=scene.player;scene.add_child(scene.game_ui)
    var m=load("res://personagem/personagens106.gd").new();m.scene=scene
    m.social=load("res://personagem/social105.gd").new();m.social.configure(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/dialogos105.json")),JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens106.json")).characters.keys())
    m.registry.configure(JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens106.json")))
    var menu=load("res://personagem/menu108/menu.gd").new();menu.set_process(false);m.add_child(menu);scene.add_child(m);menu.setup(m);menu.set_process(false);m.set_process(false)
    menu.opened=true;menu.shade.show();menu.panel.show()
    menu.preferences.path="res://qa/menu107/shell_preferences.json"
    root.size=Vector2i(1280,720)
    m.config=JSON.parse_string(FileAccess.get_file_as_string("res://personagem/personagens106.json"))
    m.registry.met.samuel_henrique=true;m.social.data.knowledge.player.append("samuel_returned")
    for tab in [0,1,2,3]:
        menu.select_tab(tab);await process_frame;await process_frame;await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png("res://qa/menu108/preview_"+str(tab)+".png")
    menu.force_close();scene.free();await process_frame;quit()
