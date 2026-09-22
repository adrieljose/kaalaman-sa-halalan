extends Node
## Checks that chapter 2 opens only after chapter 1 is finished on all three
## difficulties, and that a locked chapter says WHY it is locked.
##
## unlocked_chapters() cannot be read directly here: it lifts both locks under
## OS.has_feature("editor"), which is true for every `godot --path .` run
## including this one. So the two halves are probed for what they actually
## decide -- earned_chapters() carries the progression rule and has no editor
## bypass -- and the shipped answer is recomposed the same way
## unlocked_chapters() composes it.
##
##   godot --path . tools/progression/probe_chapter_gate.tscn

const SAVE := "user://progress.save"
const BACKUP := "user://progress.save.probe_backup"

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_stash_save()

	# A player who has never finished anything.
	GameState.certificate_earned = {}
	GameState._session_tier_progress = {}
	_expect(1, "nothing beaten")
	_expect_shipped(1, "nothing beaten")

	# Easy alone, then Easy and Medium: still not enough. The climb has to be
	# complete before the next chapter is anyone's business.
	GameState.mark_difficulty_completed(1, "easy")
	_expect(1, "chapter 1 easy only")
	_expect_shipped(1, "chapter 1 easy only")
	GameState.mark_difficulty_completed(1, "medium")
	_expect(1, "chapter 1 easy + medium")
	_expect_shipped(1, "chapter 1 easy + medium")

	# Hard closes it, and chapter 2 opens.
	GameState.mark_difficulty_completed(1, "hard")
	_expect(2, "chapter 1 all three tiers")
	_expect_shipped(2, "chapter 1 all three tiers")
	if not GameState.is_chapter_completed(1):
		_faults.append("chapter 1 was not recorded as completed")

	# And it stays open across a reload: this is the one fact GameState writes
	# to disk, so a player who earned chapter 2 yesterday still has it today.
	GameState.certificate_earned = {}
	GameState._load_progress()
	if MainMenu.earned_chapters() != 2:
		_faults.append("chapter 2 did not survive a reload of the save file")

	# Chapter 3 needs chapter 2 finished the same way -- the rule is the ladder,
	# not a special case written for chapter 2.
	_expect(2, "chapter 2 not yet beaten")
	GameState.mark_difficulty_completed(2, "easy")
	GameState.mark_difficulty_completed(2, "medium")
	GameState.mark_difficulty_completed(2, "hard")
	_expect(3, "chapter 2 all three tiers")

	await _check_toast_wording()

	_restore_save()
	print("")
	if _faults.is_empty():
		print("chapter gate OK -- chapter 2 needs all three tiers of chapter 1, and says so")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _expect(want: int, when: String) -> void:
	var got := MainMenu.earned_chapters()
	print("   earned after %-32s -> %d" % [when, got])
	if got != want:
		_faults.append("after %s, earned_chapters() = %d, expected %d" % [when, got, want])


## What the shipped build would allow: the stricter of the release cap and the
## progression ladder, which is exactly what unlocked_chapters() computes once
## the editor bypass is out of the way.
func _expect_shipped(want: int, when: String) -> void:
	var got: int = mini(MainMenu.RELEASE_CAP, MainMenu.earned_chapters())
	if got != want:
		_faults.append("in a shipped build, %s would unlock %d chapters, expected %d"
			% [when, got, want])


## The notice has to tell the two locks apart. A player who is one run away
## from chapter 2 must not be told it is "still being written".
func _check_toast_wording() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	for _f in 30:
		await get_tree().process_frame

	var title := menu.find_child("ToastTitle", true, false) as Label
	var body := menu.find_child("ToastBody", true, false) as Label
	if title == null or body == null:
		_faults.append("the map notice has no title/body label")
		menu.queue_free()
		await get_tree().process_frame
		return

	# A released chapter the player has not earned: an instruction.
	GameState.certificate_earned = {}
	GameState._session_tier_progress = {}
	menu.call("_show_locked_toast", 2)
	print("\n   locked chapter 2: %s / %s" % [title.text, body.text])
	if title.text != "LOCKED":
		_faults.append("chapter 2 shows %r, expected LOCKED" % title.text)
	for wanted in ["Easy", "Medium", "Hard"]:
		if not body.text.contains(wanted):
			_faults.append("the chapter 2 notice never names %s" % wanted)
	if body.text.contains("still being written"):
		_faults.append("chapter 2 is written -- the notice must not say otherwise")

	# A chapter with no data behind it: an apology.
	var unwritten: int = MainMenu.released_chapters() + 1
	if unwritten <= MainMenu.TOTAL_CHAPTERS:
		menu.call("_show_locked_toast", unwritten)
		print("   locked chapter %d: %s / %s" % [unwritten, title.text, body.text])
		if title.text != "AVAILABLE SOON!":
			_faults.append("chapter %d shows %r, expected AVAILABLE SOON!"
				% [unwritten, title.text])

	menu.queue_free()
	await get_tree().process_frame


## The probe writes real progress, so the developer's own save is put back.
func _stash_save() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.copy_absolute(SAVE, BACKUP)


func _restore_save() -> void:
	if FileAccess.file_exists(BACKUP):
		DirAccess.copy_absolute(BACKUP, SAVE)
		DirAccess.remove_absolute(BACKUP)
	elif FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	GameState.certificate_earned = {}
	GameState._session_tier_progress = {}
	GameState._load_progress()
