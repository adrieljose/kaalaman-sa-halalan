extends Node
func _ready() -> void:
	await get_tree().process_frame
	GameState.load_chapter(3); GameState.encounter_index=0; GameState.character="male"
	var battle: Node=load("res://scenes/word_battle.tscn").instantiate()
	get_tree().root.add_child(battle)
	for f in range(60): await get_tree().process_frame
	battle._sequence_running=true
	battle._regular_combat.selected=2
	await battle._resolve_enemy_turn()
	var handler: Node=load("res://scripts/battle/player_attack_variations.gd").new()
	battle.add_child(handler); handler.setup(battle); handler.forced_index=2
	await handler.strike()
	print("CONTACT ",handler.contact_metrics," player=",battle.player_character.position," overlay=",handler.overlay.position," scale=",handler.overlay.scale," enemy=",battle.enemy_character.position," enemy_tex=",battle.enemy_character.texture.resource_path)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://output/player_attacks/contact_probe.png")
	await handler.recover()
	battle.queue_free(); await get_tree().process_frame
	get_tree().quit()
