extends Node
const OUT := "res://output/chapter3_combat/screenshots"
var faults: Array[String]=[]
var captures := 0
var pauses := 0
var tested := 0
var recording := false

func record_skill(name: String) -> void:
	if DisplayServer.get_name()=="headless" or not "--record" in OS.get_cmdline_user_args(): return
	var folder := "res://output/chapter3_combat/recordings/"+name
	DirAccess.make_dir_recursive_absolute(folder)
	recording=true
	var n := 0
	while recording:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(folder+"/frame_%03d.png" % n)
		n+=1
		await get_tree().create_timer(.12,false).timeout

func check(ok: bool, message: String) -> void:
	if not ok: faults.append(message); push_error(message)

func later(name: String, delay: float) -> void:
	if DisplayServer.get_name()=="headless": return
	captures+=1
	await get_tree().create_timer(delay,false).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"/"+name+".png")
	captures-=1

func pause_during(scene: Node) -> void:
	pauses+=1
	await get_tree().create_timer(.65,false).timeout
	scene.call("_open_pause_menu")
	var hp: int=scene._player_hp
	var pos: Vector2=scene.enemy_character.position
	await get_tree().create_timer(.3,true).timeout
	check(scene._player_hp==hp,"damage during pause")
	check(pos.distance_to(scene.enemy_character.position)<.01,"movement during pause")
	scene.call("_on_resume_pressed")
	pauses-=1

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	for character in ["male","female"]:
		GameState.load_chapter(3); GameState.character=character; GameState.difficulty="easy"
		QuestionBank.set_context(3,"easy")
		for index in range(8):
			GameState.encounter_index=index
			var scene: Node=load("res://scenes/word_battle.tscn").instantiate()
			get_tree().root.add_child(scene)
			for f in range(60): await get_tree().process_frame
			scene._sequence_running=true
			var handler: Node=scene._regular_combat
			check(handler!=null,"missing regular handler")
			if handler==null: get_tree().quit(1); return
			var rest: Vector2=scene.enemy_character.position
			var slug: String=handler.SLUGS[index]
			for slot in range(3):
				handler.selected=slot
				var move: EnemyMove=scene._enemy.moves[slot]
				scene._player_hp=100; scene._pending_enemy_damage=3
				scene._enemy_hp=scene._enemy.max_hp
				later(character+"_"+slug+"_"+str(slot),1.42 if slot==0 else .94)
				if index==0 and slot==0: pause_during(scene)
				if character=="male": record_skill(slug+"_"+str(slot))
				await scene._resolve_enemy_turn()
				recording=false
				await get_tree().create_timer(.15,false).timeout
				check(scene._player_hp==97-move.direct_damage,slug+" damage/mud "+str(slot))
				check(handler.stage=="idle",slug+" unfinished recovery")
				check(rest.distance_to(scene.enemy_character.position)<.5,slug+" root drift")
				if slot<2:
					var count: int=(3 if index in [3,4,6] else 1) if slot==0 else (4 if index in [3,6] else 1 if index==4 else 5 if index==7 else 3)
					check(handler.impacts.size()==count,slug+" impact count "+str(slot))
					check(handler.events[0].player_hp==100,slug+" anticipation damage")
					if slot==1: check(handler.releases==count,slug+" projectile count")
				else:
					check(scene._guarded_damage(100)==65,slug+" guard preview")
					check(handler.uses==1 and handler.cooldown==2,slug+" guard limits")
					check(not handler.can_guard(),slug+" repeat guard allowed")
					var hp: int=scene._enemy_hp
					await scene._enemy_take_hit(20)
					check(scene._enemy_hp==hp-13,slug+" guard damage")
					check(scene._enemy_guard==0.0,slug+" guard not consumed")
					await scene._enemy_take_hit(20)
					check(scene._enemy_hp==hp-33,slug+" guard leaked")
					check(rest.distance_to(scene.enemy_character.position)<.5,slug+" block drift")
				tested+=1
			while captures>0 or pauses>0: await get_tree().process_frame
			handler.uses=3; handler.cooldown=0
			check(not handler.can_guard(),slug+" max guard limit")
			scene._start_encounter(true)
			check(scene._enemy_guard==0.0 and scene._regular_combat.uses==0,slug+" retry reset")
			print("REGULAR PASS ",character," ",slug)
			scene.queue_free()
			await get_tree().process_frame
	var report := {"tested_skills":tested,"characters":["Juan","Maria"],"faults":faults,"passed":faults.is_empty()}
	var file := FileAccess.open("res://output/chapter3_combat/runtime_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("REGULAR_COMBAT ","PASS" if faults.is_empty() else "FAIL"," skills=",tested," faults=",faults.size())
	get_tree().quit(0 if faults.is_empty() else 1)
