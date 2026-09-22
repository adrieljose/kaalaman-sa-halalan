extends Node
const OUT := "res://output/chapter5_environments/motion_frames"
func _ready() -> void:
	await get_tree().process_frame
	get_tree().root.size=Vector2i(768,512)
	for i in range(4): await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var frame_id:=0
	for stage in range(9):
		var env=preload("res://scripts/environments/congress_environment.gd").new()
		env.size=get_viewport().get_visible_rect().size; add_child(env); env.configure(stage)
		env.set_process(false)
		env.rng.seed=77
		env.actors[0].state="walking"
		env.next_walker=.3
		env.next_vehicle=1.0; env.next_bird=1.0
		var label=Label.new()
		label.text="CHAPTER 5  /  %02d  /  %s"%[stage+1,env.spec.title]
		label.position=Vector2(12,env.size.y-30)
		label.add_theme_color_override("font_outline_color",Color.BLACK)
		label.add_theme_constant_override("outline_size",5)
		add_child(label)
		for frame in range(165 if stage==8 else 45):
			if frame==15:
				if stage==8: env.escalate()
				else: env.react(8.0)
			if stage==8 and frame==90: env.set_stage(2)
			env._process(1.0/15.0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg(OUT+"/frame_%04d.jpg"%frame_id,.90)
			frame_id+=1
		env.stop(); env.queue_free(); label.queue_free()
		await get_tree().process_frame
	print("CONGRESS MOTION frames=",frame_id)
	get_tree().quit()
