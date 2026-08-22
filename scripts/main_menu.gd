extends Control
class_name MainMenu
## Title screen and entry point. Everything past the title — the chapter map,
## difficulty pick, Options and Credits — is an overlay panel rather than a
## separate scene, so the menu never loses its background or music.
##
## The route into a run is: PLAY -> chapter map -> chapter 1 -> difficulty.
## The map stays visible underneath the difficulty panel, so backing out of
## difficulty returns to the map rather than all the way to the title.

const BATTLE_SCENE := "res://scenes/word_battle.tscn"
## Only chapter 1 exists so far; the rest are drawn locked and answer with a
## notice. Raising this is all that is needed once chapter 2 ships.
const UNLOCKED_CHAPTERS := 1
const TOTAL_CHAPTERS := 5
## How long the "AVAILABLE SOON!" notice stays up before fading itself out.
const TOAST_HOLD := 1.3
const TOAST_FADE := 0.35

## Short names for the reviewer's chapter tabs. The map pins in main_menu.tscn
## carry the long titles; these are the abbreviations that fit five across.
const CHAPTER_TABS := {
	1: "BARANGAY", 2: "CITY HALL", 3: "PROVINCE", 4: "MALACAÑANG", 5: "KONGRESO",
}
const CHAPTER_TITLES := {
	1: "Barangay Beginnings", 2: "City Hall Shadows", 3: "Provincial Circuit",
	4: "Malacañang", 5: "Kongreso",
}
## The four content areas questions are tagged with, in the reviewer's own
## words rather than the bank's internal keys.
const CATEGORY_TABS := {
	"voting": "VOTING", "fraud": "FRAUD", "candidate": "CANDIDATES", "why": "WHY VOTE",
}
const CATEGORY_COLORS := {
	"voting": "6fc9a8", "fraud": "e59289", "candidate": "c9a2d8", "why": "8fb8dd",
}
const DIFFICULTY_COLORS := {
	"easy": "93d18d", "medium": "e5c473", "hard": "e59289",
}
## Static flavour for each tier. The example words that used to sit here were
## hard-coded and went stale the moment the question bank was rewritten, so the
## examples are now read from the bank itself — see _example_answers().
const DIFFICULTY_BLURB := {
	"easy": "Short, everyday words",
	"medium": "Real election terms",
	"hard": "Long civics words",
}
## Row heights for the reviewer's tab strips, and how wide an entry may run
## before it wraps. The wrap width has to be set explicitly: a RichTextLabel
## left to guess reports its height as if every word were on its own line.
const REVIEWER_ENTRY_WIDTH := 556.0

## Which chapter unlocks the certificate. Chapter 1 only, matching
## UNLOCKED_CHAPTERS — there is only one chapter to complete anyway, but this
## names the requirement rather than leaving a bare "1" in the unlock check.
const CERTIFICATE_CHAPTER := 1
## Master switch. While true the certificate is locked for everyone regardless
## of progress — a finished chapter 1 no longer unlocks it. Flip to false to
## hand the feature back to the ordinary chapter gate above; nothing else needs
## changing, because both the panel and the claim handler ask
## _certificate_unlocked() rather than testing the chapter themselves.
const CERTIFICATE_LOCKED := false
## One template image, not a PDF: the engine has no PDF writer, but it can
## render text onto an image and save that, which is also just an easier thing
## for a player to open and print.
const CERTIFICATE_TEMPLATE_PATH := "res://assets/certificate/certificate_template.png"
## Filename the generated certificate is written out as. Desktop platforms
## need a real file to hand to the OS; the packed res:// path only exists
## inside the game's virtual filesystem.
const CERTIFICATE_EXPORT_FILENAME := "kaalaman_sa_halalan_certificate.png"
## The template's own signature line ("Atty. Keinth L. Horario") uses a bold
## serif — TitanOne (the game's own UI font, a bold rounded display face)
## would clash badly with that on this navy-and-gold formal design, so the
## printed name gets its own font instead.
const CERTIFICATE_NAME_FONT_PATH := "res://assets/fonts/PlayfairDisplay-Variable.ttf"
const CERTIFICATE_NAME_FONT_WEIGHT := 700.0
## Where the player's name is centred on the template, and how wide it is
## allowed to run, both as a fraction of the template's own size so the layout
## holds regardless of what resolution the art gets re-exported at. Measured
## directly against certificate_template.png: the blank signature line sits at
## y=849/1414 (0.600) spanning x=404-1595/2000 (centred, 0.596 wide); the name
## is placed just above that line rather than centred in the large blank
## gap above it, the way a signature sits on its line.
const CERTIFICATE_NAME_Y_FRACTION := 0.555
const CERTIFICATE_NAME_WIDTH_FRACTION := 0.55
const CERTIFICATE_NAME_FONT_FRACTION := 0.03
const CERTIFICATE_NAME_MAX_LENGTH := 40

## Bottom of the PLAY/REVIEWER/.../QUIT stack, held fixed as buttons are added
## — matches the scene's original offset_bottom for the 4-button menu.
const MENU_STACK_BOTTOM := 434.0
## The stack must never grow above this, or it starts overlapping the
## "I am aware." subtitle banner (which ends at y=138 in main_menu.tscn).
const MENU_STACK_SAFE_TOP := 144.0

