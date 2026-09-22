extends WordBattleController
var force_full_block := false
func _guarded_damage(damage: int) -> int:
	return 0 if force_full_block else super._guarded_damage(damage)
# Exercise real ending cleanup without saving progress or advancing chapters.
func _finish_chapter() -> void: pass
func _advance_to_next_encounter() -> void: pass
