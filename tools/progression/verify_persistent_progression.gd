extends Node
var faults:Array[String]=[]
var checks:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok: faults.append(message)
func _ready()->void:
	await get_tree().process_frame
	var state=load("res://scripts/game_state.gd").new()
	var path: String="user://progression_regression_%d.save"%Time.get_ticks_usec()
	state.progress_save_path=path
	check(MainMenu.RELEASE_CAP==5,"five chapters released")
	check(not MainMenu.PROGRESSION_GATE_OFF,"production bypass removed")
	for chapter in range(1,6):
		for tier in QuestionBank.DIFFICULTY_ORDER:
			check(state.progression_tier_access(chapter,tier,true),"practice unlock %d %s"%[chapter,tier])
			check(state.progression_tier_access(chapter,tier,false)==(chapter==1 and tier=="easy"),"new player gate %d %s"%[chapter,tier])
	for chapter in range(1,6):
		for index in 3:
			var tier:String=QuestionBank.DIFFICULTY_ORDER[index]
			check(state.progression_tier_access(chapter,tier,false),"current tier accessible")
			state.mark_difficulty_completed(chapter,tier)
			# New instance simulates a fresh launch; no session data carried over.
			state.free()
			state=load("res://scripts/game_state.gd").new()
			state.progress_save_path=path
			state._load_progress()
			check(state.completed_tiers.get(chapter,{}).get(tier,false),"saved win survives reload")
			check(state.is_progression_completed(chapter)==(index==2),"chapter requires all three")
			check(not state.is_chapter_completed(chapter),"certificate remains separate")
			if index<2: check(state.progression_tier_access(chapter,QuestionBank.DIFFICULTY_ORDER[index+1],false),"next difficulty opens")
			for future in range(chapter+1,6):
				check(state.progression_tier_access(future,"easy",false)==(index==2 and future==chapter+1),"no chapter skipping")
	var snapshot:Dictionary=GameState.completed_tiers
	GameState.completed_tiers=state.completed_tiers.duplicate(true)
	check(MainMenu.earned_chapters()==5,"menu sees full progression")
	GameState.completed_tiers={}
	check(MainMenu.earned_chapters()==1,"menu fresh player")
	GameState.completed_tiers=snapshot
	state.completed_tiers={}
	state.certificate_earned={1:true}
	state._save_progress()
	state._load_progress()
	check(state.is_progression_completed(1),"legacy certificate migration")
	check(not state.progression_tier_access(0,"easy",true),"invalid chapter rejected")
	check(not state.progression_tier_access(1,"invalid",true),"invalid tier rejected")
	state.tutorial_mode=true
	state.mark_difficulty_completed(2,"easy")
	check(not state.completed_tiers.has(2),"tutorial does not record progress")
	state.free()
	DirAccess.remove_absolute(path)
	print("PERSISTENT PROGRESSION checks=",checks," faults=",faults)
	get_tree().quit(0 if faults.is_empty() else 1)