@onready var play_button: Button = $Menu/PlayButton
@onready var options_button: Button = $Menu/OptionsButton
@onready var credits_button: Button = $Menu/CreditsButton
@onready var quit_button: Button = $Menu/QuitButton
@onready var credits_panel: PanelContainer = $CreditsPanel
@onready var character_panel: PanelContainer = $CharacterPanel
@onready var male_button: Button = $CharacterPanel/VBox/ButtonRow/MaleButton
@onready var female_button: Button = $CharacterPanel/VBox/ButtonRow/FemaleButton
@onready var male_preview: AnimatedCharacter = $CharacterPanel/VBox/PreviewRow/MalePreview
@onready var female_preview: AnimatedCharacter = $CharacterPanel/VBox/PreviewRow/FemalePreview
@onready var character_back_button: Button = $CharacterPanel/VBox/BackButton
@onready var title_character: AnimatedCharacter = $PlayerCharacter
@onready var difficulty_panel: PanelContainer = $DifficultyPanel
@onready var easy_button: Button = $DifficultyPanel/VBox/EasyButton
@onready var medium_button: Button = $DifficultyPanel/VBox/MediumButton
@onready var hard_button: Button = $DifficultyPanel/VBox/HardButton
@onready var difficulty_back_button: Button = $DifficultyPanel/VBox/BackButton
@onready var credits_close_button: Button = $CreditsPanel/VBox/CloseButton
@onready var map_panel: Control = $MapPanel
@onready var map_back_button: Button = $MapPanel/MapBackButton
@onready var soon_toast: PanelContainer = $MapPanel/SoonToast

## Tracked so a second click restarts the notice cleanly instead of two fades
## fighting over the same node.
var _toast_tween: Tween
## Browsers refuse to play any audio on a page until the user has interacted
## with it at least once — a title screen that calls play_music() straight
## from _ready() gets silently muted on the web export, with no error. This
## flag makes sure the very first play_music call happens strictly after a
## real click, tap, or key press, so the browser never has cause to block it.
## Desktop builds are unaffected; this restriction is web-only, but gating it
## here costs nothing on desktop either.
var _music_started: bool = false

## The reviewer is built in code rather than added to main_menu.tscn on disk.
## The editor silently overwrites scene-file edits when it has that scene open,
## and this is a large subtree to lose; building it here also keeps the whole
## screen in one readable place instead of split across a .tscn.
var _reviewer_panel: PanelContainer
var _reviewer_entries: VBoxContainer
var _reviewer_count: Label
var _reviewer_chapter_tabs: Dictionary = {}
var _reviewer_difficulty_tabs: Dictionary = {}
var _reviewer_category_tabs: Dictionary = {}
## Current reviewer filters. Chapter is always a real chapter — there is no
## "all chapters" view, which keeps the rebuilt list to at most one chapter's
## worth of nodes. "" means no filter on the other two axes.
var _reviewer_chapter: int = 1
var _reviewer_difficulty: String = ""
var _reviewer_category: String = ""

## Same reasoning as the reviewer panel: built in code so a scene reload in
## the editor can never silently drop it.
var _certificate_panel: PanelContainer
var _certificate_column: VBoxContainer
## Options is built in code rather than in the scene, the same as the reviewer
## and certificate panels: it needs per-row layout and live value readouts that
## are far easier to keep aligned here than in a .tscn.
var options_panel: SettingsPanel
## Convenience handles onto the shared panel's own sliders.
var music_slider: HSlider
var sfx_slider: HSlider

var _certificate_status_label: Label
var _certificate_name_input: LineEdit
var _certificate_claim_button: Button

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	credits_close_button.pressed.connect(_on_close_panels)
	easy_button.pressed.connect(_start_run.bind("easy"))
	medium_button.pressed.connect(_start_run.bind("medium"))
	hard_button.pressed.connect(_start_run.bind("hard"))
	difficulty_back_button.pressed.connect(_on_difficulty_back_pressed)
	map_back_button.pressed.connect(_on_map_back_pressed)
	male_button.pressed.connect(_on_character_chosen.bind("male"))
	female_button.pressed.connect(_on_character_chosen.bind("female"))
	character_back_button.pressed.connect(_on_character_back_pressed)
	_connect_chapter_pins()
	# Built before the hides below, not after: options_panel does not exist
	# until its builder runs, and the scene-defined panels are the only ones
	# that can be hidden by name up here. The builder hides its own panel, the
	# same way the reviewer and certificate builders do.
	_build_options()
	credits_panel.hide()
	difficulty_panel.hide()
	map_panel.hide()
	character_panel.hide()
	soon_toast.hide()
	_apply_difficulty_hints()
	_build_reviewer()
	_build_certificate()
	# The title screen shows whoever is currently selected, so the choice is
	# visible from the moment it is made rather than only once battle starts.
	title_character.configure_clips(GameState.character_clips())

## Wired by index rather than one handler per pin, so adding chapter 6 means
## adding a node and bumping TOTAL_CHAPTERS — no new signal code.
func _connect_chapter_pins() -> void:
	for i in range(1, TOTAL_CHAPTERS + 1):
		var pin := map_panel.get_node_or_null("Chapter%dButton" % i) as Button
		if pin == null:
			push_warning("MainMenu: no map pin for chapter %d" % i)
			continue
		pin.pressed.connect(_on_chapter_pressed.bind(i))

## Starts the title music on the first real interaction of any kind, anywhere
## on the page — not just a press of one of our own buttons. A button click
## would also satisfy the browser, but gating on *any* input means someone who
## presses a key or taps blank space first still gets music immediately,
## instead of waiting until they happen to hit a button.
func _input(event: InputEvent) -> void:
	if _music_started:
		return
	var is_gesture := false
	if event is InputEventMouseButton:
		is_gesture = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		is_gesture = (event as InputEventScreenTouch).pressed
	elif event is InputEventKey:
		is_gesture = (event as InputEventKey).pressed
	if not is_gesture:
		return
	_music_started = true
	Audio.play_music("battle")

