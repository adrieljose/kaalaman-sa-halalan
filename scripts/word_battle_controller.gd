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
## How much of the Chapter 4 boss's health his one-time last stand gives back.
## Low enough that the fight is nearly over, high enough that "NOT YET." is a
## real second act rather than a formality.
const CH4_LAST_STAND_FRACTION := 0.22
## Phase 2 of the Chapter 4 boss. "Slightly" is the brief's own word: a sixth
## more damage and a sixth quicker, which is felt without being a different
## fight.
const CH4_PHASE2_DAMAGE_GAIN := 1.16
const CH4_PHASE2_PACE := 0.84
## Chapter 5's boss. HOUSE IN SESSION at half health, then FINAL READING in the
## last quarter -- and the two stack, so the closing stage of the last fight in
## the game is the hardest the game ever gets while still being only a fifth
## above phase 2.
const CH5_PHASE2_DAMAGE_GAIN := 1.15
const CH5_PHASE2_PACE := 0.85
const CH5_FINAL_READING_AT := 0.22
const CH5_FINAL_READING_GAIN := 1.20
const CH5_FINAL_READING_PACE := 0.76
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
const MOVE_IDLE_DESC_COLOR := Color(0.60, 0.56, 0.48)
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
var _hud_chapter_plate: PanelContainer
## Which phase the current rival is in, 1-based. Only a rival that declares
## phase_thresholds ever leaves phase 1, so every Chapter 1 encounter sits at 1
## for its whole fight and none of the phase code below does anything.
var _boss_phase: int = 1
## Guards the transformation so a single damage event that crosses two
## thresholds at once still resolves them one at a time, in order.
var _phase_changing: bool = false
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
## The console buttons' authored styleboxes, by node. See _style_console().
var _console_button_boxes: Dictionary = {}
var _moves_open: bool = false
## When the current word was started, in milliseconds. Set on the tap that
## takes the selection from empty to one letter, so the clock measures the time
## spent building THIS word rather than time spent staring at the board first.
var _selection_started_ms: int = 0
## The potential-damage plate and the row it shares with the countdown bar.
## Built in code for the same reason the HUD is -- see _build_damage_badge().
var _damage_badge: DamageBadge
var _damage_row: HBoxContainer
## The coaching overlay, non-null only while GameState.tutorial_mode is set.
## Doubles as the mode flag inside this scene -- "is the tutorial running" and
## "is there a director on screen" must be the same question.
var _tutorial: TutorialDirector

func _exit_tree() -> void:
	Audio.reset_voice()

func _ready() -> void:
	# Re-applied on every load rather than only when the menu sets it, so the
	# pool is correct after Try Again and when this scene is booted directly.
	# Chapter comes along with it: questions are scoped to the topic of the
	# chapter being played, not drawn from one generic election pool.
	QuestionBank.set_context(GameState.chapter_number(), GameState.difficulty)
	player_character.configure_clips(GameState.character_clips())
	_question_time = GameState.question_seconds()
	# Named for what it does — it rerolls the question, not the letters. It fits
	# unabbreviated on a phone now that the potions have moved off this row; the
	# layout passes set it too, so this is only about the very first frame.
	shuffle_button.text = "New Question"
	shuffle_button.add_theme_font_size_override("font_size", 12)
	_screen_home = position
	# Captured before anything re-styles them, so the WIDE layout can hand the
	# authored sunken "well" boxes back verbatim.
	for button in [shuffle_button, attack_button, menu_button]:
		_console_button_boxes[button] = button.get_theme_stylebox("normal")
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
	_build_damage_badge()
	# Before _start_encounter, so the first question is presented into a layout
	# that is already the right shape. bind() runs the pass immediately and then
	# keeps us subscribed, which is what makes rotating the device mid-fight work.
	Layout.bind(self, "_apply_layout")
	_start_encounter(true)
	Audio.play_music("battle")
	if GameState.tutorial_mode:
		_begin_tutorial()

# --- responsive layout ----------------------------------------------------
#
# The battle scene was authored entirely in absolute offsets against a 640x480
# canvas. Rather than re-author it, the layout below re-places the same nodes
# per arrangement. WIDE reproduces the authored composition exactly (see
# _layout_battle_wide), so a 4:3 window is unchanged.

## Scales an effect's particle/projectile count to what this device should be
## asked to draw.
##
## Every effect still plays and still looks like itself — this thins density,
## it never removes a move. The heaviest single frames in the game are the
## signature moves: _sig_word_salad alone allocates ~14 Control nodes and ~32
## tweens, each with its own StyleBoxFlat, and every one of them is a real node
## in the tree rather than a particle system.
##
## Never returns less than one, so a move whose whole identity is "it throws a
## thing" still throws the thing.
func _fx_count(n: int) -> int:
	if n <= 1:
		return n
	return maxi(1, int(round(float(n) * Layout.profile.fx_budget)))

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

## The floor line for the room being fought in, falling back to the authored
## default for every room that has not needed correcting.
##
## Read from EnemyData rather than a table keyed by texture path: the room is
## already a property of the encounter, and a lookup by filename would silently
## stop matching the day a backdrop is renamed or a phase swaps the texture out.
func _ground_fraction() -> float:
	var data: EnemyData = _enemy if _enemy != null else GameState.current_enemy()
	if data != null and data.ground_fraction > 0.0:
		return data.ground_fraction
	return BATTLE_GROUND_FRACTION

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
	_refresh_damage_preview()
	# After the board exists, and before the shadows are captured: this nudges
	# fighters sideways, and a shadow captured first would be left behind.
	_respect_board_safe_zone()
	# Re-read: the safe zone may have moved the player, and the walk between
	# encounters returns them to this x.
	_player_home_x = player_character.position.x
	_ensure_shadows()
	TouchFeedback.apply_to_tree(self)

## Minimum clear space between the letter board and a fighter's VISIBLE edge,
## in design units. Small enough that the composition stays close, wide enough
## that a wind-up or a held prop does not immediately cross the board.
const BOARD_SAFE_GAP := 16.0
## How close a fighter's visible edge may come to the screen edge.
const STAGE_EDGE_MARGIN := 2.0

## Keeps both fighters out of the board's safe zone.
##
## The rivals are not all the same width. Measured across their idle sheets the
## visible body runs from 163px (Auditor Alibi) to 210px (Contractor Kutsaba,
## Bokal Bulsa) inside the same 256px canvas -- so placing every rival by the
## same node centre puts the WIDE ones a great deal closer to the board than the
## narrow ones, which is why Kutsaba crowds it and Alibi does not. Nothing was
## wrong with his coordinates; the node box simply says nothing about where the
## body's left edge is.
##
## So the gap is measured from the visible body (body_rect) rather than the
## node, and only the fighters that actually breach it are moved -- and only far
## enough to clear it. A rival already comfortably clear is left exactly where
## the layout put it.
func _respect_board_safe_zone() -> void:
	if board_frame == null or not is_instance_valid(board_frame):
		return
	var frame := board_frame.get_global_rect()
	if frame.size.x <= 0.0:
		return
	var limit: float = Layout.profile.design_size.x

	# The rival stands to the RIGHT of the board: its visible LEFT edge is what
	# can crowd it.
	if enemy_character != null:
		var body := enemy_character.body_rect()
		var want: float = frame.end.x + BOARD_SAFE_GAP - body.position.x
		if enemy_character.position.x < want:
			# Never so far that the far shoulder leaves the screen.
			var most: float = limit - STAGE_EDGE_MARGIN - body.end.x
			enemy_character.position.x = minf(want, maxf(most, enemy_character.position.x))

	# The player stands to the LEFT: its visible RIGHT edge is the one at risk.
	if player_character != null:
		var pbody := player_character.body_rect()
		var pwant: float = frame.position.x - BOARD_SAFE_GAP - pbody.end.x
		if player_character.position.x > pwant:
			var least: float = STAGE_EDGE_MARGIN - pbody.position.x
			player_character.position.x = maxf(pwant, minf(least, player_character.position.x))

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
		# The pillars were pinned at absolute insets tuned for a 640-wide bar.
		# The bar is 480 wide here, which put them at 204 and 264 and left a
		# 48px gap between them -- narrower than the 124px chapter ribbon meant
		# to sit inside it, so the pillars painted over the first and last
		# letters ("CHAPTER 2" read as "HAPTER") and squeezed the chapter-name
		# plate to 32px for 127px of text ("CITY HALL SHADOWS" read as "CIT").
		#
		# Deriving them from the bar's own width keeps the centre section
		# proportional at any size. At 640 this lands within a few pixels of the
		# old constants, so the desktop bar is unchanged.
		"pillar_a_x": _hud_pillar_a(w), "pillar_b_x": _hud_pillar_b(w),
		"centre_x": _hud_pillar_a(w) + HUD_PILLAR_W,
		"centre_r": _hud_pillar_b(w),
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
	# The wooden bar and its three inset wells come back — a compact layout
	# swapped both out, and rotating a tablet back to landscape has to undo it.
	console_bar.visible = true
	for button in [shuffle_button, attack_button, menu_button]:
		_restore_console(button)
		button.clip_text = false
		button.custom_minimum_size = Vector2.ZERO
		button.add_theme_font_size_override("font_size", 12)
	shuffle_button.text = "New Question"
	potion_row.add_theme_constant_override("separation", 4)
	purify_potion_button.visible = false
	for potion in [health_potion_button, power_potion_button]:
		potion.custom_minimum_size = Vector2(60.0, 32.0)
		potion.expand_icon = false
		potion.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		potion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		potion.add_theme_font_size_override("font_size", 10)
	_place_node(potion_panel, Rect2(inset + 10.0, 55.0, 208.0, 83.0))
	# Eight units taller than the authored 84 -- the badge row costs twenty and
	# the prompt was already using every line it had, so paying for it out of
	# the question text would have clipped a three-line prompt. The panel now
	# ends at 146 instead of 138, which is why the tray below moved with it.
	_place_node(question_panel, Rect2(inset + 220.0, 54.0, 259.0, 92.0))
	_size_damage_row(20.0, false)
	_place_node(side_panel, Rect2(inset + 480.0, 55.0, 150.0, 81.0))
	_place_fighter_pair(
		Rect2(inset + 37.0, 258.0, 130.0, 180.0),
		Rect2(inset + 478.0, 265.0, 130.0, 180.0),
		1.0)
	# _start_encounter() first assigns the new room, then re-runs this layout so
	# the encounter's staging offsets can take effect. Compact layouts realign
	# the backdrop inside _place_stage(), but WIDE goes straight through
	# _place_fighter_pair(); without this matching pass the room stayed aligned
	# to the pre-offset player floor. Encounters with a positive Y correction
	# consequently floated above their own painted floor by that correction.
	_place_battle_background(profile.design_size, _stage_floor())
	_place_node(word_tray, Rect2(inset, 149.0, 640.0, 30.0))
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
	#
	# The potions share the move-strip row rather than the action bar below.
	# Two chips plus three labelled buttons on one 320-unit line leaves every
	# label touching its own border — "New Question" could not fit at all, which
	# is what forced the unreadable "New Q". Lifting the potions out gives the
	# three actions a full row to themselves and costs ten units of height,
	# where a second action row would have cost fifty and come out of the board.
	var y: float = _hud["height"] + gap
	_prepare_compact_potions()
	var strip_h := 34.0
	var potion_w: float = maxf(potion_panel.get_combined_minimum_size().x, 74.0)
	_place_node(_move_strip, Rect2(margin, y, w - potion_w - gap, strip_h))
	_place_node(potion_panel, Rect2(margin + w - potion_w, y, potion_w, strip_h))
	y += strip_h + gap
	# Raised from 0.10/58..78 to pay for the damage row without taking the
	# increase out of the prompt, which on a 320-unit-wide canvas already wraps
	# to three or four lines.
	var question_h: float = clampf(d.y * 0.125, 76.0, 96.0)
	_place_node(question_panel, Rect2(margin, y, w, question_h))
	_size_damage_row(18.0, false)
	var content_top: float = y + question_h + gap

	# --- from the bottom
	var rows := _compact_action_rows(w, true, false)
	var controls_h: float = (TOUCH_TARGET + 8.0) if rows == 1 		else (TOUCH_TARGET * 2.0 + 13.0)
	var controls_y: float = d.y - margin * 0.7 - controls_h
	_layout_compact_controls(Rect2(margin, controls_y, w, controls_h), true, false, rows)

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
	# The tightest of the three: a rotated phone gives about 270 units of height
	# for a question, a word tray, two fighters and a control bar. The badge
	# rides at 16 and drops its " DMG" suffix (see DamageBadge.set_terse), and
	# the fourteen units the panel gains come out of the stage below, which has
	# its own floor and can absorb them.
	_place_node(question_panel, Rect2(margin, y, col_w, 60.0))
	_size_damage_row(16.0, true)
	y += 60.0 + gap
	var tray_h := 22.0
	_place_node(word_tray, Rect2(margin, y, col_w, tray_h))
	_place_node(word_preview_label, Rect2(margin, y, col_w, tray_h))
	word_preview_label.visible = false
	y += tray_h + gap

	# A rotated phone has no vertical room for a second deck, so the bar stays
	# one row here whatever the measurement says — but the column is wide enough
	# (about 355 units) that all four fit comfortably anyway.
	var controls_h := 34.0
	var controls_y: float = d.y - margin - controls_h
	_layout_compact_controls(Rect2(margin, controls_y, col_w, controls_h), false, true, 1)

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
	_place_fighter_pair(
		Rect2(area.position.x + 4.0, floor_y - h, w, h),
		Rect2(area.end.x - 4.0 - w, floor_y - h, w, h),
		clampf(area.size.x / 640.0, 0.45, 1.0))
	# The backdrop follows the fighters rather than the other way round. Read the
	# actual soles back after _place_fighter_pair(): an encounter may add a
	# player_battle_offset.y staging correction, and aligning to the uncorrected
	# area edge leaves both fighters floating by exactly that amount.
	_place_battle_background(Layout.profile.design_size, _stage_floor())

## Applies the small per-room staging corrections stored on EnemyData while
## keeping each sprite's feet as the scale pivot. The room texture never
## changes: only the two fighter rects do.
func _place_fighter_pair(player_rect: Rect2, enemy_rect: Rect2,
		offset_scale: float) -> void:
	var data: EnemyData = _enemy if _enemy != null else GameState.current_enemy()
	var scale := 1.0
	var player_offset := Vector2.ZERO
	var enemy_offset := Vector2.ZERO
	if data != null:
		scale = clampf(data.battle_scale, 0.75, 1.5)
		player_offset = data.player_battle_offset * offset_scale
		enemy_offset = data.enemy_battle_offset * offset_scale
	# ONE floor for both. The authored WIDE composition stands them on lines
	# seven pixels apart (438 and 445), which was invisible while both were
	# floating by different amounts and becomes a visible step now that each is
	# grounded on its real soles. A room paints one walkable line, so both
	# fighters get it, and enemy_battle_offset.y stays available as a deliberate
	# per-room nudge on top.
	var floor_y: float = player_rect.end.y + player_offset.y
	var p_rect := _scaled_fighter_rect(player_rect, scale, player_offset)
	_place_node(player_character, p_rect)
	_stand_on_floor(player_character, floor_y)
	var enemy_scale := scale * (data.enemy_battle_scale if data != null else 1.0)
	var e_rect := _scaled_fighter_rect(enemy_rect, enemy_scale, enemy_offset)
	_place_node(enemy_character, e_rect)
	_stand_on_floor(enemy_character, floor_y + enemy_offset.y)

## Drops a fighter so its DRAWN SOLES land on `floor_y`, rather than its node box.
##
## The node box is a bad proxy for the body, and by two stacking paddings. A
## frame is a small figure on a larger transparent canvas -- Chapter 3's rivals
## carry 10px of nothing below the feet in a 320px canvas -- and that canvas is
## then letterboxed inside the node by KEEP_ASPECT_CENTERED, which for a 256x320
## sheet in a 130x180 node adds another ~8.75px underneath. Aligning the node's
## BOTTOM to the floor therefore hangs the rival ~14px above it, while the
## player, whose 73x180 sheet needs almost no letterboxing and has 4px of
## padding, hangs by ~4px. Different amounts, so they do not even float
## together: the pair read as standing on two different floors.
##
## body_rect() already resolves both paddings and caches per texture, so the
## correction is simply the distance from wherever the soles ended up to where
## the floor is. Nothing is hardcoded and nothing needs per-character tuning:
## a rival with a differently padded sheet is grounded by the same arithmetic.
func _stand_on_floor(who: AnimatedCharacter, floor_y: float) -> void:
	if who == null:
		return
	var body := who.body_rect()
	if body.size.y <= 0.0:
		return
	who.position.y += floor_y - (who.position.y + body.end.y)

func _scaled_fighter_rect(rect: Rect2, scale: float, offset: Vector2) -> Rect2:
	var scaled_size := rect.size * scale
	return Rect2(
		Vector2(rect.position.x - (scaled_size.x - rect.size.x) * 0.5,
			rect.end.y - scaled_size.y) + offset,
		scaled_size)

# --- floor shadows --------------------------------------------------------

var _shadows: BattleShadows = null

## Puts a shadow under each fighter and tells it where their feet rest.
##
## Called from the end of the layout pass rather than from _place_stage,
## because the wide arrangement never goes through _place_stage at all — it
## reproduces the authored composition, which stands the two fighters on lines
## SEVEN PIXELS APART (438 and 445). There is no single stage floor to hand
## over, so each character's ground is read back off its own placed rect
## instead, which also means this needs no argument and cannot disagree with
## the layout that just ran.
##
## The layer's tree position is the whole of its correctness: Godot draws
## siblings in tree order, so immediately BELOW the player character is the only
## index where a shadow lands on the backdrop and its props while still passing
## under both fighters. One index later and each character stands in front of
## its own shadow.
func _ensure_shadows() -> void:
	if _shadows == null or not is_instance_valid(_shadows):
		_shadows = BattleShadows.new()
		add_child(_shadows)
		_shadows.add_subject(player_character)
		_shadows.add_subject(enemy_character)
	# move_child re-inserts into the list the node has already been REMOVED
	# from, so landing immediately before the player means aiming one lower
	# whenever the layer currently sits above it. Getting this wrong makes the
	# layer leapfrog the player on alternate layout passes.
	var before: int = player_character.get_index()
	if _shadows.get_index() < before:
		before -= 1
	move_child(_shadows, before)
	# Safe here and only here: the layout has just written every fighter's rect,
	# so they are standing at rest whatever the combat choreography was doing a
	# moment ago.
	_shadows.capture_floors()

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
	var g := _ground_fraction()
	var s: float = maxf(d.x / ts.x, stage_floor / g / ts.y)
	var drawn := ts * s
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.anchor_left = 0.0
	background.anchor_top = 0.0
	background.anchor_right = 0.0
	background.anchor_bottom = 0.0
	var rect := Rect2((d.x - drawn.x) * 0.5,
		stage_floor - drawn.y * g, drawn.x, drawn.y)
	_place_node(background, rect)
	_build_props(rect)

# --- ambient props --------------------------------------------------------
#
# Rooms are single images, so anything that moves in one is a sprite composited
# over it. The props sit on their own layer directly above the backdrop and
# below the fighters, which is the only place they can go: Godot draws siblings
# in tree order, so a prop added at the end would paint over the characters.
#
# Every position is a fraction of the DRAWN backdrop rather than a pixel offset
# (see AmbientProps), so the props follow the art when the backdrop is rescaled
# for a phone instead of drifting off it.

var _prop_layer: Control = null
var _props: Array = []
var _palace_environment: Control = null
var _ch5_chamber: Control = null

func _sync_ch5_chamber(drawn: Rect2) -> void:
	if GameState.chapter_number() != 5 or _enemy == null:
		if is_instance_valid(_ch5_chamber): _ch5_chamber.queue_free()
		_ch5_chamber = null
		return
	if not is_instance_valid(_ch5_chamber):
		_ch5_chamber = preload("res://scripts/environments/congress_environment.gd").new()
		_ch5_chamber.name = "Chapter5Chamber"
		add_child(_ch5_chamber)
		_ch5_chamber.configure(GameState.encounter_index)
		move_child(_ch5_chamber, background.get_index() + 1)
	_place_node(_ch5_chamber, drawn)
	_ch5_chamber.adapt_to_layout(Layout.profile.design_size)

func _clear_palace_environment() -> void:
	if is_instance_valid(_palace_environment):
		_palace_environment.stop()
		_palace_environment.queue_free()
	_palace_environment = null
	background.show()

func _sync_palace_environment(drawn: Rect2) -> bool:
	if GameState.chapter_number() != 4:
		_clear_palace_environment()
		return false
	if not is_instance_valid(_palace_environment):
		_palace_environment = preload("res://scripts/environments/palace_environment.gd").new()
		_palace_environment.name = "PalaceEnvironment"
		add_child(_palace_environment)
		_palace_environment.setup(GameState.encounter_index)
		move_child(_palace_environment, background.get_index()+1)
	_place_node(_palace_environment,drawn)
	_palace_environment.adapt_to_layout(Layout.profile.design_size)
	background.hide()
	return true

## Changes the room. Always use this rather than assigning background.texture:
## the props belong to the backdrop, and the layout pass that would rebuild
## them has already run by the time an encounter picks its room, so a bare
## assignment leaves the previous room's props hanging in the new one.
func _set_room(texture: Texture2D) -> void:
	background.texture = texture
	# _stage_floor() reads the floor back off the player's placed rect, so this
	# needs no state of its own -- but it is only meaningful once the layout
	# pass has actually placed the fighters.
	if player_character != null and player_character.size.y > 0.0:
		_place_battle_background(Layout.profile.design_size, _stage_floor())

## Rebuilds the prop layer for the current room. Called from
## _place_battle_background, so it re-runs on rotation and on every encounter.
func _build_props(drawn: Rect2) -> void:
	_sync_ch5_chamber(drawn)
	if is_instance_valid(_ch5_chamber):
		background.hide()
		if is_instance_valid(_prop_layer):
			for child in _prop_layer.get_children(): child.queue_free()
		_props.clear()
		return
	if _sync_palace_environment(drawn):
		if is_instance_valid(_prop_layer):
			for child in _prop_layer.get_children(): child.queue_free()
		_props.clear()
		return
	if _prop_layer == null:
		_prop_layer = Control.new()
		_prop_layer.name = "PropLayer"
		_prop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_prop_layer)
	# Directly above the backdrop, and therefore behind everything else.
	move_child(_prop_layer, background.get_index() + 1)

	for child in _prop_layer.get_children():
		child.queue_free()
	_props.clear()

	var budget: float = Layout.profile.fx_budget
	for row in AmbientProps.for_background(background.texture):
		var frames := AmbientProps.load_clip(String(row.get("clip", "")))
		if frames.is_empty():
			continue
		# Phones thin the scatter rather than dropping props entirely, so every
		# room still reads as the same room on every device.
		var count: int = maxi(1, int(round(float(row.get("count", 1)) * budget)))
		for i in count:
			_props.append(_make_prop(row, frames, drawn, i, count))

func _make_prop(row: Dictionary, frames: Array[Texture2D], drawn: Rect2,
		index: int, count: int) -> Dictionary:
	var node := TextureRect.new()
	node.texture = frames[0]
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: float = drawn.size.x * float(row.get("scale", 0.1))
	var h: float = w * (float(frames[0].get_height()) / float(frames[0].get_width()))
	node.size = Vector2(w, h)
	node.pivot_offset = node.size * 0.5
	_prop_layer.add_child(node)

	# Copies of one prop are spread across the room and started out of step, so
	# a count of five reads as five things rather than one thing five times.
	var spread: float = 0.0 if count <= 1 else (float(index) / float(count - 1) - 0.5)
	var home := Vector2(
		drawn.position.x + drawn.size.x * (float(row.get("u", 0.5)) + spread * 0.16),
		drawn.position.y + drawn.size.y * float(row.get("v", 0.3)))
	node.position = home - node.size * 0.5

	return {
		"node": node, "frames": frames, "home": home,
		"fps": float(row.get("fps", 8.0)),
		"drift": row.get("drift", Vector2.ZERO) as Vector2,
		"sway": float(row.get("sway", 0.0)),
		"t": float(index) * 0.7,          # phase offset
		"travel": 0.0,
		"jolt": 0.0,
		"drawn": drawn,
	}

## Advances every prop. Called from _process ahead of its early returns,
## because scenery must keep moving during an attack sequence -- that is when
## the player is actually looking at the room.
func _tick_props(delta: float) -> void:
	for p in _props:
		var node: TextureRect = p["node"]
		if not is_instance_valid(node):
			continue
		p["t"] = float(p["t"]) + delta
		var frames: Array = p["frames"]
		node.texture = frames[int(float(p["t"]) * float(p["fps"])) % frames.size()]

		var drawn: Rect2 = p["drawn"]
		var pos: Vector2 = p["home"]
		var drift: Vector2 = p["drift"]
		if drift != Vector2.ZERO:
			p["travel"] = float(p["travel"]) + delta
			var d: Vector2 = drift * drawn.size * float(p["travel"])
			# Falling props loop back to the top instead of leaving the room
			# empty after a few seconds.
			var span: float = drawn.size.y * 0.55
			if drift.y > 0.0 and d.y > span:
				p["travel"] = 0.0
				d = Vector2.ZERO
			pos += d

		if float(p["sway"]) > 0.0:
			node.rotation = deg_to_rad(sin(float(p["t"]) * 1.6) * float(p["sway"]))

		if float(p["jolt"]) > 0.001:
			p["jolt"] = float(p["jolt"]) * maxf(0.0, 1.0 - delta * 6.0)
			var j: float = float(p["jolt"])
			pos += Vector2(randf_range(-j, j), randf_range(-j, j))

		node.position = pos - node.size * 0.5

## The room reacting to a hit: the backdrop takes the skill's colour for a
## moment and the props are knocked about. Hooked into _fx_impact, which is the
## one beat every skill in both chapters already shares.
func _react_room(color: Color, strength: float) -> void:
	if is_instance_valid(_ch5_chamber): _ch5_chamber.react(strength)
	if is_instance_valid(_palace_environment):
		_palace_environment.react(strength)
		return
	if background != null and is_instance_valid(background):
		var tint := Color(
			1.0 + color.r * 0.30, 1.0 + color.g * 0.30, 1.0 + color.b * 0.30)
		var tween := create_tween()
		tween.tween_property(background, "modulate", tint, 0.05)
		tween.tween_property(background, "modulate", Color.WHITE, 0.30)
	for p in _props:
		p["jolt"] = clampf(strength * 0.35, 0.0, 6.0)

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
## The bottom action bar for compact layouts.
##
## `with_potions` decides whether the two potion chips ride along here or have
## been placed elsewhere by the caller. `rows` is 1 or 2 — see
## _compact_action_rows() for who decides and why.
func _layout_compact_controls(area: Rect2, tall: bool, with_potions: bool = true,
		rows: int = 1) -> void:
	console_bar.visible = false
	_prepare_compact_potions()
	_prepare_compact_actions(tall)

	# ConsoleBar sits later in the scene tree than PotionPanel, so it paints over
	# it -- invisible at 640x480 where the two never overlap, and fatal wherever
	# the panel is moved onto the bar. Lifting the panel above it is safe on
	# every layout, since on WIDE they are 400 units apart.
	if potion_panel.get_index() < console_bar.get_index():
		move_child(potion_panel, console_bar.get_index())

	var pad := 4.0
	var gap := 5.0
	var inner := Rect2(area.position + Vector2(pad, pad),
		area.size - Vector2(pad, pad) * 2.0)

	if rows >= 2:
		# Two decks. The turn actions — the two ways to spend a turn — go
		# together on the lower one, side by side and largest, where a thumb
		# rests. Everything that is not a turn action shares the deck above.
		var row_gap := 5.0
		var lower: float = maxf(inner.size.y * 0.52, TOUCH_TARGET)
		var upper: float = maxf(inner.size.y - lower - row_gap, 30.0)
		var top_row := Rect2(inner.position, Vector2(inner.size.x, upper))
		var bottom_row := Rect2(inner.position + Vector2(0.0, upper + row_gap),
			Vector2(inner.size.x, lower))
		if with_potions:
			_place_row([potion_panel, menu_button], [0.42, 0.58], top_row, gap)
		else:
			_place_row([menu_button], [1.0], top_row, gap)
		_place_row([shuffle_button, attack_button], [0.48, 0.52], bottom_row, gap)
		return

	var slots: Array[Control] = []
	var shares: Array[float] = []
	if with_potions:
		# The potions take the smallest share of the slack: they are two fixed
		# chips, and any extra width goes to them as dead wood rather than as a
		# bigger target.
		slots = [potion_panel, shuffle_button, attack_button, menu_button]
		shares = [0.16, 0.26, 0.32, 0.26]
	else:
		slots = [shuffle_button, attack_button, menu_button]
		shares = [0.36, 0.36, 0.28]
	_place_row(slots, shares, inner, gap)

## Lays `items` across `rect`, giving each one at least the width it actually
## needs and sharing whatever is left over by `shares`.
##
## Distributing by share ALONE is what broke this bar before: a button whose
## label needed more than its share silently grew past it, because a Control's
## size is clamped up to its combined minimum the moment it is assigned. Every
## caller must therefore have set text, font and chip sizes before getting here,
## or the minimums measured are the wrong ones.
func _place_row(items: Array, shares: Array, rect: Rect2, gap: float) -> void:
	if items.is_empty():
		return
	var mins: Array[float] = []
	var needed := 0.0
	for item in items:
		var m: float = (item as Control).get_combined_minimum_size().x
		mins.append(m)
		needed += m
	var inner: float = rect.size.x - gap * float(items.size() - 1)
	var spare: float = maxf(inner - needed, 0.0)
	var x: float = rect.position.x
	for i in items.size():
		var width: float = mins[i] + spare * float(shares[i])
		_place_node(items[i] as Control, Rect2(x, rect.position.y, width, rect.size.y))
		x += width + gap

## Would the four controls sit comfortably on one line at `width`, or does this
## screen need two?
##
## "Fits" is not the same as "reads well": a row packed to its exact minimum has
## every label touching its own border and looks like an accident. The slack
## factor is what separates a row that merely fits from one that looks placed.
const ONE_ROW_SLACK := 1.12

func _compact_action_rows(width: float, tall: bool, with_potions: bool) -> int:
	_prepare_compact_potions()
	_prepare_compact_actions(tall)
	var slots: Array[Control] = [shuffle_button, attack_button, menu_button]
	if with_potions:
		slots.push_front(potion_panel)
	var needed := 0.0
	for slot in slots:
		needed += slot.get_combined_minimum_size().x
	var inner: float = width - 8.0 - 5.0 * float(slots.size() - 1)
	return 1 if inner >= needed * ONE_ROW_SLACK else 2

## Text, font and clipping for the three action buttons. Everything here feeds
## their minimum width, so it must run before anything measures or places them.
func _prepare_compact_actions(tall: bool) -> void:
	shuffle_button.text = "New Question"
	var font_size: int = 12 if tall else 10
	for button in [shuffle_button, attack_button, menu_button]:
		button.custom_minimum_size = Vector2.ZERO
		button.clip_text = false
		button.add_theme_font_size_override("font_size", font_size)
	_style_console(shuffle_button, Color(0.92, 0.88, 0.80))
	_style_console(attack_button, Color(1.0, 0.86, 0.62))
	_style_console(menu_button, Color(0.86, 0.84, 0.86))

## The two potion chips, slimmed to ride in a compact row.
func _prepare_compact_potions() -> void:
	potion_title.visible = false
	purify_potion_button.visible = false
	potion_row.add_theme_constant_override("separation", 3)
	for potion in [health_potion_button, power_potion_button]:
		# Clearing the minimum is not enough on its own: the bottle icon carries
		# its own, which is what expand_icon lifts.
		potion.custom_minimum_size = Vector2(22.0, 0.0)
		potion.expand_icon = true
		potion.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Fill the row's height too, or two 16-unit-tall chips sit centred in a
		# 44-unit bar and are the smallest touch targets on the screen.
		potion.size_flags_vertical = Control.SIZE_EXPAND_FILL
		potion.add_theme_font_size_override("font_size", 8)

## Dresses a console button as a small wooden button in its own right, for
## layouts where the bar it used to be inset into is gone.
##
## The meta is cleared so TouchFeedback, which runs at the end of the layout
## pass, re-derives pressed and hover from this new box rather than keeping the
## states it worked out from the old one.
func _style_console(button: Button, tint: Color) -> void:
	var box := _nine_slice(PANEL_TEXTURE, PANEL_SLICE, 4.0)
	if box is StyleBoxTexture:
		(box as StyleBoxTexture).modulate_color = tint
	for state in ["normal", "focus"]:
		button.add_theme_stylebox_override(state, box)
	button.remove_meta("touch_feedback")

func _restore_console(button: Button) -> void:
	var box: StyleBox = _console_button_boxes.get(button)
	if box == null:
		return
	for state in ["normal", "focus"]:
		button.add_theme_stylebox_override(state, box)
	button.remove_meta("touch_feedback")

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
	_move_strip.expand_icon = true
	_move_strip.add_theme_constant_override("icon_max_width",int(MOVE_ICON_SIZE.x))
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
		_move_strip.icon = null
		_move_strip.tooltip_text = ""
		_move_strip.text = "MOVES"
		return
	# Compact Chapter 4 telegraphs use the same resource icon as the expanded list.
	_move_strip.icon = move.icon if GameState.chapter_number() in [4, 5] else null
	_move_strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if GameState.chapter_number() in [4, 5] else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	_move_strip.tooltip_text = "%s\n%s" % [move.move_name,move.description] if GameState.chapter_number() in [4, 5] else ""
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
const PAUSE_PANEL_RECT := Rect2(195.0, 115.0, 250.0, 230.0)

func _on_menu_pressed() -> void:
	Audio.play_sfx("button_click")
	_open_pause_menu()

