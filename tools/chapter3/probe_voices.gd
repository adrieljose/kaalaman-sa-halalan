extends Node
## Checks every rival's spoken reactions actually resolve.
##
## The .pck scan proves the ogg files SHIP. It cannot prove the game will find
## them: the lookup goes enemy_name -> registry -> identity -> path, and a
## rival missing from the registry, or an identity spelled differently from its
## folder, is silent at runtime while every file sits happily in the build.
## So this walks the real chapter data and resolves the real paths.
const KINDS := ["hurt_01", "hurt_02", "hurt_03", "hurt_04", "defeat"]
var _faults: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for ch in [1, 2, 3]:
		if not GameState.load_chapter(ch):
			_faults.append("could not load chapter %d" % ch)
			continue
		var chapter: ChapterData = GameState.chapter
		print("\n=== chapter %d ===" % ch)
		for i in chapter.encounter_count():
			var e := chapter.encounter_at(i)
			if e == null:
				continue
			var known: bool = Audio.has_enemy_reaction_voice(e.enemy_name)
			var found := 0
			var missing: Array[String] = []
			if known:
				for k in KINDS:
					var p := "res://assets/audio/sfx/voices/chapter%d/%s/%s.ogg" % [
						ch, _identity(e.enemy_name), k]
					if ResourceLoader.exists(p):
						found += 1
					else:
						missing.append(k)
			print("   %-22s registered=%-5s clips %d/%d %s"
				% [e.enemy_name, known, found, KINDS.size(),
					("MISSING " + str(missing)) if not missing.is_empty() else ""])
			if not known:
				_faults.append("ch%d/%s is not in any voice registry -- it will be silent"
					% [ch, e.enemy_name])
			elif found < KINDS.size():
				_faults.append("ch%d/%s is registered but %s will not load"
					% [ch, e.enemy_name, missing])
	print("")
	if _faults.is_empty():
		print("voices OK -- every rival registered, every clip resolves")
		get_tree().quit(0)
		return
	for f in _faults:
		print("  FAULT  %s" % f)
	get_tree().quit(1)

## Mirrors the registries in AudioManager: the identity is the folder name.
func _identity(enemy_name: String) -> String:
	for reg in [Audio.CH1_VOICES, Audio.CH2_VOICES, Audio.CH3_VOICES]:
		if reg.has(enemy_name):
			return String(reg[enemy_name])
	return "?"