## Play opens the chapter map first — picking where you are going comes before
## picking how hard it will be.
func _on_play_pressed() -> void:
	Audio.play_sfx("button_click")
	options_panel.hide()
	credits_panel.hide()
	difficulty_panel.hide()
	character_panel.hide()
	_reviewer_panel.hide()
	_certificate_panel.hide()
	map_panel.show()

func _on_chapter_pressed(chapter: int) -> void:
	if chapter > UNLOCKED_CHAPTERS:
		Audio.play_sfx("word_rejected")
		_show_soon_toast()
		return
	Audio.play_sfx("button_click")
	character_panel.show()

## A self-dismissing notice, so a locked chapter never traps the player behind
## a dialog they have to close.
func _show_soon_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	soon_toast.modulate.a = 1.0
	soon_toast.show()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(soon_toast, "modulate:a", 0.0, TOAST_FADE)
	_toast_tween.tween_callback(soon_toast.hide)

## Picking a character records it and moves on to difficulty. The choice is
## cosmetic — GameState.PLAYER_CHARACTERS gives both identical clip counts — so
## nothing downstream needs to branch on it.
func _on_character_chosen(character: String) -> void:
	Audio.play_sfx("button_click")
	GameState.character = character
	title_character.configure_clips(GameState.character_clips())
	character_panel.hide()
	difficulty_panel.show()

func _on_character_back_pressed() -> void:
	Audio.play_sfx("button_click")
	character_panel.hide()

## Difficulty is recorded on GameState rather than pushed into QuestionBank
## here, because it belongs to the run: the battle scene re-applies it on load,
## so it survives Try Again without the menu being involved.
func _start_run(difficulty: String) -> void:
	Audio.play_sfx("button_click")
	GameState.difficulty = difficulty
	GameState.reset_chapter()
	get_tree().change_scene_to_file(BATTLE_SCENE)

## Each Back step retraces exactly one step of the route in
## (map -> character -> difficulty), rather than dumping the player at the
## title from wherever they happen to be.
func _on_difficulty_back_pressed() -> void:
	Audio.play_sfx("button_click")
	difficulty_panel.hide()
	character_panel.show()

func _on_map_back_pressed() -> void:
	Audio.play_sfx("button_click")
	difficulty_panel.hide()
	character_panel.hide()
	map_panel.hide()

func _on_options_pressed() -> void:
	Audio.play_sfx("button_click")
	credits_panel.hide()
	difficulty_panel.hide()
	character_panel.hide()
	map_panel.hide()
	_reviewer_panel.hide()
	_certificate_panel.hide()
	options_panel.pop_open()

func _on_credits_pressed() -> void:
	Audio.play_sfx("button_click")
	options_panel.hide()
	difficulty_panel.hide()
	character_panel.hide()
	map_panel.hide()
	_reviewer_panel.hide()
	_certificate_panel.hide()
	credits_panel.show()

func _on_close_panels() -> void:
	Audio.play_sfx("button_click")
	options_panel.hide()
	credits_panel.hide()

func _on_quit_pressed() -> void:
	Audio.play_sfx("button_click")
	get_tree().quit()

# --------------------------------------------------------------------------
# Difficulty hints
# --------------------------------------------------------------------------

## Writes the line under each difficulty button: what the words are like, how
## long the clock runs, and two real answers from that tier.
##
## Done here rather than as fixed text in the scene for two reasons. The clock
## is quoted from the same table the battle scene counts down from, so the
## promise cannot drift from the timer. And the example words are read out of
## the question bank, so rewriting the bank can never again leave the menu
## advertising words the game no longer asks about.
func _apply_difficulty_hints() -> void:
	var chapter_no := GameState.chapter_number()
	for tier in ["easy", "medium", "hard"]:
		var label := difficulty_panel.get_node_or_null("VBox/%sHint" % tier.capitalize()) as Label
		if label == null:
			push_warning("MainMenu: no hint label for '%s' difficulty" % tier)
			continue
		var seconds := int(round(GameState.question_seconds(tier)))
		# The clock gets its own line, in caps, above the flavour: it is the one
		# thing here a player needs before committing to a tier, and it was
		# unreadable when run together with the description on a single line.
		var detail: Array[String] = [String(DIFFICULTY_BLURB.get(tier, ""))]
		var examples := _example_answers(chapter_no, tier, 2)
		if not examples.is_empty():
			detail.append(", ".join(examples))
		label.text = "%d SECONDS PER QUESTION\n%s" % [seconds, "  ·  ".join(detail)]
	_fit_difficulty_panel()

## Grows the difficulty panel to whatever its two-line hints actually need,
## keeping it centred. Its height is set in the scene for single-line hints, and
## a PanelContainer does not shrink its children to fit — they would simply
## spill past the frame.
func _fit_difficulty_panel() -> void:
	var column := difficulty_panel.get_node_or_null("VBox") as VBoxContainer
	if column == null:
		return
	var needed: float = column.get_combined_minimum_size().y + 16.0
	if needed <= difficulty_panel.size.y:
		return
	var centre: float = difficulty_panel.offset_top + difficulty_panel.size.y * 0.5
	difficulty_panel.offset_top = centre - needed * 0.5
	difficulty_panel.offset_bottom = difficulty_panel.offset_top + needed

