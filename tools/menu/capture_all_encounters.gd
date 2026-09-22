extends Node
const OUT := "res://output/chapter1_5_encounter_screenshots/"
func frames(n:int)->void:
	for i in n: await get_tree().process_frame
func _ready()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await frames(2)
	var records:Array=[]
	GameState.character="male"
	for chapter in range(1,6):
		GameState.load_chapter(chapter)
		QuestionBank.set_context(chapter,"easy")
		for index in GameState.chapter.encounter_count():
			GameState.encounter_index=index
			var enemy=GameState.current_enemy()
			var scene=load("res://scenes/word_battle.tscn").instantiate()
			get_tree().root.add_child(scene)
			await frames(30)
			await RenderingServer.frame_post_draw
			var filename="chapter_%d_%02d_%s.png"%[chapter,index+1,enemy.enemy_name.to_snake_case().replace(" ","_")]
			assert(get_viewport().get_texture().get_image().save_png(OUT+filename)==OK)
			records.append({"chapter":chapter,"encounter":index+1,"name":enemy.enemy_name,"file":filename})
			scene.queue_free()
			await frames(3)
		print("CAPTURED CHAPTER ",chapter)
	var file=FileAccess.open(OUT+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  "))
	print("CAPTURED ",records.size()," ENCOUNTERS")
	get_tree().quit()
