extends RefCounted
var path="user://preferences107.json"
var applied={}
var defaults={}
var previous={}
var pending={}
var actions=["character_skills","weapon_quick_up","weapon_quick_left","weapon_quick_right","weapon_quick_down","weapon_quick_consult"]
var originals={}
func setup() -> void:
    for action in actions:
        originals[action]=InputMap.action_get_events(action).duplicate(true)
    defaults={"mode":0,"resolution":0,"vsync":true,"fps":60,"volume":100.0,"bindings":{}}
    for action in actions:
        var keys=[]
        for event in originals[action]:
            if event is InputEventKey:keys.append(int(event.physical_keycode if event.physical_keycode else event.keycode))
        defaults.bindings[action]=keys
    applied=defaults.duplicate(true)
    if FileAccess.file_exists(path):
        var value=JSON.parse_string(FileAccess.get_file_as_string(path))
        if valid(value):applied=normalize(value)
    execute(applied)
func valid(value: Variant) -> bool:
    if not value is Dictionary:return false
    for key in ["mode","resolution","fps","volume"]:
        if not value.get(key) is float and not value.get(key) is int:return false
    for key in ["mode","resolution","fps"]:
        if value[key]!=int(value[key]):return false
    if int(value.mode) not in [0,1,2] or int(value.resolution) not in [0,1,2] or int(value.fps) not in [0,30,60,120] or value.volume<0 or value.volume>100 or not value.get("vsync") is bool:return false
    if not value.get("bindings") is Dictionary or value.bindings.size()!=actions.size():return false
    var used=[]
    for action in actions:
        if not value.bindings.get(action) is Array or value.bindings[action].is_empty():return false
        for raw in value.bindings[action]:
            if not raw is int and not raw is float:return false
            var key=int(raw)
            if raw!=key or key<=0 or key==KEY_ESCAPE:return false
            if key in used:return false
            used.append(key)
            # Preserve existing shared contextual bindings, reject new conflicts.
            if key not in defaults.bindings[action]:
                if key in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_SHIFT,KEY_CTRL,KEY_E,KEY_I,KEY_H,KEY_R,KEY_SPACE,KEY_Q,KEY_F,KEY_TAB]:return false
                var event=InputEventKey.new();event.physical_keycode=key
                for other in InputMap.get_actions():
                    if other in actions or other.begins_with("ui_"):continue
                    if InputMap.event_is_action(event,other):return false
    return true
func normalize(value: Dictionary) -> Dictionary:
    var result=value.duplicate(true)
    for key in ["mode","resolution","fps"]:result[key]=int(result[key])
    result.volume=float(result.volume)
    for action in actions:
        var keys=[]
        for raw in result.bindings[action]:keys.append(int(raw))
        result.bindings[action]=keys
    return result
func execute(value: Dictionary) -> void:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value.mode==1 else DisplayServer.WINDOW_MODE_WINDOWED)
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,value.mode==2)
    if value.mode!=1:DisplayServer.window_set_size([Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)][int(value.resolution)])
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value.vsync else DisplayServer.VSYNC_DISABLED)
    Engine.max_fps=int(value.fps)
    AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,float(value.volume)/100)))
    AudioServer.set_bus_mute(0,value.volume==0)
    for action in actions:
        InputMap.action_erase_events(action)
        # Preserve any non-keyboard bindings already owned by the action.
        for original in originals[action]:
            if not original is InputEventKey:InputMap.action_add_event(action,original)
        for code in value.bindings[action]:
            var event=InputEventKey.new();event.physical_keycode=int(code);InputMap.action_add_event(action,event)
func apply(value: Dictionary) -> String:
    if not pending.is_empty() or not valid(value):return "Configuração inválida ou tecla em conflito."
    previous=applied.duplicate(true);pending=normalize(value);execute(pending)
    if pending.mode!=previous.mode or pending.resolution!=previous.resolution:return "video"
    return confirm()
func confirm() -> String:
    if pending.is_empty():return "Nenhuma alteração pendente."
    var f=FileAccess.open(path+".tmp",FileAccess.WRITE)
    if f==null:rollback();return "Não foi possível salvar as preferências."
    f.store_string(JSON.stringify(pending));f.flush();var error=f.get_error();f.close()
    if error!=OK:rollback();return "Não foi possível gravar as preferências."
    error=DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
    if error!=OK:rollback();return "Não foi possível confirmar as preferências."
    applied=pending.duplicate(true);pending={};previous={};return ""
func rollback() -> void:
    if not previous.is_empty():execute(previous)
    pending={};previous={}
