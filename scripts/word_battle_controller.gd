extends Control
class_name WordBattleController

const SPARK_BONUS_DAMAGE := 10
const GOLD_MULTIPLIER := 2
## Bookworm's Health Potion restores 2 hearts. Ours run 20 HP to a heart.
const HEALTH_POTION_HEAL := 40
## Power Up lasts exactly one attack, then burns off.
const POWER_UP_MULTIPLIER := 2.0
## An attack resolves as a sequence of beats rather than one instant tick:
## player swings, the hit travels across, the enemy flinches, then the enemy
## counterattacks. These are the pauses between those beats.
const TRAVEL_TIME := 0.35
const BEAT_PAUSE := 0.25
const MIN_WORD_LENGTH := 3
## Bonus damage banked when the Mudslinging Tile detonates, added on top of
## the enemy's attack rather than replacing it.
const MUD_DAMAGE_BONUS := 8
## Seconds to answer live in GameState.QUESTION_TIME_BY_DIFFICULTY, not here —
## the difficulty menu quotes those same numbers to the player before a run
## starts, so both screens have to read one table or the promise drifts from
## the clock.
## How long the educational fact stays up after a correct answer, before the
## next question replaces it.
const FACT_PAUSE := 2.0
## The answer is the only thing that can be attacked with, so this scales
## every hit — it keeps damage in a sensible range against enemy HP now that
## short answers are the norm.
const ANSWER_BONUS_MULTIPLIER := 2.5
## Marker in a question's prompt that gets expanded into the answer-shaped
## blank. Stored in the JSON as a plain "___" so the bank stays readable.
const BLANK_TOKEN := "___"
## Roughly what share of the answer's letters are already filled into the
## blank. This is the third thing difficulty controls, alongside the question
## pool and the clock — an easy round hands you half the word, a hard one only
## enough to get started.
const HINT_REVEAL_BY_DIFFICULTY := {
	"easy": 0.5,
	"medium": 0.34,
	"hard": 0.25,
}
const DEFAULT_HINT_REVEAL := 0.34
## However generous the share works out to be, at least this many letters stay
## hidden — otherwise a short answer like INK or MAY would be spelled out in
## the prompt and there would be nothing left to work out.
const MIN_HIDDEN_LETTERS := 2
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
## How far the player strides right before the screen veils over, and how long
## that stride takes. Purely presentational — the encounter has already been
## decided by the time this plays.
const WALK_DISTANCE := 150.0
const WALK_TIME := 1.1
const VEIL_TIME := 0.45
## How long the "Encounter 3 of 5 — Kapitan Komisyon" card holds before the
## board comes back.
const BANNER_TIME := 1.6
## Health carried between encounters. Bookworm hands you the next fight at the
## health you finished the last one with, which is what makes potions a real
## resource — but a full chapter with no relief is punishing for the age group
## this is aimed at, so surviving an encounter refunds part of the bar.
## Tune this: 0.0 is strict Bookworm, 1.0 heals fully between fights.
const BETWEEN_ENCOUNTER_HEAL_FRACTION := 0.35
const LETTER_TILE_SCENE := preload("res://scenes/ui/letter_tile.tscn")

## The player's swing scales with the length of the word. There is only one
## attack sprite clip, so the escalation is carried by motion around it: how
## far the player overshoots past contact, how many bolts cross the gap, how big they
## are, and how hard the screen takes the impact. Checked in order; the first
## tier whose max_length fits is used.
## `damage` is what keeps length ahead of speed. Base damage is the sum of
## Scrabble letter values, which tracks length only loosely — BOTO is 6 points
## across 4 letters, BALLOT only 8 across 6 — so a 1.3x speed bonus could
## otherwise erase a two-letter advantage outright. Scaling each tier restores
## a strict ordering: the fastest possible word of one tier still lands under
## the slowest of the next.
const ATTACK_TIERS: Array[Dictionary] = [
	{"max_length": 5, "label": "", "damage": 1.0, "lunge": 12.0, "bolts": 1, "bolt_size": 14.0, "shake": 0.0, "rate": 1.0},
	{"max_length": 8, "label": "STRONG", "damage": 1.25, "lunge": 26.0, "bolts": 3, "bolt_size": 19.0, "shake": 4.0, "rate": 0.85},
	{"max_length": 99, "label": "DEVASTATING", "damage": 1.6, "lunge": 42.0, "bolts": 6, "bolt_size": 25.0, "shake": 9.0, "rate": 0.7},
]

## Spelling quickly hits harder. Speed is measured per letter, not as raw
## elapsed time — a 14-letter answer legitimately takes longer to pick out than
## a 4-letter one, and judging both against the same stopwatch would make long
## words unrewardable. First tier whose threshold the player beats wins.
const SPEED_TIERS: Array[Dictionary] = [
	{"seconds_per_letter": 0.35, "multiplier": 1.30, "label": "LIGHTNING"},
	{"seconds_per_letter": 0.60, "multiplier": 1.15, "label": "QUICK"},
	{"seconds_per_letter": 1.00, "multiplier": 1.05, "label": ""},
]
## Applied when no tier is beaten. Never below 1.0: being slow costs the bonus,
## it does not punish the hit — the clock already punishes slowness.
const SPEED_BASE_MULTIPLIER := 1.0
## Panel chrome. These are applied from code rather than being baked into
## word_battle.tscn as theme overrides, because the scene file is edited in the
## Godot editor and a save there silently reverts stylebox edits made on disk.
## Doing it here also means "every panel gets the same treatment" is one list
## rather than a property repeated on seven nodes.
const PANEL_TEXTURE := preload("res://assets/images/ui/panel_ornate.png")
const BAR_TRACK_TEXTURE := preload("res://assets/images/ui/bar_track.png")
const BAR_FILL_TEXTURE := preload("res://assets/images/ui/bar_fill.png")
## Must match the frame thickness drawn by tools/make_ui_panels.py.
const PANEL_SLICE := 10.0
const PANEL_CONTENT := 7.0
const BAR_SLICE := 3.0
## Side-panel roster styling. The panel sizes itself to its content, so this is
## the line it must not cross — the enemy sprite stands directly beneath it.
const SIDE_PANEL_BOTTOM_LIMIT := 262.0
## Measured, not assumed: shrinking this to 14 changed the roster height by
## exactly nothing, because the header row is as tall as the NAME line (font
## 11), not the icon. The height levers that actually work are the name font
## and the description line count.
const MOVE_ICON_SIZE := Vector2(16, 16)
const MOVE_HEADING_COLOR := Color(0.78, 0.68, 0.5)
const MOVE_NAME_COLOR := Color(1, 0.85, 0.55)
const MOVE_DESC_COLOR := Color(0.86, 0.80, 0.68)
## The incoming move is lit; the rest are pushed back so the contrast between
## them does the telegraphing rather than the highlight alone.
const MOVE_ACTIVE_NAME_COLOR := Color(1, 0.93, 0.66)
const MOVE_IDLE_NAME_COLOR := Color(0.62, 0.53, 0.38)
const MOVE_IDLE_DESC_COLOR := Color(0.52, 0.48, 0.40)
## Warning orange, distinct from the gold used everywhere else in the UI so a
## lit move cannot be mistaken for ordinary trim.
const MOVE_ALERT_COLOR := Color(0.98, 0.62, 0.24)
## Values above 1 brighten; self_modulate lifts only the plate, not its text.
const MOVE_PULSE_BRIGHT := Color(1.45, 1.18, 0.95)
## Reserved on every entry so the badge appearing never reflows the row.
const MOVE_BADGE_WIDTH := 26.0

## --- HUD geometry -----------------------------------------------------
## The whole HUD lives above y=54, where QuestionPanel and PotionPanel begin.
## Everything below is measured down from that ceiling rather than eyeballed,
## so the header can never creep into the play area.
const HUD_HEIGHT := 53.0
const HUD_BAR_SLICE := 4.0
const HUD_INNER_TOP := 4.0
const HUD_INNER_BOTTOM := 49.0
const HUD_PORTRAIT := 38.0
const HUD_RIBBON_H := 15.0
const HUD_SLOT_H := 17.0
const HUD_HEART := 14.0
const HUD_PILLAR_W := 12.0
## Both fighters draw the same five hearts, each standing for a fifth of their
## own max HP. See HeartRow.fixed_heart_count for why proportional beats a
## fixed 20-points-per-heart here.
const HUD_HEART_COUNT := 5
## Section bounds across the bar: portrait, info, pillar, centre, pillar, info,
## portrait. These were constants measured against a fixed 640-wide bar; they
## are computed per layout now (see _hud_metrics()), because the bar spans
## whatever width the device actually has. The left-hand numbers below are the
## authored ones and are still used verbatim — only the right-hand sections
## move, mirrored in from the real right edge.
const HUD_LEFT_PORTRAIT_X := 6.0
const HUD_LEFT_INFO_X := 48.0
const HUD_PILLAR_A_X := 204.0
## Distances measured IN from the right edge, so a 640-wide bar reproduces the
## authored 424/440/592/596 exactly and a wider one keeps the enemy's block
## against its own edge instead of stranding it mid-screen.
const HUD_PILLAR_B_INSET := 216.0
const HUD_RIGHT_INFO_INSET := 200.0
const HUD_RIGHT_INFO_R_INSET := 48.0
const HUD_RIGHT_PORTRAIT_INSET := 44.0

## The live HUD geometry, rebuilt by _hud_metrics() on every layout change and
## read by the section builders. Keyed by the same names as the constants above
## so the builders read close to how they did when those were fixed.
var _hud: Dictionary = {}
const HUD_BAR_TEX := preload("res://assets/images/ui/hud_bar.png")
const HUD_RIBBON_TEX := preload("res://assets/images/ui/hud_ribbon.png")
const HUD_SLOT_TEX := preload("res://assets/images/ui/hud_slot.png")
const HUD_FRAME_TEX := preload("res://assets/images/ui/hud_portrait_frame.png")
const HUD_PILLAR_TEX := preload("res://assets/images/ui/hud_pillar.png")
const HUD_PARCHMENT_TEX := preload("res://assets/images/ui/hud_parchment.png")
const HUD_TITLE_FONT := preload("res://assets/fonts/TitanOne-Regular.ttf")
const HUD_CREAM := Color(1, 0.96, 0.86)
const HUD_MUTED := Color(0.74, 0.66, 0.52)
const HUD_GOLD := Color(1, 0.84, 0.42)
## Difficulty reads as a colour before it reads as a word — the same three
## semantic colours the reviewer screen uses for its tier headings.
const HUD_DIFFICULTY_COLORS := {
	"easy": Color(0.45, 0.72, 0.40),
	"medium": Color(0.88, 0.70, 0.26),
	"hard": Color(0.80, 0.34, 0.30),
}

@onready var background: TextureRect = $Background
@onready var potion_panel: PanelContainer = $PotionPanel
@onready var question_panel: PanelContainer = $QuestionPanel
@onready var side_panel: PanelContainer = $SidePanel
## Neither of these had a handle before, because nothing ever moved them.
@onready var board_frame: PanelContainer = $BoardFrame
@onready var console_bar: TextureRect = $ConsoleBar
@onready var potion_title: Label = $PotionPanel/VBox/PotionTitle
@onready var potion_row: HBoxContainer = $PotionPanel/VBox/Row
@onready var board: BoardController = $Board
@onready var enemy_name_label: Label = $TopBar/EnemyPanel/EnemyNameLabel
@onready var enemy_heart_row: HeartRow = $TopBar/EnemyPanel/EnemyHeartRow
@onready var player_heart_row: HeartRow = $TopBar/PlayerPanel/PlayerHeartRow
@onready var enemy_character: AnimatedCharacter = $EnemyCharacter
@onready var player_character: AnimatedCharacter = $PlayerCharacter
@onready var question_label: Label = $QuestionPanel/VBox/QuestionLabel
@onready var timer_bar: ProgressBar = $QuestionPanel/VBox/TimerBar
@onready var side_panel_vbox: VBoxContainer = $SidePanel/VBox
@onready var word_tray: HBoxContainer = $WordTray
@onready var word_preview_label: Label = $WordPreviewLabel
@onready var attack_button: Button = $AttackButton
@onready var shuffle_button: Button = $ShuffleButton
@onready var menu_button: Button = $MenuButton
@onready var health_potion_button: Button = $PotionPanel/VBox/Row/HealthPotionButton
@onready var power_potion_button: Button = $PotionPanel/VBox/Row/PowerPotionButton
@onready var purify_potion_button: Button = $PotionPanel/VBox/Row/PurifyPotionButton
@onready var result_overlay: PanelContainer = $ResultOverlay
@onready var result_label: Label = $ResultOverlay/VBox/ResultLabel
@onready var try_again_button: Button = $ResultOverlay/VBox/TryAgainButton
@onready var pause_overlay: Control = $PauseOverlay
## The in-battle settings panel is the SAME component the title screen
## uses, built in code rather than laid out in the scene. Two hand-built
## panels drift: this one had stayed a plain dark rectangle with unstyled
## sliders long after the title version was rebuilt in the game's own art.
var pause_options_panel: SettingsPanel
@onready var pause_main_panel: PanelContainer = $PauseOverlay/PauseMainPanel
@onready var resume_button: Button = $PauseOverlay/PauseMainPanel/VBox/ResumeButton
@onready var pause_options_button: Button = $PauseOverlay/PauseMainPanel/VBox/OptionsButton
@onready var title_button: Button = $PauseOverlay/PauseMainPanel/VBox/TitleButton
@onready var encounter_label: Label = $TopBar/EnemyPanel/EncounterLabel
@onready var chapter_banner: TextureRect = $ChapterBanner
@onready var header_bar: ColorRect = $HeaderBar
@onready var chapter_label: Label = $ChapterLabel
@onready var chapter_badge: PanelContainer = $ChapterBadge
@onready var chapter_badge_label: Label = $ChapterBadge/ChapterBadgeLabel
@onready var top_bar: Control = $TopBar
@onready var player_panel: VBoxContainer = $TopBar/PlayerPanel
@onready var enemy_panel: VBoxContainer = $TopBar/EnemyPanel
@onready var player_name_label: Label = $TopBar/PlayerPanel/PlayerNameLabel
@onready var transition_veil: ColorRect = $TransitionVeil
@onready var encounter_banner: PanelContainer = $EncounterBanner
@onready var banner_title_label: Label = $EncounterBanner/VBox/BannerTitleLabel
@onready var banner_name_label: Label = $EncounterBanner/VBox/BannerNameLabel

var _enemy: EnemyData
var _enemy_hp: int
var _player_hp: int
## HUD pieces built in code rather than added to word_battle.tscn — the editor
## silently overwrites scene-file edits when it has that scene open, and this
## is the same reason the panel chrome is applied from _apply_panel_chrome().
var _difficulty_chip: PanelContainer
var _difficulty_label: Label
var _hud_player_portrait: TextureRect
var _hud_enemy_portrait: TextureRect
var _hud_chapter_ribbon_label: Label
var _move_index: int = 0
## One dict per roster entry {plate,name,desc,icon,badge}, so the highlight can
## restyle an entry without rebuilding the panel.
var _move_entries: Array[Dictionary] = []
var _move_pulse_tween: Tween
## The skill currently swinging, so _body_swing can reach its own attack clip.
var _signature_move: EnemyMove
## The screen's resting position, captured once so camera shake always has a
## true home to return to no matter how many hits overlap.
var _screen_home: Vector2 = Vector2.ZERO
var _shake_tween: Tween
var _power_up_active: bool = false
## The board fires mud_detonated *before* word_accepted, so a bonus hit is
## parked here and folded into the enemy's turn instead of landing while the
## player's own swing is still mid-animation. This is a bonus on TOP of the
## enemy's guaranteed per-turn attack below, not a separate trigger for it —
## see enemy-attack-plan.md §0 for why the enemy needed a real turn at all.
var _pending_enemy_damage: int = 0
## True while an attack sequence is playing; every action button stays locked
## until the beats finish so input can't interleave with the animation.
var _sequence_running: bool = false
var _current_selection: String = ""
## The question on screen: {prompt, answer, fact}. Empty between questions.
var _question: Dictionary = {}
var _time_left: float = 0.0
## Stops the countdown once someone has won, so the timer can't fire an attack
## over the result screen.
var _match_over: bool = false
## Where the player sprite sits when not marching between encounters. Captured
## once at startup so the walk can always put it back exactly.
var _player_home_x: float = 0.0
## Seconds allowed per question, resolved from the run's difficulty once at
## startup rather than looked up on every frame of the countdown.
var _question_time: float = GameState.DEFAULT_QUESTION_TIME
## Held so the countdown can retint the bar without re-querying the theme.
var _timer_fill_style: StyleBoxTexture
## The compact roster strip, and whether its overlay is currently open. Both
## only mean anything on PORTRAIT / LANDSCAPE_COMPACT; on WIDE the full roster
## is permanently on screen and the strip is hidden.
var _move_strip: Button
var _moves_open: bool = false
## When the current word was started, in milliseconds. Set on the tap that
## takes the selection from empty to one letter, so the clock measures the time
## spent building THIS word rather than time spent staring at the board first.
var _selection_started_ms: int = 0

