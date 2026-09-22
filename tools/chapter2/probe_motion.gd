extends Node
## Samples an enemy's position every frame through a real skill.
##
## "Feels jerky" is not something to fix by guessing. A frame where the sprite
## does not move at all is a stall; a frame where its velocity jumps sharply is
## a jerk. Both are measurable, so measure them and fix what the numbers show.

const MOVES := ["stamp_slam", "kaban_ng_bayan"]

func _ready() -> void:
	await get_tree().process_frame
	GameState.load_chapter(2)
	GameState.encounter_index = 8
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	add_child(scene)
	for i in 90:
		await get_tree().process_frame

	var rival: Control = scene.get_node("EnemyCharacter")
	var chapter = load("res://data/chapters/chapter_02.tres")
	var by_id := {}
	for enemy in chapter.encounters:
		for m in enemy.moves:
			by_id[m.signature_id()] = m

	for move_id in MOVES:
		if not by_id.has(move_id):
			continue
		# Sampled from a sibling coroutine while the move is AWAITED properly.
		# Polling for stillness instead let the next move start on top of the
		# previous one's tail, and the "teleport" that showed up was two moves
		# overlapping in the harness rather than anything the game does.
		var samples: Array = []
		# A mutable reference is used deliberately. Capturing a primitive boolean
		# in the sampler can leave the coroutine observing the original value and
		# running forever after the test body has finished.
		var sampling := {"active": true}
		_sample(rival, samples, func(): return sampling["active"])
		await scene._play_signature_move(by_id[move_id])
		sampling["active"] = false
		await get_tree().process_frame
		_report(move_id, samples)

	scene.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)

func _sample(rival: Control, out: Array, still_going: Callable) -> void:
	while still_going.call():
		await get_tree().process_frame
		# Rotation and scale matter as much as position: the idle pose writes
		# both every frame, and if handing the body to a skill zeroes them in
		# one frame the sprite visibly pops even though it never moved.
		out.append({"p": rival.position, "r": rival.rotation, "s": rival.scale})

func _report(move_id: String, s: Array) -> void:
	var stalls := 0
	var moving := 0
	var max_jerk := 0.0
	var at := 0
	var detail := ""
	var max_rot_pop := 0.0
	var max_scale_pop := 0.0
	for i in range(1, s.size()):
		max_rot_pop = maxf(max_rot_pop,
			absf(rad_to_deg(s[i]["r"]) - rad_to_deg(s[i - 1]["r"])))
		max_scale_pop = maxf(max_scale_pop,
			(s[i]["s"] - s[i - 1]["s"]).length())
	for i in range(2, s.size()):
		var v1: Vector2 = s[i - 1]["p"] - s[i - 2]["p"]
		var v2: Vector2 = s[i]["p"] - s[i - 1]["p"]
		if v2.length() < 0.05 and v1.length() > 0.5:
			stalls += 1          # was travelling, then froze for a frame
		if v2.length() > 0.05:
			moving += 1
		var j := (v2 - v1).length()
		if j > max_jerk:
			max_jerk = j
			at = i
			detail = "v %s -> %s" % [v1, v2]
	if max_jerk > 8.0:
		print("    peak at frame %d of %d: %s" % [at, s.size(), detail])
	print("%-22s stalls=%2d  vel jump=%5.1f px/f  rot pop=%5.2f deg/f  scale pop=%.4f/f" % [
		move_id, stalls, max_jerk, max_rot_pop, max_scale_pop])
