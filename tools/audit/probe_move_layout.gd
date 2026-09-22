extends Node

func _ready() -> void:
	await get_tree().process_frame
	for window in [Vector2i(1152, 648), Vector2i(800, 600), Vector2i(390, 844)]:
		get_tree().root.size = window
		for _frame in range(8):
			await get_tree().process_frame
		for chapter_no in [3, 4]:
			GameState.load_chapter(chapter_no)
			GameState.encounter_index = 0
			GameState.character = "male"
			GameState.difficulty = "easy"
			QuestionBank.set_context(chapter_no, "easy")
			var battle: Node = load("res://scenes/word_battle.tscn").instantiate()
			get_tree().root.add_child(battle)
			for _frame in range(30):
				await get_tree().process_frame
			if battle._move_strip.visible:
				battle._on_move_strip_pressed()
				for _frame in range(4):
					await get_tree().process_frame
			print("\nwindow=", window, " chapter=", chapter_no,
				" viewport=", get_viewport().get_visible_rect(),
				" side_visible=", battle.side_panel.is_visible_in_tree(),
				" side=", battle.side_panel.get_global_rect())
			for entry: Dictionary in battle._move_entries:
				var icon := entry.icon as TextureRect
				var label := entry.name as Label
				var slot := icon.get_parent() as Control
				var header := slot.get_parent() as Control
				print(label.text, " header=", header.get_global_rect(),
					" icon=", icon.get_global_rect(), " slot=", slot.get_global_rect(),
					" label=", label.get_global_rect(), " intersects=",
					icon.get_global_rect().intersects(label.get_global_rect()))
			battle.queue_free()
			for _frame in range(5):
				await get_tree().process_frame
	get_tree().quit()