## Actually pauses the scene tree, not just shows an overlay — the question
## countdown lives in _process, which the pause automatically freezes, so
## nothing needs to remember or restore how much time was left. The overlay
## itself is process_mode=WHEN_PAUSED (set in the scene) so its own buttons
## keep working while everything else is frozen.
func _open_pause_menu() -> void:
	Audio.reset_voice()
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
	var save_button:=Button.new()
	save_button.text="Save / Load"
	save_button.custom_minimum_size.y=30
	pause_main_panel.get_node("VBox").add_child(save_button)
	save_button.pressed.connect(func(): SaveFilePanel.open(self))
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
	if is_instance_valid(_ch5_chamber): _ch5_chamber.queue_free()
	_ch5_chamber = null
	_clear_palace_environment()
	if is_instance_valid(_player_variations): _player_variations.cancel()
	result_overlay.hide()
	if is_instance_valid(_cong_meow):
		_cong_meow.queue_free()
	_cong_meow = null
	if is_instance_valid(_regular_combat): _regular_combat.queue_free()
	_regular_combat = null
	_enemy_guard = 0.0
	_clear_enemy_guard_badge()
	_enemy = GameState.current_enemy()
	if _enemy == null:
		push_warning("WordBattleController: no encounter at index %d" % GameState.encounter_index)
		return
	enemy_character.configure_from(_enemy)
	enemy_character.enable_limb_motion(GameState.chapter_number() in [1,2])
	# Swapped here rather than in the transition because _start_encounter is the
	# one path every encounter goes through — walking in, Try Again, or booting
	# this scene directly all land on the right backdrop.
	if _enemy.background != null:
		_set_room(_enemy.background)
	# The first layout happens before _enemy is assigned. Re-run it now so an
	# encounter's sprite-only staging offsets apply on direct boot, retry, and
	# the walk into the next room.
	_apply_layout(Layout.profile)

	_enemy_hp = _enemy.max_hp
	if _enemy.moves.size() == 3 and _enemy.moves[0].signature_id() == "cong_meow_capitol_claw":
		_cong_meow = preload("res://scripts/bosses/cong_meow_boss.gd").new()
		add_child(_cong_meow)
		_cong_meow.setup(self)
	elif _enemy.moves.size() == 3 and _enemy.moves[0].signature_id().begins_with("c3combat_"):
		_regular_combat = preload("res://scripts/battle/chapter3_combat.gd").new()
		add_child(_regular_combat)
		_regular_combat.setup(self)
	# Or the first blow of this fight could be swallowed by the cooldown left
	# over from the last blow of the previous one.
	Audio.reset_voice()
	# Every encounter starts at phase 1, including a boss being retried.
	_boss_phase = 1
	_phase_changing = false
	# And with its last stand unspent. Retrying the boss should offer the same
	# fight, not a shorter one.
	_ch4_last_stand_used = false
	_ch4_last_guard_turn = -1
	_ch5_final_reading_used = false
	_ch5_final_reading_active = false
	_ch5_final_reading_turns = 0
	_ch5_move_active = false
	_ch5_ranged_contact_pending = false
	_ch5_last_guard_turn = -1
	if full_reset:
		_player_hp = GameState.player_max_hp
		if not GameState.pending_checkpoint.is_empty():
			_player_hp=int(GameState.pending_checkpoint.hp)
			GameState.pending_checkpoint.clear()
	else:
		var refund := roundi(GameState.player_max_hp * BETWEEN_ENCOUNTER_HEAL_FRACTION)
		_player_hp = mini(GameState.player_max_hp, _player_hp + refund)
	# Snapshot AFTER the between-encounter heal, before any turn or potion use.
	GameState.capture_checkpoint(_player_hp)

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
	_refresh_damage_preview()

## Pulls the next question, lays its answer out on the board, and restarts the
## countdown. The board guarantees the answer stays spellable from here on.
## `avoid_answer` guarantees the next question differs from the one it
## replaces. The bank walks a shuffled lap so consecutive pulls almost always
## differ anyway — but "almost always" is not good enough for a button whose
## whole purpose is to hand you a different question, and a lap boundary can
## legitimately repeat.
func _present_question(avoid_answer: String = "") -> void:
	# One fixed question for the whole tutorial, re-presented every time the
	# scene asks for a new one. Isolated from the bank on purpose: the lesson
	# quotes a specific word and a specific damage figure, and a real question
	# arriving after the demonstration attack would leave both cards describing
	# something that is no longer on screen. Nothing about the bank is touched,
	# so neither progress nor the question rotation is disturbed.
	if GameState.tutorial_mode:
		_question = TUTORIAL_QUESTION.duplicate()
	else:
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
		_refresh_damage_preview()
		return
	question_label.text = _format_prompt(_question)
	board.set_required_answer(_question["answer"])
	_time_left = _question_time
	_update_timer_ui()
	# Cleared so the badge does not price the new question against the previous
	# question's stopwatch. _speed_bonus() reads the same field at submit time,
	# where the board's own reseed has already restarted it -- this only matters
	# to the preview, which asks before the first letter is tapped.
	_selection_started_ms = 0
	_refresh_damage_preview()

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

## The pillars divide the bar, so they belong just outside the sections they
## divide rather than at absolute insets: hard-coded 204 / w-216 assumed a
## 640-wide bar and left only a 48px gap on the 480-wide one this actually
## renders at. Derived from the neighbours, the centre gets every pixel the
## player and rival sections are not using, at any width.
static func _hud_pillar_a(w: float) -> float:
	return HUD_LEFT_INFO_X + 94.0 + 4.0        # just right of the player ribbon

static func _hud_pillar_b(w: float) -> float:
	return w - HUD_RIGHT_INFO_INSET - HUD_PILLAR_W - 4.0

## Steps a label's font down until its text fits the width it has. The chapter
## name is the one HUD string whose length is content, not layout -- "CITY HALL
## SHADOWS" is half again as long as "BARANGAY BEGINNINGS" is wide -- so it is
## fitted rather than trimmed, and chapters 3 to 5 inherit that for free.
static func _fit_label_font(label: Label, width: float,
		start: int = 12, floor_size: int = 7) -> void:
	var font: Font = label.get_theme_font("font")
	if font == null or label.text.is_empty():
		return
	var size := start
	while size > floor_size and font.get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	label.add_theme_font_size_override("font_size", size)

func _build_hud_centre_section() -> void:
	# The chapter number gets the ribbon and the chapter's name sits below it
	# in the open: number as the label, name as the thing you actually read.
	_hud_chapter_ribbon_label = Label.new()
	_hud_chapter_ribbon_label.name = "ChapterRibbonLabel"
	var centre: float = (_hud["centre_x"] + _hud["centre_r"]) * 0.5
	if _hud["show_chapter_ribbon"]:
		# Never wider than the gap between the pillars. A fixed 124 wide ribbon
		# straddled them on a narrow bar, and because the label centres its text
		# inside the ribbon, the pillars hid the first and last characters
		# rather than the ribbon simply looking too long.
		var half: float = minf(62.0,
			(float(_hud["centre_r"]) - float(_hud["centre_x"])) * 0.5 - 2.0)
		_add_ribbon("ChapterRibbon", _hud_chapter_ribbon_label,
			centre - half, centre + half, 6.0)

	# The chapter name is the one piece of HUD text that is a heading rather
	# than a stat, so it gets a light parchment ground and dark ink — the
	# inverse of everything around it. Dark-on-dark with an outline, which is
	# what it looked like before the plate went in, just read as muddy.
	var plate := PanelContainer.new()
	_hud_chapter_plate = plate
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
	# Fitted from the width the plate was BUILT with rather than the width it
	# currently reports: the metrics are already known here, and reading the
	# live size would mean awaiting a frame, which would turn a plain HUD
	# refresh into a coroutine for a purely cosmetic measurement.
	if _hud.has("centre_r"):
		_fit_label_font(chapter_label,
			float(_hud["centre_r"]) - float(_hud["centre_x"]) - 16.0)

	if _hud_player_portrait != null:
		_hud_player_portrait.texture = _portrait_texture(
			String(GameState.character_clips().get("idle_dir", "")))
	if _hud_enemy_portrait != null:
		_hud_enemy_portrait.texture = _enemy.hud_portrait if _enemy.hud_portrait != null \
			else _portrait_texture(_enemy.idle_dir)

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
	# Ahead of the early returns below: the room keeps breathing while a skill
	# plays out and after the match ends, which is when it is most on show.
	_tick_props(delta)
	if _match_over or _sequence_running or _question.is_empty():
		return
	# Before the clock check, not after: the speed tiers run out on their own
	# schedule and the badge has to follow them down even on the last frame
	# before a timeout.
	_refresh_damage_preview()
	# The tutorial holds the clock. Its whole job is to be read, and a rival
	# taking free hits while the player reads about potions teaches the wrong
	# lesson. The bar stays full and visible so the step about the timer can
	# still point at it.
	if _tutorial != null:
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
	_refresh_damage_preview()

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
	var pool := _available_moves()
	if pool.is_empty():
		return null
	if is_instance_valid(_cong_meow):
		return pool[_cong_meow.selected]
	if is_instance_valid(_regular_combat):
		return pool[_regular_combat.selected]
	var picked: EnemyMove = pool[_move_index % pool.size()]
	# "No defence spam": the Chapter 4 boss may not raise Eternal Resolve twice
	# in a row. The straight rotation would otherwise let a three-move rival
	# guard, guard, guard whenever the other two were skipped, and a boss that
	# can stand behind a barrier indefinitely is not a fight. Stepping to the
	# next move rather than blocking the turn keeps the rotation honest -- he
	# still acts, just not with the shield.
	if _ch4_guard_on_cooldown(picked) or _ch5_guard_on_cooldown(picked):
		picked = pool[(_move_index + 1) % pool.size()]
	return picked

## True when `move` is the boss's defensive skill and it was the last thing he
## did. Deliberately narrow: only the Chapter 4 boss, only his guard.
func _ch4_guard_on_cooldown(move: EnemyMove) -> bool:
	if move == null or _enemy == null or not _enemy.is_boss:
		return false
	if move.signature_id() != "c4combat_eternal_resolve":
		return false
	return _ch4_last_guard_turn >= 0 and _move_index - _ch4_last_guard_turn <= 1

## The moves this rival may currently use. A skill held back for a later phase
## is simply absent from the rotation until that phase begins, which is what
## makes a phase-2 exclusive exclusive without naming it anywhere in code.
func _available_moves() -> Array[EnemyMove]:
	var pool: Array[EnemyMove] = []
	for move in _enemy.moves:
		if move != null and move.min_phase <= _boss_phase:
			pool.append(move)
	# A rival whose every move is gated behind a later phase would have nothing
	# to attack with; fall back to the full list rather than stand there.
	if pool.is_empty():
		pool.assign(_enemy.moves)
	return pool

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
	# Entries now carry their own edge, so they no longer need a gap to be read
	# as separate -- which buys back the height the icon slots cost.
	side_panel_vbox.add_theme_constant_override("separation", 1)

	if _enemy.moves.is_empty():
		side_panel_vbox.add_child(_roster_heading(_enemy.enemy_name))
		side_panel_vbox.add_child(_roster_body(_enemy.lore, wrap_width))
		return

	side_panel_vbox.add_child(_roster_heading("MOVES"))
	# Only what the rival can actually use right now. A skill held back for a
	# later phase stays off the list until it unlocks, which keeps the panel
	# inside its height budget and lets a phase-2 skill arrive as a surprise.
	for move: EnemyMove in _available_moves():
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
	# The icon sits in a sunken slot rather than floating against the panel
	# wood. Twenty-eight skills now have their own drawn subject, and a framed
	# slot is what makes each read as a skill card's emblem instead of a
	# decoration next to some text.
	var slot := PanelContainer.new()
	slot.name = "IconSlot"
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", _move_slot_style(false))
	var icon := TextureRect.new()
	icon.texture = move.icon
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = MOVE_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)
	header.add_child(slot)

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
	name_label.custom_minimum_size.x = wrap_width - MOVE_ICON_SIZE.x - 14.0

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
## The icon's recess. Lit on the active entry so the emblem reads as switched
## on, not merely brighter -- dimming alone was too weak to find at a glance in
## a list of four.
func _move_slot_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# No inner margin: the 1px border alone frames the icon. The panel has a
	# hard height budget (SIDE_PANEL_BOTTOM_LIMIT) and padding here is charged
	# to every entry -- a margin of 1 put Lord Trapo's roster 6px over it.
	style.set_content_margin_all(0)
	style.set_corner_radius_all(2)
	style.set_border_width_all(1)
	if active:
		style.bg_color = Color(0.30, 0.17, 0.07, 0.95)
		style.border_color = MOVE_ALERT_COLOR
	else:
		style.bg_color = Color(0.10, 0.08, 0.06, 0.55)
		style.border_color = Color(0.34, 0.28, 0.20, 0.7)
	return style

func _move_plate_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 3
	style.content_margin_right = 1
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.set_corner_radius_all(2)
	if active:
		style.bg_color = Color(0.36, 0.14, 0.08, 0.96)
		style.border_width_left = 3
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = MOVE_ALERT_COLOR
	else:
		# Faintly filled rather than fully transparent. An invisible plate made
		# the list read as loose text; a whisper of ground gives every entry an
		# edge, and leaves the active one still obviously ahead of it.
		style.bg_color = Color(0.10, 0.07, 0.05, 0.34)
		style.border_width_left = 3
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0
		style.border_color = Color(0.30, 0.24, 0.17, 0.55)
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
	var active_index: int = _cong_meow.selected if is_instance_valid(_cong_meow) else _move_index % _move_entries.size()
	if is_instance_valid(_regular_combat): active_index = _regular_combat.selected
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
		var move_icon := entry["icon"] as TextureRect
		var icon_path := move_icon.texture.resource_path if move_icon.texture != null else ""
		var palace_or_capitol_icon := icon_path.begins_with("res://assets/images/ui/skill_icons/chapter3/") or icon_path.begins_with("res://assets/images/ui/skill_icons/chapter4/")
		var idle_alpha := 0.80 if palace_or_capitol_icon else 0.55
		move_icon.modulate = Color.WHITE if is_active else Color(1, 1, 1, idle_alpha)
		var slot := (entry["icon"] as TextureRect).get_parent() as PanelContainer
		if slot != null:
			slot.add_theme_stylebox_override("panel", _move_slot_style(is_active))
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
	_refresh_damage_preview()
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

## THE damage formula. Every number the player is shown or dealt comes through
## here: the blow struck by _on_word_accepted below, and the promise printed on
## the badge by _potential_damage(). They take different arguments -- the
## preview cannot know which board tiles the player will route through -- but
## they cannot disagree about what those arguments are worth, which is the
## whole point of there being one function rather than two.
##
## Pure: it reads _question (to recognise the answer) and nothing else, and it
## writes nothing. Burning the Power Up is the caller's job, precisely so the
## preview can ask "what would this be worth" without spending it.
func _damage_for(word: String, used_spark: bool, used_gold: bool,
		used_power_up: bool, speed_multiplier: float) -> int:
	var damage := BoardController.word_value(word)
	if used_gold:
		damage *= GOLD_MULTIPLIER
	if used_spark:
		damage += SPARK_BONUS_DAMAGE
	if _is_answer(word):
		damage = roundi(damage * ANSWER_BONUS_MULTIPLIER)
	damage = roundi(damage * float(_attack_tier(word.length())["damage"]))
	damage = roundi(damage * speed_multiplier)
	if used_power_up:
		damage = roundi(damage * POWER_UP_MULTIPLIER)
	return damage

## Guard is consumed by a real hit, never by a preview or a rejected word.
var _enemy_guard: float = 0.0
var _cong_meow: Node
var _regular_combat: Node
var _enemy_guard_badge: Label

func _guarded_damage(damage: int) -> int:
	return maxi(1, roundi(damage * (1.0 - _enemy_guard))) if damage > 0 else 0

func _clear_enemy_guard_badge() -> void:
	if is_instance_valid(_enemy_guard_badge):
		_enemy_guard_badge.queue_free()
	_enemy_guard_badge = null

func _show_enemy_guard_badge() -> void:
	_clear_enemy_guard_badge()
	_enemy_guard_badge = Label.new()
	_enemy_guard_badge.text = "GUARD -%d%%" % roundi(_enemy_guard * 100.0)
	_enemy_guard_badge.add_theme_font_size_override("font_size", 9)
	_enemy_guard_badge.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	_enemy_guard_badge.add_theme_color_override("font_outline_color", Color(0.05, 0.1, 0.1))
	_enemy_guard_badge.add_theme_constant_override("outline_size", 3)
	_enemy_guard_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_character.add_child(_enemy_guard_badge)
	_enemy_guard_badge.position = Vector2(10, -12)

## Whether `word` is the answer the question on screen is asking for.
func _is_answer(word: String) -> bool:
	return (not _question.is_empty()
		and word.to_upper() == String(_question.get("answer", "")))

## Damage base is the sum of each letter's Scrabble-style value (rare letters
## hit harder), not word length. Gold scales that base; Spark adds a
## flat bonus. Spelling the question's answer multiplies the lot — knowing the
## answer should always beat merely finding a long word.
func _on_word_accepted(word: String, used_spark: bool, used_gold: bool) -> void:
	var is_answer := _is_answer(word)

	# Speed scales the hit but cannot carry it: the multiplier tops out at
	# 1.3x, while length drives the base through letter values and can swing it
	# several-fold. A fast short word still loses to a slow long one.
	var tier := _attack_tier(word.length())
	var speed := _speed_bonus(word.length())
	var used_power_up := _power_up_active
	var damage := _damage_for(word, used_spark, used_gold, used_power_up,
		float(speed["multiplier"]))
	if used_power_up:
		_power_up_active = false
		_refresh_damage_preview()

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
	var message := "%s +%d" % [word.to_upper(), _guarded_damage(damage)]
	if not bonuses.is_empty():
		message += "! " + " + ".join(bonuses) + "!"
	word_preview_label.text = message

	Audio.play_sfx("word_accepted")
	_play_attack_sequence(damage, is_answer, tier)

## The whole of a rival taking a confirmed damaging hit: health, voice, flinch
## clip and a body recoil under it.
##
## Gathered into one place because the four have to agree with each other and
## used not to. The voice fired BEFORE the health came off, so the boss's
## angrier register was chosen from his health as it was a moment earlier and
## lagged a hit behind the phase it belonged to. And "the rival reacts" was the
## flinch clip alone -- six frames of the sprite, with the body it is drawn on
## perfectly still, which is what made a hit read as a texture swap.
##
## Called ONLY from the paths where damage is real. Anticipation, a miss and a
## blocked blow never reach here, which is what keeps the voice honest.
func _enemy_take_hit(damage: int) -> void:
	# Invalid/no-damage events must not heal, recoil, or speak. The existing
	# guard formula has a one-HP floor; we do not change that balance here.
	if damage <= 0 or _enemy_hp <= 0: return
	var previous_hp := _enemy_hp
	var guarded_hit := _enemy_guard > 0.0
	var boss_guard_hit := is_instance_valid(_cong_meow) and _enemy_guard > 0.0 and damage > 0
	var regular_guard_hit := is_instance_valid(_regular_combat) and _enemy_guard > 0.0 and damage > 0
	if _enemy_guard > 0.0 and damage > 0:
		damage = _guarded_damage(damage)
		if is_instance_valid(_cong_meow):
			_cong_meow.consume_shield()
		elif regular_guard_hit:
			_regular_combat.consume_guard()
		_enemy_guard = 0.0
		_clear_enemy_guard_badge()
		if not is_instance_valid(_cong_meow) and not regular_guard_hit:
			_fx_word("GUARDED", enemy_character, Color(0.55, 1.0, 0.75))
		_refresh_damage_preview()
	_enemy_hp = maxi(0, _enemy_hp - damage)
	if is_instance_valid(_ch5_chamber) and damage >= 35:
		_ch5_chamber.react(clampf(float(damage) / 8.0, 4.0, 9.0))
	# Cosmetic heavy-hit boundary only; damage and guards above remain unchanged.
	if is_instance_valid(_palace_environment) and damage >= 35:
		_palace_environment.react(clampf(float(damage) / 8.0,4.0,9.0))
	if is_instance_valid(_palace_environment) and _enemy.is_boss and _enemy_hp > 0 and float(_enemy_hp) / _enemy.max_hp <= 0.5:
		_palace_environment.escalate()
	if is_instance_valid(_cong_meow):
		_cong_meow.show_damage(damage)
	elif not regular_guard_hit:
		_fx_word("-%d HP" % damage, enemy_character, Color(1.0, 0.83, 0.55))
	enemy_heart_row.set_value(_enemy_hp)
	if previous_hp > _enemy_hp:
		_speak_enemy_hurt(guarded_hit)
	if regular_guard_hit:
		await _regular_combat.defend_impact(damage)
		await _finish_enemy_defeat_voice()
		return
	if boss_guard_hit:
		await _cong_meow.block_reaction()
		await _finish_enemy_defeat_voice()
		return

	# The clip and the recoil run TOGETHER, not one after the other: the recoil
	# is the body carrying the blow the clip is drawing, so playing them in
	# sequence would show the flinch and then, oddly, a second reaction.
	# Started without awaiting for exactly that reason -- its tweens run
	# alongside the frames, and the clip is the longer of the two.
	var flinching := enemy_character.play_hit()
	_enemy_recoil(damage)
	if flinching:
		await enemy_character.one_shot_finished
	else:
		# No flinch frames on this rival: still hold for the recoil, or the
		# exchange would carry on over the top of it.
		await get_tree().create_timer(RECOIL_SECONDS).timeout
	await _finish_enemy_defeat_voice()

## Let a lethal reaction finish before the existing encounter transition.
## Reset/pause/scene exit stops the player, so no stale completion can speak.
func _finish_enemy_defeat_voice() -> void:
	if _enemy_hp > 0 or _enemy == null or not Audio.has_enemy_reaction_voice(_enemy.enemy_name): return
	while Audio._voice_player.playing and is_inside_tree():
		await get_tree().process_frame

## Picks the register and speaks. Falls back to the shared set for any rival
## with no voice of its own, so nobody is ever silent.
func _speak_enemy_hurt(reduced: bool = false) -> void:
	var data: EnemyData = _enemy if _enemy != null else GameState.current_enemy()
	if data != null and Audio.has_enemy_reaction_voice(data.enemy_name):
		# Use Don's existing low-HP/rage boundary, measured after this hit.
		# No new damage threshold or critical system is introduced.
		var heavy := data.enemy_name=="Don Eraptado" and not data.rage_voice.is_empty() and data.max_hp>0 and float(_enemy_hp)/float(data.max_hp)<=data.rage_below
		if not Audio.play_enemy_reaction(data.enemy_name,_enemy_hp <= 0,reduced,heavy):
			# Missing authored speech remains audible, without borrowing another identity.
			if _enemy_hp > 0: Audio.play_sfx("enemy_hurt")
		return
	if data == null:
		Audio.play_sfx("enemy_hurt")
		return
	var voice := data.hurt_voice
	# The boss stops sounding composed once the fight has turned. Measured
	# after the damage above, so the change lands on the blow that causes it.
	if not data.rage_voice.is_empty() and data.max_hp > 0 \
			and float(_enemy_hp) / float(data.max_hp) <= data.rage_below:
		voice = data.rage_voice
	if not Audio.play_voice(voice):
		Audio.play_sfx("enemy_hurt")

## The body's own reaction: knocked back off its stance, head and shoulders
## carried with it, then a settle back onto the floor.
##
## Scaled by how hard the blow was, so chip damage is a twitch and a big word
## visibly rocks the rival. Deliberately small in absolute terms -- this plays
## on every single exchange, and anything larger becomes exhausting by the
## third fight.
## Impact + recoil + recovery, in seconds. Kept as one number because the wait
## above has to match what the tweens below actually take.
const RECOIL_SECONDS := 0.33

func _enemy_recoil(damage: int) -> void:
	var who := enemy_character
	if _body_home.has(who):
		return      # already mid-choreography; two owners would fight over the transform
	var k: float = clampf(float(damage) / 26.0, 0.35, 1.0)
	# Away from the player, which is rightward for a rival standing on the right.
	var back: float = 7.0 * k
	_body_begin(who, BODY_CHEST)
	await _body_play(who, [
		# Impact: driven back and folded over the blow.
		_beat(back, -2.0 * k, 5.0 * k, 1.0 - 0.04 * k, 1.0 + 0.05 * k,
			0.07, Tween.TRANS_QUAD, Tween.EASE_OUT),
		# Recoil: weight goes onto the back foot and the knees give a little.
		_beat(back * 0.55, 3.0 * k, 2.0 * k, 1.0 + 0.03 * k, 1.0 - 0.05 * k,
			0.10, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	])
	# Recovery: back onto the stance rather than snapped to it.
	await _body_end(who, 0.16)

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
	var landed: bool=await _play_player_attack(tier)
	if not landed:
		_sequence_running=false
		_update_action_buttons()
		return

	_shake_screen(float(tier["shake"]))
	await _enemy_take_hit(damage)

	# Only now does a melee attacker walk home. Before the win check, so a
	# killing blow cannot leave the player stranded mid-field.
	await _player_attack_recover()

	if _enemy_hp <= 0:
		# One rival gets back up, once. If the last stand fires, the fight is
		# not over and the win check is skipped this time round.
		if await _ch4_last_stand():
			_sequence_running = false
			_update_action_buttons()
			return
		# The last boss in the game does not simply vanish when the bar empties.
		await _ch5_boss_defeat_if_due()
		_sequence_running = false
		_update_action_buttons()
		_end_match(true)
		return

	# FINAL READING sits beside the phase check because it is the same kind of
	# event -- a threshold crossed on the way down -- and, like the phase
	# change, it must never fire on a blow that already ended the fight.

	# Checked after the win test: a blow that would kill outright should end the
	# fight rather than trigger a transformation the rival never survives to use.
	await _check_phase_change()
	# A large hit may cross both thresholds: session before final reading.
	await _ch5_try_final_reading()

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
	if is_instance_valid(_cong_meow) and move != null:
		await _cong_meow.resolve(move)
		return
	if is_instance_valid(_regular_combat) and move != null:
		await _regular_combat.resolve(move)
		return
	if move != null and _is_chapter3_move(move):
		await _resolve_chapter3_turn(move)
		return
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

	# Executive Privilege is a counter as well as a hit: a privilege claimed
	# over whatever the player had prepared. Banking a Power Up and then losing
	# the turn to this move loses the Power Up with it, so the boss punishes
	# preparation rather than only punishing a wrong answer.
	if move != null and move.signature_id() == "executive_privilege" and _power_up_active:
		_power_up_active = false
		_refresh_damage_preview()
		message += "  (Power Up revoked!)"
		_fx_word("REVOKED", player_character, Color(0.96, 0.36, 0.3), 26.0, 0.0, 14)

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

# --- potential damage -----------------------------------------------------

## Slots the damage plate into the question panel, sharing one row with the
## countdown bar.
##
## Inside the question panel rather than beside it, because what the badge
## promises is a property OF THIS QUESTION -- it changes when the question
## changes and it is meaningless without one. Putting it there also means the
## three arrangements need no new geometry between them: every layout pass
## already places the question panel, and the badge rides along.
##
## Sharing the timer's row is what keeps that free. The bar is 12 units tall in
## a panel whose other child is a three-line prompt; a row of its own would
## have cost twenty units of prompt on the arrangement that can least afford
## it. Built here rather than in word_battle.tscn for the reason given on
## _apply_panel_chrome(): the editor overwrites scene-file edits made on disk.
func _build_damage_badge() -> void:
	var vbox := timer_bar.get_parent() as VBoxContainer
	if vbox == null:
		push_warning("WordBattleController: no question VBox, skipping damage badge")
		return
	var timer_index := timer_bar.get_index()
	_damage_row = HBoxContainer.new()
	_damage_row.name = "DamageRow"
	_damage_row.add_theme_constant_override("separation", 5)
	_damage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_damage_row)
	vbox.move_child(_damage_row, timer_index)

	_damage_badge = DamageBadge.new()
	_damage_badge.name = "DamageBadge"
	_damage_row.add_child(_damage_badge)
	vbox.remove_child(timer_bar)
	_damage_row.add_child(timer_bar)
	timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

## How tall the badge stands, and whether it has room to spell out " DMG".
## Called by each layout pass with what that arrangement can afford.
func _size_damage_row(height: float, terse: bool) -> void:
	if _damage_badge == null:
		return
	_damage_badge.set_terse(terse)
	_damage_badge.custom_minimum_size.y = height
	_damage_row.custom_minimum_size.y = height

## What the question on screen is worth if it is answered correctly, as
## {slowest, fastest}.
##
## A range rather than one number because the speed bonus is not settled until
## the word is submitted: SPEED_TIERS pays up to 1.3x for assembling the answer
## quickly, and until the player starts tapping, every tier is still on the
## table. Printing the best case alone would over-promise and printing the base
## alone would under-promise, so the badge prints both ends and the range
## narrows on its own as the tiers run out -- which incidentally teaches the
## speed bonus, a mechanic nothing else on screen mentions.
##
## Gold and Spark are deliberately outside the range. Both depend on which
## tiles the player routes through, which is not knowable before they route
## through them; they can only ever push the real hit ABOVE the top of the
## range, never below it.
func _potential_damage() -> Vector2i:
	if _match_over or _question.is_empty():
		return Vector2i.ZERO
	var answer := String(_question.get("answer", ""))
	if answer.is_empty():
		return Vector2i.ZERO
	var slow := _damage_for(answer, false, false, _power_up_active,
		SPEED_BASE_MULTIPLIER)
	var fast := _damage_for(answer, false, false, _power_up_active,
		_best_speed_multiplier(answer.length()))
	return Vector2i(mini(slow, fast), maxi(slow, fast))

## The best speed multiplier still reachable for a word of this length.
##
## _speed_bonus() already answers exactly that: it returns the first tier the
## player still qualifies for, and elapsed time only ever moves that answer
## down the list. The one case it cannot speak for is "no letter has been
## tapped yet", where its stopwatch has not started -- there the top tier is
## still winnable, which is the honest reading.
func _best_speed_multiplier(word_length: int) -> float:
	if _selection_started_ms <= 0:
		return float(SPEED_TIERS[0]["multiplier"])
	return float(_speed_bonus(word_length)["multiplier"])

## Repoints the badge at whatever the situation is now. Cheap enough to call
## every frame -- DamageBadge.show_damage() drops a redraw that would not
## change anything.
func _refresh_damage_preview() -> void:
	if _damage_badge == null:
		return
	var span := _potential_damage()
	# Cleared as well as hidden, in that order. Nothing to promise means between
	# questions or after the match is decided, and the badge is hidden there
	# rather than showing a zero -- the timer bar beside it is blank at those
	# moments too, and a lone "0 DMG" would read as a bug. But hiding ALONE
	# leaves the last question's figure inside the control, so whatever made it
	# visible again would flash a stale number before the next refresh caught
	# up. Clearing it keeps "what the badge holds is what the badge means" true
	# whether it is on screen or not.
	_damage_badge.show_damage(_guarded_damage(span.x), _guarded_damage(span.y),
		_power_up_active and span.y > 0)
	_damage_badge.visible = span.y > 0

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
	# This tweens the ROOT Control, so every step retransforms the entire scene
	# — the single most expensive effect in the game per unit of drama. Phones
	# get fewer, shorter steps; the kick still reads, it just costs less.
	var steps: int = _fx_count(5)
	var reach: float = strength * lerpf(0.7, 1.0, Layout.profile.fx_budget)
	for i in steps:
		var falloff := reach * (1.0 - float(i) / float(steps))
		_shake_tween.tween_property(self, "position",
			_screen_home + Vector2(randf_range(-falloff, falloff), randf_range(-falloff, falloff)),
			0.035)
	_shake_tween.tween_property(self, "position", _screen_home, 0.04)

## One projectile crossing the gap. `arc` bends its path, `delay` staggers it
## within a volley, `wobble` makes it drift rather than fly straight.
func _spawn_bolt(from: Control, to: Control, tint: Color, bolt_size: float,
		travel: float, delay: float = 0.0, arc: float = 0.0, wobble: bool = false,
		on_impact: Callable = Callable()) -> void:
	var orb := Panel.new()
	if on_impact.is_valid():
		orb.name = "ContactProjectile"
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
	# Chapter 5 throws readable legislative objects, not anonymous circles.
	# Reuse the established per-skill pixel icon; legacy bolts stay unchanged.
	if from == enemy_character and to == player_character and _signature_move != null \
			and _signature_move.signature_id().begins_with("c5combat_") and _signature_move.icon != null:
		style.bg_color = Color.TRANSPARENT
		style.shadow_size = 0
		orb.size = Vector2.ONE * maxf(16.0, bolt_size)
		var object_icon := TextureRect.new()
		object_icon.texture = _signature_move.icon
		object_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		object_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		object_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		object_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		orb.add_child(object_icon)
		object_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _ch5_move_active:
			travel *= _ch5_pace()
			delay *= _ch5_pace()

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
	if on_impact.is_valid():
		tween.tween_callback(on_impact)
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
	count = _fx_count(count)
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
	for i in _fx_count(count):
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
	_react_room(color, shake)
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
var _player_variations: Node

func _play_player_attack(_tier: Dictionary) -> bool:
	if not is_instance_valid(_player_variations):
		_player_variations=load("res://scripts/battle/player_attack_variations.gd").new()
		add_child(_player_variations)
		_player_variations.setup(self)
	await _player_variations.strike()
	return _player_variations.contact_ready

func _play_legacy_player_attack(tier: Dictionary) -> void:
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
	if is_instance_valid(_player_variations): await _player_variations.recover()

func _legacy_player_attack_recover() -> void:
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

## Moves a node's pivot without moving the node's PICTURE.
##
## A Control renders as `position + pivot + M·(p - pivot)`, where M is its
## rotation and scale. Change the pivot alone and every rendered pixel shifts by
## `(I - M)·(p0 - p1)`, so the sprite jumps. Subtracting that from the position
## cancels it exactly, at any rotation and any scale.
##
## This is what lets a skill take over a body that is mid-lean. The old code
## sidestepped the jump by zeroing rotation and scale first -- which was itself
## a jump: every rival snapped its idle lean upright in a single frame at the
## start of every attack, up to 2.9 degrees on Budget Bandido.
func _repivot(who: Control, new_pivot: Vector2) -> void:
	var d := who.pivot_offset - new_pivot
	var m := Transform2D(who.rotation, Vector2.ZERO).scaled(who.scale)
	who.position += d - m * d
	who.pivot_offset = new_pivot

func _body_begin(who: Control, pivot: Vector2) -> void:
	# Hand the body over from the idle personality, which writes rotation and
	# scale every frame, to the choreography, which tweens the same two. The
	# live pose is kept and becomes the pose the first beat tweens FROM, so the
	# attack grows out of the stance instead of interrupting it.
	if who is AnimatedCharacter:
		(who as AnimatedCharacter).pose_locked = true
	_repivot(who, Vector2(who.size.x * pivot.x, who.size.y * pivot.y))
	# Captured AFTER the repivot, because that adjusts position -- and this is
	# the pose _body_end returns the rival to, which is its idle stance.
	_body_home[who] = {
		"pos": who.position, "rot": who.rotation,
		"scale": who.scale, "pivot": who.pivot_offset,
	}

## How far past its target an accelerating beat carries, as a fraction of that
## beat's own travel, and how long it takes to settle back.
const FOLLOW_THROUGH := 0.14
const FOLLOW_THROUGH_SECS := 0.075

