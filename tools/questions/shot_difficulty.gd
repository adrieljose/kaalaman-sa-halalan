extends Node
## Screenshots the difficulty panel for one chapter, so the example words the
## menu quotes can be checked against the panel they have to fit inside.
##
## Chapter 2's City Hall vocabulary is mostly multi-word terms, which makes its
## hint lines about half again as long as chapter 1's. The hint Labels do not
## autowrap, and a PanelContainer clamps itself UP to its children's minimum
## width -- so a line that is too long does not clip, it silently widens the
## whole panel off its centred position. That is what this is looking for.
##
## Must run WINDOWED: the headless dummy renderer hands back a null viewport
## texture and save_png() dies on it.

const CHAPTERS := [1, 2]


func _ready() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	for chapter_no: int in CHAPTERS:
		GameState.chapter = load("res://data/chapters/chapter_%02d.tres" % chapter_no)
		# Every tier has to be readable, and only Easy is unlocked at boot --
		# the locked tiers print a different, shorter line.
		GameState.mark_difficulty_completed(chapter_no, "easy")
		GameState.mark_difficulty_completed(chapter_no, "medium")
		menu.call("_apply_difficulty_hints")
		menu.get_node("DifficultyPanel").show()
		await get_tree().process_frame
		await get_tree().process_frame

		var panel: Control = menu.get_node("DifficultyPanel")
		print("ch%d panel rect: %s" % [chapter_no, panel.get_global_rect()])
		for tier in ["Easy", "Medium", "Hard"]:
			var label: Label = panel.get_node("VBox/%sHint" % tier)
			print("   %-6s width %4.0f  text %s" % [
				tier, label.get_minimum_size().x, label.text.replace("\n", " / ")])

		var image := get_viewport().get_texture().get_image()
		image.save_png("tools/questions/difficulty_ch%d.png" % chapter_no)

	get_tree().quit()
