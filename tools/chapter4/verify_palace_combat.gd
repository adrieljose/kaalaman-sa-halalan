extends Node
const OUT := "res://output/chapter4_environments"
var faults: Array[String]=[]
var checks := 0
var performance_samples: Dictionary={}
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: faults.append(message); push_error(message)
func frames(n: int) -> void:
	for i in range(n): await get_tree().process_frame
func measure(battle: Node, active: bool) -> Dictionary:
	var env=battle._palace_environment
	env.visible=active; env.set_process(active); battle.background.visible=not active
	await frames(30)
	var start:=Time.get_ticks_usec()
	var process_ms:=0.0
	var draw_calls:=0.0
	for i in range(120):
		await get_tree().process_frame
		process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
		draw_calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return {"average_frame_ms":float(Time.get_ticks_usec()-start)/120000,"average_process_ms":process_ms/120,"average_draw_calls":draw_calls/120}
func _ready() -> void:
	await frames(1)
	for who in ["male","female"]:
		for stage in range(9):
			GameState.load_chapter(4); GameState.character=who; GameState.encounter_index=stage
			var battle=load("res://scenes/word_battle.tscn").instantiate()
			get_tree().root.add_child(battle); await frames(25)
			battle._sequence_running=true
			var env=battle._palace_environment
			# Real player choreography -> authoritative HP commit -> recovery, no lethal hit.
			var hp:int=battle._enemy_hp
			await battle._play_attack_sequence(40,false,battle._attack_tier(8))
			battle._sequence_running=true
			check(battle._enemy_hp==hp-40,"Player damage changed")
			check(env.reaction_count>=1,"Actual player attack missing room reaction")
			var before:int=env.reaction_count
			env.reaction_cooldown=0
			await battle._resolve_chapter3_turn(battle._enemy.moves[0])
			check(env.reaction_count>before,"Actual enemy attack missing room reaction")
			before=env.reaction_count
			env.reaction_cooldown=0
			await battle._resolve_chapter3_turn(battle._enemy.moves[1])
			check(env.reaction_count>before,"Actual ranged enemy attack missing room reaction")
			check(battle._player_hp>0,"Combat probe unexpectedly lethal")
			if stage==8 and who=="female":
				performance_samples.static=await measure(battle,false)
				performance_samples.animated=await measure(battle,true)
				var texture=env.room.texture
				var identity=env.get_instance_id()
				battle._enemy_hp=roundi(battle._enemy.max_hp*.51)
				await battle._enemy_take_hit(40)
				check(env.phase_target==1.0,"HP crossing failed environmental phase trigger")
				check(env.room.texture==texture and env.get_instance_id()==identity,"HP crossing replaced room")
			battle.queue_free(); await frames(5)
			print("PALACE COMBAT ",who," ",stage+1)
	# Environment-only lifecycle soak isolates any added leaks from existing battle code.
	var baseline_nodes:=Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var baseline_orphans:=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for cycle in range(45):
		var env=preload("res://scripts/environments/palace_environment.gd").new()
		env.size=Vector2(768,512); add_child(env); env.setup(cycle%9)
		var ref=weakref(env)
		for i in range(900): env._process(1.0/30.0)
		env.stop(); env.queue_free(); await frames(2)
		check(ref.get_ref()==null,"Standalone environment retained")
	await frames(10)
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==baseline_nodes,"Environment soak leaked nodes")
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==baseline_orphans,"Environment soak leaked orphan nodes")
	var report={"passed":faults.is_empty(),"faults":faults,"checks":checks,"real_player_attacks":18,"real_enemy_attacks":36,"environment_lifecycle_cycles":45,"performance":performance_samples,"scope":"Native Windows RTX3050, idle battle A/B sample; not a web or low-end mobile benchmark."}
	var file=FileAccess.open(OUT+"/combat_report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("PALACE COMBAT ","PASS" if faults.is_empty() else "FAIL"," ",report)
	get_tree().quit(0 if faults.is_empty() else 1)
