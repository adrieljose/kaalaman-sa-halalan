extends Node
## Walks the whole tutorial the way a player would, and photographs it.
##
## The failure this is really guarding against is a silent one: a step whose
## target no longer resolves. TutorialDirector treats "nothing to point at" as a
## legitimate state -- the first and last cards have no target -- so a step that
## has lost its node does not error, it just quietly stops highlighting
## anything, and the tutorial goes on giving instructions about a thing it is no
## longer indicating. Every step with a target is asserted to produce a visible
## on-screen rect.
##
## Run as a SCENE (autoloads) and WINDOWED (the board hit-tests real
## coordinates, and screenshots need a real viewport):
##
##   godot --path . tools/battle/probe_tutorial.tscn --resolution 1280x960

const OUT_DIR := "res://output/tutorial"
const SETTLE := 40
## Steps worth keeping a picture of: the opener, the board demonstration, the
## badge, the attack, the rival's turn and the last card.
const SHOT_STEPS := [0, 2, 3, 4, 5, 8, 12]

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	GameState.tutorial_completed = false
	GameState.tutorial_mode = true
	GameState.load_chapter(1)
	GameState.encounter_index = 0
	GameState.difficulty = "easy"
	GameState.reset_potions()
	var chapter_before := GameState.encounter_index
	var potions_before := GameState.potion_count(GameState.PotionType.HEALTH)

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

	var director: TutorialDirector = scene.get("_tutorial")
	if director == null:
		print("FAULT: tutorial_mode set but no director was built")
		get_tree().quit(1)
		return

	# Built, and built completely. A script error inside a Godot node's _ready()
	# aborts the rest of that _ready() and the engine carries on -- so a director
	# that died halfway through construction is still standing there, still
	# stepping, and every check below it can pass while the real game logs a
	# crash on every frame. The engine does not hand script errors to GDScript,
	# so the only way to notice is to assert that the pieces exist.
	for part in ["_card", "_title", "_body", "_counter", "_next_button",
			"_back_button", "_skip_button"]:
		if director.get(part) == null:
			_faults.append("the director never finished building: %s is null" % part)
	if director.size.x <= 0.0 or director.size.y <= 0.0:
		_faults.append("the director is %s -- it will not draw its scrim" % director.size)

	var steps: Array = director.get("_steps")
	print("%d steps" % steps.size())
	var question: Dictionary = scene.get("_question")
	if String(question.get("answer", "")) != "MAYOR":
		_faults.append("the tutorial is not using its own sample question (%s)"
			% question.get("answer", "<none>"))

	var closed := {"fired": false, "start": false, "done": false}
	director.closed.connect(func(start: bool, completed: bool) -> void:
		closed["fired"] = true
		closed["start"] = start
		closed["done"] = completed)

	for i in steps.size():
		if i > 0:
			await director.call("_go_to", i)
		# Actions run on entry; wait them out before measuring anything.
		var guard := 0
		while bool(director.get("_busy")) and guard < 900:
			await get_tree().process_frame
			guard += 1
		for _f in 4:
			await get_tree().process_frame

		var step: Dictionary = steps[i]
		var spot: Rect2 = director.get("_spot")
		var has_target: bool = step.has("target")
		print("  %2d  %-30s target=%s  spot=%s" % [
			i + 1, step.get("title", ""), has_target,
			"%dx%d @ %d,%d" % [spot.size.x, spot.size.y, spot.position.x, spot.position.y]
				if spot.size.x > 0.0 else "none"])
		if has_target and spot.size.x <= 0.0:
			_faults.append("step %d (%s) points at nothing on screen"
				% [i + 1, step.get("title", "")])
		if not has_target and spot.size.x > 0.0:
			_faults.append("step %d (%s) lit something it did not name"
				% [i + 1, step.get("title", "")])
		if String(step.get("title", "")).is_empty() or String(step.get("body", "")).is_empty():
			_faults.append("step %d has no title or no body" % (i + 1))

		if i in SHOT_STEPS:
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				var path := "%s/step_%02d.png" % [OUT_DIR, i + 1]
				get_viewport().get_texture().get_image().save_png(path)

	# The two demonstrations have to have actually happened.
	var enemy_hp: int = scene.get("_enemy_hp")
	var player_hp: int = scene.get("_player_hp")
	print("after the demonstrations: player %d/%d, rival %d" % [
		player_hp, GameState.player_max_hp, enemy_hp])
	if enemy_hp >= scene.get("_enemy").max_hp:
		_faults.append("the demonstration attack never damaged the rival")
	if player_hp >= GameState.player_max_hp:
		_faults.append("the demonstration enemy turn never damaged the player")
	if enemy_hp <= 0 or player_hp <= 0:
		_faults.append("a tutorial demonstration took someone to zero")

	# BACK has to work, and must not replay the attack it steps over.
	var hp_before_back: int = scene.get("_enemy_hp")
	await director.call("_go_to", 4, false)
	for _f in 30:
		await get_tree().process_frame
	if int(director.get("_index")) != 4:
		_faults.append("BACK did not move the director")
	if int(scene.get("_enemy_hp")) != hp_before_back:
		_faults.append("stepping BACK replayed the attack (%d -> %d)"
			% [hp_before_back, scene.get("_enemy_hp")])

	# Nothing the tutorial did may have touched the run.
	if GameState.encounter_index != chapter_before:
		_faults.append("the tutorial advanced the encounter (%d -> %d)"
			% [chapter_before, GameState.encounter_index])
	if GameState.potion_count(GameState.PotionType.HEALTH) != potions_before:
		_faults.append("the tutorial spent potion stock")
	if GameState.tutorial_completed:
		_faults.append("completion was recorded before the player finished")

	# From here the battle scene's own handler has to be out of the way: it
	# answers `closed` by changing scene, which frees this probe mid-check. The
	# handler is exercised deliberately at the very end instead.
	director.closed.disconnect(Callable(scene, "_on_tutorial_closed"))

	# SKIP from a middle step must not count as completion; the last card must.
	director.call("_on_skip_pressed")
	await get_tree().process_frame
	if not closed["fired"]:
		_faults.append("SKIP did not close the tutorial")
	elif bool(closed["done"]):
		_faults.append("SKIP from step 5 was recorded as completion")

	closed["fired"] = false
	await director.call("_go_to", steps.size() - 1, false)
	director.call("_on_next_pressed")
	await get_tree().process_frame
	if not (closed["fired"] and closed["start"] and closed["done"]):
		_faults.append("START GAME on the last card did not report a completed run")

	await _check_cold_construction()

	# Held before the last check: that check runs the real close handler, which
	# changes scene and detaches this probe from the tree it is standing in.
	var tree := get_tree()
	_check_close_handler(scene)

	print("")
	if _faults.is_empty():
		print("tutorial OK -- %d steps, every target on screen, run untouched" % steps.size())
		tree.quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	tree.quit(1)

