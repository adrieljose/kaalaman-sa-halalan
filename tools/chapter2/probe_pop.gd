extends Node
## Measures the one-frame jump when a skill takes the body off the idle pose.
##
## The idle personality writes rotation and scale every frame; the choreography
## tweens the same two. Handing over between them zeroes both, and a value that
## changes in a single frame is a pop no matter how smooth the tweens either
## side of it are.

func _ready() -> void:
	await get_tree().process_frame
	GameState.load_chapter(2)
	var chapter = load("res://data/chapters/chapter_02.tres")
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	add_child(scene)
	for i in 90:
		await get_tree().process_frame

	var rival: AnimatedCharacter = scene.get_node("EnemyCharacter")
	var worst := 0.0
	for enemy in chapter.encounters:
		rival.configure_from(enemy)
		rival.pose_locked = false
		# Let the idle settle into its lean and mid-breath.
		for i in 40:
			await get_tree().process_frame
		var rot_before := rad_to_deg(rival.rotation)
		var scale_before := rival.scale
		scene._body_begin(rival, Vector2(0.5, 1.0))
		var rot_jump: float = absf(rad_to_deg(rival.rotation) - rot_before)
		var scale_jump: float = (rival.scale - scale_before).length()
		worst = maxf(worst, rot_jump)
		print("%-16s idle rot %5.2f deg -> pop %5.2f deg   scale pop %.4f" % [
			enemy.enemy_name, rot_before, rot_jump, scale_jump])
		scene._body_home.erase(rival)
	print("worst one-frame rotation pop: %.2f deg" % worst)
	get_tree().quit(0)
