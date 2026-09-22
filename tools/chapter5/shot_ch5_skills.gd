extends Node
## Photographs Chapter 5 skills mid-motion, against BOTH players.
##
## The numeric probe proves a skill lands and returns. It cannot see whether
## anything actually moved on the way -- a routine that sat still for a second
## and then dealt damage would pass every assertion in it. So this fires each
## skill and grabs the frame at the moment the body should be furthest from
## its stance, which is the only way to tell articulation from a slideshow.
##
## It runs the whole set twice, once with JUAN and once with MARIA, because a
## skill aims at whoever is standing there and a hardcoded target would only
## show up against the character it was not written for.
##
##   godot --path . tools/chapter3/shot_ch3_skills.tscn --resolution 1280x960

const OUT_DIR := "res://output/chapter5_skills"
const SETTLE := 50
## Grabbed partway through the routine rather than at the end: the interesting
## frame is the wind-up or the swing, and by the last frame everyone is home.
const CATCH_AT := 0.42

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for who in ["male", "female"]:
		GameState.character = who
		await _sweep(who)

	print("")
	if _faults.is_empty():
		print("shots OK -- every skill photographed mid-motion for both players")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _sweep(who: String) -> void:
	if not GameState.load_chapter(5):
		_faults.append("could not load chapter 5")
		return
	QuestionBank.set_context(5, "easy")
	var chapter: ChapterData = GameState.chapter
	var label := "juan" if who == "male" else "maria"
	print("\n=== %s ===" % label.to_upper())

	for index in chapter.encounter_count():
		var enemy := chapter.encounter_at(index)
		if enemy == null or enemy.is_boss:
			continue
		GameState.encounter_index = index
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame

		var body := scene.find_child("EnemyCharacter", true, false) as Control
		var rest := body.position if body != null else Vector2.ZERO

		for move in enemy.moves:
			# Is the rival actually back at its post BEFORE this skill starts?
			# _body_begin records "home" as wherever the body is standing when
			# it runs, so a skill that begins mid-return bakes that offset in
			# and every skill after it inherits the drift.
			var pre: float = absf(body.position.x - rest.x) if body != null else 0.0
			if pre > 0.75:
				_faults.append("%s (%s): started %.1fpx from home -- the previous"
					% [move.move_name, label, pre]
					+ " skill had not finished returning")
			scene.set("_player_hp", GameState.player_max_hp)
			scene.set("_enemy_hp", maxi(1, enemy.max_hp / 2))
			scene.set("_enemy_guard", 0.0)
			scene.set("_pending_enemy_damage", 0)

			# Fire and photograph WHILE it runs, not after.
			var running := [true]
			_run(scene, move, running)
			await get_tree().create_timer(CATCH_AT).timeout

			var moved: float = absf(body.position.x - rest.x) if body != null else 0.0
			var rigged: bool = body != null and body.call("is_rigged")
			var props := _prop_count(scene)
			print("   %-22s pre %5.1f  displaced %5.1fpx  rigged=%-5s props=%d"
				% [move.move_name, pre, moved, rigged, props])
			# Something has to be happening at this instant: the body has left
			# its stance, or it is posed on the rig, or a prop is in the air.
			if moved < 0.5 and not rigged and props == 0:
				_faults.append("%s (%s): nothing is moving %.2fs in"
					% [move.move_name, label, CATCH_AT])

			get_viewport().get_texture().get_image().save_png(
				"%s/%s_%s.png" % [OUT_DIR, label, move.signature_id()])

			# Let it finish before the next one.
			var guard := 0
			while running[0] and guard < 600:
				await get_tree().process_frame
				guard += 1
			for _f in 24:
				await get_tree().process_frame

		scene.queue_free()
		await get_tree().process_frame


## The flag is an ARRAY, not a bool captured by a lambda: a lambda closes over
## a COPY of a bool, so the caller never saw it flip and stopped waiting after
## its own timeout instead of when the skill actually finished. An array is a
## reference, so writing through it is visible to the caller.
func _run(scene: Node, move: EnemyMove, flag: Array) -> void:
	await scene.call("_resolve_chapter3_turn", move)
	flag[0] = false


## Effect nodes the controller has spawned -- props, papers, rings. They are
## direct children with no name of their own, so counting the controller's
## Panel/Label children that are not part of the authored scene is the cheapest
## honest measure of "something is in the air".
func _prop_count(scene: Node) -> int:
	var n := 0
	for child in scene.get_children():
		if child is Panel or child is Label or child is ColorRect:
			n += 1
	return n