## A couple of representative answers from one pool, for the difficulty hint.
##
## Picks the words whose length sits closest to that pool's median, so the
## examples read as typical of the tier rather than as its easiest or most
## punishing outliers. Multi-word terms are skipped: run together for the board
## (SANGGUNIANGBARANGAY) they look like a mistake out of context.
func _example_answers(chapter_no: int, tier: String, wanted: int) -> Array[String]:
	var pool := QuestionBank.entries_for(chapter_no, tier)
	var single_words: Array[String] = []
	for entry in pool:
		var answer := String(entry.get("answer", ""))
		if answer.is_empty() or String(entry.get("display", answer)) != answer:
			continue
		if not single_words.has(answer):
			single_words.append(answer)
	if single_words.is_empty():
		return []
	var lengths: Array[int] = []
	for word in single_words:
		lengths.append(word.length())
	lengths.sort()
	# Truncating is the point: for an even count either middle element is an
	# equally good centre to sort distance from.
	@warning_ignore("integer_division")
	var median: int = lengths[lengths.size() / 2]
	single_words.sort_custom(func(a: String, b: String) -> bool:
		var da := absi(a.length() - median)
		var db := absi(b.length() - median)
		if da == db:
			return a < b
		return da < db)
	return single_words.slice(0, mini(wanted, single_words.size()))

# --------------------------------------------------------------------------
# Reviewer
# --------------------------------------------------------------------------

## The reviewer is a study screen: every question in the game with its answer,
## filtered by chapter, difficulty and content area. It reads the same bank the
## battle scene plays from, so it can never show questions the game does not ask.
func _build_reviewer() -> void:
	_add_reviewer_menu_button()

	_reviewer_panel = PanelContainer.new()
	_reviewer_panel.name = "ReviewerPanel"
	_reviewer_panel.add_theme_stylebox_override("panel", _overlay_style())
	_reviewer_panel.offset_left = 16.0
	_reviewer_panel.offset_top = 12.0
	_reviewer_panel.offset_right = 624.0
	_reviewer_panel.offset_bottom = 468.0
	_reviewer_panel.hide()
	add_child(_reviewer_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	_reviewer_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	margin.add_child(column)

	var title := Label.new()
	title.text = "REVIEWER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/TitanOne-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Every question in the game, with its answer."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.72, 0.58))
	column.add_child(subtitle)

	# Only chapters the player can actually reach get a tab. QuestionBank holds
	# data for all five (chapters 2-5 were written ahead of the content that
	# unlocks them), but a reviewer entry for a chapter nobody can play would
	# just be confusing. Reusing UNLOCKED_CHAPTERS means this needs no changes
	# when chapter 2 ships — it gains a tab the same moment its map pin opens.
	var chapter_row := _add_tab_row(column, "CHAPTER")
	for chapter_no in QuestionBank.chapters_available():
		if int(chapter_no) > UNLOCKED_CHAPTERS:
			continue
		var tab := _make_tab(String(CHAPTER_TABS.get(chapter_no, "CH %d" % chapter_no)))
		tab.pressed.connect(_on_reviewer_chapter_selected.bind(int(chapter_no)))
		chapter_row.add_child(tab)
		_reviewer_chapter_tabs[int(chapter_no)] = tab

	var difficulty_row := _add_tab_row(column, "LEVEL")
	_add_filter_tab(difficulty_row, _reviewer_difficulty_tabs, "", "ALL", _on_reviewer_difficulty_selected)
	for tier in ["easy", "medium", "hard"]:
		_add_filter_tab(difficulty_row, _reviewer_difficulty_tabs, tier, tier.to_upper(),
			_on_reviewer_difficulty_selected)

	var category_row := _add_tab_row(column, "TOPIC")
	_add_filter_tab(category_row, _reviewer_category_tabs, "", "ALL", _on_reviewer_category_selected)
	for key in ["voting", "fraud", "candidate", "why"]:
		_add_filter_tab(category_row, _reviewer_category_tabs, key, String(CATEGORY_TABS[key]),
			_on_reviewer_category_selected)

	_reviewer_count = Label.new()
	_reviewer_count.add_theme_font_size_override("font_size", 10)
	_reviewer_count.add_theme_color_override("font_color", Color(0.72, 0.66, 0.52))
	column.add_child(_reviewer_count)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_reviewer_entries = VBoxContainer.new()
	_reviewer_entries.add_theme_constant_override("separation", 7)
	_reviewer_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_reviewer_entries)

	var close := SettingsPanel.make_back_button(_on_reviewer_close_pressed)
	column.add_child(close)

	_refresh_reviewer()


# --- options panel ---------------------------------------------------------

## Panel geometry, in the 640x480 viewport the game is authored at. Narrower
## than the old 340px panel on purpose: this sits over the title art, and the
## menu behind it should stay readable.
const OPTIONS_PANEL_RECT := Rect2(176.0, 158.0, 288.0, 168.0)

## The panel itself is SettingsPanel, shared with the battle scene's pause
## menu. Only its placement lives here -- the styling, the sliders and the Back
## button all belong to the shared component, so the two screens cannot drift
## into looking like different settings systems.
func _build_options() -> void:
	options_panel = SettingsPanel.new()
	options_panel.name = "OptionsPanel"
	options_panel.offset_left = OPTIONS_PANEL_RECT.position.x
	options_panel.offset_top = OPTIONS_PANEL_RECT.position.y
	options_panel.offset_right = OPTIONS_PANEL_RECT.position.x + OPTIONS_PANEL_RECT.size.x
	options_panel.offset_bottom = OPTIONS_PANEL_RECT.position.y + OPTIONS_PANEL_RECT.size.y
	options_panel.size = OPTIONS_PANEL_RECT.size
	add_child(options_panel)
	options_panel.build(_on_close_panels)
	options_panel.hide()
	music_slider = options_panel.music_slider
	sfx_slider = options_panel.sfx_slider

## Slots a REVIEWER button into the existing menu stack, directly under PLAY —
## it belongs with playing, not with the Options/Credits housekeeping below it.
func _add_reviewer_menu_button() -> void:
	var button := _insert_menu_button("ReviewerButton", "REVIEWER", Color(0.95, 0.82, 1), play_button)
	if button != null:
		button.pressed.connect(_on_reviewer_pressed)

