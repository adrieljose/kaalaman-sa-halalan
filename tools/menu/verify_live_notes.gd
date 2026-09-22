extends SceneTree
## Run with --main-pack output/chapter3_patch_notes/site/index.pck, so the
## production resources (not the working tree) are what is tested.
var failures: Array[String] = []
const OUT := "D:/klhgamefinal/output/chapter3_patch_notes"

func _initialize() -> void:
	call_deferred("verify")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func verify() -> void:
	await process_frame
	var menu_script = load("res://scripts/main_menu.gd")
	check(menu_script != null, "Packed menu script loads")
	check(menu_script.get_script_constant_map().get("RELEASE_CAP") == 3, "Chapter release cap stays 3")
	var chapter = load("res://data/chapters/chapter_03.tres")
	check(chapter.encounters.size() == 9, "Nine Chapter 3 encounters retained")
	for size in [Vector2i(1280, 960), Vector2i(390, 844), Vector2i(844, 390)]:
		DisplayServer.window_set_size(size)
		await process_frame
		var scene = load("res://scenes/main_menu.tscn").instantiate()
		root.add_child(scene)
		for i in 45:
			await process_frame
		var button: Button = scene.get("_patch_button")
		check(button != null and button.visible, "Patch button visible %s" % size)
		button.pressed.emit()
		for i in 20:
			await process_frame
		var panel: PanelContainer = scene.get("_patch_panel")
		check(panel.visible, "Notes open %s" % size)
		var notes := panel.find_child("PatchNotesText", true, false) as RichTextLabel
		var parsed := notes.get_parsed_text()
		for wanted in ["Chapter 3", "CONG MEOW", "27 skills, 27 unique icons", "Bokal Bulsa", "Project Padrino", "36 hurt reactions", "v1.3", "v1.2", "v1.1"]:
			check(parsed.contains(wanted), "Missing text: %s" % wanted)
		check(not parsed.contains("Chapter 4"), "Unpublished Chapter 4 not advertised")
		check(notes.text == FileAccess.get_file_as_string(OUT + "/published_notes.txt").replace("\r\n", "\n"), "Exact approved text displayed")
		root.get_texture().get_image().save_png(OUT + "/notes_%dx%d.png" % [size.x, size.y])
		var bar := notes.get_v_scroll_bar()
		check(bar.max_value > bar.page, "Long notes remain scrollable")
		bar.value = bar.max_value
		for i in 8:
			await process_frame
		root.get_texture().get_image().save_png(OUT + "/notes_end_%dx%d.png" % [size.x, size.y])
		scene.call("_on_close_panels")
		check(not panel.visible, "Notes close %s" % size)
		scene.queue_free()
		await process_frame
	var report := {"failures": failures, "layouts": 3, "tested_pack": "September 8 production with notes-only patch"}
	var file := FileAccess.open(OUT + "/runtime_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("LIVE_NOTES_TEST ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
