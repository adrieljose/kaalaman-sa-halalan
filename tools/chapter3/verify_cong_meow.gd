extends Node
## Runs the real battle/controller. Test subclass suppresses ONLY progress awards.
const OUT := "res://output/cong_meow/screenshots"
var faults: Array[String]=[]
var captures := 0
var pause_checks := 0
var recordings := 0

func record_clip(name: String, duration: float) -> void:
	if DisplayServer.get_name()=="headless" or not "--record" in OS.get_cmdline_user_args(): return
	recordings+=1
	var folder := "res://output/cong_meow/recordings/"+name
	DirAccess.make_dir_recursive_absolute(folder)
	for i in range(int(duration/.10)):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+"/frame_%03d.png" % i)
		await get_tree().create_timer(.10,false).timeout
	recordings-=1

func check(ok: bool, message: String) -> void:
	if not ok: faults.append(message)

func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+name+".png")

func later(name: String, delay: float) -> void:
	if DisplayServer.get_name()=="headless": return
	captures+=1
	await get_tree().create_timer(delay,false).timeout
	await snap(name)
	captures-=1

func pause_during(scene: Node) -> void:
	pause_checks+=1
	await get_tree().create_timer(.55,false).timeout
	scene.call("_open_pause_menu")
	var hp: int=scene._player_hp
	var position_before: Vector2=scene.enemy_character.position
	await get_tree().create_timer(.45,true).timeout
	check(scene._player_hp==hp,"HP changed while paused")
	check(position_before.distance_to(scene.enemy_character.position)<.01,"body moved while paused")
	scene.call("_on_resume_pressed")
	pause_checks-=1

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	for character in ["male","female"]:
		GameState.load_chapter(3); GameState.encounter_index=8
		GameState.character=character; GameState.difficulty="easy"
		QuestionBank.set_context(3,"easy")
		var scene: Node=load("res://scenes/word_battle.tscn").instantiate()
		scene.set_script(load("res://tools/chapter3/cong_meow_test_battle.gd"))
		get_tree().root.add_child(scene)
		for i in range(60): await get_tree().process_frame
		scene._sequence_running=true
		var boss: Node=scene._cong_meow
		check(boss!=null,"boss missing")
		check(scene._enemy.moves.size()==3,"must have exactly 3 skills")
		check(scene._enemy.enemy_name=="CONG MEOW","wrong boss")
		var rest: Vector2=scene.enemy_character.position
		await snap(character+"_idle")
		for slot in range(3):
			boss.selected=slot
			scene._highlight_current_move()
			check(scene._current_move()==scene._enemy.moves[slot],"telegraph selection mismatch")
			check(scene._move_entries.size()==3,"move panel size wrong")
			scene._player_hp=100
			scene.player_heart_row.set_value(100,false)
			scene._pending_enemy_damage=0
			if slot==0:
				later(character+"_claw",.68)
			elif slot==1:
				later(character+"_phone",.57)
				later(character+"_meow",1.99)
			if character=="male": record_clip(["claw","viral","shield"][slot],1.8 if slot==0 else 2.1 if slot==1 else .8)
			await scene._resolve_enemy_turn()
			while recordings>0: await get_tree().process_frame
			var expected: int=scene._enemy.moves[slot].direct_damage
			check(scene._player_hp==100-expected,"wrong total damage slot %d" % slot)
			if slot<2:
				check(boss.impacts.size()==3+slot,"wrong number of impacts")
				check(boss.impacts==([8,8,14] if slot==0 else [6,6,8,12]),"wrong per-hit damage")
				check(scene.enemy_character.position.distance_to(rest)<.05,"root drift")
			else:
				await snap(character+"_shield")
				check(is_instance_valid(boss.shield),"shield visual missing")
				check(scene._guarded_damage(30)==15,"30 -> 15 preview failed")
				check(scene._guarded_damage(31)==16,"odd rounding preview failed")
				var potential: Vector2i=scene._potential_damage()
				check(scene._damage_badge._low==scene._guarded_damage(potential.x),"visible preview low mismatch")
				check(scene._damage_badge._high==scene._guarded_damage(potential.y),"visible preview high mismatch")
				check(boss.guard_uses==1 and boss.cooldown==2,"guard state not set")
				var before: int=scene._enemy_hp
				later(character+"_shield_consumed",.1)
				await scene._enemy_take_hit(30)
				check(scene._enemy_hp==before-15,"guard actual damage wrong")
				check(scene._enemy_guard==0 and not is_instance_valid(boss.shield),"shield not consumed")
				await scene._enemy_take_hit(30)
				check(scene._enemy_hp==before-45,"shield incorrectly reduced second hit")
		# Pause while combo is already at contact range, before first hit.
		boss.selected=0; scene._player_hp=100
		pause_during(scene)
		await scene._resolve_enemy_turn()
		check(scene._player_hp==70,"pause interrupted combo")
		check(boss.cooldown==1 and not boss.can_guard(),"cooldown should require two offense turns")
		boss.selected=1; scene._player_hp=100; scene._pending_enemy_damage=8
		await scene._resolve_enemy_turn()
		check(scene._player_hp==60,"mud not applied exactly once")
		check(boss.cooldown==0 and boss.can_guard(),"guard should be ready after two offense turns")
		# Pausing the ranged clock also freezes in-flight projectile positions.
		boss.selected=1; scene._player_hp=100
		pause_during(scene)
		await scene._resolve_enemy_turn()
		check(scene._player_hp==68,"ranged pause lost or duplicated damage")
		# Low HP makes attacks quicker, not stronger; HP and telegraph stay honest.
		var hp_before: int=scene._enemy_hp
		scene._enemy_hp=150; scene._player_hp=100; boss.selected=0
		var started := Time.get_ticks_msec()
		await scene._resolve_enemy_turn()
		check(Time.get_ticks_msec()-started<1850,"low HP combo failed to accelerate")
		check(scene._player_hp==70,"low HP incorrectly increased damage")
		scene._enemy_hp=hp_before
		# Exercise maximum uses without playing ten extra full attacks.
		for use in range(2):
			boss.selected=2; boss.cooldown=0
			await scene._resolve_enemy_turn()
			await scene._enemy_take_hit(10)
		check(boss.guard_uses==3,"max guards not tracked")
		boss.cooldown=0
		check(not boss.can_guard(),"fourth guard permitted")
		boss.selected=2
		await scene._resolve_enemy_turn()
		check(boss.guard_uses==3 and scene._enemy_guard==0,"forced choice bypassed guard cap")
		# Seeded AI distributions: opening physical-biased, mid more ranged;
		# current choice is stable across repeated reads, never rerolled by UI.
		for hp in [700,350,150]:
			scene._enemy_hp=hp; boss.previous=-1; boss.rng.seed=303
			var counts: Array[int]=[0,0,0]
			for roll in range(500):
				boss.choose_next(); counts[boss.selected]+=1
				var telegraph: EnemyMove=scene._current_move()
				check(telegraph==scene._current_move(),"UI rerolled next move")
			check(counts[2]==0,"capped guard selected by AI")
			check(counts[0]>counts[1] if hp==700 else counts[1]>counts[0],"HP weights incorrect")
		# Actual timeout -> lethal hit -> defeat result; no negative HP or late hits.
		boss.selected=0; scene._player_hp=3
		await scene._handle_timeout()
		check(scene._player_hp==0 and scene._match_over,"defeat not reached")
		check(scene.result_overlay.visible,"defeat overlay missing")
		check(boss.impacts==[3],"combo continued after lethal impact")
		await snap(character+"_defeat")
		# Retry resets all encounter-local shield/AI data.
		GameState.encounter_index=8
		scene._start_encounter(true); scene._sequence_running=true
		boss=scene._cong_meow
		check(boss.guard_uses==0 and boss.cooldown==0 and scene._enemy_guard==0,"retry leaked state")
		scene._enemy_hp=1
		await scene._enemy_take_hit(10)
		scene._end_match(true)
		check(scene._enemy_hp==0 and scene.test_completed and scene.result_overlay.visible,"victory not reached")
		await snap(character+"_victory")
		while captures>0 or pause_checks>0 or recordings>0: await get_tree().process_frame
		print("PASS ",character," all skills, impact HP, guard, AI, pause, mud, defeat, retry, victory")
		scene.queue_free()
		for i in range(3): await get_tree().process_frame
	for fault in faults: push_error(fault)
	print("CONG_MEOW ","PASS" if faults.is_empty() else "FAIL"," faults=",faults.size())
	get_tree().quit(0 if faults.is_empty() else 1)
