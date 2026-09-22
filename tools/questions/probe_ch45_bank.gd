extends Node
## Checks the Chapter 4 and 5 banks as the GAME sees them, not as the JSON reads.
##
## QuestionBank._load_bank drops any question whose answer is not a single run
## of 3-24 letters -- with a push_warning nobody reads -- so a bank that looks
## like 150 entries on disk can be 144 in play. That is exactly the trap the
## six dated chapter-4 questions would have fallen into (1802, 1825, 1847,
## 1863, 1939, 1998), so counting through the LOADED pool is the point of this
## probe, not a formality.
##
## It then pulls a full lap per difficulty to prove every question is reachable
## and none leaks in from another chapter, and finally renders one prompt on
## the real battle screen so the letter mask is the game's own.
##
##   godot --path . tools/questions/probe_ch45_bank.tscn

const WANT := 50
const CHAPTERS := [4, 5]
const TIERS := ["easy", "medium", "hard"]
## Chapters 4 and 5 have questions but no chapter resource yet, so there is no
## scene to boot for them. The battle screen asks GameState for the chapter
## NUMBER and nothing else when it sets the question context, so chapter 3's
## resource is borrowed and its number overridden IN MEMORY for the render
## check. Nothing writes chapter resources at run time; the value is put back
## either way.
const RENDER_HOST_CHAPTER := 3

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame

	for chapter in CHAPTERS:
		print("\n=== chapter %d ===" % chapter)
		var pool: Dictionary = QuestionBank._by_chapter.get(chapter, {})
		if pool.is_empty():
			_faults.append("chapter %d has no pool at all" % chapter)
			continue

		for tier in TIERS:
			var n: int = (pool.get(tier, []) as Array).size()
			print("   %-7s loaded %d" % [tier, n])
			if n != WANT:
				_faults.append("ch%d %s holds %d, expected %d -- the rest were dropped as unspellable"
					% [chapter, tier, n, WANT])

		# A full lap per tier: every question served must belong to this chapter,
		# and the lap must reach all of them before repeating.
		for tier in TIERS:
			QuestionBank.set_context(chapter, tier)
			var seen := {}
			for i in WANT + 10:
				var q: Dictionary = QuestionBank.next_question()
				if q.is_empty():
					continue
				seen[q.get("answer", "")] = true
				if int(q.get("chapter", 0)) != chapter:
					_faults.append("ch%d %s lap served a chapter %s question"
						% [chapter, tier, q.get("chapter")])
			print("   %-7s lap served %d distinct answers" % [tier, seen.size()])
			if seen.size() < WANT:
				_faults.append("ch%d %s lap only reached %d of %d"
					% [chapter, tier, seen.size(), WANT])

		# Multi-word answers must carry a human reading; a bare concatenation
		# like TWOHUNDREDFIFTYTHOUSAND shown back as the "answer" is unreadable.
		for tier in TIERS:
			for q in (pool.get(tier, []) as Array):
				var answer := String(q.get("answer", ""))
				var display := String(q.get("display", answer))
				if answer.length() >= 12 and display == answer:
					print("   NOTE ch%d %s has no display string" % [chapter, answer])

		await _render_check(chapter)

	print("")
	if _faults.is_empty():
		print("chapter 4/5 bank OK -- 150 loaded per chapter, every lap complete, prompts render")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


## Boots the real battle screen and reads the prompt the player would see.
func _render_check(chapter: int) -> void:
	if not GameState.load_chapter(RENDER_HOST_CHAPTER):
		_faults.append("could not load the host chapter for the render check")
		return
	var host: ChapterData = GameState.chapter
	var original: int = host.chapter_number
	host.chapter_number = chapter
	GameState.encounter_index = 0
	GameState.difficulty = "easy"

	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	get_tree().root.add_child(scene)
	for _f in 55:
		await get_tree().process_frame

	var label := scene.find_child("QuestionLabel", true, false) as Label
	if label == null or label.text.strip_edges().is_empty():
		_faults.append("ch%d: no question rendered on the battle screen" % chapter)
	else:
		print("   on screen: %s" % label.text)
		if not label.text.contains("_"):
			_faults.append("ch%d: the rendered prompt carries no letter mask: %s"
				% [chapter, label.text])
		if label.text.contains("**") or label.text.contains("___"):
			_faults.append("ch%d: markup or the raw blank leaked to the screen: %s"
				% [chapter, label.text])

	scene.queue_free()
	await get_tree().process_frame
	host.chapter_number = original