## Builds a director under a parent that ALREADY has a size.
##
## This is the condition the game creates and a staged probe does not. When the
## battle scene is swapped in by change_scene_to_file() its root Control is
## sized before the director is added to it, so the director's own
## set_anchors_and_offsets_preset() grows it from nothing to the whole screen in
## one synchronous step -- and NOTIFICATION_RESIZED lands DURING _ready(), before
## the rest of _ready() has built anything for it to touch. An error there does
## not merely log: it unwinds the whole of _ready(), so the director is left
## permanently half-built and dies again on every later frame.
##
## Reproduced deliberately rather than waited for, because whether the staged
## version happens to trigger it depends on which frame the parent gets its size
## on -- which is exactly the kind of luck a regression test must not rely on.
func _check_cold_construction() -> void:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(host)
	# The awaited frame is the whole point. A parent that has not been laid out
	# yet still reports a size of zero, so a director added to it grows by
	# nothing and its resize is deferred harmlessly to the next frame -- which is
	# why staging a scene under a fresh node hid this bug rather than showing it.
	# Waiting for the host to be measured is what makes the growth happen inside
	# _ready(), the way change_scene_to_file() arranges it in the real game.
	await get_tree().process_frame
	var director := TutorialDirector.new()
	host.add_child(director)
	if director.get("_card") == null:
		_faults.append("a director built under a sized parent never finished _ready()")
	elif not director.size.is_equal_approx(host.size):
		_faults.append("a director built under a sized parent came out %s, not %s"
			% [director.size, host.size])
	else:
		print("cold construction under a %s parent: OK" % host.size)

	# And the invariant the crash was really about: a notification that arrives
	# before _ready() has built anything must not die.
	#
	# Whether the engine delivers the resize inside _ready() or defers it to the
	# next frame turns out to depend on when the parent was last laid out, which
	# is not something a test can pin down -- so this stops trying to recreate
	# the timing and asserts the property directly, by delivering the
	# notification by hand to a director that has never entered a tree. It
	# cannot be caught from GDScript: under the bug it prints a SCRIPT ERROR and
	# carries on. Run this probe with `grep -c "SCRIPT ERROR"` on its output.
	var bare := TutorialDirector.new()
	bare.notification(Control.NOTIFICATION_RESIZED)
	bare.free()

	host.queue_free()

## The battle scene's own close handler, run last because it changes scene.
##
## change_scene_to_file() is deferred to the end of the frame, so everything it
## sets synchronously can still be read here -- which is the whole of what needs
## checking: the completion flag, the mode being dropped, and the START GAME
## request left behind for the title screen.
func _check_close_handler(scene: Node) -> void:
	GameState.tutorial_completed = false
	GameState.pending_play_request = false
	scene.call("_on_tutorial_closed", true, true)
	if not GameState.tutorial_completed:
		_faults.append("finishing the tutorial did not record completion")
	if GameState.tutorial_mode:
		_faults.append("tutorial_mode was left set after closing")
	if not GameState.pending_play_request:
		_faults.append("START GAME left no play request for the title screen")
	# Left set to false so a later run of this probe starts from a clean flag;
	# the handler itself has already cleared tutorial_mode.
	GameState.pending_play_request = false
