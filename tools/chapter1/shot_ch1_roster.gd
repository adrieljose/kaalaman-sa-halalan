extends Node
## Screenshots every Chapter 1 encounter, the way shot_roster does for Chapter 2.
## Added when Senator Sabaw was finally turned to face the player -- Chapter 1
## had no roster shot of its own, so there was no way to check him beside his
## chapter-mates.
const CHAPTER := 1
const OUT_DIR := "res://output/chapter1_enemies"
const SETTLE_FRAMES := 150

func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var chapter: ChapterData = load("res://data/chapters/chapter_%02d.tres" % CHAPTER)
	for i in chapter.encounters.size():
		var rival: EnemyData = chapter.encounters[i]
		GameState.load_chapter(CHAPTER)
		GameState.encounter_index = i
		GameState.character = "female" if i % 2 == 1 else "male"
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		add_child(scene)
		for _f in SETTLE_FRAMES:
			await get_tree().process_frame
		var slug := String(rival.enemy_name).to_lower().replace(" ", "_")
		get_viewport().get_texture().get_image().save_png(
			"%s/e%d_%s.png" % [OUT_DIR, i + 1, slug])
		print("  e%d  %s" % [i + 1, rival.enemy_name])
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
