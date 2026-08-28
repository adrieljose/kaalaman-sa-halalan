extends Node
## Dumps the real rects of the chapter banner/plate and their labels.
## The clipping is a sizing problem, and sizing problems in this HUD have
## repeatedly turned out to be Godot clamping a Control to a container minimum
## rather than to the offsets that were set -- so measure, do not reason.

func _ready() -> void:
	await get_tree().process_frame
	GameState.load_chapter(2)
	GameState.encounter_index = 0
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	add_child(scene)
	for i in 120:
		await get_tree().process_frame
	_dump(scene, "")
	_measure(scene)
	var tb: Control = scene.get_node("TopBar")
	print("TopBar pos=%s size=%s" % [tb.position, tb.size])
	for n in ["HudPillar0", "HudPillar1", "ChapterRibbon", "ChapterPlate"]:
		var c := tb.get_node_or_null(NodePath(n)) as Control
		if c != null:
			print("  %-14s x %.0f..%.0f" % [n, c.position.x, c.position.x + c.size.x])
	get_tree().quit(0)

## What the text ACTUALLY measures in the font it is drawn with, against the
## width it has to live in. clip_text hides overflow instead of reporting it,
## so a label can look correctly sized and still be losing characters.
func _measure(scene: Node) -> void:
	for pair in [["TopBar/ChapterRibbon/ChapterRibbonLabel", 11],
			["TopBar/ChapterPlate/ChapterLabel", 12]]:
		var node := scene.get_node_or_null(NodePath(String(pair[0])))
		if node == null:
			print("missing %s" % pair[0])
			continue
		var l := node as Label
		var f: Font = l.get_theme_font("font")
		# Read the label's CURRENT size, not the size it was built with --
		# _fit_label_font steps it down, and measuring at the original would
		# report a clip that no longer happens.
		var fs: int = l.get_theme_font_size("font_size")
		var need: Vector2 = f.get_string_size(
			l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		print("%-24s text=%-20s @%dpt needs %.0fpx, has %.0fpx  %s" % [
			l.name, l.text, fs, need.x, l.size.x,
			"CLIPPED" if need.x > l.size.x else "fits"])

func _dump(n: Node, path: String) -> void:
	var here := path + "/" + n.name
	if n is Control:
		var c := n as Control
		var interesting := (
			"Chapter" in n.name or "Ribbon" in n.name or "Plate" in n.name
			or "Banner" in n.name or "Badge" in n.name)
		if interesting:
			var extra := ""
			if n is Label:
				var l := n as Label
				extra = "  text=%s  min=%s  clip=%s" % [
					l.text, l.get_minimum_size(), l.clip_text]
			print("%-46s pos=%s size=%s%s" % [here, c.position, c.size, extra])
	for child in n.get_children():
		_dump(child, here)
