extends Node
## Drives one full attack for every Chapter 2 rival and checks the state it
## leaves behind.
##
## The new strike structure enables the cut-out rig for the wind-up and the
## follow-through and hands it back in between. That is two extra places a
## character can be left in a broken state, and both are invisible in a still:
##
##   rig_enable() sets self_modulate.a = 0, so a rig that is never disabled
##   leaves the rival INVISIBLE for the rest of the fight.
##   The rig is rebuilt from the node's rect, so a strike that returns the body
##   to the wrong place strands every later pose with it.
##
## So this asserts the things a screenshot cannot: still visible, back on its
## mark, unrigged, and the sequence actually returned rather than hanging.

const CHAPTER := 2
## Generous: the longest signature runs about three seconds including travel.
const TIMEOUT := 8.0


func _ready() -> void:
	await get_tree().process_frame
	var chapter: ChapterData = load("res://data/chapters/chapter_%02d.tres" % CHAPTER)
	var faults: Array[String] = []

	for i in chapter.encounters.size():
		var rival: EnemyData = chapter.encounters[i]
		GameState.load_chapter(CHAPTER)
		GameState.encounter_index = i
		GameState.character = "female" if i % 2 == 1 else "male"

		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		add_child(scene)
		for _f in 90:
			await get_tree().process_frame

		var foe: AnimatedCharacter = scene.get("enemy_character")
		var home := foe.position
		var alpha := foe.self_modulate.a

		# EVERY move, not just the first. Eighteen skills now carry their own
		# clip and the shared fallback covers the rest; testing moves[0] alone
		# would exercise one of those paths per rival and miss the other.
		for m in rival.moves:
			var mv: EnemyMove = m
			var clip := mv.attack_dir
			if not clip.is_empty() and not ResourceLoader.exists("%s/frame_0.png" % clip):
				faults.append("%s / %s: attack_dir does not resolve (%s)"
					% [rival.enemy_name, mv.move_id, clip])
		var move: EnemyMove = rival.moves[rival.moves.size() - 1] if not rival.moves.is_empty() else null
		var name := move.move_id if move != null else "(none)"
		var started := Time.get_ticks_msec()
		var finished := false
		if move != null:
			# Awaited, not fired and sampled. An earlier version watched for the
			# body to stop moving instead, and that reports success in the middle
			# of a melee approach -- the travel beats are chained, so the node is
			# genuinely still for a moment between them.
			await scene.call("_play_signature_move", move)
			finished = true
		# Let the closing tweens land before reading the end state.
		for _f in 30:
			await get_tree().process_frame

		var drift := foe.position.distance_to(home)
		var vis := foe.self_modulate.a
		var rigged: bool = foe.is_rigged()
		print("  e%d %-16s %-22s home_drift=%5.1f  alpha=%.2f  rigged=%s  settled=%s" % [
			i + 1, rival.enemy_name, name, drift, vis, rigged, finished])
		if not finished:
			faults.append("%s never came to rest within %.0fs" % [rival.enemy_name, TIMEOUT])

		if vis < alpha - 0.01:
			faults.append("%s left invisible (alpha %.2f) -- a rig was not handed back"
				% [rival.enemy_name, vis])
		if rigged:
			faults.append("%s left rigged" % rival.enemy_name)
		if drift > 2.0:
			faults.append("%s ended %.1fpx off its mark" % [rival.enemy_name, drift])

		scene.queue_free()
		await get_tree().process_frame

	if faults.is_empty():
		print("\nOK -- every rival struck, stayed visible and came home")
	else:
		print("\nFAULTS: %d" % faults.size())
		for f in faults:
			print("  - ", f)
	get_tree().quit()
