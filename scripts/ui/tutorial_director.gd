class_name TutorialDirector
extends Control
## The coaching layer that runs over the real battle screen.
##
## It teaches by pointing AT the live interface rather than by describing it: a
## step names a node, this dims everything except that node's rect and parks an
## instruction card next to it with an arrow between the two. Nothing here is a
## mock-up of the battle UI -- the thing under the spotlight is the thing the
## player will use, at the position the current layout actually put it, which
## is also why a step's target is a Callable resolved at display time instead of
## a node captured up front. Rotate the device mid-tutorial and the spotlight
## follows.
##
## This class owns presentation only: the scrim, the card, the arrow and the
## NEXT / BACK / SKIP wiring. It knows nothing about elections, damage or
## potions. The steps -- their words, their targets and the battle actions some
## of them run -- are supplied by WordBattleController._tutorial_steps(), which
## is where the mechanics being explained actually live, so an explanation
## cannot drift away from its subject without the two files disagreeing in the
## same edit.

## Emitted once, when the player leaves the tutorial.
##
## `start_game` is true only from the END card's "START GAME". `completed` says
## whether they reached that card at all, by any button -- the caller uses it to
## decide whether the first-time prompt has been satisfied, and someone who taps
## SKIP on step two has not satisfied it.
signal closed(start_game: bool, completed: bool)

const PANEL_TEXTURE := preload("res://assets/images/ui/panel_ornate.png")
const PANEL_SLICE := 10.0
const PANEL_CONTENT := 9.0

const SCRIM_COLOR := Color(0.03, 0.02, 0.01, 0.72)
const HALO_COLOR := Color(1.0, 0.82, 0.35)
const HALO_SOFT := Color(1.0, 0.82, 0.35, 0.35)
const ARROW_COLOR := Color(1.0, 0.82, 0.35)
const TITLE_COLOR := Color(1.0, 0.88, 0.55)
const BODY_COLOR := Color(0.93, 0.88, 0.78)
const COUNT_COLOR := Color(0.70, 0.60, 0.44)

## Breathing room left between the spotlight and the card.
const CARD_GAP := 14.0
const CARD_MARGIN := 10.0
const HALO_PAD := 4.0

var _steps: Array[Dictionary] = []
var _index: int = -1
## True while a step's demonstration is playing. Navigation is locked for its
## duration -- the alternative is a player clicking NEXT through an attack and
## watching the explanation of the next thing over the top of it.
var _busy: bool = false
## The rect being lit right now, in this control's own coordinates. Empty means
## "no target": the card centres and no arrow is drawn.
var _spot: Rect2 = Rect2()

var _card: PanelContainer
var _title: Label
var _body: Label
var _counter: Label
var _buttons: HBoxContainer
var _back_button: Button
var _next_button: Button
var _skip_button: Button


func _ready() -> void:
	# Swallows every click that is not on one of our own buttons: the battle
	# underneath is live, and a stray tap on the board mid-lesson would spend
	# the turn the lesson is about to demonstrate.
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The card is built FIRST, before the line below.
	#
	# Growing from nothing to the full screen fires NOTIFICATION_RESIZED, and
	# this control answers that by re-placing the card -- so with the two the
	# other way round _ready() reached into a card that did not exist yet and
	# died on it. That left _card null for good, and every later frame of
	# _process() died the same way.
	_build_card()
	# ANCHORS **AND OFFSETS**. set_anchors_preset() alone preserves the rect the
	# control already has and rewrites the offsets to keep it -- and a Control
	# built with .new() has a rect of zero. That silently produced a director of
	# size (0,0): the scrim drew nothing, and every clamp in _place_card()
	# collapsed onto CARD_MARGIN, parking the card in the top-left corner with
	# no spotlight anywhere.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)

## Hands over the script and shows the first card.
func begin(steps: Array[Dictionary]) -> void:
	_steps = steps
	_index = -1
	await _go_to(0)

# --- construction ---------------------------------------------------------

func _build_card() -> void:
	_card = PanelContainer.new()
	_card.name = "CoachCard"
	_card.add_theme_stylebox_override("panel", _nine_slice())
	add_child(_card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_card.add_child(column)

	_counter = Label.new()
	_counter.add_theme_color_override("font_color", COUNT_COLOR)
	_counter.add_theme_font_size_override("font_size", 9)
	column.add_child(_counter)

	_title = Label.new()
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.add_theme_font_size_override("font_size", 14)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	_body = Label.new()
	_body.add_theme_color_override("font_color", BODY_COLOR)
	_body.add_theme_font_size_override("font_size", 11)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_body)

	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 5)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_buttons)

	_skip_button = _make_button("SKIP", Color(0.80, 0.72, 0.62))
	_skip_button.pressed.connect(_on_skip_pressed)
	_buttons.add_child(_skip_button)

	_back_button = _make_button("BACK", Color(0.86, 0.82, 0.74))
	_back_button.pressed.connect(_on_back_pressed)
	_buttons.add_child(_back_button)

	_next_button = _make_button("NEXT", Color(1.0, 0.90, 0.60))
	_next_button.pressed.connect(_on_next_pressed)
	_buttons.add_child(_next_button)

