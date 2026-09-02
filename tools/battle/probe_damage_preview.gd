extends Node
## Checks that the number the badge promises is the number the rival takes.
##
## The two cannot use different arithmetic -- there is one _damage_for() and
## both call it -- so what this actually tests is the harder thing: that the
## preview feeds that function the same ARGUMENTS the real hit will, and that
## the badge is repainted at every moment something in them changes. A stale
## badge is still an honest formula lying to the player.
##
## Run as a SCENE (autoloads) and WINDOWED (the board needs a real viewport for
## its click hit-testing):
##
##   godot --path . tools/battle/probe_damage_preview.tscn --resolution 640x480

const SETTLE := 40

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	for tier in ["easy", "medium", "hard"]:
		await _check_tier(tier)
	print("")
	if _faults.is_empty():
		print("damage preview OK -- every previewed range contained the hit that landed")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _check_tier(tier: String) -> void:
	GameState.load_chapter(1)
	GameState.encounter_index = 0
	GameState.difficulty = tier
	GameState.reset_potions()

	# Parented to the ROOT VIEWPORT, not to this helper node.
	#
	# A Control under a plain Node has no parent area to anchor against, so it
	# sits at size zero -- and a scene staged that way never reproduces what the
	# real game does when a full-rect child grows from nothing to the whole
	# screen. That gap hid a crash: the tutorial director answers its first
	# NOTIFICATION_RESIZED by placing a card it had not built yet, which under a
	# zero-sized parent never fired at all. Staged here the way the game stages
	# it, so a size-dependent failure fails here too.
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	get_tree().root.add_child(scene)
	for _f in SETTLE:
		await get_tree().process_frame

	var badge: DamageBadge = scene.get("_damage_badge")
	var question: Dictionary = scene.get("_question")
	var answer := String(question.get("answer", ""))
	print("%s: %s  badge=%s  visible=%s" % [
		tier.to_upper(), answer, badge.damage_text(), badge.visible])

	if answer.is_empty():
		_faults.append("%s: no question presented" % tier)
		scene.queue_free()
		return
	if not badge.visible:
		_faults.append("%s: badge hidden while a question is live" % tier)

	# The promise, read off the badge's own numbers before a letter is tapped.
	var span: Vector2i = scene.call("_potential_damage")
	if span.x <= 0:
		_faults.append("%s: previewed a non-positive floor (%s)" % [tier, span])

	# A Power Up has to move the promise, or the badge is ignoring live state.
	var before := scene.call("_potential_damage") as Vector2i
	scene.call("_use_power_potion")
	var boosted := scene.call("_potential_damage") as Vector2i
	if boosted.x <= before.x:
		_faults.append("%s: priming a Power Up did not raise the preview (%s -> %s)"
			% [tier, before, boosted])
	if not _reads_as(badge, boosted):
		_faults.append("%s: badge reads '%s', preview says %s"
			% [tier, badge.damage_text(), boosted])

	# Now actually answer it. The Power Up is spent first: it is a live
	# modifier, and leaving it primed would fold a x2 into the comparison for
	# no reason -- its effect on the PREVIEW is what was just checked above.
	scene.set("_power_up_active", false)
	scene.call("_refresh_damage_preview")
	var promised := scene.call("_potential_damage") as Vector2i
	var hp_before: int = scene.get("_enemy_hp")
	if not scene.get("board").call("demo_select", answer):
		_faults.append("%s: could not spell %s off the board" % [tier, answer])
		scene.queue_free()
		return
	# The combat line is caught as it is posted rather than read at the end:
	# the educational fact replaces it a couple of seconds later, and the run
	# has to keep going past that point to see the NEXT question reach the
	# badge. Reading the damage off this line rather than off the rival's
	# health is what makes a big answer testable -- a rival on 120 HP taking a
	# 282-point hit only ever reports a 120-point loss.
	var log_line := ""
	scene.get("board").call("submit_word")
	for _f in 420:
		await get_tree().process_frame
		if log_line.is_empty():
			var line := String(scene.get("word_preview_label").text)
			if line.contains("+"):
				log_line = line
	var hp_after: int = scene.get("_enemy_hp")
	var dealt := _parse_damage(log_line)
	var bonused := log_line.contains("Spark") or log_line.contains("Gold")
	print("   promised %d-%d   dealt %d   (hp %d -> %d)  %s" % [
		promised.x, promised.y, dealt, hp_before, scene.get("_enemy_hp"),
		"[bonus tiles]" if bonused else ""])
	if hp_after >= hp_before:
		_faults.append("%s: rival took %d damage but its health did not move (%d)"
			% [tier, dealt, hp_after])
	elif hp_before - hp_after != mini(dealt, hp_before):
		_faults.append("%s: rival lost %d health for a %d-point hit"
			% [tier, hp_before - hp_after, dealt])
	if dealt <= 0:
		_faults.append("%s: could not read the damage out of '%s'" % [tier, log_line])
	elif dealt < promised.x:
		_faults.append("%s: dealt %d, under the promised floor of %d"
			% [tier, dealt, promised.x])
	elif dealt > promised.y and not bonused:
		# Above the ceiling with no Gold and no Spark on the route means the
		# preview and the hit disagree about something real.
		_faults.append("%s: dealt %d over the promised ceiling of %d with no bonus tile"
			% [tier, dealt, promised.y])

	# And the badge must follow the question that replaces it. Forced rather
	# than waited for, so this is a real assertion on every run instead of one
	# that quietly skips whenever the timing lands badly.
	scene.call("_present_question")
	await get_tree().process_frame
	var forced: Vector2i = scene.call("_potential_damage")
	if not _reads_as(badge, forced):
		_faults.append("%s: stale badge after the question changed ('%s' vs %s)"
			% [tier, badge.damage_text(), forced])
	else:
		print("   next question %s -> badge %s" % [
			scene.get("_question").get("answer", "?"), badge.damage_text()])

	scene.queue_free()
	await get_tree().process_frame


## The badge drops its " DMG" suffix on the compact arrangements, so both
## renderings are accepted -- what is being checked is the NUMBERS.
func _expected_text(span: Vector2i) -> String:
	if span.x <= 0 and span.y <= 0:
		return "NO DMG"
	return str(span.x) if span.x == span.y else "%d-%d" % [span.x, span.y]

func _reads_as(badge: DamageBadge, span: Vector2i) -> bool:
	var wanted := _expected_text(span)
	return badge.damage_text() in [wanted, "%s DMG" % wanted]

## "PARTY +130! CORRECT + LIGHTNING!" -> 130
func _parse_damage(line: String) -> int:
	var plus := line.find("+")
	if plus < 0:
		return -1
	var digits := ""
	for i in range(plus + 1, line.length()):
		if line[i] < "0" or line[i] > "9":
			break
		digits += line[i]
	return int(digits) if not digits.is_empty() else -1
