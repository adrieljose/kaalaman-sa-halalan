extends Node
## Drives the Chapter 4 boss through the two things that only happen once.
##
##   godot --path . tools/chapter4/probe_ch4_boss.tscn
##
## Both mechanics are easy to get subtly wrong in ways no ordinary playtest
## catches: a phase that fires twice looks like a stutter, and a revive that
## fires twice makes the boss unkillable. So each is driven deliberately --
## health is set, a turn is resolved, and the result is read back.

const BOSS_INDEX := 8          # the ninth encounter, zero-based
var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	for who in ["male", "female"]:
		GameState.character = who
		await _run(who)

	print("")
	if _faults.is_empty():
		print("boss OK -- phase 2 once, last stand once, defeat sticks")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _run(who: String) -> void:
	var label := "juan" if who == "male" else "maria"
	print("\n=== %s ===" % label.to_upper())
	if not GameState.load_chapter(4):
		_faults.append("chapter 4 will not load")
		return
	QuestionBank.set_context(4, "easy")
	GameState.encounter_index = BOSS_INDEX
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	get_tree().root.add_child(scene)
	for _f in 60:
		await get_tree().process_frame

	var enemy: EnemyData = GameState.chapter.encounter_at(BOSS_INDEX)
	if enemy == null or not enemy.is_boss:
		_faults.append("encounter %d is not the boss" % (BOSS_INDEX + 1))
		scene.queue_free()
		return
	print("   %s -- %s, %d hp" % [enemy.enemy_name, enemy.title, enemy.max_hp])

	# --- PHASE 2 ---------------------------------------------------------
	if int(scene.get("_boss_phase")) != 1:
		_faults.append("%s: the fight did not start in phase 1" % label)
	# Drop him just under half and let the controller notice.
	scene.set("_enemy_hp", int(enemy.max_hp * 0.45))
	await scene.call("_check_phase_change")
	for _f in 40:
		await get_tree().process_frame
	var phase := int(scene.get("_boss_phase"))
	print("   after falling under half: phase %d" % phase)
	if phase != 2:
		_faults.append("%s: phase stayed at %d after crossing the threshold" % [label, phase])

	# It must not fire again on the way down.
	await scene.call("_check_phase_change")
	for _f in 20:
		await get_tree().process_frame
	if int(scene.get("_boss_phase")) != 2:
		_faults.append("%s: phase advanced a second time" % label)

	# Phase 2 must actually hit harder, and only for this boss.
	var gain: float = scene.call("_ch4_phase_gain", "c4combat_veterans_verdict")
	var other: float = scene.call("_ch4_phase_gain", "c3combat_pocket_payload")
	print("   phase-2 damage gain %.2fx (chapter 3 move unaffected: %.2fx)" % [gain, other])
	if gain <= 1.0:
		_faults.append("%s: phase 2 does not raise the boss's damage" % label)
	if not is_equal_approx(other, 1.0):
		_faults.append("%s: the phase gain leaked onto a chapter 3 move" % label)

	# --- THE LAST STAND --------------------------------------------------
	if bool(scene.get("_ch4_last_stand_used")):
		_faults.append("%s: the last stand was spent before the fight began" % label)
	scene.set("_enemy_hp", 0)
	var revived: bool = await scene.call("_ch4_last_stand")
	for _f in 40:
		await get_tree().process_frame
	var hp := int(scene.get("_enemy_hp"))
	print("   at zero: revived=%s, back to %d hp" % [revived, hp])
	if not revived:
		_faults.append("%s: the boss did not make his last stand" % label)
	if hp <= 0:
		_faults.append("%s: the last stand restored no health" % label)
	var want := roundi(enemy.max_hp * 0.22)
	if absi(hp - want) > 2:
		_faults.append("%s: restored %d hp, expected about %d" % [label, hp, want])

	# And it is ONCE. A second trip to zero must be the end of him.
	scene.set("_enemy_hp", 0)
	var again: bool = await scene.call("_ch4_last_stand")
	for _f in 20:
		await get_tree().process_frame
	print("   at zero a second time: revived=%s" % again)
	if again:
		_faults.append("%s: the boss revived twice -- the fight cannot be won" % label)

	# --- NO DEFENCE SPAM -------------------------------------------------
	# The guard must not be selectable on the turn straight after using it.
	var guard: EnemyMove = null
	for move in enemy.moves:
		if move.signature_id() == "c4combat_eternal_resolve":
			guard = move
	if guard == null:
		_faults.append("%s: the boss has no Eternal Resolve" % label)
	else:
		scene.set("_ch4_last_guard_turn", int(scene.get("_move_index")))
		var blocked: bool = scene.call("_ch4_guard_on_cooldown", guard)
		print("   guard immediately after guarding: on cooldown=%s" % blocked)
		if not blocked:
			_faults.append("%s: Eternal Resolve can be used twice in a row" % label)
		scene.set("_ch4_last_guard_turn", -1)
		if bool(scene.call("_ch4_guard_on_cooldown", guard)):
			_faults.append("%s: Eternal Resolve is stuck on cooldown" % label)

	scene.queue_free()
	await get_tree().process_frame
