extends Node
## Photographs the credits panel.
##
## The panel's text is assigned from CREDITS_COPY at runtime, over the top of
## whatever scenes/main_menu.tscn holds -- so the scene file is not evidence of
## what a player reads, and neither is the constant on its own once BBCode
## wrapping and the panel's scroll height get involved. A picture is.
##
##   godot --path . tools/menu/shot_credits.tscn --resolution 1280x960

const OUT_DIR := "res://output/menu"
const SETTLE := 45


func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var scene: Node = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(scene)
	for _f in SETTLE:
		await get_tree().process_frame

	scene.call("_on_credits_pressed")
	for _f in 30:
		await get_tree().process_frame

	var panel: Control = scene.get_node("CreditsPanel")
	print("credits panel visible=%s rect=%s" % [panel.visible, panel.get_global_rect()])

	# The RENDERED text, with the BBCode stripped -- which is what a player
	# actually reads, and the only thing that proves the constant reached the
	# panel rather than the scene file's stale copy winning.
	var copy: RichTextLabel = panel.find_child("CreditsText", true, false)
	var shown := copy.get_parsed_text()
	for gone in ["Word List", "Titan One", "PixelLab", "Unlicense", "Fuenzalida"]:
		print("  removed %-12s : %s" % [gone, not shown.contains(gone)])
	for kept in ["Adriel Jose C. Villas", "Godot Engine", "CREDITS.md"]:
		print("  present %-22s : %s" % [kept, shown.contains(kept)])

	get_viewport().get_texture().get_image().save_png("%s/credits_top.png" % OUT_DIR)
	# Scrolled to the end, where the edited section lives.
	var bar := copy.get_v_scroll_bar()
	bar.value = bar.max_value
	for _f in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/credits_bottom.png" % OUT_DIR)
	print("saved credits_top.png and credits_bottom.png")
	get_tree().quit(0)
