extends Node
## Photographs the title screen with TUTORIAL in the stack, and the first-time
## prompt PLAY puts in front of a new player.
##
## Seven buttons is two more than the stack was authored for, and _grow_menu_stack
## shrinks every button together once they stop fitting -- so the thing to check
## is not that TUTORIAL exists but that adding it did not squeeze CERTIFICATE
## into clipping its own last letter, on any of the three arrangements.
##
##   godot --path . tools/battle/shot_menu_tutorial.tscn --resolution 1280x960

const OUT_DIR := "res://output/tutorial"
const SETTLE := 45
const CASES := [
	{"name": "menu_wide", "window": Vector2i(1280, 960)},
	{"name": "menu_portrait", "window": Vector2i(390, 844)},
	{"name": "menu_landscape", "window": Vector2i(844, 390)},
]

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for case in CASES:
		DisplayServer.window_set_size(case["window"])
		await get_tree().process_frame
		# Never completed, so PLAY offers the tutorial -- which is the state a
		# brand new player arrives in.
		GameState.tutorial_completed = false
		GameState.pending_play_request = false

		# Parented to the ROOT VIEWPORT, not to this helper node.
		#
		# A Control under a plain Node has no parent area to anchor against, so it
		# sits at size zero -- and a scene staged that way never reproduces what the
		# real game does when a full-rect child grows from nothing to the whole
		# screen. That gap hid a crash: the tutorial director answers its first
		# NOTIFICATION_RESIZED by placing a card it had not built yet, which under a
		# zero-sized parent never fired at all. Staged here the way the game stages
		# it, so a size-dependent failure fails here too.
		var scene: Node = load("res://scenes/main_menu.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame

		var menu: VBoxContainer = scene.get_node("Menu")
		var names: PackedStringArray = []
		for child in menu.get_children():
			names.append((child as Button).text)
		print("%-16s %s" % [case["name"], ", ".join(names)])
		if not "TUTORIAL" in names:
			_faults.append("%s: no TUTORIAL button" % case["name"])

		for child in menu.get_children():
			var button := child as Button
			var wanted: float = button.get_theme_font("font").get_string_size(
				button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				button.get_theme_font_size("font_size")).x
			if wanted > button.size.x:
				_faults.append("%s: '%s' needs %dpx in a %dpx button"
					% [case["name"], button.text, wanted, button.size.x])
			if button.size.y < 26.0:
				_faults.append("%s: '%s' is only %d units tall"
					% [case["name"], button.text, button.size.y])
		if menu.position.y < 0.0 or menu.position.y + menu.size.y > scene.size.y + 1.0:
			_faults.append("%s: the stack runs off the screen (%s..%s of %s)"
				% [case["name"], menu.position.y, menu.position.y + menu.size.y,
					scene.size.y])

		get_viewport().get_texture().get_image().save_png(
			"%s/%s.png" % [OUT_DIR, case["name"]])

		# ... and what PLAY does for someone who has never finished it.
		scene.call("_on_play_pressed")
		for _f in 20:
			await get_tree().process_frame
		var prompt: PanelContainer = scene.get("_first_time_panel")
		if prompt == null or not prompt.visible:
			_faults.append("%s: PLAY did not offer the tutorial to a new player"
				% case["name"])
		else:
			# Where the panel actually ENDED UP, which is not what it was asked
			# for.
			#
			# _centre_panel() sizes and centres in one step, and a Control whose
			# content needs more room than it was given is quietly raised back to
			# its minimum afterwards -- growing downward, from a centre that was
			# computed for the smaller rect. Nothing clips and no size query
			# disagrees with itself; the panel just sits low. Comparing its real
			# centre against the screen's is the only thing that notices.
			var d := Layout.profile.design_size
			var off_centre: float = absf(prompt.get_global_rect().get_center().y - d.y * 0.5)
			print("   %s prompt %dx%d, off centre by %d" % [
				case["name"], prompt.size.x, prompt.size.y, off_centre])
			if off_centre > 2.0:
				_faults.append("%s: the prompt sits %d units off centre"
					% [case["name"], off_centre])
			get_viewport().get_texture().get_image().save_png(
				"%s/%s_prompt.png" % [OUT_DIR, case["name"]])

		# BACK is a cancel, not a quiet decline. The panel closes, the chapter
		# map stays shut, the player is back on the title screen -- and because
		# nothing was decided, PLAY asks again.
		scene.call("_on_first_time_back")
		for _f in 10:
			await get_tree().process_frame
		if prompt != null and prompt.visible:
			_faults.append("%s: BACK did not close the prompt" % case["name"])
		if (scene.get_node("MapPanel") as Control).visible:
			_faults.append("%s: BACK opened the chapter map instead of cancelling"
				% case["name"])
		scene.call("_on_play_pressed")
		for _f in 10:
			await get_tree().process_frame
		if prompt != null and not prompt.visible:
			_faults.append("%s: PLAY did not ask again after BACK cancelled"
				% case["name"])

		# Declining decides something: it falls through to the chapter map, and
		# it does not ask again for the rest of the sitting.
		scene.call("_on_first_time_declined")
		for _f in 10:
			await get_tree().process_frame
		if not (scene.get_node("MapPanel") as Control).visible:
			_faults.append("%s: SKIP TUTORIAL did not open the chapter map"
				% case["name"])
		scene.call("_on_play_pressed")
		await get_tree().process_frame
		if prompt != null and prompt.visible:
			_faults.append("%s: the prompt came back after being declined"
				% case["name"])

		scene.queue_free()
		await get_tree().process_frame

	print("")
	if _faults.is_empty():
		print("title screen OK -- TUTORIAL in the stack, prompt offered once")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)
