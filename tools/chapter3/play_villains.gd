extends Node
## Open this scene in Godot and press F6. Select an encounter in the Inspector.
@export_range(1, 9) var encounter: int = 1

func _ready() -> void:
	if not OS.has_feature("editor"):
		get_tree().quit()
		return
	GameState.load_chapter(3)
	GameState.encounter_index = encounter - 1
	GameState.difficulty = "easy"
	QuestionBank.set_context(3, "easy")
	get_tree().change_scene_to_file.call_deferred("res://scenes/word_battle.tscn")
