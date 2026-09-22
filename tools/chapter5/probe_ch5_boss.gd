extends Node
## Drives the Chapter 5 boss through both of his once-only stages.
##
##   godot --path . tools/chapter5/probe_ch5_boss.tscn
##
## HOUSE IN SESSION and FINAL READING are each meant to happen exactly once, in
## that order, and FINAL READING is explicitly NOT a heal. All three of those
## are things a playtest would probably not catch going subtly wrong, so each
## is driven deliberately here and read back.

const BOSS_INDEX := 8
var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	for who in ["male", "female"]:
		GameState.character = who
		await _run(who)

	print("")
	if _faults.is_empty():
		print("boss OK -- session once, final reading once and no heal, defeat plays")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _run(who: String) -> void:
	var label := "juan" if who == "male" else "maria"
	print("\n=== %s ===" % label.to_upper())
	if not GameState.load_chapter(5):
		_faults.append("chapter 5 will not load")
		return
	QuestionBank.set_context(5, "easy")
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

	# --- HOUSE IN SESSION ------------------------------------------------
	scene.set("_enemy_hp", int(enemy.max_hp * 0.46))
	await scene.call("_check_phase_change")
	for _f in 40:
		await get_tree().process_frame
	var phase := int(scene.get("_boss_phase"))
	print("   under half: phase %d, banner %s" % [phase, enemy.phase_banners])
	if phase != 2:
		_faults.append("%s: HOUSE IN SESSION did not fire (phase %d)" % [label, phase])
	var chamber := scene.get_node_or_null("Chapter5Chamber")
	if chamber == null or int(chamber.get("state")) != 1:
		_faults.append("%s: voting board did not activate" % label)
	if enemy.phase_banners.is_empty() or String(enemy.phase_banners[0]) != "HOUSE IN SESSION!":
		_faults.append("%s: the phase banner is not HOUSE IN SESSION!" % label)
	await scene.call("_check_phase_change")
	for _f in 20:
		await get_tree().process_frame
	if int(scene.get("_boss_phase")) != 2:
		_faults.append("%s: the phase advanced twice" % label)

	# --- FINAL READING ---------------------------------------------------
	# Above the threshold it must NOT fire.
	scene.set("_enemy_hp", int(enemy.max_hp * 0.40))
	var early: bool = await scene.call("_ch5_try_final_reading")
	if early:
		_faults.append("%s: FINAL READING fired at 40%% health" % label)

	# In the last quarter it must, once, and must not heal.
	var before := int(enemy.max_hp * 0.20)
	scene.set("_enemy_hp", before)
	var fired: bool = await scene.call("_ch5_try_final_reading")
	for _f in 60:
		await get_tree().process_frame
	var after := int(scene.get("_enemy_hp"))
	print("   at 20%%: fired=%s, hp %d -> %d" % [fired, before, after])
	if not fired:
		_faults.append("%s: FINAL READING did not fire in the last quarter" % label)
	if after > before:
		_faults.append("%s: FINAL READING healed the boss (%d -> %d)" % [label, before, after])
	if not bool(scene.get("_ch5_final_reading_active")):
		_faults.append("%s: the closing stage did not stay active" % label)
	if chamber != null and int(chamber.get("state")) != 2:
		_faults.append("%s: FINAL READING chamber did not intensify" % label)

	var again: bool = await scene.call("_ch5_try_final_reading")
	if again:
		_faults.append("%s: FINAL READING fired a second time" % label)

	# The two stages stack, and only for this boss.
	var gain: float = scene.call("_ch5_damage_gain", "c5combat_house_rules")
	var other: float = scene.call("_ch5_damage_gain", "c4combat_house_rules")
	print("   damage gain in the closing stage: %.2fx (a chapter 4 id: %.2fx)"
		% [gain, other])
	if gain <= 1.15:
		_faults.append("%s: the closing stage does not stack with phase 2" % label)
	if not is_equal_approx(other, 1.0):
		_faults.append("%s: the Chapter 5 gain leaked onto another chapter" % label)
	for turn in 3:
		scene.call("_ch5_finish_turn")
		if turn < 2 and not bool(scene.get("_ch5_final_reading_active")):
			_faults.append("%s: FINAL READING expired early" % label)
	if bool(scene.get("_ch5_final_reading_active")):
		_faults.append("%s: FINAL READING was not temporary" % label)
	if chamber != null and int(chamber.get("state")) != 1:
		_faults.append("%s: chamber did not return to session lighting" % label)
	if bool(await scene.call("_ch5_try_final_reading")):
		_faults.append("%s: expired FINAL READING retriggered" % label)

	# --- NO SHIELD SPAM --------------------------------------------------
	var guard: EnemyMove = null
	for move in enemy.moves:
		if move.signature_id() == "c5combat_speakers_shield":
			guard = move
	if guard == null:
		_faults.append("%s: the boss has no Speaker's Shield" % label)
	else:
		scene.set("_ch5_last_guard_turn", int(scene.get("_move_index")))
		if not bool(scene.call("_ch5_guard_on_cooldown", guard)):
			_faults.append("%s: Speaker's Shield can be raised twice in a row" % label)
		scene.set("_ch5_last_guard_turn", -1)
		if bool(scene.call("_ch5_guard_on_cooldown", guard)):
			_faults.append("%s: Speaker's Shield is stuck on cooldown" % label)

	# --- THE DEFEAT SEQUENCE ---------------------------------------------
	# It must run for this boss, and the sprite must still be there afterwards.
	scene.set("_enemy_hp", 0)
	await scene.call("_ch5_boss_defeat_if_due")
	if chamber != null and chamber.is_processing():
		_faults.append("%s: chamber still animates after defeat" % label)
	for _f in 30:
		await get_tree().process_frame
	var body := scene.find_child("EnemyCharacter", true, false) as Control
	if body == null or not is_instance_valid(body):
		_faults.append("%s: the boss sprite was removed by the defeat sequence" % label)
	else:
		print("   defeat sequence played, sprite still present at %s" % body.position)

	scene.queue_free()
	await get_tree().process_frame
