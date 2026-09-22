extends Node
## Checks the Chapter 3 bank as the GAME sees it, not as the JSON file reads.
##
## QuestionBank._load_bank drops any question whose answer is not a single run
## of 3-24 letters -- with a push_warning nobody reads -- so a bank that looks
## like 150 entries on disk can be 143 in play. Counting through the loaded
## pool is the only way to see that. It then pulls a full lap per difficulty
## and boots the real battle so the prompt is rendered by the game's own
## masking rather than by an idea of it.
const WANT := 50
var _faults: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	var pool: Dictionary = QuestionBank._by_chapter.get(3, {})
	if pool.is_empty():
		_faults.append("chapter 3 has no pool at all")
	for tier in ["easy", "medium", "hard"]:
		var n: int = (pool.get(tier, []) as Array).size()
		print("   %-7s loaded %d" % [tier, n])
		if n != WANT:
			_faults.append("%s holds %d, expected %d -- the rest were dropped as unspellable"
				% [tier, n, WANT])

	# A full lap per tier: every question served must belong to chapter 3.
	for tier in ["easy", "medium", "hard"]:
		QuestionBank.set_context(3, tier)
		var seen := {}
		for i in 60:
			var q: Dictionary = QuestionBank.next_question()
			if q.is_empty():
				continue
			seen[q.get("answer", "")] = true
			if int(q.get("chapter", 0)) != 3:
				_faults.append("%s lap served a chapter %s question" % [tier, q.get("chapter")])
		print("   %-7s lap served %d distinct answers" % [tier, seen.size()])
		if seen.size() < WANT:
			_faults.append("%s lap only reached %d of %d" % [tier, seen.size(), WANT])

	# And the real screen, so the mask is the game's.
	GameState.load_chapter(3)
	GameState.encounter_index = 0
	GameState.difficulty = "easy"
	QuestionBank.set_context(3, "easy")
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	get_tree().root.add_child(scene)
	for _f in 55:
		await get_tree().process_frame
	var label := scene.find_child("QuestionLabel", true, false) as Label
	if label == null or label.text.strip_edges().is_empty():
		_faults.append("no question rendered on the battle screen")
	else:
		print("\n   on screen: %s" % label.text)
		if not label.text.contains("_"):
			_faults.append("the rendered prompt carries no letter mask: %s" % label.text)
		if label.text.contains("**") or label.text.contains("___"):
			_faults.append("markup or raw blank leaked to the screen: %s" % label.text)
	scene.queue_free()
	await get_tree().process_frame

	print("")
	if _faults.is_empty():
		print("chapter 3 bank OK -- 150 loaded, every lap in-chapter, prompt renders masked")
		get_tree().quit(0)
		return
	for f in _faults:
		print("  FAULT  %s" % f)
	get_tree().quit(1)
