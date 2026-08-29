extends Node
## Why is the character panel taller than its contents?
func _ready() -> void:
	await get_tree().process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 60:
		await get_tree().process_frame
	menu._on_play_pressed()
	for i in 30:
		await get_tree().process_frame
	menu._on_chapter_pressed(1)
	for i in 60:
		await get_tree().process_frame
	var panel: Control = menu.get_node("CharacterPanel")
	print("panel size=%s  min=%s" % [panel.size, panel.get_combined_minimum_size()])
	var vbox: Control = panel.get_node("VBox")
	print("vbox  size=%s  min=%s" % [vbox.size, vbox.get_combined_minimum_size()])
	for c in vbox.get_children():
		var ctl := c as Control
		if ctl == null:
			continue
		print("   %-18s size=%-18s min=%s %s" % [
			ctl.name, ctl.size, ctl.get_combined_minimum_size(),
			"(hidden)" if not ctl.visible else ""])
	get_tree().quit(0)
