class_name SaveFilePanel
extends CanvasLayer
var status:Label
var confirmation:ConfirmationDialog
var pending:Dictionary={}
var callback:JavaScriptObject
var native_dialog:FileDialog

static func open(owner:Node)->void:
	if owner.has_node("SaveFilePanel"): return
	var panel:=SaveFilePanel.new()
	panel.name="SaveFilePanel"
	owner.add_child(panel)

func _ready()->void:
	layer=100
	process_mode=Node.PROCESS_MODE_ALWAYS
	var root:=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade:=ColorRect.new()
	shade.color=Color(0,0,0,.85)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel:=PanelContainer.new()
	panel.custom_minimum_size=Vector2(300,0)
	center.add_child(panel)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("292015")
	style.border_color=Color("c69d51")
	style.set_border_width_all(2)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=12
	style.content_margin_bottom=12
	panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	var title:=Label.new()
	title.text="SAVE / LOAD"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	status=Label.new()
	status.custom_minimum_size=Vector2(268,100)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.text=summary(GameState.checkpoint)+"\nSaves the START of the battle, not the current turn.\nKeep your downloaded file as a backup."
	box.add_child(status)
	button(box,"DOWNLOAD SAVE FILE",_download)
	button(box,"LOAD SAVE FILE",_pick_file)
	var resume:=button(box,"RESUME SAVED CHECKPOINT",_resume)
	resume.disabled=GameState.checkpoint.is_empty() or GameState.tutorial_mode
	button(box,"CLOSE",queue_free)
	confirmation=ConfirmationDialog.new()
	confirmation.title="Load save file?"
	confirmation.ok_button_text="LOAD & CONTINUE"
	confirmation.confirmed.connect(_confirm_import)
	add_child(confirmation)

func button(box:VBoxContainer,text:String,action:Callable)->Button:
	var b:=Button.new()
	b.text=text
	b.custom_minimum_size.y=32
	b.pressed.connect(action)
	box.add_child(b)
	return b

func summary(run:Dictionary)->String:
	if run.is_empty(): return "No active checkpoint. Completed modes can still be backed up."
	return "Chapter %d • %s • Encounter %d\n%s • %d HP"%[run.chapter,str(run.difficulty).capitalize(),int(run.encounter)+1,"Juan" if run.character=="male" else "Maria",run.hp]

func _download()->void:
	if GameState.tutorial_mode:
		status.text="Finish or leave the tutorial before saving."
		return
	var text:=SaveGameCodec.encode(GameState.completed_tiers,GameState.checkpoint)
	var name:="kaalaman-%s-%s.json"%[SaveGameCodec.environment(),Time.get_datetime_string_from_system().replace(":","-")]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(),name,"application/json")
		status.text="Save download requested. Check your browser Downloads.\n"+summary(GameState.checkpoint)
	else:
		_dialog(FileDialog.FILE_MODE_SAVE_FILE)
		native_dialog.current_file=name
		native_dialog.file_selected.connect(func(path:String):
			var file:=FileAccess.open(path,FileAccess.WRITE)
			if file==null: status.text="Could not write the save file."; return
			file.store_string(text)
			file.close()
			status.text="Saved successfully.\n"+summary(GameState.checkpoint))

func _pick_file()->void:
	if OS.has_feature("web"):
		callback=JavaScriptBridge.create_callback(_browser_file)
		JavaScriptBridge.get_interface("window").klhSaveFileCallback=callback
		JavaScriptBridge.eval("""(function(){
 const old=document.getElementById('klh-save-picker'); if(old)old.remove();
 const i=document.createElement('input');i.id='klh-save-picker';i.type='file';i.accept='.json,application/json';i.style.display='none';
 const done=(text)=>{if(window.klhSaveFileCallback)window.klhSaveFileCallback(text);i.remove();};
 i.oncancel=()=>i.remove();i.onchange=()=>{const f=i.files[0];if(!f){i.remove();return;}
 if(f.size>65536){done('');return;}const r=new FileReader();r.onload=()=>done(String(r.result));r.onerror=()=>done('');r.readAsText(f);};
 document.body.appendChild(i);i.click();})();""")
	else:
		_dialog(FileDialog.FILE_MODE_OPEN_FILE)
		native_dialog.file_selected.connect(func(path:String):
			var file:=FileAccess.open(path,FileAccess.READ)
			if file==null or file.get_length()>SaveGameCodec.MAX_BYTES:
				status.text="Cannot read save, or file exceeds 64 KB."
				return
			_accept_text(file.get_as_text()))

func _dialog(mode:FileDialog.FileMode)->void:
	if is_instance_valid(native_dialog):
		remove_child(native_dialog)
		native_dialog.queue_free()
	native_dialog=FileDialog.new()
	native_dialog.access=FileDialog.ACCESS_FILESYSTEM
	native_dialog.file_mode=mode
	native_dialog.filters=PackedStringArray(["*.json ; Kaalaman save files"])
	add_child(native_dialog)
	native_dialog.popup_centered_ratio(.8)

func _browser_file(args:Array)->void:
	if not args.is_empty(): _accept_text(str(args[0]))

func _accept_text(text:String)->void:
	pending=SaveGameCodec.validate(text)
	if not pending.error.is_empty():
		status.text=pending.error
		pending.clear()
		return
	confirmation.dialog_text=summary(pending.checkpoint)+"\n\nReplace the current run? Existing completed modes are kept."
	confirmation.popup_centered(Vector2i(300,200))

func _confirm_import()->void:
	if pending.is_empty(): return
	GameState.apply_imported_save(pending)
	if GameState.checkpoint.is_empty():
		get_tree().paused=false
		GameState.tutorial_mode=false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else: _resume()

func _resume()->void:
	if not GameState.prepare_checkpoint_resume():
		status.text="Checkpoint cannot be resumed. Load a valid save file."
		return
	get_tree().paused=false
	get_tree().change_scene_to_file("res://scenes/word_battle.tscn")

func _exit_tree()->void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.klhSaveFileCallback=null;var p=document.getElementById('klh-save-picker');if(p)p.remove();")
	callback=null