func _make_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(0.16, 0.10, 0.05))
	button.custom_minimum_size = Vector2(58.0, 22.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _button_style(accent, state))
	return button

## Flat wooden chips rather than the console's carved wells: the card floats
## over a dimmed screen, and the heavier chrome read as a second HUD competing
## with the one being explained.
func _button_style(accent: Color, state: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	var shade := accent
	match state:
		"pressed":
			shade = accent.darkened(0.35)
		"hover", "focus":
			shade = accent.lightened(0.12)
		"disabled":
			shade = accent.darkened(0.55)
	box.bg_color = shade
	box.border_color = shade.darkened(0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	if state == "pressed":
		box.content_margin_top = 4.0
		box.content_margin_bottom = 2.0
	return box

func _nine_slice() -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	for side in ["left", "top", "right", "bottom"]:
		box.set("texture_margin_" + side, PANEL_SLICE)
		box.set("content_margin_" + side, PANEL_CONTENT)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box

# --- navigation -----------------------------------------------------------

func _on_next_pressed() -> void:
	if _busy:
		return
	Audio.play_sfx("button_click")
	if _index >= _steps.size() - 1:
		closed.emit(true, true)
		return
	await _go_to(_index + 1)

func _on_back_pressed() -> void:
	if _busy or _index <= 0:
		return
	Audio.play_sfx("button_click")
	# Backwards never replays a demonstration. Re-running an attack to re-read
	# the sentence next to it would spend the rival's health a second time and
	# leave the numbers in the card describing a fight that had moved on.
	await _go_to(_index - 1, false)

func _on_skip_pressed() -> void:
	Audio.play_sfx("button_click")
	closed.emit(false, _index >= _steps.size() - 1)

func _go_to(index: int, run_action: bool = true) -> void:
	if index < 0 or index >= _steps.size():
		return
	_index = index
	var step: Dictionary = _steps[index]
	_title.text = String(step.get("title", ""))
	_body.text = String(step.get("body", ""))
	_counter.text = "STEP %d OF %d" % [index + 1, _steps.size()]

	var last := index >= _steps.size() - 1
	_next_button.text = String(step.get("next_text", "START GAME" if last else "NEXT"))
	_skip_button.text = "BACK TO MENU" if last else "SKIP"
	_skip_button.custom_minimum_size.x = 92.0 if last else 58.0
	_back_button.visible = index > 0
	_refresh_spot()

	var action: Variant = step.get("action")
	if run_action and action is Callable:
		_set_busy(true)
		await (action as Callable).call()
		_set_busy(false)
		# The demonstration may have moved what the step points at -- health
		# came off a bar, a question was replaced -- so the spotlight is
		# re-measured once it has finished rather than only before it starts.
		_refresh_spot()

func _set_busy(busy: bool) -> void:
	_busy = busy
	_next_button.disabled = busy
	_back_button.disabled = busy

# --- spotlight and placement ----------------------------------------------

## Re-reads the current step's target and re-places the card around it. Called
## on every step change and every frame, so a layout pass, a rotation or an
## animation that moves the target cannot leave the halo behind.
func _refresh_spot() -> void:
	if _index < 0 or _index >= _steps.size():
		return
	var target: Variant = _steps[_index].get("target")
	var rect := Rect2()
	if target is Callable:
		var resolved: Variant = (target as Callable).call()
		if resolved is Array:
			# Several nodes lit as one region. The board step needs this: the
			# demonstration spells the word into the tray, and lighting only the
			# board would leave the card free to park itself over the very thing
			# the demonstration is producing.
			for item: Variant in resolved as Array:
				var part := _local_rect(item)
				rect = part if rect.size == Vector2.ZERO else rect.merge(part)
		else:
			rect = _local_rect(resolved)
	if not rect.is_equal_approx(_spot):
		_spot = rect
		queue_redraw()
	_place_card()

## A target's rect in this control's own coordinates, or an empty rect for
## anything not on screen. Hidden nodes return empty rather than their last
## known rect, so a step that names something the current arrangement does not
## show lights nothing instead of lighting the wrong place.
func _local_rect(target: Variant) -> Rect2:
	if target is Control and (target as Control).is_visible_in_tree():
		var global_rect := (target as Control).get_global_rect()
		return Rect2(global_rect.position - global_position, global_rect.size)
	if target is Rect2:
		return target as Rect2
	return Rect2()

func _process(_delta: float) -> void:
	_refresh_spot()

func _notification(what: int) -> void:
	# A rotation resizes this control without changing the step, so the scrim
	# has to be redrawn against the new screen even when the target has not
	# moved within it.
	if what == NOTIFICATION_RESIZED and _card != null:
		queue_redraw()
		_place_card()

## Puts the card in the largest band of screen the spotlight is not using.
##
## Deliberately not "always below": on a phone the potion chips are at the top
## and the board fills the bottom, so a fixed side would bury the card under
## whatever it was pointing at for half the lesson.
func _place_card() -> void:
	# Notifications reach a Control before its _ready() has finished building
	# anything, and a resize is one of them -- see the ordering note in _ready().
	# The guard stays even though that ordering is now correct: a node that dies
	# inside a notification is dead for the rest of its life, which is far too
	# expensive a failure for a screen whose whole job is to be reassuring.
	if _card == null:
		return
	var screen := size
	# 340 rather than 300: on the desktop composition the board step's spotlight
	# runs from the word tray to the bottom of the grid, which leaves the card
	# about 125 units of clear space above it. A wider card is a shorter one,
	# and the difference between four wrapped lines and three is the difference
	# between overlapping the tray and clearing it.
	var wanted: float = clampf(screen.x - CARD_MARGIN * 2.0, 150.0, 340.0)
	_card.size.x = wanted
	_body.custom_minimum_size.x = wanted - PANEL_CONTENT * 2.0
	_title.custom_minimum_size.x = wanted - PANEL_CONTENT * 2.0
	var card_size := Vector2(wanted, _card.get_combined_minimum_size().y)

	var x: float = clampf((screen.x - card_size.x) * 0.5,
		CARD_MARGIN, maxf(screen.x - card_size.x - CARD_MARGIN, CARD_MARGIN))
	var y: float = (screen.y - card_size.y) * 0.5
	if _spot.size.x > 0.0:
		var below: float = screen.y - _spot.end.y - CARD_GAP - CARD_MARGIN
		var above: float = _spot.position.y - CARD_GAP - CARD_MARGIN
		if below >= card_size.y or below >= above:
			y = _spot.end.y + CARD_GAP
		else:
			y = _spot.position.y - CARD_GAP - card_size.y
		# Nudged toward the target horizontally so the arrow stays short.
		x = clampf(_spot.get_center().x - card_size.x * 0.5,
			CARD_MARGIN, maxf(screen.x - card_size.x - CARD_MARGIN, CARD_MARGIN))
	y = clampf(y, CARD_MARGIN, maxf(screen.y - card_size.y - CARD_MARGIN, CARD_MARGIN))
	_card.position = Vector2(floorf(x), floorf(y))
	_card.size = card_size

func _draw() -> void:
	var screen := size
	if _spot.size.x <= 0.0 or _spot.size.y <= 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), SCRIM_COLOR, true)
		return

	# The hole is cut by drawing the four bands around it rather than with a
	# blend mode, which keeps this working identically on the GLES fallback the
	# web export can land on.
	var hole := _spot.grow(HALO_PAD).intersection(Rect2(Vector2.ZERO, screen))
	draw_rect(Rect2(0, 0, screen.x, hole.position.y), SCRIM_COLOR, true)
	draw_rect(Rect2(0, hole.end.y, screen.x, screen.y - hole.end.y), SCRIM_COLOR, true)
	draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), SCRIM_COLOR, true)
	draw_rect(Rect2(hole.end.x, hole.position.y, screen.x - hole.end.x, hole.size.y),
		SCRIM_COLOR, true)

	draw_rect(hole.grow(1.0), HALO_SOFT, false, 3.0)
	draw_rect(hole, HALO_COLOR, false, 1.0)
	_draw_arrow(hole)

## A stubby triangle on the card's edge, aimed at the middle of the halo. Kept
## short on purpose -- a long pointer crossing a dimmed battle screen reads as
## another piece of UI rather than as a gesture.
func _draw_arrow(hole: Rect2) -> void:
	var card := Rect2(_card.position, _card.size)
	var from := card.get_center()
	var to := hole.get_center()
	var dir := to - from
	if dir.length() < 1.0:
		return
	dir = dir.normalized()
	var tip: Vector2
	if absf(dir.y) > absf(dir.x):
		tip = Vector2(clampf(to.x, card.position.x + 8.0, card.end.x - 8.0),
			card.end.y + 6.0 if dir.y > 0.0 else card.position.y - 6.0)
	else:
		tip = Vector2(card.end.x + 6.0 if dir.x > 0.0 else card.position.x - 6.0,
			clampf(to.y, card.position.y + 8.0, card.end.y - 8.0))
	var side := Vector2(-dir.y, dir.x) * 6.0
	var base := tip - dir * 8.0
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]),
		ARROW_COLOR)
