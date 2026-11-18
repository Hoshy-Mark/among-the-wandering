extends "res://personagem/hud65.gd"

func setup(body: CharacterBody3D) -> void:
    super.setup(body)
    windows[0].visible=false
    player.set_hud_open(false)

func show_container(id: String) -> bool:
    if not player.bag_inventory.accessible(id) or not player.set_hud_open(true):
        return false
    if get_viewport_rect().size.x<1200:
        windows[1].visible=false
    windows[0].visible=true
    container_id=id
    selected_uid=""
    refresh()
    feedback.text="E ou Esc fecha o recipiente. Selecione os itens para transferir."
    return true

func toggle(index: int) -> void:
    if player.world_interaction!=null and not player.world_interaction.pending_id.is_empty():
        player.world_interaction.close_interaction()
        return
    super.toggle(index)
    if not windows[0].visible and player.world_interaction!=null:
        player.world_interaction.close_interaction(false)
