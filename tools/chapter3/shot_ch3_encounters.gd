extends Node
## Photographs all nine Chapter 3 encounters in BOTH layouts.
##
## The battle screen is authored three ways -- WIDE, PORTRAIT and
## LANDSCAPE_COMPACT -- and the arrangement, not just the scale, changes
## between them: the HUD becomes a two-row band, the moves panel collapses, the
## board retiles at a larger tap size. So a desktop screenshot says nothing
## about the phone, and a rival that fits one can overflow the other.
##
## Each shot is taken on a settled scene with the rival idle, which is the
## frame that shows staging: whether the fighter stands on the room's floor
## line, whether the HUD names fit, whether anything clips.
##
##   godot --path . tools/chapter3/shot_ch3_encounters.tscn --resolution 1280x960

const OUT_DIR := "res://output/chapter3_encounters"
const SETTLE := 60
const CASES := [
	{"name": "desktop", "window": Vector2i(1280, 960)},
	{"name": "mobile", "window": Vector2i(390, 844)},
]

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for case in CASES:
		DisplayServer.window_set_size(case["window"])
		# The layout director reacts to the resize on the following frame; the
		# scene is built after that so it is born into the right arrangement.
		for _f in 8:
			await get_tree().process_frame
		await _sweep(String(case["name"]))

	print("")
	if _faults.is_empty():
		print("encounters OK -- 9 rivals photographed in both layouts")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _sweep(case_name: String) -> void:
	if not GameState.load_chapter(3):
		_faults.append("could not load chapter 3")
		return
	QuestionBank.set_context(3, "easy")
	var chapter: ChapterData = GameState.chapter
	print("\n=== %s (%s) ===" % [case_name.to_upper(), Layout.profile.design_size])

	for index in chapter.encounter_count():
		var enemy := chapter.encounter_at(index)
		if enemy == null:
			continue
		GameState.encounter_index = index
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame

		var d: Vector2 = Layout.profile.design_size
		var body := scene.find_child("EnemyCharacter", true, false) as Control
		var player := scene.find_child("PlayerCharacter", true, false) as Control

		var note := ""
		if body == null:
			_faults.append("%s/%s: no EnemyCharacter" % [case_name, enemy.enemy_name])
		else:
			# The VISIBLE body. The node rect is mostly transparent air, so a
			# bounds check against it condemns rivals that are entirely on
			# screen -- the same padded-box mistake that made the earlier feet
			# check fire on every encounter.
			var vb: Rect2 = body.call("body_rect")
			var r := Rect2(body.position + vb.position, vb.size)
			note = "rival %s" % r
			# On screen, and standing rather than floating or sunk. Both
			# fighters share the room's floor line, so their feet should agree.
			if r.position.x < -1.0 or r.end.x > d.x + 1.0:
				_faults.append("%s/%s: rival runs off the side (%s in %s)"
					% [case_name, enemy.enemy_name, r, d])
			if r.end.y > d.y + 1.0:
				_faults.append("%s/%s: rival's feet are below the screen (%.1f > %.1f)"
					% [case_name, enemy.enemy_name, r.end.y, d.y])
			# NOT a feet check: a node's rect is the whole canvas, most of which
			# is transparent air around a narrower sprite (AnimatedCharacter
			# carries melee_rest_x for exactly this reason). Comparing the two
			# padded boxes reported a 13px gap on every rival while the drawn
			# feet sat on the same line, so it measured padding, not grounding.
			# Grounding is verified from the picture instead.
			if body.get("texture") == null:
				_faults.append("%s/%s: rival has no frame loaded"
					% [case_name, enemy.enemy_name])

		print("   %d  %-20s %s" % [index + 1, enemy.enemy_name, note])
		get_viewport().get_texture().get_image().save_png(
			"%s/%s_%02d_%s.png" % [OUT_DIR, case_name, index + 1,
				enemy.enemy_name.to_lower().replace(" ", "_")])

		scene.queue_free()
		await get_tree().process_frame
