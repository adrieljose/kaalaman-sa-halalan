class_name SaveGameCodec
extends RefCounted
const FORMAT := "kaalaman-checkpoint"
const VERSION := 1
const MAX_BYTES := 65536

static func environment() -> String:
	return "testing" if OS.has_feature("testing_chapters") else "main"

static func encode(progress:Dictionary, checkpoint:Dictionary) -> String:
	return JSON.stringify({"format":FORMAT,"version":VERSION,"environment":environment(),
		"saved_at":Time.get_datetime_string_from_system(true),"completed_tiers":progress,
		"checkpoint":checkpoint},"  ")

static func integer(value:Variant, minimum:int, maximum:int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum and value<=maximum

static func validate(text:String, target:String=environment()) -> Dictionary:
	if text.to_utf8_buffer().size()>MAX_BYTES: return {"error":"Save file is too large (maximum 64 KB)."}
	var parser:=JSON.new()
	if parser.parse(text)!=OK: return {"error":"This is not a valid JSON save file."}
	var data:Variant=parser.data
	if not data is Dictionary: return {"error":"This is not a valid JSON save file."}
	if data.get("format")!=FORMAT or data.get("version")!=VERSION: return {"error":"Unsupported game save or save version."}
	if data.get("environment")!=target: return {"error":"This save belongs to the other website. Main and testing saves are separate."}
	var source:Variant=data.get("completed_tiers")
	if not source is Dictionary or source.size()>5: return {"error":"Invalid chapter progress."}
	var progress:Dictionary={}
	for key in source:
		if str(key) not in ["1","2","3","4","5"] or not source[key] is Dictionary: return {"error":"Invalid chapter entry."}
		var tiers:Dictionary={}
		for tier in source[key]:
			if tier not in ["easy","medium","hard"] or not source[key][tier] is bool: return {"error":"Invalid difficulty progress."}
			if source[key][tier]: tiers[tier]=true
		progress[int(key)]=tiers
	if target=="main":
		for chapter in progress:
			var tiers:Dictionary=progress[chapter]
			if tiers.get("hard",false) and not tiers.get("medium",false): return {"error":"Save skips Medium completion."}
			if tiers.get("medium",false) and not tiers.get("easy",false): return {"error":"Save skips Easy completion."}
			if not tiers.is_empty() and not previous_complete(progress,chapter): return {"error":"Save skips a locked chapter."}
	var run:Variant=data.get("checkpoint")
	if not run is Dictionary: return {"error":"Invalid checkpoint."}
	if not run.is_empty():
		if not integer(run.get("chapter"),1,5): return {"error":"Invalid checkpoint chapter."}
		var chapter:=int(run.chapter)
		var chapter_data=load(GameState.chapter_path(chapter)) as ChapterData
		if chapter_data==null or not integer(run.get("encounter"),0,chapter_data.encounter_count()-1): return {"error":"Invalid checkpoint encounter."}
		if run.get("difficulty") not in ["easy","medium","hard"] or run.get("character") not in ["male","female"]: return {"error":"Invalid checkpoint mode or character."}
		if not integer(run.get("hp"),1,GameState.player_max_hp): return {"error":"Invalid checkpoint HP."}
		var pots:Variant=run.get("potions")
		if not pots is Dictionary or pots.size()!=3: return {"error":"Invalid potion inventory."}
		for key in ["0","1","2"]:
			if not integer(pots.get(key),0,GameState.MAX_PER_POTION): return {"error":"Invalid potion count."}
		if target=="main":
			if not previous_complete(progress,chapter): return {"error":"Checkpoint chapter is locked."}
			var order:=["easy","medium","hard"]
			for i in range(order.find(run.difficulty)):
				if not progress.get(chapter,{}).get(order[i],false): return {"error":"Checkpoint difficulty is locked."}
		# Only allowlisted state reaches the game; no arbitrary resource paths.
		run={"chapter":chapter,"encounter":int(run.encounter),"difficulty":run.difficulty,
			"character":run.character,"hp":int(run.hp),"potions":{"0":int(pots["0"]),"1":int(pots["1"]),"2":int(pots["2"])}}
	return {"error":"","progress":progress,"checkpoint":run}

static func previous_complete(progress:Dictionary, chapter:int) -> bool:
	for previous in range(1,chapter):
		for tier in ["easy","medium","hard"]:
			if not progress.get(previous,{}).get(tier,false): return false
	return true
