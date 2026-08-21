extends Node
## Loads the election question bank once at startup and serves questions
## filtered to the chapter being played and the difficulty chosen.
##
## Questions live in a plain JSON file rather than one .tres per question —
## adding or editing a question should not require opening Godot.

const BANK_PATH := "res://data/questions/questions.json"
## Order matters here — this is the ramp an unfiltered lap follows.
const DIFFICULTY_ORDER: Array[String] = ["easy", "medium", "hard"]
## Every question belongs to a chapter, so the topic matches where the player
## is: barangay questions in Chapter 1, Congress questions in Chapter 5. A
## question whose chapter is missing or unknown lands here.
const DEFAULT_CHAPTER := 1

## Questions keyed [chapter][difficulty] -> Array. Two levels rather than one
## flat list so a lap can be assembled without re-scanning the whole bank.
var _by_chapter: Dictionary = {}
var _order: Array[Dictionary] = []
var _next: int = 0
## Empty means "no filter": serve everything as an easy→medium→hard ramp, which
## is what booting the battle scene directly for testing gets.
var _difficulty: String = ""
## 0 means "every chapter". Set to a chapter number to restrict the pool.
var _chapter: int = 0

func _ready() -> void:
	_load_bank()

func _load_bank() -> void:
	_by_chapter.clear()

	var file := FileAccess.open(BANK_PATH, FileAccess.READ)
	if file == null:
		push_warning("QuestionBank: could not open %s" % BANK_PATH)
		return
	var raw := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("QuestionBank: %s is not a JSON array" % BANK_PATH)
		return

	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if not entry.has("prompt") or not entry.has("answer"):
			continue
		# Answers are spelled from tiles, so they must be a single run of
		# letters — anything else could never be entered on the board.
		var answer := String(entry["answer"]).strip_edges().to_upper()
		if not _is_spellable(answer):
			push_warning("QuestionBank: skipping unspellable answer '%s'" % answer)
			continue

		var tier := String(entry.get("difficulty", "medium")).to_lower()
		if not DIFFICULTY_ORDER.has(tier):
			tier = "medium"
		var chapter_no := int(entry.get("chapter", DEFAULT_CHAPTER))

		if not _by_chapter.has(chapter_no):
			_by_chapter[chapter_no] = {}
			for t in DIFFICULTY_ORDER:
				_by_chapter[chapter_no][t] = []
		_by_chapter[chapter_no][tier].append({
			"prompt": String(entry["prompt"]),
			"answer": answer,
			# How the term reads to a human, when that differs from how it has
			# to be spelled on the board: "PUNONG BARANGAY" vs PUNONGBARANGAY.
			# Defaults to the answer itself, so single-word entries need no
			# field in the JSON at all.
			"display": String(entry.get("display", answer)),
			"fact": String(entry.get("fact", "")),
			"difficulty": tier,
			"chapter": chapter_no,
			# Content-area tag (voting / fraud / candidate / why) — carried
			# through for any future UI that wants to show or filter by it.
			# Not currently used to filter the lap; chapter + difficulty are.
			"category": String(entry.get("category", "")),
		})
	_reshuffle()

## No hard ceiling tied to a specific board size — 24 letters is just a sanity
## bound so a malformed entry can't produce an answer no board could ever fit
## (the board itself is 6x6 = 36 cells). Raised from 20 to 24 to fit a couple
## of concatenated multi-word terms (e.g. RESPONSIBLEGOVERNANCE, 21 letters)
## in the chapter 1 bank.
func _is_spellable(answer: String) -> bool:
	if answer.length() < 3 or answer.length() > 24:
		return false
	for ch in answer:
		if ch < "A" or ch > "Z":
			return false
	return true

## Points the bank at one chapter's topic and one difficulty. Both are applied
## together because they are set at the same moment — when a run starts — and
## rebuilding the lap twice would be wasted work.
##
## Pass chapter 0 or difficulty "" to leave that axis unfiltered.
func set_context(chapter_no: int, tier: String) -> void:
	var wanted_tier := tier.to_lower()
	if not wanted_tier.is_empty() and not DIFFICULTY_ORDER.has(wanted_tier):
		push_warning("QuestionBank: unknown difficulty '%s', serving all tiers" % tier)
		wanted_tier = ""
	if chapter_no > 0 and not _by_chapter.has(chapter_no):
		push_warning("QuestionBank: no questions for chapter %d, serving all chapters" % chapter_no)
		chapter_no = 0
	_chapter = chapter_no
	_difficulty = wanted_tier
	_reshuffle()

## Kept for callers that only care about difficulty (and for tests).
func set_difficulty(tier: String) -> void:
	set_context(_chapter, tier)

func difficulty() -> String:
	return _difficulty

func current_chapter() -> int:
	return _chapter

## Chapter numbers the bank actually holds questions for, in order. Used by the
## reviewer to draw one tab per chapter rather than hard-coding a count.
func chapters_available() -> Array:
	var all := _by_chapter.keys()
	all.sort()
	return all

## Every question in one chapter/tier pool, for browsing rather than playing.
##
## Deliberately separate from next_question(): reading the bank to display it
## must not disturb the lap the battle scene is partway through, so this touches
## neither `_order` nor `_next`. The returned array is a copy, so a caller
## sorting or filtering it cannot reorder the bank itself.
func entries_for(chapter_no: int, tier: String) -> Array:
	var tiers: Dictionary = _by_chapter.get(chapter_no, {})
	return (tiers.get(tier.to_lower(), []) as Array).duplicate()

## Which tiers a lap draws from: just the chosen one, or all three in ramp
## order when nothing was chosen.
func _active_tiers() -> Array:
	if _difficulty.is_empty():
		return DIFFICULTY_ORDER
	return [_difficulty]

## Which chapters a lap draws from: just the current one, or all of them in
## order when unfiltered.
func _active_chapters() -> Array:
	if _chapter > 0:
		return [_chapter]
	var all := _by_chapter.keys()
	all.sort()
	return all

## Rebuilds the lap. Chapter is the outer axis and difficulty the inner one, so
## an unfiltered session still walks chapter 1 easy→hard, then chapter 2, and
## so on, rather than shuffling every topic together.
##
## If the requested chapter/tier combination turns out to be empty, the whole
## bank is used instead — better to ask an off-topic question than to leave the
## player with a board and nothing to answer.
func _reshuffle() -> void:
	_order.clear()
	for chapter_no in _active_chapters():
		var tiers: Dictionary = _by_chapter.get(chapter_no, {})
		for tier in _active_tiers():
			var pool: Array = (tiers.get(tier, []) as Array).duplicate()
			pool.shuffle()
			for q in pool:
				_order.append(q)
	if _order.is_empty() and not _by_chapter.is_empty():
		push_warning("QuestionBank: chapter %d / '%s' is empty, falling back to the full bank"
			% [_chapter, _difficulty])
		for chapter_no in _by_chapter:
			for tier in DIFFICULTY_ORDER:
				for q in _by_chapter[chapter_no][tier]:
					_order.append(q)
		_order.shuffle()
	_next = 0

func has_questions() -> bool:
	return not _order.is_empty()

func question_count() -> int:
	return _order.size()

## Returns the next question as {prompt, answer, fact, difficulty, chapter}, or
## {} if the bank is empty. Starts a fresh shuffled lap once the current one
## runs out, so a long chapter never runs dry.
func next_question() -> Dictionary:
	if _order.is_empty():
		return {}
	if _next >= _order.size():
		_reshuffle()
	var q: Dictionary = _order[_next]
	_next += 1
	return q