func _ready() -> void:
	# Re-applied on every load rather than only when the menu sets it, so the
	# pool is correct after Try Again and when this scene is booted directly.
	# Chapter comes along with it: questions are scoped to the topic of the
	# chapter being played, not drawn from one generic election pool.
	QuestionBank.set_context(GameState.chapter_number(), GameState.difficulty)
	player_character.configure_clips(GameState.character_clips())
	_question_time = GameState.question_seconds()
	# Renamed from "Shuffle": it rerolls the question now, not the letters.
	shuffle_button.text = "New Question"
	shuffle_button.add_theme_font_size_override("font_size", 12)
	_screen_home = position
	_apply_panel_chrome()
	# The HUD is no longer built here: it needs the layout metrics, so
	# _apply_layout() builds it as part of the first layout pass below.
	board.word_accepted.connect(_on_word_accepted)
	board.tile_lifted.connect(_on_tile_lifted)
	board.tile_returned.connect(_on_tile_returned)
	board.word_rejected.connect(_on_word_rejected)
	board.selection_changed.connect(_on_selection_changed)
	board.mud_detonated.connect(_on_mud_detonated)
	attack_button.pressed.connect(_on_attack_pressed)
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	health_potion_button.pressed.connect(_use_health_potion)
	power_potion_button.pressed.connect(_use_power_potion)
	purify_potion_button.pressed.connect(_use_purify_potion)
	try_again_button.pressed.connect(_on_try_again_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	pause_options_button.pressed.connect(_on_pause_options_pressed)
	title_button.pressed.connect(_on_title_pressed)
	_build_pause_options()
	pause_overlay.hide()
	encounter_banner.hide()
	transition_veil.color.a = 0.0
	transition_veil.hide()
	_build_move_strip()
	# Before _start_encounter, so the first question is presented into a layout
	# that is already the right shape. bind() runs the pass immediately and then
	# keeps us subscribed, which is what makes rotating the device mid-fight work.
	Layout.bind(self, "_apply_layout")
	_start_encounter(true)
	Audio.play_music("battle")

# --- responsive layout ----------------------------------------------------
#
# The battle scene was authored entirely in absolute offsets against a 640x480
# canvas. Rather than re-author it, the layout below re-places the same nodes
# per arrangement. WIDE reproduces the authored composition exactly (see
# _layout_battle_wide), so a 4:3 window is unchanged.

## Where the play area's bottom controls sit, and how tall a tap target has to
## be to count as one. 44 CSS px is the usual minimum; on a phone the content
## scale turns 44 design units into roughly 54, with margin to spare.
const TOUCH_TARGET := 44.0
## Below this design height the portrait layout stops trying to give the stage
## a generous share and starts protecting the board instead.
const PORTRAIT_STAGE_MIN := 92.0
## Where the floor the fighters stand on sits in the battle backdrop, as a
## fraction of the image height. Taken from the authored composition: the
## player's rect ends at y=438 of 480 with the backdrop drawn 1:1 over it.
const BATTLE_GROUND_FRACTION := 0.9125

func _apply_layout(profile: LayoutProfile) -> void:
	_hud = _hud_metrics(profile)
	_build_hud()
	match profile.arrangement:
		LayoutProfile.Arrangement.PORTRAIT:
			_layout_battle_portrait(profile)
		LayoutProfile.Arrangement.LANDSCAPE_COMPACT:
			_layout_battle_landscape(profile)
		_:
			_layout_battle_wide(profile)
	_layout_overlays(profile)
	# The walk between encounters returns the player to this x, so it has to be
	# re-read after anything moves them.
	_player_home_x = player_character.position.x
	# Rebuilt against the new panel width: the roster's labels wrap to an
	# explicit width and keep whatever one they were created with.
	if _enemy != null:
		_build_move_list()
		_fit_move_overlay(profile)
	_refresh_move_strip()
	TouchFeedback.apply_to_tree(self)

## Shrinks the compact roster overlay to the moves it actually holds. It has to
## happen after _build_move_list(), because until the entries exist the panel
## has no content to measure and would keep whatever height the layout guessed.
func _fit_move_overlay(profile: LayoutProfile) -> void:
	if profile.is_wide():
		return
	# A container recomputes its minimum on the next layout pass, not the moment
	# a child is added — asking now returns the size it was before the roster
	# went in. Same reason _warn_if_roster_overflows() waits a frame.
	await get_tree().process_frame
	if not is_instance_valid(side_panel):
		return
	var d := profile.design_size
	var needed: float = side_panel.get_combined_minimum_size().y
	var h: float = clampf(needed, 80.0, d.y * 0.55)
	side_panel.offset_bottom = side_panel.offset_top + h
	side_panel.size.y = h

## HUD section geometry for the current arrangement.
##
## The WIDE branch reproduces the authored 640-wide bar exactly — every value
## below evaluates to the constant it replaced when width is 640 — while
## anchoring the enemy's block to the real right edge so a wider bar keeps it
## against its own end instead of stranding it mid-screen.
func _hud_metrics(profile: LayoutProfile) -> Dictionary:
	var w := profile.design_size.x
	if profile.is_portrait():
		# A 320-unit bar cannot range seven sections across one line, so the
		# portrait bar is two decks: chapter and progress on top, the two
		# fighters facing each other below. The head portraits are dropped
		# rather than shrunk — both characters are on the stage a few units
		# further down, so the bar is not the only place you can see them.
		var half: float = w * 0.5
		return {
			"width": w, "height": 62.0,
			"show_pillars": false, "show_portraits": false,
			"show_chapter_ribbon": false,
			"left_portrait_x": 0.0, "right_portrait_x": 0.0,
			"left_info_x": 5.0,
			"right_info_x": half + 4.0, "right_info_r": w - 5.0,
			"info_w": half - 9.0, "ribbon_w": half - 9.0,
			"player_ribbon_top": 26.0, "enemy_ribbon_top": 26.0,
			"hearts_top": 43.0, "enemy_hearts_top": 43.0,
			"centre_x": 5.0, "centre_r": w - 96.0,
			"chapter_top": 3.0,
			"encounter_x": w - 92.0, "encounter_r": w - 5.0,
			"encounter_top": 6.0,
		}
	return {
		"width": w, "height": HUD_HEIGHT,
		"show_pillars": true, "show_portraits": true,
		"show_chapter_ribbon": true,
		"left_portrait_x": HUD_LEFT_PORTRAIT_X,
		"right_portrait_x": w - HUD_RIGHT_PORTRAIT_INSET,
		"left_info_x": HUD_LEFT_INFO_X,
		"right_info_x": w - HUD_RIGHT_INFO_INSET,
		"right_info_r": w - HUD_RIGHT_INFO_R_INSET,
		"info_w": 150.0, "ribbon_w": 94.0,
		"player_ribbon_top": 9.0, "enemy_ribbon_top": 4.0,
		"hearts_top": 27.0, "enemy_hearts_top": 32.0,
		"pillar_a_x": HUD_PILLAR_A_X, "pillar_b_x": w - HUD_PILLAR_B_INSET,
		"centre_x": HUD_PILLAR_A_X + 16.0,
		"centre_r": w - HUD_PILLAR_B_INSET - 4.0,
		"chapter_top": 24.0,
		"encounter_x": w - HUD_RIGHT_INFO_INSET,
		"encounter_r": w - HUD_RIGHT_INFO_R_INSET,
		"encounter_top": 20.0,
	}

## The authored composition, centred. Every offset is the scene's own plus an
## inset that is zero at 640 wide, so a 4:3 window is untouched and a wider one
## simply reveals more background either side of the same arrangement.
func _layout_battle_wide(profile: LayoutProfile) -> void:
	var inset: float = maxf((profile.design_size.x - 640.0) * 0.5, 0.0)
	board.set_tile_size(36.0, 3.0)
	_show_compact_chrome(false)
	shuffle_button.text = "New Question"
	shuffle_button.add_theme_font_size_override("font_size", 12)
	potion_row.add_theme_constant_override("separation", 4)
	for potion in [health_potion_button, power_potion_button, purify_potion_button]:
		potion.custom_minimum_size = Vector2(60.0, 32.0)
		potion.expand_icon = false
		potion.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		potion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		potion.add_theme_font_size_override("font_size", 10)
	_place_node(potion_panel, Rect2(inset + 10.0, 55.0, 208.0, 83.0))
	_place_node(question_panel, Rect2(inset + 220.0, 54.0, 259.0, 84.0))
	_place_node(side_panel, Rect2(inset + 480.0, 55.0, 150.0, 81.0))
	_place_node(player_character, Rect2(inset + 37.0, 258.0, 130.0, 180.0))
	_place_node(enemy_character, Rect2(inset + 478.0, 265.0, 130.0, 180.0))
	_place_node(word_tray, Rect2(inset, 143.0, 640.0, 32.0))
	_place_node(word_preview_label, Rect2(inset - 5.0, 416.0, 640.0, 36.0))
	_place_board(inset + 205.0, 187.0)
	_place_node(console_bar, Rect2(inset + 120.0, 454.0, 400.0, 26.0))
	_place_node(shuffle_button, Rect2(inset + 135.0, 457.0, 110.0, 20.0))
	_place_node(attack_button, Rect2(inset + 260.0, 457.0, 110.0, 20.0))
	_place_node(menu_button, Rect2(inset + 385.0, 457.0, 110.0, 20.0))

## Everything stacked down a narrow, tall canvas.
##
## Laid out from both ends inward — HUD, move strip and question from the top;
## controls, board and word tray from the bottom — with the character stage
## taking whatever is left in the middle. That ordering is deliberate: the
## board and the controls are what the player touches, so they claim their space
## first and the stage absorbs the variation between a 692-unit phone and a
## 568-unit one.
func _layout_battle_portrait(profile: LayoutProfile) -> void:
	var d := profile.design_size
	var margin: float = maxf(d.x * 0.04, 10.0)
	var w: float = d.x - margin * 2.0
	var gap := 5.0
	_show_compact_chrome(true)

	# --- from the top
	var y: float = _hud["height"] + gap
	_place_node(_move_strip, Rect2(margin, y, w, 24.0))
	y += 24.0 + gap
	var question_h: float = clampf(d.y * 0.10, 58.0, 78.0)
	_place_node(question_panel, Rect2(margin, y, w, question_h))
	var content_top: float = y + question_h + gap

	# --- from the bottom
	var controls_h: float = TOUCH_TARGET + 8.0
	var controls_y: float = d.y - margin * 0.7 - controls_h
	_layout_compact_controls(Rect2(margin, controls_y, w, controls_h), true)

	var tray_h := 30.0
	var available: float = controls_y - gap - content_top - tray_h - gap * 2.0
	var board_side: float = _fit_board(minf(w, available - PORTRAIT_STAGE_MIN))
	var board_y: float = controls_y - gap - board_side
	var tray_y: float = board_y - gap - tray_h
	_place_board((d.x - board_side) * 0.5, board_y)
	_place_node(word_tray, Rect2(0.0, tray_y, d.x, tray_h))

	# --- the middle
	var stage := Rect2(0.0, content_top, d.x, maxf(tray_y - gap - content_top, 60.0))
	_place_stage(stage, 0.9)
	# The preview reads out the word being spelled; on a stacked layout it sits
	# under the tray it describes rather than under the board.
	_place_node(word_preview_label, Rect2(margin, tray_y - 2.0, w, tray_h))
	word_preview_label.visible = false

## Two columns: the board owns the right, everything else stacks down the left.
## A rotated phone gives about 270 units of height, which is not enough to stack
## a question, a stage, a board and a control row on top of each other.
func _layout_battle_landscape(profile: LayoutProfile) -> void:
	var d := profile.design_size
	var margin := 8.0
	var gap := 4.0
	_show_compact_chrome(true)

	var top: float = _hud["height"] + gap
	var strip_h := 20.0

	# Right column: the board, with the move strip tucked under it. The strip
	# goes here rather than over the left column because every unit of height
	# on that side is already spoken for, and the stage is the thing that
	# suffers if it loses any more.
	var board_side: float = _fit_board(minf(
		d.y - top - margin - strip_h - gap, d.x * 0.36))
	var board_x: float = d.x - margin - board_side
	_place_board(board_x, top)
	_place_node(_move_strip, Rect2(board_x, top + board_side + gap,
		board_side, strip_h))

	# Left column, top down: question, then the word being spelled, then the
	# fighters, with the controls pinned to the bottom.
	var col_w: float = board_x - margin * 2.0
	var y: float = top
	_place_node(question_panel, Rect2(margin, y, col_w, 46.0))
	y += 46.0 + gap
	var tray_h := 22.0
	_place_node(word_tray, Rect2(margin, y, col_w, tray_h))
	_place_node(word_preview_label, Rect2(margin, y, col_w, tray_h))
	word_preview_label.visible = false
	y += tray_h + gap

	var controls_h := 34.0
	var controls_y: float = d.y - margin - controls_h
	_layout_compact_controls(Rect2(margin, controls_y, col_w, controls_h), false)

	_place_stage(Rect2(margin, y, col_w, maxf(controls_y - gap - y, 50.0)), 0.95)

## Stands the two fighters in `area`, facing each other, sized to a share of its
## height and pushed out to its edges.
##
## The gap between them is what melee attacks travel across, and every distance
## in the combat code is derived from these two nodes' live rects — so sizing
## them correctly here is the whole of what requirement 8 needs. Nothing in the
## attack choreography has a hardcoded reach.
func _place_stage(area: Rect2, height_share: float) -> void:
	var h: float = clampf(area.size.y * height_share, 84.0, 180.0)
	var w: float = h * 0.72
	var floor_y: float = area.end.y
	_place_node(player_character, Rect2(area.position.x + 4.0, floor_y - h, w, h))
	_place_node(enemy_character, Rect2(area.end.x - 4.0 - w, floor_y - h, w, h))
	# The backdrop follows the fighters rather than the other way round, so
	# whatever height the stage ended up with, they are standing on its floor.
	_place_battle_background(Layout.profile.design_size, floor_y)

## Places the backdrop so its painted floor lands under the fighters.
##
## The node was anchored full-rect with KEEP_ASPECT_COVERED, which is correct at
## 4:3 and wrong everywhere else: on a phone the stage is a band in the middle of
## the screen, and a centred cover-crop puts the floor a long way below it, so
## the pair stand in mid-air against a window.
##
## Scaling to cover the band from the top of the screen down to the stage floor
## — rather than the whole screen — puts the floor exactly where it is needed.
## At 640x480 this evaluates to the same 720x480 crop the anchored version
## produced, so the desktop backdrop is untouched.
func _place_battle_background(d: Vector2, stage_floor: float) -> void:
	if background.texture == null:
		return
	var ts := background.texture.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var s: float = maxf(d.x / ts.x, stage_floor / BATTLE_GROUND_FRACTION / ts.y)
	var drawn := ts * s
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 0.0
	background.anchor_bottom = 0.0
	_place_node(background, Rect2((d.x - drawn.x) * 0.5,
		stage_floor - drawn.y * BATTLE_GROUND_FRACTION, drawn.x, drawn.y))

## Largest tile pitch that fits `budget`, snapped so the six columns come out to
## a whole number of units. Clamped at both ends: never so small a finger cannot
## land on one, never so large the art looks blown up.
func _fit_board(budget: float) -> float:
	var gap := 3.0
	var tile: float = floorf((maxf(budget, 120.0) - gap * 5.0) / 6.0)
	tile = clampf(tile, 26.0, 48.0)
	board.set_tile_size(tile, gap)
	return board.board_side()

func _place_board(x: float, y: float) -> void:
	var side: float = board.board_side()
	_place_node(board, Rect2(x, y, side, side))
	_place_node(board_frame, Rect2(x - 6.0, y - 6.0, side + 12.0, side + 12.0))

## The bottom bar for compact layouts: three potions, then reroll, attack and
## menu. Potions move down here rather than keeping the desktop's separate panel
## because a phone cannot spare a whole row for three buttons that are used
## once a fight.
func _layout_compact_controls(area: Rect2, tall: bool) -> void:
	_place_node(console_bar, area)
	# The three potions go in as their whole PANEL, not as three loose buttons.
	# They live inside PotionPanel/VBox/Row, and a container lays its children
	# out itself — placing them individually sets offsets the HBoxContainer
	# overwrites on the next sort, which is why they piled up in one corner.
	# Moving the panel and letting its own row do the spacing works with the
	# scene rather than against it.
	# ConsoleBar sits later in the scene tree than PotionPanel, so it paints over
	# it -- invisible at 640x480 where the two never overlap, fatal here where
	# the panel is being moved onto the bar. Lifting the panel above it is safe
	# on every layout, since on WIDE they are 400 units apart.
	if potion_panel.get_index() < console_bar.get_index():
		move_child(potion_panel, console_bar.get_index())
	# Shrink the potions BEFORE the panel around them is placed. A Control's
	# size is clamped up to its combined minimum at the moment it is assigned,
	# so placing the panel first and slimming its contents afterwards leaves it
	# stuck at the old minimum -- 3x60 + 2x4 + 14 = 202 units of it, straight
	# across New Q and Attack.
	potion_title.visible = false
	potion_row.add_theme_constant_override("separation", 2)
	for potion in [health_potion_button, power_potion_button, purify_potion_button]:
		# Clearing the minimum is not enough on its own: the bottle icon carries
		# its own, which is what expand_icon lifts.
		potion.custom_minimum_size = Vector2(22.0, 0.0)
		potion.expand_icon = true
		potion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Fill the bar's height too, or three 16-unit-tall chips sit centred in a
		# 46-unit bar and are the smallest touch targets on the screen.
		potion.size_flags_vertical = Control.SIZE_EXPAND_FILL
		potion.add_theme_font_size_override("font_size", 8)

	var slots: Array[Control] = [potion_panel, shuffle_button, attack_button, menu_button]
	# Attack is the primary action and gets the widest slot of the three
	# buttons. Weights, not pixels, so the same split works at 296 units and at
	# 560.
	var weights := [0.36, 0.19, 0.26, 0.19]
	var pad := 3.0
	var inner: float = area.size.x - pad * 2.0
	var x: float = area.position.x + pad
	var h: float = area.size.y - pad * 2.0
	for i in slots.size():
		var slot: float = inner * weights[i]
		_place_node(slots[i], Rect2(x + 1.0, area.position.y + pad, slot - 2.0, h))
		if slots[i] is Button:
			(slots[i] as Button).custom_minimum_size = Vector2.ZERO
			(slots[i] as Button).add_theme_font_size_override("font_size", 12 if tall else 10)
		x += slot

	# "New Question" does not fit a fifth of a phone's width at any legible size.
	shuffle_button.text = "New Q"

## Panels that only exist on one arrangement or the other.
func _show_compact_chrome(compact: bool) -> void:
	_move_strip.visible = compact
	# potion_panel is NOT hidden on compact -- it moves into the bottom bar,
	# carrying its three buttons with it. Only its heading goes.
	potion_title.visible = not compact
	# On compact layouts the roster is opened from the strip instead of living
	# on screen permanently; on WIDE it is always up.
	side_panel.visible = not compact
	_moves_open = false

func _layout_overlays(profile: LayoutProfile) -> void:
	var d := profile.design_size
	var margin: float = maxf(d.x * 0.04, 10.0)
	_centre_battle_panel(encounter_banner, Vector2(340.0, 70.0), d, margin)
	_centre_battle_panel(result_overlay, Vector2(300.0, 120.0), d, margin)
	_centre_battle_panel(pause_main_panel, PAUSE_PANEL_RECT.size, d, margin)
	_centre_battle_panel(pause_options_panel, PAUSE_PANEL_RECT.size, d, margin)
	pause_options_panel.pivot_offset = pause_options_panel.size * 0.5
	# The compact roster overlay, when the player opens it from the strip.
	if not profile.is_wide():
		var panel_w: float = minf(320.0, d.x - margin * 2.0)
		_place_node(side_panel, Rect2((d.x - panel_w) * 0.5, _hud["height"] + 34.0,
			panel_w, minf(220.0, d.y * 0.5)))
	if profile.is_touch:
		for button in [try_again_button, resume_button, pause_options_button, title_button]:
			button.custom_minimum_size.y = TOUCH_TARGET

func _centre_battle_panel(panel: Control, preferred: Vector2, d: Vector2,
		margin: float) -> void:
	if panel == null:
		return
	var w: float = minf(preferred.x, d.x - margin * 2.0)
	var h: float = minf(preferred.y, d.y - margin * 2.0)
	_place_node(panel, Rect2((d.x - w) * 0.5, (d.y - h) * 0.5, w, h))

func _place_node(node: Control, rect: Rect2) -> void:
	if node == null:
		return
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y
	node.size = rect.size

## The compact stand-in for the MOVES roster: one tappable strip naming the move
## that is about to land, which opens the full descriptions when pressed.
##
## Requirement was to keep telegraphing the incoming move without spending a
## permanent panel on it — so the strip carries the one fact that matters every
## turn, and the detail stays one tap away.
func _build_move_strip() -> void:
	# Behind everything, including the backdrop art. On compact layouts the
	# artwork is scaled to the stage band rather than the whole screen, so the
	# strips above and below it need something to sit on other than the void.
	var floorfill := ColorRect.new()
	floorfill.name = "Backdrop"
	floorfill.color = Color(0.10, 0.07, 0.05)
	floorfill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floorfill.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(floorfill)
	move_child(floorfill, 0)

	_move_strip = Button.new()
	_move_strip.name = "MoveStrip"
	_move_strip.add_theme_font_size_override("font_size", 11)
	_move_strip.add_theme_color_override("font_color", MOVE_ACTIVE_NAME_COLOR)
	_move_strip.clip_text = true
	_move_strip.pressed.connect(_on_move_strip_pressed)
	_move_strip.hide()
	add_child(_move_strip)

func _on_move_strip_pressed() -> void:
	Audio.play_sfx("button_click")
	_moves_open = not _moves_open
	side_panel.visible = _moves_open
	# Same z-order trap as the potion panel: as an overlay it has to be drawn
	# after the board it now covers, not before it.
	if _moves_open:
		move_child(side_panel, get_child_count() - 1)

func _refresh_move_strip() -> void:
	# _enemy is still null during the first layout pass, which runs before the
	# opening encounter is staged.
	if _move_strip == null or not _move_strip.visible or _enemy == null:
		return
	var move := _current_move()
	if move == null:
		_move_strip.text = "MOVES"
		return
	_move_strip.text = "NEXT:  %s      ▸" % move.move_name.to_upper()

func _on_attack_pressed() -> void:
	Audio.play_sfx("button_click")
	board.submit_word()

func _on_shuffle_pressed() -> void:
	Audio.play_sfx("shuffle")
	_shuffle_and_counterattack()

## Rerolls the whole question, not just the board's layout: the prompt, the
## answer and the letters all change together, which is what a player pressing
## this button is actually asking for.
##
## It still costs the turn, same as Bookworm's reshuffle — the rival gets a
## free hit. Without that price a stuck player would simply reroll until an
## easy question came up, and the clock would stop meaning anything.
func _shuffle_and_counterattack() -> void:
	_sequence_running = true
	_update_action_buttons()
	var replaced := String(_question.get("answer", ""))
	_present_question(replaced)
	# Keeps the mud-spawn cost shuffling has always carried; the reseed it does
	# on top is harmless, since the new answer stays spellable either way.
	board.shuffle_board()
	_flash_question_panel()
	await get_tree().create_timer(BEAT_PAUSE).timeout
	await _resolve_enemy_turn()
	if _player_hp <= 0:
		_sequence_running = false
		_update_action_buttons()
		_end_match(false)
		return
	# A fresh board earns a fresh window to search it — shuffling shouldn't
	# cost time on top of the guaranteed hit it already costs.
	_time_left = _question_time
	_update_timer_ui()
	_sequence_running = false
	_update_action_buttons()

## A quick lift on the question panel so the swap is unmistakable — without it
## a reroll that happens to produce a similar-length prompt can look like
## nothing happened at all.
func _flash_question_panel() -> void:
	question_panel.modulate = Color(1.55, 1.45, 1.15)
	var tween := create_tween()
	tween.tween_property(question_panel, "modulate", Color.WHITE, 0.4) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## Where both pages of the pause menu sit. Matches PauseMainPanel's own rect
## in word_battle.tscn so switching pages does not move the box.
const PAUSE_PANEL_RECT := Rect2(195.0, 135.0, 250.0, 190.0)

func _on_menu_pressed() -> void:
	Audio.play_sfx("button_click")
	_open_pause_menu()

## Actually pauses the scene tree, not just shows an overlay — the question
## countdown lives in _process, which the pause automatically freezes, so
## nothing needs to remember or restore how much time was left. The overlay
## itself is process_mode=WHEN_PAUSED (set in the scene) so its own buttons
## keep working while everything else is frozen.
func _open_pause_menu() -> void:
	pause_main_panel.show()
	pause_options_panel.hide()
	pause_overlay.show()
	get_tree().paused = true

func _on_resume_pressed() -> void:
	Audio.play_sfx("button_click")
	get_tree().paused = false
	pause_overlay.hide()

## Builds the in-battle settings panel. Centred on the same rect the pause
## menu's own page uses, so the two pages of the pause menu sit in one place
## rather than jumping as the player moves between them.
func _build_pause_options() -> void:
	pause_options_panel = SettingsPanel.new()
	pause_options_panel.name = "PauseOptionsPanel"
	pause_options_panel.offset_left = PAUSE_PANEL_RECT.position.x
	pause_options_panel.offset_top = PAUSE_PANEL_RECT.position.y
	pause_options_panel.offset_right = PAUSE_PANEL_RECT.position.x + PAUSE_PANEL_RECT.size.x
	pause_options_panel.offset_bottom = PAUSE_PANEL_RECT.position.y + PAUSE_PANEL_RECT.size.y
	pause_options_panel.size = PAUSE_PANEL_RECT.size
	# The overlay runs WHEN_PAUSED so its controls stay live while the tree is
	# frozen; a child added in code has to be told the same, or the sliders go
	# dead the moment the game is actually paused.
	pause_options_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_overlay.add_child(pause_options_panel)
	pause_options_panel.build(_on_pause_options_back_pressed)
	pause_options_panel.hide()

func _on_pause_options_pressed() -> void:
	Audio.play_sfx("button_click")
	pause_main_panel.hide()
	pause_options_panel.pop_open()

func _on_pause_options_back_pressed() -> void:
	Audio.play_sfx("button_click")
	pause_options_panel.hide()
	pause_main_panel.show()


## Must unpause before changing scenes — a scene loaded while the tree is
## still paused would arrive frozen, with nothing on it able to process.
func _on_title_pressed() -> void:
	Audio.play_sfx("button_click")
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

## Try Again always restarts the chapter from encounter one — _end_match has
## already rewound GameState by this point.
func _on_try_again_pressed() -> void:
	Audio.play_sfx("button_click")
	_start_encounter(true)
	Audio.play_music("battle")

## Sets up whichever encounter GameState currently points at. `full_reset`
## separates starting a chapter (fresh health bar) from walking into the next
## encounter of one already in progress (health carries, partly refunded).
func _start_encounter(full_reset: bool) -> void:
	result_overlay.hide()
	_enemy = GameState.current_enemy()
	if _enemy == null:
		push_warning("WordBattleController: no encounter at index %d" % GameState.encounter_index)
		return
	enemy_character.configure_from(_enemy)
	# Swapped here rather than in the transition because _start_encounter is the
	# one path every encounter goes through — walking in, Try Again, or booting
	# this scene directly all land on the right backdrop.
	if _enemy.background != null:
		background.texture = _enemy.background

	_enemy_hp = _enemy.max_hp
	if full_reset:
		_player_hp = GameState.player_max_hp
	else:
		var refund := roundi(GameState.player_max_hp * BETWEEN_ENCOUNTER_HEAL_FRACTION)
		_player_hp = mini(GameState.player_max_hp, _player_hp + refund)

	enemy_name_label.text = _enemy.enemy_name
	_refresh_encounter_hud()
	_move_index = 0
	_build_move_list()
	enemy_heart_row.set_max(_enemy.max_hp)
	enemy_heart_row.set_value(_enemy_hp, false)
	player_heart_row.set_max(GameState.player_max_hp)
	player_heart_row.set_value(_player_hp, false)
	word_preview_label.text = ""
	_pending_enemy_damage = 0
	_sequence_running = false
	_match_over = false
	_current_selection = ""
	_power_up_active = false
	_set_tray_word("")
	_present_question()
	_update_action_buttons()

## Pulls the next question, lays its answer out on the board, and restarts the
## countdown. The board guarantees the answer stays spellable from here on.
## `avoid_answer` guarantees the next question differs from the one it
## replaces. The bank walks a shuffled lap so consecutive pulls almost always
## differ anyway — but "almost always" is not good enough for a button whose
## whole purpose is to hand you a different question, and a lap boundary can
## legitimately repeat.
func _present_question(avoid_answer: String = "") -> void:
	_question = QuestionBank.next_question()
	if not avoid_answer.is_empty() and QuestionBank.question_count() > 1:
		var guard := 0
		while not _question.is_empty() 				and String(_question.get("answer", "")) == avoid_answer 				and guard < 8:
			_question = QuestionBank.next_question()
			guard += 1
	if _question.is_empty():
		question_label.text = "No questions loaded — spell any word to attack."
		board.set_required_answer("")
		_time_left = 0.0
		timer_bar.value = 0.0
		return
	question_label.text = _format_prompt(_question)
	board.set_required_answer(_question["answer"])
	_time_left = _question_time
	_update_timer_ui()

## Dresses every panel in the carved-wood-and-gold 9-slice, and the timer in a
## sunken track with a beveled fill.
func _apply_panel_chrome() -> void:
	var panel_box := _nine_slice(PANEL_TEXTURE, PANEL_SLICE, PANEL_CONTENT)
	for panel: Control in [
		potion_panel, question_panel, side_panel,
		encounter_banner, result_overlay, pause_main_panel, pause_options_panel,
	]:
		if panel != null:
			panel.add_theme_stylebox_override("panel", panel_box)

	timer_bar.add_theme_stylebox_override(
		"background", _nine_slice(BAR_TRACK_TEXTURE, BAR_SLICE, 1.0))
	# Kept on hand: the countdown tints this one, and tinting the stylebox is
	# what leaves the track behind it dark instead of colouring the whole bar.
	_timer_fill_style = _nine_slice(BAR_FILL_TEXTURE, BAR_SLICE, 1.0)
	timer_bar.add_theme_stylebox_override("fill", _timer_fill_style)

# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------

## Rebuilds the header as one carved-wood bar holding three framed sections
## divided by brass pillars: the player on the left, chapter context in the
## middle, the rival on the right. Each fighter gets a portrait, a ribbon
## nameplate and a recessed tray of hearts, so nothing floats loose — every
## piece of information sits inside the section that owns it.
##
## Built in code rather than added to word_battle.tscn because the editor
## silently overwrites scene-file edits when it has that scene open, which is
## the same reason _apply_panel_chrome() exists.
func _build_hud() -> void:
	# chapter_banner.png is 400x56 stretched across 640 — that smear is what
	# drew the three unrecognisable brown slabs behind the old header. The bar
	# built here replaces it outright, along with the flat scrim and the loose
	# badge that used to sit on top of it.
	chapter_banner.hide()
	header_bar.hide()
	chapter_badge.hide()
	_teardown_hud()

	var bar := Panel.new()
	bar.name = "HudBar"
	bar.offset_right = _hud["width"]
	bar.offset_bottom = _hud["height"]
	bar.add_theme_stylebox_override("panel", _nine_slice(HUD_BAR_TEX, HUD_BAR_SLICE, 0.0))
	add_child(bar)
	move_child(bar, top_bar.get_index())

	_build_hud_player_section()
	_build_hud_centre_section()
	_build_hud_enemy_section()

	# The dividers go on last so they sit over the section edges rather than
	# being clipped by them. A portrait bar stacks its sections instead of
	# ranging them across one line, so there is nothing for them to divide.
	if _hud["show_pillars"]:
		for i in [0, 1]:
			var x: float = _hud["pillar_a_x"] if i == 0 else _hud["pillar_b_x"]
			var pillar := TextureRect.new()
			pillar.name = "HudPillar%d" % i
			pillar.texture = HUD_PILLAR_TEX
			pillar.offset_left = x
			pillar.offset_right = x + HUD_PILLAR_W
			pillar.offset_top = HUD_INNER_TOP
			pillar.offset_bottom = _hud["height"] - HUD_BAR_SLICE
			pillar.stretch_mode = TextureRect.STRETCH_SCALE
			top_bar.add_child(pillar)

## Returns the HUD to a blank slate so _build_hud() can run again.
##
## It could not, before: the original freed PlayerPanel and EnemyPanel outright
## once it had harvested their labels and heart rows, which is fine exactly once
## and fatal the second time. Nothing ever asked for a second time, because
## nothing ever re-laid-out — until a phone could be rotated mid-battle.
##
## The order matters. The scene's own nodes are rescued from whatever code-made
## container currently holds them FIRST; only then is that container freed, or
## they would go down with it. free() rather than queue_free() because the
## rebuild happens in this same frame and would otherwise collide with the
## still-living nodes it is replacing by name.
func _teardown_hud() -> void:
	for salvaged in [chapter_label, encounter_label, player_name_label,
			enemy_name_label, player_heart_row, enemy_heart_row]:
		if is_instance_valid(salvaged) and salvaged.get_parent() != null:
			salvaged.get_parent().remove_child(salvaged)
	var bar := get_node_or_null("HudBar")
	if bar != null:
		bar.free()
	for child in top_bar.get_children():
		child.free()

func _build_hud_player_section() -> void:
	if _hud["show_portraits"]:
		_hud_player_portrait = _add_portrait("PlayerPortrait", _hud["left_portrait_x"])
	else:
		_hud_player_portrait = null
	var left: float = _hud["left_info_x"]
	_add_ribbon("PlayerRibbon", player_name_label, left, left + _hud["ribbon_w"],
		_hud["player_ribbon_top"])
	player_name_label.text = "YOU"
	_add_heart_slot(
		"PlayerHeartSlot", player_heart_row, left, left + _hud["info_w"],
		_hud["hearts_top"], false)

func _build_hud_centre_section() -> void:
	# The chapter number gets the ribbon and the chapter's name sits below it
	# in the open: number as the label, name as the thing you actually read.
	_hud_chapter_ribbon_label = Label.new()
	_hud_chapter_ribbon_label.name = "ChapterRibbonLabel"
	var centre: float = (_hud["centre_x"] + _hud["centre_r"]) * 0.5
	if _hud["show_chapter_ribbon"]:
		_add_ribbon("ChapterRibbon", _hud_chapter_ribbon_label,
			centre - 62.0, centre + 62.0, 6.0)

	# The chapter name is the one piece of HUD text that is a heading rather
	# than a stat, so it gets a light parchment ground and dark ink — the
	# inverse of everything around it. Dark-on-dark with an outline, which is
	# what it looked like before the plate went in, just read as muddy.
	var plate := PanelContainer.new()
	plate.name = "ChapterPlate"
	plate.offset_left = _hud["centre_x"] + 4.0
	plate.offset_right = _hud["centre_r"] - 4.0
	plate.offset_top = _hud["chapter_top"]
	plate.offset_bottom = _hud["chapter_top"] + 22.0
	plate.add_theme_stylebox_override("panel", _nine_slice(HUD_PARCHMENT_TEX, 6.0, 2.0))
	top_bar.add_child(plate)

	# Moved under TopBar, which is drawn after the bar: left where the scene put
	# it (index 3, below the bar at index 5) the new backdrop painted straight
	# over the chapter name.
	if chapter_label.get_parent() != null:
		chapter_label.get_parent().remove_child(chapter_label)
	plate.add_child(chapter_label)
	chapter_label.show()
	chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chapter_label.add_theme_font_override("font", HUD_TITLE_FONT)
	chapter_label.add_theme_font_size_override("font_size", 12)
	chapter_label.add_theme_color_override("font_color", Color(0.20, 0.12, 0.05))
	chapter_label.add_theme_constant_override("outline_size", 0)
	# Long chapter names trim rather than spill past the pillars.
	chapter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	chapter_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	chapter_label.clip_text = true

func _build_hud_enemy_section() -> void:
	if _hud["show_portraits"]:
		_hud_enemy_portrait = _add_portrait("EnemyPortrait", _hud["right_portrait_x"])
	else:
		_hud_enemy_portrait = null
	var right_x: float = _hud["right_info_x"]
	var right_r: float = _hud["right_info_r"]
	_add_ribbon("EnemyRibbon", enemy_name_label, right_x, right_r, _hud["enemy_ribbon_top"])

	# Encounter count and difficulty share a line but stay visibly separate —
	# the old header ran them together as one grey "Encounter · 1/5 · EASY".
	var row := HBoxContainer.new()
	row.name = "EncounterRow"
	row.offset_left = _hud["encounter_x"]
	row.offset_right = _hud["encounter_r"]
	row.offset_top = _hud["encounter_top"]
	row.offset_bottom = _hud["encounter_top"] + 11.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	top_bar.add_child(row)

	if encounter_label.get_parent() != null:
		encounter_label.get_parent().remove_child(encounter_label)
	encounter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	encounter_label.add_theme_font_size_override("font_size", 9)
	encounter_label.add_theme_color_override("font_color", HUD_CREAM)
	row.add_child(encounter_label)

	_difficulty_chip = PanelContainer.new()
	_difficulty_chip.name = "DifficultyChip"
	_difficulty_label = Label.new()
	_difficulty_label.add_theme_font_size_override("font_size", 8)
	_difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_difficulty_chip.add_child(_difficulty_label)
	row.add_child(_difficulty_chip)

	_add_heart_slot(
		"EnemyHeartSlot", enemy_heart_row, right_r - _hud["info_w"],
		right_r, _hud["enemy_hearts_top"], true)

## A gold-framed head crop. Returns the inner TextureRect so the caller can
## swap which character it shows.
func _add_portrait(node_name: String, left: float) -> TextureRect:
	var frame := PanelContainer.new()
	frame.name = node_name
	frame.offset_left = left
	frame.offset_right = left + HUD_PORTRAIT
	frame.offset_top = 7.0
	frame.offset_bottom = 7.0 + HUD_PORTRAIT
	frame.add_theme_stylebox_override("panel", _nine_slice(HUD_FRAME_TEX, 6.0, 4.0))
	top_bar.add_child(frame)

	var art := TextureRect.new()
	art.name = node_name + "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Without clipping, a head crop wider than the frame paints straight over
	# the gold border.
	art.clip_contents = true
	frame.add_child(art)
	return art

## Seats a label on a red ribbon nameplate.
func _add_ribbon(
		node_name: String, label: Label, left: float, right: float,
		top: float) -> PanelContainer:
	var ribbon := PanelContainer.new()
	ribbon.name = node_name
	ribbon.offset_left = left
	ribbon.offset_right = right
	ribbon.offset_top = top
	ribbon.offset_bottom = top + HUD_RIBBON_H
	ribbon.add_theme_stylebox_override("panel", _nine_slice(HUD_RIBBON_TEX, 5.0, 1.0))
	top_bar.add_child(ribbon)

	if label.get_parent() != null:
		label.get_parent().remove_child(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", HUD_TITLE_FONT)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", HUD_CREAM)
	# Names longer than the plate trim rather than escaping it — "Kapitan
	# Komisyon" is already close to the limit.
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	ribbon.add_child(label)
	return ribbon

## A sunken tray holding the heart row and its exact-numbers readout, mirrored
## for the enemy so each fighter's hearts sit nearest their own portrait.
func _add_heart_slot(
		node_name: String, heart_row: HeartRow, left: float, right: float,
		top: float, mirrored: bool) -> void:
	var slot := PanelContainer.new()
	slot.name = node_name
	slot.offset_left = left
	slot.offset_right = right
	slot.offset_top = top
	slot.offset_bottom = top + HUD_SLOT_H
	slot.add_theme_stylebox_override("panel", _nine_slice(HUD_SLOT_TEX, 6.0, 2.0))
	top_bar.add_child(slot)

	var row := HBoxContainer.new()
	row.name = "SlotRow"
	row.add_theme_constant_override("separation", 5)
	slot.add_child(row)

	var hp := Label.new()
	hp.name = "HpReadout"
	hp.add_theme_font_size_override("font_size", 8)
	hp.add_theme_color_override("font_color", HUD_MUTED)
	hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if mirrored else HORIZONTAL_ALIGNMENT_RIGHT)

	if heart_row.get_parent() != null:
		heart_row.get_parent().remove_child(heart_row)
	heart_row.fixed_heart_count = HUD_HEART_COUNT
	heart_row.max_row_width = HUD_HEART_COUNT * (HUD_HEART + 3.0)
	heart_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart_row.alignment = (
		BoxContainer.ALIGNMENT_END if mirrored else BoxContainer.ALIGNMENT_BEGIN)

	if mirrored:
		row.add_child(hp)
		row.add_child(heart_row)
	else:
		row.add_child(heart_row)
		row.add_child(hp)
	heart_row.readout = hp

