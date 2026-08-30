extends Node
## Every encounter in the game, cropped to the fighters' feet.
##
## The session hall was caught by eye; this is the check that the same fault is
## not sitting in another room. Each room was generated on its own, so nothing
## guarantees any of them put walkable floor where the fighters stand.
##
##   godot --path . res://tools/chapter2/shot_all_feet.tscn --resolution 1280x960

func _ready() -> void:
	await get_tree().process_frame
	for chapter in [1, 2]:
		var data = load("res://data/chapters/chapter_%02d.tres" % chapter)
		for i in data.encounters.size():
			GameState.load_chapter(chapter)
			GameState.character = "female" if i % 2 == 1 else "male"
			GameState.encounter_index = i
			var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
			add_child(scene)
			for f in 100:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img: Image = get_viewport().get_texture().get_image()
			img.save_png("res://feet_c%d_e%d.png" % [chapter, i + 1])
			print("saved c%d e%d  %s" % [chapter, i + 1, data.encounters[i].enemy_name])
			scene.queue_free()
			await get_tree().process_frame
	get_tree().quit(0)
