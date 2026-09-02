extends Node
## Loads the question bank the way the game does and reports what survived.
##
## The point is the SURVIVED part: QuestionBank._is_spellable rejects a bad
## answer with push_warning and moves on, so a malformed entry does not fail
## the build -- it just quietly stops existing. Counting the pools after load
## is the only way to see that from outside.

func _ready() -> void:
	await get_tree().process_frame

	var chapters: Array = QuestionBank.chapters_available()
	print("chapters: ", chapters)

	var total := 0
	var faults: Array[String] = []
	for chapter_no: int in chapters:
		var line := "  ch%d " % chapter_no
		for tier in QuestionBank.DIFFICULTY_ORDER:
			var pool: Array = QuestionBank.entries_for(chapter_no, tier)
			total += pool.size()
			line += "%s=%d " % [tier, pool.size()]
			for entry: Dictionary in pool:
				var prompt := String(entry.get("prompt", ""))
				var answer := String(entry.get("answer", ""))
				if not prompt.contains("___"):
					faults.append("ch%d %s: no blank in %s" % [chapter_no, answer, prompt])
				if answer.length() > 24:
					faults.append("ch%d %s: %d letters" % [chapter_no, answer, answer.length()])
		print(line)
	print("total loaded: ", total)

	# The one that matters for chapter 2: every supplied question made it in.
	var ch2 := 0
	for tier in QuestionBank.DIFFICULTY_ORDER:
		ch2 += QuestionBank.entries_for(2, tier).size()
	print("chapter 2 loaded: %d (expected 150)" % ch2)

	# Play a lap the way a real hard run would, to prove the pool serves and
	# that every answer can actually be seeded onto the 6x6 board.
	QuestionBank.set_context(2, "hard")
	var seen := {}
	var longest := 0
	for i in 150:
		var q: Dictionary = QuestionBank.next_question()
		if q.is_empty():
			faults.append("lap ran dry at %d" % i)
			break
		seen[String(q["answer"])] = true
		longest = maxi(longest, String(q["answer"]).length())
	print("hard lap: %d distinct answers, longest %d, board holds 36" % [seen.size(), longest])

	if faults.is_empty():
		print("OK -- no faults")
	else:
		print("FAULTS: %d" % faults.size())
		for f in faults:
			print("  - ", f)
	get_tree().quit()
