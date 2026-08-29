extends Node
## The battle's melee stride runs on the same rig the title dance now shares,
## so the default three-band path has to still behave exactly as it did.
##
##   godot --path . res://tools/menu/probe_rig.tscn

func _ready() -> void:
	await get_tree().process_frame
	var who := AnimatedCharacter.new()
	who.size = Vector2(120, 220)
	who.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	who.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(who)
	who.configure_clips(GameState.PLAYER_CHARACTERS["male"])
	await get_tree().process_frame

	print("before rig:            rigged=%s" % who.is_rigged())
	who.rig_enable()
	var names: Array = []
	for c in who.get_children():
		names.append(c.name)
	print("default chain built:   rigged=%s  top child=%s" % [who.is_rigged(), names])
	print("rig_pose returns:      %s" % (who.rig_pose(6.0, -2.0, 1.0, 3.0, 2.0, 0.05) != null))
	who.rig_disable()
	print("after rig_disable:     rigged=%s  modulate_a=%.1f" % [who.is_rigged(), who.self_modulate.a])

	# And the four-band chain the title screen uses must not satisfy rig_pose,
	# which addresses legs/torso/head by name.
	who.rig_enable(TitleDance.DANCE_CHAIN)
	print("dance chain built:     rigged=%s" % who.is_rigged())
	print("rig_pose declines it:  %s" % (who.rig_pose(6.0, -2.0, 1.0) == null))
	who.rig_set("hips", 8.0, Vector2(3.0, -2.0))
	print("rig_set reached hips:  %s" % (who.get_node("Rig_legs/Rig_hips").rotation > 0.0))
	who.rig_disable()
	print("torn down again:       rigged=%s" % who.is_rigged())
	get_tree().quit(0)
