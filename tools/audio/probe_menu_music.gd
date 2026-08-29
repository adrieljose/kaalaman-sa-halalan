extends Node
## Boots the real title screen and reports what it put on the music player.
## The probe above tests the autoload in isolation; this checks the wiring —
## that _ready asks for the menu track and that the autoload's _input still
## sees a gesture when a full scene is up and running.
##
##   godot --path . res://tools/audio/probe_menu_music.tscn

func _state() -> String:
	for child in Audio.get_children():
		if child is AudioStreamPlayer and child.bus == Audio.MUSIC_BUS:
			if child.stream == null:
				return "<nothing loaded>"
			return "%s playing=%s" % [child.stream.resource_path.get_file(), child.playing]
	return "<no music player>"


func _ready() -> void:
	await get_tree().process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 30:
		await get_tree().process_frame
	print("title screen, before any input:   %s" % _state())

	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 10:
		await get_tree().process_frame
	print("title screen, after a click:      %s" % _state())
	get_tree().quit(0)
