extends Node
## Boots straight into chosen Chapter 2 encounters and saves a frame of each.
##
## Run as a SCENE, not with --script: autoloads (GameState, Layout, Audio) are
## only registered for a real scene run, and this needs GameState to pick the
## encounter. Judging the art this way rather than from the source PNGs is the
## point -- rooms, props and fighters only reveal their problems once they
## composite together at the size the player sees.
##
##   godot --path . res://tools/chapter2/shot.tscn --resolution 640x480

const SHOTS := [
	{"chapter": 2, "encounter": 0, "file": "shot_e1.png"},
	{"chapter": 2, "encounter": 4, "file": "shot_e5.png", "who": "female"},
	{"chapter": 2, "encounter": 7, "file": "shot_e8.png", "who": "female"},
	{"chapter": 1, "encounter": 0, "file": "shot_ch1.png"},
]

func _ready() -> void:
	await get_tree().process_frame
	for shot in SHOTS:
		GameState.load_chapter(int(shot["chapter"]))
		GameState.character = String(shot.get("who", "male"))
		GameState.encounter_index = int(shot["encounter"])
		if "selected_character" in GameState:
			GameState.selected_character = "juan"
		var scene: Node = load("res://scenes/word_battle.tscn").instantiate()
		add_child(scene)
		# Long enough for the layout pass, the intro and a few prop frames.
		for i in 180:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://" + String(shot["file"]))
		print("saved %s" % shot["file"])
		scene.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