## Slots a CERTIFICATE button directly under REVIEWER. Order in the stack
## mirrors the order a player actually reaches these: play, review what you
## missed, then come back for the certificate once chapter 1 is beaten.
func _add_certificate_menu_button() -> void:
	var reviewer_button := get_node_or_null("Menu/ReviewerButton") as Button
	var button := _insert_menu_button(
		"CertificateButton", "CERTIFICATE", Color(1, 0.88, 0.55), reviewer_button if reviewer_button != null else play_button)
	if button != null:
		button.pressed.connect(_on_certificate_pressed)

## Adds one button to the PLAY/REVIEWER/.../QUIT stack, positioned right after
## `after`, and grows the stack to fit. Shared by REVIEWER and CERTIFICATE so
## both get identical styling (borrowed from PLAY's own stylebox) instead of
## two near-duplicate blocks that could quietly drift apart.
func _insert_menu_button(button_name: String, text: String, color: Color, after: Button) -> Button:
	var menu := play_button.get_parent() as VBoxContainer
	if menu == null:
		push_warning("MainMenu: PLAY has no menu container, skipping %s button" % text)
		return null
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.self_modulate = color
	button.custom_minimum_size = play_button.custom_minimum_size
	button.add_theme_font_override("font", load("res://assets/fonts/TitanOne-Regular.ttf"))
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color(0.2, 0.11, 0.05))
	for state in ["normal", "pressed", "hover", "focus"]:
		var style := play_button.get_theme_stylebox(state)
		if style != null:
			button.add_theme_stylebox_override(state, style)
	menu.add_child(button)
	menu.move_child(button, after.get_index() + 1)
	_grow_menu_stack(menu)
	return button

## A VBoxContainer honours its children's minimum sizes and does not shrink
## them to fit its own box — so every time a button is appended, the stack has
## to be told to grow. It grows upward first (bottom stays put, matching the
## scene's original layout), but only up to MENU_STACK_SAFE_TOP: past four or
## five buttons there just isn't room to keep every button at PLAY's height
## without colliding with the title art above, so beyond that point every
## button in the stack — not just the new one — shrinks together to keep the
## whole stack legible rather than letting it overrun its ceiling.
func _grow_menu_stack(menu: VBoxContainer) -> void:
	var count := menu.get_child_count()
	var separation := menu.get_theme_constant("separation")
	var available: float = MENU_STACK_BOTTOM - MENU_STACK_SAFE_TOP
	var default_height: float = maxf(play_button.custom_minimum_size.y, 1.0)
	var fitted_height: float = (available - separation * (count - 1)) / float(count)
	var button_height: float = clampf(fitted_height, 30.0, default_height)
	for child in menu.get_children():
		if child is Button:
			(child as Button).custom_minimum_size.y = button_height
	var needed := button_height * count + separation * (count - 1)
	menu.offset_top = MENU_STACK_BOTTOM - needed
	menu.offset_bottom = MENU_STACK_BOTTOM

## One labelled strip of filter tabs, returned empty for the caller to fill.
##
## The row is deliberately kept out of the tabs dictionary that goes with it:
## chapter tabs are keyed by int, and a stray String key in the same dictionary
## makes the selected-tab comparison a type error rather than a false.
func _add_tab_row(column: VBoxContainer, heading: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	column.add_child(row)

	var label := Label.new()
	label.text = heading
	label.custom_minimum_size = Vector2(52, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.44))
	row.add_child(label)

	return row

func _add_filter_tab(row: HBoxContainer, tabs: Dictionary, value: String, text: String,
		handler: Callable) -> void:
	var tab := _make_tab(text)
	tab.pressed.connect(handler.bind(value))
	row.add_child(tab)
	tabs[value] = tab

func _make_tab(text: String) -> Button:
	var tab := Button.new()
	tab.text = text
	tab.custom_minimum_size = Vector2(0, 19)
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.add_theme_font_size_override("font_size", 9)
	return tab

## Repaints a strip so exactly one tab reads as chosen. Style is applied per
## tab on every refresh rather than toggled, so a tab can never be left showing
## the previous selection's colours.
func _paint_tabs(tabs: Dictionary, selected: Variant) -> void:
	for key in tabs:
		var tab := tabs[key] as Button
		var is_selected: bool = key == selected
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.72, 0.56, 0.22, 1.0) if is_selected else Color(0.19, 0.14, 0.09, 0.9)
		style.set_border_width_all(1)
		style.border_color = Color(0.72, 0.56, 0.22, 0.9) if is_selected else Color(0.42, 0.34, 0.22, 0.8)
		style.set_corner_radius_all(2)
		style.content_margin_left = 4
		style.content_margin_right = 4
		for state in ["normal", "pressed", "hover", "focus"]:
			tab.add_theme_stylebox_override(state, style)
		tab.add_theme_color_override(
			"font_color", Color(0.16, 0.1, 0.04) if is_selected else Color(0.8, 0.74, 0.6))

func _overlay_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.06, 0.04, 0.97)
	style.set_border_width_all(5)
	style.border_color = Color(0.72, 0.56, 0.22)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 8
	style.shadow_offset = Vector2(3, 4)
	return style

