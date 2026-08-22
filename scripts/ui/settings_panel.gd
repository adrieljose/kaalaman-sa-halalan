extends PanelContainer
class_name SettingsPanel
## The game's one settings panel, used by both the title screen and the
## in-battle pause menu.
##
## It exists as a shared component rather than as two similar-looking panels
## because that is the only way the two stay identical. The battle version had
## already drifted into a plain dark rectangle with unstyled HSliders while the
## title version was rebuilt in the game's wood-and-brass art -- same settings,
## two visibly different objects. Building both from here makes that
## impossible.
##
## Everything is drawn from art the game already owns: panel_ornate for the
## frame, bar_track / bar_fill for the meters, slider_knob for the grabber.

## panel_ornate is 96x96 with a 5px brass frame and a rivet in each corner.
## Slicing at 12 leaves the rivets whole while the wood between them tiles.
const FRAME_SLICE := 12.0
const TITLE_FONT := "res://assets/fonts/TitanOne-Regular.ttf"
const UI_DIR := "res://assets/images/ui"

const GOLD := Color(1, 0.85, 0.5)
const PARCHMENT := Color(0.92, 0.86, 0.72)
const BRASS := Color(0.72, 0.56, 0.22)

var music_slider: HSlider
var sfx_slider: HSlider

var _music_value: Label
var _sfx_value: Label

## Builds the whole panel. `on_close` is wired to the Back button.
##
## The caller positions it: the title screen centres it over the menu, the
## battle scene centres it in its pause overlay, and neither wants the other's
## geometry baked in here.
func build(on_close: Callable) -> void:
	add_theme_stylebox_override("panel", _ornate_style())
	# Scaling on show pushes out from the middle rather than a corner.
	pivot_offset = size * 0.5

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load(TITLE_FONT))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD)
	# Carved-into-the-wood look, matching the signs on the title screen.
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(title)

	var rule := ColorRect.new()
	rule.color = Color(BRASS.r, BRASS.g, BRASS.b, 0.55)
	rule.custom_minimum_size = Vector2(0, 2)
	column.add_child(rule)

	music_slider = HSlider.new()
	_music_value = Label.new()
	column.add_child(_make_row("%s/icon_music.png" % UI_DIR, "Music", music_slider, _music_value))

	sfx_slider = HSlider.new()
	_sfx_value = Label.new()
	column.add_child(_make_row("%s/icon_sfx.png" % UI_DIR, "Sound", sfx_slider, _sfx_value))

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	column.add_child(make_back_button(on_close))
	refresh()

## Repaints both readouts from the volumes actually in force, so the panel
## opens showing the truth rather than whatever it was built with.
func refresh() -> void:
	if music_slider == null:
		return
	music_slider.set_value_no_signal(Audio.music_volume_percent())
	_music_value.text = "%d%%" % int(round(music_slider.value))
	sfx_slider.set_value_no_signal(Audio.sfx_volume_percent())
	_sfx_value.text = "%d%%" % int(round(sfx_slider.value))

## Opens with a short push out from the panel's own centre. Subtle on purpose:
## this is a settings box, not a reward screen.
func pop_open() -> void:
	refresh()
	show()
	scale = Vector2(0.94, 0.94)
	modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)

func _on_music_changed(value: float) -> void:
	Audio.set_music_volume_percent(value)
	_music_value.text = "%d%%" % int(round(value))
	_flash(_music_value)

func _on_sfx_changed(value: float) -> void:
	Audio.set_sfx_volume_percent(value)
	_sfx_value.text = "%d%%" % int(round(value))
	_flash(_sfx_value)
	# Answers audibly as well as visually, so the slider proves itself.
	if value > 0.0:
		Audio.play_sfx("tile_tap")

## Confirms a change on the readout itself: a brief lift, then back. Music has
## no audible answer while it is being dragged, and a number that changes
## silently is easy to miss.
func _flash(label: Label) -> void:
	label.modulate = Color(1.6, 1.5, 1.3)
	var tween := create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 1), 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## The panel background: the game's ornate wood-and-brass frame, nine-sliced so
