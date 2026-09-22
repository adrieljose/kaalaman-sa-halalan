extends Node
var faults: Array[String]=[]
var checks := 0
const OUT := "res://output/chapter3_skill_icons"
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: faults.append(message); push_error(message)
func frames(count: int) -> void:
	for _frame in range(count): await get_tree().process_frame

func _ready() -> void:
	await frames(1)
	var paths: Array[String]=[]
	var chapter: ChapterData=load("res://data/chapters/chapter_03.tres")
	for enemy: EnemyData in chapter.encounters:
		for move: EnemyMove in enemy.moves:
			check(move.icon!=null,"Missing icon: "+move.move_name)
			if move.icon==null: continue
			check(move.icon.get_size()==Vector2(64,64),"Wrong master size")
			check(move.icon.get_image().detect_alpha()!=Image.ALPHA_NONE,"Not transparent")
			check(not paths.has(move.icon.resource_path),"Duplicate icon path")
			paths.append(move.icon.resource_path)
	check(paths.size()==27,"Expected 27 assigned moves")
	for window_size in [Vector2i(1152,648),Vector2i(800,600),Vector2i(390,844)]:
		get_tree().root.size=window_size
		# LayoutDirector learns about a resized root asynchronously. Instantiating
		# immediately measured the previous profile, and on a compact profile the
		# full roster is hidden until its strip is opened -- hidden Containers do
		# not sort their children, so every row falsely appeared at one origin.
		await frames(8)
		for index in range(chapter.encounters.size()):
			GameState.load_chapter(3); GameState.encounter_index=index; GameState.character="male"; GameState.difficulty="easy"
			QuestionBank.set_context(3,"easy")
			var battle=load("res://scenes/word_battle.tscn").instantiate()
			get_tree().root.add_child(battle)
			await frames(20)
			battle._sequence_running=true
			check(battle._move_entries.size()==3,"Missing displayed move")
			if battle._move_strip.visible:
				battle._on_move_strip_pressed()
				await frames(3)
				check(battle.side_panel.visible,"Compact move list did not open")
			for selected in range(3):
				if battle._regular_combat!=null: battle._regular_combat.selected=selected
				else: battle._cong_meow.selected=selected
				battle._highlight_current_move()
				await frames(3)
				for i in range(battle._move_entries.size()):
					var entry: Dictionary=battle._move_entries[i]
					var icon: TextureRect=entry.icon
					var label: Label=entry.name
					check(icon.texture==chapter.encounters[index].moves[i].icon,"Wrong row mapping")
					check(icon.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Filtering blur")
					check(icon.size==Vector2(16,16),"Icon slot changed")
					check(not icon.get_global_rect().intersects(label.get_global_rect()),"Icon overlaps move name")
					check(icon.modulate.a>=.79,"Icon invisible in inactive state")
				if DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png(OUT+"/battle_%d_%d_%d.png" % [window_size.x,index,selected])
			battle.queue_free(); await frames(5)
	var report={"passed":faults.is_empty(),"faults":faults,"checks":checks,"moves":paths.size(),"encounters":9,"resolutions":3,"selected_states_per_encounter":3}
	var file=FileAccess.open(OUT+"/runtime_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("CH3 ICONS ","PASS" if faults.is_empty() else "FAIL"," checks=",checks)
	get_tree().quit(0 if faults.is_empty() else 1)
