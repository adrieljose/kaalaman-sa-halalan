extends Node
## Opens the credits panel and saves a frame. The panel is a fixed-size box
## around a RichTextLabel, so adding a line is exactly the kind of change that
## silently pushes the last line out of view.
##
##   godot --path . res://tools/audio/shot_credits.tscn --resolution 1280x960

func _ready() -> void:
	await get_tree().process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 30:
		await get_tree().process_frame
	menu.get_node("Menu/CreditsButton").emit_signal("pressed")
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://credits_check.png")
	print("saved credits_check.png")
	get_tree().quit(0)
