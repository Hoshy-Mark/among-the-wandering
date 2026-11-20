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
    for width in [1280,640,390]:
        root.size=Vector2i(width,720);await process_frame
        for tab in range(4):
            menu.select_tab(tab);await process_frame;await process_frame
            assert(menu.panel.get_global_rect().end.x<=width,"panel width "+str(width)+" tab "+str(tab))
            assert(menu.tabs[tab].get_global_rect().end.y<=720,"bottom navigation")
    menu.draft.volume=64;menu.close();await process_frame;assert(menu.modal.visible and menu.opened,"dirty close")
    menu.modal.hide();menu.apply_preferences();assert(menu.preferences.applied.volume==64,"apply")
    var service=load("res://personagem/menu107/preferences.gd").new();service.path=menu.preferences.path;service.setup();assert(service.applied.volume==64,"disk roundtrip")
    service.path="res://qa/menu107/missing_directory/preferences.json";var bad=service.applied.duplicate(true);bad.volume=12;assert(service.apply(bad)!="" and service.applied.volume==64,"write failure rolls back")
    menu.draft.resolution=1;menu.apply_preferences();assert(menu.video_seconds>0,"video confirmation");menu._rollback_video();assert(menu.preferences.applied.resolution==0,"video reversal")
    print("MENU108_SHELL_OK widths 1280/640/390; draft, persistence and video reversal");scene.free();quit()