## Redraws the entry list for the current filters. Every entry is one
## RichTextLabel rather than a row of separate labels — a third of the node
## count, and the colouring is markup instead of layout.
func _refresh_reviewer() -> void:
	_paint_tabs(_reviewer_chapter_tabs, _reviewer_chapter)
	_paint_tabs(_reviewer_difficulty_tabs, _reviewer_difficulty)
	_paint_tabs(_reviewer_category_tabs, _reviewer_category)

	for child in _reviewer_entries.get_children():
		child.queue_free()

	var tiers := ["easy", "medium", "hard"] if _reviewer_difficulty.is_empty() else [_reviewer_difficulty]
	var shown := 0
	for tier in tiers:
		var pool := QuestionBank.entries_for(_reviewer_chapter, tier)
		if not _reviewer_category.is_empty():
			pool = pool.filter(func(e: Dictionary) -> bool:
				return String(e.get("category", "")) == _reviewer_category)
		if pool.is_empty():
			continue
		# Alphabetical by answer, so the list reads like a glossary and a term
		# is findable without remembering how its question was worded.
		pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return String(a.get("display", a.get("answer", ""))) < String(b.get("display", b.get("answer", ""))))
		_reviewer_entries.add_child(_make_tier_heading(tier, pool.size()))
		for entry in pool:
			_reviewer_entries.add_child(_make_entry_label(entry))
			shown += 1

	if shown == 0:
		var empty := Label.new()
		empty.text = "No questions match this combination."
		empty.add_theme_font_size_override("font_size", 11)
		empty.add_theme_color_override("font_color", Color(0.6, 0.55, 0.44))
		_reviewer_entries.add_child(empty)

	_reviewer_count.text = "%s  —  %d question%s" % [
		String(CHAPTER_TITLES.get(_reviewer_chapter, "Chapter %d" % _reviewer_chapter)),
		shown,
		"" if shown == 1 else "s",
	]

func _make_tier_heading(tier: String, count: int) -> RichTextLabel:
	var heading := RichTextLabel.new()
	heading.bbcode_enabled = true
	heading.fit_content = true
	heading.scroll_active = false
	heading.custom_minimum_size = Vector2(REVIEWER_ENTRY_WIDTH, 0)
	heading.add_theme_font_size_override("normal_font_size", 10)
	heading.add_theme_font_size_override("bold_font_size", 13)
	heading.text = "[color=#%s][b]%s[/b][/color]  [color=#6b6252]%d[/color]" % [
		String(DIFFICULTY_COLORS.get(tier, "cccccc")), tier.to_upper(), count,
	]
	return heading

## One reviewer entry: the answer as a headword, the question it answers, and
## — where the two differ — how the answer must actually be spelled on the
## board. That last line matters: better than a quarter of chapter one's
## answers are multi-word terms whose spaces vanish on a tile board, which is
## a poor thing to discover mid-fight with the clock running.
func _make_entry_label(entry: Dictionary) -> RichTextLabel:
	var answer := String(entry.get("answer", ""))
	var display := String(entry.get("display", answer))
	var category := String(entry.get("category", ""))

	var head := "[color=#f0cf7a][b]%s[/b][/color]" % display
	if not category.is_empty():
		head += "  [color=#%s]%s[/color]" % [
			String(CATEGORY_COLORS.get(category, "999999")),
			String(CATEGORY_TABS.get(category, category)).to_lower(),
		]
	if display != answer:
		head += "  [color=#6b6252]spelled %s[/color]" % answer

	var question := String(entry.get("prompt", "")).replace("___", "[color=#a08b55]____[/color]")
	var lines := "%s\n[color=#cfc6b2]%s[/color]" % [head, question]

	# The fact is the line shown after a correct answer. In chapters where it
	# just restates the completed question there is nothing to add, so it is
	# only printed when it genuinely carries something extra.
	var fact := String(entry.get("fact", ""))
	var completed := String(entry.get("prompt", "")).replace("___", display)
	if not fact.is_empty() and fact.to_lower() != completed.to_lower():
		lines += "\n[color=#8f8770][i]%s[/i][/color]" % fact

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(REVIEWER_ENTRY_WIDTH, 0)
	# Sized deliberately rather than left to the theme: the headword is bold and
	# would otherwise inherit a much larger default, making each entry tall
	# enough that only a handful fit on screen at once.
	label.add_theme_font_size_override("bold_font_size", 13)
	label.add_theme_font_size_override("normal_font_size", 10)
	label.add_theme_font_size_override("italics_font_size", 10)
	label.text = lines
	return label

func _on_reviewer_chapter_selected(chapter_no: int) -> void:
	Audio.play_sfx("tile_tap")
	_reviewer_chapter = chapter_no
	_refresh_reviewer()

func _on_reviewer_difficulty_selected(tier: String) -> void:
	Audio.play_sfx("tile_tap")
	_reviewer_difficulty = tier
	_refresh_reviewer()

func _on_reviewer_category_selected(category: String) -> void:
	Audio.play_sfx("tile_tap")
	_reviewer_category = category
	_refresh_reviewer()

func _on_reviewer_pressed() -> void:
	Audio.play_sfx("button_click")
	options_panel.hide()
	credits_panel.hide()
	difficulty_panel.hide()
	character_panel.hide()
	map_panel.hide()
	_certificate_panel.hide()
	_reviewer_panel.show()

func _on_reviewer_close_pressed() -> void:
	Audio.play_sfx("button_click")
	_reviewer_panel.hide()

# --------------------------------------------------------------------------
# Certificate
# --------------------------------------------------------------------------

## A reward screen, not a settings panel: locked until chapter 1 is beaten
## (GameState.is_chapter_completed, loaded from disk — a save file that
## outlives the current session, not just an in-memory flag), then a CLAIM
## button that hands the player the certificate PDF. Built in code for the
## same reason as the reviewer: no .tscn to lose to an editor auto-revert.
## this is a settings box, not a reward screen.
func _pop_panel(panel: Control) -> void:
	panel.show()
	panel.scale = Vector2(0.94, 0.94)
	panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.12)

