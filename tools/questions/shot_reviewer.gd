extends Node
## Screenshots the reviewer on chapter 2, one shot per difficulty tier.
##
## The reviewer is the study screen, and it is the only place the whole bank is
## put on screen as text — so it is where a bad prompt, a term whose board
## spelling reads as nonsense, or a fact that just restates the question shows
## up. Chapter 2 is now 150 entries of mostly multi-word City Hall vocabulary,
## which is the first time that path has had to render at this length.
##
## Must run WINDOWED: the headless dummy renderer returns a null viewport
## texture and save_png() dies on it.

const CHAPTER := 2


func _ready() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	menu.call("_on_reviewer_pressed")
	menu.call("_on_reviewer_chapter_selected", CHAPTER)
	await get_tree().process_frame
	await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	image.save_png("tools/questions/reviewer_ch%d.png" % CHAPTER)
	print("saved reviewer_ch%d.png" % CHAPTER)
	get_tree().quit()
