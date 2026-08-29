extends Node
## Samples the title dance across one full cycle and lays the frames out as a
## strip, which is the only way to judge a procedural loop: the seam is between
## the last sample and the first, and it has to be invisible.
##
##   godot --path . res://tools/menu/shot_dance.tscn --resolution 1280x960

const SAMPLES := 8

func _ready() -> void:
	await get_tree().process_frame
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	for i in 60:
		await get_tree().process_frame
	var dance = menu.get_node("TitleDance")
	for i in SAMPLES:
		dance.set("_t", float(i) / float(SAMPLES))
		dance.call("_apply", float(i) / float(SAMPLES))
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("res://dance_%d.png" % i)
	print("saved %d samples" % SAMPLES)
	get_tree().quit(0)
