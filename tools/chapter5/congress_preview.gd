extends Control
## Isolated environment viewer: no GameState mutation or progression writes.
var environment: Control
var stage := 0
var caption: Label
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	caption = Label.new()
	caption.position=Vector2(12,12)
	caption.add_theme_color_override("font_outline_color",Color.BLACK)
	caption.add_theme_constant_override("outline_size",6)
	add_child(caption)
	get_viewport().size_changed.connect(_layout)
	_show_stage()
func _show_stage() -> void:
	get_tree().paused=false
	if is_instance_valid(environment): environment.stop(); environment.queue_free()
	environment=preload("res://scripts/environments/congress_environment.gd").new()
	add_child(environment)
	move_child(environment,0)
	environment.configure(stage)
	caption.text="%d / 9  %s\n1–9 stage | H heavy hit | B boss phase | F final reading | Space pause | Escape close"%[stage+1,environment.spec.title]
	_layout()
func _layout() -> void:
	if is_instance_valid(environment): environment.size=get_viewport_rect().size
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode>=KEY_1 and event.keycode<=KEY_9:
		stage=event.keycode-KEY_1; _show_stage()
	elif event.keycode==KEY_H: environment.react(8.0)
	elif event.keycode==KEY_B: environment.escalate()
	elif event.keycode==KEY_F: environment.set_stage(2)
	elif event.keycode==KEY_SPACE: get_tree().paused=not get_tree().paused
	elif event.keycode==KEY_ESCAPE: get_tree().paused=false; get_tree().quit()
