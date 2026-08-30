extends Node
## Reports whether the shadow layer exists, where it sits in the draw order,
## and what it computed — the three things that can each silently produce a
## battle with no shadows in it.
func _ready() -> void:
	await get_tree().process_frame
	GameState.load_chapter(2)
	GameState.character = "male"
	GameState.encounter_index = 0
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
	var sh = scene.get_node_or_null("BattleShadows")
	print("layer exists:      %s" % (sh != null))
	if sh == null:
		return
	var p: Control = scene.get_node("PlayerCharacter")
	var e: Control = scene.get_node("EnemyCharacter")
	print("indices:           shadows=%d player=%d enemy=%d" % [
		sh.get_index(), p.get_index(), e.get_index()])
	print("layer rect:        %s  visible=%s  modulate=%s" % [
		Rect2(sh.position, sh.size), sh.visible, sh.self_modulate])
	for who in [p, e]:
		var body = who.body_rect()
		var ground = who.position.y + body.end.y
		var to_local = sh.get_global_transform().affine_inverse() * who.get_global_transform()
		var foot = to_local * Vector2(body.position.x + body.size.x * 0.5, body.end.y)
		var l = to_local * Vector2(body.position.x, body.end.y)
		var r = to_local * Vector2(body.end.x, body.end.y)
		print("%-16s node=%s body=%s ground=%.1f foot=%s width=%.1f alpha=%.2f" % [
			who.name, Rect2(who.position, who.size), body, ground, foot,
			(r - l).length(), who.modulate.a])
	get_tree().quit(0)
