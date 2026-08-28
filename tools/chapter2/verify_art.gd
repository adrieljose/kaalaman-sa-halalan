@tool
extends SceneTree

## Headless check that every rival's declared clips actually resolve.
##
## The battle scene hangs when instantiated headless, so this verifies the
## layer underneath it instead: that each EnemyData names clip folders whose
## frames all exist AND import as textures. A dangling path shows up in-game as
## a console error and a rival frozen on one frame, which is exactly the failure
## a placeholder-to-real-art swap is most likely to introduce.

const CHAPTERS := [1, 2]


func _frames_ok(dir: String, count: int, label: String, errors: Array) -> void:
	if dir.is_empty():
		if count > 0:
			errors.append("%s: count=%d but no directory" % [label, count])
		return
	if count <= 0:
		errors.append("%s: directory set but count=%d" % [label, count])
		return
	for i in count:
		var path := "%s/frame_%d.png" % [dir, i]
		if not ResourceLoader.exists(path):
			errors.append("%s: missing %s" % [label, path])
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			errors.append("%s: %s did not import as a texture" % [label, path])


func _init() -> void:
	var errors: Array = []
	var checked := 0

	for chapter in CHAPTERS:
		var chapter_path := "res://data/chapters/chapter_%02d.tres" % chapter
		if not ResourceLoader.exists(chapter_path):
			errors.append("chapter %d: %s missing" % [chapter, chapter_path])
			continue
		var data = load(chapter_path)
		for enemy in data.encounters:
			checked += 1
			var who := "ch%d/%s" % [chapter, enemy.enemy_name]
			_frames_ok(enemy.idle_dir, enemy.idle_count, who + " idle", errors)
			_frames_ok(enemy.attack_dir, enemy.attack_count, who + " attack", errors)
			_frames_ok(enemy.hit_dir, enemy.hit_count, who + " hit", errors)
			if enemy.portrait == null:
				errors.append("%s: no portrait" % who)
			for move in enemy.moves:
				# An empty per-skill dir is correct -- it falls back to the
				# rival's attack clip. A NON-empty one that does not resolve is
				# the bug this catches.
				_frames_ok(move.attack_dir, move.attack_count,
						"%s/%s" % [who, move.move_name], errors)

	print("rivals checked: %d" % checked)
	if errors.is_empty():
		print("ALL CLIPS RESOLVE")
	else:
		print("PROBLEMS (%d):" % errors.size())
		for e in errors:
			print("  - %s" % e)
	quit(0 if errors.is_empty() else 1)
