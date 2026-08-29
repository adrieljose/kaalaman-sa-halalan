extends Node
## The rig is cut from each character's rect, so every arrangement has to
## re-cut it. This boots the title screen at three window sizes and samples the
## dance mid-swing in each — a rig that failed to rebuild shows up here as bands
## sitting beside the character instead of on it.
##
##   godot --path . res://tools/menu/shot_dance_layouts.tscn

const SIZES := [
	{"w": 1280, "h": 960, "file": "layout_wide.png"},
	{"w": 390, "h": 844, "file": "layout_portrait.png"},
	{"w": 844, "h": 390, "file": "layout_compact.png"},
]

func _ready() -> void:
	await get_tree().process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for shot in SIZES:
		DisplayServer.window_set_size(Vector2i(int(shot["w"]), int(shot["h"])))
		# Long enough for the layout signal, the deferred re-cut, and a draw.
		for i in 40:
			await get_tree().process_frame
		var dance = menu.get_node_or_null("TitleDance")
		if dance != null:
			dance.call("_apply", 0.25)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://" + String(shot["file"]))
		print("saved %s  rigged=%s/%s" % [shot["file"],
			menu.get_node("PlayerCharacter").is_rigged(),
			menu.get_node("PlayerCharacterFemale").is_rigged()])
	get_tree().quit(0)