func _build_certificate() -> void:
	_add_certificate_menu_button()

	_certificate_panel = PanelContainer.new()
	_certificate_panel.name = "CertificatePanel"
	_certificate_panel.add_theme_stylebox_override("panel", _overlay_style())
	_certificate_panel.offset_left = 150.0
	_certificate_panel.offset_top = 130.0
	_certificate_panel.offset_right = 490.0
	_certificate_panel.offset_bottom = 356.0
	_certificate_panel.hide()
	add_child(_certificate_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 14)
	_certificate_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_certificate_column = column

	var title := Label.new()
	title.text = "CERTIFICATE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/TitanOne-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	column.add_child(title)

	_certificate_status_label = Label.new()
	_certificate_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_certificate_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Wrap width set explicitly, same reason as everywhere else in this file: an
	# autowrap Label left to guess its minimum size assumes one word per line.
	_certificate_status_label.custom_minimum_size = Vector2(300, 0)
	_certificate_status_label.add_theme_font_size_override("font_size", 12)
	_certificate_status_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.68))
	column.add_child(_certificate_status_label)

	_certificate_name_input = LineEdit.new()
	_certificate_name_input.placeholder_text = "Enter your name"
	_certificate_name_input.max_length = CERTIFICATE_NAME_MAX_LENGTH
	_certificate_name_input.custom_minimum_size = Vector2(0, 30)
	_certificate_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_certificate_name_input.add_theme_font_size_override("font_size", 13)
	# Enter submits the same as clicking CLAIM, since retyping a name and then
	# having to reach for the mouse would be an odd extra step.
	_certificate_name_input.text_submitted.connect(func(_text: String) -> void: _on_certificate_claim_pressed())
	column.add_child(_certificate_name_input)

	_certificate_claim_button = Button.new()
	_certificate_claim_button.custom_minimum_size = Vector2(0, 36)
	_certificate_claim_button.add_theme_font_override("font", load("res://assets/fonts/TitanOne-Regular.ttf"))
	_certificate_claim_button.add_theme_font_size_override("font_size", 15)
	_certificate_claim_button.add_theme_color_override("font_color", Color(0.2, 0.11, 0.05))
	for state in ["normal", "pressed", "hover", "focus"]:
		var style := play_button.get_theme_stylebox(state)
		if style != null:
			_certificate_claim_button.add_theme_stylebox_override(state, style)
	_certificate_claim_button.pressed.connect(_on_certificate_claim_pressed)
	column.add_child(_certificate_claim_button)

	column.add_child(SettingsPanel.make_back_button(_on_certificate_close_pressed))

	_refresh_certificate()

## Grows the certificate panel to whatever its current content needs, the same
## way _fit_difficulty_panel() does — content height varies here too, since
## the status label's message changes length (a one-line "Locked." versus a
## two-line "please enter your name" warning) and the name field only exists
## at all once the chapter is unlocked.
func _fit_certificate_panel() -> void:
	var margin := 28.0  # 14px top + 14px bottom, matching the MarginContainer above
	var needed: float = _certificate_column.get_combined_minimum_size().y + margin
	var centre: float = _certificate_panel.offset_top + _certificate_panel.size.y * 0.5
	_certificate_panel.offset_top = centre - needed * 0.5
	_certificate_panel.offset_bottom = _certificate_panel.offset_top + needed

## The single place that decides whether a certificate can be claimed.
##
## Both the panel's appearance and the claim handler ask this, so the two can
## never disagree. That matters more than it looks: Enter in the name field
## submits straight to the handler whether or not the CLAIM button is reachable,
## so a lock enforced only by disabling the button would still hand out
## certificates to anyone who pressed Enter.
func _certificate_unlocked() -> bool:
	if CERTIFICATE_LOCKED:
		return false
	return GameState.is_chapter_completed(CERTIFICATE_CHAPTER)

## Repaints the panel for the current unlock state. Called every time the
## panel opens (not just once at startup) because completing chapter 1 always
## happens in the battle scene — the menu has to notice the change the next
## time the player looks, not assume it already knew.
func _refresh_certificate() -> void:
	var chapter_title := String(CHAPTER_TITLES.get(CERTIFICATE_CHAPTER, "Chapter %d" % CERTIFICATE_CHAPTER))
	var done := _certificate_unlocked()
	# The name field is meaningless before the chapter is beaten, so it only
	# appears once there is actually something to claim.
	_certificate_name_input.visible = done
	if done:
		_certificate_status_label.text = (
			"You completed %s! Enter your name and claim your Certificate of Completion." % chapter_title)
		_certificate_claim_button.text = "CLAIM CERTIFICATE"
		_certificate_claim_button.disabled = false
		_certificate_claim_button.modulate.a = 1.0
		# Always blank, never pre-filled from the last claim. This runs on every
		# open, so it also clears a name left behind by a previous visit rather
		# than only skipping the restore.
		_certificate_name_input.text = ""
	else:
		# Two different reasons to be locked, and the player is owed the right
		# one: "finish the chapter" is a lie when finishing it would not help.
		if CERTIFICATE_LOCKED:
			_certificate_status_label.text = (
				"Certificates are not available yet. Check back in a later update.")
		else:
			_certificate_status_label.text = (
				"Locked. Finish %s to unlock your Certificate of Completion." % chapter_title)
		_certificate_claim_button.text = "LOCKED"
		_certificate_claim_button.disabled = true
		# Dimmed rather than hidden — a locked chapter pin on the map works the
		# same way, visible but blocked, so a player always knows the reward
		# exists rather than wondering if a button is missing.
		_certificate_claim_button.modulate.a = 0.5
	_fit_certificate_panel()

func _on_certificate_pressed() -> void:
	Audio.play_sfx("button_click")
	options_panel.hide()
	credits_panel.hide()
	difficulty_panel.hide()
	character_panel.hide()
	map_panel.hide()
	_reviewer_panel.hide()
	_refresh_certificate()
	_certificate_panel.show()

