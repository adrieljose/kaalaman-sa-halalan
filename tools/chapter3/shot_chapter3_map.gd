extends Node
## Photographs the chapter map now that chapter_03.tres exists.
##
## The map unlocks a chapter by asking whether its data is on disk, so landing
## Chapter 3's resources lights its pin without anyone editing the menu. What
## that does NOT guarantee is that there is any island painted under the pin --
## the marker points were authored against the map artwork, and a pin over open
## water is still a pin that "works".
##
## The pins are looked up with find_child rather than by path: _group_map()
## reparents everything named Chapter* into a MapGroup wrapper at runtime so
## the illustration can be scaled as one piece, and a path written against the
## scene file finds nothing after that.
##
## There are also TWO presentations -- the illustration on wide screens and a
## button list on compact ones -- and a chapter that is unlocked in one and
## locked in the other is a chapter half-shipped. Both are checked.
##
##   godot --path . tools/chapter3/shot_chapter3_map.tscn --resolution 1280x960

const OUT_DIR := "res://output/chapter3"
const SETTLE := 45
const CASES := [
	{"name": "wide", "window": Vector2i(1280, 960)},
	{"name": "portrait", "window": Vector2i(390, 844)},
]

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for case in CASES:
		DisplayServer.window_set_size(case["window"])
		await get_tree().process_frame
		await _check(String(case["name"]))

	print("")
	if _faults.is_empty():
		print("map OK -- chapter 3 is lit and hittable in both presentations")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _check(case_name: String) -> void:
	var scene: Node = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(scene)
	for _f in SETTLE:
		await get_tree().process_frame

	var unlocked: int = scene.call("unlocked_chapters")
	if unlocked < 3:
		_faults.append("%s: chapter 3 is on disk but the map stops at %d"
			% [case_name, unlocked])

	scene.call("_on_play_pressed")
	for _f in 30:
		await get_tree().process_frame

	var map: Control = scene.get_node_or_null("MapPanel")
	if map == null:
		_faults.append("%s: no MapPanel" % case_name)
		scene.queue_free()
		await get_tree().process_frame
		return

	var group := map.get_node_or_null("MapGroup") as Control
	var list := map.get_node_or_null("MapList") as Control
	var illustrated: bool = group != null and group.visible
	print("%s: showing the %s" % [case_name, "illustration" if illustrated else "list"])

	# --- the illustrated pin, wherever it now lives ---
	var pin := map.find_child("Chapter3Button", true, false) as Button
	var label := map.find_child("Chapter3Label", true, false) as Label
	if pin == null:
		_faults.append("%s: no map pin for chapter 3" % case_name)
	elif pin.disabled:
		_faults.append("%s: the chapter 3 pin is disabled" % case_name)
	else:
		# The gold tint is the "available" look; grey is how a locked chapter
		# is drawn, and the caption carrying "(LOCKED)" is the other half.
		print("   pin at %s  tint %s" % [pin.position, pin.self_modulate])
		if pin.self_modulate.r < 0.9:
			_faults.append("%s: the chapter 3 pin is still drawn as locked (%s)"
				% [case_name, pin.self_modulate])
	if label == null:
		_faults.append("%s: no caption for chapter 3" % case_name)
	else:
		print("   caption \"%s\"" % label.text)
		if label.text.contains("LOCKED"):
			_faults.append("%s: chapter 3 still reads as locked: \"%s\""
				% [case_name, label.text])

	# --- and the compact list, which is a separate set of buttons ---
	if list != null:
		var found := false
		for child in list.get_children():
			var button := child as Button
			if button == null or not button.text.begins_with("3"):
				continue
			found = true
			print("   list entry \"%s\" disabled=%s" % [button.text, button.disabled])
			if button.disabled:
				_faults.append("%s: the chapter 3 list entry is disabled" % case_name)
		if not found:
			_faults.append("%s: the chapter list has no entry for chapter 3" % case_name)

	get_viewport().get_texture().get_image().save_png(
		"%s/chapter_map_%s.png" % [OUT_DIR, case_name])

	scene.queue_free()
	await get_tree().process_frame