## Appends a follow-through to a beat list whose last beat ACCELERATES into its
## target.
##
## An EASE_IN beat arrives at maximum speed, and whatever ran next held station
## -- so the rival went from travelling to stopped between two frames. Measured
## on Stamp Slam, that was a 72 px/frame velocity reversal, which is the snap
## that made the attacks read as broken rather than merely fast.
##
## A body cannot stop dead, so it does not: the strike carries a little past
## its mark and eases back. That is the follow-through every one of these
## skills was missing, and adding it here gives it to all of them at once
## rather than editing twenty-eight hand-written beat lists.
func _with_follow_through(beats: Array, from: Vector2) -> Array:
	if beats.is_empty():
		return beats
	var last: Dictionary = beats[-1]
	if int(last["ease"]) != int(Tween.EASE_IN):
		return beats
	# Measured against where the beat STARTS, which for a single-beat list is
	# wherever the previous call left the body -- not the resting pose. Reading
	# it as travel-from-rest made a strike that merely tilted in place carry a
	# thirty-pixel overshoot it never earned.
	var start := from
	if beats.size() > 1:
		var prev: Dictionary = beats[-2]
		start = Vector2(float(prev["dx"]), float(prev["dy"]))
	var carry := (Vector2(float(last["dx"]), float(last["dy"])) - start) * FOLLOW_THROUGH
	if carry.length() < 0.5:
		return beats
	var out := beats.duplicate()
	out.append(_beat(float(last["dx"]) + carry.x, float(last["dy"]) + carry.y,
		float(last["deg"]), float(last["sx"]), float(last["sy"]),
		FOLLOW_THROUGH_SECS, Tween.TRANS_SINE, Tween.EASE_OUT))
	return out

func _body_play(who: Control, beats: Array) -> void:
	if not _body_home.has(who):
		return
	var home: Vector2 = _body_home[who]["pos"]
	if who == enemy_character and enemy_character.contact_sync_pending:
		var contact_seconds := 0.0
		for beat: Dictionary in _with_follow_through(beats, who.position-home):
			contact_seconds += float(beat["secs"])
		enemy_character.synchronize_attack_contact(contact_seconds)
	# One tween for the whole list, chained. A tween per beat cost a frame at
	# every junction while the next one was created, so a five-beat skill sat
	# still for five frames spread through its own animation.
	var tween := create_tween()
	for beat: Dictionary in _with_follow_through(beats, who.position - home):
		var secs: float = beat["secs"]
		var joint_driven := who == enemy_character and enemy_character.limb_motion != null and not enemy_character.is_rigged()
		var angle := float(beat["deg"])
		var stretch := Vector2(beat["sx"], beat["sy"])
		if joint_driven:
			# Keep the authored timing/travel, but distribute effort into the
			# shoulders, forearms and knees instead of bending the entire sprite.
			angle = clampf(angle * .35, -8.0, 8.0)
			stretch = Vector2(clampf(stretch.x,.96,1.04),clampf(stretch.y,.96,1.04))
		if _ch5_move_active and who == enemy_character:
			secs *= _ch5_pace()
		var step := tween.tween_property(
			who, "position", home + Vector2(beat["dx"], beat["dy"]), secs)
		step.set_trans(beat["trans"]).set_ease(beat["ease"])
		tween.parallel().tween_property(
			who, "rotation", deg_to_rad(angle), secs) \
			.set_trans(beat["trans"]).set_ease(beat["ease"])
		tween.parallel().tween_property(
			who, "scale", stretch, secs) \
			.set_trans(beat["trans"]).set_ease(beat["ease"])
		if joint_driven:
			var joints := Vector3(clampf(float(beat["deg"])/24.0,-1,1),
				clampf((1.0-float(beat["sy"]))*6.0,-1,1),
				clampf(float(beat["deg"])/18.0,-1,1))
			tween.parallel().tween_property(who,"combat_joint_pose",joints,secs) \
				.set_trans(beat["trans"]).set_ease(beat["ease"])
		tween.chain()
	await tween.finished

func _body_end(who: Control, secs: float = 0.18) -> void:
	if not _body_home.has(who):
		return
	if _ch5_move_active and who == enemy_character:
		secs *= _ch5_pace()
	var home: Dictionary = _body_home[who]
	var tween := create_tween().set_parallel(true)
	if who == enemy_character and enemy_character.limb_motion != null:
		tween.tween_property(who,"combat_joint_pose",Vector3.ZERO,secs) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(who, "position", home["pos"], secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(who, "rotation", home["rot"], secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(who, "scale", home["scale"], secs) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	# Compensated on the way back as well: at this point the body is once more
	# carrying its idle lean, so restoring the pivot raw would jump it.
	_repivot(who, home["pivot"])
	# Only this character's entry -- clearing the lot would strand anyone else
	# who happens to be mid-move.
	_body_home.erase(who)
	if who is AnimatedCharacter:
		(who as AnimatedCharacter).pose_locked = false

# --- the shape of a strike ------------------------------------------------
#
# A blow that reads as a blow has five parts, and the choreography used to have
# one of them. Every Chapter 2 skill went straight from travelling to its impact
# beat: no gathering beforehand, no carrying through afterwards, and a snap back
# to the stance at the end. What movement there was came from tweening the whole
# node -- position, scale, and a rotation applied to the ENTIRE sprite, so a
# "spinning swing" turned the rival's legs and head with its arms. That is the
# rigid-object look: the body never does anything, the picture is just moved.
#
# The fix is not more node-tweening. It is to use the two things the character
# already has, in the two places each is actually good:
#
#   RIG ON   for anticipation and follow-through. These are HELD poses -- a
#            coil, a carry-through -- and the cut-out can bend legs, turn a
#            torso against them and let the head lead or lag. The rig freezes
#            the sprite on one frame, which costs nothing here because a held
#            pose is meant to be one frame.
#   RIG OFF  for the strike itself. The hand-drawn attack clip has the actual
#            arm swing drawn into it, and the rig hides the flat sprite, so the
#            two can never be shown at once. The drawn frames win the moment
#            the limb is really moving.
#
# So the body gathers, the drawing swings, the body carries it through. Callers
# get that by wrapping their impact beats in _strike_windup / _strike_follow.

## How far the body coils away from its target before a blow, in degrees of
## torso turn. Read as "how much of a punch is the part before the punch".
const WINDUP_TORSO := 13.0
const WINDUP_LEGS := 6.0
const WINDUP_SECS := 0.17
const FOLLOW_SECS := 0.20

## Gathers the body before a strike: weight drops onto the back leg, the torso
## turns away from the target, the head stays looking at it.
##
## `facing` is -1 when the striker is moving left (a rival attacking the player)
## and +1 for the mirror, so the coil always winds AGAINST the direction the
## blow will travel.
func _strike_windup(who: AnimatedCharacter, facing: float = -1.0) -> void:
	if not is_instance_valid(who):
		return
	who.rig_enable()
	# Legs and torso turn together but by different amounts, which is what
	# makes it read as a body gathering rather than a figure leaning.
	who.rig_pose(WINDUP_LEGS * facing, -WINDUP_TORSO * facing,
		WINDUP_TORSO * 0.35 * facing, 2.0, -3.0 * facing, WINDUP_SECS)
	await get_tree().create_timer(WINDUP_SECS).timeout
	# Handed straight back: the strike that follows needs the drawn frames.
	who.rig_disable()

## Carries the blow through after impact and settles onto the stance.
##
## The overshoot is the point. Stopping the body at the moment of contact is
## what made every recovery look like a reset; letting it travel past and come
## back is the difference between a swing and a snapshot.
func _strike_follow(who: AnimatedCharacter, facing: float = -1.0) -> void:
	if not is_instance_valid(who):
		return
	who.rig_enable()
	# Past the blow: torso has rotated through, legs trail, head last.
	who.rig_pose(-WINDUP_LEGS * 0.8 * facing, WINDUP_TORSO * 1.15 * facing,
		-WINDUP_TORSO * 0.5 * facing, -1.0, 4.0 * facing, FOLLOW_SECS * 0.55)
	await get_tree().create_timer(FOLLOW_SECS * 0.55).timeout
	# Settle: back to neutral, slower than it left, so it eases rather than snaps.
	who.rig_pose(0.0, 0.0, 0.0, 0.0, 0.0, FOLLOW_SECS)
	await get_tree().create_timer(FOLLOW_SECS).timeout
	who.rig_disable()

## Fires the sprite's arm clip WITHOUT waiting for it, so it overlaps the body
## choreography instead of adding its full second on top. Used only on the
## moves where the rival actually strikes — the ones that gesture, retreat or
## lecture deliberately never call it, which is itself part of how they read
## as different actions.
func _body_swing(who: AnimatedCharacter) -> void:
	if who == enemy_character and who.limb_motion != null:
		who.contact_sync_pending = true
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
	# The SOLES, not the node's bottom edge. Those were the same thing until
	# fighters were grounded on their drawn feet (_stand_on_floor); the node now
	# hangs below the floor by whatever padding its sheet carries, and placing
	# the backdrop against it would put the painted floor back under the feet by
	# exactly the amount the grounding just removed.
	return player_character.position.y + player_character.body_rect().end.y

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
## Chapter 3's articulated clips are timed against the actual damage frame.
## Other chapters continue through their existing signature choreography.
## Chapter 3's move ids have been renamed once already (ch3_* -> c3combat_*).
## Matching on a single prefix meant the rename silently unrouted all 24 skills:
## they kept animating, via the generic Chapter 1/2 path, while guard_reduction
## and self_heal -- which only this resolver reads -- stopped resolving at all.
## Both prefixes are accepted so the next rename degrades to "unstyled", never
## to "the defensive skills do nothing".
## Chapter 4 joins the same resolver rather than getting one of its own. What
## _resolve_chapter3_turn actually owns is generic -- read guard_reduction and
## self_heal, drive the articulated clip, land the blow on the beat the routine
## returns on -- and only _ch3_perform's match is chapter-specific. Adding a
## second resolver would have meant a second copy of the defensive branch, and
## the defensive branch is precisely the part that silently stopped working the
## last time these ids were renamed.
func _is_chapter3_move(move: EnemyMove) -> bool:
	var id := move.signature_id()
	return (id.begins_with("ch3_") or id.begins_with("c3combat_")
		or id.begins_with("c4combat_") or id.begins_with("c5combat_"))

func _resolve_chapter3_turn(move: EnemyMove) -> void:
	var defending := move.guard_reduction > 0.0 or move.self_heal > 0
	var melee := not defending and move.animation_style == "slam"
	var tint := move.effect_color
	var move_id := move.signature_id()
	var mud := _pending_enemy_damage
	_ch5_move_active = move_id.begins_with("c5combat_")
	_pending_enemy_damage = 0
	var damage := move.direct_damage + mud
	if defending and move_id == "c4combat_eternal_resolve":
		_ch4_last_guard_turn = _move_index
	# Phase 2 is the same boss, more determined -- so it is a scaling of what he
	# already does, not a new moveset. Damage is lifted here rather than in the
	# routine because the routine performs the blow and the resolver is what
	# lands it.
	if defending and move_id in ["c5combat_speakers_shield", "c5combat_quorum_escape"]:
		_ch5_last_guard_turn = _move_index
	damage = roundi(float(damage) * _ch4_phase_gain(move_id) * _ch5_damage_gain(move_id))
	var ch5_ranged := move_id.begins_with("c5combat_") and not melee and not defending
	if ch5_ranged:
		_ch5_ranged_contact_pending = true
		_ch5_ranged_damage = damage
	_signature_move = move
	_body_begin(enemy_character, BODY_FEET)
	if Audio.has_move_sfx(move_id, "cast"):
		Audio.play_move_sfx(move_id, "cast")
	# Per-skill choreography -- the Chapter 3 section at the foot of this file.
	# Each routine runs its own anticipation, wind-up, execution and release,
	# and returns on the beat the blow should land.
	await _ch3_perform(move_id, move, tint, melee, defending)
	# Wait for the final projectile's actual tween contact, including during
	# accelerated boss phases. No guessed flight timer and no early HP loss.
	while ch5_ranged and _ch5_ranged_contact_pending:
		await get_tree().process_frame
	# The cut-out rig is a display state, not a pose: whatever a skill left it
	# in, the body is handed back to its drawn frames before anything below
	# moves it. Idempotent, so a skill that already tidied up pays nothing.
	if enemy_character.is_rigged():
		await _ch3_ungather()
	if defending:
		if move.guard_reduction > 0.0:
			_enemy_guard = maxf(_enemy_guard, move.guard_reduction)
			_show_enemy_guard_badge()
			_fx_ring(enemy_character, tint, 72.0, 0.40)
			word_preview_label.text = "%s: guard for the next hit" % move.move_name
		else:
			var heal := mini(move.self_heal, _enemy.max_hp - _enemy_hp)
			_enemy_hp += heal
			enemy_heart_row.set_value(_enemy_hp)
			_fx_word("+%d HP" % heal, enemy_character, Color(0.65, 1.0, 0.8))
			word_preview_label.text = "%s: +%d HP" % [move.move_name, heal]
		_refresh_damage_preview()
	elif not ch5_ranged:
		# Projectiles are released by the skill itself, on the frame they
		# leave the hand, so nothing generic is thrown here any more.
		if Audio.has_move_sfx(move_id, "hit"):
			Audio.play_move_sfx(move_id, "hit")
		else:
			Audio.play_sfx("attack_impact")
		_shake_screen(5.0 if melee else 2.5)
		_react_room(tint, 8.0 if is_instance_valid(_palace_environment) and _enemy.is_boss else 4.0)
		_fx_flash(tint, 0.16)
		word_preview_label.text = "%s hits! -%d HP" % [move.move_name, damage]
	if damage > 0 and not ch5_ranged:
		_player_hp = maxi(0, _player_hp - damage)
		player_heart_row.set_value(_player_hp)
		Audio.play_sfx("player_hurt")
		player_character.play_hit()
		if defending:
			word_preview_label.text += " (mud: -%d HP)" % mud
	# Let the clip settle back to exactly the same idle pose before retreating.
	var recovery := 0.47 if defending or melee else 0.25
	if _ch5_move_active:
		recovery *= _ch5_pace()
	await get_tree().create_timer(recovery, not _ch5_move_active).timeout
	if melee:
		await _body_play_walking(enemy_character, _melee_retreat(0.36), 10.0)
		_body_send_back(enemy_character)
	await _body_end(enemy_character, 0.12)
	_ch5_move_active = false
	_move_index += 1
	if move_id.begins_with("c5combat_"):
		_ch5_finish_turn()
	_highlight_current_move()

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

		# --- Chapter 2 ---
		"backdoor_dash": await _sig_backdoor_dash(move_id, tint)
		"envelope_express": await _sig_envelope_express(move_id, tint)
		"queue_skip_kick": await _sig_queue_skip_kick(move_id, tint)
		"stamp_slam": await _sig_stamp_slam(move_id, tint)
		"paper_cut_volley": await _sig_paper_cut_volley(move_id, tint)
		"counter_charge": await _sig_counter_charge(move_id, tint)
		"permit_board_bash": await _sig_permit_board_bash(move_id, tint)
		"fake_seal_shot": await _sig_fake_seal_shot(move_id, tint)
		"carbon_copy_barrage": await _sig_carbon_copy_barrage(move_id, tint)
		"notary_stampede": await _sig_notary_stampede(move_id, tint)
		"signature_slash": await _sig_signature_slash(move_id, tint)
		"seal_of_approval": await _sig_seal_of_approval(move_id, tint)
		"cash_drawer_bash": await _sig_cash_drawer_bash(move_id, tint)
		"coin_flick": await _sig_coin_flick(move_id, tint)
		"receipt_whip": await _sig_receipt_whip(move_id, tint)
		"budget_bag_bash": await _sig_budget_bag_bash(move_id, tint)
		"coin_burst": await _sig_coin_burst(move_id, tint)
		"deficit_drop": await _sig_deficit_drop(move_id, tint)
		"briefcase_beatdown": await _sig_briefcase_beatdown(move_id, tint)
		"bid_folder_fan": await _sig_bid_folder_fan(move_id, tint)
		"contract_snare": await _sig_contract_snare(move_id, tint)
		"codex_crusher": await _sig_codex_crusher(move_id, tint)
		"citation_cannon": await _sig_citation_cannon(move_id, tint)
		"session_smash": await _sig_session_smash(move_id, tint)
		"kaban_ng_bayan": await _sig_kaban_ng_bayan(move_id, tint)
		"plunder_supremo": await _sig_plunder_supremo(move_id, tint)
		"jueteng_jackpot": await _sig_jueteng_jackpot(move_id, tint)
		"executive_privilege": await _sig_executive_privilege(move_id, tint)
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
	for i in _fx_count(3):
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
	for i in _fx_count(9):
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
	for i in _fx_count(6):
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
	for i in _fx_count(3):
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
	for i in _fx_count(8):
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
	for i in _fx_count(4):
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
	for i in _fx_count(10):
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
	for i in _fx_count(3):
		_fx_word("†", enemy_character, pale, 30.0, 0.16 * float(i), 14)
	_fx_charge(enemy_character, tint, 0.6)
	await _body_play(enemy_character, [
		_beat(14, 0, -12, 0.9, 1.0, 0.3, Tween.TRANS_SINE, Tween.EASE_OUT),   # turns away, narrows
		_beat(18, 2, -14, 0.86, 1.0, 0.22),                                   # hunched over the book
		_beat(16, 0, -10, 0.9, 1.0, 0.18),                                    # a glance back
	])
	for i in _fx_count(3):
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
	for i in _fx_count(3):
		_fx_ring(enemy_character, tint, 26.0, 0.24, 0.09 * float(i))
	_fx_charge(enemy_character, tint, 0.34)
	await _body_play(enemy_character, [
		_beat(-14, 2, 11, 1.02, 0.99, 0.26, Tween.TRANS_QUAD, Tween.EASE_OUT),    # leans in, palm out
		_beat(-16, 3, 13, 1.03, 0.98, 0.1),                                       # waits for it
	])
	for i in _fx_count(5):
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
			for i in _fx_count(7):
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
	if is_instance_valid(_ch5_chamber): _ch5_chamber.stop()
	Audio.reset_voice()
	if is_instance_valid(_player_variations): _player_variations.cancel()
	# A tutorial is a rehearsal, and every real ending writes to GameState --
	# reset_chapter() on a loss, mark_difficulty_completed() and an encounter
	# advance on a win. The demonstrations are sized so neither bar should reach
	# zero, but "should" is not a guarantee when the rival's move list is data,
	# so this refuses the ending outright and puts the health back rather than
	# trusting the numbers.
	if _tutorial != null:
		_player_hp = maxi(_player_hp, roundi(GameState.player_max_hp * 0.5))
		_enemy_hp = maxi(_enemy_hp, roundi(_enemy.max_hp * 0.5) if _enemy != null else 1)
		player_heart_row.set_value(_player_hp)
		enemy_heart_row.set_value(_enemy_hp)
		_refresh_damage_preview()
		return
	_match_over = true
	if is_instance_valid(_palace_environment): _palace_environment.stop()
	if is_instance_valid(_regular_combat):
		_regular_combat.clear_effects()
		_enemy_guard = 0.0
		_clear_enemy_guard_badge()
	if is_instance_valid(_cong_meow):
		_cong_meow.clear_effects()
		_enemy_guard = 0.0
		_clear_enemy_guard_badge()
	_refresh_damage_preview()
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

## Escalates the rival a phase if its health has fallen past the next
## threshold, and stages the transformation that announces it.
##
## Thresholds are read high-to-low as fractions of max health, so a rival can
## declare any number of them; the boss declares one, at half.
func _check_phase_change() -> void:
	if _phase_changing or _enemy == null or _enemy.phase_thresholds.is_empty():
		return
	var next_index := _boss_phase - 1          # 0 -> the threshold into phase 2
	if next_index >= _enemy.phase_thresholds.size():
		return
	var fraction := float(_enemy_hp) / float(maxi(1, _enemy.max_hp))
	if fraction > _enemy.phase_thresholds[next_index]:
		return

	_phase_changing = true
	_boss_phase += 1
	await _play_phase_transition(next_index)
	_phase_changing = false
	# The rotation has just gained a skill, so the panel has to be rebuilt or it
	# keeps listing only what was available a moment ago.
	_build_move_list()
	_highlight_current_move()

## The room turns on the player. Curtains, light, and the rival itself all
## change together so the escalation reads as one event rather than a stat
## quietly moving behind the scenes.
func _play_phase_transition(index: int) -> void:
	if is_instance_valid(_ch5_chamber): _ch5_chamber.set_stage(1)
	if is_instance_valid(_palace_environment): _palace_environment.escalate()
	_sequence_running = true
	_update_action_buttons()

	# Everything stops for a beat.
	_shake_screen(7.0)
	Audio.play_sfx("attack_impact")
	await get_tree().create_timer(0.18).timeout

	# The arena itself changes, where the rival supplies a backdrop for it.
	if index < _enemy.phase_backgrounds.size():
		var next_bg: Texture2D = _enemy.phase_backgrounds[index]
		if next_bg != null:
			var veil := ColorRect.new()
			veil.color = Color(0.02, 0.01, 0.0, 0.0)
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			veil.offset_right = Layout.profile.design_size.x
			veil.offset_bottom = Layout.profile.design_size.y
			_fx_node(veil, 1.2)
			var dim := create_tween()
			dim.tween_property(veil, "color:a", 0.85, 0.22)
			await dim.finished
			_set_room(next_bg)
			var lift := create_tween()
			lift.tween_property(veil, "color:a", 0.0, 0.35)

	# The rival draws itself up: it has stopped pretending this is beneath it.
	_fx_charge(enemy_character, Color(1.0, 0.72, 0.28, 1.0), 0.5)
	_fx_ring(enemy_character, Color(1.0, 0.78, 0.34, 0.9), 120.0, 0.45)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(0, 6, 0, 1.04, 0.9, 0.16, Tween.TRANS_QUAD, Tween.EASE_OUT),   # coils
		_beat(0, -14, 0, 0.96, 1.14, 0.26, Tween.TRANS_BACK, Tween.EASE_OUT), # rises
		_beat(0, 0, 0, 1.0, 1.0, 0.18),
	])
	await _body_end(enemy_character)

	var banner := "PHASE %d" % _boss_phase
	if index < _enemy.phase_banners.size() and not _enemy.phase_banners[index].is_empty():
		banner = _enemy.phase_banners[index]
	_fx_word(banner, enemy_character, Color(1.0, 0.84, 0.38), 34.0, 0.0, 17)
	_fx_flash(Color(1.0, 0.62, 0.22), 0.45)
	_shake_screen(9.0)
	await get_tree().create_timer(0.6).timeout

	_sequence_running = false
	_update_action_buttons()

func _show_encounter_banner() -> void:
	banner_title_label.text = "CHAPTER BOSS" if _enemy.is_boss else "Encounter %d of %d" % [
		GameState.encounter_number(), GameState.encounter_total()]
	banner_name_label.text = "%s — %s" % [_enemy.enemy_name, _enemy.title]
	encounter_banner.show()
	await get_tree().create_timer(BANNER_TIME).timeout
	encounter_banner.hide()


# ==========================================================================
# CHAPTER 2 — CITY HALL
# ==========================================================================
#
# Twenty-eight skills across nine rivals. Each one is its own choreography
# rather than a shared "walk in, hit, walk out": the brief asks that a physical
# attack actually carry the body across the field and that a ranged attack send
# something recognisable across it, so the vocabulary below leans on
# _body_play_walking (which drives the cut-out rig, so limbs swing rather than
# the whole sprite sliding) and on per-skill projectile shapes.
#
# Every skill also names itself before it lands — see _telegraph — because with
# three skills per rival the player needs to know which one is coming while
# there is still time to read it.

## The shout before the swing. Names the skill over the rival and lights it up,
## so the wind-up is readable as *this* skill rather than as generic menace.
func _telegraph(label: String, tint: Color, charge: float = 0.36) -> void:
	_fx_word(label, enemy_character, Color(tint.r, tint.g, tint.b, 1.0), 22.0, 0.0, 12)
	_fx_charge(enemy_character, tint, charge)

## A rectangle that flies from the rival to the player and tumbles on the way.
## Papers, folders, envelopes and receipts are all this shape with different
## proportions and spin, which is what keeps nine paper-themed rivals from
## looking like one rival.
func _fx_paper(size: Vector2, tint: Color, travel: float, delay: float,
		arc: float, spin: float) -> void:
	_fx_slab(enemy_character, player_character, tint, size, travel, delay, arc, spin, 1)

# --- Fixer Fredo ----------------------------------------------------------

