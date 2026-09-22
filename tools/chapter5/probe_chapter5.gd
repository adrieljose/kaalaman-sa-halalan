extends Node
## Loads Chapter 5 the way the game does and checks every encounter is whole.
##
## A .tres with a missing ExtResource does not fail loudly -- Godot hands back
## a null and the battle screen carries on with an empty room or a blank HUD.
## So each resource is read back through GameState and every field the battle
## screen actually reads is asserted to be present.
##
##   godot --path . tools/chapter5/probe_chapter5.tscn

const WANT := 9
var _faults: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	if not GameState.load_chapter(5):
		print("  FAULT  chapter 5 will not load at all")
		get_tree().quit(1)
		return
	var chapter: ChapterData = GameState.chapter
	print("chapter %d: %s" % [chapter.chapter_number, chapter.chapter_name])
	if chapter.encounter_count() != WANT:
		_faults.append("chapter holds %d encounters, expected %d"
			% [chapter.encounter_count(), WANT])

	for index in chapter.encounter_count():
		var enemy := chapter.encounter_at(index)
		if enemy == null:
			_faults.append("encounter %d is null" % (index + 1))
			continue
		var names: Array[String] = []
		for move in enemy.moves:
			names.append(move.move_name)
			if move.icon == null or move.icon.get_size() != Vector2(64, 64):
				_faults.append("%s: missing/nonstandard icon for %s" % [enemy.enemy_name, move.move_name])
		if not Audio.has_enemy_reaction_voice(enemy.enemy_name):
			_faults.append("%s: missing voice registry hook" % enemy.enemy_name)
		for move in enemy.moves:
			if not move.signature_id().begins_with("c5combat_"):
				_faults.append("%s: %s has id %s, expected a c5combat_ id"
					% [enemy.enemy_name, move.move_name, move.signature_id()])
			if move.guard_reduction <= 0.0 and move.direct_damage <= 0:
				_faults.append("%s: %s neither damages nor guards"
					% [enemy.enemy_name, move.move_name])
		print("   %d %-20s hp %3d  %s  [%s]" % [index + 1, enemy.enemy_name,
			enemy.max_hp, "BOSS" if enemy.is_boss else "    ", ", ".join(names)])

		if enemy.title.strip_edges().is_empty():
			_faults.append("%s has no title" % enemy.enemy_name)
		if enemy.moves.size() != 3:
			_faults.append("%s has %d moves, expected 3" % [enemy.enemy_name, enemy.moves.size()])
		if enemy.portrait == null:
			_faults.append("%s has no portrait" % enemy.enemy_name)
		if enemy.background == null:
			_faults.append("%s has no background" % enemy.enemy_name)
		# Two attacks and one defensive skill, per the brief.
		var guards := 0
		for move in enemy.moves:
			if move.guard_reduction > 0.0 or move.self_heal > 0:
				guards += 1
		if guards != 1:
			_faults.append("%s has %d defensive skills, expected 1" % [enemy.enemy_name, guards])
		# Every clip the battle screen may play must have frames on disk.
		for pair in [[enemy.idle_dir, enemy.idle_count], [enemy.attack_dir, enemy.attack_count],
				[enemy.hit_dir, enemy.hit_count], [enemy.walk_dir, enemy.walk_count]]:
			var dir := String(pair[0])
			var count := int(pair[1])
			for f in count:
				var path := "%s/frame_%d.png" % [dir, f]
				if not ResourceLoader.exists(path):
					_faults.append("%s: missing %s" % [enemy.enemy_name, path])
					break
		for move in enemy.moves:
			if move.attack_dir.is_empty():
				continue
			for f in move.attack_count:
				var path := "%s/frame_%d.png" % [move.attack_dir, f]
				if not ResourceLoader.exists(path):
					_faults.append("%s/%s: missing %s" % [enemy.enemy_name, move.move_name, path])
					break

	# HP must climb, and the boss must top it.
	var previous := 0
	for index in chapter.encounter_count():
		var enemy := chapter.encounter_at(index)
		if enemy == null:
			continue
		if enemy.max_hp <= previous:
			_faults.append("%s (%d hp) does not out-rank the encounter before it (%d)"
				% [enemy.enemy_name, enemy.max_hp, previous])
		previous = enemy.max_hp

	print("")
	if _faults.is_empty():
		print("chapter 5 OK -- 9 encounters, 27 skills, every asset present")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)
