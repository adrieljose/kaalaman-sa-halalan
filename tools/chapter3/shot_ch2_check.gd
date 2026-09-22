extends Node
## Visual check on the Chapter 2 rooms with custom ground_fraction, which are
## the ones the grounding change could plausibly have disturbed.
const SETTLE := 60
func _ready() -> void:
	await get_tree().process_frame
	# The working Chapter 3 probe sizes the window before building anything.
	# Testing whether that is what lets the battle scene finish _ready().
	DisplayServer.window_set_size(Vector2i(1280, 960))
	for _f in 8:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://output/ch2_check")
	GameState.load_chapter(2)
	QuestionBank.set_context(2, "easy")
	for idx in [1, 6, 7, 8]:
		GameState.encounter_index = idx
		var e := GameState.current_enemy()
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame
		var pc := scene.find_child("PlayerCharacter", true, false) as Control
		var ec := scene.find_child("EnemyCharacter", true, false) as Control
		var pf: float = pc.position.y + (pc.call("body_rect") as Rect2).end.y
		var ef: float = ec.position.y + (ec.call("body_rect") as Rect2).end.y
		# The requirement that actually matters visually: one floor, both feet.
		print("   %-20s soles p%.1f e%.1f  apart %.1f" % [e.enemy_name, pf, ef, absf(pf - ef)])
		get_viewport().get_texture().get_image().save_png(
			"res://output/ch2_check/%s.png" % e.enemy_name.to_lower().replace(" ", "_"))
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
