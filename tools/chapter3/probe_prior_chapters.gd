extends Node
## Regression guard for Chapters 1 and 2 after the grounding change.
##
## _place_fighter_pair is shared by every chapter, so standing both fighters on
## ONE floor could not be scoped to Chapter 3. The authored WIDE composition put
## them on lines seven pixels apart; this checks what that change did to the
## chapters that were already correct.
const SETTLE := 50
var _faults: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for chapter_no in [1, 2]:
		await _sweep(chapter_no)
	print("")
	if _faults.is_empty():
		print("prior chapters OK -- feet still on the painted floor")
		get_tree().quit(0)
		return
	for f in _faults:
		print("  FAULT  %s" % f)
	get_tree().quit(1)

func _sweep(chapter_no: int) -> void:
	if not GameState.load_chapter(chapter_no):
		_faults.append("could not load chapter %d" % chapter_no)
		return
	var chapter: ChapterData = GameState.chapter
	print("\n=== chapter %d ===" % chapter_no)
	for index in chapter.encounter_count():
		var enemy := chapter.encounter_at(index)
		GameState.encounter_index = index
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		get_tree().root.add_child(scene)
		for _f in SETTLE:
			await get_tree().process_frame
		var pc := scene.find_child("PlayerCharacter", true, false) as Control
		var ec := scene.find_child("EnemyCharacter", true, false) as Control
		var bg := scene.find_child("Background", true, false) as TextureRect
		if pc != null and ec != null and bg != null and bg.texture != null:
			var gf: float = enemy.ground_fraction if enemy.ground_fraction > 0.0 else 0.9125
			var painted: float = bg.position.y + bg.size.y * gf
			var pf: float = pc.position.y + (pc.call("body_rect") as Rect2).end.y
			var ef: float = ec.position.y + (ec.call("body_rect") as Rect2).end.y
			print("   %-20s feet p%.1f e%.1f (floor %.1f)" % [enemy.enemy_name, pf, ef, painted])
			if absf(pf - painted) > 4.0:
				_faults.append("ch%d/%s: player soles %.1fpx off the floor"
					% [chapter_no, enemy.enemy_name, pf - painted])
			if absf(ef - painted) > 4.0:
				_faults.append("ch%d/%s: rival soles %.1fpx off the floor"
					% [chapter_no, enemy.enemy_name, ef - painted])
		scene.queue_free()
		await get_tree().process_frame
