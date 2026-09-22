extends Node
const OUT = "res://output/encounter_floor_facing/"
func frames(n:int)->void:
	for i in n: await get_tree().process_frame
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await frames(2)
	var count:=0
	for character in ["male", "female"]:
		GameState.character=character
		for entry in [[1,2],[1,3],[2,6],[2,7]]:
			GameState.load_chapter(entry[0])
			QuestionBank.set_context(entry[0],"easy")
			GameState.encounter_index=entry[1]
			var enemy=GameState.current_enemy()
			if entry[0]==1: assert(not enemy.flip_h)
			var battle=load("res://scenes/word_battle.tscn").instantiate()
			get_tree().root.add_child(battle)
			await frames(24)
			var actor=battle.get_node("EnemyCharacter")
			for action in ["idle","attack","hit"]:
				if action=="attack": actor.play_attack()
				if action=="hit": actor.play_hit()
				await frames(8)
				if DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
					assert(get_viewport().get_texture().get_image().save_png(OUT+"%s_%s_%s.png"%[character,enemy.enemy_name.to_snake_case(),action])==OK)
			battle.queue_free()
			await frames(3)
			count+=1
	print("FLOOR/FACING CAPTURED: ",count," encounters, 24 action screenshots")
	get_tree().quit()