## A head-and-shoulders crop of a character's idle frame, for a HUD portrait.
##
## There are no portrait assets — every character is one 100x180 full-body
## sprite — so the head is taken as a square off the top of the sprite's own
## opaque bounding box. Reading that box from the alpha rather than assuming
## fixed pixel offsets means a character whose art sits higher, lower or wider
## in its canvas still frames correctly.
func _portrait_texture(idle_dir: String) -> Texture2D:
	if idle_dir.is_empty():
		return null
	var source := load("%s/frame_0.png" % idle_dir) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return null
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	# Roughly the top third of the figure: head and shoulders, no torso.
	var side := clampi(int(used.size.y * 0.34), 8, mini(image.get_width(), image.get_height()))
	var centre_x := used.position.x + int(used.size.x * 0.5)
	var left := clampi(centre_x - side / 2, 0, maxi(0, image.get_width() - side))
	var top := clampi(used.position.y - 1, 0, maxi(0, image.get_height() - side))
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = Rect2(left, top, side, side)
	return atlas

## Repaints the parts of the HUD that change per encounter. Called from
## _start_encounter rather than only at startup, because walking to the next
## fight swaps the enemy without reloading the scene.
func _refresh_encounter_hud() -> void:
	var chapter_title := GameState.chapter.chapter_name if GameState.chapter != null else ""
	_hud_chapter_ribbon_label.text = "CHAPTER %d" % GameState.chapter_number()
	# Was fixed text in the scene reading "CHAPTER 1 — LORD TRAPO, THE DYNASTY
	# HEIR", which stayed put through every later encounter and so was wrong
	# for four fights out of five. The rival has its own nameplate now.
	chapter_label.text = chapter_title.to_upper()

	if _hud_player_portrait != null:
		_hud_player_portrait.texture = _portrait_texture(
			String(GameState.character_clips().get("idle_dir", "")))
	if _hud_enemy_portrait != null:
		_hud_enemy_portrait.texture = _portrait_texture(_enemy.idle_dir)

	var total := GameState.encounter_total()
	var current := GameState.encounter_number()
	encounter_label.text = "BOSS FIGHT" if _enemy.is_boss else "Encounter %d / %d" % [current, total]
	encounter_label.add_theme_color_override(
		"font_color", HUD_GOLD if _enemy.is_boss else HUD_CREAM)

	var tier := GameState.difficulty.to_lower()
	var tier_color: Color = HUD_DIFFICULTY_COLORS.get(tier, HUD_MUTED)
	_difficulty_label.text = tier.to_upper()
	_difficulty_label.add_theme_color_override("font_color", Color(0.11, 0.09, 0.05))
	var chip := StyleBoxFlat.new()
	chip.bg_color = tier_color
	chip.set_border_width_all(1)
	chip.border_color = Color(tier_color.r * 0.55, tier_color.g * 0.55, tier_color.b * 0.55)
	chip.set_corner_radius_all(2)
	chip.content_margin_left = 4
	chip.content_margin_right = 4
	chip.content_margin_top = 0
	chip.content_margin_bottom = 0
	_difficulty_chip.add_theme_stylebox_override("panel", chip)

