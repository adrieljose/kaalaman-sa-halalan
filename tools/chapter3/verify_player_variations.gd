extends Node
const OUT := "res://output/player_ranged"
var faults: Array[String]=[]
var records: Array[Dictionary]=[]
var watching := false
var captures := 0
var pause_pending := false
var full_record := false

func check(ok: bool, message: String) -> void:
	if not ok: faults.append(message); push_error(message)

func watch(scene: Node, name: String, capture: bool) -> void:
	captures+=1
	var folder := OUT+"/recordings/"+name
	if capture: DirAccess.make_dir_recursive_absolute(folder)
	var frame := 0
	var ground: float=scene._shadows._subjects[0].ground
	while watching:
		if scene._player_variations.active and scene._player_variations.ranged_run:
			check(scene.player_character.position.distance_to(scene._player_variations.home)<.01,name+" ranged player travelled")
		check(scene._shadows._subjects[0].ground==ground,name+" shadow left floor")
		if capture:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(folder+"/frame_%03d.png" % frame)
		frame+=1
		await get_tree().create_timer(.12,false).timeout
	captures-=1

func pause_during(scene: Node, delay: float=.34) -> void:
	pause_pending=true
	await get_tree().create_timer(delay,false).timeout
	scene._open_pause_menu()
	var pos: Vector2=scene.player_character.position
	var hp: int=scene._enemy_hp
	var frame: int=scene._player_variations.animation_frame
	await get_tree().create_timer(.25,true).timeout
	check(pos.distance_to(scene.player_character.position)<.01,"player moved during pause")
	check(scene._enemy_hp==hp,"damage during pause")
	check(scene._player_variations.animation_frame==frame,"sprite advanced during pause")
	scene._on_resume_pressed()
	pause_pending=false

