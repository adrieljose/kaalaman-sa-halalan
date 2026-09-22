extends Node
func _ready()->void:
	await get_tree().process_frame
	var tested:=0
	for chapter in [1,2]:
		GameState.load_chapter(chapter)
		for enemy:EnemyData in GameState.chapter.encounters:
			var actor:=AnimatedCharacter.new()
			add_child(actor)
			actor.configure_from(enemy)
			actor.enable_limb_motion(true)
			actor.set_process(false)
			for delta in [.0166667,.04,.11]:
				assert(actor.play_attack())
				var elapsed:=0.0
				while elapsed<AnimatedCharacter.ATTACK_SECONDS:
					actor._process(delta)
					elapsed+=delta
				assert(not actor._one_shot,"clip drift at low FPS: "+enemy.enemy_name)
				assert(actor._limb_action==0.0,"limbs outlived clip")
				tested+=1
			actor.queue_free()
	print("EARLY CLIP CLOCK PASS ",tested)
	get_tree().quit()
