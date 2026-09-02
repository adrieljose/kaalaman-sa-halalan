extends Node
## Photographs the potential-damage badge in all three arrangements.
##
## The badge shares the question panel with the countdown bar and with a prompt
## that wraps to three or four lines, so the thing worth checking is not that it
## renders -- it is that nothing it was squeezed in beside got clipped. That
## only shows up in a picture.
##
##   godot --path . tools/battle/shot_damage_badge.tscn --resolution 1280x960

const OUT_DIR := "res://output/damage_badge"
const SETTLE := 90
## design width x height, and the window size that produces that arrangement.
const CASES := [
	{"name": "wide", "window": Vector2i(1280, 960)},
	{"name": "portrait", "window": Vector2i(390, 844)},
	{"name": "landscape", "window": Vector2i(844, 390)},
]


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	GameState.load_chapter(1)
	GameState.encounter_index = 0
	GameState.difficulty = "easy"

	for case in CASES:
		DisplayServer.window_set_size(case["window"])
		await get_tree().process_frame
		# Parented to the ROOT VIEWPORT, not to this helper node.
		#
		# A Control under a plain Node has no parent area to anchor against, so it
		# sits at size zero -- and a scene staged that way never reproduces what the
		# real game does when a full-rect child grows from nothing to the whole
		# screen. That gap hid a crash: the tutorial director answers its first
		# NOTIFICATION_RESIZED by placing a card it had not built yet, which under a
		# zero-sized parent never fired at all. Staged here the way the game stages
		# it, so a size-dependent failure fails here too.
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame

		var badge: DamageBadge = scene.get("_damage_badge")
		var panel: Control = scene.get("question_panel")
		var label: Label = scene.get("question_label")
		print("%-10s %s  badge '%s' rect %s   panel %s   prompt %d lines, %s" % [
			case["name"], case["window"], badge.damage_text(),
			badge.get_global_rect(), panel.get_global_rect(),
			label.get_line_count(),
			"FITS" if label.get_line_count() <= label.get_visible_line_count()
				or label.get_visible_line_count() <= 0 else "CLIPPED"])

		var path := "%s/%s.png" % [OUT_DIR, case["name"]]
		var err := get_viewport().get_texture().get_image().save_png(path)
		if err != OK:
			print("  save failed (%d)" % err)
		scene.queue_free()
		await get_tree().process_frame

	get_tree().quit(0)
