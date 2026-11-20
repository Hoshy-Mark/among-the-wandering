extends Node
var scene: Node3D
var tester: RefCounted
var elapsed=0.0
func setup(root: Node3D) -> void:
    scene=root;_start()
func _start() -> void:
    var script=GDScript.new();script.source_code=FileAccess.get_file_as_string("res://personagem/revisao98.gd")
    if script.reload()!=OK:print("R98_QA_COMPILE_FAILED");return
    tester=script.new();tester.run(scene)
func _process(delta: float) -> void:
    elapsed+=delta
    if elapsed<.5:return
    elapsed=0
    if not FileAccess.file_exists("res://qa/retry98.flag"):return
    DirAccess.remove_absolute(ProjectSettings.globalize_path("res://qa/retry98.flag"));_start()
func finish(report: Dictionary) -> void:
    FileAccess.open("res://qa/population98.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("R98_INTEGRATION_OK ",JSON.stringify(report))
    if not "--keep-population98" in OS.get_cmdline_user_args():get_tree().quit()
