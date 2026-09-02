extends Node
## Saves one battle frame for every rival in Chapter 2, in encounter order.
##
## Judging the roster from the source PNGs is not the same thing: a sprite only
## reveals its problems once it composites against its own room, at the size the
## player sees, standing on the floor line the shadow is cast onto. That is what
## this captures -- the real battle scene, one shot per encounter.
##
## Run as a SCENE, not with --script: the autoloads (GameState, Layout, Audio)
## are only registered for a real scene run, and picking the encounter needs
## GameState. Run WINDOWED too -- the headless dummy renderer hands back a null
## viewport texture and save_png() dies on it.
##
##   godot --path . tools/chapter2/shot_roster.tscn --resolution 640x480

const CHAPTER := 2
const OUT_DIR := "res://output/chapter2_enemies"
## Long enough for the layout pass, the encounter banner and a few idle frames,
## so the rival is captured mid-breath rather than on its first frame.
const SETTLE_FRAMES := 180


func _ready() -> void:
	await get_tree().process_frame

	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var chapter: ChapterData = load("res://data/chapters/chapter_%02d.tres" % CHAPTER)
	var count: int = chapter.encounters.size()
	print("chapter %d -- %s, %d encounters" % [CHAPTER, chapter.chapter_name, count])

	for i in count:
		var rival: EnemyData = chapter.encounters[i]

		GameState.load_chapter(CHAPTER)
		GameState.encounter_index = i
		# Alternated so both player sprites are seen against the roster rather
		# than only Juan -- Maria's silhouette and reach differ enough to be
		# worth having on record.
		GameState.character = "female" if i % 2 == 1 else "male"

		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		add_child(scene)
		for _f in SETTLE_FRAMES:
			await get_tree().process_frame

		var slug := String(rival.enemy_name).to_lower().replace(" ", "_")
		var path := "%s/e%d_%s.png" % [OUT_DIR, i + 1, slug]
		var image := get_viewport().get_texture().get_image()
		var err := image.save_png(path)
		print("  e%d  %-18s hp %-4d %s  ->  %s" % [
			i + 1, rival.enemy_name, rival.max_hp,
			"BOSS" if rival.is_boss else "    ",
			path if err == OK else "FAILED (%d)" % err])

		scene.queue_free()
		await get_tree().process_frame

	get_tree().quit(0)
