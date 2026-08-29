extends Node
func _ready() -> void:
	await get_tree().process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 60:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://title_now.png")
	print("saved")
	get_tree().quit(0)
