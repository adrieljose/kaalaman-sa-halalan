extends Node
## Boots each Chapter 1 encounter and saves a frame, to judge the new poses
## where they actually matter: composited at the size the player sees.
##
## Encounter 2 is Senator Sabaw, the one deliberately left un-rotated, so this
## also shows how far out of step he reads next to the four that were done.
##
##   godot --path . res://tools/chapter1/shot_ch1.tscn --resolution 1280x960

const SHOTS := [
	{"encounter": 0, "file": "ch1_e1_trapo.png"},
	{"encounter": 1, "file": "ch1_e2_vandal.png"},
	{"encounter": 2, "file": "ch1_e3_sabaw.png"},
	{"encounter": 3, "file": "ch1_e4_kapitan.png", "who": "female"},
	{"encounter": 4, "file": "ch1_e5_ayuda.png", "who": "female"},
]

func _ready() -> void:
	await get_tree().process_frame
	for shot in SHOTS:
		GameState.load_chapter(1)
		GameState.character = String(shot.get("who", "male"))
		GameState.encounter_index = int(shot["encounter"])
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		add_child(scene)
		for i in 180:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://" + String(shot["file"]))
		print("saved %s" % shot["file"])
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
