extends Node
## Checks Chapter 3's data layer, then actually plays it.
##
## Parsing is not the bar. A .tres can load perfectly and still point at a
## sprite folder that does not exist, name a phase-2 move the rotation never
## reaches, or hand a rival a hit that kills the player outright -- none of
## which a load error would report. So this walks all nine encounters, resolves
## every asset path it claims, filters the boss's rotation at each phase, and
## then boots the real battle scene on chapter 3 to confirm an encounter
## actually starts.
##
##   godot --path . tools/chapter3/probe_chapter3.tscn --resolution 1280x960

const SETTLE := 45

var _faults: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame

	_check_data()
	await _check_battle_boots()

	print("")
	if _faults.is_empty():
		print("chapter 3 OK -- 9 encounters, assets resolve, boss phases filter, battle boots")
		get_tree().quit(0)
		return
	for fault in _faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)


func _check_data() -> void:
	if not GameState.chapter_exists(3):
		_faults.append("chapter_03.tres is not on disk where GameState looks for it")
		return
	var chapter := load(GameState.chapter_path(3)) as ChapterData
	if chapter == null:
		_faults.append("chapter_03.tres did not load as a ChapterData")
		return

	print("chapter %d  \"%s\"  %d encounters"
		% [chapter.chapter_number, chapter.chapter_name, chapter.encounter_count()])
	if chapter.encounter_count() != 9:
		_faults.append("expected 9 encounters, found %d" % chapter.encounter_count())

	var seen_moves := {}
	var previous_hp := 0
	var boss_count := 0

	for i in chapter.encounter_count():
		var e := chapter.encounter_at(i)
		if e == null:
			_faults.append("encounter %d is null" % (i + 1))
			continue
		var damages: Array[int] = []
		for move in e.moves:
			damages.append(move.direct_damage)
		print("  %d  %-20s HP %-4d dmg %s" % [i + 1, e.enemy_name, e.max_hp, damages])

		# --- the curve ---
		if e.max_hp <= previous_hp:
			_faults.append("%s has %d HP, not more than the rival before it (%d)"
				% [e.enemy_name, e.max_hp, previous_hp])
		previous_hp = e.max_hp

		# --- assets it CLAIMS to have ---
		if e.portrait == null:
			_faults.append("%s has no portrait" % e.enemy_name)
		if e.background == null:
			_faults.append("%s has no room" % e.enemy_name)
		for pair in [[e.idle_dir, e.idle_count, "idle"],
				[e.attack_dir, e.attack_count, "attack"],
				[e.hit_dir, e.hit_count, "hit"]]:
			var dir := String(pair[0])
			var count := int(pair[1])
			if dir.is_empty() or count <= 0:
				_faults.append("%s has no %s clip" % [e.enemy_name, pair[2]])
				continue
			# Every frame, not just the first -- a folder that stops at frame_4
			# while the resource claims 8 plays a clip that jumps.
			for f in count:
				if load("%s/frame_%d.png" % [dir, f]) == null:
					_faults.append("%s %s clip is missing frame_%d (%s)"
						% [e.enemy_name, pair[2], f, dir])
					break

		# --- moves ---
		var wanted := 3
		if e.moves.size() != wanted:
			_faults.append("%s has %d moves, expected %d"
				% [e.enemy_name, e.moves.size(), wanted])
		for move in e.moves:
			if move == null:
				_faults.append("%s carries a null move" % e.enemy_name)
				continue
			var id := move.signature_id()
			if seen_moves.has(id):
				_faults.append("move id '%s' is used twice (%s and %s)"
					% [id, seen_moves[id], e.enemy_name])
			seen_moves[id] = e.enemy_name
			# Only direct_damage is read by the battle controller. A move whose
			# whole effect sits in the fields the controller ignores does
			# nothing at all when it lands.
			if move.direct_damage <= 0 and move.guard_reduction <= 0.0 and move.self_heal <= 0:
				_faults.append("%s's %s deals no damage" % [e.enemy_name, move.move_name])
			# A hit that empties the bar from full is not difficulty.
			if move.direct_damage >= GameState.player_max_hp:
				_faults.append("%s's %s deals %d against %d max player HP"
					% [e.enemy_name, move.move_name, move.direct_damage,
						GameState.player_max_hp])

		# --- boss phases ---
		if e.is_boss:
			boss_count += 1
			# Cong Meow changes weighted AI/timing with HP; all three moves stay visible.
			if e.phase_backgrounds.size() != e.phase_thresholds.size():
				_faults.append("%s has %d phase thresholds but %d phase rooms"
					% [e.enemy_name, e.phase_thresholds.size(), e.phase_backgrounds.size()])
			for bg in e.phase_backgrounds:
				if bg == null:
					_faults.append("%s has a null phase room" % e.enemy_name)
			# The rotation the controller would actually build, per phase.
			# A phase-2 exclusive that is not excluded in phase 1 is not
			# exclusive, and one that never becomes available is unreachable.
			var phase1 := _rotation(e, 1)
			var phase2 := _rotation(e, 2)
			print("     phase 1 rotation %s" % [phase1])
			print("     phase 2 rotation %s" % [phase2])
			if phase1.size() != 3 or phase2.size() != 3:
				_faults.append("%s must retain exactly three skills (%d then %d)"
					% [e.enemy_name, phase1.size(), phase2.size()])
			if phase1.is_empty():
				_faults.append("%s has nothing to attack with in phase 1" % e.enemy_name)

	if seen_moves.size() != 27:
		_faults.append("expected 27 distinct skills across the chapter, found %d"
			% seen_moves.size())
	if boss_count != 1:
		_faults.append("expected exactly one boss, found %d" % boss_count)


## Mirrors WordBattleController's own filter (`move.min_phase <= _boss_phase`).
func _rotation(enemy: EnemyData, phase: int) -> Array[String]:
	var names: Array[String] = []
	for move in enemy.moves:
		if move != null and move.min_phase <= phase:
			names.append(move.move_name)
	return names


## Boots the real battle scene on chapter 3, which is the only thing that
## proves the resources survive contact with the code that consumes them.
func _check_battle_boots() -> void:
	if not GameState.load_chapter(3):
		_faults.append("GameState refused to load chapter 3")
		return
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	# The ROOT, not this node: a Control parented under a plain Node has a zero
	# rect, and every layout pass then measures against nothing.
	get_tree().root.add_child(scene)
	for _f in SETTLE:
		await get_tree().process_frame

	var live: EnemyData = GameState.current_enemy()
	if live == null:
		_faults.append("no live encounter after booting the battle scene")
	elif live.enemy_name != "Bokal Bulsa":
		_faults.append("chapter 3 opened on %s, not the first rival" % live.enemy_name)
	else:
		print("\nbattle scene booted on %s (%d HP)" % [live.enemy_name, live.max_hp])

	# The sprite has to have actually taken the frames, not merely been handed
	# the paths -- an empty clip leaves an invisible fighter on the floor.
	var enemy_node := scene.find_child("EnemyCharacter", true, false)
	if enemy_node == null:
		_faults.append("the battle scene has no EnemyCharacter")
	elif enemy_node.get("texture") == null:
		_faults.append("%s is on screen with no frame loaded" % live.enemy_name)

	scene.queue_free()
	await get_tree().process_frame