## it holds at any size instead of the frame stretching with the panel.
func _ornate_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("%s/panel_ornate.png" % UI_DIR)
	style.texture_margin_left = FRAME_SLICE
	style.texture_margin_top = FRAME_SLICE
	style.texture_margin_right = FRAME_SLICE
	style.texture_margin_bottom = FRAME_SLICE
	# Keeps content off the brass, which the frame would otherwise overlap.
	style.set_content_margin_all(6.0)
	return style

## One settings row: icon, name, slider, live percentage.
##
## The fixed widths on the name and the readout are what line the two sliders
## up with each other. Without them each row sizes to its own text, so "Music"
## and "Sound" start their tracks at different x positions.
func _make_row(icon_path: String, label_text: String,
		slider: HSlider, value_label: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(18, 18)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size = Vector2(50, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", PARCHMENT)
	row.add_child(name_label)

	_style_slider(slider)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	value_label.custom_minimum_size = Vector2(34, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", GOLD)
	row.add_child(value_label)
	return row

## Dresses an HSlider in the game's own bar art.
##
## The three pieces are theme items of different KINDS, which is what the
## original panels got wrong: `slider` and `grabber_area` are styleboxes, but
## `grabber` is an ICON. Overriding only the styleboxes leaves Godot drawing
## its default grey circle, floating clear of the track.
func _style_slider(slider: HSlider) -> void:
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(0, 18)

	var track := StyleBoxTexture.new()
	track.texture = load("%s/bar_track.png" % UI_DIR)
	# bar_track is 64x14 with 4px end caps; slicing there keeps the caps square
	# however far the middle is stretched.
	track.texture_margin_left = 4.0
	track.texture_margin_right = 4.0
	# Not decoration: Slider draws its track at the stylebox's MINIMUM height,
	# and a stylebox with only horizontal margins reports zero -- so the track
	# draws 0px tall and vanishes, leaving the grabber on nothing.
	track.texture_margin_top = 7.0
	track.texture_margin_bottom = 7.0
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxTexture.new()
	fill.texture = load("%s/bar_fill.png" % UI_DIR)
	fill.texture_margin_left = 4.0
	fill.texture_margin_right = 4.0
	fill.texture_margin_top = 7.0
	fill.texture_margin_bottom = 7.0
	# The art is near-white so it can be tinted per use; brass here, so the
	# panel stays a two-colour object rather than gaining a fourth hue.
	fill.modulate_color = Color(0.93, 0.74, 0.33)
	slider.add_theme_stylebox_override("grabber_area", fill)

	var fill_hot: StyleBoxTexture = fill.duplicate()
	fill_hot.modulate_color = Color(1.0, 0.88, 0.52)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hot)

	var knob: Texture2D = load("%s/slider_knob.png" % UI_DIR)
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)

## The Back button, shared so every panel in the game closes with the same
## control. Static because the pause menu wants one on its main page too,
## where there is no SettingsPanel instance to ask.
static func make_back_button(handler: Callable, label: String = "Back") -> Button:
	var close := Button.new()
	close.text = label
	close.custom_minimum_size = Vector2(0, 24)
	close.add_theme_font_size_override("font_size", 12)
	close.add_theme_color_override("font_color", Color(1, 0.96, 0.85))

	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.55, 0.2, 0.18, 0.85)
	base.set_border_width_all(2)
	base.border_color = Color(0.85, 0.75, 0.5, 0.8)
	base.set_corner_radius_all(3)
	for state in ["normal", "focus"]:
		close.add_theme_stylebox_override(state, base)

	# Hover lifts, press sinks. Sharing one box across all four states, as the
	# original did, means the button never acknowledges the cursor at all.
	var hover: StyleBoxFlat = base.duplicate()
	hover.bg_color = Color(0.68, 0.26, 0.22, 0.92)
	hover.border_color = Color(1.0, 0.9, 0.62, 0.95)
	close.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = base.duplicate()
	pressed.bg_color = Color(0.4, 0.14, 0.13, 0.95)
	pressed.border_color = Color(0.7, 0.6, 0.4, 0.8)
	close.add_theme_stylebox_override("pressed", pressed)

	close.pressed.connect(handler)
	return close
