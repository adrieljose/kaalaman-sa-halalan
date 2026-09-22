extends WordBattleController
var hit_log: Array[Dictionary]=[]
var no_awards := false

func _enemy_take_hit(damage: int) -> void:
	hit_log.append({"damage":damage,"frame":_player_variations.animation_frame,
		"ready":_player_variations.contact_ready,"stage":_player_variations.stage,
		"before":_enemy_hp,"guarded":_guarded_damage(damage)})
	await super._enemy_take_hit(damage)

func _finish_chapter() -> void:
	no_awards=true
	result_overlay.show()
