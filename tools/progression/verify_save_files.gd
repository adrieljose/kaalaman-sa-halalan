extends Node
var faults:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: faults.append(label)
func _ready()->void:
	await get_tree().process_frame
	var path:="user://savefile_test_%d.save"%Time.get_ticks_usec()
	GameState.progress_save_path=path
	GameState.completed_tiers={1:{"easy":true}}
	GameState.load_chapter(1)
	GameState.encounter_index=2
	GameState.difficulty="medium"
	GameState.character="female"
	GameState.potions={0:1,1:3,2:0}
	GameState.capture_checkpoint(63)
	var encoded:=SaveGameCodec.encode(GameState.completed_tiers,GameState.checkpoint)
	var valid:=SaveGameCodec.validate(encoded)
	check(valid.error.is_empty(),"roundtrip validation")
	GameState.checkpoint={}
	GameState.completed_tiers={}
	GameState._load_progress()
	check(GameState.checkpoint.hp==63,"local checkpoint reload HP")
	check(GameState.prepare_checkpoint_resume(),"resume accepted")
	check(GameState.encounter_index==2 and GameState.character=="female" and GameState.difficulty=="medium","resume location")
	check(GameState.potion_count(1)==3,"resume inventory")
	check(not SaveGameCodec.validate("not json").error.is_empty(),"malformed JSON")
	check(not SaveGameCodec.validate(" ".repeat(65537)).error.is_empty(),"oversize")
	var original:Dictionary=JSON.parse_string(encoded)
	for edit in [{"version":99},{"environment":"testing"},{"completed_tiers":[]},{"checkpoint":[]}]:
		var bad:=original.duplicate(true)
		bad.merge(edit,true)
		check(not SaveGameCodec.validate(JSON.stringify(bad),"main").error.is_empty(),"invalid header "+str(edit))
	for edit in [{"chapter":6},{"encounter":99},{"hp":0},{"hp":101},{"hp":1.5},{"character":"unknown"},{"difficulty":"hard"},{"potions":{"0":11,"1":1,"2":0}}]:
		var bad:=original.duplicate(true)
		bad.checkpoint.merge(edit,true)
		check(not SaveGameCodec.validate(JSON.stringify(bad),"main").error.is_empty(),"invalid run "+str(edit))
	var progress:Dictionary={}
	for ch in range(1,6):
		for tier in ["easy","medium","hard"]:
			var run:Dictionary=original.checkpoint.duplicate(true)
			run.chapter=ch
			run.encounter=0
			run.difficulty=tier
			var payload:={"format":SaveGameCodec.FORMAT,"version":1,"environment":"main","completed_tiers":progress,"checkpoint":run}
			check(SaveGameCodec.validate(JSON.stringify(payload),"main").error.is_empty(),"all valid chapters/modes")
			if not progress.has(ch): progress[ch]={}
			progress[ch][tier]=true
	var testing:=original.duplicate(true)
	testing.environment="testing"
	testing.completed_tiers={}
	testing.checkpoint.chapter=5
	testing.checkpoint.difficulty="hard"
	check(SaveGameCodec.validate(JSON.stringify(testing),"testing").error.is_empty(),"testing all unlocked")
	check(not SaveGameCodec.validate(JSON.stringify(testing),"main").error.is_empty(),"testing cannot import to main")
	# Actual battle initialization consumes saved HP once, without healing again.
	var battle=load("res://scenes/word_battle.tscn").instantiate()
	get_tree().root.add_child(battle)
	for i in 20: await get_tree().process_frame
	check(battle._player_hp==63,"battle HP restored exactly")
	check(GameState.pending_checkpoint.is_empty(),"resume consumed once")
	check(GameState.potion_count(0)==1 and GameState.potion_count(1)==3,"battle potions preserved")
	SaveFilePanel.open(battle)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://output/save_files")
		get_viewport().get_texture().get_image().save_png("res://output/save_files/panel.png")
	var panel=battle.get_node("SaveFilePanel")
	panel._accept_text(encoded)
	check(panel.confirmation.visible,"load confirmation shown")
	panel.queue_free()
	battle.queue_free()
	await get_tree().process_frame
	GameState.reset_chapter()
	check(GameState.checkpoint.is_empty(),"new run clears checkpoint")
	DirAccess.remove_absolute(path)
	print("SAVE FILE TESTS ",checks," faults=",faults)
	get_tree().quit(0 if faults.is_empty() else 1)
