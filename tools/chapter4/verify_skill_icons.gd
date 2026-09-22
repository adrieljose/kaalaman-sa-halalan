extends Node
const OUT := "res://output/chapter4_skill_icons"
var faults: Array[String]=[]
var checks := 0
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: faults.append(message); push_error(message)
func frames(count: int) -> void:
	for i in range(count): await get_tree().process_frame
func _ready() -> void:
	await frames(1)
	var chapter: ChapterData=load("res://data/chapters/chapter_04.tres")
	var paths: Array[String]=[]
	for enemy: EnemyData in chapter.encounters:
		for move: EnemyMove in enemy.moves:
			check(move.icon!=null,"Missing icon: "+move.move_name)
			if move.icon==null: continue
			check(move.icon.get_size()==Vector2(64,64),"Wrong master size")
			check(move.icon.get_image().detect_alpha()!=Image.ALPHA_NONE,"No transparency")
			check(not paths.has(move.icon.resource_path),"Reused icon path")
			paths.append(move.icon.resource_path)
	check(paths.size()==27,"Expected 27 unique icons")
	for window in [Vector2i(1152,648),Vector2i(800,600),Vector2i(390,844)]:
		get_tree().root.size=window; await frames(8)
		for who in ["male","female"]:
			for index in range(9):
				GameState.load_chapter(4); GameState.encounter_index=index; GameState.character=who; GameState.difficulty="easy"
				var battle=load("res://scenes/word_battle.tscn").instantiate()
				get_tree().root.add_child(battle); await frames(20)
				battle._sequence_running=true
				check(battle._move_entries.size()==3,"Missing displayed skill")
				if battle._move_strip.visible:
					battle._on_move_strip_pressed(); await frames(3)
					check(battle.side_panel.visible,"Compact move list did not open")
				for selected in range(3):
					battle._move_index=selected
					battle._highlight_current_move(); await frames(4)
					for i in range(3):
						var entry: Dictionary=battle._move_entries[i]
						var icon: TextureRect=entry.icon
						check(icon.texture==chapter.encounters[index].moves[i].icon,"Wrong skill-icon pairing")
						check(icon.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Filtering blur")
						check(icon.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Icon stretched")
						check(icon.size==Vector2(16,16),"Slot size changed")
						check(icon.is_visible_in_tree(),"Icon hidden")
						check(icon.modulate.a>=.79,"Inactive icon too faint")
						check(not icon.get_global_rect().intersects(entry.name.get_global_rect()),"Icon overlaps name")
						check(battle.side_panel.get_global_rect().encloses(icon.get_global_rect()),"Icon clipped outside panel")
					if battle._move_strip.visible:
						check(battle._move_strip.icon==chapter.encounters[index].moves[selected].icon,"Compact telegraph mismatch")
						check(battle._move_strip.tooltip_text.begins_with(chapter.encounters[index].moves[selected].move_name),"Tooltip mismatch")
					if DisplayServer.get_name()!="headless":
						await RenderingServer.frame_post_draw
						get_viewport().get_texture().get_image().save_png(OUT+"/battle_%d_%s_%02d_%d.png"%[window.x,who,index+1,selected+1])
				battle.queue_free(); await frames(5)
				print("CH4 ICONS ",window," ",who," ",index+1)
	var report={"passed":faults.is_empty(),"faults":faults,"checks":checks,"icons":paths.size(),"battle_cases":54,"selected_states":162,"characters":["Juan","Maria"],"resolutions":["1152x648","800x600","390x844"]}
	var file=FileAccess.open(OUT+"/runtime_report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("CH4 ICONS ","PASS" if faults.is_empty() else "FAIL"," checks=",checks)
	get_tree().quit(0 if faults.is_empty() else 1)
