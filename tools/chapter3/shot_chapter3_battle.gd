extends Node
## Photographs Chapter 3 encounters in the real battle scene.
##
## Two things here cannot be proved by loading a resource. The first is that
## the rivals are actually ON SCREEN -- an empty clip leaves an invisible
## fighter standing on the floor and every check about paths still passes. The
## second is the moves panel: Chapter 3's skills have no icons yet, and a null
## texture flowing into the icon slot is exactly the kind of thing that either
## renders as an empty frame (fine) or collapses the row (not fine).
##
##   godot --path . tools/chapter3/shot_chapter3_battle.tscn --resolution 1280x960

const OUT_DIR := "res://output/chapter3"
const SETTLE := 60
## First, middle and boss -- enough to cover a default-staged room, a room with
## measured offsets, and the two-phase arena.
const ENCOUNTERS := [0, 1, 2, 3, 4, 5, 6, 7, 8]

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	if not GameState.load_chapter(3):
		_faults.append("GameState refused to load chapter 3")
		_report()
		return
	QuestionBank.set_context(3, "easy")

	for index in ENCOUNTERS:
		await _shoot(int(index))

	_report()


func _shoot(index: int) -> void:
	GameState.encounter_index = index
	var enemy: EnemyData = GameState.current_enemy()
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	get_tree().root.add_child(scene)
	for _f in SETTLE:
		await get_tree().process_frame

	print("encounter %d  %s" % [index + 1, enemy.enemy_name])

	# --- is the rival actually drawn? ---
	var body := scene.find_child("EnemyCharacter", true, false) as Control
	if body == null:
		_faults.append("%s: no EnemyCharacter node" % enemy.enemy_name)
	else:
		var tex: Texture2D = body.get("texture")
		if tex == null:
			_faults.append("%s is on screen with no frame loaded" % enemy.enemy_name)
		elif body.size.x <= 1.0 or body.size.y <= 1.0:
			_faults.append("%s is drawn at %s" % [enemy.enemy_name, body.size])
		else:
			print("   body %s  frame %dx%d"
				% [body.size, tex.get_width(), tex.get_height()])

	# --- the moves panel, with every icon null ---
	var plates := 0
	for move in enemy.moves:
		var plate := scene.find_child("Move_%s" % move.move_name.replace(" ", ""), true, false) as Control
		if plate == null:
			# A phase-2 move is legitimately absent from the panel in phase 1.
			if move.min_phase <= 1:
				_faults.append("%s: no panel entry for %s"
					% [enemy.enemy_name, move.move_name])
			continue
		plates += 1
		var slot := plate.find_child("IconSlot", true, false) as Control
		if slot == null:
			_faults.append("%s: %s has no icon slot"
				% [enemy.enemy_name, move.move_name])
		elif slot.size.x < 8.0 or slot.size.y < 8.0:
			# The whole point of this probe: a null icon must leave the slot
			# standing at its authored size, not collapse the row around it.
			_faults.append("%s: %s's empty icon slot collapsed to %s"
				% [enemy.enemy_name, move.move_name, slot.size])
		if plate.size.y < 16.0:
			_faults.append("%s: %s's plate collapsed to %s"
				% [enemy.enemy_name, move.move_name, plate.size])
	print("   %d move plates drawn" % plates)

	get_viewport().get_texture().get_image().save_png(
		"%s/battle_%02d_%s.png" % [OUT_DIR, index + 1,
			enemy.enemy_name.to_lower().replace(" ", "_")])

	scene.queue_free()
	await get_tree().process_frame


func _report() -> void:
	print("")
	if _faults.is_empty():
		print("chapter 3 battles OK -- rivals drawn, move panel survives empty icons")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)
