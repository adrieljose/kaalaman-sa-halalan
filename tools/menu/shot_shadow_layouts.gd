extends Node
## The floor is decided by the layout, and each arrangement decides it
## differently — wide reproduces the authored composition, the other two derive
## a stage band. This checks the shadows land on the feet in all three.
##
##   godot --path . res://tools/menu/shot_shadow_layouts.tscn

const SIZES := [
	{"w": 1280, "h": 960, "file": "sh_wide.png"},
	{"w": 390, "h": 844, "file": "sh_portrait.png"},
	{"w": 844, "h": 390, "file": "sh_compact.png"},
]

func _ready() -> void:
	await get_tree().process_frame
	GameState.load_chapter(2)
	GameState.character = "female"
	GameState.encounter_index = 4
	var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
	add_child(scene)
	for shot in SIZES:
		DisplayServer.window_set_size(Vector2i(int(shot["w"]), int(shot["h"])))
		for i in 90:
			await get_tree().process_frame
		var sh = scene.get_node_or_null("BattleShadows")
		var report := "no layer"
		if sh != null:
			var parts: Array = []
			for entry in sh.get("_subjects"):
				var who: Control = entry["who"]
				parts.append("%s foot=%.1f ground=%.1f" % [
					who.name.substr(0, 6), who.position.y + who.body_rect().end.y,
					entry["ground"]])
			report = "idx=%d  %s" % [sh.get_index(), " | ".join(parts)]
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://" + String(shot["file"]))
		print("%-14s %s" % [shot["file"], report])
	get_tree().quit(0)
