extends Node
## Captures a strip of frames through one rival's attack, so the phases can be
## looked at side by side.
##
## A single screenshot cannot show whether an attack has anticipation or
## follow-through -- those are defined by what the frames either side look like.
## Sampling straight through the move is the only way to see the shape of it.

const CHAPTER := 2
## Which encounters to strip, by index.
const SUBJECTS := [6, 7]
const SHOTS := 10
## Skip the telegraph and the approach; the strike itself starts about here.
const LEAD_IN := 62
const GAP_FRAMES := 6


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://output/strikes")
	var chapter: ChapterData = load("res://data/chapters/chapter_%02d.tres" % CHAPTER)

	for idx: int in SUBJECTS:
		var rival: EnemyData = chapter.encounters[idx]
		GameState.load_chapter(CHAPTER)
		GameState.encounter_index = idx
		GameState.character = "male"

		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		add_child(scene)
		for _f in 90:
			await get_tree().process_frame

		var move: EnemyMove = rival.moves[0]
		scene.call("_play_signature_move", move)
		for _f in LEAD_IN:
			await get_tree().process_frame

		var slug := String(rival.enemy_name).to_lower().replace(" ", "_")
		for shot in SHOTS:
			for _f in GAP_FRAMES:
				await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.save_png("res://output/strikes/%s_%02d.png" % [slug, shot])
		print("  %s -- %d frames" % [rival.enemy_name, SHOTS])

		# Let the move finish before tearing the scene down, or the next
		# encounter starts on top of a running coroutine.
		for _f in 140:
			await get_tree().process_frame
		scene.queue_free()
		await get_tree().process_frame

	get_tree().quit()
