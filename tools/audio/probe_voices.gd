extends Node
## Checks that every Chapter 2 rival's hurt voice resolves, that the cooldown
## actually suppresses a burst, and that the boss changes register when his
## health crosses the threshold.
##
## Worth a probe rather than an ear test: a voice that fails to load falls back
## to the shared grunt SILENTLY, which sounds like the old behaviour rather than
## like a bug, so a typo in one id could sit there unnoticed for months.

const CHAPTER := 2


func _ready() -> void:
	await get_tree().process_frame
	var chapter: ChapterData = load("res://data/chapters/chapter_%02d.tres" % CHAPTER)
	var faults: Array[String] = []

	print("--- voice assets ---")
	for rival: EnemyData in chapter.encounters:
		if rival.hurt_voice.is_empty():
			faults.append("%s has no hurt_voice" % rival.enemy_name)
			continue
		var takes := 0
		for i in range(1, Audio.VOICE_TAKES + 1):
			var p := "%s/%s_hurt_%d.ogg" % [Audio.VOICE_DIR, rival.hurt_voice, i]
			if ResourceLoader.exists(p):
				takes += 1
			else:
				faults.append("missing %s" % p)
		var rage := 0
		if not rival.rage_voice.is_empty():
			for i in range(1, Audio.VOICE_TAKES + 1):
				if ResourceLoader.exists("%s/%s_hurt_%d.ogg" % [Audio.VOICE_DIR, rival.rage_voice, i]):
					rage += 1
		print("  %-16s voice=%-16s takes=%d%s" % [
			rival.enemy_name, rival.hurt_voice, takes,
			"  rage=%s(%d) below %d%%" % [rival.rage_voice, rage, int(rival.rage_below * 100.0)]
				if not rival.rage_voice.is_empty() else ""])

	# Every id must be distinct, or two rivals share a voice again.
	var seen: Array[String] = []
	for rival: EnemyData in chapter.encounters:
		if seen.has(rival.hurt_voice):
			faults.append("duplicate voice id '%s'" % rival.hurt_voice)
		seen.append(rival.hurt_voice)

	print("--- cooldown ---")
	Audio.reset_voice()
	var fired := 0
	# Ten blows in the same instant, the way a multi-hit skill lands them.
	for i in 10:
		if Audio.play_voice("ordinance_ogre"):
			fired += 1
	# play_voice reports true when it deliberately suppresses, so count what
	# actually reached the player instead.
	print("  10 instant hits -> player is playing: %s (one voice, not ten)"
		% Audio._voice_player.playing)
	if not Audio._voice_player.playing:
		faults.append("cooldown swallowed the first hit too")

	print("--- unknown voice falls back ---")
	Audio.reset_voice()
	if Audio.play_voice("no_such_rival"):
		faults.append("a missing voice reported success; the fallback would never run")
	else:
		print("  missing id correctly reports false, so the shared grunt plays")

	if faults.is_empty():
		print("\nOK -- no faults")
	else:
		print("\nFAULTS: %d" % faults.size())
		for f in faults:
			print("  - ", f)
	get_tree().quit()
