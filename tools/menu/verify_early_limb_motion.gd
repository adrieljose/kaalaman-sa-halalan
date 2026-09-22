extends Node
const OUT="res://output/early_limb_motion/"
var faults:Array[String]=[]
func frames(n:int)->void:
	for i in n: await get_tree().process_frame
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(OUT+"frames")
	await frames(2)
	var count:=0
	for ch in [1,2]:
		GameState.load_chapter(ch)
		QuestionBank.set_context(ch,"easy")
		for index in GameState.chapter.encounter_count():
			GameState.encounter_index=index
			var battle=load("res://scenes/word_battle.tscn").instantiate()
			get_tree().root.add_child(battle)
			await frames(8)
			var actor=battle.get_node("EnemyCharacter")
			if actor.limb_motion==null: faults.append("missing shader %s"%index)
			var home:Vector2=actor.position
			actor.play_attack()
			await frames(35)
			actor.play_hit()
			await frames(35)
			actor.play_walk()
			await frames(12)
			actor.play_idle()
			var t:float=actor._limb_elapsed
			get_tree().paused=true
			await frames(4)
			if actor._limb_elapsed!=t: faults.append("pause")
			get_tree().paused=false
			if actor.position.distance_to(home)>.01: faults.append("position drift")
			for f in 24:
				if f==0:actor.play_attack()
				if f==12:actor.play_hit()
				await frames(2)
				if DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_jpg(OUT+"frames/frame_%04d.jpg"%(count*24+f),.88)
			var reference=weakref(actor)
			battle.queue_free()
			await frames(3)
			if reference.get_ref()!=null: faults.append("cleanup")
			count+=1
	var report=FileAccess.open(OUT+"tests.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"enemies":count,"faults":faults,"passed":faults.is_empty()},"  "))
	print("EARLY LIMB ",count," ",faults)
	get_tree().quit(0 if faults.is_empty() else 1)
