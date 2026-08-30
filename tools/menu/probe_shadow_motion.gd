extends Node
## Samples the shadow through a real enemy attack.
##
## This is the part of the request that is easy to get wrong and impossible to
## judge from a still: the shadow has to STAY ON THE FLOOR while the body it
## belongs to travels, leans and lifts. Reading it out per frame catches a
## shadow that has quietly become a child of the body's transform.
##
##   godot --path . res://tools/menu/probe_shadow_motion.tscn --resolution 1280x960

func _ready() -> void:
	await get_tree().process_frame
	GameState.load_chapter(2)
	GameState.character = "male"
	GameState.encounter_index = 0
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	add_child(scene)
	for i in 150:
		await get_tree().process_frame

	var sh = scene.get_node("BattleShadows")
	var who: Control = scene.get_node("EnemyCharacter")
	var ground: float = 0.0
	for entry in sh.get("_subjects"):
		if entry["who"] == who:
			ground = entry["ground"]
	print("captured ground: %.1f" % ground)
	print("%-6s %-9s %-8s %-7s %-7s   %s" % ["frame", "node.x", "node.y", "rot", "scale.y", "shadow centre / width"])

	# The two cases a real move does not happen to exercise, driven directly:
	# crossing the stage, and leaving the floor.
	print("")
	print("%-22s %s" % ["driven pose", "shadow centre / width / alpha factor"])
	await get_tree().process_frame
	for step in [{"dx": 0.0, "dy": 0.0}, {"dx": -60.0, "dy": 0.0},
			{"dx": -120.0, "dy": 0.0}, {"dx": -120.0, "dy": -12.0},
			{"dx": -120.0, "dy": -34.0}, {"dx": 0.0, "dy": -55.0}]:
		who.position = Vector2(478.0 + step["dx"], 265.0 + step["dy"])
		who.rotation = 0.0
		await get_tree().process_frame
		var b2 = who.body_rect()
		var f2 = who.foot_rect()
		var m = sh.get_global_transform().affine_inverse() * who.get_global_transform()
		var l2 = m * Vector2(f2.position.x, b2.end.y)
		var r2 = m * Vector2(f2.end.x, b2.end.y)
		var c2 = (l2 + r2) * 0.5
		var lift = maxf(ground - c2.y, 0.0)
		var k = clampf(lift / maxf(b2.size.y * sh.LIFT_SPAN, 1.0), 0.0, 1.0)
		print("dx=%-6.0f dy=%-6.0f  pos=%-7.1f  (%.1f, %.1f)  w=%.1f  a=%.2f" % [
			step["dx"], step["dy"], who.position.x, c2.x, ground,
			(r2 - l2).length() * sh.SPREAD * (1.0 - sh.LIFT_SHRINK * k),
			1.0 - sh.LIFT_FADE * k])
	print("")
	scene.call("_resolve_enemy_turn")
	for i in 42:
		await get_tree().process_frame
		if i % 6 != 0:
			continue
		var body = who.body_rect()
		var feet = who.foot_rect()
		var to_local = sh.get_global_transform().affine_inverse() * who.get_global_transform()
		var l = to_local * Vector2(feet.position.x, body.end.y)
		var r = to_local * Vector2(feet.end.x, body.end.y)
		var foot = (l + r) * 0.5
		print("%-6d %-9.1f %-8.1f %-7.1f %-7.2f   (%.1f, %.1f) w=%.1f lift=%.1f" % [
			i, who.position.x, who.position.y, rad_to_deg(who.rotation), who.scale.y,
			foot.x, ground, (r - l).length(), maxf(ground - foot.y, 0.0)])

	get_tree().quit(0)
