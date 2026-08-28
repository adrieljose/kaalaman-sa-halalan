extends Node
## Confirms each Chapter 2 rival idles differently, and that the idle yields
## while a skill is choreographing the body.
##
## Sampling rotation/scale over time is the only honest check: the frames are
## identical across rivals, so "does it look different" is entirely a question
## of what the pose code is doing to them.

func _ready() -> void:
	await get_tree().process_frame
	GameState.load_chapter(2)
	var chapter = load("res://data/chapters/chapter_02.tres")
	var seen := {}
	for enemy in chapter.encounters:
		var actor := AnimatedCharacter.new()
		actor.size = Vector2(98, 180)
		add_child(actor)
		actor.configure_from(enemy)
		if actor.idle_style.is_empty():
			print("%-16s NO STYLE" % enemy.enemy_name)
			actor.queue_free()
			continue
		# Sample a second of idle and record how far it travels.
		var rot_min := 999.0
		var rot_max := -999.0
		var sy_min := 999.0
		var sy_max := -999.0
		for i in 60:
			actor._tick_idle_pose(1.0 / 60.0)
			rot_min = minf(rot_min, rad_to_deg(actor.rotation))
			rot_max = maxf(rot_max, rad_to_deg(actor.rotation))
			sy_min = minf(sy_min, actor.scale.y)
			sy_max = maxf(sy_max, actor.scale.y)
		var key := "%.2f/%.4f" % [rot_max - rot_min, sy_max - sy_min]
		seen[key] = seen.get(key, 0) + 1
		print("%-16s sway %5.2f deg   breath %6.4f   lean %5.2f" % [
			enemy.enemy_name, rot_max - rot_min, sy_max - sy_min,
			(rot_max + rot_min) * 0.5])

		# Locked: a skill owns the body, so the idle must not move it.
		actor.pose_locked = true
		var before := actor.rotation
		for i in 30:
			actor._tick_idle_pose(1.0 / 60.0)
		if not is_equal_approx(actor.rotation, before):
			print("  ! %s kept posing while locked" % enemy.enemy_name)
		actor.queue_free()

	print("distinct idle signatures: %d of %d" % [seen.size(), chapter.encounters.size()])
	get_tree().quit(0)
