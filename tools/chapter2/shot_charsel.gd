extends Node
## Screenshots the character-select screen in both states: nothing picked yet,
## then with Maria chosen. The selected state is the whole point of the
## redesign, so a shot that only shows the neutral one proves nothing.
func _ready() -> void:
	await get_tree().process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 60:
		await get_tree().process_frame
	menu._on_play_pressed()
	for i in 40:
		await get_tree().process_frame
	menu._on_chapter_pressed(1)
	for i in 60:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shot_char_none.png")
	menu._on_character_selected("female")
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shot_char_pick.png")
	print("saved both character-select states")
	get_tree().quit(0)
