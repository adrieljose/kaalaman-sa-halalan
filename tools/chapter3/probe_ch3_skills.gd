extends Node
## Fires all 24 Chapter 3 skills in the real battle scene and checks each one.
##
## "It ran without erroring" is not the bar. A skill can complete and still
## leave the rival two pixels left of where it started, still rigged, rotated,
## or scaled -- and every one of those is invisible on the turn it happens and
## obvious three turns later when the drift has accumulated. Chapter 3's whole
## complaint was animation that did not return cleanly, so the return is what
## this measures.
##
## Per skill:
##   * the routine completes (a stuck await never returns and the probe hangs,
##     which a timeout catches as a failure rather than a pass)
##   * damage / guard / heal actually lands, and by the right amount
##   * the rival is back at its EXACT home x, rotation, scale and alpha
##   * the cut-out rig is handed back -- a skill that leaves it on freezes the
##     rival on one frame for the rest of the fight
##   * the sprite still has a texture (an emptied clip leaves an invisible body)
##
## It also checks statically that all 24 ids reach a bespoke routine rather
## than the generic fallback, which no runtime assertion can see: a typo'd id
## still animates, just identically to everyone else, which is the exact bug
## this whole change exists to remove.
##
##   godot --path . tools/chapter3/probe_ch3_skills.tscn --resolution 1280x960

const SETTLE := 45
const CONTROLLER := "res://scripts/word_battle_controller.gd"
## How far the body may sit from home afterwards and still count as returned.
const HOME_EPS := 0.75

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	_check_dispatch_covers_every_skill()
	await _run_every_skill()

	print("")
	if _faults.is_empty():
		print("chapter 3 skills OK -- 24 routines, all land and all return clean")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


## Static: every ch3 move id must appear as its own arm in _ch3_perform's match.
func _check_dispatch_covers_every_skill() -> void:
	var src := FileAccess.get_file_as_string(CONTROLLER)
	if src.is_empty():
		_faults.append("could not read the battle controller")
		return
	var chapter := load(GameState.chapter_path(3)) as ChapterData
	var routed := 0
	for i in chapter.encounter_count():
		var e := chapter.encounter_at(i)
		if e == null or e.is_boss:
			continue
		for move in e.moves:
			var id := move.signature_id()
			if not src.contains('"%s": await _ch3_' % id):
				_faults.append("%s (%s) has no routine of its own -- it would fall"
					% [move.move_name, id]
					+ " through to the generic fallback")
			else:
				routed += 1
	print("dispatch: %d of 24 skills routed to their own choreography" % routed)
	if routed != 24:
		_faults.append("expected 24 routed skills, counted %d" % routed)


func _run_every_skill() -> void:
	if not GameState.load_chapter(3):
		_faults.append("could not load chapter 3")
		return
	QuestionBank.set_context(3, "easy")
	var chapter: ChapterData = GameState.chapter

	for index in chapter.encounter_count():
		var enemy := chapter.encounter_at(index)
		if enemy == null or enemy.is_boss:
			continue          # Cong Meow has his own controller and his own tests
		GameState.encounter_index = index
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame

		print("\n%s" % enemy.enemy_name)
		var body := scene.find_child("EnemyCharacter", true, false) as Control
		if body == null:
			_faults.append("%s: no EnemyCharacter" % enemy.enemy_name)
			scene.queue_free()
			await get_tree().process_frame
			continue

		# The baseline every skill has to come back to.
		var home := body.position
		var home_rot: float = body.rotation
		var home_scale: Vector2 = body.scale

		for move in enemy.moves:
			await _fire(scene, body, enemy, move, home, home_rot, home_scale)

		scene.queue_free()
		await get_tree().process_frame


func _fire(scene: Node, body: Control, enemy: EnemyData, move: EnemyMove,
		home: Vector2, home_rot: float, home_scale: Vector2) -> void:
	var name := move.move_name
	# Full bars each time, so a heal has room to land and a hit has room to
	# subtract -- otherwise clamping hides a wrong number.
	scene.set("_player_hp", GameState.player_max_hp)
	scene.set("_enemy_hp", maxi(1, enemy.max_hp / 2))
	scene.set("_enemy_guard", 0.0)
	scene.set("_pending_enemy_damage", 0)
	var hp_before: int = scene.get("_player_hp")
	var enemy_hp_before: int = scene.get("_enemy_hp")

	await scene.call("_resolve_chapter3_turn", move)
	# Let the recovery tweens finish before measuring the resting pose.
	for _f in 30:
		await get_tree().process_frame

	var hp_after: int = scene.get("_player_hp")
	var dealt := hp_before - hp_after
	var guard: float = scene.get("_enemy_guard")
	var healed: int = int(scene.get("_enemy_hp")) - enemy_hp_before
	var drift: float = absf(body.position.x - home.x)

	print("   %-22s dealt %-3d guard %.2f heal %-3d drift %.2fpx"
		% [name, dealt, guard, healed, drift])

	# --- did the skill actually DO its job? ---
	if move.direct_damage > 0 and dealt != move.direct_damage:
		_faults.append("%s: dealt %d, should deal %d" % [name, dealt, move.direct_damage])
	if move.guard_reduction > 0.0 and not is_equal_approx(guard, move.guard_reduction):
		_faults.append("%s: guard is %.2f, should be %.2f" % [name, guard, move.guard_reduction])
	if move.self_heal > 0 and healed != move.self_heal:
		_faults.append("%s: healed %d, should heal %d" % [name, healed, move.self_heal])
	if move.direct_damage == 0 and dealt > 0:
		_faults.append("%s: a defensive skill dealt %d damage" % [name, dealt])

	# --- did it come back? ---
	if drift > HOME_EPS:
		_faults.append("%s: rival ended %.2fpx from home" % [name, drift])
	if absf(body.position.y - home.y) > HOME_EPS:
		_faults.append("%s: rival ended %.2fpx above/below home"
			% [name, absf(body.position.y - home.y)])
	if absf(body.rotation - home_rot) > 0.02:
		_faults.append("%s: rival left rotated %.1f degrees"
			% [name, rad_to_deg(body.rotation - home_rot)])
	if not body.scale.is_equal_approx(home_scale):
		_faults.append("%s: rival left scaled %s (was %s)" % [name, body.scale, home_scale])
	if body.modulate.a < 0.99:
		_faults.append("%s: rival left at %.2f alpha" % [name, body.modulate.a])

	# --- is the body still a body? ---
	if body.call("is_rigged"):
		_faults.append("%s: left the cut-out rig ON -- the rival is frozen on one frame" % name)
	if body.get("texture") == null:
		_faults.append("%s: rival has no frame after the skill" % name)
