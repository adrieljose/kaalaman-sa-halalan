extends Node
## Checks the sprite clip against the body choreography it belongs to.
##
## The two are driven by different systems -- the clip by AnimatedCharacter's
## frame timer, the body by the skill's tweens -- and nothing ties them
## together, so they can drift apart without any error being raised. This
## reports how long each rival's attack clip takes to play out.

func _ready() -> void:
	await get_tree().process_frame
	var chapter: ChapterData = load("res://data/chapters/chapter_02.tres")
	var probe := AnimatedCharacter.new()
	add_child(probe)
	print("clip playback, per rival:")
	for enemy: EnemyData in chapter.encounters:
		probe.configure_from(enemy)
		var atk: float = enemy.attack_count / probe.attack_fps
		var hit: float = enemy.hit_count / probe.hit_fps
		var old: float = enemy.attack_count / probe.fps
		print("  %-16s attack %d frames: %.2fs  (was %.2fs)   hit %d: %.2fs" % [
			enemy.enemy_name, enemy.attack_count, atk, old, enemy.hit_count, hit])
	get_tree().quit(0)
