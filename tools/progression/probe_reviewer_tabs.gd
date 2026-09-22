extends Node
## The reviewer must offer every SHIPPED chapter, whatever the player has beaten.
##
## The map gate and the reviewer gate are deliberately different questions --
## "may I play this?" and "may I read this?" -- and it is easy to answer the
## second with the first by accident, because they were one call until now.
func _ready() -> void:
	await get_tree().process_frame
	GameState.certificate_earned = {}
	GameState._session_tier_progress = {}

	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	get_tree().root.add_child(menu)
	for _f in 40:
		await get_tree().process_frame

	var tabs: Dictionary = menu.get("_reviewer_chapter_tabs")
	var listed: Array = tabs.keys()
	listed.sort()
	print("reviewer tabs with NO progress at all: %s" % str(listed))
	print("released %d, earned %d" % [MainMenu.released_chapters(), MainMenu.earned_chapters()])

	var faults: Array[String] = []
	if not listed.has(2):
		faults.append("chapter 2 has no reviewer tab for a player who has beaten nothing")
	if MainMenu.earned_chapters() != 1:
		faults.append("this player should have earned only chapter 1")
	for chapter_no in listed:
		if int(chapter_no) > MainMenu.released_chapters():
			faults.append("chapter %d is listed but has not shipped" % int(chapter_no))

	menu.queue_free()
	await get_tree().process_frame
	print("")
	if faults.is_empty():
		print("reviewer OK -- every shipped chapter readable, progress irrelevant")
		get_tree().quit(0)
		return
	for fault in faults:
		print("  FAULT  %s" % fault)
	get_tree().quit(1)
