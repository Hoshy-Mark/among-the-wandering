extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    var male=load("res://personagem/personagem.tscn").instantiate();male.manual_update=true;root.add_child(male)
    var library=male.player.get_animation_library("Actions51");var id=library.get_animation_list()[0]
    var before=str(library.get_animation(id).track_get_path(0));var a_id=library.get_animation(id).get_instance_id()
    var female=load("res://personagem/personagem_feminina106.tscn").instantiate();female.manual_update=true;root.add_child(female)
    var other=female.player.get_animation_library("Actions51")
    print(JSON.stringify({"male_before":before,"male_after":str(library.get_animation(id).track_get_path(0)),"female_path":str(other.get_animation(id).track_get_path(0)),"male_instance":a_id,"female_instance":other.get_animation(id).get_instance_id(),"male_skeleton":str(male.get_path_to(male.skeleton)),"female_skeleton":str(female.get_path_to(female.skeleton))}))
    quit()