## He does not walk over — he leaves. A look both ways, a puff, and he is on
## the other side of you. The only rival in the chapter that crosses the field
## without travelling across it.
func _sig_backdoor_dash(move_id: String, tint: Color) -> void:
	_telegraph("BACKDOOR DASH", tint, 0.3)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(0, 0, -9, 1.0, 1.0, 0.14),
		_beat(0, 0, 9, 1.0, 1.0, 0.14),
		_beat(-6, 2, 0, 0.98, 1.02, 0.12),
	])

	# Out through the side door.
	_fx_splatter(enemy_character, Color(0.82, 0.80, 0.74, 0.8), 7, 20.0, 0.4)
	var vanish := create_tween()
	vanish.tween_property(enemy_character, "modulate:a", 0.0, 0.12)
	await vanish.finished

	# Reappears past the player's shoulder, facing back the way he came.
	var home := _body_home_x(enemy_character)
	enemy_character.position.x = player_character.position.x - player_character.size.x * 0.6
	_fx_splatter(enemy_character, Color(0.82, 0.80, 0.74, 0.8), 7, 20.0, 0.4)
	var appear := create_tween()
	appear.tween_property(enemy_character, "modulate:a", 1.0, 0.1)
	await appear.finished

	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(30, -4, -14, 1.12, 0.9, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_impact(move_id, 6.0, tint, 0.2)

	# Back to his spot as if he never left it.
	var back := create_tween()
	back.tween_property(enemy_character, "modulate:a", 0.0, 0.1)
	await back.finished
	enemy_character.position.x = home
	var settle := create_tween()
	settle.tween_property(enemy_character, "modulate:a", 1.0, 0.12)
	await settle.finished
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_end(enemy_character)

## RANGED — three envelopes flicked like cards, bursting into loose bills.
func _sig_envelope_express(move_id: String, tint: Color) -> void:
	_telegraph("ENVELOPE EXPRESS", tint)
	_body_begin(enemy_character, BODY_CHEST)
	await _body_play(enemy_character, [
		_beat(-8, 2, -7, 1.02, 0.98, 0.18, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	for i in _fx_count(3):
		_fx_paper(Vector2(22, 14), tint, TRAVEL_TIME * 1.05, 0.09 * float(i),
			-18.0 + float(i) * 16.0, 3.0)
		await _body_play(enemy_character, [
			_beat(6, -2, 8, 1.04, 0.97, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN),
			_beat(-2, 0, -3, 1.0, 1.0, 0.07),
		])
	await get_tree().create_timer(TRAVEL_TIME * 0.9).timeout
	_fx_splatter(player_character, Color(0.86, 0.84, 0.62, 0.95), 8, 26.0, 0.5)
	_fx_impact(move_id, 5.0, tint, 0.2)
	await _body_end(enemy_character)

## PHYSICAL — steps over the barrier as if it were painted on, then a spinning
## kick. The only skill in the chapter that puts a prop on the field first.
func _sig_queue_skip_kick(move_id: String, tint: Color) -> void:
	_telegraph("QUEUE SKIP KICK", tint, 0.28)

	# The barrier he is about to ignore.
	var rail := Panel.new()
	rail.add_theme_stylebox_override("panel", _fx_style(Color(0.72, 0.66, 0.5, 0.95), 1))
	rail.size = Vector2(8, 30)
	rail.position = Vector2((enemy_character.position.x + player_character.position.x) * 0.5,
		_stage_floor() - 30.0)
	_fx_node(rail, 1.4)

	_body_begin(enemy_character, BODY_FEET)
	_body_bring_forward(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx * 0.4, 4, 0, 1.02, 0.98, 0.2, Tween.TRANS_SINE, Tween.EASE_IN),
		_beat(dx * 0.6, -34, 0, 0.96, 1.1, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(dx * 0.72, 0, 0, 1.02, 0.98, 0.14, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	# A torso whip, not a cartwheel. This used to rotate the whole node
	# through 360 degrees, which turned the legs and head with the arms --
	# the clearest case of the sprite being spun rather than the body
	# swinging. The arc now stays inside what a torso can actually do and
	# the drawn attack frames carry the limb.
	await _body_play(enemy_character, [
		_beat(dx, -10, -24, 1.06, 0.94, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(dx, 0, 12, 1.02, 0.98, 0.1),
	])
	_fx_impact(move_id, 7.0, tint, 0.24)
	# The smug point at the front of a line that is not there.
	await _body_play(enemy_character, [_beat(dx - 10, -4, -12, 1.04, 1.0, 0.18)])
	_fx_word("NEXT!", enemy_character, Color(tint.r, tint.g, tint.b, 1.0), 18.0, 0.0, 11)
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.5), 11.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

# --- Clerk Kurakot --------------------------------------------------------

## PHYSICAL — glasses, stamp, two short steps, and down. The heaviest single
## downward blow among the ordinary rivals.
func _sig_stamp_slam(move_id: String, tint: Color) -> void:
	_telegraph("STAMP SLAM", tint, 0.42)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(0, -2, 0, 1.0, 1.02, 0.14),
		_beat(-4, 8, -5, 1.06, 0.92, 0.18, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(0, -16, 0, 0.94, 1.16, 0.2, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_body_bring_forward(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play_walking(enemy_character, [
		_beat(dx * 0.55, -12, 4, 0.96, 1.12, 0.16),
		_beat(dx, -12, 8, 0.96, 1.12, 0.14),
	], 9.0)
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx, 16, 22, 1.18, 0.8, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_word("DENIED!", player_character, Color(0.94, 0.24, 0.2), 8.0, 0.0, 18)
	_fx_ring(player_character, Color(0.88, 0.22, 0.18, 0.9), 88.0, 0.28)
	_fx_splatter(player_character, Color(0.86, 0.2, 0.16, 0.95), 9, 26.0, 0.55)
	_fx_impact(move_id, 10.0, tint, 0.3)
	await _body_play(enemy_character, [_beat(dx, 4, 6, 1.04, 0.96, 0.16)])
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.56), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## RANGED — documents thrown up, straightening into blades on the way down.
## Deliberately uneven speeds so the volley arrives as three separate threats.
func _sig_paper_cut_volley(move_id: String, tint: Color) -> void:
	_telegraph("PAPER CUT VOLLEY", tint)
	_body_begin(enemy_character, BODY_CHEST)
	await _body_play(enemy_character, [
		_beat(0, 4, -6, 1.02, 0.98, 0.12),
		_beat(0, 2, 6, 1.02, 0.98, 0.1),
		_beat(0, -12, 0, 0.96, 1.1, 0.16, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	var speeds := [1.25, 0.95, 0.72]
	for i in _fx_count(3):
		_fx_paper(Vector2(26, 4), Color(0.96, 0.95, 0.9, 0.95),
			TRAVEL_TIME * float(speeds[i % speeds.size()]),
			0.1 * float(i), -30.0 + float(i) * 24.0, 0.0)
	await get_tree().create_timer(TRAVEL_TIME * 1.1).timeout
	_fx_splatter(player_character, Color(0.96, 0.95, 0.9, 0.95), 7, 22.0, 0.45)
	_fx_impact(move_id, 5.0, tint, 0.2)
	await _body_end(enemy_character)

## PHYSICAL — he vaults his own counter. Ends by straightening his uniform as
## though the last two seconds did not happen.
func _sig_counter_charge(move_id: String, tint: Color) -> void:
	_telegraph("COUNTER CHARGE", tint, 0.3)
	_body_begin(enemy_character, BODY_FEET)
	_body_bring_forward(enemy_character)
	await _body_play(enemy_character, [
		_beat(0, 10, 0, 1.1, 0.88, 0.16, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	await _body_play_walking(enemy_character, _melee_advance("lunge", 0.6), 13.0)
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx + 6, -2, -18, 1.16, 0.9, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_splatter(player_character, Color(0.82, 0.84, 0.9, 0.95), 8, 24.0, 0.5)
	_fx_impact(move_id, 8.0, tint, 0.26)
	# Stumbles back into his workstation, then tidies himself.
	await _body_play(enemy_character, [
		_beat(dx - 26, 6, 12, 0.96, 1.04, 0.16, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(dx - 26, 0, -3, 1.0, 1.0, 0.12),
		_beat(dx - 26, -2, 3, 1.0, 1.0, 0.12),
	])
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.54), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

# --- Permit Peke ----------------------------------------------------------

## PHYSICAL — a signboard swung flat. The board answers for him afterwards.
func _sig_permit_board_bash(move_id: String, tint: Color) -> void:
	_telegraph("PERMIT BOARD BASH", tint, 0.32)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(-10, 4, -12, 1.06, 0.96, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	_body_bring_forward(enemy_character)
	await _body_play_walking(enemy_character, _melee_advance("charge", 0.62), 13.0)
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx, -4, 30, 1.2, 0.88, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_slab(enemy_character, player_character, tint, Vector2(58, 26), 0.14, 0.0, 0.0, 0.0, 2)
	_fx_impact(move_id, 9.0, tint, 0.26)
	_fx_word("APPROVED?", player_character, Color(0.92, 0.9, 0.84), 14.0, 0.0, 13)
	await get_tree().create_timer(0.34).timeout
	_fx_word("PEKE!", player_character, Color(0.94, 0.26, 0.22), 22.0, 0.0, 17)
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.54), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## RANGED — stamped seals peel off the page and curve in, still wet.
func _sig_fake_seal_shot(move_id: String, tint: Color) -> void:
	_telegraph("FAKE SEAL SHOT", tint)
	_body_begin(enemy_character, BODY_CHEST)
	# Three fast stamps, one per seal.
	for i in 3:
		await _body_play(enemy_character, [
			_beat(0, 9, 0, 1.06, 0.92, 0.07, Tween.TRANS_QUAD, Tween.EASE_IN),
			_beat(0, -3, 0, 1.0, 1.02, 0.07),
		])
	for i in _fx_count(3):
		# Curved, not straight — a forged seal should not arrive honestly.
		_spawn_bolt(enemy_character, player_character, tint, 13.0,
			TRAVEL_TIME * 1.15, 0.1 * float(i), -34.0 + float(i) * 34.0, true)
	await get_tree().create_timer(TRAVEL_TIME * 1.2).timeout
	_fx_ring(player_character, tint, 62.0, 0.26)
	_fx_impact(move_id, 6.0, tint, 0.22)
	await _body_end(enemy_character)

## RANGED — the photocopier will not stop. The densest volley in the chapter,
## and the one that most obviously thins itself out on a phone.
func _sig_carbon_copy_barrage(move_id: String, tint: Color) -> void:
	_telegraph("CARBON COPY BARRAGE", tint, 0.44)
	_body_begin(enemy_character, BODY_CHEST)
	await _body_play(enemy_character, [
		_beat(0, -10, 0, 0.96, 1.1, 0.2, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_flash(Color(0.92, 0.94, 1.0), 0.3, 0.02, 0.16)
	for i in _fx_count(10):
		_fx_paper(Vector2(18, 12), Color(0.94, 0.94, 0.92, 0.95),
			TRAVEL_TIME * (0.85 + 0.05 * float(i % 4)), 0.045 * float(i),
			-40.0 + float(i % 5) * 20.0, 4.0)
		if i % 3 == 0:
			await _body_play(enemy_character, [_beat(0, 3, 0, 1.02, 0.98, 0.06)])
	await get_tree().create_timer(TRAVEL_TIME * 0.9).timeout
	_fx_splatter(player_character, Color(0.94, 0.94, 0.92, 0.95), 10, 30.0, 0.5)
	_fx_impact(move_id, 7.0, tint, 0.24)
	await _body_end(enemy_character)

# --- Notaryo Naku ---------------------------------------------------------

## PHYSICAL — a stamp on each fist. Left, right, then both together. The only
## three-hit combo among the ordinary rivals, so it lands as three separate
## thumps rather than one.
func _sig_notary_stampede(move_id: String, tint: Color) -> void:
	_telegraph("NOTARY STAMPEDE", tint, 0.34)
	_body_begin(enemy_character, BODY_CHEST)
	await _body_play(enemy_character, [
		_beat(-6, -8, 0, 0.94, 1.1, 0.2, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_body_bring_forward(enemy_character)
	await _body_play_walking(enemy_character, _melee_advance("charge", 0.56), 14.0)
	var dx := _melee_target_x() - _body_home_x(enemy_character)

	# Left, right, then both. Each thump is its own impact so the combo reads.
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx - 6, -6, -16, 1.12, 0.94, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_impact(move_id, 4.0, tint, 0.14)
	await _body_play(enemy_character, [
		_beat(dx + 4, -2, 16, 1.12, 0.94, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_impact(move_id, 4.0, tint, 0.14)
	await _body_play(enemy_character, [
		_beat(dx, -12, 0, 0.94, 1.14, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT),
		_beat(dx, 14, 0, 1.22, 0.8, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# The seal that hangs over you afterwards.
	_fx_ring(player_character, Color(0.9, 0.24, 0.22, 0.95), 104.0, 0.34)
	_fx_word("NOTARISED", player_character, Color(0.92, 0.28, 0.24), 12.0, 0.05, 14)
	_fx_impact(move_id, 9.0, tint, 0.28)
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.55), 11.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## RANGED — he signs the air, and the signature keeps travelling. One wide
## horizontal wave rather than a volley.
func _sig_signature_slash(move_id: String, tint: Color) -> void:
	_telegraph("SIGNATURE SLASH", tint, 0.4)
	_body_begin(enemy_character, BODY_CHEST)
	# The flourish: three strokes of a very large pen.
	await _body_play(enemy_character, [
		_beat(-10, -6, -14, 1.02, 1.04, 0.14, Tween.TRANS_SINE, Tween.EASE_OUT),
		_beat(8, -2, 12, 1.04, 1.0, 0.12),
		_beat(-4, -8, -8, 1.02, 1.04, 0.12),
	])
	_fx_word("~Naku~", enemy_character, Color(0.42, 0.44, 0.72), 16.0, 0.0, 13)
	await _body_play(enemy_character, [
		_beat(14, 0, 20, 1.1, 0.94, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# The ink wave — long, thin, and fast.
	_fx_slab(enemy_character, player_character, tint, Vector2(96, 9),
		TRAVEL_TIME * 0.8, 0.0, 0.0, 0.0, 1)
	await get_tree().create_timer(TRAVEL_TIME * 0.8).timeout
	_fx_splatter(player_character, Color(0.22, 0.24, 0.5, 0.95), 9, 26.0, 0.6)
	_fx_impact(move_id, 7.0, tint, 0.24)
	await _body_end(enemy_character)

## RANGED / TRAP — a seal glows under your feet and gives you exactly one beat
## to notice it. The chapter's clearest telegraphed ground attack.
func _sig_seal_of_approval(move_id: String, tint: Color) -> void:
	_telegraph("SEAL OF APPROVAL", tint, 0.3)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(0, 12, 0, 1.08, 0.9, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN),
	])

	# The warning: a circle drawn on the floor under the player that closes in.
	var centre := player_character.position + Vector2(player_character.size.x * 0.5, 0.0)
	var seal := Panel.new()
	seal.add_theme_stylebox_override("panel", _fx_style(Color(tint.r, tint.g, tint.b, 0.45), 40))
	seal.size = Vector2(96, 24)
	seal.position = Vector2(centre.x - 48.0, _stage_floor() - 14.0)
	_fx_node(seal, 1.1)
	var warn := create_tween()
	warn.tween_property(seal, "modulate:a", 1.0, 0.16)
	warn.tween_property(seal, "size", Vector2(56, 16), 0.34)
	warn.parallel().tween_property(seal, "position:x", centre.x - 28.0, 0.34)
	await warn.finished

	# Then it erupts: papers, ink and stamps straight up.
	for i in _fx_count(7):
		var shard := Panel.new()
		shard.add_theme_stylebox_override("panel", _fx_style(tint, 1))
		shard.size = Vector2(10, 14)
		shard.position = Vector2(centre.x - 5.0 + randf_range(-24.0, 24.0), _stage_floor() - 10.0)
		_fx_node(shard, 0.6)
		var up := create_tween()
		up.tween_property(shard, "position:y", _stage_floor() - randf_range(70.0, 120.0), 0.24)
		up.parallel().tween_property(shard, "rotation", randf_range(-3.0, 3.0), 0.24)
		up.tween_property(shard, "modulate:a", 0.0, 0.22)
	_fx_ring(player_character, tint, 96.0, 0.3)
	_fx_impact(move_id, 8.0, tint, 0.28)
	await _body_end(enemy_character)

# --- Cashier Kaltas -------------------------------------------------------

## PHYSICAL — the whole drawer comes out of the counter and swings like a
## hammer. Coins leave it on contact.
func _sig_cash_drawer_bash(move_id: String, tint: Color) -> void:
	_telegraph("CASH DRAWER BASH", tint, 0.36)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(-14, 2, 0, 1.08, 0.96, 0.18, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(-4, -10, -8, 0.96, 1.1, 0.16, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_body_bring_forward(enemy_character)
	await _body_play_walking(enemy_character, _melee_advance("charge", 0.58), 13.0)
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx, -14, -26, 1.0, 1.08, 0.1, Tween.TRANS_BACK, Tween.EASE_OUT),
		_beat(dx, 12, 24, 1.2, 0.84, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# Coins out of the drawer, in an arc rather than a spray.
	for i in _fx_count(8):
		_spawn_bolt(player_character, enemy_character, Color(0.98, 0.86, 0.4, 0.95),
			8.0, 0.34, 0.02 * float(i), randf_range(-60.0, 60.0), true)
	_fx_impact(move_id, 10.0, tint, 0.28)
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.55), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## RANGED — Ping. Ping. PING. Three flicks, the last one bigger and faster.
func _sig_coin_flick(move_id: String, tint: Color) -> void:
	_telegraph("COIN FLICK", tint, 0.26)
	_body_begin(enemy_character, BODY_CHEST)
	var sizes := [9.0, 9.0, 16.0]
	var rates := [1.0, 0.9, 0.6]
	for i in 3:
		# A short aim before each one, so the third reads as deliberate.
		await _body_play(enemy_character, [
			_beat(-4, 0, -5, 1.0, 1.0, 0.1 if i < 2 else 0.2, Tween.TRANS_SINE, Tween.EASE_OUT),
			_beat(6, -2, 7, 1.04, 0.97, 0.07, Tween.TRANS_QUAD, Tween.EASE_IN),
		])
		_spawn_bolt(enemy_character, player_character, tint,
			float(sizes[i]), TRAVEL_TIME * float(rates[i]), 0.0, 0.0, false)
		if i == 2:
			_fx_word("PING!", enemy_character, Color(1.0, 0.9, 0.45), 18.0, 0.0, 13)
	await get_tree().create_timer(TRAVEL_TIME * 0.7).timeout
	_fx_impact(move_id, 7.0, tint, 0.24)
	await _body_end(enemy_character)

## PHYSICAL / MID — the register prints until the paper reaches the floor, and
## then she picks it up. Reach without closing the distance.
func _sig_receipt_whip(move_id: String, tint: Color) -> void:
	_telegraph("RECEIPT WHIP", tint, 0.3)
	_body_begin(enemy_character, BODY_CHEST)

	# The register printing: a strip that grows downward beside her.
	var strip := Panel.new()
	strip.add_theme_stylebox_override("panel", _fx_style(Color(0.94, 0.93, 0.88, 0.95), 1))
	strip.size = Vector2(9, 6)
	strip.position = enemy_character.position + Vector2(enemy_character.size.x * 0.28, 40.0)
	_fx_node(strip, 1.2)
	var print_out := create_tween()
	print_out.tween_property(strip, "size", Vector2(9, 74), 0.34)
	await print_out.finished

	# Grabs it and spins it overhead.
	await _body_play(enemy_character, [
		_beat(-6, 4, -10, 1.04, 0.98, 0.12),
		_beat(0, -10, -22, 0.98, 1.08, 0.16, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	var lift := create_tween()
	lift.tween_property(strip, "modulate:a", 0.0, 0.12)

	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(12, -4, 28, 1.14, 0.92, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# The whip itself: a long thin lash across the gap.
	_fx_slab(enemy_character, player_character, Color(0.94, 0.93, 0.88, 0.95),
		Vector2(110, 6), 0.16, 0.0, -10.0, 0.0, 1)
	await get_tree().create_timer(0.18).timeout
	# Tears into pieces on contact.
	for i in _fx_count(6):
		_fx_paper(Vector2(14, 5), Color(0.94, 0.93, 0.88, 0.95), 0.3,
			0.02 * float(i), randf_range(-40.0, 40.0), 2.0)
	_fx_impact(move_id, 8.0, tint, 0.24)
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_end(enemy_character)

# --- Budget Bandido -------------------------------------------------------

## PHYSICAL — he can barely lift it. One spin, and the sack does the rest.
## Ends by pocketing a coin he dropped, which is the whole character.
func _sig_budget_bag_bash(move_id: String, tint: Color) -> void:
	_telegraph("BUDGET BAG BASH", tint, 0.4)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(0, 16, 0, 1.12, 0.84, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(0, 10, -4, 1.08, 0.9, 0.14),
		_beat(0, 12, 4, 1.08, 0.9, 0.14),
	])
	_body_bring_forward(enemy_character)
	await _body_play_walking(enemy_character, _melee_advance("walk", 0.66), 10.0)
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	# A torso whip, not a cartwheel. This used to rotate the whole node
	# through 360 degrees, which turned the legs and head with the arms --
	# the clearest case of the sprite being spun rather than the body
	# swinging. The arc now stays inside what a torso can actually do and
	# the drawn attack frames carry the limb.
	# The weight still comes round with him -- in the squash, which sells a
	# heavy bag far better than turning him upside down did.
	await _body_play(enemy_character, [
		_beat(dx, 4, -26, 1.06, 0.96, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(dx, 0, 16, 1.16, 0.88, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	for i in _fx_count(9):
		_spawn_bolt(player_character, enemy_character, Color(0.98, 0.84, 0.34, 0.95),
			9.0, 0.4, 0.02 * float(i), randf_range(-70.0, 70.0), true)
	_fx_impact(move_id, 11.0, tint, 0.3)
	# Stoops for one coin before leaving.
	await _body_play(enemy_character, [
		_beat(dx - 12, 20, 0, 1.1, 0.86, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(dx - 12, 0, 0, 1.0, 1.0, 0.14),
	])
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.58), 10.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## RANGED — one coin goes up, a calculator comes out, and considerably more
## coins come down. A shotgun spread rather than a line.
func _sig_coin_burst(move_id: String, tint: Color) -> void:
	_telegraph("COIN BURST", tint, 0.34)
	_body_begin(enemy_character, BODY_CHEST)
	# Tosses the one coin.
	_spawn_bolt(enemy_character, enemy_character, tint, 10.0, 0.3, 0.0, -70.0, false)
	await _body_play(enemy_character, [
		_beat(0, -8, 0, 0.98, 1.08, 0.18, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	# The calculator: numbers rising while he works.
	for i in _fx_count(4):
		_fx_word(str(randi_range(100, 999)), enemy_character,
			Color(0.7, 0.94, 0.72), 20.0, 0.06 * float(i), 10)
	await _body_play(enemy_character, [
		_beat(0, 2, 0, 1.02, 0.98, 0.1),
		_beat(0, 0, 0, 1.0, 1.0, 0.1),
	])
	# ...and the spread.
	for i in _fx_count(11):
		_spawn_bolt(enemy_character, player_character, tint,
			randf_range(7.0, 12.0), TRAVEL_TIME * randf_range(0.7, 1.0),
			0.02 * float(i), randf_range(-52.0, 52.0), true)
	await get_tree().create_timer(TRAVEL_TIME * 0.85).timeout
	_fx_splatter(player_character, tint, 8, 28.0, 0.5)
	_fx_impact(move_id, 8.0, tint, 0.26)
	await _body_end(enemy_character)

## PHYSICAL / AREA — a red figure appears overhead, and then the sack it
## belongs to lands. The only attack in the chapter that arrives from above.
func _sig_deficit_drop(move_id: String, tint: Color) -> void:
	_telegraph("DEFICIT DROP", tint, 0.46)
	_body_begin(enemy_character, BODY_CHEST)
	await _body_play(enemy_character, [
		_beat(0, -6, 0, 0.96, 1.08, 0.22, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	# The number, hanging over the player as a warning.
	_fx_word("-PPP", player_character, Color(0.94, 0.22, 0.18), 4.0, 0.0, 20)
	await get_tree().create_timer(0.38).timeout

	# The sack itself, falling from off the top of the screen.
	var sack := Panel.new()
	sack.add_theme_stylebox_override("panel", _fx_style(Color(0.86, 0.72, 0.34, 0.98), 8, 12.0))
	sack.size = Vector2(56, 62)
	var cx := player_character.position.x + player_character.size.x * 0.5 - 28.0
	sack.position = Vector2(cx, -80.0)
	_fx_node(sack, 0.9)
	var fall := create_tween()
	fall.tween_property(sack, "position:y", _stage_floor() - 58.0, 0.26) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	var squash := create_tween()
	squash.tween_property(sack, "size", Vector2(76, 30), 0.1)
	squash.parallel().tween_property(sack, "position:y", _stage_floor() - 26.0, 0.1)
	squash.tween_property(sack, "modulate:a", 0.0, 0.3)

	_shake_screen(12.0)
	_fx_splatter(player_character, Color(0.98, 0.84, 0.34, 0.95), 10, 32.0, 0.6)
	_fx_impact(move_id, 12.0, tint, 0.32)
	await _body_end(enemy_character)

# --- Bidding Bandit -------------------------------------------------------

## PHYSICAL — jab, spin, overhead. Three distinct blows rather than one swing,
## and the case bursts open on the last of them.
func _sig_briefcase_beatdown(move_id: String, tint: Color) -> void:
	_telegraph("BRIEFCASE BEATDOWN", tint, 0.32)
	_body_begin(enemy_character, BODY_CHEST)
	await _body_play(enemy_character, [
		_beat(-6, 2, 0, 1.04, 0.98, 0.16, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	_body_bring_forward(enemy_character)
	await _body_play_walking(enemy_character, _melee_advance("dash", 0.5), 15.0)
	var dx := _melee_target_x() - _body_home_x(enemy_character)

	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	await _body_play(enemy_character, [        # jab
		_beat(dx + 4, 0, -8, 1.1, 0.96, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_impact(move_id, 4.0, tint, 0.12)
	# A torso whip, not a cartwheel. This used to rotate the whole node
	# through 360 degrees, which turned the legs and head with the arms --
	# the clearest case of the sprite being spun rather than the body
	# swinging. The arc now stays inside what a torso can actually do and
	# the drawn attack frames carry the limb.
	await _body_play(enemy_character, [        # the swing itself
		_beat(dx, -4, -22, 1.06, 0.98, 0.14, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(dx, 0, 14, 1.1, 0.94, 0.1),
	])
	_fx_impact(move_id, 5.0, tint, 0.14)
	await _body_play(enemy_character, [        # overhead smash
		_beat(dx, -18, 0, 0.94, 1.16, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT),
		_beat(dx, 16, 10, 1.22, 0.8, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# The case comes open and the contracts get out.
	for i in _fx_count(9):
		_fx_paper(Vector2(16, 11), Color(0.94, 0.92, 0.86, 0.95), 0.42,
			0.02 * float(i), randf_range(-70.0, 70.0), 3.0)
	_fx_impact(move_id, 10.0, tint, 0.3)
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.54), 11.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## RANGED — folders fanned like a hand of cards. The last one is the winning
## bid, and it travels faster than the rest for that reason.
func _sig_bid_folder_fan(move_id: String, tint: Color) -> void:
	_telegraph("BID FOLDER FAN", tint)
	_body_begin(enemy_character, BODY_CHEST)
	await _body_play(enemy_character, [
		_beat(-8, -4, -10, 1.02, 1.02, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	var hues := [
		Color(0.56, 0.82, 0.72, 0.95),
		Color(0.86, 0.74, 0.46, 0.95),
		Color(0.66, 0.70, 0.90, 0.95),
	]
	for i in _fx_count(3):
		_fx_paper(Vector2(20, 26), hues[i % hues.size()], TRAVEL_TIME * 1.1,
			0.11 * float(i), -26.0 + float(i) * 26.0, 2.0)
		await _body_play(enemy_character, [
			_beat(8, -2, 10, 1.04, 0.97, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
			_beat(-2, 0, -4, 1.0, 1.0, 0.06),
		])
	# The winning bid: bigger, faster, and announced.
	_fx_word("WINNING BID", enemy_character, Color(1.0, 0.92, 0.5), 20.0, 0.0, 12)
	_fx_paper(Vector2(28, 34), Color(1.0, 0.9, 0.44, 0.98), TRAVEL_TIME * 0.62,
		0.0, 0.0, 4.0)
	await get_tree().create_timer(TRAVEL_TIME * 0.7).timeout
	_fx_impact(move_id, 8.0, tint, 0.26)
	await _body_end(enemy_character)

## RANGED / TRAP — it unrolls at your feet, finds your ankles, and asks for a
## signature. The player is visibly held before the damage lands.
func _sig_contract_snare(move_id: String, tint: Color) -> void:
	_telegraph("CONTRACT SNARE", tint, 0.3)
	_body_begin(enemy_character, BODY_CHEST)
	await _body_play(enemy_character, [
		_beat(-6, -6, -12, 1.0, 1.04, 0.16, Tween.TRANS_SINE, Tween.EASE_OUT),
		_beat(10, 2, 14, 1.06, 0.96, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# The roll, thrown low at the feet.
	_fx_slab(enemy_character, player_character, tint, Vector2(26, 8),
		TRAVEL_TIME * 0.8, 0.0, 26.0, 5.0, 1)
	await get_tree().create_timer(TRAVEL_TIME * 0.8).timeout

	# It unrolls and closes around the player's legs.
	var bind := Panel.new()
	bind.add_theme_stylebox_override("panel", _fx_style(Color(0.94, 0.9, 0.8, 0.95), 2))
	bind.size = Vector2(6, 34)
	var cx := player_character.position.x + player_character.size.x * 0.5
	bind.position = Vector2(cx - 3.0, _stage_floor() - 38.0)
	_fx_node(bind, 1.0)
	var wrap := create_tween()
	wrap.tween_property(bind, "size", Vector2(54, 34), 0.18)
	wrap.parallel().tween_property(bind, "position:x", cx - 27.0, 0.18)

	# Signature lines, then it snaps shut.
	for i in _fx_count(3):
		_fx_word("_______", player_character, Color(0.4, 0.42, 0.66),
			10.0 + float(i) * 8.0, 0.08 * float(i), 10)
	await get_tree().create_timer(0.42).timeout
	var snap := create_tween()
	snap.tween_property(bind, "size", Vector2(14, 34), 0.08)
	snap.parallel().tween_property(bind, "position:x", cx - 7.0, 0.08)
	snap.tween_property(bind, "modulate:a", 0.0, 0.2)
	_fx_ring(player_character, tint, 70.0, 0.26)
	_fx_impact(move_id, 9.0, tint, 0.28)
	await _body_end(enemy_character)

# --- Ordinance Ogre -------------------------------------------------------

## PHYSICAL — he shuts the book on the argument, then swings it like a club.
func _sig_codex_crusher(move_id: String, tint: Color) -> void:
	_telegraph("CODEX CRUSHER", tint, 0.4)
	_body_begin(enemy_character, BODY_FEET)
	# The book closing — one hard clap of the whole body.
	await _body_play(enemy_character, [
		_beat(0, -6, 0, 1.1, 1.02, 0.16, Tween.TRANS_SINE, Tween.EASE_OUT),
		_beat(0, 6, 0, 0.9, 1.04, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_splatter(enemy_character, Color(0.8, 0.74, 0.6, 0.8), 5, 18.0, 0.4)
	_body_bring_forward(enemy_character)
	await _body_play_walking(enemy_character, _melee_advance("charge", 0.66), 11.0)
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx, -8, -34, 1.04, 1.06, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT),
		_beat(dx, 4, 34, 1.26, 0.84, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# Papers, dust and roman numerals.
	for i in _fx_count(7):
		_fx_paper(Vector2(15, 11), Color(0.9, 0.86, 0.74, 0.95), 0.42,
			0.02 * float(i), randf_range(-60.0, 60.0), 3.0)
	for i in _fx_count(3):
		_fx_word(["XIV", "IX", "XXII"][i % 3], player_character,
			Color(0.94, 0.88, 0.6), 24.0, 0.06 * float(i), 12)
	_fx_impact(move_id, 12.0, tint, 0.3)
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.6), 9.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## RANGED — he points at a clause and the clause leaves the page at speed. It
## wraps before it bursts, so the hit has two stages.
func _sig_citation_cannon(move_id: String, tint: Color) -> void:
	_telegraph("CITATION CANNON", tint, 0.42)
	_body_begin(enemy_character, BODY_CHEST)
	# Flipping through for the right ordinance.
	for i in 3:
		await _body_play(enemy_character, [
			_beat(0, 2, -4, 1.02, 0.99, 0.07),
			_beat(0, 0, 4, 1.02, 0.99, 0.07),
		])
	# The point.
	await _body_play(enemy_character, [
		_beat(12, -4, 10, 1.08, 0.96, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# The scroll, fired flat and fast.
	_fx_slab(enemy_character, player_character, tint, Vector2(34, 13),
		TRAVEL_TIME * 0.7, 0.0, 0.0, 1.0, 3)
	await get_tree().create_timer(TRAVEL_TIME * 0.7).timeout
	# Wraps around the player...
	_fx_ring(player_character, tint, 58.0, 0.2)
	await get_tree().create_timer(0.18).timeout
	# ...then bursts into scraps.
	_fx_splatter(player_character, Color(0.92, 0.88, 0.72, 0.95), 10, 30.0, 0.5)
	_fx_impact(move_id, 9.0, tint, 0.28)
	await _body_end(enemy_character)

## PHYSICAL / HEAVY — the gavel grows, he jumps, and the floor does not enjoy
## it. The single heaviest impact among the ordinary rivals.
func _sig_session_smash(move_id: String, tint: Color) -> void:
	_telegraph("SESSION SMASH", tint, 0.5)
	_body_begin(enemy_character, BODY_FEET)
	# The gavel growing, shown as a ring that swells around him.
	_fx_ring(enemy_character, Color(0.94, 0.8, 0.4, 0.85), 92.0, 0.34)
	await _body_play(enemy_character, [
		_beat(0, 14, 0, 1.12, 0.86, 0.22, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_body_bring_forward(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	# Straight up, across, and down.
	await _body_play(enemy_character, [
		_beat(dx * 0.4, -78, -6, 0.9, 1.2, 0.26, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(dx, -62, 6, 0.94, 1.14, 0.14),
	])
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx, 18, 16, 1.3, 0.74, 0.1, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	# Cracks along the floor, drawn outward from the point of impact.
	for i in _fx_count(6):
		var crack := Panel.new()
		crack.add_theme_stylebox_override("panel", _fx_style(Color(0.2, 0.16, 0.12, 0.9), 0))
		crack.size = Vector2(2, 3)
		crack.position = Vector2(player_character.position.x + player_character.size.x * 0.5,
			_stage_floor() - 4.0)
		_fx_node(crack, 0.7)
		var grow := create_tween()
		grow.tween_property(crack, "size", Vector2(randf_range(26.0, 54.0), 3), 0.16)
		grow.parallel().tween_property(crack, "position:x",
			crack.position.x + randf_range(-54.0, 54.0), 0.16)
		grow.tween_property(crack, "modulate:a", 0.0, 0.4)
	_shake_screen(15.0)
	_fx_flash(Color(0.96, 0.86, 0.5), 0.4)
	_fx_impact(move_id, 14.0, tint, 0.34)
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.62), 9.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

# --- Don Eraptado (boss) --------------------------------------------------

## PHYSICAL — two taps of the cane, a chest rolled in, and then he carries it
## himself. The slow walk before the dash is the whole point: he is not in a
## hurry until he decides to be.
func _sig_kaban_ng_bayan(move_id: String, tint: Color) -> void:
	_telegraph("KABAN NG BAYAN", tint, 0.44)
	_body_begin(enemy_character, BODY_FEET)
	# Cane, twice.
	for i in 2:
		await _body_play(enemy_character, [
			_beat(0, 5, 0, 1.02, 0.97, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
			_beat(0, 0, 0, 1.0, 1.0, 0.11),
		])
	# The chest arrives from off screen behind him.
	var chest := Panel.new()
	chest.add_theme_stylebox_override("panel", _fx_style(Color(0.72, 0.52, 0.24, 0.98), 4, 10.0))
	chest.size = Vector2(46, 34)
	chest.position = Vector2(Layout.profile.design_size.x + 40.0, _stage_floor() - 34.0)
	_fx_node(chest, 1.6)
	var roll := create_tween()
	roll.tween_property(chest, "position:x",
		enemy_character.position.x + enemy_character.size.x * 0.5, 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await roll.finished
	_fx_word("KABAN NG BAYAN", enemy_character, Color(1.0, 0.88, 0.44), 26.0, 0.0, 11)

	# Cracks his knuckles, then picks it up.
	await _body_play(enemy_character, [
		_beat(0, 2, -4, 1.02, 0.99, 0.12),
		_beat(0, 2, 4, 1.02, 0.99, 0.12),
		_beat(0, 12, 0, 1.1, 0.88, 0.18, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	var carry := create_tween()
	carry.tween_property(chest, "modulate:a", 0.0, 0.14)

	_body_bring_forward(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	# Two unhurried steps...
	await _body_play_walking(enemy_character, [
		_beat(dx * 0.22, -5, 3, 1.0, 1.0, 0.24, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_beat(dx * 0.4, 0, 5, 1.0, 1.0, 0.24, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	], 8.0)
	# ...then all at once.
	await _body_play_walking(enemy_character, [
		_beat(dx, -2, 14, 1.08, 0.96, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN),
	], 18.0)
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx, -10, -30, 1.02, 1.1, 0.1, Tween.TRANS_BACK, Tween.EASE_OUT),
		_beat(dx, 8, 32, 1.28, 0.8, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	for i in _fx_count(12):
		_spawn_bolt(player_character, enemy_character, Color(1.0, 0.86, 0.36, 0.95),
			10.0, 0.46, 0.02 * float(i), randf_range(-80.0, 80.0), true)
	_shake_screen(13.0)
	_fx_impact(move_id, 13.0, tint, 0.32)
	# Fixes his clothes on the way back.
	await _body_play(enemy_character, [
		_beat(dx, 0, -3, 1.0, 1.0, 0.12),
		_beat(dx, -2, 3, 1.0, 1.0, 0.12),
	])
	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.62), 9.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

## RANGED — he never stands. The sacks fire on their own while he laughs, which
## is the point: this is the attack of a man who does not consider you work.
func _sig_plunder_supremo(move_id: String, tint: Color) -> void:
	_telegraph("PLUNDER SUPREMO", tint, 0.4)
	_body_begin(enemy_character, BODY_CHEST)
	# A snap of the fingers. He barely moves for the whole first half.
	await _body_play(enemy_character, [
		_beat(0, -3, 0, 1.0, 1.02, 0.14),
	])
	_fx_word("HA HA HA", enemy_character, Color(1.0, 0.9, 0.5), 24.0, 0.0, 12)

	# Five sacks, five different payloads, fired without him lifting a finger.
	var payloads := [
		{"size": 10.0, "col": Color(1.0, 0.86, 0.34, 0.95)},   # coins
		{"size": 16.0, "col": Color(0.94, 0.92, 0.84, 0.95)},  # bundled papers
		{"size": 8.0, "col": Color(0.9, 0.88, 0.8, 0.95)},     # receipts
		{"size": 18.0, "col": Color(0.86, 0.8, 0.62, 0.95)},   # contracts
		{"size": 13.0, "col": Color(1.0, 0.82, 0.3, 0.95)},    # gold tokens
	]
	for i in _fx_count(5):
		var p: Dictionary = payloads[i % payloads.size()]
		_spawn_bolt(enemy_character, player_character, p["col"], float(p["size"]),
			TRAVEL_TIME * 0.95, 0.12 * float(i), -30.0 + float(i) * 15.0, false)
		# A small shrug per volley, and nothing more.
		await _body_play(enemy_character, [_beat(0, 2, 0, 1.01, 0.99, 0.1)])

	# The last one has his face on it.
	_fx_word("SUPREMO", enemy_character, Color(1.0, 0.9, 0.42), 18.0, 0.0, 13)
	_spawn_bolt(enemy_character, player_character, Color(1.0, 0.84, 0.3, 1.0),
		30.0, TRAVEL_TIME * 1.1, 0.0, 0.0, false)
	await get_tree().create_timer(TRAVEL_TIME * 1.15).timeout
	_fx_ring(player_character, Color(1.0, 0.86, 0.36, 0.95), 108.0, 0.3)
	_fx_impact(move_id, 11.0, tint, 0.3)
	await _body_end(enemy_character)

## RANGED — he draws a number nobody chose and collects on it anyway. A spray
## of numbered tokens, one of which is the "winning" draw.
func _sig_jueteng_jackpot(move_id: String, tint: Color) -> void:
	_telegraph("JUETENG JACKPOT", tint, 0.36)
	_body_begin(enemy_character, BODY_CHEST)
	# Shaking the drum.
	for i in 3:
		await _body_play(enemy_character, [
			_beat(-5, 0, -6, 1.02, 0.99, 0.07),
			_beat(5, 0, 6, 1.02, 0.99, 0.07),
		])
	# Numbers tumbling out.
	for i in _fx_count(6):
		_fx_word(str(randi_range(1, 37)), enemy_character,
			Color(0.96, 0.6, 0.74), 22.0, 0.05 * float(i), 11)
	await _body_play(enemy_character, [
		_beat(0, -8, 0, 0.96, 1.1, 0.16, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	# The draw, fired as a scatter of tokens.
	for i in _fx_count(9):
		_spawn_bolt(enemy_character, player_character, tint,
			randf_range(8.0, 13.0), TRAVEL_TIME * randf_range(0.75, 1.05),
			0.03 * float(i), randf_range(-58.0, 58.0), true)
	await get_tree().create_timer(TRAVEL_TIME * 0.95).timeout
	_fx_word("JACKPOT!", player_character, Color(1.0, 0.72, 0.86), 20.0, 0.0, 16)
	_fx_splatter(player_character, tint, 9, 30.0, 0.55)
	_fx_impact(move_id, 10.0, tint, 0.3)
	await _body_end(enemy_character)

## PHASE 2 ONLY — the lights go out and he stops pretending. Ranged barrage
## first, then he closes the distance himself, which no other attack of his
## does. Also the counter: whatever the player had banked, he takes.
func _sig_executive_privilege(move_id: String, tint: Color) -> void:
	# The room goes dark, and one light finds him.
	var dark := ColorRect.new()
	dark.color = Color(0.02, 0.01, 0.0, 0.0)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.offset_right = Layout.profile.design_size.x
	dark.offset_bottom = Layout.profile.design_size.y
	# Long enough to outlive the whole move — this is a ~3.8s choreography and a
	# shorter life reaps the node before the lights come back up.
	_fx_node(dark, 6.0)
	var lights_out := create_tween()
	lights_out.tween_property(dark, "color:a", 0.72, 0.26)
	await lights_out.finished

	var spot := Panel.new()
	spot.add_theme_stylebox_override("panel",
		_fx_style(Color(1.0, 0.94, 0.68, 0.16), 60, 26.0))
	spot.size = Vector2(150, 150)
	spot.position = enemy_character.position + enemy_character.size * 0.5 - Vector2(75, 75)
	_fx_node(spot, 6.0)

	_fx_word("EXECUTIVE PRIVILEGE", enemy_character, Color(1.0, 0.9, 0.5), 30.0, 0.0, 14)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(0, -14, 0, 0.96, 1.14, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT),
	])

	# The paperwork he is entitled to, circling him.
	var docs := ["BUDGET", "CONTRACT", "PERMIT", "PAYROLL", "PROCUREMENT"]
	for i in _fx_count(5):
		_fx_word(docs[i % docs.size()], enemy_character,
			Color(1.0, 0.92, 0.62), 30.0 + float(i) * 7.0, 0.07 * float(i), 11)
	await get_tree().create_timer(0.4).timeout

	# The cane comes down and they turn into ammunition.
	await _body_play(enemy_character, [
		_beat(0, 16, 0, 1.14, 0.84, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_shake_screen(11.0)
	_fx_flash(Color(1.0, 0.82, 0.36), 0.5)
	for i in _fx_count(8):
		_spawn_bolt(enemy_character, player_character, tint,
			randf_range(11.0, 17.0), TRAVEL_TIME * randf_range(0.7, 1.0),
			0.05 * float(i), randf_range(-70.0, 70.0), true)
	await get_tree().create_timer(TRAVEL_TIME * 1.0).timeout

	# Then he comes for you himself — the only time he does.
	_body_bring_forward(enemy_character)
	await _body_play_walking(enemy_character, _melee_advance("dash", 0.4), 18.0)
	# Gather before the blow -- see _strike_windup.
	await _strike_windup(enemy_character)
	_body_swing(enemy_character)
	var dx := _melee_target_x() - _body_home_x(enemy_character)
	await _body_play(enemy_character, [
		_beat(dx, -16, -34, 1.0, 1.14, 0.09, Tween.TRANS_BACK, Tween.EASE_OUT),
		_beat(dx, 10, 30, 1.3, 0.78, 0.08, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_shake_screen(16.0)
	_fx_ring(player_character, Color(1.0, 0.88, 0.44, 0.95), 130.0, 0.32)
	_fx_impact(move_id, 15.0, tint, 0.38)

	# APPROVED... for him.
	_fx_word("APPROVED", enemy_character, Color(0.96, 0.3, 0.24), 16.0, 0.1, 18)
	await get_tree().create_timer(0.5).timeout
	_fx_word("FOR ME.", enemy_character, Color(1.0, 0.86, 0.4), 20.0, 0.0, 18)
	await get_tree().create_timer(0.35).timeout

	# Carry the blow through instead of stopping dead on impact.
	await _strike_follow(enemy_character)
	await _body_play_walking(enemy_character, _melee_retreat(0.5), 12.0)
	_body_send_back(enemy_character)
	await _body_end(enemy_character)

	# The lights come back up. Guarded because a fight that ends on this move
	# tears the scene down before the tween would have run.
	if is_instance_valid(dark) and is_instance_valid(spot):
		var lights_on := create_tween()
		lights_on.tween_property(dark, "color:a", 0.0, 0.4)
		lights_on.parallel().tween_property(spot, "modulate:a", 0.0, 0.4)


# --- tutorial -------------------------------------------------------------
#
# The tutorial is not a separate screen. It is THIS scene, running for real,
# with a coaching overlay on top of it (see TutorialDirector) and three things
# held back: the countdown, the question bank, and any ending that would write
# to GameState. Everything the player is shown -- the prompt, the board, the
# badge, the swing, the floating number, the rival's hit -- is the production
# code path executing, which is the only way an explanation can be guaranteed
# to still be true a month from now.

## The one question the tutorial ever asks. Kept here rather than in the bank so
## it can never be dealt during a real run, and so the cards below can quote its
## answer and its damage figure without hedging.
##
## MAYOR is five letters and easy-tier, which puts three of them in the prompt
## ("M _ Y _ R") and leaves two to work out -- enough to show the mechanic
## without turning the first thing a new player meets into a puzzle.
const TUTORIAL_QUESTION := {
	"prompt": "The elected head of a city is the ___.",
	"answer": "MAYOR",
	"category": "local government",
	"fact": "A city or municipal mayor serves a three-year term and may be elected for no more than three consecutive terms.",
}
## Pause between demonstration taps. Slow enough to follow a letter at a time,
## fast enough that spelling five of them is not a wait.
const TUTORIAL_TAP_INTERVAL := 0.28

func _begin_tutorial() -> void:
	_tutorial = TutorialDirector.new()
	_tutorial.name = "TutorialDirector"
	# Added last, so it draws over the pause and result overlays as well as the
	# board. Nothing else in this scene is added after the first layout pass.
	add_child(_tutorial)
	_tutorial.closed.connect(_on_tutorial_closed)
	_tutorial.begin(_tutorial_steps())

func _on_tutorial_closed(start_game: bool, completed: bool) -> void:
	# Only reaching the last card counts. Someone who taps SKIP on step two has
	# not been taught the game and should still be offered it next time.
	if completed:
		GameState.mark_tutorial_completed()
	GameState.tutorial_mode = false
	GameState.pending_play_request = start_game
	_tutorial = null
	# Both exits go through the title screen. START GAME leaves a request behind
	# for it to act on, rather than this scene trying to pick a chapter and a
	# character on the player's behalf.
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

## The script. Ordered as a player meets things: what the game is, what to read,
## what to touch, what it is worth, what happens when you are right, what
## happens when you are not, then the four things around the edge of the screen.
##
## Every claim below was checked against the function that implements it, and
## several of them are not what you would guess. A wrong word does not cost you
## health -- BoardController.is_submittable() refuses to submit anything that is
## not the answer, so the rival's free hit comes from the CLOCK or from New
## Question, not from being wrong. Losing does not retry the encounter, it
## rewinds the whole chapter and wipes the potion stock (_end_match). Winning
## does not refill your health, it refunds a share of it
## (BETWEEN_ENCOUNTER_HEAL_FRACTION).
func _tutorial_steps() -> Array[Dictionary]:
	# Resolved when the step is shown rather than captured now: the compact
	# arrangements hide the full roster and show a strip instead, and the player
	# can rotate the device mid-tutorial.
	var moves_target := func() -> Control:
		return side_panel if side_panel.visible else _move_strip
	# The board AND the chips the demonstration lifts into the tray, lit as one
	# region. Lighting the board alone left the coach card free to sit exactly
	# over the tray, hiding the word being spelled -- which is the one thing
	# that step exists to show.
	var board_target := func() -> Array:
		var parts: Array[Control] = [board]
		if word_tray.visible:
			for chip in word_tray.get_children():
				parts.append(chip as Control)
		return parts
	return [
		{
			"title": "Welcome to the fight",
			"body": "Each encounter is a question. Spell the missing word on the letter board and your character attacks. Empty the rival's health to win and move on to the next one.",
		},
		{
			"title": "1. Read the question",
			"body": "Every question hides one word. The blank shows how long it is and gives you some of its letters. Here it reads M _ Y _ R -- the elected head of a city.",
			"target": func() -> Control: return question_panel,
		},
		{
			"title": "2. Spell it on the board",
			"body": "Tap the letters in order to build the WHOLE word, not just the missing ones. Tap one you already picked to take it back. Watch:",
			"target": board_target,
			"action": _tutorial_spell_answer,
		},
		{
			"title": "3. What it is worth",
			"body": "This plate is the damage the question will do if you get it right. It is a range because spelling quickly pays a speed bonus -- the top of the range slips away the longer you take.",
			"target": func() -> Control: return _damage_badge,
		},
		{
			"title": "4. Attack",
			"body": "ATTACK only lights up when the word you have spelled IS the answer, so a wrong word can never be fired off. Watch the damage land, and watch the rival's bar.",
			"target": func() -> Control: return attack_button,
			"action": _tutorial_demo_attack,
		},
		{
			"title": "5. Being wrong costs time",
			"body": "A wrong word is simply refused -- it never reaches the rival. What hurts is the clock: let this bar empty and the rival takes a free swing at you. Here is one.",
			"target": func() -> Control: return timer_bar,
			"action": _tutorial_demo_enemy_turn,
		},
		{
			"title": "6. Your health",
			"body": "Your hearts. Drain them and the run ends: the chapter restarts from its first encounter and your potions go back to the starting stock.",
			"target": func() -> Control: return player_heart_row,
		},
		{
			"title": "7. The rival's health",
			"body": "Empty this to win the encounter. Your own health carries into the next fight -- winning refunds part of the bar, it does not refill it, which is what makes potions worth saving.",
			"target": func() -> Control: return enemy_heart_row,
		},
		{
			"title": "8. Potions are free",
			"body": "Drinking one never costs your turn -- heal and still attack in the same breath. Health restores %d HP. Power Up doubles your next answer, then burns off. Neither is spent if it would do nothing." % HEALTH_POTION_HEAL,
			"target": func() -> Control: return potion_panel,
		},
		{
			"title": "9. What the rival will do",
			"body": "Every rival works through a fixed rotation of moves. The one marked NEXT is the one that lands at the end of this exchange; once it has, the panel moves on to the following one.",
			"target": moves_target,
		},
		{
			"title": "10. New Question",
			"body": "Rerolls the prompt, the answer and the letters together when you are stuck. It costs your turn -- the rival gets a free hit for it -- and the clock starts again.",
			"target": func() -> Control: return shuffle_button,
		},
		{
			"title": "11. Menu",
			"body": "Pauses everything. Resume goes back in, Options has the music and sound sliders, and Title Page leaves the fight.",
			"target": func() -> Control: return menu_button,
		},
		{
			"title": "You are ready!",
			"body": "Answer correctly, deal damage, defeat your rivals, and learn more about Philippine elections as you work through each chapter. You can open this tutorial again from the title screen any time.",
		},
	]

## Taps the answer out on the board a letter at a time.
##
## Clears whatever is already selected first, so stepping BACK past this card
## and forward into it again re-spells the word rather than appending a second
## copy of it to the selection.
func _tutorial_spell_answer() -> void:
	board.deselect_from(0)
	await get_tree().process_frame
	var answer := String(_question.get("answer", ""))
	for letter in answer:
		if not board.demo_select(letter):
			return
		await get_tree().create_timer(TUTORIAL_TAP_INTERVAL).timeout

## Fires the spelled answer through the real submit path and waits out the
## exchange it starts -- the swing, the floating number, the rival's flinch.
##
## Re-spells first if the selection is not already the answer, which is what
## makes this card survive being reached out of order.
func _tutorial_demo_attack() -> void:
	var answer := String(_question.get("answer", ""))
	if _current_selection.to_upper() != answer:
		await _tutorial_spell_answer()
		await get_tree().create_timer(0.35).timeout
	board.submit_word()
	# _play_attack_sequence raises the flag before its first await, so by the
	# time submit_word() returns this is already true if a hit was accepted.
	while _sequence_running:
		await get_tree().process_frame

## The rival's half of an exchange, run on its own so the card about running out
## of time can show what running out of time looks like. Mirrors _handle_timeout
## minus the parts a tutorial must not do: no death check, and no reroll of a
## question that is fixed anyway.
func _tutorial_demo_enemy_turn() -> void:
	_sequence_running = true
	_update_action_buttons()
	await get_tree().create_timer(BEAT_PAUSE).timeout
	await _resolve_enemy_turn()
	if _player_hp <= 0:
		_player_hp = roundi(GameState.player_max_hp * 0.4)
		player_heart_row.set_value(_player_hp)
	_sequence_running = false
	_update_action_buttons()

# --- Chapter 3: per-skill choreography ------------------------------------
#
# Chapters 1 and 2 gave every skill its own _sig_ routine. Chapter 3 shipped
# with all twenty-four sharing one generic block, which is why its rivals read
# as the same fight repeated: identical wind-up, identical bolt, identical
# recovery, whatever the skill was called.
#
# What a skill can actually DO here is bounded by two things, and it is worth
# being plain about which is which:
#
#   THE DRAWN CLIPS carry the real limb work. Each rival has attack (12
#   frames), attack2 (12) and guard (10) -- separate hand-drawn motions, not
#   one clip recoloured. Nothing here can add a limb the frames do not draw.
#
#   THE CUT-OUT RIG (AnimatedCharacter.rig_pose) splits whatever frame is on
#   screen into legs / torso / head bands and rotates them independently. That
#   is what makes anticipation and recovery read as a BODY rather than a
#   sliding picture: knees compress, the torso twists away from the target,
#   the head leads or lags.
#
# So every skill below is built the same way, and it is the shape the brief
# asks for:
#
#   ANTICIPATION + WIND-UP   rig -- knees, torso, head
#   EXECUTION                the drawn clip, which is where the arm work lives
#   RELEASE / IMPACT         props leave the hand on the frame they should
#   FOLLOW-THROUGH+RECOVERY  rig again, then back to the exact idle baseline
#
# Props are the third piece. A coin pouch, a valuation stamp, a cashbox, a red
# pen, a rolled masterplan, a briefcase: none are drawn in the sprites, so each
# is a node that spawns at the hand, travels the arc the swing implies, and
# dies. That is what puts the named weapon on screen.

## Where a held prop sits on the sprite, as a fraction of its box. The rivals
## face LEFT (the player stands on the left), so the working hand is on the
## left side of the canvas.
const CH3_HAND := Vector2(0.30, 0.44)
const CH3_HAND_HIGH := Vector2(0.32, 0.24)

## The rig's anticipation pose. Held for `secs`, then the caller hands the body
## back to its drawn frames with _ch3_ungather.
##
## Positive `legs` rotates the whole figure back onto its rear foot, which is
## what a wind-up looks like from the side; `torso` counter-rotates against it
## and `head` against that, so the three bands do not read as one hinge.
func _ch3_gather(legs: float, torso: float, head: float,
		bob: float = 0.0, sway: float = 0.0, secs: float = 0.18) -> void:
	enemy_character.rig_enable()
	enemy_character.rig_pose(legs, torso, head, bob, sway, secs)
	await get_tree().create_timer(secs).timeout

## Another rig beat without rebuilding the cut-out -- for a two-stage gather
## (settle, then coil) or a recoil after the blow.
func _ch3_pose(legs: float, torso: float, head: float,
		bob: float = 0.0, sway: float = 0.0, secs: float = 0.12) -> void:
	if not enemy_character.is_rigged():
		enemy_character.rig_enable()
	enemy_character.rig_pose(legs, torso, head, bob, sway, secs)
	await get_tree().create_timer(secs).timeout

## Back to a neutral stance and off the rig, so the drawn clip can take over
## from exactly the pose the rig left.
func _ch3_ungather(secs: float = 0.09) -> void:
	if not enemy_character.is_rigged():
		return
	enemy_character.rig_pose(0.0, 0.0, 0.0, 0.0, 0.0, secs)
	await get_tree().create_timer(secs + 0.01).timeout
	enemy_character.rig_disable()

## Plays this skill's own drawn clip over `secs`.
func _ch3_clip(move: EnemyMove, secs: float = 0.80) -> void:
	if _ch5_move_active:
		secs *= _ch5_pace()
	if not move.attack_dir.is_empty():
		enemy_character.play_clip(move.attack_dir, move.attack_count, secs)
	else:
		enemy_character.play_attack()

## A held object. Spawned at the rival's hand rather than at its centre, so a
## swing starts where a hand is instead of out of the chest.
func _ch3_prop(tint: Color, prop_size: Vector2, corner: int = 2,
		high: bool = false) -> Panel:
	var prop := Panel.new()
	prop.add_theme_stylebox_override("panel", _fx_style(tint, corner, prop_size.x * 0.3))
	prop.size = prop_size
	prop.pivot_offset = prop_size * 0.5
	var anchor: Vector2 = CH3_HAND_HIGH if high else CH3_HAND
	prop.position = enemy_character.position + enemy_character.size * anchor - prop_size * 0.5
	_fx_node(prop, 1.2)
	return prop

## Carries a prop through the arc its swing implies. `dx`/`dy` are relative to
## where it spawned, so a caller thinks in "up and across", not screen coords.
func _ch3_prop_arc(prop: Panel, dx: float, dy: float, spin_deg: float,
		secs: float, fade: bool = true) -> void:
	var tween := create_tween()
	tween.parallel().tween_property(prop, "position",
		prop.position + Vector2(dx, dy), secs).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(prop, "rotation", deg_to_rad(spin_deg), secs)
	if fade:
		tween.parallel().tween_property(prop, "modulate:a", 0.0, secs).set_delay(secs * 0.55)

## The walk in, using the rival's real ten-frame walk cycle. Chapter 3's rivals
## all have one, so _body_play_walking uses the drawn legs rather than the rig.
func _ch3_walk_in(secs: float = 0.42, gait: String = "charge") -> void:
	_body_bring_forward(enemy_character)
	await _body_play_walking(enemy_character, _melee_advance(gait, secs), 10.0)

## Dispatch. Every id below is a real Chapter 3 move; anything unmatched falls
## through to a competent generic performance rather than nothing, so a skill
## added tomorrow still animates.
func _ch3_perform(move_id: String, move: EnemyMove, tint: Color,
		melee: bool, defending: bool) -> void:
	# One approach for every melee skill, so a routine never has to know whether
	# the data calls it a slam. The retreat is the resolver's, already.
	if melee:
		await _ch3_walk_in(0.46, "stride")
	if move_id.begins_with("c4combat_"):
		await _ch4_perform(move_id, move, tint, melee, defending)
		return
	if move_id.begins_with("c5combat_"):
		await _ch5_perform(move_id, move, tint, melee, defending)
		return
	match move_id:
		# --- Bokal Bulsa: the pocket politico -----------------------------
		"c3combat_resolution_ricochet": await _ch3_kickback_flick(move, tint)
		"c3combat_pocket_punch": await _ch3_pocket_payload(move, tint)
		"c3combat_pocket_privilege": await _ch3_deep_pockets(move, tint)
		# --- Assessor Altapresyo: the valuation vulture -------------------
		"c3combat_tax_tag_toss": await _ch3_markup_strike(move, tint)
		"c3combat_appraisal_hammer": await _ch3_appraisal_talons(move, tint)
		"c3combat_assessment_shield": await _ch3_overvalued_cover(move, tint)
		# --- Treasurer Tago: the vault keeper -----------------------------
		"c3combat_coffer_crush": await _ch3_treasury_slam(move, tint)
		"c3combat_lockbox_launch": await _ch3_keychain_lash(move, tint)
		"c3combat_vault_lockdown": await _ch3_vault_lockdown(move, tint)
		# --- Auditor Alibi: the paper trail painter -----------------------
		"c3combat_red_pen_riposte": await _ch3_redaction_slash(move, tint)
		"c3combat_paper_trail_storm": await _ch3_paper_trail_torrent(move, tint)
		"c3combat_audit_exception": await _ch3_whitewash(move, tint)
		# --- Planner Palusot: the masterplan manipulator ------------------
		"c3combat_blueprint_bash": await _ch3_blueprint_crossfire(move, tint)
		"c3combat_zoning_grid": await _ch3_compass_sweep(move, tint)
		"c3combat_revised_plan": await _ch3_strategic_reroute(move, tint)
		# --- Engineer Eskandalo: the project wrecker ----------------------
		"c3combat_hard_hat_headbutt": await _ch3_substandard_smash(move, tint)
		"c3combat_concrete_chuck": await _ch3_rebar_rake(move, tint)
		"c3combat_safety_barricade": await _ch3_hardhat_hunker(move, tint)
		# --- Contractor Kutsaba: the capitol partner ----------------------
		"c3combat_change_order_barrage": await _ch3_rigged_deal(move, tint)
		"c3combat_contract_case_combo": await _ch3_partners_cut(move, tint)
		"c3combat_partner_protection": await _ch3_padded_contract(move, tint)
		# --- Project Padrino: the backroom benefactor ---------------------
		"c3combat_backroom_deal": await _ch3_strings_attached(move, tint)
		"c3combat_padrino_palm": await _ch3_backroom_verdict(move, tint)
		"c3combat_padrinos_favor": await _ch3_patrons_protection(move, tint)
		_: await _ch3_generic(move, tint, melee, defending)

## The fallback, kept deliberately competent: it still gathers on the rig and
## still throws, so an unnamed skill is plain rather than broken.
func _ch3_generic(move: EnemyMove, tint: Color, melee: bool, _defending: bool) -> void:
	await _ch3_gather(4.0, -5.0, -3.0, 2.0, 3.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.80)
	_fx_charge(enemy_character, tint, 0.28)
	await _body_play(enemy_character, [_beat(_ch3_dx(), 0, 0, 1, 1, 0.22)])
	if not melee:
		var count := 3 if move.animation_style == "volley" else 1
		for i in count:
			_spawn_bolt(enemy_character, player_character, tint, 8.0,
				0.15, float(i) * 0.035, float(i - count / 2) * 8.0, false)
		await get_tree().create_timer(0.22).timeout

## Where the body currently is relative to its home, so a beat written for a
## standing rival still works after a melee walk-in has moved it.
func _ch3_dx() -> float:
	return enemy_character.position.x - _body_home_x(enemy_character)

# =========================================================================
# BOKAL BULSA -- The Pocket Politico
# =========================================================================

## RANGED. Envelopes flicked off the fingers -- the drawn attack clip is
## exactly that motion, so the clip does the arm and the rig does the lean.
## Three envelopes leave on three different lines: straight, curving up, then
## one thrown hard enough to skip.
func _ch3_kickback_flick(move: EnemyMove, tint: Color) -> void:
	# Anticipation: weight settles back, torso closes, head checks the target.
	await _ch3_gather(3.0, -6.0, -4.0, 2.0, 4.0, 0.16)
	await _ch3_pose(5.0, -10.0, -6.0, 3.0, 6.0, 0.12)
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	_fx_charge(enemy_character, tint, 0.24)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 4.0, 0, 2, 1, 1, 0.18)])
	var paper := Color(0.96, 0.93, 0.84, 0.98)
	_fx_paper(Vector2(16, 11), paper, 0.30, 0.00, 0.0, 30.0)
	_fx_paper(Vector2(16, 11), paper, 0.34, 0.09, -26.0, -40.0)
	_fx_paper(Vector2(19, 13), paper, 0.26, 0.19, 10.0, 90.0)
	_fx_splatter(enemy_character, Color(0.78, 0.16, 0.16, 0.9), 4, 16.0, 0.34)
	await get_tree().create_timer(0.46).timeout

## MELEE. The pouch of coins. He walks in easily -- the deception is that
## nothing about the approach telegraphs a strike -- then plants, coils, and
## brings the pouch up from below.
func _ch3_pocket_payload(move: EnemyMove, tint: Color) -> void:
	# Plants the rear foot and coils: knees compress, torso winds away.
	await _ch3_gather(7.0, -12.0, -5.0, 4.0, 5.0, 0.20)
	await _ch3_ungather()
	var gold := Color(0.95, 0.78, 0.30, 1.0)
	var pouch := _ch3_prop(Color(0.44, 0.30, 0.16, 1.0), Vector2(22, 26), 8)
	_ch3_clip(move, 0.72)
	# The uppercut: body drives up and through, pouch swings from low to high.
	_ch3_prop_arc(pouch, -34.0, -46.0, -120.0, 0.26, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 4.0, 4, 3, 1.02, 0.97, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 10.0, -6, -8, 1.0, 1.04, 0.14, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, gold, 12, 30.0, 0.55)
	_fx_ring(player_character, gold, 64.0, 0.30)
	var tween := create_tween()
	tween.tween_property(pouch, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.10).timeout

## DEFENSIVE. An oversized Provincial Board folder held across the body. Foot
## slides back, knees bend, the folder comes up on the diagonal and a seal
## lights behind it.
func _ch3_deep_pockets(move: EnemyMove, tint: Color) -> void:
	# Notices it coming: head snaps first, body follows.
	await _ch3_gather(0.0, -3.0, -9.0, 0.0, 2.0, 0.12)
	await _ch3_pose(9.0, -8.0, -4.0, 5.0, 9.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.70)
	var folder := _ch3_prop(Color(0.72, 0.60, 0.34, 1.0), Vector2(30, 40), 3)
	folder.rotation = deg_to_rad(-24.0)
	_ch3_prop_arc(folder, -10.0, -6.0, -14.0, 0.22, false)
	_fx_ring(enemy_character, tint, 78.0, 0.36)
	_fx_word("PRIVILEGE", enemy_character, Color(1.0, 0.88, 0.52), 20.0, 0.10, 10)
	await get_tree().create_timer(0.30).timeout
	# The barrier takes the hit: arms recoil, papers come loose.
	_fx_splatter(enemy_character, Color(0.96, 0.93, 0.84, 0.9), 6, 22.0, 0.4)
	await _ch3_pose(4.0, 6.0, 4.0, 3.0, 6.0, 0.12)
	var tween := create_tween()
	tween.tween_property(folder, "modulate:a", 0.0, 0.20)
	await _ch3_ungather()

# =========================================================================
# ASSESSOR ALTAPRESYO -- The Valuation Vulture
# =========================================================================

## RANGED. Price tags thrown as projectiles: straight, curved, then one heavy
## enough to arrive late and hard.
func _ch3_markup_strike(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -5.0, -7.0, 1.0, 3.0, 0.15)
	_fx_word("APPRAISING…", enemy_character, Color(0.86, 0.9, 1.0), 16.0, 0.0, 9)
	await _ch3_pose(4.0, -11.0, -4.0, 3.0, 5.0, 0.13)
	await _ch3_ungather()
	_ch3_clip(move, 0.76)
	_fx_charge(enemy_character, tint, 0.24)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 3.0, 0, 2, 1, 1, 0.18)])
	var tag := Color(0.98, 0.86, 0.42, 0.98)
	_fx_paper(Vector2(15, 10), tag, 0.28, 0.00, 0.0, 20.0)
	_fx_paper(Vector2(15, 10), tag, 0.34, 0.08, -30.0, 160.0)
	_fx_paper(Vector2(22, 15), tag, 0.22, 0.18, 6.0, 60.0)
	_fx_word("₱₱₱", player_character, Color(0.98, 0.82, 0.36), 22.0, 0.30, 13)
	await get_tree().create_timer(0.48).timeout

## MELEE-ish LUNGE. The valuation stamp swung two-handed from over the
## shoulder. Heaviest wind-up of the three: he genuinely struggles with it.
func _ch3_appraisal_talons(move: EnemyMove, tint: Color) -> void:
	# Hefts it up over the shoulder -- torso opens, knees take the weight.
	await _ch3_gather(6.0, -14.0, -6.0, 5.0, 6.0, 0.22)
	await _ch3_ungather()
	var stamp := _ch3_prop(Color(0.72, 0.18, 0.18, 1.0), Vector2(26, 30), 4, true)
	_ch3_clip(move, 0.70)
	# The downward swing.
	_ch3_prop_arc(stamp, -40.0, 44.0, 96.0, 0.22, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 5.0, -4, 6, 1.0, 1.03, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 14.0, 5, -7, 1.03, 0.96, 0.13, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_ring(player_character, Color(0.86, 0.22, 0.2), 70.0, 0.28)
	_fx_word("OVERVALUED!", player_character, Color(0.98, 0.36, 0.3), 26.0, 0.04, 14)
	_fx_splatter(player_character, Color(0.66, 0.58, 0.48, 0.85), 9, 26.0, 0.45)
	var tween := create_tween()
	tween.tween_property(stamp, "modulate:a", 0.0, 0.16)
	# Knees compress under the landed weight.
	await _ch3_pose(8.0, 5.0, 5.0, 6.0, 0.0, 0.12)
	await _ch3_ungather()

## DEFENSIVE. A torn-off assessment sheet held up, property boundary lines
## snapping into a grid around him.
func _ch3_overvalued_cover(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -4.0, -8.0, 0.0, 2.0, 0.12)
	await _ch3_pose(7.0, -7.0, -3.0, 4.0, 7.0, 0.15)
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	var sheet := _ch3_prop(Color(0.94, 0.92, 0.86, 1.0), Vector2(34, 30), 2)
	_ch3_prop_arc(sheet, -8.0, -4.0, 6.0, 0.20, false)
	# The grid: four boundary lines snapping in around him.
	for i in _fx_count(4):
		_fx_ring(enemy_character, tint, 46.0 + 16.0 * float(i), 0.34, 0.06 * float(i))
	_fx_word("ASSESSED", enemy_character, Color(0.9, 0.94, 1.0), 18.0, 0.12, 10)
	await get_tree().create_timer(0.32).timeout
	_fx_splatter(enemy_character, Color(0.94, 0.92, 0.86, 0.9), 6, 20.0, 0.4)
	await _ch3_pose(3.0, 5.0, 3.0, 2.0, 5.0, 0.12)
	var tween := create_tween()
	tween.tween_property(sheet, "modulate:a", 0.0, 0.20)
	await _ch3_ungather()

# =========================================================================
# TREASURER TAGO -- The Vault Keeper
# =========================================================================

## MELEE. The treasury cashbox, carried in and swung sideways. He is visibly
## working: the walk is slow, the coil is deep, and the momentum turns him.
func _ch3_treasury_slam(move: EnemyMove, tint: Color) -> void:
	# Both arms strain: knees bend hard, torso leans back against the weight.
	await _ch3_gather(9.0, -10.0, -4.0, 6.0, 4.0, 0.24)
	await _ch3_ungather()
	var box := _ch3_prop(Color(0.52, 0.54, 0.58, 1.0), Vector2(34, 26), 3)
	_ch3_clip(move, 0.74)
	_ch3_prop_arc(box, -46.0, -6.0, -40.0, 0.24, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 6.0, 2, 7, 1.02, 0.98, 0.11, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 12.0, -2, -10, 1.0, 1.02, 0.14, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	var gold := Color(0.95, 0.80, 0.32, 1.0)
	_fx_splatter(player_character, gold, 14, 34.0, 0.6)
	_fx_splatter(player_character, Color(0.96, 0.93, 0.84, 0.9), 5, 26.0, 0.5)
	_fx_ring(player_character, gold, 66.0, 0.30)
	var tween := create_tween()
	tween.tween_property(box, "modulate:a", 0.0, 0.18)
	# The swing carries him round; he catches his balance.
	await _ch3_pose(-5.0, 9.0, 6.0, 3.0, -6.0, 0.14)
	await _ch3_ungather()

## RANGED. Three lockboxes: thrown overhand, thrown sidearm, and the third
## KICKED -- the leg beat is the point of the skill.
func _ch3_keychain_lash(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(3.0, -6.0, -5.0, 2.0, 4.0, 0.16)
	_fx_word("♪ click ♪", enemy_character, Color(0.86, 0.9, 0.96), 14.0, 0.0, 9)
	await _ch3_ungather()
	_ch3_clip(move, 0.78)
	var steel := Color(0.62, 0.64, 0.70, 0.98)
	# One overhand, one sidearm.
	_fx_slab(enemy_character, player_character, steel, Vector2(16, 14), 0.30, 0.00, -22.0, 90.0, 3)
	_fx_slab(enemy_character, player_character, steel, Vector2(16, 14), 0.30, 0.10, 14.0, -70.0, 3)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 4.0, 0, 3, 1, 1, 0.18)])
	# The kick: the whole figure pivots onto the standing leg and the boot
	# comes through. Legs rotate one way, torso counters, head stays level.
	await _ch3_pose(-13.0, 9.0, 4.0, -4.0, -7.0, 0.13)
	_fx_slab(enemy_character, player_character, steel, Vector2(20, 18), 0.22, 0.0, 0.0, 200.0, 3)
	Audio.play_sfx("attack_impact")
	await _ch3_pose(4.0, -3.0, -2.0, 2.0, 3.0, 0.12)
	await _ch3_ungather()
	_fx_splatter(player_character, Color(0.95, 0.80, 0.32, 1.0), 10, 28.0, 0.5)
	await get_tree().create_timer(0.14).timeout

## DEFENSIVE. A vault door hauled across on its wheel. Two-handed pull, brace
## behind it, recoil when it is struck, then wind it back.
func _ch3_vault_lockdown(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -3.0, -10.0, 0.0, 2.0, 0.12)
	# Hauls the wheel: torso rotates hard, knees drop into it.
	await _ch3_pose(10.0, -13.0, -3.0, 6.0, 8.0, 0.20)
	await _ch3_ungather()
	_ch3_clip(move, 0.70)
	var door := _ch3_prop(Color(0.46, 0.48, 0.54, 1.0), Vector2(40, 58), 4)
	door.position.y -= 8.0
	_ch3_prop_arc(door, -14.0, 0.0, 0.0, 0.18, false)
	_fx_ring(enemy_character, Color(0.72, 0.78, 0.86), 74.0, 0.34)
	_fx_word("SEALED", enemy_character, Color(0.84, 0.9, 0.98), 18.0, 0.12, 10)
	await get_tree().create_timer(0.30).timeout
	# Struck: the door shakes, sparks, and he recoils behind it.
	_fx_splatter(enemy_character, Color(1.0, 0.86, 0.5, 0.95), 8, 20.0, 0.32)
	var shake := create_tween()
	shake.tween_property(door, "position:x", door.position.x + 5.0, 0.05)
	shake.tween_property(door, "position:x", door.position.x - 3.0, 0.05)
	shake.tween_property(door, "position:x", door.position.x, 0.05)
	await _ch3_pose(6.0, 7.0, 3.0, 4.0, 8.0, 0.13)
	var tween := create_tween()
	tween.tween_property(door, "modulate:a", 0.0, 0.22)
	await _ch3_ungather()

# =========================================================================
# AUDITOR ALIBI -- The Paper Trail Painter
# =========================================================================

## RANGED. The red pen as a fencing weapon: he turns side-on, thrusts, recovers,
## slashes on the diagonal, and leaves a check mark hanging.
func _ch3_redaction_slash(move: EnemyMove, tint: Color) -> void:
	# Side-on fencing stance: legs open, torso squares, head level.
	await _ch3_gather(-6.0, 8.0, -3.0, 0.0, -5.0, 0.16)
	await _ch3_ungather()
	var pen := _ch3_prop(Color(0.88, 0.20, 0.22, 1.0), Vector2(30, 6), 2)
	_ch3_clip(move, 0.76)
	# Thrust.
	_ch3_prop_arc(pen, -30.0, 0.0, 0.0, 0.12, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 16.0, 0, 0, 1.04, 0.98, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(_ch3_dx() - 4.0, 0, 0, 1.0, 1.0, 0.09),
	])
	_fx_slab(enemy_character, player_character, Color(0.9, 0.24, 0.24, 0.9),
		Vector2(26, 4), 0.14, 0.0, 0.0, 0.0, 1)
	# Second cut, on the diagonal.
	_ch3_prop_arc(pen, -22.0, 18.0, 40.0, 0.12, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 14.0, 3, -5, 1.03, 0.99, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_fx_slab(enemy_character, player_character, Color(0.9, 0.24, 0.24, 0.9),
		Vector2(24, 4), 0.14, 0.0, -18.0, 32.0, 1)
	_fx_word("✓", player_character, Color(0.96, 0.28, 0.26), 24.0, 0.10, 22)
	var tween := create_tween()
	tween.tween_property(pen, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.22).timeout

## RANGED. The binder opens and the trail comes out: receipts, then reports,
## then one stamped document heavy enough to land like a brick.
func _ch3_paper_trail_torrent(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -7.0, -6.0, 1.0, 3.0, 0.16)
	# Draws the circle in the air: torso opens, head follows the hand.
	await _ch3_pose(2.0, 9.0, 7.0, 0.0, -3.0, 0.16)
	for i in _fx_count(3):
		_fx_ring(enemy_character, tint, 40.0 + 18.0 * float(i), 0.36, 0.07 * float(i))
	await _ch3_ungather()
	_ch3_clip(move, 0.82)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 5.0, 0, 3, 1, 1, 0.16)])
	var paper := Color(0.96, 0.94, 0.88, 0.98)
	for i in _fx_count(5):
		_fx_paper(Vector2(14, 10), paper, 0.30, 0.05 * float(i),
			float(i - 2) * 14.0, float(i) * 40.0 - 60.0)
	# The disallowance: bigger, slower, arrives last.
	_fx_paper(Vector2(28, 22), Color(0.92, 0.88, 0.80, 1.0), 0.30, 0.30, 0.0, 24.0)
	_fx_word("DISALLOWANCE", player_character, Color(0.96, 0.32, 0.28), 24.0, 0.42, 12)
	await get_tree().create_timer(0.58).timeout

## DEFENSIVE + HEAL. Sheets tossed up align into a wall; he writes a note
## while it holds. This is the chapter's only self-heal.
func _ch3_whitewash(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -4.0, -7.0, 0.0, 2.0, 0.13)
	# Tosses the sheets: arms up, torso opens, head back.
	await _ch3_pose(-3.0, 10.0, 8.0, -3.0, -4.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	var white := Color(0.97, 0.96, 0.92, 1.0)
	# The wall: three sheets standing in a row in front of him.
	for i in 3:
		var sheet := _ch3_prop(white, Vector2(16, 44), 1)
		sheet.position += Vector2(-16.0 + float(i) * 14.0, -6.0)
		var rise := create_tween()
		rise.tween_property(sheet, "position:y", sheet.position.y - 10.0, 0.22)
		rise.parallel().tween_property(sheet, "modulate:a", 0.0, 0.55).set_delay(0.30)
	_fx_ring(enemy_character, white, 70.0, 0.34)
	_fx_word("NO FINDING", enemy_character, Color(0.86, 1.0, 0.92), 20.0, 0.14, 10)
	await get_tree().create_timer(0.34).timeout
	await _ch3_pose(2.0, -4.0, -3.0, 1.0, 3.0, 0.12)
	await _ch3_ungather()

# =========================================================================
# PLANNER PALUSOT -- The Masterplan Manipulator
# =========================================================================

## RANGED. The rolled masterplan used as a staff: horizontal swing, spin, then
## the plan half-unrolls and sheets fly off it toward the player.
func _ch3_blueprint_crossfire(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(5.0, -9.0, -5.0, 3.0, 5.0, 0.18)
	await _ch3_ungather()
	var roll := _ch3_prop(Color(0.36, 0.52, 0.72, 1.0), Vector2(38, 8), 3)
	_ch3_clip(move, 0.78)
	# Horizontal sweep, then a spin through the body.
	_ch3_prop_arc(roll, -26.0, -4.0, -150.0, 0.24, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 4.0, 0, 6, 1.0, 1.0, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 9.0, 0, -9, 1.02, 0.99, 0.13, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	var blue := Color(0.58, 0.74, 0.94, 0.96)
	_fx_paper(Vector2(20, 14), blue, 0.28, 0.00, -18.0, 60.0)
	_fx_paper(Vector2(20, 14), blue, 0.30, 0.10, 18.0, -60.0)
	_fx_paper(Vector2(24, 16), blue, 0.24, 0.20, 0.0, 120.0)
	var tween := create_tween()
	tween.tween_property(roll, "modulate:a", 0.0, 0.20)
	await get_tree().create_timer(0.42).timeout

## MELEE. He kneels to set the plan down, the zoning grid lights under the
## player, model buildings rise out of it -- and then fall on them.
func _ch3_compass_sweep(move: EnemyMove, tint: Color) -> void:
	# Kneels to place the map: deep knee bend, torso folds over it.
	await _ch3_gather(12.0, -16.0, -8.0, 8.0, 3.0, 0.22)
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	# The grid, drawn under the player rather than around the caster.
	for i in _fx_count(3):
		_fx_ring(player_character, Color(0.50, 0.78, 0.96), 52.0 + 20.0 * float(i),
			0.32, 0.07 * float(i))
	_fx_word("ZONED", player_character, Color(0.62, 0.86, 1.0), 18.0, 0.06, 11)
	await _body_play(enemy_character, [_beat(_ch3_dx(), 0, 0, 1, 1, 0.16)])
	# Buildings rise, then come down.
	for i in 3:
		var block := _ch3_prop(Color(0.72, 0.74, 0.78, 1.0), Vector2(12, 30), 1)
		block.position = player_character.position + Vector2(
			player_character.size.x * 0.3 + float(i) * 16.0, player_character.size.y * 0.34)
		var t := create_tween()
		t.tween_property(block, "position:y", block.position.y - 34.0, 0.20)
		t.tween_property(block, "position:y", block.position.y + 12.0, 0.14)
		t.parallel().tween_property(block, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.36).timeout
	_fx_splatter(player_character, Color(0.70, 0.66, 0.58, 0.9), 11, 30.0, 0.5)
	_fx_ring(player_character, Color(0.66, 0.62, 0.56), 68.0, 0.28)
	await _ch3_pose(4.0, -4.0, -3.0, 2.0, 4.0, 0.12)
	await _ch3_ungather()

## DEFENSIVE / EVASION. He redraws the route and steps off it. The sidestep is
## real travel with real legs, not a fade -- and he comes back to the exact
## same x, so the baseline is never lost.
func _ch3_strategic_reroute(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -3.0, -9.0, 0.0, 2.0, 0.12)
	_ch3_clip(move, 0.70)
	_fx_word("REVISED", enemy_character, Color(0.66, 0.88, 1.0), 18.0, 0.0, 10)
	var arrow := _ch3_prop(Color(0.52, 0.82, 0.98, 0.9), Vector2(30, 5), 2)
	arrow.position.y += enemy_character.size.y * 0.36
	_ch3_prop_arc(arrow, 20.0, 0.0, 0.0, 0.26)
	await _ch3_ungather()
	# The sidestep itself, on the drawn walk cycle.
	var home := _body_home_x(enemy_character)
	await _body_play_walking(enemy_character, [
		_beat(_ch3_dx() + 26.0, 0, -4, 1, 1, 0.20),
	], 12.0)
	_fx_ring(enemy_character, tint, 60.0, 0.30)
	await get_tree().create_timer(0.16).timeout
	# Back to the exact baseline.
	await _body_play_walking(enemy_character, [
		_beat(0, 0, 0, 1, 1, 0.20),
	], 12.0)
	enemy_character.position.x = home

# =========================================================================
# ENGINEER ESKANDALO -- The Project Wrecker
# =========================================================================

## MELEE. The hard-hat headbutt. He stomps, drops his head, RUNS the whole
## distance on the drawn walk cycle, and leads with the helmet.
func _ch3_substandard_smash(move: EnemyMove, tint: Color) -> void:
	# Tightens the strap and stomps: one hard knee compression on the spot.
	await _ch3_gather(0.0, -6.0, -10.0, 5.0, 0.0, 0.16)
	await _ch3_pose(3.0, -12.0, -16.0, 3.0, 4.0, 0.12)
	await _ch3_ungather()
	# The run -- a fast cadence so the legs visibly cycle.
	_ch3_clip(move, 0.60)
	# Head drops into the hit.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 10.0, 6, -12, 1.04, 0.96, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
	])
	_fx_splatter(player_character, Color(1.0, 0.88, 0.52, 0.95), 10, 24.0, 0.35)
	_fx_ring(player_character, Color(1.0, 0.82, 0.36), 62.0, 0.26)
	# Rebound: he bounces off it and shakes his head clear.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 12.0, -3, 8, 1.0, 1.02, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	await _ch3_pose(0.0, 4.0, 12.0, 0.0, 0.0, 0.10)
	await _ch3_pose(0.0, 0.0, -8.0, 0.0, 0.0, 0.09)
	await _ch3_ungather()

## MELEE. Concrete. He kneels, lifts with both arms, throws overhead, then
## kicks a smaller piece after it.
func _ch3_rebar_rake(move: EnemyMove, tint: Color) -> void:
	# Kneels and lifts: the deepest knee bend of any rival.
	await _ch3_gather(14.0, -8.0, -6.0, 9.0, 2.0, 0.20)
	await _ch3_pose(2.0, -14.0, -8.0, -3.0, 4.0, 0.16)
	await _ch3_ungather()
	var rock := Color(0.58, 0.56, 0.52, 1.0)
	var chunk := _ch3_prop(rock, Vector2(24, 20), 3, true)
	_ch3_clip(move, 0.70)
	_ch3_prop_arc(chunk, -46.0, 6.0, -70.0, 0.22, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 5.0, -3, 5, 1.0, 1.02, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 11.0, 3, -6, 1.02, 0.98, 0.13, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, rock, 12, 30.0, 0.55)
	_fx_ring(player_character, Color(0.72, 0.68, 0.60), 64.0, 0.28)
	var tween := create_tween()
	tween.tween_property(chunk, "modulate:a", 0.0, 0.16)
	# And the kick after it.
	await _ch3_pose(-12.0, 8.0, 3.0, -4.0, -6.0, 0.12)
	_fx_slab(enemy_character, player_character, rock, Vector2(14, 12), 0.20, 0.0, 0.0, 180.0, 3)
	await _ch3_pose(3.0, -3.0, -2.0, 2.0, 3.0, 0.11)
	await _ch3_ungather()

## DEFENSIVE. A folding barricade kicked open and braced with both hands. One
## foot slides back under the force.
func _ch3_hardhat_hunker(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -4.0, -8.0, 0.0, 2.0, 0.12)
	# Kicks the legs of the barricade open.
	await _ch3_pose(-10.0, 6.0, 2.0, -3.0, -5.0, 0.13)
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	var bar := _ch3_prop(Color(0.94, 0.78, 0.16, 1.0), Vector2(44, 30), 2)
	_ch3_prop_arc(bar, -12.0, 2.0, 0.0, 0.18, false)
	_fx_word("UNDER CONSTRUCTION", enemy_character, Color(1.0, 0.88, 0.36), 18.0, 0.10, 9)
	for i in _fx_count(2):
		_fx_ring(enemy_character, Color(0.98, 0.82, 0.20), 60.0 + 18.0 * float(i),
			0.32, 0.08 * float(i))
	await get_tree().create_timer(0.30).timeout
	# Braced: the barrier shakes and his rear foot slides.
	var shake := create_tween()
	shake.tween_property(bar, "position:x", bar.position.x + 6.0, 0.05)
	shake.tween_property(bar, "position:x", bar.position.x, 0.07)
	await _ch3_pose(8.0, 6.0, 3.0, 4.0, 10.0, 0.14)
	var tween := create_tween()
	tween.tween_property(bar, "modulate:a", 0.0, 0.20)
	await _ch3_ungather()

# =========================================================================
# CONTRACTOR KUTSABA -- The Capitol Partner
# =========================================================================

## RANGED. Change orders thrown like cards -- one, then a sidestep and another,
## then a spin and a third that arrives twice the size.
func _ch3_rigged_deal(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(3.0, -7.0, -5.0, 2.0, 4.0, 0.16)
	_fx_word("CHANGE ORDER", enemy_character, Color(1.0, 0.92, 0.72), 16.0, 0.0, 9)
	await _ch3_ungather()
	_ch3_clip(move, 0.80)
	var doc := Color(0.95, 0.92, 0.84, 0.98)
	_fx_paper(Vector2(17, 12), doc, 0.28, 0.00, 0.0, 40.0)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 5.0, 0, 3, 1, 1, 0.12),
		# The sidestep between throws.
		_beat(_ch3_dx() + 7.0, 0, -3, 1, 1, 0.12),
	])
	_fx_paper(Vector2(17, 12), doc, 0.30, 0.00, -22.0, -50.0)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 6.0, 0, 4, 1, 1, 0.12)])
	_fx_paper(Vector2(26, 19), doc, 0.26, 0.06, 8.0, 110.0)
	_fx_splatter(enemy_character, doc, 5, 18.0, 0.35)
	await get_tree().create_timer(0.40).timeout

## MELEE. The briefcase: a jab, a horizontal swing, then an overhead smash that
## bursts it open and scatters the contracts.
func _ch3_partners_cut(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(6.0, -11.0, -5.0, 4.0, 5.0, 0.18)
	await _ch3_ungather()
	var case := _ch3_prop(Color(0.34, 0.22, 0.14, 1.0), Vector2(30, 22), 3)
	_ch3_clip(move, 0.80)
	# Jab.
	_ch3_prop_arc(case, -22.0, 0.0, 0.0, 0.10, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 10.0, 0, 0, 1.03, 0.99, 0.09, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	# Horizontal swing.
	_ch3_prop_arc(case, 14.0, -6.0, -80.0, 0.10, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 6.0, 0, 7, 1.0, 1.0, 0.09),
	])
	# Overhead smash.
	_ch3_prop_arc(case, -34.0, 30.0, 120.0, 0.16, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 14.0, 5, -8, 1.03, 0.96, 0.13, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, Color(0.95, 0.92, 0.84, 0.95), 13, 32.0, 0.6)
	_fx_ring(player_character, Color(0.80, 0.68, 0.44), 66.0, 0.28)
	var tween := create_tween()
	tween.tween_property(case, "modulate:a", 0.0, 0.18)
	await _ch3_pose(6.0, 5.0, 4.0, 4.0, 4.0, 0.12)
	await _ch3_ungather()

## DEFENSIVE. He snaps his fingers and a second contractor comes out of the
## dark to hold the other end of the board. Both brace; the partner fades.
func _ch3_padded_contract(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -3.0, -8.0, 0.0, 2.0, 0.12)
	# The snap.
	await _ch3_pose(0.0, -8.0, -2.0, -3.0, 3.0, 0.10)
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	# The partner: a silhouette behind him, holding the far edge.
	var mate := _ch3_prop(Color(0.10, 0.09, 0.14, 0.72), Vector2(38, 84), 6)
	mate.position += Vector2(26.0, -14.0)
	mate.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(mate, "modulate:a", 1.0, 0.14)
	var board := _ch3_prop(Color(0.62, 0.52, 0.34, 1.0), Vector2(48, 34), 2)
	_ch3_prop_arc(board, -10.0, -4.0, -6.0, 0.18, false)
	_fx_ring(enemy_character, tint, 74.0, 0.34)
	await get_tree().create_timer(0.30).timeout
	# Both brace against the hit.
	await _ch3_pose(7.0, 6.0, 3.0, 4.0, 8.0, 0.14)
	_fx_splatter(enemy_character, Color(0.62, 0.52, 0.34, 0.9), 6, 22.0, 0.4)
	var gone := create_tween()
	gone.tween_property(mate, "modulate:a", 0.0, 0.22)
	gone.parallel().tween_property(board, "modulate:a", 0.0, 0.22)
	await _ch3_ungather()

# =========================================================================
# PROJECT PADRINO -- The Backroom Benefactor
# =========================================================================
#
# The strongest ordinary rival, and his animation says so by being SLOWER than
# everyone else's. Longer holds, smaller recoveries, no scrambling. Where
# Eskandalo runs, Padrino walks and stops just outside range.

## RANGED. Sealed envelopes summoned out of the dark and sent one at a time,
## from three different angles, with the room dimmed while he does it.
func _ch3_strings_attached(move: EnemyMove, tint: Color) -> void:
	# One hand raised. Almost no body movement -- that is the character.
	await _ch3_gather(0.0, -4.0, -3.0, -2.0, 1.0, 0.22)
	_react_room(Color(0.16, 0.12, 0.22), 2.0)
	_fx_charge(enemy_character, tint, 0.40)
	for i in _fx_count(3):
		_fx_ring(enemy_character, tint, 44.0 + 20.0 * float(i), 0.40, 0.09 * float(i))
	await _ch3_ungather()
	_ch3_clip(move, 0.84)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 3.0, 0, 2, 1, 1, 0.18)])
	var seal := Color(0.94, 0.86, 0.56, 0.98)
	_fx_paper(Vector2(20, 14), seal, 0.30, 0.00, 0.0, 20.0)
	_fx_paper(Vector2(18, 13), seal, 0.32, 0.10, -30.0, -40.0)
	_fx_paper(Vector2(18, 13), seal, 0.32, 0.14, 30.0, 40.0)
	# The briefcase opening above the player.
	_fx_slab(enemy_character, player_character, Color(0.30, 0.20, 0.12, 1.0),
		Vector2(26, 20), 0.28, 0.24, -46.0, 30.0, 3)
	_fx_splatter(player_character, seal, 9, 28.0, 0.5)
	_fx_paper(Vector2(24, 18), Color(0.98, 0.90, 0.60, 1.0), 0.24, 0.40, 0.0, 60.0)
	await get_tree().create_timer(0.66).timeout

## The measured palm strike. He walks in, stops SHORT, sets one hand behind his
## back, and drives the other through from the hip. Held finishing pose.
func _ch3_backroom_verdict(move: EnemyMove, tint: Color) -> void:
	# Settles. Hips load, torso closes, head stays level and on the target.
	await _ch3_gather(5.0, -10.0, 0.0, 3.0, 5.0, 0.26)
	await _ch3_ungather()
	_ch3_clip(move, 0.70)
	# Hips rotate through, shoulder drives, and the pose HOLDS.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 16.0, 0, -6, 1.05, 0.98, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_fx_ring(player_character, Color(0.98, 0.90, 0.60), 58.0, 0.24)
	_fx_ring(player_character, Color(0.98, 0.90, 0.60), 86.0, 0.34, 0.06)
	_fx_flash(Color(1.0, 0.94, 0.72), 0.20)
	_fx_splatter(player_character, Color(0.96, 0.88, 0.58, 0.9), 8, 26.0, 0.5)
	# The hold: three-tenths of nothing happening, which is the whole point.
	await get_tree().create_timer(0.30).timeout
	await _ch3_pose(-3.0, 4.0, 0.0, -2.0, -4.0, 0.16)
	await _ch3_ungather(0.14)

## DEFENSIVE / COUNTER. Two silhouettes and a golden seal. He barely moves,
## then flicks one hand and the shockwave goes back the other way.
func _ch3_patrons_protection(move: EnemyMove, tint: Color) -> void:
	# One finger. No panic: the smallest anticipation in the chapter.
	await _ch3_gather(0.0, -2.0, -2.0, -1.0, 1.0, 0.18)
	_ch3_clip(move, 0.78)
	var gold := Color(0.98, 0.86, 0.44, 1.0)
	# The two backers.
	for i in 2:
		var shade := _ch3_prop(Color(0.10, 0.09, 0.14, 0.66), Vector2(30, 76), 6)
		shade.position += Vector2(20.0 + float(i) * 16.0, -12.0 + float(i) * 5.0)
		shade.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.05 * float(i))
		t.tween_property(shade, "modulate:a", 1.0, 0.16)
		t.tween_interval(0.34)
		t.tween_property(shade, "modulate:a", 0.0, 0.22)
	var seal := _ch3_prop(gold, Vector2(40, 40), 20)
	seal.modulate.a = 0.0
	var up := create_tween()
	up.tween_property(seal, "modulate:a", 0.9, 0.16)
	_fx_ring(enemy_character, gold, 80.0, 0.38)
	_fx_word("FAVOR", enemy_character, Color(1.0, 0.92, 0.62), 20.0, 0.14, 11)
	await _ch3_ungather()
	await get_tree().create_timer(0.30).timeout
	# The counter-flick: a small hand movement, a wave that travels.
	_spawn_bolt(enemy_character, player_character, gold, 12.0, 0.24, 0.0, 0.0, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 5.0, 0, -3, 1.0, 1.0, 0.10),
		_beat(_ch3_dx(), 0, 0, 1.0, 1.0, 0.12),
	])
	var out := create_tween()
	out.tween_property(seal, "modulate:a", 0.0, 0.22)
	await get_tree().create_timer(0.16).timeout

# =========================================================================
# CHAPTER 4 -- MALACANANG PALACE
# =========================================================================
#
# Every routine below is built from the same vocabulary Chapter 3 uses --
# _ch3_gather / _ch3_pose / _ch3_ungather drive the cut-out rig, _ch3_clip
# plays the drawn frames, _ch3_prop and _ch3_prop_arc carry a held object, and
# _body_play sequences the whole body -- so the two chapters animate through
# one system rather than two.
#
# The shape asked for in the brief is the shape of each routine, in order:
# ANTICIPATION (the rig settles back), WIND-UP (it coils), EXECUTION (the clip
# and the body drive forward), IMPACT (the effect lands on the beat the routine
# returns), FOLLOW-THROUGH and RECOVERY (the tail beats), then the resolver
# hands the body back to its idle. Nothing here moves the sprite as one rigid
# block: the approach is a walk cycle, and the strike is the rig bending.

## Chapter 4's dispatcher. Kept separate from _ch3_perform's match so the two
## rosters cannot collide on an id, and so a Chapter 4 skill that has not been
## choreographed yet degrades to a competent generic rather than to nothing.
func _ch4_perform(move_id: String, move: EnemyMove, tint: Color,
		melee: bool, defending: bool) -> void:
	match move_id:
		# --- Secretary Sipsip: the cabinet clinger ------------------------
		"c4combat_approval_jab": await _ch4_approval_jab(move, tint)
		"c4combat_cabinet_folder_toss": await _ch4_folder_toss(move, tint)
		"c4combat_yes_sir_shield": await _ch4_yes_sir_shield(move, tint)
		# --- Protocol Porma: the ceremony controller ----------------------
		"c4combat_red_carpet_sweep": await _ch4_carpet_sweep(move, tint)
		"c4combat_velvet_rope_snare": await _ch4_rope_snare(move, tint)
		"c4combat_formal_formation": await _ch4_formal_formation(move, tint)
		# --- Spox Spin: the narrative twister -----------------------------
		"c4combat_mic_check_bash": await _ch4_mic_check(move, tint)
		"c4combat_press_release_barrage": await _ch4_press_barrage(move, tint)
		"c4combat_narrative_redirect": await _ch4_narrative_redirect(move, tint)
		# --- Chief Utos: the command keeper -------------------------------
		"c4combat_directive_strike": await _ch4_directive_strike(move, tint)
		"c4combat_command_stamp": await _ch4_command_stamp(move, tint)
		"c4combat_executive_order_brace": await _ch4_order_brace(move, tint)
		# --- Cabinet Konek: the inner circle insider ----------------------
		"c4combat_connection_kick": await _ch4_connection_kick(move, tint)
		"c4combat_network_signal": await _ch4_network_signal(move, tint)
		"c4combat_inner_circle_guard": await _ch4_inner_circle(move, tint)
		# --- Director Dikta: the executive enforcer -----------------------
		"c4combat_memo_slam": await _ch4_memo_slam(move, tint)
		"c4combat_directive_volley": await _ch4_directive_volley(move, tint)
		"c4combat_command_barrier": await _ch4_command_barrier(move, tint)
		# --- Adviser Areglo: the backroom whisperer -----------------------
		"c4combat_whisper_jab": await _ch4_whisper_jab(move, tint)
		"c4combat_backroom_deal": await _ch4_backroom_deal(move, tint)
		"c4combat_strategic_sidestep": await _ch4_strategic_sidestep(move, tint)
		# --- EO Ego: the order overlord -----------------------------------
		"c4combat_executive_smash": await _ch4_executive_smash(move, tint)
		"c4combat_eo_barrage": await _ch4_eo_barrage(move, tint)
		"c4combat_presidential_seal_guard": await _ch4_seal_guard(move, tint)
		# --- Lolo Enrilegend: the eternal statesman -----------------------
		"c4combat_veterans_verdict": await _ch4_veterans_verdict(move, tint)
		"c4combat_history_repeats": await _ch4_history_repeats(move, tint)
		"c4combat_eternal_resolve": await _ch4_eternal_resolve(move, tint)
		_: await _ch3_generic(move, tint, melee, defending)


## Palace paper. Chapter 4 throws a great deal of it, and it is always the same
## cream official stock, so the colour lives in one place.
func _ch4_paper() -> Color:
	return Color(0.96, 0.94, 0.88, 0.98)


## A gold seal flash -- the chapter's signature accent, used on anything that
## carries executive authority.
func _ch4_seal(who: Control, size: float = 70.0, secs: float = 0.34) -> void:
	_fx_ring(who, Color(1.0, 0.84, 0.34, 0.95), size, secs)


## A wait that shortens in the boss's second phase and is an ordinary wait for
## everyone else. Used only by the three Lolo Enrilegend routines, so "attack
## speed slightly increased" and "recovery time slightly shorter" are one
## change in one place rather than thirty edited numbers.
func _ch4_wait(secs: float) -> void:
	await get_tree().create_timer(secs * _ch4_phase_pace()).timeout


# -------------------------------------------------------------------------
# SECRETARY SIPSIP -- The Cabinet Clinger
# -------------------------------------------------------------------------

## MELEE. A short stamping jab. He bows first -- the flattery IS the wind-up --
## then drives the approval stamp straight out at chest height.
func _ch4_approval_jab(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -8.0, -10.0, 3.0, 2.0, 0.16)     # the half-bow
	await _ch3_pose(5.0, -12.0, -6.0, 4.0, 4.0, 0.12)       # coils behind it
	await _ch3_ungather()
	_ch3_clip(move, 0.70)
	var stamp := _ch3_prop(Color(0.55, 0.35, 0.18, 1.0), Vector2(18, 20), 4)
	_ch3_prop_arc(stamp, -30.0, -6.0, -18.0, 0.18, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 3.0, 2, 2, 1.02, 0.98, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 9.0, -3, -4, 1.0, 1.03, 0.13, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_ch4_seal(player_character, 54.0, 0.26)
	_fx_splatter(player_character, tint, 8, 22.0, 0.42)
	var fade := create_tween()
	fade.tween_property(stamp, "modulate:a", 0.0, 0.20)
	await get_tree().create_timer(0.12).timeout


## RANGED. Three folders skimmed out flat, shedding signed pages as they go.
func _ch4_folder_toss(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(3.0, -7.0, -5.0, 2.0, 5.0, 0.16)
	await _ch3_pose(6.0, -11.0, -3.0, 3.0, 7.0, 0.12)
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	_fx_charge(enemy_character, tint, 0.22)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 5.0, 0, 3, 1, 1, 0.17)])
	var paper := _ch4_paper()
	_fx_paper(Vector2(26, 18), Color(0.78, 0.66, 0.42, 0.98), 0.30, 0.00, 0.0, 34.0)
	_fx_paper(Vector2(24, 17), Color(0.78, 0.66, 0.42, 0.98), 0.33, 0.08, -18.0, -30.0)
	_fx_paper(Vector2(15, 11), paper, 0.26, 0.15, 12.0, 70.0)
	_fx_paper(Vector2(13, 10), paper, 0.24, 0.21, -8.0, 100.0)
	await get_tree().create_timer(0.44).timeout


## DEFENSIVE. He agrees with everything, from behind the folder. Deep bow, the
## folder comes up edge-on, and a seal lights behind it.
func _ch4_yes_sir_shield(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -4.0, -11.0, 0.0, 2.0, 0.12)     # head ducks first
	await _ch3_pose(7.0, -14.0, -9.0, 5.0, 4.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.70)
	var folder := _ch3_prop(Color(0.74, 0.62, 0.38, 1.0), Vector2(28, 38), 3)
	folder.rotation = deg_to_rad(-18.0)
	_ch3_prop_arc(folder, -12.0, -8.0, -10.0, 0.22, false)
	_ch4_seal(enemy_character, 78.0, 0.36)
	_fx_word("YES SIR", enemy_character, Color(1.0, 0.90, 0.56), 20.0, 0.10, 10)
	await get_tree().create_timer(0.30).timeout
	_fx_splatter(enemy_character, _ch4_paper(), 6, 22.0, 0.40)


# -------------------------------------------------------------------------
# PROTOCOL PORMA -- The Ceremony Controller
# -------------------------------------------------------------------------

## MELEE. The carpet edge whipped low across the floor. Rigid and ceremonial:
## she does not lunge, she pivots and the carpet does the travelling.
func _ch4_carpet_sweep(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(6.0, -5.0, -2.0, 1.0, 6.0, 0.18)      # heels together, coils
	await _ch3_pose(10.0, -9.0, -4.0, 2.0, 9.0, 0.12)
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	var carpet := _ch3_prop(Color(0.72, 0.14, 0.18, 1.0), Vector2(64, 12), 2)
	carpet.rotation = deg_to_rad(6.0)
	_ch3_prop_arc(carpet, -74.0, 26.0, -16.0, 0.26, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 2.0, 1, 4, 1.01, 0.99, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 7.0, 3, -5, 1.03, 0.98, 0.15, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, Color(0.72, 0.14, 0.18, 0.9), 10, 26.0, 0.48)
	_fx_ring(player_character, tint, 58.0, 0.28)
	var fade := create_tween()
	fade.tween_property(carpet, "modulate:a", 0.0, 0.20)
	await get_tree().create_timer(0.12).timeout


## RANGED. The hooked velvet rope, thrown like a lasso and snapped taut.
func _ch4_rope_snare(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(4.0, -8.0, -4.0, 2.0, 6.0, 0.16)
	await _ch3_pose(7.0, -13.0, -6.0, 3.0, 9.0, 0.14)
	await _ch3_ungather()
	_ch3_clip(move, 0.76)
	_fx_charge(enemy_character, tint, 0.20)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 6.0, -2, 4, 1, 1, 0.16)])
	# The rope reads as a run of linked segments crossing the gap.
	for i in 5:
		_spawn_bolt(enemy_character, player_character, Color(0.74, 0.16, 0.22, 0.95),
			9.0, 0.16, float(i) * 0.045, float(i - 2) * 4.0, false)
	await get_tree().create_timer(0.30).timeout
	_fx_ring(player_character, Color(1.0, 0.84, 0.34, 0.95), 46.0, 0.24)
	_fx_word("HOLD THE LINE", player_character, Color(0.96, 0.80, 0.80), 18.0, 0.08, 9)
	await get_tree().create_timer(0.16).timeout


## DEFENSIVE. She sets the boundary. Snaps to attention, plants the clipboard,
## and a rope line of floor markers comes up in front of her.
func _ch4_formal_formation(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -2.0, -6.0, 0.0, 1.0, 0.10)
	await _ch3_pose(3.0, -4.0, -2.0, 1.0, 2.0, 0.14)        # ramrod straight
	await _ch3_ungather()
	_ch3_clip(move, 0.68)
	var board := _ch3_prop(Color(0.62, 0.48, 0.26, 1.0), Vector2(24, 32), 3)
	_ch3_prop_arc(board, -8.0, -4.0, 0.0, 0.20, false)
	for i in 3:
		_fx_ring(enemy_character, Color(0.74, 0.16, 0.22, 0.9), 40.0 + float(i) * 18.0,
			0.30, float(i) * 0.06)
	_fx_word("PROTOCOL", enemy_character, Color(1.0, 0.86, 0.50), 20.0, 0.10, 10)
	await get_tree().create_timer(0.34).timeout


# -------------------------------------------------------------------------
# SPOX SPIN -- The Narrative Twister
# -------------------------------------------------------------------------

## MELEE. Check, check. Two short microphone jabs, the second one harder.
func _ch4_mic_check(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(3.0, -6.0, -6.0, 3.0, 3.0, 0.14)
	await _ch3_ungather(0.07)
	_ch3_clip(move, 0.72)
	var mic := _ch3_prop(Color(0.20, 0.20, 0.24, 1.0), Vector2(14, 22), 6)
	# Two beats, not one: the first is the tap, the second is the blow.
	_ch3_prop_arc(mic, -20.0, -2.0, -8.0, 0.12, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 6.0, 0, 2, 1.0, 1.0, 0.09, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(_ch3_dx() + 2.0, 0, -1, 1.0, 1.0, 0.07),
	])
	_fx_ring(player_character, tint, 40.0, 0.18)
	_ch3_prop_arc(mic, -26.0, 2.0, -14.0, 0.14, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 12.0, -2, -5, 1.02, 1.0, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, tint, 9, 24.0, 0.44)
	var fade := create_tween()
	fade.tween_property(mic, "modulate:a", 0.0, 0.18)
	await get_tree().create_timer(0.12).timeout


## RANGED. Five statement pages fanned out in a spreading arc -- the answer to
## a question nobody asked.
func _ch4_press_barrage(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -5.0, -4.0, 2.0, 4.0, 0.14)
	await _ch3_pose(4.0, -9.0, -7.0, 3.0, 6.0, 0.12)
	await _ch3_ungather()
	_ch3_clip(move, 0.76)
	_fx_charge(enemy_character, tint, 0.24)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 4.0, -1, 3, 1, 1, 0.16)])
	var paper := _ch4_paper()
	for i in 5:
		_fx_paper(Vector2(17, 12), paper, 0.28 + float(i) * 0.02,
			float(i) * 0.055, float(i - 2) * 16.0, float(i - 2) * 44.0)
	_fx_word("NO FURTHER COMMENT", enemy_character, Color(0.80, 0.92, 1.0), 22.0, 0.14, 9)
	await get_tree().create_timer(0.46).timeout


## DEFENSIVE. The question is redirected. He spins on the ball of one foot and
## a curtain of turning headlines closes in front of him.
func _ch4_narrative_redirect(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -6.0, -8.0, 2.0, 3.0, 0.12)
	await _ch3_pose(6.0, 12.0, 9.0, 3.0, -8.0, 0.18)        # torso turns AWAY
	await _ch3_ungather()
	_ch3_clip(move, 0.70)
	for i in 4:
		_fx_paper(Vector2(20, 14), _ch4_paper(), 0.10, float(i) * 0.05,
			float(i - 2) * 22.0, 0.0)
	_fx_ring(enemy_character, tint, 74.0, 0.34)
	_fx_word("MOVING ON", enemy_character, Color(0.82, 0.94, 1.0), 20.0, 0.10, 10)
	await get_tree().create_timer(0.32).timeout


# -------------------------------------------------------------------------
# CHIEF UTOS -- The Command Keeper
# -------------------------------------------------------------------------

## MELEE. The clipboard edge, brought down overhand. Brisk and impatient: the
## wind-up is short because she has somewhere else to be.
func _ch4_directive_strike(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(5.0, -10.0, -5.0, 3.0, 4.0, 0.13)
	await _ch3_ungather(0.07)
	_ch3_clip(move, 0.70)
	var board := _ch3_prop(Color(0.58, 0.60, 0.64, 1.0), Vector2(22, 30), 3)
	_ch3_prop_arc(board, -26.0, -34.0, -74.0, 0.22, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 4.0, -4, 3, 1.0, 1.03, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 11.0, 5, -6, 1.03, 0.97, 0.14, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, tint, 11, 27.0, 0.46)
	_fx_ring(player_character, tint, 56.0, 0.26)
	var fade := create_tween()
	fade.tween_property(board, "modulate:a", 0.0, 0.20)
	await get_tree().create_timer(0.12).timeout


## RANGED. A sealed order slammed flat; three stamped seals skid out across the
## floor towards the player.
func _ch4_command_stamp(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(6.0, -9.0, -4.0, 4.0, 4.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	await _body_play(enemy_character, [
		_beat(_ch3_dx(), 6, 2, 1.0, 0.96, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx(), 0, 0, 1.0, 1.0, 0.10, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_ch4_seal(enemy_character, 52.0, 0.22)
	for i in 3:
		_spawn_bolt(enemy_character, player_character, Color(1.0, 0.84, 0.34, 0.95),
			12.0, 0.17, float(i) * 0.07, float(i - 1) * 10.0, false)
	await get_tree().create_timer(0.38).timeout


## DEFENSIVE. Both feet planted, clipboard held flat: a bracing wall of pinned
## schedules that the next blow has to get through first.
func _ch4_order_brace(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -3.0, -7.0, 0.0, 2.0, 0.11)
	await _ch3_pose(8.0, -7.0, -3.0, 4.0, 5.0, 0.15)
	await _ch3_ungather()
	_ch3_clip(move, 0.70)
	var board := _ch3_prop(Color(0.58, 0.60, 0.64, 1.0), Vector2(30, 36), 3)
	_ch3_prop_arc(board, -10.0, -6.0, -6.0, 0.20, false)
	for i in 3:
		_fx_paper(Vector2(14, 10), _ch4_paper(), 0.08, float(i) * 0.05,
			float(i - 1) * 16.0, 0.0)
	_ch4_seal(enemy_character, 76.0, 0.34)
	_fx_word("BY ORDER", enemy_character, Color(1.0, 0.88, 0.54), 20.0, 0.10, 10)
	await get_tree().create_timer(0.32).timeout


# -------------------------------------------------------------------------
# CABINET KONEK -- The Inner Circle Insider
# -------------------------------------------------------------------------

## MELEE. A low forward kick -- the only skill in the chapter that leads with a
## leg, so the rig drives the legs band hard and the torso follows late.
func _ch4_connection_kick(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(9.0, -6.0, -3.0, 5.0, 3.0, 0.18)      # weight onto the back foot
	await _ch3_pose(14.0, -4.0, -2.0, 6.0, 5.0, 0.12)
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 5.0, 3, 2, 0.98, 1.02, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 13.0, -2, -7, 1.04, 0.98, 0.14, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, tint, 10, 26.0, 0.46)
	_fx_ring(player_character, tint, 60.0, 0.28)
	await get_tree().create_timer(0.14).timeout


## RANGED. He does not throw anything. He signals, and the signal travels along
## the connections -- linked nodes racing outward.
func _ch4_network_signal(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -5.0, -5.0, 2.0, 4.0, 0.15)
	await _ch3_pose(4.0, -8.0, -3.0, 3.0, 7.0, 0.13)
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	_fx_charge(enemy_character, tint, 0.26)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 3.0, -1, 2, 1, 1, 0.15)])
	# A chain rather than a volley: each node leaves as the last one lands.
	for i in 4:
		_spawn_bolt(enemy_character, player_character, tint, 10.0,
			0.19, float(i) * 0.085, float(i % 2) * 12.0 - 6.0, false)
		_fx_ring(enemy_character, tint, 34.0 + float(i) * 10.0, 0.22, float(i) * 0.085)
	await get_tree().create_timer(0.44).timeout


## DEFENSIVE. The circle closes. A ring of linked contacts comes up around him
## and takes the blow instead.
func _ch4_inner_circle(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(1.0, -4.0, -6.0, 1.0, 3.0, 0.12)
	await _ch3_pose(5.0, -7.0, -3.0, 3.0, 6.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	for i in 4:
		_fx_ring(enemy_character, tint, 44.0 + float(i) * 14.0, 0.34, float(i) * 0.055)
	_fx_word("KAKILALA", enemy_character, Color(0.68, 1.0, 0.90), 22.0, 0.12, 10)
	await get_tree().create_timer(0.36).timeout
	_fx_splatter(enemy_character, tint, 6, 20.0, 0.36)


# -------------------------------------------------------------------------
# DIRECTOR DIKTA -- The Executive Enforcer
# -------------------------------------------------------------------------

## MELEE. The whole folder stack hauled overhead and dropped. The heaviest
## melee in the chapter, so the wind-up is the longest and the recoil the most.
func _ch4_memo_slam(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(8.0, -14.0, -8.0, 6.0, 4.0, 0.22)     # the long haul up
	await _ch3_pose(11.0, -18.0, -11.0, 8.0, 5.0, 0.14)
	await _ch3_ungather()
	_ch3_clip(move, 0.78)
	var stack := _ch3_prop(Color(0.70, 0.58, 0.36, 1.0), Vector2(34, 40), 2)
	_ch3_prop_arc(stack, -18.0, -46.0, -96.0, 0.26, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 6.0, -7, 4, 1.0, 1.05, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 12.0, 8, -7, 1.06, 0.94, 0.16, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(7.0)
	_fx_splatter(player_character, _ch4_paper(), 14, 32.0, 0.55)
	_fx_ring(player_character, tint, 72.0, 0.32)
	var fade := create_tween()
	fade.tween_property(stack, "modulate:a", 0.0, 0.24)
	await get_tree().create_timer(0.16).timeout


## RANGED. Four heavy directives hammered out low and fast.
func _ch4_directive_volley(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(5.0, -10.0, -5.0, 4.0, 4.0, 0.17)
	await _ch3_ungather()
	_ch3_clip(move, 0.76)
	_fx_charge(enemy_character, tint, 0.22)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 7.0, 2, 3, 1.0, 1.0, 0.16)])
	for i in 4:
		_spawn_bolt(enemy_character, player_character, tint, 13.0,
			0.15, float(i) * 0.05, float(i - 2) * 7.0, false)
	_fx_paper(Vector2(24, 17), Color(0.72, 0.60, 0.38, 0.98), 0.28, 0.12, 8.0, 40.0)
	await get_tree().create_timer(0.40).timeout


## DEFENSIVE. The stamp goes into the floor and a wall of stamped directives
## comes up out of it.
func _ch4_command_barrier(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(4.0, -9.0, -6.0, 3.0, 3.0, 0.14)
	await _ch3_pose(9.0, -6.0, -2.0, 6.0, 4.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	await _body_play(enemy_character, [
		_beat(_ch3_dx(), 7, 1, 1.0, 0.95, 0.11, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx(), 0, 0, 1.0, 1.0, 0.10, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(3.0)
	for i in 3:
		_fx_ring(enemy_character, tint, 46.0 + float(i) * 16.0, 0.32, float(i) * 0.05)
	_fx_word("DIRECTIVE", enemy_character, Color(1.0, 0.80, 0.72), 20.0, 0.10, 10)
	await get_tree().create_timer(0.34).timeout


# -------------------------------------------------------------------------
# ADVISER AREGLO -- The Backroom Whisperer
# -------------------------------------------------------------------------

## MELEE. A feint high, then a short palm strike close in. The feint is a real
## beat of its own -- the body commits to it and then goes somewhere else.
func _ch4_whisper_jab(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -5.0, -9.0, 1.0, 3.0, 0.14)
	# The feint: shoulder and head lead high, then stop dead.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 5.0, -4, -6, 1.0, 1.0, 0.11, Tween.TRANS_SINE, Tween.EASE_OUT),
		_beat(_ch3_dx() - 2.0, -2, -3, 1.0, 1.0, 0.07),
	])
	await _ch3_pose(7.0, -11.0, -4.0, 3.0, 6.0, 0.10)
	await _ch3_ungather()
	_ch3_clip(move, 0.70)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 10.0, 3, -4, 1.02, 0.99, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, tint, 8, 22.0, 0.42)
	_fx_ring(player_character, tint, 48.0, 0.24)
	await get_tree().create_timer(0.14).timeout


## RANGED. Three folders set drifting, then sprung all at once after a beat --
## the arrangement was already made before the conversation started.
func _ch4_backroom_deal(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -4.0, -5.0, 1.0, 3.0, 0.15)
	await _ch3_ungather()
	_ch3_clip(move, 0.80)
	# The three folders hang there. Nothing happens for a moment.
	for i in 3:
		_fx_paper(Vector2(20, 15), Color(0.30, 0.26, 0.36, 0.95), 0.09,
			float(i) * 0.04, float(i - 1) * 26.0, 0.0)
	_fx_charge(enemy_character, tint, 0.30)
	await get_tree().create_timer(0.34).timeout
	# Then all three at once.
	for i in 3:
		_spawn_bolt(enemy_character, player_character, tint, 12.0,
			0.13, 0.0, float(i - 1) * 14.0, false)
	_fx_word("AREGLADO", enemy_character, Color(0.82, 0.72, 1.0), 22.0, 0.10, 10)
	await get_tree().create_timer(0.30).timeout


## DEFENSIVE. He is simply not where the blow is going. One clean step off the
## line, then a counter-ready stance.
func _ch4_strategic_sidestep(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(3.0, -3.0, -6.0, 1.0, 4.0, 0.12)
	_ch3_clip(move, 0.68)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 13.0, 0, 5, 1.0, 1.0, 0.15, Tween.TRANS_SINE, Tween.EASE_OUT),
		_beat(_ch3_dx() + 4.0, 0, -2, 1.0, 1.0, 0.13, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	])
	await _ch3_ungather()
	_fx_ring(enemy_character, tint, 66.0, 0.30)
	_fx_word("WALA AKO DOON", enemy_character, Color(0.84, 0.76, 1.0), 20.0, 0.10, 9)
	await get_tree().create_timer(0.28).timeout


# -------------------------------------------------------------------------
# EO EGO -- The Order Overlord
# -------------------------------------------------------------------------

## MELEE. The giant golden seal, two-handed, straight down. Mini-boss weight:
## the longest wind-up of any regular skill and the hardest landing.
func _ch4_executive_smash(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(7.0, -15.0, -10.0, 6.0, 3.0, 0.24)
	await _ch3_pose(10.0, -20.0, -13.0, 9.0, 4.0, 0.15)
	await _ch3_ungather()
	_ch3_clip(move, 0.80)
	var seal := _ch3_prop(Color(0.98, 0.80, 0.28, 1.0), Vector2(36, 36), 18)
	_ch3_prop_arc(seal, -16.0, -52.0, -110.0, 0.28, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 7.0, -8, 5, 1.0, 1.06, 0.13, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 14.0, 9, -8, 1.07, 0.93, 0.17, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(8.0)
	_ch4_seal(player_character, 92.0, 0.36)
	_fx_splatter(player_character, Color(1.0, 0.84, 0.34, 0.95), 16, 36.0, 0.58)
	var fade := create_tween()
	fade.tween_property(seal, "modulate:a", 0.0, 0.26)
	await get_tree().create_timer(0.16).timeout


## RANGED. Six sealed documents in two waves -- issuances, not arguments.
func _ch4_eo_barrage(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(4.0, -9.0, -6.0, 3.0, 5.0, 0.18)
	await _ch3_pose(7.0, -13.0, -8.0, 4.0, 8.0, 0.13)
	await _ch3_ungather()
	_ch3_clip(move, 0.82)
	_fx_charge(enemy_character, tint, 0.28)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 6.0, -3, 4, 1, 1, 0.16)])
	for i in 3:                                     # first wave, straight
		_spawn_bolt(enemy_character, player_character, Color(1.0, 0.84, 0.34, 0.95),
			13.0, 0.16, float(i) * 0.05, float(i - 1) * 9.0, false)
	await get_tree().create_timer(0.20).timeout
	for i in 3:                                     # second wave, spread
		_spawn_bolt(enemy_character, player_character, Color(1.0, 0.84, 0.34, 0.95),
			13.0, 0.17, float(i) * 0.05, float(i - 1) * 26.0, false)
	_fx_paper(Vector2(26, 19), _ch4_paper(), 0.30, 0.10, 0.0, 30.0)
	_fx_word("BY EXECUTIVE ORDER", enemy_character, Color(1.0, 0.90, 0.56), 24.0, 0.14, 9)
	await get_tree().create_timer(0.40).timeout


## DEFENSIVE. The seal is planted in front of him and a gold crest rises and
## holds. The strongest regular guard in the chapter.
func _ch4_seal_guard(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -6.0, -8.0, 2.0, 3.0, 0.13)
	await _ch3_pose(8.0, -10.0, -4.0, 5.0, 5.0, 0.17)
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	var seal := _ch3_prop(Color(0.98, 0.80, 0.28, 1.0), Vector2(34, 34), 17)
	_ch3_prop_arc(seal, -14.0, -10.0, -20.0, 0.22, false)
	for i in 3:
		_ch4_seal(enemy_character, 56.0 + float(i) * 18.0, 0.36)
	_fx_word("SEALED", enemy_character, Color(1.0, 0.90, 0.52), 22.0, 0.12, 11)
	await get_tree().create_timer(0.36).timeout
	_fx_splatter(enemy_character, Color(1.0, 0.84, 0.34, 0.9), 8, 24.0, 0.40)


# -------------------------------------------------------------------------
# LOLO ENRILEGEND -- The Eternal Statesman
# -------------------------------------------------------------------------
#
# The boss is a FICTIONAL satirical character. Nothing in these routines
# depicts, names or implies any real person, and nothing here asserts
# wrongdoing: what they dramatise is age, patience and refusal to move.

## MELEE. The full verdict, in the order the brief sets out: adjust the sleeve,
## plant the cane, raise one finger, two deliberate steps, then jab, sweep and
## a heavy downward strike. He is old, so every beat is slower than any other
## melee in the game -- and the last one is the hardest.
func _ch4_veterans_verdict(move: EnemyMove, tint: Color) -> void:
	# Adjusts the sleeve. Head first, unhurried.
	await _ch3_gather(0.0, -2.0, -5.0, 0.0, 2.0, 0.18)
	# Plants the cane, raises one finger.
	await _ch3_pose(4.0, -5.0, -8.0, 2.0, 3.0, 0.20)
	_fx_word("ONE MOMENT", enemy_character, Color(0.96, 0.88, 0.62), 18.0, 0.06, 9)
	await _ch3_ungather()
	_ch3_clip(move, 0.92)
	var cane := _ch3_prop(Color(0.42, 0.28, 0.16, 1.0), Vector2(9, 58), 4)

	# JAB -- short, straight, testing.
	_ch3_prop_arc(cane, -26.0, -6.0, -12.0, 0.16, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 7.0, 0, 2, 1.0, 1.0, 0.14, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_fx_ring(player_character, tint, 40.0, 0.18)

	# SWEEP -- horizontal, across.
	_ch3_prop_arc(cane, -14.0, 18.0, -78.0, 0.20, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 3.0, 3, -6, 1.02, 0.99, 0.16, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	])
	_fx_splatter(player_character, _ch4_paper(), 8, 24.0, 0.40)

	# VERDICT -- the downward strike. This is the beat that hurts.
	_ch3_prop_arc(cane, -20.0, -44.0, -104.0, 0.24, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 5.0, -6, 4, 1.0, 1.05, 0.13, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 13.0, 8, -7, 1.06, 0.94, 0.18, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(8.0)
	_ch4_seal(player_character, 96.0, 0.38)
	_fx_splatter(player_character, Color(1.0, 0.84, 0.34, 0.95), 15, 34.0, 0.58)
	var fade := create_tween()
	fade.tween_property(cane, "modulate:a", 0.0, 0.26)
	await _ch4_wait(0.18)


## RANGED. Aged documents orbit him, launch in two waves -- two straight, then
## two curving in from either side -- and finally one great historical page is
## loosed on a point of the cane. He never leaves his spot.
func _ch4_history_repeats(move: EnemyMove, tint: Color) -> void:
	var sepia := Color(0.86, 0.74, 0.52, 0.97)
	# Raises both hands. The papers gather.
	await _ch3_gather(0.0, -6.0, -9.0, 0.0, 2.0, 0.20)
	for i in 4:
		_fx_paper(Vector2(19, 14), sepia, 0.08, float(i) * 0.05,
			float(i - 2) * 24.0, -18.0)
	_fx_charge(enemy_character, Color(1.0, 0.84, 0.34, 0.9), 0.34)
	await _ch3_ungather()
	_ch3_clip(move, 0.88)

	# First wave: two straight.
	for i in 2:
		_spawn_bolt(enemy_character, player_character, sepia, 12.0,
			0.17, float(i) * 0.06, float(i) * 12.0 - 6.0, false)
	await _ch4_wait(0.22)
	# Second wave: two curving in from above and below.
	for i in 2:
		_spawn_bolt(enemy_character, player_character, sepia, 12.0,
			0.19, float(i) * 0.05, 34.0 if i == 0 else -34.0, false)
	await _ch4_wait(0.20)

	# The great page forms above him, then the cane points and it goes.
	_fx_paper(Vector2(46, 34), sepia, 0.06, 0.0, 0.0, -46.0)
	_fx_word("HISTORY REPEATS!", enemy_character, Color(1.0, 0.88, 0.56), 26.0, 0.10, 12)
	await _ch4_wait(0.20)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 5.0, 0, 3, 1.0, 1.0, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_spawn_bolt(enemy_character, player_character, Color(1.0, 0.84, 0.34, 0.95),
		22.0, 0.20, 0.0, 0.0, false)
	_fx_flash(Color(0.86, 0.74, 0.52, 0.55), 0.20)
	await _ch4_wait(0.30)


## DEFENSIVE. Eternal Resolve. A step back, both feet planted, the cane held
## vertical, and a translucent golden barrier that holds.
##
## The cooldown the brief asks for is enforced by the boss controller, not
## here: this routine only performs the block. See chapter4_boss.gd.
func _ch4_eternal_resolve(move: EnemyMove, tint: Color) -> void:
	# The small step back.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 9.0, 0, 2, 1.0, 1.0, 0.16, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	# Plants both feet, cane upright.
	await _ch3_gather(2.0, -4.0, -6.0, 1.0, 2.0, 0.16)
	await _ch3_pose(6.0, -2.0, -2.0, 2.0, 2.0, 0.18)
	await _ch3_ungather()
	_ch3_clip(move, 0.84)
	var cane := _ch3_prop(Color(0.42, 0.28, 0.16, 1.0), Vector2(9, 60), 4)
	_ch3_prop_arc(cane, -6.0, -6.0, 0.0, 0.20, false)
	# The statesman's emblem, then the barrier over it.
	_ch4_seal(enemy_character, 56.0, 0.30)
	for i in 3:
		_fx_paper(Vector2(16, 12), Color(0.86, 0.74, 0.52, 0.9), 0.07,
			float(i) * 0.05, float(i - 1) * 20.0, -10.0)
	_ch4_seal(enemy_character, 88.0, 0.42)
	_fx_word("STILL HERE", enemy_character, Color(1.0, 0.90, 0.58), 22.0, 0.12, 11)
	await _ch4_wait(0.40)
	var fade := create_tween()
	fade.tween_property(cane, "modulate:a", 0.0, 0.22)


# =========================================================================
# LOLO ENRILEGEND -- the last stand
# =========================================================================

## Set the moment the last stand fires, and never cleared for the rest of the
## encounter. This is what makes it happen ONCE: a second trip to zero finds
## the flag already true and the fight ends normally.
##
## It is deliberately a plain member and not saved anywhere. The revive belongs
## to one fight, so retrying the boss should offer it again -- and _setup_enemy
## resets it along with everything else about the encounter.
var _ch4_last_stand_used: bool = false

## The turn on which the boss last raised Eternal Resolve, or -1 if never.
## Read by _ch4_guard_on_cooldown; reset with the encounter.
var _ch4_last_guard_turn: int = -1

## Whether the boss just refused to lose. Returns true when the encounter
## should CONTINUE instead of ending.
##
## Guarded on three things, all of which must hold: the rival is the Chapter 4
## boss (matched on its own move id rather than on a name, so renaming the
## character cannot silently disarm it), the health really is at zero, and it
## has not already been used this encounter.
func _ch4_last_stand() -> bool:
	if _ch4_last_stand_used or _enemy == null or not _enemy.is_boss:
		return false
	if _enemy_hp > 0 or _enemy.moves.is_empty():
		return false
	if not _enemy.moves[0].signature_id().begins_with("c4combat_"):
		return false          # Chapter 5's boss has its own final mechanic
	_ch4_last_stand_used = true
	await _play_ch4_last_stand()
	return true

## The beat itself: he kneels, the cane hits the floor, the fight looks won --
## and then he stands up again.
##
## The pause before he rises is the whole point. It has to be long enough for
## the player to believe it is over.
func _play_ch4_last_stand() -> void:
	_sequence_running = true
	_update_action_buttons()

	# Down. The cane goes first, then he follows it.
	Audio.play_sfx("attack_impact")
	_shake_screen(6.0)
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(0, 10, 4, 1.02, 0.88, 0.26, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(0, 16, 6, 1.03, 0.82, 0.20, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	_fx_splatter(enemy_character, Color(0.86, 0.74, 0.52, 0.9), 10, 26.0, 0.5)

	# The pause where the player thinks they have won.
	await get_tree().create_timer(0.95).timeout

	# Back up. Slowly, and without any help.
	_fx_charge(enemy_character, Color(1.0, 0.82, 0.34, 1.0), 0.55)
	await _body_play(enemy_character, [
		_beat(0, 8, 2, 1.0, 0.94, 0.28, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_beat(0, -6, 0, 0.98, 1.08, 0.34, Tween.TRANS_BACK, Tween.EASE_OUT),
		_beat(0, 0, 0, 1.0, 1.0, 0.20),
	])
	await _body_end(enemy_character)

	var restored: int = maxi(1, roundi(float(_enemy.max_hp) * CH4_LAST_STAND_FRACTION))
	_enemy_hp = restored
	enemy_heart_row.set_value(_enemy_hp)
	_refresh_damage_preview()

	_fx_ring(enemy_character, Color(1.0, 0.84, 0.36, 0.95), 130.0, 0.5)
	_fx_word("NOT YET.", enemy_character, Color(1.0, 0.88, 0.44), 34.0, 0.0, 17)
	_fx_flash(Color(1.0, 0.70, 0.26), 0.42)
	_shake_screen(8.0)
	word_preview_label.text = "%s is still standing." % _enemy.enemy_name
	await get_tree().create_timer(0.75).timeout

	_sequence_running = false
	_update_action_buttons()


## How much harder the Chapter 4 boss hits once "STILL STANDING" has fired.
##
## 1.0 for everyone else and for phase 1, so this multiplier is invisible
## everywhere except the fight it was written for. The brief asks for phase 2
## to be "slightly" stronger and explicitly NOT a redesign, so the number is
## small and applies to every skill equally rather than singling one out.
func _ch4_phase_gain(move_id: String) -> float:
	if _boss_phase < 2 or _enemy == null or not _enemy.is_boss:
		return 1.0
	if not move_id.begins_with("c4combat_"):
		return 1.0
	return CH4_PHASE2_DAMAGE_GAIN

## How much quicker phase 2 is. Used by the boss routines to shorten their own
## beats; a value below 1.0 shortens both the wind-up and the recovery, which
## is what "attack speed slightly increased, recovery time slightly shorter"
## amounts to when the animation is written as timed beats.
func _ch4_phase_pace() -> float:
	if _boss_phase < 2 or _enemy == null or not _enemy.is_boss:
		return 1.0
	return CH4_PHASE2_PACE


# =========================================================================
# CHAPTER 5 -- CONGRESS OF THE PHILIPPINES
# =========================================================================
#
# The final chapter, animated through the same vocabulary as Chapters 3 and 4:
# _ch3_gather / _ch3_pose / _ch3_ungather bend the cut-out rig, _ch3_clip plays
# the drawn frames, _ch3_prop and _ch3_prop_arc carry a held object, _body_play
# sequences the whole body. Nothing new was added to the engine for it.
#
# Every routine runs ANTICIPATION -> WIND-UP -> EXECUTION -> IMPACT/RELEASE ->
# FOLLOW-THROUGH -> RECOVERY, and the resolver returns the body to idle after.
# No routine translates the sprite as a rigid block: an approach is a walk
# cycle, a strike is the rig bending at the shoulder, hip and knee.
#
# PROJECTILE TIMING. The brief is explicit that damage must land when a
# projectile ARRIVES, not when it is created. That is already how the engine
# works and these routines keep it that way: _spawn_bolt / _fx_paper only put a
# thing in the air, and the resolver applies damage after the routine returns,
# so every ranged routine awaits its own travel time before returning.

## Chapter 5's dispatcher.
func _ch5_perform(move_id: String, move: EnemyMove, tint: Color,
		melee: bool, defending: bool) -> void:
	match move_id:
		# --- Cong Kodigo: the scripted solon -----------------------------
		"c5combat_scripted_strike": await _ch5_scripted_strike(move, tint)
		"c5combat_bill_barrage": await _ch5_bill_barrage(move, tint)
		"c5combat_talking_point_guard": await _ch5_talking_point_guard(move, tint)
		# --- Senador Sawsaw: the floor interrupter ------------------------
		"c5combat_interpellation_jab": await _ch5_interpellation_jab(move, tint)
		"c5combat_floor_hirit": await _ch5_floor_hirit(move, tint)
		"c5combat_point_of_order": await _ch5_point_of_order(move, tint)
		# --- Chairman Chika: the hearing hype -----------------------------
		"c5combat_gavel_bang": await _ch5_gavel_bang(move, tint)
		"c5combat_mic_barrage": await _ch5_mic_barrage(move, tint)
		"c5combat_committee_shield": await _ch5_committee_shield(move, tint)
		# --- Quorum Kuno: the vanishing vote ------------------------------
		"c5combat_attendance_swipe": await _ch5_attendance_swipe(move, tint)
		"c5combat_empty_seat_shuffle": await _ch5_empty_seat_shuffle(move, tint)
		"c5combat_quorum_escape": await _ch5_quorum_escape(move, tint)
		# --- Whip Walanghiya: the vote wrangler ---------------------------
		"c5combat_bloc_breaker": await _ch5_bloc_breaker(move, tint)
		"c5combat_vote_count_volley": await _ch5_vote_volley(move, tint)
		"c5combat_majority_guard": await _ch5_majority_guard(move, tint)
		# --- Amendment Atras: the bill rewriter ---------------------------
		"c5combat_red_pen_slash": await _ch5_red_pen_slash(move, tint)
		"c5combat_revision_rain": await _ch5_revision_rain(move, tint)
		"c5combat_motion_to_amend": await _ch5_motion_to_amend(move, tint)
		# --- Bicam Berto: the conference closer ---------------------------
		"c5combat_conference_crash": await _ch5_conference_crash(move, tint)
		"c5combat_bicam_merge": await _ch5_bicam_merge(move, tint)
		"c5combat_compromise_shield": await _ch5_compromise_shield(move, tint)
		# --- Budget Bomba: the appropriation bruiser ----------------------
		"c5combat_budget_book_bash": await _ch5_budget_book_bash(move, tint)
		"c5combat_appropriation_bombardment": await _ch5_appropriation_bombardment(move, tint)
		"c5combat_fiscal_fortress": await _ch5_fiscal_fortress(move, tint)
		# --- MarTinde RomuRulez: the house supremo -------------------------
		"c5combat_house_rules": await _ch5_house_rules(move, tint)
		"c5combat_majority_motion": await _ch5_majority_motion(move, tint)
		"c5combat_speakers_shield": await _ch5_speakers_shield(move, tint)
		_: await _ch3_generic(move, tint, melee, defending)


## Congress runs on paper, and it is always the same official cream stock.
func _ch5_paper() -> Color:
	return Color(0.97, 0.95, 0.89, 0.98)


## The chamber's authority colour: gavels, seals, the majority.
func _ch5_gold() -> Color:
	return Color(0.97, 0.80, 0.33, 0.95)


## A wait that shortens once the boss is in session, and is an ordinary wait
## for every rival. Chapter 4 proved the pattern; reusing it means "phase 2 is
## quicker" stays one number rather than thirty edited timings.
func _ch5_wait(secs: float) -> void:
	await get_tree().create_timer(secs * _ch5_pace(), false).timeout


func _ch5_pace() -> float:
	if _enemy == null or not _enemy.is_boss:
		return 1.0
	if _ch5_final_reading_active:
		return CH5_FINAL_READING_PACE
	if _boss_phase >= 2:
		return CH5_PHASE2_PACE
	return 1.0


# -------------------------------------------------------------------------
# CONG KODIGO -- The Scripted Solon
# -------------------------------------------------------------------------

## MELEE. He checks the card first. That IS the anticipation -- he cannot begin
## until he has read what he is about to say.
func _ch5_scripted_strike(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(1.0, -3.0, -8.0, 1.0, 2.0, 0.18)      # reads the card
	await _ch3_pose(6.0, -11.0, -4.0, 3.0, 5.0, 0.13)       # nods, coils
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	var scroll := _ch3_prop(Color(0.94, 0.91, 0.82, 1.0), Vector2(34, 10), 5)
	_ch3_prop_arc(scroll, -32.0, -4.0, -58.0, 0.22, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 4.0, 1, 4, 1.01, 0.99, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 10.0, -3, -6, 1.02, 0.99, 0.14, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, _ch5_paper(), 10, 26.0, 0.46)
	_fx_ring(player_character, tint, 52.0, 0.26)
	var fade := create_tween()
	fade.tween_property(scroll, "modulate:a", 0.0, 0.20)
	await _ch5_wait(0.13)


## RANGED. Three bills: straight, curving, then one bigger and faster. Each is
## released as its own beat, and the routine waits for the last to cross.
func _ch5_bill_barrage(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -6.0, -5.0, 2.0, 4.0, 0.16)
	await _ch3_pose(5.0, -10.0, -3.0, 3.0, 6.0, 0.12)
	await _ch3_ungather()
	_ch3_clip(move, 0.78)
	_fx_charge(enemy_character, tint, 0.22)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 5.0, 0, 3, 1, 1, 0.16)])
	var paper := _ch5_paper()
	_fx_paper(Vector2(16, 12), paper, 0.28, 0.00, 0.0, 26.0)
	_spawn_bolt(enemy_character, player_character, paper, 9.0, 0.17, 0.00, 0.0, false)
	_fx_paper(Vector2(17, 12), paper, 0.30, 0.10, -20.0, -34.0)
	_spawn_bolt(enemy_character, player_character, paper, 9.0, 0.18, 0.10, -18.0, false)
	_fx_paper(Vector2(22, 16), tint, 0.24, 0.20, 8.0, 44.0)
	_spawn_bolt(enemy_character, player_character, tint, 14.0, 0.14, 0.20, 6.0, false, _ch5_land_ranged_hit)
	await _ch5_wait(0.44)


## DEFENSIVE. The talking points come up in layers and he braces behind them.
func _ch5_talking_point_guard(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -3.0, -8.0, 0.0, 2.0, 0.12)
	await _ch3_pose(8.0, -9.0, -4.0, 5.0, 4.0, 0.16)        # knees bend
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	for i in 3:
		var card := _ch3_prop(_ch5_paper(), Vector2(22, 28), 2)
		card.rotation = deg_to_rad(-14.0 + float(i) * 12.0)
		_ch3_prop_arc(card, -8.0 - float(i) * 4.0, -6.0, -8.0, 0.20 + float(i) * 0.04, false)
	_fx_ring(enemy_character, tint, 76.0, 0.36)
	_fx_word("ON THE RECORD", enemy_character, Color(1.0, 0.94, 0.70), 20.0, 0.10, 9)
	await _ch5_wait(0.32)
	_fx_splatter(enemy_character, _ch5_paper(), 8, 24.0, 0.42)   # cards scatter


# -------------------------------------------------------------------------
# SENADOR SAWSAW -- The Floor Interrupter
# -------------------------------------------------------------------------

## MELEE. A pointing feint, then two jabs -- the second harder than the first.
func _ch5_interpellation_jab(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -5.0, -9.0, 2.0, 3.0, 0.14)      # finger up
	# The feint: he commits, then stops.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 6.0, -3, -5, 1.0, 1.0, 0.10, Tween.TRANS_SINE, Tween.EASE_OUT),
		_beat(_ch3_dx() - 2.0, -1, -2, 1.0, 1.0, 0.06),
	])
	await _ch3_ungather()
	_ch3_clip(move, 0.76)
	# First jab.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 9.0, 0, -3, 1.0, 1.0, 0.10, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(_ch3_dx() - 3.0, 0, 0, 1.0, 1.0, 0.07),
	])
	_fx_ring(player_character, tint, 38.0, 0.16)
	# Second, harder.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 14.0, -3, -6, 1.03, 0.99, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, tint, 10, 26.0, 0.46)
	await _ch5_wait(0.14)


## RANGED. Three speech waves off the microphone, each wider than the last.
func _ch5_floor_hirit(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -7.0, -6.0, 2.0, 4.0, 0.17)      # leans to the mic
	await _ch3_pose(4.0, -11.0, -8.0, 3.0, 6.0, 0.13)       # inhales
	await _ch3_ungather()
	_ch3_clip(move, 0.80)
	_fx_charge(enemy_character, tint, 0.24)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 4.0, -2, 3, 1, 1, 0.15)])
	# Waves rather than text walls: rings that leave him and cross the gap.
	for i in 3:
		_fx_ring(enemy_character, tint, 46.0 + float(i) * 22.0, 0.30, float(i) * 0.10)
		_spawn_bolt(enemy_character, player_character, tint,
			10.0 + float(i) * 4.0, 0.18, float(i) * 0.10, float(i - 1) * 10.0, false,
			_ch5_land_ranged_hit if i == 2 else Callable())
	_fx_word("MISTER SPEAKER!", enemy_character, Color(1.0, 0.84, 0.60), 22.0, 0.12, 9)
	await _ch5_wait(0.46)


## DEFENSIVE COUNTER. One finger, a chamber flash, and everything stops.
func _ch5_point_of_order(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -2.0, -10.0, 0.0, 1.0, 0.10)     # the finger snaps up
	_ch3_clip(move, 0.70)
	_fx_flash(Color(1.0, 0.92, 0.70, 0.45), 0.16)
	_fx_word("POINT OF ORDER!", enemy_character, Color(1.0, 0.88, 0.52), 24.0, 0.04, 11)
	await _ch3_pose(6.0, -6.0, -4.0, 3.0, 4.0, 0.16)
	await _ch3_ungather()
	_fx_ring(enemy_character, _ch5_gold(), 70.0, 0.34)
	await _ch5_wait(0.30)
	# The counter: the barrier answers back.
	_fx_ring(enemy_character, tint, 96.0, 0.28)
	_fx_splatter(player_character, tint, 6, 20.0, 0.34)
	await _ch5_wait(0.16)


# -------------------------------------------------------------------------
# CHAIRMAN CHIKA -- The Hearing Hype
# -------------------------------------------------------------------------

## MELEE. The gavel, all the way up and all the way down.
func _ch5_gavel_bang(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(6.0, -14.0, -9.0, 5.0, 3.0, 0.20)     # arm high, torso back
	await _ch3_pose(9.0, -17.0, -12.0, 7.0, 4.0, 0.13)      # feet brace
	await _ch3_ungather()
	_ch3_clip(move, 0.78)
	var gavel := _ch3_prop(Color(0.55, 0.36, 0.18, 1.0), Vector2(14, 30), 4)
	_ch3_prop_arc(gavel, -18.0, -48.0, -102.0, 0.26, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 6.0, -7, 4, 1.0, 1.05, 0.12, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 12.0, 8, -7, 1.05, 0.95, 0.16, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(7.0)
	_fx_ring(player_character, _ch5_gold(), 74.0, 0.32)
	_fx_splatter(player_character, _ch5_paper(), 13, 32.0, 0.54)
	var fade := create_tween()
	fade.tween_property(gavel, "modulate:a", 0.0, 0.24)
	await _ch5_wait(0.16)


## RANGED. Three microphones: straight, diagonal, then a spinning fast one.
func _ch5_mic_barrage(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(3.0, -7.0, -5.0, 2.0, 5.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.78)
	_fx_charge(enemy_character, tint, 0.22)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 5.0, -1, 3, 1, 1, 0.15)])
	var steel := Color(0.62, 0.68, 0.76, 0.96)
	_spawn_bolt(enemy_character, player_character, steel, 11.0, 0.18, 0.00, 0.0, false)
	_spawn_bolt(enemy_character, player_character, steel, 11.0, 0.19, 0.09, -26.0, false)
	_spawn_bolt(enemy_character, player_character, tint, 15.0, 0.13, 0.18, 12.0, false, _ch5_land_ranged_hit)
	_fx_paper(Vector2(12, 9), steel, 0.22, 0.06, -6.0, 20.0)
	await _ch5_wait(0.42)


## DEFENSIVE. The hearing table itself comes up, folders stacked around it.
func _ch5_committee_shield(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(0.0, -4.0, -7.0, 0.0, 2.0, 0.12)
	await _ch3_pose(8.0, -8.0, -3.0, 5.0, 5.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	var table := _ch3_prop(Color(0.44, 0.28, 0.15, 1.0), Vector2(44, 22), 3)
	_ch3_prop_arc(table, -12.0, -14.0, -6.0, 0.22, false)
	for i in 2:
		var stack := _ch3_prop(_ch5_paper(), Vector2(16, 20), 2)
		_ch3_prop_arc(stack, -6.0 + float(i) * 24.0, -8.0, 6.0, 0.20, false)
	_fx_ring(enemy_character, tint, 82.0, 0.36)
	_fx_word("ORDER IN THE HEARING", enemy_character, Color(1.0, 0.86, 0.96), 20.0, 0.12, 9)
	await _ch5_wait(0.34)
	_fx_splatter(enemy_character, _ch5_paper(), 9, 26.0, 0.44)   # papers fall


# -------------------------------------------------------------------------
# QUORUM KUNO -- The Vanishing Vote
# -------------------------------------------------------------------------
#
# The brief is firm that evasion must never be unfair, so every vanish here is
# telegraphed before it happens, has a visible destination, and ends with him
# back on his own mark. He is hard to hit, never impossible to read.

## MELEE. He actually runs in -- real legs, not a slide -- swipes, and runs out.
func _ch5_attendance_swipe(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -4.0, -7.0, 1.0, 3.0, 0.16)      # checks the sheet
	await _ch3_pose(10.0, -6.0, -3.0, 5.0, 4.0, 0.12)       # lowers his stance
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	var board := _ch3_prop(Color(0.80, 0.74, 0.60, 1.0), Vector2(20, 26), 3)
	_ch3_prop_arc(board, -30.0, -6.0, -46.0, 0.20, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 3.0, 2, 3, 1.0, 1.0, 0.09, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 11.0, -3, -5, 1.02, 0.99, 0.13, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, _ch5_paper(), 9, 24.0, 0.44)
	_fx_ring(player_character, tint, 48.0, 0.24)
	# And straight back out again.
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 6.0, 0, 4, 1.0, 1.0, 0.14, Tween.TRANS_SINE, Tween.EASE_OUT),
		_beat(_ch3_dx(), 0, 0, 1.0, 1.0, 0.12),
	])
	var fade := create_tween()
	fade.tween_property(board, "modulate:a", 0.0, 0.18)


## RANGED TRICK. Empty chairs bloom, he half-fades, throws from the new spot,
## and comes back. The chairs ARE the telegraph: they appear before he moves.
func _ch5_empty_seat_shuffle(move: EnemyMove, tint: Color) -> void:
	# Telegraph first, always.
	for i in 3:
		_fx_paper(Vector2(18, 22), Color(0.62, 0.70, 0.78, 0.65), 0.05,
			float(i) * 0.06, float(i - 1) * 30.0, 6.0)
	await _ch5_wait(0.26)
	_ch3_clip(move, 0.76)
	var dim := create_tween()
	dim.tween_property(enemy_character, "modulate:a", 0.45, 0.14)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 18.0, 0, 6, 1.0, 1.0, 0.16, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	])
	var back := create_tween()
	back.tween_property(enemy_character, "modulate:a", 1.0, 0.12)
	_fx_charge(enemy_character, tint, 0.18)
	for i in 3:
		_spawn_bolt(enemy_character, player_character, _ch5_paper(),
			10.0, 0.18, float(i) * 0.06, float(i - 1) * 16.0, false,
			_ch5_land_ranged_hit if i == 2 else Callable())
	await _ch5_wait(0.30)
	# Home again, on his own mark.
	await _body_play(enemy_character, [
		_beat(_ch3_dx(), 0, 0, 1.0, 1.0, 0.16, Tween.TRANS_SINE, Tween.EASE_OUT),
	])


## DEFENSIVE EVASION. Telegraphed, then a real sidestep -- never a teleport.
func _ch5_quorum_escape(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(1.0, -3.0, -9.0, 1.0, 3.0, 0.16)      # glances around
	_fx_paper(Vector2(20, 24), Color(0.62, 0.70, 0.78, 0.55), 0.05, 0.0, 22.0, 4.0)
	await _ch3_pose(9.0, -5.0, -4.0, 5.0, 4.0, 0.14)        # knees bend
	await _ch3_ungather()
	_ch3_clip(move, 0.72)
	var dim := create_tween()
	dim.tween_property(enemy_character, "modulate:a", 0.40, 0.12)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 15.0, 0, 5, 1.0, 1.0, 0.16, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	_fx_ring(enemy_character, tint, 68.0, 0.30)
	_fx_word("WALANG QUORUM", enemy_character, Color(0.80, 0.90, 1.0), 20.0, 0.08, 9)
	await _ch5_wait(0.26)
	var back := create_tween()
	back.tween_property(enemy_character, "modulate:a", 1.0, 0.14)
	await _body_play(enemy_character, [
		_beat(_ch3_dx(), 0, 0, 1.0, 1.0, 0.15, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	])


# -------------------------------------------------------------------------
# WHIP WALANGHIYA -- The Vote Wrangler
# -------------------------------------------------------------------------

## MELEE. He points, the bloc gathers behind the point, then he goes through.
func _ch5_bloc_breaker(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -6.0, -6.0, 2.0, 4.0, 0.16)      # the point
	for i in 3:
		_fx_ring(enemy_character, tint, 30.0 + float(i) * 12.0, 0.22, float(i) * 0.05)
	await _ch3_pose(10.0, -12.0, -4.0, 6.0, 5.0, 0.14)      # loads the shoulder
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 5.0, 3, 3, 1.01, 1.0, 0.10, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 13.0, -4, -6, 1.04, 0.98, 0.15, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(5.0)
	_fx_splatter(player_character, tint, 12, 30.0, 0.50)
	_fx_ring(player_character, tint, 66.0, 0.30)
	await _ch5_wait(0.14)


## RANGED. Two waves of tokens at different heights, then one big marker.
func _ch5_vote_volley(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(3.0, -7.0, -5.0, 2.0, 5.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.80)
	_fx_charge(enemy_character, tint, 0.24)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 5.0, -1, 3, 1, 1, 0.15)])
	for i in 3:                                     # low wave
		_spawn_bolt(enemy_character, player_character, tint, 10.0, 0.17,
			float(i) * 0.05, 16.0 + float(i) * 4.0, false)
	await _ch5_wait(0.16)
	for i in 3:                                     # high wave
		_spawn_bolt(enemy_character, player_character, tint, 10.0, 0.17,
			float(i) * 0.05, -20.0 - float(i) * 4.0, false)
	await _ch5_wait(0.16)
	_spawn_bolt(enemy_character, player_character, _ch5_gold(), 20.0, 0.19, 0.0, 0.0, false, _ch5_land_ranged_hit)
	await _ch5_wait(0.32)


## DEFENSIVE. The bloc falls in behind him and links up.
func _ch5_majority_guard(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(1.0, -4.0, -6.0, 1.0, 3.0, 0.13)
	await _ch3_pose(6.0, -8.0, -3.0, 4.0, 5.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.74)
	# The allies: silhouettes that arrive, link, and go again.
	var allies: Array[Panel] = []
	for i in 4:
		var ally := _ch3_prop(Color(tint.r, tint.g, tint.b, 0.55), Vector2(18, 44), 3)
		_ch3_prop_arc(ally, 10.0 + float(i) * 12.0, -4.0, 0.0, 0.22 + float(i) * 0.03, false)
		allies.append(ally)
	for i in 3:
		_fx_ring(enemy_character, tint, 50.0 + float(i) * 16.0, 0.34, float(i) * 0.05)
	_fx_word("MAYORYA", enemy_character, Color(0.72, 1.0, 0.84), 22.0, 0.12, 11)
	await _ch5_wait(0.38)
	for ally in allies:
		var out := create_tween()
		out.tween_property(ally, "modulate:a", 0.0, 0.20)


# -------------------------------------------------------------------------
# AMENDMENT ATRAS -- The Bill Rewriter
# -------------------------------------------------------------------------

## MELEE. Two cuts of the red pen: diagonal, then horizontal.
func _ch5_red_pen_slash(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(4.0, -8.0, -6.0, 3.0, 4.0, 0.16)      # spins the pen
	await _ch3_pose(8.0, -12.0, -3.0, 4.0, 6.0, 0.12)       # repositions the feet
	await _ch3_ungather()
	_ch3_clip(move, 0.76)
	var pen := _ch3_prop(Color(0.81, 0.24, 0.23, 1.0), Vector2(30, 8), 4)
	# Cut one: diagonal.
	_ch3_prop_arc(pen, -28.0, -20.0, -66.0, 0.18, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 8.0, -2, -5, 1.0, 1.0, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, Color(0.86, 0.22, 0.20, 0.95), 7, 22.0, 0.36)
	# Cut two: horizontal, the correction.
	_ch3_prop_arc(pen, -20.0, 16.0, 54.0, 0.18, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 13.0, 3, 5, 1.02, 0.99, 0.13, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_splatter(player_character, Color(0.86, 0.22, 0.20, 0.95), 9, 26.0, 0.44)
	var fade := create_tween()
	fade.tween_property(pen, "modulate:a", 0.0, 0.20)
	await _ch5_wait(0.14)


## RANGED. Pages fall in two telegraphed sets, then one REVISED document.
func _ch5_revision_rain(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -6.0, -8.0, 2.0, 3.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.84)
	# Telegraph: the pages gather overhead before any of them fall.
	for i in 3:
		_fx_paper(Vector2(16, 12), _ch5_paper(), 0.05, float(i) * 0.05,
			float(i - 1) * 26.0, -52.0)
	await _ch5_wait(0.28)
	for i in 3:
		_spawn_bolt(enemy_character, player_character, _ch5_paper(),
			9.0, 0.20, float(i) * 0.06, -34.0 + float(i) * 6.0, false)
	await _ch5_wait(0.20)
	for i in 2:
		_spawn_bolt(enemy_character, player_character, _ch5_paper(),
			9.0, 0.20, float(i) * 0.06, 18.0 + float(i) * 8.0, false)
	await _ch5_wait(0.18)
	_fx_paper(Vector2(40, 30), tint, 0.06, 0.0, 0.0, -40.0)
	_fx_word("REVISED", enemy_character, Color(1.0, 0.72, 0.68), 24.0, 0.08, 12)
	_spawn_bolt(enemy_character, player_character, tint, 22.0, 0.20, 0.0, 0.0, false, _ch5_land_ranged_hit)
	await _ch5_wait(0.32)


## DEFENSIVE. He crosses the incoming text out and rewrites it into a wall.
func _ch5_motion_to_amend(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(1.0, -4.0, -7.0, 1.0, 3.0, 0.13)
	_ch3_clip(move, 0.76)
	var bill := _ch3_prop(_ch5_paper(), Vector2(34, 42), 3)
	_ch3_prop_arc(bill, -10.0, -8.0, -6.0, 0.20, false)
	await _ch5_wait(0.18)
	# The crossing-out, then the replacement.
	_fx_splatter(enemy_character, Color(0.86, 0.22, 0.20, 0.95), 6, 18.0, 0.30)
	_fx_word("AMENDED", enemy_character, Color(1.0, 0.74, 0.70), 20.0, 0.06, 10)
	await _ch3_pose(6.0, -7.0, -3.0, 4.0, 4.0, 0.15)
	await _ch3_ungather()
	_fx_ring(enemy_character, tint, 78.0, 0.34)
	await _ch5_wait(0.30)


# -------------------------------------------------------------------------
# BICAM BERTO -- The Conference Closer
# -------------------------------------------------------------------------
#
# His whole identity is TWO WEAKER THINGS -> MERGE -> ONE STRONGER RESULT, and
# all three of his skills say it: two strikes then a double, two bills then a
# fused one, two barriers then a single shield.

## MELEE. One folder, the other folder, then both together.
func _ch5_conference_crash(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(4.0, -9.0, -5.0, 3.0, 4.0, 0.17)
	await _ch3_ungather()
	_ch3_clip(move, 0.82)
	var senate := _ch3_prop(Color(0.31, 0.44, 0.78, 1.0), Vector2(24, 30), 3)
	var house := _ch3_prop(Color(0.78, 0.28, 0.28, 1.0), Vector2(24, 30), 3)
	# Strike one.
	_ch3_prop_arc(senate, -26.0, -8.0, -40.0, 0.16, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 7.0, 0, -3, 1.0, 1.0, 0.11, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_fx_ring(player_character, Color(0.42, 0.56, 0.92, 0.9), 40.0, 0.18)
	# Strike two.
	_ch3_prop_arc(house, -26.0, 6.0, 40.0, 0.16, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 4.0, 0, 3, 1.0, 1.0, 0.11, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_fx_ring(player_character, Color(0.90, 0.36, 0.34, 0.9), 40.0, 0.18)
	# And both, together, downward.
	_ch3_prop_arc(senate, -14.0, -34.0, -84.0, 0.20, false)
	_ch3_prop_arc(house, -14.0, -34.0, -84.0, 0.20, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 5.0, -6, 4, 1.0, 1.05, 0.11, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 14.0, 8, -7, 1.05, 0.95, 0.16, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(6.0)
	_fx_splatter(player_character, _ch5_paper(), 14, 32.0, 0.54)
	for prop in [senate, house]:
		var fade := create_tween()
		fade.tween_property(prop, "modulate:a", 0.0, 0.22)
	await _ch5_wait(0.16)


## RANGED SIGNATURE. Two bills converge, fuse, and the fused one is what flies.
func _ch5_bicam_merge(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(2.0, -6.0, -6.0, 2.0, 4.0, 0.18)
	await _ch3_ungather()
	_ch3_clip(move, 0.90)
	var blue := Color(0.36, 0.50, 0.88, 0.96)
	var red := Color(0.86, 0.32, 0.30, 0.96)
	# Each chamber's bill takes its own side, and hovers.
	_fx_paper(Vector2(22, 28), blue, 0.05, 0.00, -40.0, -26.0)
	_fx_paper(Vector2(22, 28), red, 0.05, 0.00, 40.0, -26.0)
	_fx_charge(enemy_character, tint, 0.32)
	await _ch5_wait(0.34)
	# They come together at the centre.
	_fx_paper(Vector2(20, 26), blue, 0.10, 0.00, -14.0, -20.0)
	_fx_paper(Vector2(20, 26), red, 0.10, 0.00, 14.0, -20.0)
	await _ch5_wait(0.24)
	# And leave as one, larger and gold.
	_fx_ring(enemy_character, _ch5_gold(), 84.0, 0.30)
	_fx_paper(Vector2(46, 34), _ch5_gold(), 0.08, 0.0, 0.0, -22.0)
	_fx_word("BICAM", enemy_character, Color(1.0, 0.88, 0.52), 24.0, 0.06, 13)
	await _ch5_wait(0.18)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 6.0, 0, 3, 1.0, 1.0, 0.13, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_spawn_bolt(enemy_character, player_character, _ch5_gold(), 26.0, 0.22, 0.0, 0.0, false, _ch5_land_ranged_hit)
	await _ch5_wait(0.34)


## DEFENSIVE. Two barriers slide together and become one.
func _ch5_compromise_shield(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(1.0, -4.0, -6.0, 1.0, 3.0, 0.14)
	await _ch3_pose(6.0, -8.0, -3.0, 4.0, 4.0, 0.15)
	await _ch3_ungather()
	_ch3_clip(move, 0.78)
	var senate := _ch3_prop(Color(0.34, 0.48, 0.86, 0.92), Vector2(20, 46), 3)
	var house := _ch3_prop(Color(0.84, 0.30, 0.28, 0.92), Vector2(20, 46), 3)
	_ch3_prop_arc(senate, -22.0, -6.0, -8.0, 0.22, false)
	_ch3_prop_arc(house, 18.0, -6.0, 8.0, 0.22, false)
	await _ch5_wait(0.26)
	# The compromise: they meet in the middle.
	_ch3_prop_arc(senate, 12.0, 0.0, 8.0, 0.18, false)
	_ch3_prop_arc(house, -12.0, 0.0, -8.0, 0.18, false)
	_fx_ring(enemy_character, _ch5_gold(), 80.0, 0.34)
	_fx_word("RECONCILED", enemy_character, Color(1.0, 0.90, 0.62), 20.0, 0.10, 10)
	await _ch5_wait(0.32)


# -------------------------------------------------------------------------
# BUDGET BOMBA -- The Appropriation Bruiser
# -------------------------------------------------------------------------
#
# Slow on purpose. Every beat here is longer than its equivalent elsewhere in
# the chapter -- the threat is weight and reach, never speed.

## MELEE. He strains the book up, walks it in, swings, then brings it down.
func _ch5_budget_book_bash(move: EnemyMove, tint: Color) -> void:
	# The strain. Longest anticipation in the game.
	await _ch3_gather(6.0, -8.0, -4.0, 4.0, 2.0, 0.26)
	await _ch3_pose(10.0, -16.0, -9.0, 8.0, 3.0, 0.20)
	await _ch3_ungather()
	_ch3_clip(move, 0.94)
	var book := _ch3_prop(Color(0.42, 0.28, 0.14, 1.0), Vector2(46, 52), 2)
	# Horizontal swing.
	_ch3_prop_arc(book, -34.0, -6.0, -52.0, 0.26, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 6.0, 2, -4, 1.02, 1.0, 0.18, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	])
	_fx_splatter(player_character, _ch5_gold(), 10, 28.0, 0.46)
	# Then the downward smash.
	_ch3_prop_arc(book, -18.0, -56.0, -112.0, 0.30, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 8.0, -8, 5, 1.0, 1.07, 0.15, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 15.0, 10, -8, 1.08, 0.92, 0.20, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(9.0)
	_fx_ring(player_character, _ch5_gold(), 96.0, 0.36)
	_fx_splatter(player_character, _ch5_paper(), 18, 38.0, 0.60)
	var fade := create_tween()
	fade.tween_property(book, "modulate:a", 0.0, 0.28)
	await _ch5_wait(0.20)


## RANGED. A light volley, a heavy one, then the whole folder.
func _ch5_appropriation_bombardment(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(5.0, -9.0, -5.0, 4.0, 3.0, 0.22)
	await _ch3_ungather()
	_ch3_clip(move, 0.92)
	_fx_charge(enemy_character, tint, 0.30)
	await _body_play(enemy_character, [_beat(_ch3_dx() - 4.0, 2, 3, 1, 1, 0.18)])
	for i in 3:                                     # light
		_spawn_bolt(enemy_character, player_character, _ch5_gold(),
			9.0, 0.19, float(i) * 0.05, float(i - 1) * 12.0, false)
	await _ch5_wait(0.22)
	for i in 3:                                     # heavy
		_spawn_bolt(enemy_character, player_character, tint,
			15.0, 0.20, float(i) * 0.06, float(i - 1) * 20.0, false)
	await _ch5_wait(0.24)
	_fx_paper(Vector2(44, 32), tint, 0.28, 0.0, 0.0, 26.0)
	_spawn_bolt(enemy_character, player_character, tint, 26.0, 0.24, 0.0, 0.0, false, _ch5_land_ranged_hit)
	await _ch5_wait(0.36)


## DEFENSIVE. The ledger opens, he grips both covers and plants.
func _ch5_fiscal_fortress(move: EnemyMove, tint: Color) -> void:
	await _ch3_gather(3.0, -6.0, -6.0, 2.0, 3.0, 0.18)
	await _ch3_pose(12.0, -8.0, -3.0, 7.0, 4.0, 0.20)       # feet very wide
	await _ch3_ungather()
	_ch3_clip(move, 0.86)
	var ledger := _ch3_prop(Color(0.46, 0.30, 0.16, 1.0), Vector2(58, 50), 2)
	_ch3_prop_arc(ledger, -16.0, -10.0, -4.0, 0.26, false)
	for i in 3:
		_fx_ring(enemy_character, _ch5_gold(), 58.0 + float(i) * 20.0, 0.38, float(i) * 0.06)
	_fx_word("APPROPRIATED", enemy_character, Color(1.0, 0.88, 0.48), 22.0, 0.12, 11)
	await _ch5_wait(0.42)
	_fx_splatter(enemy_character, _ch5_paper(), 10, 28.0, 0.46)  # pages fly


# -------------------------------------------------------------------------
# MARTINDE ROMURULEZ -- The House Supremo
# -------------------------------------------------------------------------
#
# The fictional parody uses the user's appearance reference, with his approved
# navy polo and dark pants. Satire concerns procedure, never factual allegations.

## MELEE. The full command combo, in the order the brief sets out: cuff, gavel
## raised, a point, a step through, then gavel jab, folder sweep, and the
## overhead slam that carries the damage.
func _ch5_house_rules(move: EnemyMove, tint: Color) -> void:
	# Adjusts his polo collar, unhurried and composed.
	await _ch3_gather(0.0, -2.0, -4.0, 0.0, 2.0, 0.20)
	# Raises the gavel and points.
	await _ch3_pose(3.0, -7.0, -9.0, 2.0, 3.0, 0.20)
	_fx_word("ORDER!", enemy_character, Color(1.0, 0.90, 0.56), 20.0, 0.04, 11)
	await _ch3_ungather()
	_ch3_clip(move, 0.94)
	var gavel := _ch3_prop(Color(0.52, 0.34, 0.17, 1.0), Vector2(13, 34), 4)
	var folder := _ch3_prop(_ch5_paper(), Vector2(26, 32), 3)

	# The step through, then the gavel jab.
	_ch3_prop_arc(gavel, -24.0, -6.0, -16.0, 0.16, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 7.0, 0, 3, 1.0, 1.0, 0.14, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_fx_ring(player_character, tint, 42.0, 0.18)

	# The folder sweep, horizontal.
	_ch3_prop_arc(folder, -22.0, 12.0, 62.0, 0.18, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 4.0, 3, -5, 1.02, 0.99, 0.15, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	])
	_fx_splatter(player_character, _ch5_paper(), 9, 26.0, 0.42)

	# THE SLAM. This is the strongest frame and the one the damage belongs to,
	# so it is the last thing that happens before the routine returns.
	_ch3_prop_arc(gavel, -20.0, -50.0, -110.0, 0.24, false)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() + 6.0, -7, 5, 1.0, 1.06, 0.13, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx() - 15.0, 9, -8, 1.07, 0.93, 0.18, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(9.0)
	_fx_ring(player_character, _ch5_gold(), 104.0, 0.38)
	_fx_splatter(player_character, _ch5_gold(), 16, 36.0, 0.58)
	for prop in [gavel, folder]:
		var fade := create_tween()
		fade.tween_property(prop, "modulate:a", 0.0, 0.26)
	await _ch5_wait(0.18)


## RANGED. The board lights, the count gathers, two waves go, and the MAJORITY
## symbol follows them. He never leaves his mark while any of it travels.
func _ch5_majority_motion(move: EnemyMove, tint: Color) -> void:
	# One calm raised hand. That is the entire wind-up.
	await _ch3_gather(0.0, -5.0, -7.0, 0.0, 2.0, 0.22)
	_fx_charge(enemy_character, _ch5_gold(), 0.34)
	# The board and the count.
	for i in 4:
		_fx_paper(Vector2(14, 14), _ch5_gold(), 0.05, float(i) * 0.05,
			float(i - 2) * 22.0, -30.0)
	await _ch3_ungather()
	_ch3_clip(move, 0.92)
	await _ch5_wait(0.22)

	# Wave one: the votes.
	for i in 3:
		_spawn_bolt(enemy_character, player_character, _ch5_gold(),
			11.0, 0.18, float(i) * 0.05, float(i - 1) * 14.0, false)
	await _ch5_wait(0.22)
	# Wave two: the papers.
	for i in 3:
		_fx_paper(Vector2(18, 13), _ch5_paper(), 0.28, float(i) * 0.05,
			float(i - 1) * 20.0, float(i - 1) * 26.0)
		_spawn_bolt(enemy_character, player_character, _ch5_paper(),
			10.0, 0.19, float(i) * 0.05, float(i - 1) * 24.0, false)
	await _ch5_wait(0.22)

	# And the motion itself.
	_fx_word("MAJORITY", enemy_character, Color(1.0, 0.88, 0.50), 28.0, 0.06, 14)
	_fx_ring(enemy_character, _ch5_gold(), 110.0, 0.34)
	await _ch5_wait(0.18)
	await _body_play(enemy_character, [
		_beat(_ch3_dx() - 6.0, 0, 3, 1.0, 1.0, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	_spawn_bolt(enemy_character, player_character, _ch5_gold(), 28.0, 0.22, 0.0, 0.0, false, _ch5_land_ranged_hit)
	_fx_flash(Color(1.0, 0.86, 0.44, 0.40), 0.20)
	_shake_screen(3.0)
	await _ch5_wait(0.34)


## DEFENSIVE. He strikes the stand, the emblem lights, and the panels rise.
##
## The cooldown the brief asks for is enforced by _ch5_guard_on_cooldown in the
## move rotation, not here: this routine only performs the block.
func _ch5_speakers_shield(move: EnemyMove, tint: Color) -> void:
	# Into a firm stance, gavel up.
	await _ch3_gather(2.0, -4.0, -6.0, 1.0, 2.0, 0.18)
	await _ch3_pose(7.0, -9.0, -8.0, 3.0, 3.0, 0.16)
	await _ch3_ungather()
	_ch3_clip(move, 0.88)
	# The strike on the stand.
	await _body_play(enemy_character, [
		_beat(_ch3_dx(), 6, 2, 1.0, 0.96, 0.11, Tween.TRANS_QUAD, Tween.EASE_IN),
		_beat(_ch3_dx(), 0, 0, 1.0, 1.0, 0.10, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_shake_screen(4.0)
	# The emblem under his feet, then the panels, then the orbiting votes.
	_fx_ring(enemy_character, _ch5_gold(), 62.0, 0.30)
	for i in 3:
		var panel := _ch3_prop(Color(0.96, 0.93, 0.86, 0.90), Vector2(20, 44), 3)
		_ch3_prop_arc(panel, -26.0 + float(i) * 26.0, -8.0,
			-10.0 + float(i) * 10.0, 0.24, false)
	for i in 3:
		_fx_ring(enemy_character, _ch5_gold(), 74.0 + float(i) * 16.0,
			0.36, float(i) * 0.06)
	_fx_word("THE CHAIR IS PROTECTED", enemy_character,
		Color(1.0, 0.90, 0.56), 22.0, 0.12, 10)
	await _ch5_wait(0.42)
	_fx_splatter(enemy_character, _ch5_paper(), 8, 24.0, 0.40)


# =========================================================================
# SPIKER SUPREMO -- FINAL READING, and the defeat of the last boss
# =========================================================================

## True once FINAL READING has fired, for the rest of the encounter. This is
## what makes it happen ONCE: the trigger checks the flag before anything else.
var _ch5_final_reading_used: bool = false
## True only while the closing stage is running, so the pace helper can read it.
var _ch5_final_reading_active: bool = false
var _ch5_move_active: bool = false
var _ch5_final_reading_turns: int = 0
var _ch5_ranged_contact_pending: bool = false
var _ch5_ranged_damage: int = 0

func _ch5_land_ranged_hit() -> void:
	if not _ch5_ranged_contact_pending:
		return
	_ch5_ranged_contact_pending = false
	var move := _signature_move
	if move == null:
		return
	var tint := move.effect_color
	_react_room(tint, 7.0 if _enemy.is_boss else 4.0)
	if Audio.has_move_sfx(move.signature_id(), "hit"):
		Audio.play_move_sfx(move.signature_id(), "hit")
	else:
		Audio.play_sfx("attack_impact")
	_shake_screen(2.5)
	_fx_flash(tint, 0.16)
	_fx_ring(player_character, tint, 48.0, 0.20)
	word_preview_label.text = "%s hits! -%d HP" % [move.move_name, _ch5_ranged_damage]
	if _ch5_ranged_damage > 0:
		_player_hp = maxi(0, _player_hp - _ch5_ranged_damage)
		player_heart_row.set_value(_player_hp)
		Audio.play_sfx("player_hurt")
		player_character.play_hit()

func _ch5_finish_turn() -> void:
	if not _ch5_final_reading_active:
		return
	_ch5_final_reading_turns = maxi(0, _ch5_final_reading_turns - 1)
	if _ch5_final_reading_turns == 0:
		_ch5_final_reading_active = false
		if is_instance_valid(_ch5_chamber): _ch5_chamber.set_stage(1)
		_fx_word("FINAL READING COMPLETE", enemy_character, _ch5_gold(), 20.0, 0.0, 10)
## The turn the boss last raised Speaker's Shield, or -1. Read by
## _ch5_guard_on_cooldown; reset with the encounter.
var _ch5_last_guard_turn: int = -1

## Whether `move` is the Chapter 5 boss's shield and he used it last turn.
## "No shield spam", scoped as narrowly as Chapter 4's equivalent.
func _ch5_guard_on_cooldown(move: EnemyMove) -> bool:
	if move == null or _enemy == null:
		return false
	if move.signature_id() not in ["c5combat_speakers_shield", "c5combat_quorum_escape"]:
		return false
	return _ch5_last_guard_turn >= 0 and _move_index - _ch5_last_guard_turn <= 1

## How much harder the Chapter 5 boss hits, by stage. Phase 2 and FINAL READING
## stack deliberately: the closing stage is meant to be the hardest the game
## ever gets, and it is still only a fifth above phase 2.
func _ch5_damage_gain(move_id: String) -> float:
	if _enemy == null or not _enemy.is_boss or not move_id.begins_with("c5combat_"):
		return 1.0
	var gain := 1.0
	if _boss_phase >= 2:
		gain *= CH5_PHASE2_DAMAGE_GAIN
	if _ch5_final_reading_active:
		gain *= CH5_FINAL_READING_GAIN
	return gain

## Fires the closing stage the first time the boss falls into the last quarter.
## Returns true if it ran, so the caller knows a beat has been spent.
##
## Deliberately NOT a heal. The brief asks for a climax, not a second health
## bar, so nothing here touches _enemy_hp -- what changes is speed, damage and
## how loud the room is.
func _ch5_try_final_reading() -> bool:
	if _ch5_final_reading_used or _enemy == null or not _enemy.is_boss:
		return false
	if _enemy.moves.is_empty() or not _enemy.moves[0].signature_id().begins_with("c5combat_"):
		return false
	if _enemy_hp <= 0:
		return false
	var fraction := float(_enemy_hp) / float(maxi(1, _enemy.max_hp))
	if fraction > CH5_FINAL_READING_AT:
		return false
	_ch5_final_reading_used = true
	_ch5_final_reading_active = true
	_ch5_final_reading_turns = 3
	if is_instance_valid(_ch5_chamber): _ch5_chamber.set_stage(2)
	await _play_ch5_final_reading()
	return true

## He raises the bill, the chamber dims, the bell goes, and the last stage of
## the last fight in the game begins.
func _play_ch5_final_reading() -> void:
	_sequence_running = true
	_update_action_buttons()

	# The room drops away.
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.04, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.offset_right = Layout.profile.design_size.x
	veil.offset_bottom = Layout.profile.design_size.y
	_fx_node(veil, 2.4)
	var dim := create_tween()
	dim.tween_property(veil, "color:a", 0.62, 0.28)
	await dim.finished

	# The bill goes up.
	Audio.play_sfx("attack_impact")
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(0, 4, 0, 1.0, 0.97, 0.16, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_beat(0, -10, 0, 0.98, 1.10, 0.30, Tween.TRANS_BACK, Tween.EASE_OUT),
	])
	_fx_paper(Vector2(52, 40), Color(1.0, 0.88, 0.52, 0.98), 0.06, 0.0, 0.0, -54.0)
	# The voting symbols come up around the arena.
	for i in 6:
		_fx_ring(enemy_character, Color(1.0, 0.84, 0.36, 0.9),
			60.0 + float(i) * 22.0, 0.5, float(i) * 0.05)
	_fx_word("FINAL READING", enemy_character, Color(1.0, 0.90, 0.50), 36.0, 0.0, 18)
	_fx_flash(Color(1.0, 0.80, 0.34), 0.5)
	_shake_screen(8.0)
	await get_tree().create_timer(0.7).timeout

	await _body_play(enemy_character, [_beat(0, 0, 0, 1.0, 1.0, 0.18)])
	await _body_end(enemy_character)
	var lift := create_tween()
	lift.tween_property(veil, "color:a", 0.0, 0.4)
	word_preview_label.text = "%s calls the final reading." % _enemy.enemy_name
	await get_tree().create_timer(0.4).timeout

	_sequence_running = false
	_update_action_buttons()

## Plays the Chapter 5 boss's defeat sequence, and nothing at all for anyone
## else. Matched on the move id rather than the name, so renaming the character
## cannot silently skip his send-off.
func _ch5_boss_defeat_if_due() -> void:
	if _enemy == null or not _enemy.is_boss or _enemy.moves.is_empty():
		return
	if not _enemy.moves[0].signature_id().begins_with("c5combat_"):
		return
	await _play_ch5_boss_defeat()

## The last defeat in the game. Played instead of cutting straight to the
## victory screen, because the brief asks for it to be dignified: the gavel
## goes first, then the board, then the man.
func _play_ch5_boss_defeat() -> void:
	if is_instance_valid(_ch5_chamber): _ch5_chamber.stop()
	_sequence_running = true
	_update_action_buttons()

	# The final hit has landed. He takes it standing, then does not.
	_body_begin(enemy_character, BODY_FEET)
	await _body_play(enemy_character, [
		_beat(6, -3, 4, 1.0, 1.0, 0.14, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	# The gavel slips, and hits the floor.
	var gavel := _ch3_prop(Color(0.52, 0.34, 0.17, 1.0), Vector2(13, 34), 4)
	_ch3_prop_arc(gavel, -6.0, 54.0, -120.0, 0.34, false)
	await get_tree().create_timer(0.34).timeout
	Audio.play_sfx("attack_impact")
	_shake_screen(3.0)
	_fx_splatter(enemy_character, Color(0.52, 0.34, 0.17, 0.9), 5, 16.0, 0.32)

	# The board powers down and the papers lose their lift.
	for i in 3:
		_fx_paper(Vector2(18, 13), Color(0.90, 0.88, 0.82, 0.75), 0.16,
			float(i) * 0.07, float(i - 1) * 22.0, 34.0)
	await get_tree().create_timer(0.30).timeout

	# He takes the stand for support rather than falling.
	await _body_play(enemy_character, [
		_beat(4, 8, 3, 1.01, 0.92, 0.30, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_beat(2, 13, 5, 1.02, 0.86, 0.26, Tween.TRANS_SINE, Tween.EASE_OUT),
	])
	# The chamber lights come back to neutral.
	_fx_flash(Color(0.96, 0.94, 0.88, 0.30), 0.55)
	var settle := create_tween()
	settle.tween_property(gavel, "modulate:a", 0.0, 0.5)
	word_preview_label.text = "The session is adjourned."
	await get_tree().create_timer(0.85).timeout
	await _body_end(enemy_character)

	_sequence_running = false
	_update_action_buttons()
