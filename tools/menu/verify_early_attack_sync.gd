extends Node
const OUT := "res://output/early_attack_sync/"
var faults:Array[String]=[]
var active:Node
var recording:=false
var clock:=0.0
var frame:=0
var records:Array=[]
func frames(n:int)->void:
	for i in n: await get_tree().process_frame
func check(ok:bool,message:String)->void:
	if not ok: faults.append(message)
func _process(delta:float)->void:
	if not recording or get_tree().paused: return
	clock+=delta
	if clock<.1: return
	clock=0
	var img:=get_viewport().get_texture().get_image()
	img.resize(640,360,Image.INTERPOLATE_NEAREST)
	img.save_jpg(OUT+"frames/%05d.jpg"%frame,.85)
	frame+=1
func pause_check(actor:AnimatedCharacter)->void:
	await get_tree().create_timer(.25,false).timeout
	get_tree().paused=true
	var before:=actor.combat_joint_pose
	var time:=actor._limb_elapsed
	await get_tree().create_timer(.15,true).timeout
	check(actor.combat_joint_pose==before,"joint movement during pause")
	check(actor._limb_elapsed==time,"limb clock during pause")
	get_tree().paused=false
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(OUT+"frames")
	await frames(2)
	var tested:=0
	for character in ["male","female"]:
		GameState.character=character
		for chapter in [1,2]:
			GameState.load_chapter(chapter)
			QuestionBank.set_context(chapter,"easy")
			for index in GameState.chapter.encounter_count():
				GameState.encounter_index=index
				active=load("res://scenes/word_battle.tscn").instantiate()
				get_tree().root.add_child(active)
				await frames(15)
				active._sequence_running=true
				var actor:AnimatedCharacter=active.enemy_character
				var home:=actor.position
				var slot:=0
				for move:EnemyMove in active._enemy.moves:
					var start:=frame
					active._player_hp=10000
					active._enemy_hp=10000
					recording=character=="male"
					if slot==0: pause_check(actor)
					await active._play_signature_move(move)
					recording=false
					check(actor.position.distance_to(home)<1.0,active._enemy.enemy_name+" root drift "+move.signature_id())
					check(actor.combat_joint_pose.length()<.001,"joint recovery "+move.signature_id())
					check(not actor.pose_locked,"pose lock "+move.signature_id())
					check(not actor.is_rigged(),"rig not released "+move.signature_id())
					records.append({"character":character,"enemy":active._enemy.enemy_name,"skill":move.signature_id(),"start_frame":start,"end_frame":frame})
					tested+=1
					slot+=1
				print("SYNC TEST ",character," ",active._enemy.enemy_name," total=",tested)
				var ref:WeakRef=weakref(actor)
				active.queue_free()
				await frames(3)
				check(ref.get_ref()==null,"actor cleanup")
	var report:=FileAccess.open(OUT+"tests.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"tested":tested,"faults":faults,"records":records,"passed":faults.is_empty()},"  "))
	print("ATTACK SYNC DONE ",tested," faults=",faults)
	get_tree().quit(0 if faults.is_empty() else 1)
