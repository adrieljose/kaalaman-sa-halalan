extends Node
## Checks that the right track plays on each screen, and that the web autoplay
## gate HOLDS a request rather than dropping it.
##
## Run as a SCENE, not with --script: the Audio autoload only exists for a real
## scene run, and exercising it is the whole point.
##
##   godot --path . res://tools/audio/probe_music.tscn

func _state() -> String:
	var player: AudioStreamPlayer = null
	for child in Audio.get_children():
		if child is AudioStreamPlayer and child.bus == Audio.MUSIC_BUS:
			player = child
			break
	if player == null or player.stream == null:
		return "<nothing loaded>"
	return "%-17s playing=%-5s trim=%+.1f dB" % [
		player.stream.resource_path.get_file(), player.playing, player.volume_db]


func _report(label: String) -> void:
	print("%-38s %s" % [label, _state()])


func _gesture() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame

	Audio.play_music("menu")
	_report("menu asked for, no gesture yet")

	await _gesture()
	_report("after the first gesture")

	Audio.play_music("menu")
	_report("menu asked for again (no restart)")

	Audio.play_music("battle")
	_report("entering a battle")

	Audio.play_sting("victory")
	_report("victory sting")

	Audio.play_music("battle")
	_report("battle resumes after the sting")

	Audio.play_music("menu")
	_report("back out to the menu")

	get_tree().quit(0)
