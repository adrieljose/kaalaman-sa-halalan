extends Node
var faults: Array[String] = []
var events: Array[Dictionary] = []
var battle: Node
var watching := false
var attack_cases := 0
var rows: Array[Dictionary] = []

func check(value: bool, message: String) -> void:
	if not value: faults.append(message); push_error(message)

func heard(identity: String, kind: String, take: int) -> void:
	if watching:
		check(battle._player_variations.contact_ready,"voice before final projectile/contact")
		check(battle._player_variations.stage=="impact","voice outside impact")
		check(battle._enemy_hp < battle._enemy.max_hp,"voice before HP reduction")
	events.append({"identity":identity,"kind":kind,"take":take})

func _ready() -> void:
	Audio.enemy_reaction_started.connect(heard)
	await get_tree().process_frame
	var chapter_id := 1 if "--chapter1" in OS.get_cmdline_user_args() else 2 if "--chapter2" in OS.get_cmdline_user_args() else 3
	var out := "res://output/speech/chapter%d" % chapter_id
	var chapter: ChapterData=load("res://data/chapters/chapter_%02d.tres" % chapter_id)
	for data: EnemyData in chapter.encounters:
		check(Audio.has_enemy_reaction_voice(data.enemy_name),"missing identity "+data.enemy_name)
		var key: String=(Audio.CH1_VOICES if chapter_id==1 else Audio.CH2_VOICES if chapter_id==2 else Audio.CH3_VOICES).get(data.enemy_name,"")
		for kind in ["hurt_01","hurt_02","hurt_03","hurt_04","defeat"]:
			var stream=load("res://assets/audio/sfx/voices/chapter%d/%s/%s.ogg" % [chapter_id,key,kind])
			check(stream != null and stream.get_length()>0,"empty clip "+key+kind)
		Audio.reset_voice(); events.clear()
		var last := -1
		var seen: Array[int] = []
		for n in range(80):
			Audio._voice_player.stop(); Audio._voice_until=0
			Audio.play_enemy_reaction(data.enemy_name)
			var take: int=events[-1].take
			check(take!=last,"immediate repeat "+key)
			if not seen.has(take): seen.append(take)
			last=take
		check(seen.size()==4,"variant missing from randomizer "+key)
		var count := events.size()
		for burst in range(10): Audio.play_enemy_reaction(data.enemy_name)
		check(events.size()==count,"cooldown spam "+key)
		Audio.play_enemy_reaction(data.enemy_name,true)
		check(events.size()==count+1 and events[-1].kind=="defeat","defeat failed to interrupt hurt")
		Audio.play_enemy_reaction(data.enemy_name,true)
		Audio.play_enemy_reaction(data.enemy_name)
		check(events.size()==count+1,"hurt/duplicate defeat after death")
		Audio.reset_voice()
		count=events.size()
		get_tree().paused=true
		var suppressed: bool=Audio.play_enemy_reaction(data.enemy_name)
		get_tree().paused=false
		check(suppressed and events.size()==count and not Audio._voice_player.playing,"paused request must suppress without fallback")
	if chapter_id==2:
		Audio.reset_voice(); events.clear()
		var seen: Array[int]=[]
		var last := -1
		for n in range(80):
			Audio._voice_player.stop(); Audio._voice_until=0
			Audio.play_enemy_reaction("Don Eraptado",false,false,true)
			var take: int=events[-1].take
			check(events[-1].kind=="heavy" and take!=last,"boss heavy bank/repeat")
			if not seen.has(take): seen.append(take)
			last=take
		check(seen.size()==4,"boss missing heavy variants")
		Audio.reset_voice()
	if "--unit-only" in OS.get_cmdline_user_args():
		var file=FileAccess.open(out+"/unit_report.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"passed":faults.is_empty(),"faults":faults,"random_draws":chapter.encounters.size()*80+(80 if chapter_id==2 else 0),"paused_identities":chapter.encounters.size()},"  ")); file.close()
		print("CH",chapter_id,"_VOICE_UNITS ","PASS" if faults.is_empty() else "FAIL")
		get_tree().quit(0 if faults.is_empty() else 1)
		return
	for character in ["male","female"]:
		for index in range(chapter.encounters.size()):
			GameState.load_chapter(chapter_id); GameState.character=character
			GameState.encounter_index=index; GameState.difficulty="easy"
			QuestionBank.set_context(chapter_id,"easy")
			battle=load("res://scenes/word_battle.tscn").instantiate()
			battle.set_script(load("res://tools/audio/chapter3_voice_test_battle.gd"))
			get_tree().root.add_child(battle)
			for frame in range(35): await get_tree().process_frame
			battle._sequence_running=true
			var handler: Node=load("res://scripts/battle/player_attack_variations.gd").new()
			battle.add_child(handler); handler.setup(battle); battle._player_variations=handler
			for slot in [0,1,4]:
				Audio.reset_voice(); events.clear()
				battle._enemy_hp=battle._enemy.max_hp
				handler.forced_index=slot
				watching=true
				await battle._play_attack_sequence(15,false,battle._attack_tier(4))
				watching=false
				check(events.size()==1,"expected single final-hit reaction "+character+str(index)+str(slot))
				check(battle._enemy_hp==battle._enemy.max_hp-15,"damage changed")
				attack_cases+=1
			Audio.reset_voice(); events.clear()
			var hp: int=battle._enemy_hp
			await battle._enemy_take_hit(0)
			await battle._enemy_take_hit(-10)
			check(events.is_empty() and hp==battle._enemy_hp,"zero/invalid damage spoke or altered HP")
			# Existing guard skills keep a one-HP floor. Test genuine reduced damage.
			if chapter_id<3:
				battle._enemy_guard=.35 # Exercise the existing shared mitigation path.
			elif battle._regular_combat!=null:
				battle._regular_combat.uses=0; battle._regular_combat.cooldown=0; battle._regular_combat.selected=2
			else:
				battle._cong_meow.guard_uses=0; battle._cong_meow.cooldown=0; battle._cong_meow.selected=2
			if chapter_id==3: await battle._resolve_enemy_turn()
			var intended: int=battle._guarded_damage(15)
			Audio.reset_voice(); events.clear()
			await battle._enemy_take_hit(15)
			check(events.size()==1 and battle._enemy_hp==hp-intended,"reduced damage voice mismatch")
			check(Audio._voice_player.volume_db == -3.0,"reduced reaction gain")
			if chapter_id<3:
				# Inject a resolved zero only in the fixture, not the game's formula.
				Audio.reset_voice(); events.clear()
				var before_block: int=battle._enemy_hp
				battle.force_full_block=true; battle._enemy_guard=.35
				await battle._enemy_take_hit(15)
				check(events.is_empty() and battle._enemy_hp==before_block,"fully mitigated damage spoke")
				battle.force_full_block=false
				if battle._enemy.enemy_name=="Don Eraptado":
					battle._enemy_hp=241
					Audio.reset_voice(); events.clear()
					await battle._enemy_take_hit(1)
					check(events.size()==1 and events[0].kind=="heavy" and events[0].identity=="don_eraptado","half-HP crossing did not preserve identity/switch bank")
					await battle._check_phase_change()
					check(battle._boss_phase==2,"existing boss phase transition failed")
			Audio.reset_voice(); events.clear()
			await battle._enemy_take_hit(battle._enemy_hp)
			check(events.size()==1 and events[0].kind=="defeat","lethal hit did not replace hurt")
			check(not Audio._voice_player.playing,"defeat wait did not finish")
			await battle._enemy_take_hit(15)
			check(events.size()==1,"dead enemy spoke again")
			Audio.reset_voice(); Audio.play_enemy_reaction(battle._enemy.enemy_name)
			battle._open_pause_menu()
			check(not Audio._voice_player.playing,"pause leaked voice")
			battle._on_resume_pressed()
			check(not Audio._voice_player.playing,"resume replayed stale voice")
			Audio.play_enemy_reaction(battle._enemy.enemy_name)
			battle._start_encounter(false)
			check(not Audio._voice_player.playing,"encounter reset leaked voice")
			Audio.play_enemy_reaction(battle._enemy.enemy_name)
			battle._end_match(true)
			check(not Audio._voice_player.playing,"battle end leaked voice")
			Audio.reset_voice(); Audio.play_enemy_reaction(battle._enemy.enemy_name)
			rows.append({"character":character,"enemy":battle._enemy.enemy_name,"passed":faults.is_empty()})
			battle.queue_free(); await get_tree().process_frame
			check(not Audio._voice_player.playing,"scene exit leaked voice")
			print("CH",chapter_id," VOICE PASS ",character," encounter ",index+1)
	var volume := Audio.sfx_volume_percent()
	Audio.set_sfx_volume_percent(0)
	check(Audio._voice_player.bus==Audio.SFX_BUS and Audio.sfx_volume_percent()==0,"mute routing")
	Audio.set_sfx_volume_percent(35)
	check(absf(Audio.sfx_volume_percent()-35)<.01,"volume routing")
	Audio.set_sfx_volume_percent(volume)
	var report={"passed":faults.is_empty(),"faults":faults,"assets":chapter.encounters.size()*5+(4 if chapter_id==2 else 0),"random_draws":chapter.encounters.size()*80+(80 if chapter_id==2 else 0),"attack_cases":attack_cases,"encounters":rows,"cooldown_seconds":Audio.CH3_VOICE_COOLDOWN}
	var file=FileAccess.open(out+"/runtime_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("CH",chapter_id,"_VOICES ","PASS" if faults.is_empty() else "FAIL"," attacks=",attack_cases," faults=",faults.size())
	get_tree().quit(0 if faults.is_empty() else 1)
