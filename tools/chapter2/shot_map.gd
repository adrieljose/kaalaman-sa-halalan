extends Node
## Screenshots the chapter-select map as the player sees it -- markers, labels
## and landmarks composited together, which is the only place their collisions
## actually show up.
func _ready() -> void:
	await get_tree().process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 60:
		await get_tree().process_frame
	if menu.has_method("_on_play_pressed"):
		menu._on_play_pressed()
	for i in 90:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shot_map.png")
	print("saved shot_map.png")
	get_tree().quit(0)
