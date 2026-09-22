extends Node
## Measures grounding and board clearance for every Chapter 3 encounter, in
## both layouts, for both players -- then runs turns and checks nothing drifts.
##
## Everything here is measured from the VISIBLE body (AnimatedCharacter.
## body_rect), never from the node box. That distinction is the whole bug: a
## frame is a small figure on a larger transparent canvas, letterboxed again
## inside a node, so the node's bottom edge sits well below the drawn soles and
## its left edge well outside the drawn shoulder. Any check written against the
## node box agrees with the broken behaviour and proves nothing.
##
##   godot --path . tools/chapter3/probe_ch3_grounding.tscn --resolution 1280x960

const SETTLE := 55
const CASES := [
	{"name": "desktop", "window": Vector2i(1280, 960)},
	{"name": "mobile", "window": Vector2i(390, 844)},
]
## How far a fighter's soles may sit from the room's painted floor.
const FOOT_TOLERANCE := 3.0
## The gap the controller promises between the board and a visible body.
const WANT_GAP := 16.0
## Slack on that promise, for a fighter the edge clamp legitimately held back.
const GAP_SLACK := 1.0
## Turns to run when checking for drift.
const DRIFT_TURNS := 6

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	for case in CASES:
		DisplayServer.window_set_size(case["window"])
		for _f in 8:
			await get_tree().process_frame
		for who in ["male", "female"]:
			GameState.character = who
			await _sweep(String(case["name"]), who)

	print("")
	if _faults.is_empty():
		print("grounding OK -- feet on the floor, board clear, no drift")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _sweep(case_name: String, who: String) -> void:
	if not GameState.load_chapter(3):
		_faults.append("could not load chapter 3")
		return
	QuestionBank.set_context(3, "easy")
	var chapter: ChapterData = GameState.chapter
	var label := "%s/%s" % [case_name, "juan" if who == "male" else "maria"]
	print("\n=== %s ===" % label)

	for index in chapter.encounter_count():
		var enemy := chapter.encounter_at(index)
		if enemy == null:
			continue
		GameState.encounter_index = index
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame

		var pc := scene.find_child("PlayerCharacter", true, false) as Control
		var ec := scene.find_child("EnemyCharacter", true, false) as Control
		var frame := scene.find_child("BoardFrame", true, false) as Control
		var bg := scene.find_child("Background", true, false) as TextureRect
		if pc == null or ec == null or frame == null:
			_faults.append("%s/%s: missing a stage node" % [label, enemy.enemy_name])
			scene.queue_free()
			await get_tree().process_frame
			continue

		# The room's own walkable line: where ground_fraction of the DRAWN
		# backdrop falls. This is the floor the art paints, and the thing the
		# feet are supposed to touch -- not a number the layout chose.
		var painted := 0.0
		if bg != null and bg.texture != null and bg.size.y > 0.0:
			var gf: float = enemy.ground_fraction if enemy.ground_fraction > 0.0 else 0.9125
			painted = bg.position.y + bg.size.y * gf

		var p_body: Rect2 = pc.call("body_rect")
		var e_body: Rect2 = ec.call("body_rect")
		var p_feet: float = pc.position.y + p_body.end.y
		var e_feet: float = ec.position.y + e_body.end.y
		var f := frame.get_global_rect()
		var d: Vector2 = Layout.profile.design_size
		var p_gap: float = f.position.x - (pc.position.x + p_body.end.x)
		var e_gap: float = (ec.position.x + e_body.position.x) - f.end.x

		print("   %d %-20s feet p%.1f e%.1f (floor %.1f)  gap p%.1f e%.1f"
			% [index + 1, enemy.enemy_name, p_feet, e_feet, painted, p_gap, e_gap])

		if painted > 0.0:
			if absf(p_feet - painted) > FOOT_TOLERANCE:
				_faults.append("%s/%s: player soles %.1fpx off the painted floor"
					% [label, enemy.enemy_name, p_feet - painted])
			if absf(e_feet - painted) > FOOT_TOLERANCE:
				_faults.append("%s/%s: rival soles %.1fpx off the painted floor"
					% [label, enemy.enemy_name, e_feet - painted])
		# The gap is only demanded where the screen can pay for it. On a 320-unit
		# phone the board is nearly the full width, so the compact layout stands
		# the fighters BESIDE and partly behind it by design -- asking for 16px
		# of clearance there would be asking the layout to be a different
		# layout. What is checked on every arrangement is that the fighter is
		# not pushed off screen; the gap is checked where it is affordable.
		var room_for_gap: bool = d.x - f.size.x >= (e_body.size.x + p_body.size.x
			+ WANT_GAP * 2.0)
		if room_for_gap:
			if e_gap < WANT_GAP - GAP_SLACK:
				_faults.append("%s/%s: rival is only %.1fpx from the board"
					% [label, enemy.enemy_name, e_gap])
			if p_gap < WANT_GAP - GAP_SLACK:
				_faults.append("%s/%s: player is only %.1fpx from the board"
					% [label, enemy.enemy_name, p_gap])

		# Fully on screen, measured on the visible body.
		if ec.position.x + e_body.end.x > d.x + 1.0:
			_faults.append("%s/%s: rival's far side is off screen by %.1fpx"
				% [label, enemy.enemy_name, ec.position.x + e_body.end.x - d.x])
		if pc.position.x + p_body.position.x < -1.0:
			_faults.append("%s/%s: player's near side is off screen" % [label, enemy.enemy_name])

		# --- drift: several turns, then back to the same spot? ---
		var p_home := pc.position
		var e_home := ec.position
		for t in DRIFT_TURNS:
			var move: EnemyMove = enemy.moves[t % enemy.moves.size()]
			scene.set("_player_hp", GameState.player_max_hp)
			scene.set("_enemy_hp", maxi(1, enemy.max_hp / 2))
			scene.set("_enemy_guard", 0.0)
			scene.set("_pending_enemy_damage", 0)
			if enemy.is_boss:
				break          # the boss runs its own controller
			await scene.call("_resolve_chapter3_turn", move)
			for _f in 26:
				await get_tree().process_frame
		if not enemy.is_boss:
			var pd := (pc.position - p_home).length()
			var ed := (ec.position - e_home).length()
			if pd > 0.75 or ed > 0.75:
				_faults.append("%s/%s: after %d turns drifted player %.2fpx rival %.2fpx"
					% [label, enemy.enemy_name, DRIFT_TURNS, pd, ed])

		scene.queue_free()
		await get_tree().process_frame