func _nine_slice(tex: Texture2D, slice: float, content: float) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex
	for side in ["left", "top", "right", "bottom"]:
		box.set("texture_margin_" + side, slice)
		box.set("content_margin_" + side, content)
	# Tile rather than stretch, so the grain keeps its pixel size on a wide
	# panel instead of smearing out.
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box

## Expands the prompt's "___" marker into the answer with some of its letters
## already filled in, e.g. "C _ U _ T". The gap shows how long the word is and
## the revealed letters narrow down which word it is — both sitting inside the
## sentence the player is already reading, which is why the separate hint line
## under the board is no longer needed.
func _format_prompt(question: Dictionary) -> String:
	var prompt := String(question.get("prompt", ""))
	if not prompt.contains(BLANK_TOKEN):
		return prompt
	var answer := String(question.get("answer", ""))
	var revealed := _revealed_indices(answer.length())
	var parts: PackedStringArray = []
	for i in answer.length():
		parts.append(answer[i] if revealed.has(i) else "_")
	return prompt.replace(BLANK_TOKEN, " ".join(parts))

## Which letter positions are given away, as a set. The first letter is always
## one of them — it is the single most useful clue — and the rest are spread
## evenly across the word rather than clustered, so the shape of the answer
## comes through instead of just its opening.
func _revealed_indices(length: int) -> Dictionary:
	var revealed := {}
	if length <= MIN_HIDDEN_LETTERS:
		return revealed
	var share: float = HINT_REVEAL_BY_DIFFICULTY.get(GameState.difficulty, DEFAULT_HINT_REVEAL)
	var count := clampi(ceili(length * share), 1, length - MIN_HIDDEN_LETTERS)
	if count == 1:
		revealed[0] = true
		return revealed
	# Spread `count` picks across the full width of the word, first to last.
	for i in count:
		revealed[roundi(float(i) * float(length - 1) / float(count - 1))] = true
	return revealed

func _update_timer_ui() -> void:
	timer_bar.max_value = _question_time
	timer_bar.value = _time_left
	# Green while there's room, amber as it tightens, red in the last breath.
	var fill := Color(0.35, 0.7, 0.3)
	if _time_left <= _question_time * 0.3:
		fill = Color(0.8, 0.2, 0.18)
	elif _time_left <= _question_time * 0.6:
		fill = Color(0.9, 0.7, 0.2)
	# Tint the fill stylebox rather than self_modulate, which would colour the
	# sunken track behind it too — the track is meant to stay dark wood whatever
	# the clock is doing. The bar's bevel and tick segments are drawn in
	# greyscale precisely so this tint reads cleanly over them.
	if _timer_fill_style != null:
		_timer_fill_style.modulate_color = fill

## The countdown only runs while the player actually has control — it pauses
## through attack animations so a slow flinch can't eat the clock.
func _process(delta: float) -> void:
	if _match_over or _sequence_running or _question.is_empty():
		return
	if _time_left <= 0.0:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_update_timer_ui()
	if _time_left <= 0.0:
		_handle_timeout()

## Ran out of time: the rival takes its shot, then a fresh question comes up.
func _handle_timeout() -> void:
	_sequence_running = true
	_update_action_buttons()
	word_preview_label.text = "Time's up! The answer was %s." % _question.get("answer", "")
	await get_tree().create_timer(BEAT_PAUSE).timeout
	await _resolve_enemy_turn()
	if _player_hp <= 0:
		_sequence_running = false
		_update_action_buttons()
		_end_match(false)
		return
	# Laying out the next question reseeds the board, which fires
	# selection_changed and resets the message line — so the rival's hit is
	# re-posted afterwards instead of vanishing the instant it lands.
	var hit_message := word_preview_label.text
	_present_question()
	word_preview_label.text = hit_message
	_sequence_running = false
	_update_action_buttons()

## Potions are a free action: drinking one never consumes your turn, so you
## can heal or clean the board and still attack in the same breath. Each one
## refuses to spend stock when it would do nothing, so a misclick at full
## health doesn't cost you a bottle.
func _use_health_potion() -> void:
	if _player_hp >= GameState.player_max_hp:
		word_preview_label.text = "Already at full health"
		return
	if not GameState.consume_potion(GameState.PotionType.HEALTH):
		return
	Audio.play_sfx("potion")
	_player_hp = mini(GameState.player_max_hp, _player_hp + HEALTH_POTION_HEAL)
	player_heart_row.set_value(_player_hp)
	word_preview_label.text = "Health Potion — +%d HP" % HEALTH_POTION_HEAL
	_refresh_potion_buttons()

func _use_power_potion() -> void:
	if _power_up_active:
		word_preview_label.text = "Power Up is already primed"
		return
	if not GameState.consume_potion(GameState.PotionType.POWER):
		return
	Audio.play_sfx("potion")
	_power_up_active = true
	word_preview_label.text = "Power Up — next word hits x%s" % POWER_UP_MULTIPLIER
	_refresh_potion_buttons()

func _use_purify_potion() -> void:
	if not board.has_contamination():
		word_preview_label.text = "Nothing on the board to purify"
		return
	if not GameState.consume_potion(GameState.PotionType.PURIFY):
		return
	Audio.play_sfx("potion")
	board.purify()
	word_preview_label.text = "Purify Potion — the board is clean"
	_refresh_potion_buttons()

func _refresh_potion_buttons() -> void:
	var health := GameState.potion_count(GameState.PotionType.HEALTH)
	var power := GameState.potion_count(GameState.PotionType.POWER)
	var purify := GameState.potion_count(GameState.PotionType.PURIFY)
	health_potion_button.text = "x%d" % health
	power_potion_button.text = "x%d" % power
	purify_potion_button.text = "x%d" % purify
	health_potion_button.disabled = _sequence_running or health <= 0
	power_potion_button.disabled = _sequence_running or power <= 0
	purify_potion_button.disabled = _sequence_running or purify <= 0

## Attack only lights up when the current selection is a word the board would
## actually accept — the same test submit_word runs — so the button state
## tracks validity live instead of failing after the press.
func _is_selection_submittable() -> bool:
	return board.is_submittable(_current_selection)

func _update_action_buttons() -> void:
	attack_button.disabled = _sequence_running or not _is_selection_submittable()
	shuffle_button.disabled = _sequence_running
	# Not gated on match-over: menu stays reachable from the result screen too.
	menu_button.disabled = _sequence_running
	_refresh_potion_buttons()

## Whichever move is telegraphed here is the one that lands at the end of
## the current exchange (_resolve_enemy_turn) — the panel always shows
## what's coming, not what already happened.
func _current_move() -> EnemyMove:
	if _enemy.moves.is_empty():
		return null
	return _enemy.moves[_move_index % _enemy.moves.size()]

## Builds the side panel as the full roster of everything this enemy can do,
## with the move it is about to use marked.
##
## Still a reference list rather than a rotating single card — the player can
## read every move a rival has up front — but no longer a purely static one:
## the entry for _current_move() is highlighted, so "what is about to hit me"
## is answerable without memorising the cycle order.
func _build_move_list() -> void:
	_stop_move_pulse()
	_move_entries.clear()
	for child in side_panel_vbox.get_children():
		side_panel_vbox.remove_child(child)
		child.queue_free()

	# Labels have to be told how wide they may wrap; see _roster_body.
	var wrap_width := side_panel.size.x - PANEL_CONTENT * 2.0
	# Tighter than the scene's default: three moves plus a heading only clear
	# the enemy sprite below at this spacing.
	side_panel_vbox.add_theme_constant_override("separation", 2)

	if _enemy.moves.is_empty():
		side_panel_vbox.add_child(_roster_heading(_enemy.enemy_name))
		side_panel_vbox.add_child(_roster_body(_enemy.lore, wrap_width))
		return

	side_panel_vbox.add_child(_roster_heading("MOVES"))
	for move: EnemyMove in _enemy.moves:
		side_panel_vbox.add_child(_move_entry(move, wrap_width))
	_highlight_current_move()
	_warn_if_roster_overflows()

## One entry: icon, name and a NEXT badge on a line, flavour text beneath it,
## all seated on a plate that gets lit when this is the incoming move.
func _move_entry(move: EnemyMove, wrap_width: float) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.name = "Move_%s" % move.move_name.replace(" ", "")
	plate.add_theme_stylebox_override("panel", _move_plate_style(false))

	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 0)
	plate.add_child(entry)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = move.icon
	icon.custom_minimum_size = MOVE_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	var name_label := Label.new()
	name_label.text = move.move_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)

	entry.add_child(header)

	# The name gets the whole row: the badge below is an overlay, not a
	# sibling. Carrying it in the flow cost every entry ~26px of name width,
	# which wrapped "Smear Campaign" and "Relief Goods Blitz" onto a second
	# line and pushed two of the five rosters past SIDE_PANEL_BOTTOM_LIMIT.
	name_label.custom_minimum_size.x = wrap_width - MOVE_ICON_SIZE.x - 8.0

	var desc := _roster_body(move.description, wrap_width - 4.0)
	entry.add_child(desc)

	# A transparent full-rect layer contributes no minimum size of its own, so
	# anchoring the badge inside it keeps the plate exactly as tall as its text.
	var badge_layer := Control.new()
	badge_layer.name = "BadgeLayer"
	badge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(badge_layer)

	var badge := PanelContainer.new()
	badge.name = "NextBadge"
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.anchor_top = 1.0
	badge.anchor_bottom = 1.0
	# Pinned bottom-right: the description's last line is nearly always short,
	# where a name can run the full width of the plate.
	badge.offset_left = -MOVE_BADGE_WIDTH
	badge.offset_right = 0.0
	badge.offset_top = -11.0
	badge.offset_bottom = 0.0
	var badge_label := Label.new()
	badge_label.text = "NEXT"
	badge_label.add_theme_font_size_override("font_size", 7)
	badge_label.add_theme_color_override("font_color", Color(0.14, 0.08, 0.04))
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = MOVE_ALERT_COLOR
	badge_style.set_corner_radius_all(2)
	badge_style.content_margin_left = 2
	badge_style.content_margin_right = 2
	badge_style.content_margin_top = 0
	badge_style.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", badge_style)
	badge_layer.add_child(badge)

	_move_entries.append({
		"plate": plate, "name": name_label, "desc": desc, "icon": icon, "badge": badge,
	})
	return plate

## The plate behind one move. Both variants carry identical content margins, so
## swapping between them lights the entry up without moving a single pixel of
## the text inside it.
func _move_plate_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 3
	style.content_margin_right = 1
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.set_corner_radius_all(2)
	if active:
		style.bg_color = Color(0.34, 0.13, 0.09, 0.95)
		style.border_width_left = 3
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = MOVE_ALERT_COLOR
	else:
		style.bg_color = Color(0, 0, 0, 0)
		style.set_border_width_all(0)
	return style

## Marks whichever move the enemy will swing next, and dims the rest.
##
## Called both when the roster is built and immediately after _move_index
## advances, so the panel always names the *incoming* move rather than the one
## that just landed.
func _highlight_current_move() -> void:
	_stop_move_pulse()
	_refresh_move_strip()
	if _move_entries.is_empty():
		return
	var active_index := _move_index % _move_entries.size()
	for i in _move_entries.size():
		var entry: Dictionary = _move_entries[i]
		var plate := entry["plate"] as PanelContainer
		var is_active := i == active_index
		plate.add_theme_stylebox_override("panel", _move_plate_style(is_active))
		plate.self_modulate = Color.WHITE
		(entry["name"] as Label).add_theme_color_override(
			"font_color", MOVE_ACTIVE_NAME_COLOR if is_active else MOVE_IDLE_NAME_COLOR)
		(entry["desc"] as Label).add_theme_color_override(
			"font_color", MOVE_DESC_COLOR if is_active else MOVE_IDLE_DESC_COLOR)
		# The icons carry the same secondary treatment as their text, so an
		# inactive entry recedes as a whole rather than keeping a bright icon.
		(entry["icon"] as TextureRect).modulate = (
			Color.WHITE if is_active else Color(1, 1, 1, 0.55))
		(entry["badge"] as PanelContainer).modulate.a = 1.0 if is_active else 0.0

	_start_move_pulse(_move_entries[active_index]["plate"] as PanelContainer)