func _on_certificate_close_pressed() -> void:
	Audio.play_sfx("button_click")
	_certificate_panel.hide()

## Enter in the name field submits here too (see the text_submitted connection
## in _build_certificate), so this has to independently re-check the lock —
## Enter fires whatever is currently wired up, whether or not CLAIM itself is
## reachable at the moment.
func _on_certificate_claim_pressed() -> void:
	if not _certificate_unlocked():
		return
	Audio.play_sfx("button_click")

	var typed_name := _certificate_name_input.text.strip_edges()
	if typed_name.is_empty():
		_certificate_status_label.text = "Please enter your name first."
		_fit_certificate_panel()
		_certificate_name_input.grab_focus()
		return

	GameState.set_player_name(typed_name)
	await _generate_and_open_certificate(typed_name)

## Renders the certificate template with the player's name on it, saves it as
## an image, and hands it to the player. A missing template is treated as an
## expected, temporary state rather than an error — the art is being made
## separately and simply is not in the repo yet — so the status label says so
## plainly instead of the button silently doing nothing.
func _generate_and_open_certificate(claimed_name: String) -> void:
	if not FileAccess.file_exists(CERTIFICATE_TEMPLATE_PATH):
		_certificate_status_label.text = (
			"The certificate template hasn't been added to the game yet — check back soon!")
		_fit_certificate_panel()
		push_warning("MainMenu: certificate claimed but %s is missing" % CERTIFICATE_TEMPLATE_PATH)
		return

	var image := await _render_certificate_image(claimed_name)
	if image == null:
		_certificate_status_label.text = "Something went wrong generating the certificate."
		_fit_certificate_panel()
		return

	if OS.has_feature("web"):
		var bytes := image.save_png_to_buffer()
		_open_image_bytes_in_browser(bytes)
	else:
		var out_path := "user://%s" % CERTIFICATE_EXPORT_FILENAME
		var err := image.save_png(out_path)
		if err != OK:
			push_warning("MainMenu: could not save certificate to %s (%s)" % [
				out_path, error_string(err)])
			_certificate_status_label.text = "Something went wrong generating the certificate."
			_fit_certificate_panel()
			return
		OS.shell_open(ProjectSettings.globalize_path(out_path))

	_certificate_status_label.text = "Certificate saved! Opening it now..."
	_fit_certificate_panel()

## Draws the player's claimed_name onto the template, off-screen, and reads the result
## back as an Image. Godot has no way to paint text onto an Image directly —
## text is a draw call, and draw calls need something to render into — so a
## SubViewport stands in for a canvas: a background TextureRect plus a Label
## get added to it, one frame is rendered, and the pixels are captured.
##
## Position and size are fractions of the template's own dimensions
## (CERTIFICATE_NAME_Y_FRACTION etc.), measured directly against the current
## certificate_template.png — see the constants' own comments for the pixel
## measurements they came from. Retune them together if the template changes.
func _render_certificate_image(claimed_name: String) -> Image:
	var template := load(CERTIFICATE_TEMPLATE_PATH) as Texture2D
	if template == null:
		push_warning("MainMenu: %s did not load as a texture" % CERTIFICATE_TEMPLATE_PATH)
		return null
	var template_size := template.get_size()

	var viewport := SubViewport.new()
	viewport.size = Vector2i(template_size)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var background := TextureRect.new()
	background.texture = template
	background.size = template_size
	background.stretch_mode = TextureRect.STRETCH_SCALE
	viewport.add_child(background)

	var name_label := Label.new()
	name_label.text = claimed_name
	# A FontVariation over the variable Playfair Display file, rather than a
	# second static font file, to get a weight that reads as confidently as
	# the template's own "Atty. Keinth L. Horario" signature line.
	var name_font := FontVariation.new()
	name_font.base_font = load(CERTIFICATE_NAME_FONT_PATH)
	name_font.variation_opentype = {"wght": CERTIFICATE_NAME_FONT_WEIGHT}
	name_label.add_theme_font_override("font", name_font)
	var font_size := int(clampf(template_size.x * CERTIFICATE_NAME_FONT_FRACTION, 18.0, 160.0))
	name_label.add_theme_font_size_override("font_size", font_size)
	# Matches the template's own ink colour (sampled from its signature text)
	# rather than pure black, so the printed claimed_name doesn't stand out as an
	# obviously separate layer from the rest of the design.
	name_label.add_theme_color_override("font_color", Color(0.14, 0.14, 0.14))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_width := template_size.x * CERTIFICATE_NAME_WIDTH_FRACTION
	var label_height := font_size * 1.4
	name_label.size = Vector2(label_width, label_height)
	name_label.position = Vector2(
		(template_size.x - label_width) * 0.5, template_size.y * CERTIFICATE_NAME_Y_FRACTION - label_height * 0.5)
	viewport.add_child(name_label)

	add_child(viewport)
	# The viewport needs at least one full render pass with its children
	# already attached before its texture holds anything meaningful.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image

## Hands PNG bytes to the browser as a downloadable/openable Blob, since a web
## export has no filesystem the OS can open a file from. Built as one inline
## script rather than a loose .js asset — it is small, used nowhere else, and
## keeping it here means the whole claim flow reads in one place.
func _open_image_bytes_in_browser(bytes: PackedByteArray) -> void:
	var base64 := Marshalls.raw_to_base64(bytes)
	var js := (
		"(function(){var b=atob('%s');var arr=new Uint8Array(b.length);" +
		"for(var i=0;i<b.length;i++){arr[i]=b.charCodeAt(i);}" +
		"var blob=new Blob([arr],{type:'image/png'});" +
		"window.open(URL.createObjectURL(blob),'_blank');})();"
	) % base64
	JavaScriptBridge.eval(js)