func cancellation_checks(scene: Node, handler: Node, character: String) -> void:
	for reason in ["restart","character","end"]:
		scene._enemy_hp=scene._enemy.max_hp; scene._enemy_guard=0; scene.hit_log.clear()
		handler.forced_index=1
		scene._play_attack_sequence(30,false,scene._attack_tier(4))
		while handler.launched==0: await get_tree().process_frame
		if reason=="restart": scene._start_encounter(true)
		elif reason=="character": GameState.character="female" if character=="male" else "male"
		else: handler.cancel() # Same hook used by _end_match; avoids progress writes.
		await get_tree().create_timer(.8,false).timeout
		check(scene.hit_log.is_empty(),"cancelled "+reason+" attack damaged enemy")
		check(handler.projectiles.is_empty(),"cancelled "+reason+" left projectile")
		check(not handler.active,"cancelled attack stuck")
		GameState.character=character

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	full_record="--record" in OS.get_cmdline_user_args()
	var only_ranged := "--ranged-only" in OS.get_cmdline_user_args()
	var visual_smoke := "--visual-smoke" in OS.get_cmdline_user_args()
	if visual_smoke: only_ranged=true
	var contexts := [[1,0],[1,-1],[2,0],[2,-1],[3,0],[3,2],[3,7],[3,8]]
	if only_ranged:
		contexts=[[1,0],[2,0],[3,0],[3,1],[3,2],[3,3],[3,4],[3,5],[3,6],[3,7],[3,8]]
	if visual_smoke: contexts=[[3,0]]
	for character in ["male","female"]:
		for context in contexts:
			GameState.load_chapter(context[0]); GameState.character=character
			GameState.encounter_index=GameState.chapter.encounter_count()-1 if context[1]==-1 else context[1]
			GameState.difficulty="easy"; QuestionBank.set_context(context[0],"easy")
			var scene: Node=load("res://scenes/word_battle.tscn").instantiate()
			scene.set_script(load("res://tools/chapter3/player_variations_test_battle.gd"))
			get_tree().root.add_child(scene)
			for f in range(50): await get_tree().process_frame
			scene._sequence_running=true
			var handler: Node=load("res://scripts/battle/player_attack_variations.gd").new()
			scene.add_child(handler); handler.setup(scene); scene._player_variations=handler
			var seen: Array=[]; var previous := -1
			for i in range(30):
				var next: int=handler.choose(character)
				check(next!=previous,"consecutive random repeat")
				previous=next
				if i<5: seen.append(next)
			check(seen.size()==5 and seen.count(0)==1 and seen.count(1)==1 and seen.count(2)==1 and seen.count(3)==1 and seen.count(4)==1,"shuffle bag coverage")
			check(handler.history["female" if character=="male" else "male"]==-1,"histories not independent")
			for slot in range(2 if only_ranged else 5):
				scene._enemy_hp=scene._enemy.max_hp
				scene._player_hp=100; scene.hit_log.clear()
				if context[0]==3:
					if scene._regular_combat!=null:
						scene._regular_combat.uses=0; scene._regular_combat.cooldown=0; scene._regular_combat.selected=2
					else:
						scene._cong_meow.guard_uses=0; scene._cong_meow.cooldown=0; scene._cong_meow.selected=2
					await scene._resolve_enemy_turn()
				handler.forced_index=slot
				var rest: Vector2=scene.player_character.position
				var rotation: float=scene.player_character.rotation
				var scale: Vector2=scene.player_character.scale
				var flip: bool=scene.player_character.flip_h
				var expected: int=scene._guarded_damage(30)
				var before: int=scene._enemy_hp
				watching=true
				watch(scene,character+"_"+str(slot),full_record and context==[3,0])
				if context==[1,0] and slot==3: pause_during(scene)
				if context==[1,0] and slot<2: pause_during(scene,.50 if slot==0 else .75)
				await scene._play_attack_sequence(30,false,scene._attack_tier(4))
				watching=false
				while captures>0 or pause_pending: await get_tree().process_frame
				check(scene._enemy_hp==before-expected,"damage changed by animation "+character+str(slot))
				check(scene.hit_log.size()==1,"more than one damage commit")
				if scene.hit_log.size()==1:
					check(scene.hit_log[0].frame==12 and scene.hit_log[0].ready and scene.hit_log[0].stage=="impact","damage not on contact frame")
				check(rest.distance_to(scene.player_character.position)<.01,"player root drift")
				check(is_equal_approx(rotation,scene.player_character.rotation),"rotation drift")
				check(scale.distance_to(scene.player_character.scale)<.01,"scale drift")
				check(flip==scene.player_character.flip_h,"orientation flip")
				check(not handler.active and not handler.overlay.visible and scene.player_character.self_modulate.a==1.0,"animation stuck")
				if slot<2:
					var count := 1 if slot==0 else 3 if character=="male" else 5
					check(handler.launched==count and handler.arrived==count,"projectile count mismatch")
					check(handler.projectiles.is_empty(),"orphan projectile")
				records.append({"character":character,"enemy":scene._enemy.enemy_name,"animation":handler.attack_id,"damage":expected,"events":handler.events.duplicate(true)})
			# Real accepted-answer entry point, not just the animation helper.
			scene._enemy_hp=scene._enemy.max_hp; scene._enemy_guard=0; scene.hit_log.clear()
			scene._question={"answer":"VOTE","fact":""}
			var bonus: Dictionary=scene._speed_bonus(4)
			var intended: int=scene._damage_for("VOTE",false,false,false,bonus.multiplier)
			scene._on_word_accepted("VOTE",false,false)
			while scene._sequence_running: await get_tree().process_frame
			check(scene.hit_log.size()==1 and scene.hit_log[0].damage==intended,"accepted-answer formula mismatch")
			if context==[1,0]:
				var prior: int=handler.selected
				for repeat in range(5):
					scene._enemy_hp=scene._enemy.max_hp; scene.hit_log.clear()
					scene._question={"answer":"VOTE","fact":""}
					scene._on_word_accepted("VOTE",false,false)
					while scene._sequence_running: await get_tree().process_frame
					check(handler.selected!=prior,"repeat in consecutive successful answers")
					check(scene.hit_log.size()==1,"consecutive answer duplicated damage")
					prior=handler.selected
				await cancellation_checks(scene,handler,character)
			print("PLAYER PASS ",character," ",scene._enemy.enemy_name," five variations + actual answer")
			scene.queue_free(); await get_tree().process_frame
	var report := {"passed":faults.is_empty(),"faults":faults,"tests":records,"attack_tests":records.size(),"correct_answer_tests":contexts.size()*2+(0 if visual_smoke else 10),"cancellation_checks":0 if visual_smoke else 6}
	var file := FileAccess.open(OUT+("/visual_smoke_report.json" if visual_smoke else "/ranged_report.json" if only_ranged else "/runtime_report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("PLAYER_VARIATIONS ","PASS" if faults.is_empty() else "FAIL"," attacks=",records.size()," faults=",faults.size())
	get_tree().quit(0 if faults.is_empty() else 1)