## A slow breath on the active plate. Tuned to be noticeable in peripheral
## vision without pulling the eye off the board mid-word: it only lightens the
## plate, never darkens it below its resting colour, and self_modulate leaves
## the text inside untouched.
func _start_move_pulse(plate: PanelContainer) -> void:
	plate.self_modulate = MOVE_PULSE_BRIGHT
	_move_pulse_tween = create_tween()
	_move_pulse_tween.set_loops()
	_move_pulse_tween.tween_property(plate, "self_modulate", Color.WHITE, 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_pulse_tween.tween_property(plate, "self_modulate", MOVE_PULSE_BRIGHT, 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Killed explicitly rather than left to expire: the roster is rebuilt on every
## encounter, and a tween still pointing at a freed plate is an error.
func _stop_move_pulse() -> void:
	if _move_pulse_tween != null and _move_pulse_tween.is_valid():
		_move_pulse_tween.kill()
	_move_pulse_tween = null

## The panel grows to fit however many moves an enemy has, which means a future
## enemy with more of them could run into the sprite below. Rather than silently
## overlapping, say so.
func _warn_if_roster_overflows() -> void:
	await get_tree().process_frame
	if not is_instance_valid(side_panel):
		return
	# Only meaningful on WIDE, where the roster is permanently on screen with
	# the enemy standing underneath it. On compact layouts it is a hidden
	# overlay that is *supposed* to cover the stage when opened, so measuring it
	# against the sprite line reports a collision that is the whole design.
	if not Layout.profile.is_wide():
		return
	var bottom := side_panel.position.y + side_panel.size.y
	if bottom > SIDE_PANEL_BOTTOM_LIMIT:
		push_warning("Side panel roster for %s runs to y=%d, past the %d limit — it will overlap the enemy sprite. Shorten a description or drop a move."
			% [_enemy.enemy_name, bottom, SIDE_PANEL_BOTTOM_LIMIT])

func _roster_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", MOVE_HEADING_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _roster_body(text: String, wrap_width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", MOVE_DESC_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Without this the label reports a minimum height as if it were wrapping one
	# word per line, and the PanelContainer above sizes itself to that.
	label.custom_minimum_size.x = wrap_width
	return label




## Bookworm-style word tray: the picked letters appear as raised tiles (not
## text) above the board, while the message line below carries hints and the
## combat log. They sit in separate places now, so both stay visible.
func _on_selection_changed(current_text: String) -> void:
	# The stopwatch starts on the tap that takes the word from empty to one
	# letter, so reading the question first costs nothing — only the time spent
	# actually assembling the word is measured.
	if _current_selection.is_empty() and not current_text.is_empty():
		_selection_started_ms = Time.get_ticks_msec()
	_current_selection = current_text
	_set_tray_word(current_text)
	word_tray.visible = current_text.length() > 0
	word_preview_label.text = _idle_hint()
	_update_action_buttons()

## The message line under the board is now blank while you play — the prompt's
## own blank shows how long the answer is, so a standing instruction there was
## just noise. The line still carries things that actually happen: damage
## dealt, the rival's hits, and the fact after a correct answer.
##
## A primed Power Up is the one exception. It has to stay visible while you
## pick letters, otherwise the reminder vanishes the moment you tap a tile.
func _idle_hint() -> String:
	if _power_up_active:
		return "Power Up primed — your answer hits x%s" % POWER_UP_MULTIPLIER
	return ""

const TRAY_CHIP_SIZE := Vector2(32, 32)
## Travel time between a board cell and the tray, shared with the tile itself
## so the board's "stay empty until it lands" wait matches the ghost's flight.
const TILE_FLIGHT_TIME := LetterTile.FLIGHT_TIME
## The tray chip holds off appearing until the ghost is most of the way there,
## so the letter is never visibly in two places at once.
const TRAY_POP_DELAY := TILE_FLIGHT_TIME * 0.7

## Updates the tray in place — chips are reused and only the tail is added or
## trimmed. A wholesale rebuild would free chips that in-flight tile animations
## are still aiming at, so incremental is what keeps the two in step.
func _set_tray_word(word: String) -> void:
	while word_tray.get_child_count() > word.length():
		var extra := word_tray.get_child(word_tray.get_child_count() - 1)
		word_tray.remove_child(extra)
		extra.queue_free()

	for i in word_tray.get_child_count():
		(word_tray.get_child(i) as LetterTile).letter = word[i]

	for i in range(word_tray.get_child_count(), word.length()):
		var chip: LetterTile = LETTER_TILE_SCENE.instantiate()
		word_tray.add_child(chip)
		chip.custom_minimum_size = TRAY_CHIP_SIZE
		chip.letter = word[i]
		# Board tiles ignore the mouse and let the board hit-test by position,
		# but a tray chip has no such owner — it takes its own clicks so a
		# letter can be undone from the word as well as from the board.
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.gui_input.connect(_on_tray_chip_input.bind(chip))
		_pop_in_tray_chip(chip)

## Clicking a letter in the word rewinds the selection to just before it —
## the same rule as clicking its cell on the board, routed through the board
## so there is only one implementation of what a rewind means.
func _on_tray_chip_input(event: InputEvent, chip: Control) -> void:
	if _sequence_running:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	Audio.play_sfx("tile_tap")
	board.deselect_from(chip.get_index())

func _pop_in_tray_chip(chip: Control) -> void:
	chip.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(chip, "scale", Vector2.ONE, 0.16) \
		.set_delay(TRAY_POP_DELAY).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Flies a copy of the tapped tile from its board cell up into the word tray.
## The ghost is decoration only — it is never the source of truth for what the
## word says — so it fades out on arrival and frees itself, and losing one to a
## scene change or a fast second tap costs nothing.
func _on_tile_lifted(letter: String, from_rect: Rect2) -> void:
	# Where this tile is headed is worked out from the tray's own geometry, not
	# by reading the chip node. The chip was only added a moment ago and the
	# HBoxContainer has not sorted its children yet, so its position is still
	# (0, 0) — which sent every tile flying to the top-left corner of the
	# screen instead of up into the tray.
	var slot := word_tray.get_child_count() - 1
	var target := _tray_slot_position(slot, word_tray.get_child_count())

	var ghost: LetterTile = LETTER_TILE_SCENE.instantiate()
	add_child(ghost)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.custom_minimum_size = from_rect.size
	ghost.size = from_rect.size
	ghost.global_position = from_rect.position
	ghost.letter = letter

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ghost, "global_position", target, TILE_FLIGHT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale", TRAY_CHIP_SIZE / from_rect.size, TILE_FLIGHT_TIME)
	tween.tween_property(ghost, "modulate:a", 0.0, TILE_FLIGHT_TIME * 0.5) \
		.set_delay(TILE_FLIGHT_TIME * 0.5)
	await tween.finished
	if is_instance_valid(ghost):
		ghost.queue_free()

## The mirror of _on_tile_lifted: a dropped letter flies back down from its
## tray slot to the cell it came from, growing to board size as it goes. The
## cell stays drawn as an empty socket until this lands (LetterTile.play_return
## times its own wait to match), so the letter is never in two places.
func _on_tile_returned(letter: String, tray_index: int, tray_total: int, to_rect: Rect2) -> void:
	var from := _tray_slot_position(tray_index, tray_total)

	var ghost: LetterTile = LETTER_TILE_SCENE.instantiate()
	add_child(ghost)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.custom_minimum_size = TRAY_CHIP_SIZE
	ghost.size = TRAY_CHIP_SIZE
	ghost.global_position = from
	ghost.letter = letter

	var tween := create_tween().set_parallel(true)
	tween.tween_property(ghost, "global_position", to_rect.position, TILE_FLIGHT_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale", to_rect.size / TRAY_CHIP_SIZE, TILE_FLIGHT_TIME)
	await tween.finished
	if is_instance_valid(ghost):
		ghost.queue_free()

## Screen position of slot `index` in a centred row of `total` chips. Derived
## from the tray's rect rather than read off a chip node, so it is correct on
## the same frame the chip is added — before any layout pass has run.
func _tray_slot_position(index: int, total: int) -> Vector2:
	var tray_rect := word_tray.get_global_rect()
	if total <= 0:
		return tray_rect.get_center() - TRAY_CHIP_SIZE * 0.5
	var separation := float(word_tray.get_theme_constant("separation"))
	var row_width := total * TRAY_CHIP_SIZE.x + float(total - 1) * separation
	var start_x := tray_rect.position.x + (tray_rect.size.x - row_width) * 0.5
	var y := tray_rect.position.y + (tray_rect.size.y - TRAY_CHIP_SIZE.y) * 0.5
	return Vector2(start_x + index * (TRAY_CHIP_SIZE.x + separation), y)

func _on_word_rejected(word: String) -> void:
	if word.length() > 0:
		Audio.play_sfx("word_rejected")
		word_preview_label.text = "\"%s\" isn't a word" % word

## Damage base is the sum of each letter's Scrabble-style value (rare letters
## hit harder), not word length. Gold scales that base; Spark adds a
## flat bonus. Spelling the question's answer multiplies the lot — knowing the
## answer should always beat merely finding a long word.
func _on_word_accepted(word: String, used_spark: bool, used_gold: bool) -> void:
	var is_answer := (not _question.is_empty()
		and word.to_upper() == String(_question.get("answer", "")))

	var damage := BoardController.word_value(word)
	if used_gold:
		damage *= GOLD_MULTIPLIER
	if used_spark:
		damage += SPARK_BONUS_DAMAGE
	if is_answer:
		damage = roundi(damage * ANSWER_BONUS_MULTIPLIER)
	# Speed scales the hit but cannot carry it: the multiplier tops out at
	# 1.3x, while length drives the base through letter values and can swing it
	# several-fold. A fast short word still loses to a slow long one.
	var tier := _attack_tier(word.length())
	damage = roundi(damage * float(tier["damage"]))
	var speed := _speed_bonus(word.length())
	damage = roundi(damage * float(speed["multiplier"]))
	var used_power_up := _power_up_active
	if used_power_up:
		damage = roundi(damage * POWER_UP_MULTIPLIER)
		_power_up_active = false

	var bonuses: Array[String] = []
	if is_answer:
		bonuses.append("CORRECT")
	if not String(tier["label"]).is_empty():
		bonuses.append(String(tier["label"]))
	if not String(speed["label"]).is_empty():
		bonuses.append(String(speed["label"]))
	if used_gold:
		bonuses.append("Gold")
	if used_spark:
		bonuses.append("Spark")
	if used_power_up:
		bonuses.append("Power Up")
	var message := "%s +%d" % [word.to_upper(), damage]
	if not bonuses.is_empty():
		message += "! " + " + ".join(bonuses) + "!"
	word_preview_label.text = message

	Audio.play_sfx("word_accepted")
	_play_attack_sequence(damage, is_answer, tier)

## One exchange, beat by beat: the player swings, the hit crosses the screen,
## the rival flinches and loses health.
##
## The rival does NOT counterattack here — it only gets a turn when the clock
## runs out (_handle_timeout). Answering correctly is therefore a clean win of
## the exchange, and an ordinary word chips damage without stopping the clock.
func _play_attack_sequence(damage: int, is_answer: bool, tier: Dictionary) -> void:
	_sequence_running = true
	_update_action_buttons()

	# One of five swings, picked at random — see _play_player_attack. Each still
	# spends the tier's own reach, so a longer word visibly carries further
	# whichever style comes up, and nothing about the damage changes.
	# Returns with the hit already landed -- the projectile arrived, or a melee
	# attacker is standing over the rival. Either way the flinch below plays at
	# the right moment rather than after the animation has finished.
	await _play_player_attack(tier)

	Audio.play_sfx("enemy_hurt")
	_shake_screen(float(tier["shake"]))
	var enemy_flinching := enemy_character.play_hit()
	_enemy_hp = maxi(0, _enemy_hp - damage)
	enemy_heart_row.set_value(_enemy_hp)
	if enemy_flinching:
		await enemy_character.one_shot_finished

	# Only now does a melee attacker walk home. Before the win check, so a
	# killing blow cannot leave the player stranded mid-field.
	await _player_attack_recover()

	if _enemy_hp <= 0:
		_sequence_running = false
		_update_action_buttons()
		_end_match(true)
		return

	if is_answer:
		var fact := String(_question.get("fact", ""))
		if not fact.is_empty():
			word_preview_label.text = fact
			await get_tree().create_timer(FACT_PAUSE).timeout
		_present_question()

	_sequence_running = false
	_update_action_buttons()

## The enemy's real turn (Phase 0 — see enemy-attack-plan.md). Whichever move
## was telegraphed in the side panel lands now, using its direct_damage; any
## bonus banked by the Mudslinging Tile detonating rides along on top rather
## than being the only way the enemy could ever hit you. The move then
## rotates so the panel shows something new for the next exchange.
func _resolve_enemy_turn() -> void:
	var move := _current_move()
	var damage := move.direct_damage if move != null else 0
	var attacker := move.move_name if move != null else _enemy.enemy_name
	var message := "%s hits! -%d HP" % [attacker, damage]
	if _pending_enemy_damage > 0:
		message += "  (+%d from the mud)" % _pending_enemy_damage
		damage += _pending_enemy_damage
		_pending_enemy_damage = 0

	# Every skill has its own four-beat sequence and its own two sounds; see
	# _play_signature_move. The generic "take_damage" that used to fire here is
	# gone on purpose — each animation now plays its own impact sound on the
	# exact frame it lands, and layering a second thud over that just muddied
	# fifteen distinct hits back into one.
	await _play_signature_move(move)

	Audio.play_sfx("player_hurt")
	var player_flinching := player_character.play_hit()
	_player_hp = maxi(0, _player_hp - damage)
	player_heart_row.set_value(_player_hp)
	word_preview_label.text = message
	# Advanced and re-telegraphed together: the panel has to name the NEXT
	# move the moment this one has landed, not keep pointing at the spent one.
	_move_index += 1
	_highlight_current_move()
	if player_flinching:
		await player_character.one_shot_finished

## Which swing a word earns. First tier whose max_length fits.
func _attack_tier(word_length: int) -> Dictionary:
	for tier in ATTACK_TIERS:
		if word_length <= int(tier["max_length"]):
			return tier
	return ATTACK_TIERS[ATTACK_TIERS.size() - 1]

## How much the speed bonus is worth for a word of this length, as
## {multiplier, label}. Rated per letter so long answers stay winnable.
func _speed_bonus(word_length: int) -> Dictionary:
	if _selection_started_ms <= 0 or word_length <= 0:
		return {"multiplier": SPEED_BASE_MULTIPLIER, "label": ""}
	var elapsed := float(Time.get_ticks_msec() - _selection_started_ms) / 1000.0
	var per_letter := elapsed / float(word_length)
	for tier in SPEED_TIERS:
		if per_letter <= float(tier["seconds_per_letter"]):
			return {"multiplier": float(tier["multiplier"]), "label": String(tier["label"])}
	return {"multiplier": SPEED_BASE_MULTIPLIER, "label": ""}

## Drives a fighter toward its opponent and back. Purely additive on top of the
## sprite clip, and always returns the node to where it started so a swing
## interrupted by a scene change cannot leave a character stranded.
func _lunge(who: Control, distance: float) -> void:
	if is_zero_approx(distance):
		return
	var home := who.position.x
	var toward := 1.0 if who == player_character else -1.0
	var tween := create_tween()
	tween.tween_property(who, "position:x", home + distance * toward, 0.10) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(who, "position:x", home, 0.18) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A short kick of camera shake, always measured from and returned to the one
## screen position captured at startup.
##
## It used to read `position` at call time and restore to that. That silently
## drifted the whole battle screen: a second shake fired while the first was
## still running captured a mid-shake offset as its "origin" and put the screen
## back *there*. One hit could not show it, but the signature attacks kick
## several times in quick succession (Relief Goods Blitz lands three sacks),
## and the error accumulated permanently.
func _shake_screen(strength: float) -> void:
	if strength <= 0.0:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	position = _screen_home
	_shake_tween = create_tween()
	for i in 5:
		var falloff := strength * (1.0 - float(i) / 5.0)
		_shake_tween.tween_property(self, "position",
			_screen_home + Vector2(randf_range(-falloff, falloff), randf_range(-falloff, falloff)),
			0.035)
	_shake_tween.tween_property(self, "position", _screen_home, 0.04)

## One projectile crossing the gap. `arc` bends its path, `delay` staggers it
## within a volley, `wobble` makes it drift rather than fly straight.
func _spawn_bolt(from: Control, to: Control, tint: Color, bolt_size: float,
		travel: float, delay: float = 0.0, arc: float = 0.0, wobble: bool = false) -> void:
	var orb := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	var radius := int(bolt_size * 0.5)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(tint.r, tint.g, tint.b, 0.55)
	style.shadow_size = int(bolt_size * 0.4)
	orb.add_theme_stylebox_override("panel", style)
	orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.size = Vector2(bolt_size, bolt_size)
	add_child(orb)

	var start := from.position + from.size * 0.5 - orb.size * 0.5
	var finish := to.position + to.size * 0.5 - orb.size * 0.5
	orb.position = start
	orb.modulate.a = 0.0

	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(orb, "modulate:a", 1.0, 0.05)
	if is_zero_approx(arc):
		tween.tween_property(orb, "position", finish, travel) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		# Two hops through a lifted midpoint stand in for a curved path.
		var mid := start.lerp(finish, 0.5) + Vector2(0, -arc)
		tween.tween_property(orb, "position", mid, travel * 0.5) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(orb, "position", finish, travel * 0.5) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if wobble:
		tween.parallel().tween_property(orb, "rotation", randf_range(-2.0, 2.0), travel)
	tween.tween_callback(orb.queue_free)

## Fires `count` bolts and waits for the last of them to land.
## Fires `count` bolts and returns how long the last one needs to land,
## WITHOUT waiting for it. The player's throw keeps animating while they fly:
## awaiting here is what used to freeze the thrower mid-motion and make the
## projectile look bolted on rather than thrown.
func _launch_bolts(from: Control, to: Control, tint: Color, count: int,
		bolt_size: float, rate: float) -> float:
	var travel := TRAVEL_TIME * rate
	var stagger := travel * 0.22
	for i in count:
		_spawn_bolt(from, to, tint, bolt_size, travel, stagger * float(i),
			0.0 if count == 1 else randf_range(-14.0, 14.0))
	return travel + stagger * float(maxi(0, count - 1))

## Fires `count` bolts and waits for the last of them to land. The rival's
## skills use this; the player's throws use _launch_bolts directly so their
## follow-through can run over the top of the flight.
func _spawn_bolts(from: Control, to: Control, tint: Color, count: int,
		bolt_size: float, rate: float) -> void:
	await get_tree().create_timer(
		_launch_bolts(from, to, tint, count, bolt_size, rate)).timeout

## Plays one enemy skill. Every style moves the rival and crosses the gap
## differently, so the three moves on a roster never look alike even though
## they share a single attack sprite clip.
# --------------------------------------------------------------------------
# Signature attacks
# --------------------------------------------------------------------------
#
# Every skill gets its own sequence rather than sharing one of five generic
# patterns, because the roster panel now names the incoming move and the
# animation is what confirms it. Each runs the same four beats:
#
#   telegraph — the rival visibly prepares THIS skill, with its cast sound
#   execute   — the attack crosses the screen in a shape unique to the skill
#   impact    — the hit lands, with the skill's own impact sound on that frame
#   recovery  — everything transient is freed and the board returns to rest
#
# There is no per-skill sprite art (each character sheet has one attack clip),
# so identity is carried by motion, colour, effect shape and audio instead.

## A transient effect layer, freed the moment its tween ends. Everything the
## signature moves draw goes through here so nothing can outlive its attack.
func _fx_node(node: Control, life: float) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep the effect on screen. Several effects are placed relative to a
	# fighter but sized in absolute units -- a 150-unit damage label, a
	# 150-unit shockwave ring -- which is comfortably inside a 640-unit canvas
	# and hangs off the edge of a 320-unit one.
	var limit: Vector2 = Layout.profile.design_size
	if node.size.x > 0.0 and node.size.x < limit.x:
		node.position.x = clampf(node.position.x, 0.0, limit.x - node.size.x)
	add_child(node)
	var killer := create_tween()
	killer.tween_interval(life)
	killer.tween_callback(node.queue_free)
	return node

func _fx_style(color: Color, radius: int, shadow: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	if shadow > 0.0:
		style.shadow_color = Color(color.r, color.g, color.b, 0.5)
		style.shadow_size = int(shadow)
	return style

## Full-screen colour wash. The cheapest way to make an impact feel like it
## reached the player rather than merely arrived near them.
func _fx_flash(color: Color, peak: float, hold: float = 0.03, fade: float = 0.22) -> void:
	var wash := ColorRect.new()
	wash.color = Color(color.r, color.g, color.b, 0.0)
	# "Full screen" is whatever the screen currently is, not the 640x480 this
	# was written against.
	wash.offset_right = Layout.profile.design_size.x
	wash.offset_bottom = Layout.profile.design_size.y
	_fx_node(wash, hold + fade + 0.05)
	var tween := create_tween()
	tween.tween_property(wash, "color:a", peak, 0.04)
	tween.tween_interval(hold)
	tween.tween_property(wash, "color:a", 0.0, fade)

## An expanding ring centred on a character. Reads as a pulse of force or,
## slowed down, as something spreading outward.
func _fx_ring(who: Control, color: Color, to_size: float, time: float, delay: float = 0.0) -> void:
	var ring := Panel.new()
	var style := _fx_style(Color(color.r, color.g, color.b, 0.0), 64)
	style.draw_center = false
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = color
	ring.add_theme_stylebox_override("panel", style)
	var centre := who.position + who.size * 0.5
	ring.size = Vector2(8, 8)
	ring.position = centre - ring.size * 0.5
	_fx_node(ring, delay + time + 0.05)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.parallel().tween_property(ring, "size", Vector2(to_size, to_size), time)
	tween.parallel().tween_property(ring, "position", centre - Vector2(to_size, to_size) * 0.5, time)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, time)

## A word thrown up over a character. Several skills are about what is *said*
## rather than what is thrown, and a floating phrase says that instantly.
func _fx_word(text: String, who: Control, color: Color, rise: float = 26.0,
		delay: float = 0.0, size: int = 11) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", HUD_TITLE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(150, 18)
	label.position = who.position + Vector2(who.size.x * 0.5 - 75.0, 12.0)
	label.modulate.a = 0.0
	_fx_node(label, delay + 0.85)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(label, "modulate:a", 1.0, 0.10)
	tween.parallel().tween_property(label, "position:y", label.position.y - rise, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)

## A rectangular projectile — paper, tarpaulin, a sack of rice. Squares read as
## thrown objects where the round bolts read as energy.
func _fx_slab(from: Control, to: Control, color: Color, slab: Vector2, travel: float,
		delay: float = 0.0, arc: float = 0.0, spin: float = 0.0, corner: int = 2) -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _fx_style(color, corner, slab.x * 0.25))
	panel.size = slab
	panel.pivot_offset = slab * 0.5
	var start := from.position + from.size * 0.5 - slab * 0.5
	var finish := to.position + to.size * 0.5 - slab * 0.5
	panel.position = start
	panel.modulate.a = 0.0
	_fx_node(panel, delay + travel + 0.2)
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(panel, "modulate:a", 1.0, 0.05)
	if is_zero_approx(arc):
		tween.tween_property(panel, "position", finish, travel) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		var mid := start.lerp(finish, 0.5) + Vector2(0, -arc)
		tween.tween_property(panel, "position", mid, travel * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position", finish, travel * 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if not is_zero_approx(spin):
		tween.parallel().tween_property(panel, "rotation", spin, travel)
	tween.tween_property(panel, "modulate:a", 0.0, 0.12)

## Debris left sitting on whoever was hit — mud, paste, scribble.
func _fx_splatter(who: Control, color: Color, count: int, spread: float, life: float) -> void:
	for i in count:
		var bit := Panel.new()
		var s := randf_range(4.0, 9.0)
		bit.add_theme_stylebox_override("panel", _fx_style(color, int(s * 0.5)))
		bit.size = Vector2(s, s)
		bit.position = who.position + who.size * 0.5 + Vector2(
			randf_range(-spread, spread), randf_range(-spread, spread))
		bit.rotation = randf_range(-1.5, 1.5)
		_fx_node(bit, life + 0.1)
		var tween := create_tween()
		tween.tween_interval(life * 0.6)
		tween.tween_property(bit, "modulate:a", 0.0, life * 0.4)

## The rival lit up while winding up, so the telegraph is visible on the
## attacker and not only in the effects it throws.
func _fx_charge(who: Control, color: Color, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(who, "modulate", Color(
		1.0 + color.r * 0.55, 1.0 + color.g * 0.55, 1.0 + color.b * 0.55), time * 0.6)
	tween.tween_property(who, "modulate", Color.WHITE, time * 0.4)

## The impact beat, shared by every skill: the skill's own sound on the exact
## frame the screen kicks and washes.
func _fx_impact(move_id: String, shake: float, color: Color, flash: float = 0.22) -> void:
	Audio.play_move_sfx(move_id, "hit")
	_shake_screen(shake)
	if flash > 0.0:
		_fx_flash(color, flash)

# --- player attacks -------------------------------------------------------
#
# Juan and Maria fight with a mixed pool: some attacks close the distance and
# land a physical blow, others hold ground and throw. Which one comes up is
# random, so a run of attacks reads as a fight rather than one move on repeat.
#
# The two kinds are deliberately built to look nothing alike:
#
#   ranged  the character holds position. Anticipation, then the projectile
#           leaves ON the release beat -- not after the animation, which is
#           what used to make the orb look bolted on rather than thrown.
#
#   melee   the character crosses the gap, strikes at contact range, and walks
#           back. The gap is ~374px of mostly transparent air, so the distance
#           is measured between the VISIBLE bodies (see _player_melee_dx).
#
# A style is two phase lists rather than one. `strike` runs up to and including
# the moment the hit lands; the caller then plays the rival's flinch and applies
# damage while a melee attacker is still standing over them, and only then is
# `recover` run. Merging the two would put the walk home before the hit.
#
# Body motion comes from three layers at once, because any one alone reads as a
# sliding sprite: `_beat` moves and tilts the whole figure, the cut-out rig
# swings legs, torso and head against each other, and the 7-frame attack clip
# supplies the arm. The rig and the clip cannot both be up -- the rig is a slice
# of whichever frame was showing when it was raised -- so every style rigs its
# wind-up and drops the rig on the beat that strikes.

## One phase. Every field is optional.
##
##   approach  fraction of the way to contact range, MELEE ONLY. 0 is home,
##             1 is standing over the rival. Scaled to the real gap, so it
##             holds whatever the two sprites' widths are.
##   dx, dy    offset from the stance in pixels, on top of `approach`
##   rot       whole-body tilt, degrees
##   sx, sy    squash and stretch
##   legs,
##   torso,
##   head      rig joint angles in degrees -- the actual articulation
##   bob       lifts the rigged figure, for a rise onto the toes
##   walk      run the real walk clip through this phase instead of the rig
##   t         seconds
##   release   RANGED: the projectile leaves the hand on this beat
##   contact   MELEE: the blow lands on this beat
func _phase(d: Dictionary) -> Dictionary:
	return d

## Which pool a character draws from. Keyed by character so adding a third
## means adding an entry, not editing a branch.
func _attack_pool(who: String) -> Dictionary:
	if who == "female":
		return _maria_attacks()
	return _juan_attacks()

## JUAN -- grounded and committed. He throws from the shoulder and hits with
## his whole weight behind it; his melee is straight-line and forceful.
func _juan_attacks() -> Dictionary:
	return {
		# ---- ranged ----------------------------------------------------
		"overhand": {"kind": "ranged", "sfx": "attack_impact",
			"clip": "res://assets/images/characters/juan_throw", "frames": 7,
			"strike": [
				_phase({"dx": -9, "dy": 3, "rot": -7, "legs": 5, "torso": -12, "head": -5, "t": 0.20}),
				_phase({"dx": -13, "dy": 1, "rot": -10, "legs": 8, "torso": -18, "head": -8, "t": 0.10}),
				_phase({"dx": 8, "dy": -4, "rot": 9, "sx": 1.06, "sy": 0.95, "t": 0.07, "release": true}),
			],
			"recover": [
				_phase({"dx": 13, "dy": 2, "rot": 14, "sx": 1.04, "sy": 0.97, "t": 0.09}),
				_phase({"dx": 4, "rot": 4, "t": 0.16}),
			]},
		"sidearm": {"kind": "ranged", "sfx": "attack_impact",
			"clip": "res://assets/images/characters/juan_throw", "frames": 7,
			"strike": [
				_phase({"dx": -7, "dy": 4, "rot": -4, "legs": 10, "torso": -16, "head": -3, "t": 0.17}),
				_phase({"dx": 10, "dy": 5, "rot": 7, "sx": 1.08, "sy": 0.93, "t": 0.07, "release": true}),
			],
			"recover": [
				_phase({"dx": 15, "dy": 3, "rot": 11, "t": 0.10}),
				_phase({"dx": 3, "rot": 3, "t": 0.15}),
			]},
		"snap": {"kind": "ranged", "sfx": "tile_tap",
			"clip": "res://assets/images/characters/juan_punch", "frames": 6,
			"strike": [
				_phase({"dx": -4, "dy": 1, "rot": -3, "legs": 3, "torso": -6, "t": 0.08}),
				_phase({"dx": 9, "dy": -2, "rot": 6, "sx": 1.04, "sy": 0.97, "t": 0.05, "release": true}),
			],
			"recover": [_phase({"dx": 5, "rot": 3, "t": 0.09})]},
		"heave": {"kind": "ranged", "sfx": "attack_impact",
			"clip": "res://assets/images/characters/juan_uppercut", "frames": 7,
			"strike": [
				_phase({"dx": -5, "dy": 10, "legs": 14, "torso": -6, "head": 6, "sx": 1.06, "sy": 0.9, "t": 0.26}),
				_phase({"dx": -8, "dy": 12, "rot": -4, "legs": 17, "torso": -10, "head": 8, "sx": 1.08, "sy": 0.88, "t": 0.12}),
				_phase({"dx": 10, "dy": -12, "rot": 8, "sx": 0.94, "sy": 1.12, "t": 0.08, "release": true}),
			],
			"recover": [
				_phase({"dx": 16, "dy": -4, "rot": 13, "sx": 1.05, "sy": 0.96, "t": 0.12}),
				_phase({"dx": 4, "dy": 3, "rot": 3, "sy": 1.02, "t": 0.18}),
			]},
		"turnthrow": {"kind": "ranged", "sfx": "attack_impact",
			"clip": "res://assets/images/characters/juan_throw", "frames": 7,
			"strike": [
				_phase({"dx": -6, "dy": 2, "rot": -22, "legs": 7, "torso": -14, "head": -10, "t": 0.16}),
				_phase({"dx": -2, "rot": -150, "t": 0.13}),
				_phase({"dx": 9, "dy": -3, "rot": -330, "sx": 1.06, "sy": 0.95, "t": 0.09, "release": true}),
			],
			"recover": [
				_phase({"dx": 12, "dy": 1, "rot": -368, "t": 0.10}),
				_phase({"dx": 3, "rot": -360, "t": 0.14}),
			]},

		# ---- melee -----------------------------------------------------
		# Straight cross: runs in, plants, drives one fist through.
		"cross": {"kind": "melee", "sfx": "attack_impact", "shake": 7.0,
			"clip": "res://assets/images/characters/juan_punch", "frames": 6,
			"strike": [
				_phase({"dx": -8, "dy": 2, "legs": 6, "torso": -9, "head": -4, "t": 0.13}),
				_phase({"approach": 0.55, "walk": true, "t": 0.20}),
				_phase({"approach": 1.0, "walk": true, "t": 0.16}),
				_phase({"approach": 1.0, "dx": -6, "rot": -8, "legs": 9, "torso": -12, "t": 0.08}),
				_phase({"approach": 1.0, "dx": 10, "dy": -2, "rot": 11, "sx": 1.08, "sy": 0.94, "t": 0.06, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dx": 6, "rot": 6, "t": 0.10}),
				_phase({"approach": 0.45, "walk": true, "t": 0.20}),
				_phase({"approach": 0.0, "walk": true, "t": 0.18}),
			]},
		# Flying kick: a short run, then both feet leave the ground.
		"flyingkick": {"kind": "melee", "sfx": "attack_impact", "shake": 9.0,
			"clip": "res://assets/images/characters/juan_kick", "frames": 7,
			"strike": [
				_phase({"dx": -5, "dy": 8, "legs": 13, "torso": -6, "sy": 0.9, "t": 0.16}),
				_phase({"approach": 0.5, "walk": true, "t": 0.18}),
				_phase({"approach": 0.85, "dy": -26, "rot": 12, "sx": 0.94, "sy": 1.1, "t": 0.14}),
				_phase({"approach": 1.0, "dy": -14, "rot": 18, "sx": 1.12, "sy": 0.9, "t": 0.07, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dy": 2, "rot": 6, "sy": 0.96, "t": 0.12}),
				_phase({"approach": 0.4, "walk": true, "t": 0.20}),
				_phase({"approach": 0.0, "walk": true, "t": 0.18}),
			]},
		# Shoulder charge: no wind-up, just a full-speed barge.
		"barge": {"kind": "melee", "sfx": "attack_impact", "shake": 10.0,
			"clip": "res://assets/images/characters/juan_punch", "frames": 6,
			"strike": [
				_phase({"dx": -11, "rot": -6, "legs": 8, "torso": -10, "t": 0.14}),
				_phase({"approach": 0.7, "walk": true, "rot": 6, "t": 0.18}),
				_phase({"approach": 1.0, "rot": 12, "sx": 1.1, "sy": 0.92, "t": 0.09, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dx": 4, "rot": 4, "t": 0.10}),
				_phase({"approach": 0.0, "walk": true, "t": 0.26}),
			]},
		# Uppercut: steps in close, sinks, then drives upward.
		"uppercut": {"kind": "melee", "sfx": "attack_impact", "shake": 8.0,
			"clip": "res://assets/images/characters/juan_uppercut", "frames": 7,
			"strike": [
				_phase({"approach": 0.5, "walk": true, "t": 0.20}),
				_phase({"approach": 1.0, "walk": true, "t": 0.16}),
				_phase({"approach": 1.0, "dy": 9, "legs": 15, "torso": -7, "sy": 0.9, "t": 0.11}),
				_phase({"approach": 1.0, "dy": -16, "rot": 9, "sx": 0.95, "sy": 1.14, "t": 0.07, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dy": -4, "rot": 4, "t": 0.11}),
				_phase({"approach": 0.0, "walk": true, "t": 0.24}),
			]},
		# Stomp: closes, rises onto one leg, brings the heel down.
		"stomp": {"kind": "melee", "sfx": "attack_impact", "shake": 11.0,
			"clip": "res://assets/images/characters/juan_kick", "frames": 7,
			"strike": [
				_phase({"approach": 0.6, "walk": true, "t": 0.22}),
				_phase({"approach": 1.0, "walk": true, "t": 0.15}),
				_phase({"approach": 1.0, "dy": -20, "rot": -6, "sy": 1.12, "t": 0.13}),
				_phase({"approach": 1.0, "dy": 6, "rot": 4, "sx": 1.14, "sy": 0.86, "t": 0.06, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dy": 0, "sy": 0.98, "t": 0.12}),
				_phase({"approach": 0.0, "walk": true, "t": 0.26}),
			]},
	}

## MARIA -- lighter and faster. She throws from the wrist and the hips, and her
## melee is built on rotation and footwork rather than mass.
func _maria_attacks() -> Dictionary:
	return {
		# ---- ranged ----------------------------------------------------
		"arc": {"kind": "ranged", "sfx": "attack_impact",
			"clip": "res://assets/images/characters/maria_throw", "frames": 5,
			"strike": [
				_phase({"dx": -8, "dy": 1, "rot": -9, "legs": 4, "torso": -14, "head": -6, "bob": -2, "t": 0.22}),
				_phase({"dx": -10, "dy": -2, "rot": -12, "legs": 5, "torso": -17, "head": -8, "bob": -4, "t": 0.10}),
				_phase({"dx": 9, "dy": -5, "rot": 10, "sx": 1.03, "sy": 1.02, "t": 0.07, "release": true}),
			],
			"recover": [
				_phase({"dx": 14, "dy": -2, "rot": 15, "t": 0.10}),
				_phase({"dx": 3, "rot": 4, "t": 0.17}),
			]},
		"flick": {"kind": "ranged", "sfx": "tile_tap",
			"clip": "res://assets/images/characters/maria_throw", "frames": 5,
			"strike": [
				_phase({"dx": -3, "rot": -4, "legs": 2, "torso": -5, "head": -3, "t": 0.07}),
				_phase({"dx": 7, "dy": -3, "rot": 7, "sx": 1.02, "sy": 1.01, "t": 0.04, "release": true}),
			],
			"recover": [_phase({"dx": 4, "rot": 3, "t": 0.08})]},
		"twincast": {"kind": "ranged", "sfx": "attack_impact",
			"clip": "res://assets/images/characters/maria_throw", "frames": 5,
			"strike": [
				_phase({"dx": -4, "dy": 3, "legs": 4, "torso": -4, "head": 5, "sx": 0.95, "sy": 1.05, "t": 0.20}),
				_phase({"dx": -6, "dy": 4, "legs": 6, "torso": -6, "head": 7, "sx": 0.92, "sy": 1.08, "t": 0.10}),
				_phase({"dx": 10, "dy": -4, "sx": 1.12, "sy": 0.94, "t": 0.06, "release": true}),
			],
			"recover": [
				_phase({"dx": 13, "dy": -1, "sx": 1.05, "sy": 0.98, "t": 0.10}),
				_phase({"dx": 2, "t": 0.16}),
			]},
		"pirouette": {"kind": "ranged", "sfx": "attack_impact",
			"clip": "res://assets/images/characters/maria_throw", "frames": 5,
			"strike": [
				_phase({"dx": -4, "dy": -3, "rot": -14, "legs": 3, "torso": -10, "head": -6, "bob": -5, "t": 0.15}),
				_phase({"dy": -6, "rot": 160, "bob": -7, "sy": 1.06, "t": 0.14}),
				_phase({"dx": 8, "dy": -4, "rot": 344, "sx": 1.04, "t": 0.08, "release": true}),
			],
			"recover": [
				_phase({"dx": 11, "dy": -1, "rot": 372, "t": 0.10}),
				_phase({"dx": 2, "rot": 360, "t": 0.15}),
			]},
		"skycast": {"kind": "ranged", "sfx": "attack_impact",
			"clip": "res://assets/images/characters/maria_throw", "frames": 5,
			"strike": [
				_phase({"dx": -4, "dy": 4, "rot": -3, "legs": 6, "torso": -6, "head": -8, "t": 0.20}),
				_phase({"dx": -2, "dy": -8, "legs": 2, "torso": -3, "head": -12, "bob": -9, "sy": 1.08, "t": 0.12}),
				_phase({"dx": 7, "dy": -11, "rot": 5, "sx": 1.02, "sy": 1.04, "t": 0.07, "release": true}),
			],
			"recover": [
				_phase({"dx": 10, "dy": -5, "rot": 9, "t": 0.11}),
				_phase({"dx": 2, "rot": 2, "t": 0.17}),
			]},

		# ---- melee -----------------------------------------------------
		# Spin kick: carries her turn into the leg.
		"spinkick": {"kind": "melee", "sfx": "attack_impact", "shake": 8.0,
			"clip": "res://assets/images/characters/maria_kick", "frames": 5,
			"strike": [
				_phase({"dx": -5, "dy": -2, "rot": -12, "legs": 4, "torso": -10, "bob": -4, "t": 0.14}),
				_phase({"approach": 0.6, "walk": true, "t": 0.18}),
				_phase({"approach": 1.0, "rot": 190, "dy": -8, "t": 0.14}),
				_phase({"approach": 1.0, "rot": 350, "dy": -4, "sx": 1.1, "sy": 0.93, "t": 0.07, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "rot": 372, "t": 0.10}),
				_phase({"approach": 0.0, "rot": 360, "walk": true, "t": 0.24}),
			]},
		# Palm strike: closes quietly, then one short sharp push.
		"palm": {"kind": "melee", "sfx": "attack_impact", "shake": 6.0,
			"clip": "res://assets/images/characters/maria_punch", "frames": 5,
			"strike": [
				_phase({"approach": 0.55, "walk": true, "t": 0.20}),
				_phase({"approach": 1.0, "walk": true, "t": 0.15}),
				_phase({"approach": 1.0, "dx": -5, "dy": 3, "legs": 6, "torso": -7, "head": 4, "t": 0.10}),
				_phase({"approach": 1.0, "dx": 9, "dy": -1, "sx": 1.1, "sy": 0.94, "t": 0.05, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dx": 4, "t": 0.10}),
				_phase({"approach": 0.0, "walk": true, "t": 0.22}),
			]},
		# Sliding sweep: drops low on the way in and takes the legs.
		"sweep": {"kind": "melee", "sfx": "attack_impact", "shake": 9.0,
			"clip": "res://assets/images/characters/maria_kick", "frames": 5,
			"strike": [
				_phase({"dx": -4, "dy": 6, "legs": 12, "sy": 0.92, "t": 0.14}),
				_phase({"approach": 0.65, "dy": 14, "rot": -8, "sx": 1.12, "sy": 0.82, "t": 0.20}),
				_phase({"approach": 1.0, "dy": 16, "rot": -12, "sx": 1.16, "sy": 0.8, "t": 0.09, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dy": 6, "rot": -4, "sy": 0.94, "t": 0.13}),
				_phase({"approach": 0.0, "walk": true, "t": 0.24}),
			]},
		# Two quick jabs, the second one carrying the weight.
		"doublejab": {"kind": "melee", "sfx": "tile_tap", "shake": 5.0,
			"clip": "res://assets/images/characters/maria_punch", "frames": 5,
			"strike": [
				_phase({"approach": 0.6, "walk": true, "t": 0.18}),
				_phase({"approach": 1.0, "walk": true, "t": 0.14}),
				_phase({"approach": 1.0, "dx": 7, "rot": 5, "sx": 1.05, "t": 0.05}),
				_phase({"approach": 1.0, "dx": 1, "rot": 0, "t": 0.05}),
				_phase({"approach": 1.0, "dx": 10, "rot": 8, "sx": 1.08, "sy": 0.95, "t": 0.05, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dx": 5, "rot": 3, "t": 0.09}),
				_phase({"approach": 0.0, "walk": true, "t": 0.22}),
			]},
		# Axe kick: rises high on the approach, then drops the heel.
		"axekick": {"kind": "melee", "sfx": "attack_impact", "shake": 10.0,
			"clip": "res://assets/images/characters/maria_kick", "frames": 5,
			"strike": [
				_phase({"approach": 0.55, "walk": true, "t": 0.20}),
				_phase({"approach": 1.0, "dy": -24, "rot": -5, "sy": 1.12, "bob": -8, "t": 0.15}),
				_phase({"approach": 1.0, "dy": 8, "rot": 6, "sx": 1.12, "sy": 0.85, "t": 0.06, "contact": true}),
			],
			"recover": [
				_phase({"approach": 1.0, "dy": 1, "sy": 0.97, "t": 0.12}),
				_phase({"approach": 0.0, "walk": true, "t": 0.24}),
			]},
	}

## Which attack comes next. Never the same one twice running -- random that
## repeats itself reads as broken rather than random.
var _last_player_attack: String = ""
## The style currently mid-swing, so _player_attack_recover() knows whether it
## has a walk home to play and whether the raised z-order needs dropping.
var _player_attack: Dictionary = {}
## Projectile flight still outstanding from the release beat. A phase can only
## report its own duration, so the launch records here and _play_player_attack
## counts it down as the follow-through plays over the top of the flight.
var _pending_flight: float = 0.0

## The kinds of the last two attacks, so a third of the same kind can be ruled
## out. Uniform random over ten styles is genuinely fair but streaky, and a run
## of four melee in a row reads as "the player only ever charges" -- which is
## exactly how an even 5/5 split got mistaken for an all-melee pool.
var _recent_kinds: Array[String] = []

func _pick_player_attack(pool: Dictionary) -> String:
	var keys: Array = pool.keys().filter(
		func(s: String) -> bool: return s != _last_player_attack)
	if keys.is_empty():
		keys = pool.keys()

	# Two of a kind already: the third must be the other kind.
	if _recent_kinds.size() >= 2 and _recent_kinds[0] == _recent_kinds[1]:
		var wanted := "ranged" if _recent_kinds[0] == "melee" else "melee"
		var switched: Array = keys.filter(
			func(s: String) -> bool: return String(pool[s].get("kind", "")) == wanted)
		if not switched.is_empty():
			keys = switched

	_last_player_attack = keys[randi() % keys.size()]
	_recent_kinds.push_back(String(pool[_last_player_attack].get("kind", "")))
	while _recent_kinds.size() > 2:
		_recent_kinds.pop_front()
	return _last_player_attack

## Runs an attack up to and including the moment it lands.
##
## Returns with the hit already delivered, so the caller can play the rival's
## flinch and apply damage while a melee attacker is still standing over them.
## _player_attack_recover() must be called afterwards, whatever happens next --
## it is what walks a melee attacker home and restores the z-order.
func _play_player_attack(tier: Dictionary) -> void:
	var pool := _attack_pool(GameState.character)
	_player_attack = pool[_pick_player_attack(pool)]
	var melee: bool = _player_attack.get("kind", "ranged") == "melee"
	# A longer word commits the body further. This scales the motion, never the
	# distance travelled -- that is set by where the rival actually stands.
	var power: float = clampf(float(tier.get("lunge", 20.0)) / 26.0, 0.6, 1.6)

	_body_begin(player_character, BODY_FEET)
	if melee:
		# Crossing the field means passing over the board, which is drawn after
		# the characters; the rival's melee skills raise themselves the same way.
		_body_bring_forward(player_character)
	var dist := _player_melee_dx() if melee else 0.0
	player_character.rig_enable()

	_pending_flight = 0.0
	for phase: Dictionary in _player_attack["strike"]:
		var spent := await _run_attack_phase(phase, dist, power, tier)
		_pending_flight = maxf(0.0, _pending_flight - spent)
	# A ranged attack lands when its projectile arrives, not when the arm stops.
	if _pending_flight > 0.0:
		await get_tree().create_timer(_pending_flight).timeout
		_pending_flight = 0.0

## Walks a melee attacker home and puts everything back. Safe to call for a
## ranged attack, which simply plays its follow-through in place.
func _player_attack_recover() -> void:
	if _player_attack.is_empty():
		return
	var dist := _player_melee_dx() if _player_attack.get("kind", "") == "melee" else 0.0
	for phase: Dictionary in _player_attack.get("recover", []):
		await _run_attack_phase(phase, dist, 1.0, {})
	if player_character.is_rigged():
		player_character.rig_disable()
	player_character.play_idle()
	_body_send_back(player_character)
	await _body_end(player_character, 0.14)
	_player_attack = {}

## One phase of an attack. Returns how long it took, so the caller can subtract
## it from any projectile flight still outstanding.
func _run_attack_phase(phase: Dictionary, dist: float, power: float,
		tier: Dictionary) -> float:
	var t := float(phase.get("t", 0.12))
	var hit: bool = bool(phase.get("release", false)) or bool(phase.get("contact", false))

	if hit:
		# The rig has to come down before the attack clip can show: the rig is a
		# slice of whichever frame was up when it was raised, so the clip would
		# otherwise play underneath it, invisible.
		if player_character.is_rigged():
			player_character.rig_disable()
		# Each style plays ITS OWN frames. Before this every attack -- punch,
		# kick, throw alike -- ran the single shared attack clip, in which Juan
		# only extends his arm to point a pen and Maria only moves her
		# ponytail. No amount of stance, travel or timing work could make a
		# kick read as a kick while the arm was doing the same thing every time.
		var clip := String(_player_attack.get("clip", ""))
		if clip.is_empty() or not player_character.play_clip(
				clip, int(_player_attack.get("frames", 0))):
			player_character.play_attack()
		Audio.play_sfx(String(_player_attack.get("sfx", "attack_impact")))

	if bool(phase.get("release", false)):
		_pending_flight = _launch_bolts(player_character, enemy_character,
			Color(1, 0.86, 0.42, 0.95), int(tier.get("bolts", 1)),
			float(tier.get("bolt_size", 14.0)), float(tier.get("rate", 1.0)))
	elif bool(phase.get("contact", false)):
		# A melee hit has no projectile to sell it, so the impact carries the
		# whole blow: a ring at the point of contact, spatter, and a shake.
		_fx_ring(enemy_character, Color(1, 0.9, 0.55, 0.9), 54.0, 0.24)
		_fx_splatter(enemy_character, Color(1, 0.86, 0.42, 0.95), 4, 20.0, 0.4)
		_shake_screen(float(_player_attack.get("shake", 7.0)))
	elif bool(phase.get("walk", false)) and player_character.walk_count >= 2:
		# Real leg animation for the run-in, rather than the rig's paper stride.
		if player_character.is_rigged():
			player_character.rig_disable()
		player_character.play_walk()
	elif player_character.is_rigged():
		player_character.rig_pose(
			float(phase.get("legs", 0.0)), float(phase.get("torso", 0.0)),
			float(phase.get("head", 0.0)), float(phase.get("bob", 0.0)), 0.0, t)

	await _body_play(player_character, [_beat(
		float(phase.get("approach", 0.0)) * dist + float(phase.get("dx", 0.0)) * power,
		float(phase.get("dy", 0.0)) * power,
		float(phase.get("rot", 0.0)),
		float(phase.get("sx", 1.0)), float(phase.get("sy", 1.0)),
		t, Tween.TRANS_QUAD,
		Tween.EASE_OUT if hit else Tween.EASE_IN_OUT)])
	return t

# --- body choreography ----------------------------------------------------
#
# Each character has exactly one 7-frame attack clip, so the sprite alone can
# only ever show one arm motion. The body is animated on top of it instead:
# where the rival stands, which way it leans, what it pivots around and how it
# squashes. Anticipation, overshoot and settle are what make a snap of the
# fingers read differently from a two-handed slam using the same frames.
#
# Beats are offsets from the resting stance, so a choreography reads as motion
# rather than as a list of absolute coordinates. Negative dx is toward the
# player, who stands to the rival's left.

## What the rotation and scale happen around. Pivoting at the feet reads as the
## whole body leaning; at the chest as a twist; at the head as a topple.
const BODY_FEET := Vector2(0.5, 1.0)
const BODY_CHEST := Vector2(0.5, 0.4)
const BODY_CENTRE := Vector2(0.5, 0.5)

## The rival's stance before a performance, so every beat is relative and the
## body always returns exactly where it started.
## Keyed BY CHARACTER, not one shared slot. The player and the rival can both
## be mid-choreography at once -- a rival's turn beginning while the player is
## still walking home overwrote the player's rest pose, and the walk then had
## nowhere to return to. The symptom was the player stranded at contact range,
## which made every following attack look like a melee one whatever it was.
var _body_home: Dictionary = {}

## Where `who` was standing when its choreography began, or where it is now if
## it has none captured. Never indexes blind: a missing entry used to throw and
## abandon whatever walk was in progress.
func _body_home_x(who: Control) -> float:
	if _body_home.has(who):
		return float((_body_home[who]["pos"] as Vector2).x)
	return who.position.x

func _beat(dx: float, dy: float, deg: float, sx: float, sy: float, secs: float,
		trans: Tween.TransitionType = Tween.TRANS_SINE,
		ease: Tween.EaseType = Tween.EASE_IN_OUT) -> Dictionary:
	return {"dx": dx, "dy": dy, "deg": deg, "sx": sx, "sy": sy, "secs": secs,
		"trans": trans, "ease": ease}

func _body_begin(who: Control, pivot: Vector2) -> void:
	_body_home[who] = {
		"pos": who.position, "rot": who.rotation,
		"scale": who.scale, "pivot": who.pivot_offset,
	}
	# Safe to move the pivot only while the node is unrotated and unscaled —
	# which it is at rest. Moving it later would visibly jump the sprite.
	who.pivot_offset = Vector2(who.size.x * pivot.x, who.size.y * pivot.y)

func _body_play(who: Control, beats: Array) -> void:
	if not _body_home.has(who):
		return
	var home: Vector2 = _body_home[who]["pos"]
	for beat: Dictionary in beats:
		var tween := create_tween().set_parallel(true)
		var secs: float = beat["secs"]
		tween.tween_property(who, "position", home + Vector2(beat["dx"], beat["dy"]), secs) \
			.set_trans(beat["trans"]).set_ease(beat["ease"])
		tween.tween_property(who, "rotation", deg_to_rad(beat["deg"]), secs) \
			.set_trans(beat["trans"]).set_ease(beat["ease"])
		tween.tween_property(who, "scale", Vector2(beat["sx"], beat["sy"]), secs) \
			.set_trans(beat["trans"]).set_ease(beat["ease"])
		await tween.finished

func _body_end(who: Control, secs: float = 0.18) -> void:
	if not _body_home.has(who):
		return
	var home: Dictionary = _body_home[who]
	var tween := create_tween().set_parallel(true)
	tween.tween_property(who, "position", home["pos"], secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(who, "rotation", home["rot"], secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(who, "scale", home["scale"], secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	who.pivot_offset = home["pivot"]
	# Only this character's entry -- clearing the lot would strand anyone else
	# who happens to be mid-move.
	_body_home.erase(who)

## Fires the sprite's arm clip WITHOUT waiting for it, so it overlaps the body
## choreography instead of adding its full second on top. Used only on the
## moves where the rival actually strikes — the ones that gesture, retreat or
## lecture deliberately never call it, which is itself part of how they read
## as different actions.
func _body_swing(who: AnimatedCharacter) -> void:
	# A skill with its own generated clip swings with THAT; everything else
	# falls back to the rival's shared attack. Read from _signature_move rather
	# than threaded through fifteen signatures that would all pass it along
	# unchanged.
	if _signature_move != null and not _signature_move.attack_dir.is_empty():
		if who.play_clip(_signature_move.attack_dir, _signature_move.attack_count):
			return
	who.play_attack()

# --- melee: crossing the battlefield --------------------------------------
#
# Most skills are fought at range, but a handful should close the distance and
# hit you where you stand. The rival really does travel — it is not the same
# pose slid leftward — because the gait itself (a stride, a leap, a low creep)
# is chosen per skill and carries its own lean, bob and squash.

## Where a melee attacker comes to rest: just off the player's shoulder, near
## enough to strike without standing inside them.
const MELEE_GAP := 22.0
## Where a dash-through carries on to, past the player and off the left edge.
const MELEE_THROUGH_X := -150.0

## The line the fighters stand on, in the current layout. Effects that erupt
## from or land on the ground were written against the authored y=438 floor and
## have to follow the stage wherever it moved to.
func _stage_floor() -> float:
	return player_character.position.y + player_character.size.y

## How far the player must travel from its rest pose to bring its own visible
## edge MELEE_GAP from the rival's. The mirror of _melee_target_x, and measured
## the same way for the same reason: node bounds leave 374px of transparent air
## between the two, so a lunge sized in node pixels never arrives.
##
## Nothing calls this today — Juan and Maria fight purely at range and hold
## their ground. It is kept as the hook for a player melee skill, which is the
## one case that SHOULD cross the field; see the note above _ranged_styles.
func _player_melee_dx() -> float:
	return AnimatedCharacter.melee_rest_x(
		player_character, enemy_character, MELEE_GAP, true) 		- _body_home_x(player_character)

func _melee_target_x() -> float:
	# Measured between the VISIBLE bodies, not the node rectangles. Each
	# character is a narrow sprite inside a wider transparent canvas inside a
	# wider node again, so node-to-node spacing came to rest 85-97px apart --
	# four times this gap -- and the blows plainly never reached.
	return AnimatedCharacter.melee_rest_x(enemy_character, player_character, MELEE_GAP)

## The rival is drawn before the board, so anything that crosses the field
## would slide underneath the letters. Melee moves lift it above them for the
## duration and put it back afterwards.
## Whoever is currently crossing the field — a rival on a melee skill, or the
## player on any of its physical swings. Only ever one at a time: the two never
## travel in the same beat.
var _travel_layer_home: int = -1
## Which node the slot above belongs to. Tracked by identity, not just by "is
## something raised", so a stray send_back can never drop one fighter at the
## other's z-index — the two use the same single slot and only differ by who
## happens to be crossing.
var _travel_layer_node: Control = null

func _body_bring_forward(who: Control) -> void:
	if _travel_layer_node != null:
		return
	_travel_layer_node = who
	_travel_layer_home = who.get_index()
	move_child(who, board.get_index())

func _body_send_back(who: Control) -> void:
	if _travel_layer_node != who:
		return
	move_child(who, _travel_layer_home)
	_travel_layer_node = null
	_travel_layer_home = -1

## Plays travel beats with the cut-out rig driving a stride underneath them.
##
## This is the difference between walking and sliding: the beats move the
## rival across the field, while the rig swings its legs about the hip, leans
## the torso against the swing and bobs the whole figure on each step. The rig
## is always handed back before the strike, because the hand-drawn attack clip
## needs the flat sprite visible to play.
func _body_play_walking(who: AnimatedCharacter, beats: Array, cadence: float = 12.0) -> void:
	# Hand-drawn legs beat a cut-out every time. The rig exists for the rivals
	# that have no walk cycle; one that does gets its real frames instead.
	if who.walk_count >= 2:
		who.play_walk()
		for beat: Dictionary in beats:
			await _body_play(who, [beat])
		who.play_idle()
		return
	who.rig_enable()
	var step := 0
	for beat: Dictionary in beats:
		var swing: float = cadence * (1.0 if step % 2 == 0 else -1.0)
		# Torso counter-rotates against the legs and the head against the
		# torso, which is what stops a swinging cut-out reading as a hinge.
		who.rig_pose(swing, -swing * 0.34, swing * 0.16,
			-3.0 if step % 2 == 0 else 0.0, 0.0, float(beat["secs"]))
		await _body_play(who, [beat])
		step += 1
	who.rig_pose(0.0, 0.0, 0.0, 0.0, 0.0, 0.08)
	await get_tree().create_timer(0.09).timeout
	who.rig_disable()

## The travel itself, as beats relative to the resting stance. Each gait moves
## the same distance but arrives telling a different story.
func _melee_advance(gait: String, secs: float) -> Array:
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	match gait:
		"charge":
			# Drops low, then accelerates the whole way in, leaning further
			# forward the closer it gets. The lean is deliberately shallower
			# than it looks on paper: the rig adds its own torso tilt on top of
			# whatever the body does, and the two used to compound into a figure
			# that read as falling over rather than charging.
			return [
				_beat(14, 10, -6, 1.08, 0.9, secs * 0.3, Tween.TRANS_QUAD, Tween.EASE_OUT),
				_beat(dx * 0.45, -6, 11, 1.05, 0.98, secs * 0.4, Tween.TRANS_QUAD, Tween.EASE_IN),
				_beat(dx, 2, 15, 1.08, 0.95, secs * 0.3, Tween.TRANS_QUAD, Tween.EASE_IN),
			]
		"lunge":
			# Coils, then one airborne arc that lands heavily.
			return [
				_beat(16, 12, -10, 1.1, 0.86, secs * 0.34, Tween.TRANS_QUAD, Tween.EASE_OUT),
				_beat(dx * 0.55, -40, -2, 0.94, 1.12, secs * 0.36, Tween.TRANS_QUAD, Tween.EASE_OUT),
				_beat(dx, 6, 14, 1.14, 0.86, secs * 0.3, Tween.TRANS_QUAD, Tween.EASE_IN),
			]
		"creep":
			# Stays in a deep crouch the whole way, hugging the floor.
			return [
				_beat(4, 18, 0, 1.14, 0.76, secs * 0.26, Tween.TRANS_QUAD, Tween.EASE_OUT),
				_beat(dx * 0.5, 20, 7, 1.14, 0.76, secs * 0.42),
				_beat(dx, 20, 11, 1.14, 0.76, secs * 0.32),
			]
		"dash":
			# Straight through at speed, barely touching down.
			return [
				_beat(16, 6, -12, 1.02, 1.0, secs * 0.3, Tween.TRANS_QUAD, Tween.EASE_OUT),
				_beat(dx, -4, -11, 1.06, 0.96, secs * 0.7, Tween.TRANS_QUAD, Tween.EASE_IN),
			]
		_:
			# "walk" — an unhurried four-step approach with a bob on each step.
			var steps := 4
			var walk: Array = []
			for i in steps:
				var f := float(i + 1) / float(steps)
				walk.append(_beat(dx * f, -6.0 if i % 2 == 0 else 1.0, 5.0 if i % 2 == 0 else 8.0,
					1.0, 0.99, secs / float(steps), Tween.TRANS_SINE, Tween.EASE_IN_OUT))
			return walk

## Walking it back, deliberately less urgent than the way in.
func _melee_retreat(secs: float, gait: String = "walk") -> Array:
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	if gait == "hop":
		return [
			_beat(dx * 0.6, -22, -8, 0.96, 1.08, secs * 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT),
			_beat(0, 0, 0, 1.0, 1.0, secs * 0.5, Tween.TRANS_QUAD, Tween.EASE_IN),
		]
	return [
		_beat(dx * 0.7, -3, -6, 1.0, 1.0, secs * 0.45, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_beat(dx * 0.3, 1, -4, 1.0, 1.0, secs * 0.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_beat(0, 0, 0, 1.0, 1.0, secs * 0.25, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	]

## Entry point. Falls back to the old style-based patterns for any move without
## a signature, so an unfinished or renamed skill still animates.
func _play_signature_move(move: EnemyMove) -> void:
	var move_id := move.signature_id() if move != null else ""
	var tint: Color = move.effect_color if move != null else Color(0.75, 0.35, 0.85, 0.95)
	_signature_move = move
	Audio.play_move_sfx(move_id, "cast")
	match move_id:
		"padrino_favor": await _sig_padrino_favor(move_id, tint)
		"dynasty_power": await _sig_dynasty_power(move_id, tint)
		"smear_campaign": await _sig_smear_campaign(move_id, tint)
		"ballot_defacer": await _sig_ballot_defacer(move_id, tint)
		"poster_paste": await _sig_poster_paste(move_id, tint)
		"spray_and_run": await _sig_spray_and_run(move_id, tint)
		"filibuster": await _sig_filibuster(move_id, tint)
		"sabaw_splash": await _sig_sabaw_splash(move_id, tint)
		"word_salad": await _sig_word_salad(move_id, tint)
		"ghost_payroll": await _sig_ghost_payroll(move_id, tint)
		"tong_collection": await _sig_tong_collection(move_id, tint)
		"under_the_table": await _sig_under_the_table(move_id, tint)
		"medical_mission": await _sig_medical_mission(move_id, tint)
		"relief_goods_blitz": await _sig_relief_goods_blitz(move_id, tint)
		"tarpaulin_wall": await _sig_tarpaulin_wall(move_id, tint)
		_:
			var style: String = move.animation_style if move != null else "lunge"
			await _play_move_animation(style, tint)
			Audio.play_move_sfx(move_id, "hit")

# --- Lord Trapo -----------------------------------------------------------

## A snap of the fingers and a phone call. He barely moves: a small rise onto
## the toes, a flick of the wrist, and the favour arrives from off screen. The
## least physical attack in the game, and deliberately so.
func _sig_padrino_favor(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	_fx_charge(enemy_character, tint, 0.5)
	_fx_word("☎ RING…", enemy_character, Color(1, 0.9, 0.6))
	_fx_ring(enemy_character, tint, 54.0, 0.34)
	_fx_ring(enemy_character, tint, 54.0, 0.34, 0.18)
	await _body_play(enemy_character, [
		_beat(0, -3, -3, 1.0, 1.02, 0.26),                                    # settles back, unbothered
		_beat(0, -5, 4, 1.0, 1.03, 0.10, Tween.TRANS_BACK, Tween.EASE_OUT),   # the snap
		_beat(0, -1, 0, 1.0, 1.0, 0.14),
	])

	# Comes in from beyond the right edge: the favour, not the man.
	var offscreen := Control.new()
	offscreen.position = Vector2(Layout.profile.design_size.x + 60.0,
		player_character.position.y + 40.0)
	offscreen.size = Vector2(2, 2)
	_fx_node(offscreen, 1.0)
	_spawn_bolt(offscreen, player_character, tint, 17.0, 0.34, 0.0, 0.0, false)
	await get_tree().create_timer(0.34).timeout

	_fx_impact(move_id, 5.0, tint, 0.18)
	await _body_end(enemy_character)

## MELEE — charge. Three generations bearing down on you: he drops low, strides
## the whole field leaning further in with every step, and brings both arms
## down on you at point-blank range. The heaviest attack in the game.
func _sig_dynasty_power(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	_body_bring_forward(enemy_character)
	for i in 3:
		_fx_ring(enemy_character, tint, 46.0 + 22.0 * float(i), 0.36, 0.13 * float(i))
	_fx_charge(enemy_character, tint, 0.55)
	await _body_play_walking(enemy_character, _melee_advance("charge", 0.62), 16.0)

	# Arrives, rears up over the player, then drives down.
	_body_swing(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx, -18, -14, 1.06, 1.14, 0.16, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(dx - 10, 12, 20, 1.16, 0.84, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_impact(move_id, 15.0, tint, 0.34)
	_fx_ring(player_character, tint, 150.0, 0.45)
	_fx_splatter(player_character, tint, 4, 24.0, 0.5)
	await _body_play(enemy_character, [
		_beat(dx - 4, 6, 12, 1.08, 0.94, 0.18, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	await _body_play_walking(enemy_character, _melee_retreat(0.44), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## A sidearm fling: he twists away to load the throw, then whips across his
## body and overshoots. Rotation carries this one, not forward travel.
func _sig_smear_campaign(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_CHEST)
	_fx_charge(enemy_character, tint, 0.3)
	await _body_play(enemy_character, [
		_beat(14, 2, -20, 0.96, 1.0, 0.24, Tween.TRANS_QUAD, Tween.EASE_OUT),     # winds away
	])
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(-18, 0, 24, 1.04, 0.98, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN),     # whips across
	])
	for i in 9:
		_spawn_bolt(enemy_character, player_character, tint, randf_range(7.0, 15.0),
			TRAVEL_TIME * 0.95, 0.035 * float(i), randf_range(-40.0, 40.0), true)
	await _body_play(enemy_character, [
		_beat(-8, 0, 14, 1.0, 1.0, 0.2, Tween.TRANS_BACK, Tween.EASE_OUT),        # follow through
	])
	await get_tree().create_timer(TRAVEL_TIME * 0.7).timeout

	_fx_impact(move_id, 6.0, tint, 0.2)
	_fx_splatter(player_character, tint, 8, 26.0, 0.7)
	await _body_end(enemy_character)

# --- Vote Vandal ----------------------------------------------------------

## All wrist: he hunches over the ballot and scribbles, four quick alternating
## jerks. No forward travel at all — this is defacing, not striking.
func _sig_ballot_defacer(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_CHEST)
	_fx_charge(enemy_character, tint, 0.26)
	_fx_word("VOID", enemy_character, tint, 20.0)
	await _body_play(enemy_character, [
		_beat(-6, 6, 9, 1.0, 0.95, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT),        # hunches over
	])
	var scribble: Array = []
	for i in 4:
		var swing := 8.0 if i % 2 == 0 else -6.0
		scribble.append(_beat(-6 + swing * 0.4, 6, 9 + swing, 1.0, 0.95, 0.07,
			Tween.TRANS_QUAD, Tween.EASE_IN_OUT))
		_fx_slab(enemy_character, player_character, tint, Vector2(30, 3),
			0.16, 0.055 * float(i), randf_range(-16.0, 16.0), randf_range(-0.9, 0.9), 1)
	await _body_play(enemy_character, scribble)

	# The cross-out itself, drawn on the player.
	for angle in [0.7, -0.7]:
		var stroke := Panel.new()
		stroke.add_theme_stylebox_override("panel", _fx_style(tint, 1))
		stroke.size = Vector2(52, 4)
		stroke.pivot_offset = stroke.size * 0.5
		stroke.position = player_character.position + player_character.size * 0.5 - stroke.size * 0.5
		stroke.rotation = angle
		_fx_node(stroke, 0.5)
		var fade := create_tween()
		fade.tween_interval(0.28)
		fade.tween_property(stroke, "modulate:a", 0.0, 0.2)
	_fx_impact(move_id, 6.0, tint, 0.2)
	await _body_end(enemy_character)

## MELEE — walk up and slap. He strolls over at his own pace, reaches high, and
## pastes the tarpaulin straight onto you from arm's length.
func _sig_poster_paste(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	_body_bring_forward(enemy_character)
	_fx_charge(enemy_character, tint, 0.3)
	await _body_play_walking(enemy_character, _melee_advance("walk", 0.68), 13.0)

	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx + 4, -18, -8, 0.92, 1.18, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT),  # reaches up
	])
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx - 12, 10, 20, 1.14, 0.86, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),   # slaps it on
	])

	# Sticks flat over the player for a beat before peeling off.
	var poster := Panel.new()
	poster.add_theme_stylebox_override("panel", _fx_style(tint, 2))
	poster.size = Vector2(46, 36)
	poster.position = player_character.position + player_character.size * 0.5 - poster.size * 0.5
	_fx_node(poster, 0.9)
	var peel := create_tween()
	peel.tween_interval(0.5)
	peel.tween_property(poster, "modulate:a", 0.0, 0.3)
	peel.parallel().tween_property(poster, "position:y", poster.position.y + 18.0, 0.3)

	_fx_impact(move_id, 7.0, tint, 0.22)
	await _body_play_walking(enemy_character, _melee_retreat(0.5), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## MELEE — dash through. He blurs across the whole field, tags you in passing,
## and keeps going off the far edge before slinking back. The only attack that
## does not stop when it reaches you.
func _sig_spray_and_run(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	_body_bring_forward(enemy_character)
	_fx_charge(enemy_character, tint, 0.3)
	await _body_play(enemy_character, [
		_beat(10, 12, 0, 1.1, 0.82, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT),        # crouches to launch
	])
	await _body_play_walking(enemy_character, _melee_advance("dash", 0.3), 15.0)

	# The tag happens in passing, not from a stop.
	_fx_impact(move_id, 4.0, tint, 0.16)
	_fx_word("TAGGED", player_character, tint, 18.0)
	for i in 6:
		_spawn_bolt(player_character, player_character, tint, randf_range(5.0, 9.0),
			0.22, 0.02 * float(i), randf_range(-20.0, 20.0), true)
	_fx_splatter(player_character, tint, 4, 20.0, 0.5)

	# Straight out the far side, then back as if nothing happened.
	var home := Vector2(_body_home_x(enemy_character), enemy_character.position.y)
	var through := create_tween()
	through.tween_property(enemy_character, "position:x", MELEE_THROUGH_X, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	through.parallel().tween_property(enemy_character, "modulate:a", 0.1, 0.2)
	await through.finished
	enemy_character.position.x = home.x + 150.0
	var slink := create_tween()
	slink.tween_property(enemy_character, "position:x", home.x, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slink.parallel().tween_property(enemy_character, "modulate:a", 1.0, 0.26)
	await slink.finished
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

# --- Senator Sabaw --------------------------------------------------------

## Rocks back and forth on his heels, lecturing. Three full sways, no forward
## travel, no strike — the body language of somebody running out the clock.
func _sig_filibuster(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	for i in 3:
		_fx_word(["MR. SPEAKER…", "AS I WAS SAYING…", "POINT OF ORDER…"][i],
			enemy_character, tint, 22.0, 0.26 * float(i), 10)
	_fx_charge(enemy_character, tint, 0.9)
	await _body_play(enemy_character, [
		_beat(6, -2, -7, 1.0, 1.02, 0.24),      # leans back, hands behind
		_beat(-4, 0, 6, 1.0, 1.0, 0.24),        # forward for emphasis
		_beat(6, -2, -7, 1.0, 1.02, 0.24),      # back again
		_beat(-3, 0, 4, 1.0, 1.0, 0.2),         # and again, going nowhere
	])
	_spawn_bolt(enemy_character, player_character, tint, 24.0, TRAVEL_TIME * 1.6, 0.0, -18.0, true)
	await get_tree().create_timer(TRAVEL_TIME * 1.6).timeout

	# A dull tap, not a blow.
	_fx_impact(move_id, 2.5, tint, 0.12)
	await _body_end(enemy_character)

## MELEE — lunge. He coils, leaps the gap in one arc, and throws the pot into
## your face on landing. "No further questions."
func _sig_sabaw_splash(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	_body_bring_forward(enemy_character)
	_fx_charge(enemy_character, tint, 0.34)
	_fx_ring(enemy_character, tint, 34.0, 0.3)
	await _body_play_walking(enemy_character, _melee_advance("lunge", 0.56), 7.0)

	_body_swing(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx + 6, -6, -18, 0.94, 1.1, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT),  # winds the pot back
		_beat(dx - 14, 4, 16, 1.12, 0.9, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),    # throws it
	])
	_fx_impact(move_id, 8.0, tint, 0.26)
	_fx_ring(player_character, tint, 92.0, 0.34)
	for i in 8:
		_spawn_bolt(player_character, player_character, tint, randf_range(5.0, 11.0),
			0.3, 0.02 * float(i), randf_range(-50.0, 50.0), true)
	_fx_splatter(player_character, tint, 6, 24.0, 0.55)
	await _body_play_walking(enemy_character, _melee_retreat(0.44, "hop"), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## Flails: he wobbles side to side gesticulating at nothing, bobbing as he
## goes. The only choreography with no stable pose at any point.
func _sig_word_salad(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_CHEST)
	var letters := ["A", "E", "R", "S", "T", "O", "N", "I"]
	for i in 4:
		_fx_word(letters[randi() % letters.size()], enemy_character,
			Color(randf_range(0.6, 1.0), randf_range(0.6, 1.0), randf_range(0.6, 1.0)),
			16.0, 0.07 * float(i), 12)
	_fx_charge(enemy_character, tint, 0.38)
	await _body_play(enemy_character, [
		_beat(-5, -4, 13, 1.03, 1.0, 0.11, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(7, 3, -14, 0.97, 1.02, 0.11, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(-7, -5, 15, 1.04, 0.98, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(5, 2, -10, 0.98, 1.01, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	for i in 10:
		_fx_slab(enemy_character, player_character,
			Color(randf_range(0.55, 1.0), randf_range(0.55, 1.0), randf_range(0.55, 1.0), 0.95),
			Vector2(randf_range(7.0, 13.0), randf_range(7.0, 13.0)), TRAVEL_TIME * 1.05,
			0.03 * float(i), randf_range(-40.0, 40.0), randf_range(-4.0, 4.0), 2)
	await _body_play(enemy_character, [
		_beat(-9, 0, 8, 1.02, 1.0, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	await get_tree().create_timer(TRAVEL_TIME * 0.85).timeout

	_fx_impact(move_id, 5.5, tint, 0.2)
	await _body_end(enemy_character)

# --- Kapitan Komisyon -----------------------------------------------------

## Turns his back and signs the names in, then glances round. He never faces
## the player and never advances — the attack happens behind him.
func _sig_ghost_payroll(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	var pale := Color(tint.r, tint.g, tint.b, 0.45)
	for i in 3:
		_fx_word("†", enemy_character, pale, 30.0, 0.16 * float(i), 14)
	_fx_charge(enemy_character, tint, 0.6)
	await _body_play(enemy_character, [
		_beat(14, 0, -12, 0.9, 1.0, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT),   # turns away, narrows
		_beat(18, 2, -14, 0.86, 1.0, 0.22),                                   # hunched over the book
		_beat(16, 0, -10, 0.9, 1.0, 0.18),                                    # a glance back
	])
	for i in 3:
		_fx_slab(enemy_character, player_character, pale, Vector2(14, 20),
			TRAVEL_TIME * 1.7, 0.14 * float(i), randf_range(-12.0, 12.0), 0.0, 6)
	await get_tree().create_timer(TRAVEL_TIME * 1.7 + 0.2).timeout

	_fx_impact(move_id, 3.5, tint, 0.24)
	_fx_word("+34 NAMES", player_character, pale, 22.0, 0.0, 10)
	await _body_end(enemy_character)

## Beckons with an open palm, then snatches his cut back. Forward then sharply
## away — the only move whose strongest motion is retreating.
func _sig_tong_collection(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_CHEST)
	for i in 3:
		_fx_ring(enemy_character, tint, 26.0, 0.24, 0.09 * float(i))
	_fx_charge(enemy_character, tint, 0.34)
	await _body_play(enemy_character, [
		_beat(-14, 2, 11, 1.02, 0.99, 0.26, Tween.TRANS_QUAD, Tween.EASE_OUT),    # leans in, palm out
		_beat(-16, 3, 13, 1.03, 0.98, 0.1),                                       # waits for it
	])
	for i in 5:
		_fx_slab(enemy_character, player_character, tint, Vector2(11, 11),
			TRAVEL_TIME * 1.1, 0.05 * float(i), 34.0 + randf_range(-10.0, 10.0),
			randf_range(4.0, 8.0), 6)
	await _body_play(enemy_character, [
		_beat(20, -4, -15, 0.97, 1.02, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT),   # snatches it away
	])
	await get_tree().create_timer(TRAVEL_TIME * 0.9).timeout

	_fx_impact(move_id, 7.0, tint, 0.24)
	_fx_word("₱ COLLECTED", player_character, tint, 22.0, 0.0, 10)
	await _body_end(enemy_character)

## MELEE — creep. He drops into a crouch and stays there the whole way across,
## slides it to you on the floor, then strikes upward from beneath.
func _sig_under_the_table(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	_body_bring_forward(enemy_character)
	_fx_charge(enemy_character, tint, 0.42)
	await _body_play_walking(enemy_character, _melee_advance("creep", 0.74), 6.0)

	var dx := _melee_target_x() - _body_home_x(enemy_character)
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx - 8, 22, 14, 1.16, 0.74, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN),   # slides it under
	])

	# Strikes upward from beneath the player.
	var spike := Panel.new()
	spike.add_theme_stylebox_override("panel", _fx_style(tint, 2, 10.0))
	spike.size = Vector2(16, 8)
	spike.position = Vector2(
		player_character.position.x + player_character.size.x * 0.5 - 8.0,
		_stage_floor() + 8.0)
	_fx_node(spike, 0.5)
	var rise := create_tween()
	rise.tween_property(spike, "size", Vector2(16, 92), 0.14)
	rise.parallel().tween_property(spike, "position:y", _stage_floor() - 84.0, 0.14)
	rise.tween_property(spike, "modulate:a", 0.0, 0.2)

	_fx_impact(move_id, 9.0, tint, 0.24)
	await _body_play(enemy_character, [
		_beat(dx, 16, 4, 1.1, 0.8, 0.16),                                           # settles back down
	])
	await _body_play_walking(enemy_character, _melee_retreat(0.56), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

# --- Ate Ayuda ------------------------------------------------------------

## Poses for the cameras: draws up to her full height, holds it for the photo,
## then jabs. The only choreography that deliberately pauses mid-attack.
func _sig_medical_mission(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	for arm in [Vector2(26, 7), Vector2(7, 26)]:
		var bar := Panel.new()
		bar.add_theme_stylebox_override("panel", _fx_style(Color(1, 1, 1, 0.92), 1))
		bar.size = arm
		bar.position = enemy_character.position + Vector2(
			enemy_character.size.x * 0.5 - arm.x * 0.5, 6.0)
		_fx_node(bar, 0.55)
		var fade := create_tween()
		fade.tween_interval(0.3)
		fade.tween_property(bar, "modulate:a", 0.0, 0.22)
	_fx_charge(enemy_character, tint, 0.42)
	await _body_play(enemy_character, [
		_beat(0, -8, 5, 1.0, 1.07, 0.26, Tween.TRANS_SINE, Tween.EASE_OUT),       # draws herself up
		_beat(0, -8, -5, 1.0, 1.07, 0.22),                                        # turns for the photo
		_beat(0, -8, 0, 1.0, 1.07, 0.14),                                         # holds the pose
	])
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(-18, -2, 9, 1.06, 0.98, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),     # the jab
	])
	_fx_slab(enemy_character, player_character, Color(0.92, 1.0, 0.98, 0.95),
		Vector2(120, 5), 0.18, 0.0, 0.0, 0.0, 2)
	await get_tree().create_timer(0.2).timeout

	_fx_impact(move_id, 5.0, Color(1, 1, 1, 1), 0.3)
	await _body_end(enemy_character)

## MELEE — advance and shove. She walks right up and hurls three sacks into you
## point-blank, each one heavier than the last.
func _sig_relief_goods_blitz(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_CHEST)
	_body_bring_forward(enemy_character)
	_fx_charge(enemy_character, tint, 0.36)
	await _body_play_walking(enemy_character, _melee_advance("walk", 0.6), 13.0)

	var dx := _melee_target_x() - _body_home_x(enemy_character)
	Audio.play_move_sfx(move_id, "hit")
	for i in 3:
		var effort := 1.0 + 0.14 * float(i)
		await _body_play(enemy_character, [
			_beat(dx + 12, 3, -17 * effort, 0.96, 1.02, 0.14, Tween.TRANS_QUAD, Tween.EASE_OUT),
			_beat(dx - 14, -2, 17 * effort, 1.08, 0.94, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN),
		])
		if i == 0:
			_body_swing(enemy_character)
		_shake_screen(5.0 + 3.0 * float(i))
		_fx_splatter(player_character, tint, 3, 18.0, 0.45)
		_fx_ring(player_character, tint, 40.0 + 14.0 * float(i), 0.22)
	_fx_flash(tint, 0.24)
	await _body_play_walking(enemy_character, _melee_retreat(0.5), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## Spreads both arms wide to unfurl the banner, then sweeps it across. The
## widest stance in the game — she takes up the whole screen before the tarp
## even arrives.
func _sig_tarpaulin_wall(move_id: String, tint: Color) -> void:
	_body_begin(enemy_character, BODY_FEET)
	_fx_charge(enemy_character, tint, 0.44)
	_fx_word("VOTE 1", enemy_character, tint, 22.0, 0.0, 13)
	await _body_play(enemy_character, [
		_beat(4, -10, 0, 1.22, 1.06, 0.3, Tween.TRANS_QUAD, Tween.EASE_OUT),      # arms thrown wide
		_beat(6, -12, -4, 1.26, 1.08, 0.14),                                      # holds it open
	])

	# One enormous banner sweeping in from off the right edge.
	var tarp := Panel.new()
	tarp.add_theme_stylebox_override("panel", _fx_style(
		Color(tint.r, tint.g, tint.b, 0.88), 3, 14.0))
	tarp.size = Vector2(430, 250)
	tarp.position = Vector2(Layout.profile.design_size.x + 40.0,
		player_character.position.y - 40.0)
	tarp.pivot_offset = tarp.size * 0.5
	tarp.rotation = 0.12
	_fx_node(tarp, 1.0)
	var sweep := create_tween()
	sweep.tween_property(tarp, "position:x", player_character.position.x - 20.0, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	sweep.parallel().tween_property(tarp, "rotation", 0.0, 0.26)
	await _body_play(enemy_character, [
		_beat(-14, -4, 11, 1.1, 1.0, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN),      # sweeps it across
	])

	_fx_impact(move_id, 13.0, tint, 0.3)
	var drop := create_tween()
	drop.tween_interval(0.16)
	drop.tween_property(tarp, "position:y", _stage_floor() + 30.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	drop.parallel().tween_property(tarp, "modulate:a", 0.0, 0.3)
	await _body_end(enemy_character)

## Legacy five-pattern fallback, kept for any move without a signature.
func _play_move_animation(style: String, tint: Color) -> void:
	match style:
		"volley":
			# Three shots, the rival rocking back with each recoil.
			_lunge(enemy_character, 10.0)
			if enemy_character.play_attack():
				await enemy_character.one_shot_finished
			await _spawn_bolts(enemy_character, player_character, tint, 3, 16.0, 0.85)
			_shake_screen(3.0)
		"slam":
			# No projectile at all — the rival looms, then the screen takes it.
			_lunge(enemy_character, 34.0)
			if enemy_character.play_attack():
				await enemy_character.one_shot_finished
			await get_tree().create_timer(0.10).timeout
			_shake_screen(11.0)
			await get_tree().create_timer(0.18).timeout
		"spray":
			# A wide fan of small motes on staggered arcs.
			if enemy_character.play_attack():
				await enemy_character.one_shot_finished
			var travel := TRAVEL_TIME * 0.9
			for i in 7:
				_spawn_bolt(enemy_character, player_character, tint, randf_range(8.0, 13.0),
					travel, 0.04 * float(i), randf_range(-34.0, 34.0), true)
			await get_tree().create_timer(travel + 0.28).timeout
			_shake_screen(2.0)
		"curse":
			# One slow drifting mote — unhurried and harder to ignore.
			if enemy_character.play_attack():
				await enemy_character.one_shot_finished
			_spawn_bolt(enemy_character, player_character, tint, 22.0,
				TRAVEL_TIME * 2.1, 0.0, -26.0, true)
			await get_tree().create_timer(TRAVEL_TIME * 2.1).timeout
		_:
			# "lunge" — one fast bolt with the rival driving in behind it.
			_lunge(enemy_character, 24.0)
			if enemy_character.play_attack():
				await enemy_character.one_shot_finished
			await _spawn_bolts(enemy_character, player_character, tint, 1, 20.0, 0.75)
			_shake_screen(4.0)

## The board's Mudslinging Tile went unaddressed too long and detonated. This
## fires mid-submission, before the player's swing has even played, so it just
## banks a bonus for _resolve_enemy_turn to add to that exchange's attack —
## the enemy's turn was going to happen regardless (Phase 0).
func _on_mud_detonated() -> void:
	_pending_enemy_damage += MUD_DAMAGE_BONUS

func _end_match(player_won: bool) -> void:
	_match_over = true
	if not player_won:
		# Losing rewinds the whole chapter, not just this fight, and wipes the
		# potion stock back to baseline — the doc's penalty for poor resource
		# management. Winning keeps whatever you saved.
		GameState.reset_chapter()
		Audio.play_sting("defeat")
		result_label.text = "Try Again"
		result_overlay.show()
		return

	Audio.play_sting("victory")
	if GameState.has_next_encounter():
		_advance_to_next_encounter()
		return
	_finish_chapter()

func _finish_chapter() -> void:
	var title := GameState.chapter.chapter_name if GameState.chapter != null else ""
	result_label.text = "Chapter Complete!\n%s" % title
	result_overlay.show()
	# Persisted immediately, before reset_chapter() below touches anything —
	# this records the TIER just cleared. The certificate needs Easy, Medium
	# and Hard all recorded before it unlocks, and has to survive the app
	# closing, not just this run.
	GameState.mark_difficulty_completed(GameState.chapter_number(), GameState.difficulty)
	# Beating the boss rewinds to the top so Try Again is a fresh run rather
	# than dropping the player back onto an already-cleared boss.
	GameState.reset_chapter()

## The walk between encounters, staged as the reference doc describes it:
## the beaten rival clears out to the right, the player marches after them,
## and the next encounter is standing there when the screen comes back.
##
## The swap happens under a full-screen veil rather than on camera because the
## battle lives in one fixed layout — there is no scrolling world to travel
## through, so the veil is what sells "somewhere further down the road".
func _advance_to_next_encounter() -> void:
	_sequence_running = true
	_update_action_buttons()

	await _play_enemy_retreat()
	await _play_player_walk()
	await _fade_veil(1.0)

	GameState.advance_encounter()
	player_character.position.x = _player_home_x
	player_character.play_idle()
	enemy_character.modulate.a = 1.0
	_start_encounter(false)
	# _start_encounter hands control back to the player, but the banner and the
	# fade-in still have to play — without re-locking, the countdown for the
	# question it just dealt would drain behind the veil.
	_sequence_running = true

	await _show_encounter_banner()
	# The victory sting replaced the looping battle track and does not loop
	# itself, so the music has to be restarted explicitly — otherwise every
	# encounter after the first would be fought in silence.
	Audio.play_music("battle")
	await _fade_veil(0.0)

	_sequence_running = false
	_update_action_buttons()

## Defeated rival slides off to the right and fades — the visual counterpart to
## the doc's "enemy defeat animation" beat before the walk begins.
func _play_enemy_retreat() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(enemy_character, "position:x",
		enemy_character.position.x + 70.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(enemy_character, "modulate:a", 0.0, 0.6)
	await tween.finished
	enemy_character.position.x -= 70.0

func _play_player_walk() -> void:
	player_character.play_walk()
	var tween := create_tween()
	tween.tween_property(player_character, "position:x",
		_player_home_x + WALK_DISTANCE, WALK_TIME).set_trans(Tween.TRANS_SINE)
	await tween.finished

func _fade_veil(target_alpha: float) -> void:
	transition_veil.show()
	var tween := create_tween()
	tween.tween_property(transition_veil, "color:a", target_alpha, VEIL_TIME)
	await tween.finished
	if is_equal_approx(target_alpha, 0.0):
		transition_veil.hide()

func _show_encounter_banner() -> void:
	banner_title_label.text = "CHAPTER BOSS" if _enemy.is_boss else "Encounter %d of %d" % [
		GameState.encounter_number(), GameState.encounter_total()]
	banner_name_label.text = "%s — %s" % [_enemy.enemy_name, _enemy.title]
	encounter_banner.show()
	await get_tree().create_timer(BANNER_TIME).timeout
	encounter_banner.hide()
