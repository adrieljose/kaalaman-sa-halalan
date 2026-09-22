extends Node
## Run with the editor executable, not an export. Does not award progression.
const OUT := "res://output/screenshots/chapter3_integrated"
var faults: Array[String] = []
var shots_pending := 0

func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	GameState.load_chapter(3)
	GameState.difficulty = "easy"
	QuestionBank.set_context(3, "easy")
	for i in range(8):
		GameState.encounter_index = i
		var enemy: EnemyData = GameState.current_enemy()
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for f in range(70):
			await get_tree().process_frame
		scene.set("_sequence_running", true)
		var slug := enemy.enemy_name.to_lower().replace(" ", "_")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
		var visual_only := "--visual-only" in OS.get_cmdline_user_args()
		var shot_dir := OUT
		if visual_only:
			shot_dir += "/layout_%dx%d" % [get_viewport().get_visible_rect().size.x,get_viewport().get_visible_rect().size.y]
			DirAccess.make_dir_recursive_absolute(shot_dir)
		if DisplayServer.get_name()!="headless":
			get_viewport().get_texture().get_image().save_png("%s/%02d_%s_idle.png" % [shot_dir,i+1,slug])
		if visual_only:
			scene.queue_free()
			await get_tree().process_frame
			continue
		var body: AnimatedCharacter = scene.find_child("EnemyCharacter",true,false)
		var rest_position: Vector2 = body.position
		_check(body.texture != null, slug + " missing texture")
		_check(body.texture.get_image().get_format() == Image.FORMAT_RGBA8, slug + " missing alpha")
		for j in range(3):
			var move: EnemyMove = enemy.moves[j]
			scene.set("_move_index",j)
			if scene._regular_combat != null: scene._regular_combat.selected=j
			scene.set("_player_hp",100)
			scene.set("_enemy_hp",enemy.max_hp-40)
			scene.set("_enemy_guard",0.0)
			scene.set("_pending_enemy_damage",0)
			if j==0:
				_capture_mid_move("%s/%02d_%s_attack.png" % [OUT,i+1,slug], move.animation_style=="slam")
			await scene.call("_resolve_enemy_turn")
			_check(scene.get("_player_hp")==100-move.direct_damage, slug+" incorrect player damage")
			_check(scene.get("_move_index")==j+1,slug+" rotation did not advance")
			if move.guard_reduction>0.0:
				_check(is_equal_approx(scene.get("_enemy_guard"),0.35),slug+" guard missing")
				_check(scene.call("_guarded_damage",100)==65,slug+" guard preview wrong")
				var before: int=scene.get("_enemy_hp")
				await scene.call("_enemy_take_hit",20)
				_check(scene.get("_enemy_hp")==before-13,slug+" guard reduction wrong")
				_check(scene.get("_enemy_guard")==0.0,slug+" guard not consumed")
				await scene.call("_enemy_take_hit",20)
				_check(scene.get("_enemy_hp")==before-33,slug+" guard leaked to second hit")
			if move.self_heal>0:
				_check(scene.get("_enemy_hp")==enemy.max_hp-16,slug+" heal wrong")
				scene.set("_enemy_hp",enemy.max_hp-2)
				scene.set("_move_index",j)
				await scene.call("_resolve_enemy_turn")
				_check(scene.get("_enemy_hp")==enemy.max_hp,slug+" healing exceeded max HP")
			_check(body.position.distance_to(rest_position)<0.5,slug+" root drift")
		# Retry/next-encounter resets defense; mud still hurts on a defense turn.
		scene.set("_move_index",2)
		if scene._regular_combat != null: scene._regular_combat.selected=2
		scene.set("_player_hp",100)
		scene.set("_pending_enemy_damage",3)
		await scene.call("_resolve_enemy_turn")
		_check(scene.get("_player_hp")==97,slug+" defense swallowed mud damage")
		scene.call("_start_encounter",true)
		_check(scene.get("_enemy_guard")==0.0,slug+" guard survived retry")
		while shots_pending>0:
			await get_tree().process_frame
		print("PASS ",enemy.enemy_name," / 3 skills, guard/heal, mud, reset, screenshots")
		scene.queue_free()
		await get_tree().process_frame
	# Chapter 3 now finishes with the dedicated three-skill boss.
	_check(GameState.chapter.encounter_count()==9,"encounter count changed")
	_check(GameState.chapter.encounter_at(8).enemy_name=="CONG MEOW","Chapter 3 boss missing")
	for chapter_no in [1,2]:
		_check(GameState.load_chapter(chapter_no),"earlier chapter cannot load")
		GameState.encounter_index=0
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for f in range(45): await get_tree().process_frame
		scene.set("_sequence_running",true)
		scene.set("_player_hp",100)
		var move: EnemyMove=GameState.current_enemy().moves[0]
		await scene.call("_resolve_enemy_turn")
		_check(scene.get("_player_hp")==100-move.direct_damage,"chapter %d attack regression" % chapter_no)
		scene.queue_free()
		await get_tree().process_frame
	for fault in faults: push_error(fault)
	print("CHAPTER3_INTEGRATION ","PASS" if faults.is_empty() else "FAIL", " faults=",faults.size())
	get_tree().quit(0 if faults.is_empty() else 1)

func _check(ok: bool,message: String) -> void:
	if not ok: faults.append(message)

func _capture_mid_move(path: String,melee: bool) -> void:
	if DisplayServer.get_name()=="headless": return
	shots_pending+=1
	await get_tree().create_timer(0.81 if melee else 0.41).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	shots_pending-=1
