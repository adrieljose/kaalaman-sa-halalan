extends Node
## Regression: no ranged HP loss before the real final-projectile callback.
var faults: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	for who in ["male", "female"]:
		GameState.character = who
		GameState.load_chapter(5)
		QuestionBank.set_context(5, "easy")
		for index in 9:
			GameState.encounter_index = index
			var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
			get_tree().root.add_child(scene)
			for f in 15:
				await get_tree().process_frame
			var enemy: EnemyData = GameState.chapter.encounter_at(index)
			var move: EnemyMove = enemy.moves[1]
			if index == 8:
				scene.set("_boss_phase", 2)
				scene.set("_ch5_final_reading_active", true)
				scene.set("_ch5_final_reading_turns", 3)
			scene.set("_player_hp", 1000)
			scene.set("_pending_enemy_damage", 0)
			var finished := [false]
			_run(scene, move, finished)
			var clock := Time.get_ticks_msec()
			var saw_pending := false
			var pause_checked := false
			while not finished[0] and Time.get_ticks_msec() - clock < 12000:
				await get_tree().process_frame
				var pending: bool = scene.get("_ch5_ranged_contact_pending")
				saw_pending = saw_pending or pending
				if pending and int(scene.get("_player_hp")) != 1000:
					faults.append("%s/%s: damage before contact" % [who, move.move_name])
				var projectile := scene.get_node_or_null("ContactProjectile") as Control
				if is_instance_valid(projectile) and not pause_checked:
					pause_checked = true
					var position_before := projectile.position
					get_tree().paused = true
					await get_tree().create_timer(0.20, true).timeout
					if projectile.position != position_before or int(scene.get("_player_hp")) != 1000:
						faults.append("%s/%s: projectile/damage advanced while paused" % [who, move.move_name])
					get_tree().paused = false
			if not finished[0] or not saw_pending:
				faults.append("%s/%s: missing contact or incomplete turn" % [who, move.move_name])
			var gain: float = scene.call("_ch5_damage_gain", move.signature_id())
			var expected := roundi(move.direct_damage * gain)
			if 1000 - int(scene.get("_player_hp")) != expected:
				faults.append("%s/%s: wrong damage total" % [who, move.move_name])
			if index == 3:
				scene.set("_ch5_last_guard_turn", int(scene.get("_move_index")))
				if not scene.call("_ch5_guard_on_cooldown", enemy.moves[2]):
					faults.append("Quorum Escape has no cooldown")
				scene.set("_move_index", int(scene.get("_move_index")) + 2)
				if scene.call("_ch5_guard_on_cooldown", enemy.moves[2]):
					faults.append("Quorum Escape never becomes available")
			print("contact: %s / %s / damage %d" % [who, move.move_name, expected])
			# Real defense cast, reduced damage, one-hit consumption and zero-hit safety.
			scene.set("_enemy_hp", enemy.max_hp)
			scene.set("_enemy_guard", 0.0)
			await scene.call("_resolve_chapter3_turn", enemy.moves[2])
			if float(scene.get("_enemy_guard")) <= 0.0:
				faults.append("%s: defense did not activate" % enemy.enemy_name)
			var reduced: int = scene.call("_guarded_damage", 40)
			await scene.call("_enemy_take_hit", 40)
			if int(scene.get("_enemy_hp")) != enemy.max_hp - reduced or float(scene.get("_enemy_guard")) != 0.0:
				faults.append("%s: guard damage/consumption failed" % enemy.enemy_name)
			await scene.call("_enemy_take_hit", 0)
			if int(scene.get("_enemy_hp")) != enemy.max_hp - reduced:
				faults.append("%s: zero damage changed HP" % enemy.enemy_name)
			scene.queue_free()
			await get_tree().process_frame
	for fault in faults:
		push_error(fault)
	print("CONTACT TEST: %d faults" % faults.size())
	get_tree().quit(0 if faults.is_empty() else 1)

func _run(scene: Node, move: EnemyMove, finished: Array) -> void:
	await scene.call("_resolve_chapter3_turn", move)
	finished[0] = true
