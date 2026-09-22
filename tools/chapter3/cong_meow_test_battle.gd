extends WordBattleController
## Local test-only seam: exercise actual result handling without awarding saves.
var test_completed := false
func _finish_chapter() -> void:
	test_completed = true
	result_label.text = "Chapter Complete! (local test; no progress awarded)"
	result_overlay.show()
	GameState.reset_chapter()
