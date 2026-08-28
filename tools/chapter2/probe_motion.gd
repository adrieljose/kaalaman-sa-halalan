extends Node
## Samples an enemy's position every frame through a real skill.
##
## "Feels jerky" is not something to fix by guessing. A frame where the sprite
## does not move at all is a stall; a frame where its velocity jumps sharply is
## a jerk. Both are measurable, so measure them and fix what the numbers show.

const MOVES := ["kaban_ng_bayan", "stamp_slam", "briefcase_beatdown",
	"codex_crusher", "backdoor_dash"]

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
		var sampling := true
		_sample(rival, samples, func(): return sampling)
		await scene._play_signature_move(by_id[move_id])
		sampling = false
		await get_tree().process_frame
		_report(move_id, samples)

func _sample(rival: Control, out: Array, still_going: Callable) -> void:
	while still_going.call():
		await get_tree().process_frame
		out.append(rival.position)
	get_tree().quit(0)

func _report(move_id: String, s: Array) -> void:
	var stalls := 0
	var moving := 0
	var max_jerk := 0.0
	var at := 0
	var detail := ""
	for i in range(2, s.size()):
		var v1: Vector2 = s[i - 1] - s[i - 2]
		var v2: Vector2 = s[i] - s[i - 1]
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
	print("%-22s frames=%3d  moving=%3d  mid-motion stalls=%2d  peak velocity jump=%5.1f px/f" % [
		move_id, s.size(), moving, stalls, max_jerk])
