extends Node
## Checks the Patch Notes scroll and the panel it opens, in all three layouts.
##
## The thing most likely to go wrong is not the panel but the BUTTON: it is
## placed by hand in a corner that only exists on some arrangements, and the
## title screen has a logo, a menu column and a plaza all competing for those
## corners. A button that lands under the logo, off the screen, or on top of
## PLAY still "works" -- it just cannot be seen or hit. So this measures where
## it actually ended up and what it overlaps.
##
##   godot --path . tools/menu/probe_patch_notes.tscn --resolution 1280x960

const OUT_DIR := "res://output/menu"
const SETTLE := 45
const CASES := [
	{"name": "wide", "window": Vector2i(1280, 960)},
	{"name": "portrait", "window": Vector2i(390, 844)},
	{"name": "landscape", "window": Vector2i(844, 390)},
]

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for case in CASES:
		DisplayServer.window_set_size(case["window"])
		await get_tree().process_frame
		var scene: Node = load("res://scenes/main_menu.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame

		var name: String = case["name"]
		var button: Button = scene.get("_patch_button")
		var panel: PanelContainer = scene.get("_patch_panel")
		if button == null or panel == null:
			_faults.append("%s: the patch notes were never built" % name)
			scene.queue_free()
			continue

		var d: Vector2 = Layout.profile.design_size
		var rect := button.get_global_rect()
		print("  %-10s button %s   screen %s" % [name, rect, d])

		# On screen, whole.
		if rect.position.x < 0.0 or rect.position.y < 0.0 \
				or rect.end.x > d.x + 0.5 or rect.end.y > d.y + 0.5:
			_faults.append("%s: the scroll runs off the screen (%s in %s)"
				% [name, rect, d])
		# In the top HALF and the right HALF -- it was asked for in the top
		# right corner, and a button that drifts to the middle is not that.
		if rect.get_center().x < d.x * 0.5:
			_faults.append("%s: the scroll is on the left half" % name)
		if rect.get_center().y > d.y * 0.5:
			_faults.append("%s: the scroll is in the bottom half" % name)
		# Not buried under the logo or the menu.
		for other_name in ["TitleLogo", "Menu"]:
			var other := scene.get_node_or_null(other_name) as Control
			if other != null and other.visible \
					and other.get_global_rect().intersects(rect):
				_faults.append("%s: the scroll overlaps %s" % [name, other_name])
		# Big enough to hit with a finger.
		if rect.size.x < 40.0 or rect.size.y < 40.0:
			_faults.append("%s: the scroll is only %s" % [name, rect.size])

		var caption := button.find_child("Caption", true, false) as Label
		var art := button.find_child("Icon", true, false) as TextureRect
		if caption == null or art == null or art.texture == null:
			_faults.append("%s: the scroll is missing its icon or caption" % name)
		elif caption.get_global_rect().end.y > rect.end.y + 0.5:
			_faults.append("%s: the caption spills out of the button" % name)

		get_viewport().get_texture().get_image().save_png(
			"%s/patch_button_%s.png" % [OUT_DIR, name])

		# And the panel it opens.
		scene.call("_on_patch_notes_pressed")
		for _f in 25:
			await get_tree().process_frame
		if not panel.visible:
			_faults.append("%s: the panel did not open" % name)
		else:
			var body := panel.get_child(0) as Control
			var over: float = body.get_global_rect().end.y - panel.get_global_rect().end.y
			if over > 0.5:
				_faults.append("%s: the panel's content runs %d units past it"
					% [name, over])
			var notes := panel.find_child("PatchNotesText", true, false) as RichTextLabel
			var shown := notes.get_parsed_text()
			for wanted in ["v1.3", "v1.2", "v1.1", "Chapter 2", "Tutorial"]:
				if not shown.contains(wanted):
					_faults.append("%s: the notes never mention %s" % [name, wanted])
			get_viewport().get_texture().get_image().save_png(
				"%s/patch_panel_%s.png" % [OUT_DIR, name])

		# CLOSE has to actually close it.
		scene.call("_on_close_panels")
		for _f in 10:
			await get_tree().process_frame
		if panel.visible:
			_faults.append("%s: CLOSE left the panel open" % name)

		scene.queue_free()
		await get_tree().process_frame

	print("")
	if _faults.is_empty():
		print("patch notes OK -- scroll placed and hittable, panel opens and closes")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)
