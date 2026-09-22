extends Node
## Local-only regression sweep. Never resolves a match or writes progression.
const OUT := "res://output/chapter5_environments"
var faults: Array[String] = []
var checks := 0
var timings: Array[float] = []
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: faults.append(message); push_error(message)
func frames(n: int) -> void:
	for i in range(n): await get_tree().process_frame
func shot(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+path+".png")
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await frames(1)
	DirAccess.make_dir_recursive_absolute(OUT)
	var old_character := GameState.character
	var old_chapter := GameState.chapter_number()
	var old_encounter := GameState.encounter_index
	for resolution in [Vector2i(1152,648),Vector2i(390,844)]:
		get_tree().root.size = resolution
		await frames(8)
		for who in ["male","female"]:
			for index in range(9):
				GameState.load_chapter(5)
				GameState.character=who
				GameState.encounter_index=index
				var battle = load("res://scenes/word_battle.tscn").instantiate()
				get_tree().root.add_child(battle)
				await frames(20)
				battle._sequence_running=true
				var env = battle._ch5_chamber
				check(is_instance_valid(env),"Missing environment %d"%index)
				if not is_instance_valid(env):
					battle.queue_free(); await frames(2); continue
				check(env.stage_index==index,"Incorrect stage mapping")
				check(env.room.texture==battle._enemy.background,"Backdrop resource mismatch")
				check(env.get_index()<battle.player_character.get_index(),"NPC layer above player")
				check(env.get_index()<battle.enemy_character.get_index(),"NPC layer above enemy")
				check(env.ambience.bus=="SFX" and env.ambience.playing,"Ambience routing/playback")
				check(env.ambience.stream.loop,"Ambience does not loop")
				check(env.actors.size()<=2,"NPC budget exceeded")
				for sprite in env.sprites:
					check(sprite!=null,"Missing NPC texture")
					check(sprite.get_image().detect_alpha()!=Image.ALPHA_NONE,"NPC opaque background")
				var before: float=env.elapsed
				get_tree().paused=true
				await frames(5)
				check(env.elapsed==before,"Clock advanced during pause")
				check(not env.ambience.can_process(),"Ambience not paused")
				get_tree().paused=false
				await frames(5)
				check(env.elapsed>before,"Did not resume")
				check(not env.react(2.0),"Weak hit triggered room reaction")
				battle._fx_impact("backdoor_dash",7.0,Color(.9,.7,.3),0.0)
				check(env.reaction_count==1,"Shared combat hook missed environment")
				check(not env.react(7.0),"Reaction spam cooldown failed")
				# Simulate long ambient lifecycle with a fixed isolated cosmetic seed.
				env.rng.seed=4219
				var tick_start:=Time.get_ticks_usec()
				for tick in range(3600):
					env._process(1.0/30.0)
					check(env.actors.size()<=2,"Long-run NPC budget")
					for actor in env.actors: check(actor.y<=.65,"NPC entered foreground floor")
					if tick%100==0: env.react(7.0)
				timings.append(float(Time.get_ticks_usec()-tick_start)/3600.0)
				check(env.spawned_count>1,"No randomized arrivals")
				check(env.npc_reaction_count>0,"No NPC reaction over seeded sequence")
				await frames(8)
				await shot("battle_%d_%s_%02d"%[resolution.x,who,index+1])
				if index==8:
					var identity=env.get_instance_id()
					var texture=env.room.texture
					battle._enemy_hp=roundi(battle._enemy.max_hp*.49)
					await battle._check_phase_change()
					check(env.phase_target==1.0,"Boss phase hook missed")
					check(env.phase_mix>0 and env.phase_mix<1,"Phase is not a smooth transition")
					for tick in range(150): env._process(1.0/30.0)
					check(env.phase_mix==1.0,"Phase transition did not complete")
					check(env.get_instance_id()==identity and env.room.texture==texture,"Boss backdrop replaced")
					for tick in range(500): env._process(1.0/30.0)
					check(env.actors.is_empty(),"Staff remain in escalated boss arena")
					await frames(5)
					await shot("boss_phase2_%d_%s"%[resolution.x,who])
					battle._enemy_hp=roundi(battle._enemy.max_hp*.21)
					await battle._ch5_try_final_reading()
					check(env.phase_target==2.0,"Final Reading hook missed")
					for tick in range(150): env._process(1.0/30.0)
					check(env.phase_mix==2.0,"Final Reading blend incomplete")
					check(env.get_instance_id()==identity and env.room.texture==texture,"Final Reading replaced backdrop")
					await shot("boss_final_reading_%d_%s"%[resolution.x,who])
					for turn in 3: battle._ch5_finish_turn()
					check(env.phase_target==1.0,"Final Reading expiration did not restore session")
				var reference=weakref(env)
				env.stop()
				check(not env.ambience.playing and not env.is_processing(),"Stop left activity running")
				battle._start_encounter(false)
				await frames(3)
				check(reference.get_ref()==null,"Retry leaked environment")
				check(battle._ch5_chamber.phase_mix==0.0,"Retry retained boss phase")
				var final_ref=weakref(battle._ch5_chamber)
				battle.queue_free()
				await frames(3)
				check(final_ref.get_ref()==null,"Scene exit leaked environment")
				print("CONGRESS verified ",resolution," ",who," stage ",index+1)
	GameState.load_chapter(old_chapter)
	GameState.character=old_character
	GameState.encounter_index=old_encounter
	var report={"passed":faults.is_empty(),"checks":checks,"faults":faults,"battle_cases":36,"characters":["Juan","Maria"],"resolutions":["1152x648","390x844"],"simulated_seconds_per_case":120,"environment_cpu_us_per_tick":timings,"note":"CPU simulation cost, not GPU FPS benchmark. No progression writes; no deployment."}
	var file=FileAccess.open(OUT+"/runtime_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("CONGRESS ","PASS" if faults.is_empty() else "FAIL"," checks=",checks)
	get_tree().quit(0 if faults.is_empty() else 1)
