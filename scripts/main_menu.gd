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
## Chapters with real content behind them. Derived from what is actually on
## disk rather than typed in, so shipping chapter 3 means adding its data and
## nothing else -- this constant stops being a thing anyone has to remember.
## Caps what the WEB BUILD shows as unlocked, independent of which
## chapter_XX.tres files exist on disk. Chapter 2 is finished enough to test
## locally but not to release, and this is the one knob that keeps it out of
## the public build without deleting or renaming anything: chapter_02.tres
## stays in place, every local run still sees it, and un-capping later is a
## one-line change back to TOTAL_CHAPTERS.
##
## OS.has_feature("editor") is true whenever the project runs through the
## editor executable — pressing Play, or any `godot --path .` invocation used
## by this project's own tooling — and false in an exported template, which is
## the only thing Vercel is ever serving. That is what makes "local" and
## "deployed" the same thing as "editor" and "not editor" here.
const RELEASE_CAP := 1

static func unlocked_chapters() -> int:
	var n := 0
	for i in range(1, TOTAL_CHAPTERS + 1):
		if not GameState.chapter_exists(i):
			break
		n = i
	if not OS.has_feature("editor"):
		n = mini(n, RELEASE_CAP)
	return n
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
## How wide a reviewer entry may run before it wraps. The wrap width has to be
## set explicitly: a RichTextLabel left to guess reports its height as if every
## word were on its own line.
##
## A variable rather than a constant because the reviewer is near-fullscreen on
## a phone and a fixed 556 would run straight off a 320-unit canvas. Recomputed
## from the panel's real width in _layout_panels(), which then rebuilds the list
## so existing entries pick the new width up.
var _reviewer_entry_width := 556.0

## Which chapter unlocks the certificate. Chapter 1 only, matching
## the unlocked set — there is only one certificate chapter for now, but this
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

## Where the plaza floor sits in menu_updated.png, as a fraction of the image's
## height. Measured against the authored composition: the characters' rects end
## at y=457 of a 480-unit canvas, and the background is a 4:3 image drawn 1:1
## over it, so the paved ground the pair stand on is 95% of the way down.
##
## This number is why the phone layout puts the menu ABOVE the characters rather
## than below them. Only the bottom 5% of the illustration is ground; on a tall
## screen a bottom-anchored menu covers the plaza entirely, and the characters
## get pushed up into the sky to stand on the town hall roof. Moving the buttons
## into the empty sky instead leaves the pair on real paving at every size.
const GROUND_FRACTION := 0.95

## The composition the title screen was authored at. In WIDE arrangements the
## whole screen is laid out at exactly these coordinates and centred inside
## whatever design space we actually got, which is what keeps a 4:3 window
## pixel-identical to the pre-responsive build while a 16:9 one simply gains
## background either side.
const WIDE_COMPOSITION := Vector2(640.0, 480.0)

## Where the PLAY/REVIEWER/.../QUIT stack may live, as left/top/right/bottom in
## design space. Top is a floor the stack must not grow above; bottom is fixed
## and the stack grows upward from it.
##
## Was a pair of constants matching the scene's authored 4-button menu; it is a
## variable now because the answer differs per arrangement — the same six
## buttons are a narrow column beside the characters on a monitor and a
## full-width stack beneath them on a phone.
var _menu_bounds := Rect2(372.0, 144.0, 240.0, 290.0)
## Preferred button height before the fitting in _grow_menu_stack() shrinks it.
## Phones get a taller one so the target clears a fingertip.
var _menu_button_height := 50.0
## Menu label size. Compact arrangements need a smaller one or CERTIFICATE runs
## off the end of its scroll.
var _menu_font_size := 21

## Everything the title screen composes. Kept as one list because the map, the
## character picker and the rest all need them hidden together, and hand-written
## hide lists at each call site is exactly how the original drifted.
@onready var _title_pieces: Array[Control] = [
	$TitleLogo, $PlayerCharacter, $PlayerCharacterFemale, $Menu,
]

## The chapter map's artwork and its pins, reparented into one group at
## _ready() so they can be fitted to the screen as a unit. The pins are placed
## against landmarks in the illustration, so anything that moves the picture
## without moving them by the same amount puts Barangay in the sea.
var _map_group: Control
## The compact stand-in for the illustration — see _build_map_list().
var _map_list: VBoxContainer
## Dimmed backdrop behind the list, showing the map artwork itself so the
## compact chapter picker still reads as the map rather than as a bare menu.
var _map_scrim: TextureRect

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
@onready var title_character_female: AnimatedCharacter = $PlayerCharacterFemale
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
## The reviewer is built in code rather than added to main_menu.tscn on disk.
## The editor silently overwrites scene-file edits when it has that scene open,
## and this is a large subtree to lose; building it here also keeps the whole
## screen in one readable place instead of split across a .tscn.
var _reviewer_panel: PanelContainer
var _reviewer_entries: VBoxContainer
var _reviewer_count: Label
## The CHAPTER / LEVEL / TOPIC captions down the left of the filter strips.
## Tracked so a narrow layout can drop them: 52 units of caption is a fifth of a
## phone's width, and the tab labels beside them already say what they filter.
var _reviewer_headings: Array[Label] = []
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
	# Selecting and starting are now two acts: the buttons pick, the confirm
	# below commits. Choosing used to launch the run on the same click, so
	# there was never a moment where the screen showed you who you had picked.
	male_button.pressed.connect(_on_character_selected.bind("male"))
	female_button.pressed.connect(_on_character_selected.bind("female"))
	_build_character_cards()
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
	# Asked for unconditionally. On the web it is held until the player's first
	# touch and flushed then; on desktop it starts here. Either way this also
	# covers coming BACK from a battle, which is what puts the title screen back
	# under its own theme instead of leaving the battle loop running.
	Audio.play_music("menu")
	_build_reviewer()
	_build_certificate()
	# Both characters stand on the plaza, Juan on the left and Maria on the
	# right, rather than only whoever happens to be selected. They are the two
	# faces of the game and the title screen is where a player meets them; the
	# selection is made on its own screen a click later anyway.
	title_character.configure_clips(GameState.PLAYER_CHARACTERS["male"])
	title_character_female.configure_clips(GameState.PLAYER_CHARACTERS["female"])
	_group_map()
	# Last, and after every builder above: the layout pass positions panels that
	# do not exist until those builders have run. bind() also runs it once
	# immediately, so the first frame is already in the right arrangement.
	Layout.bind(self, "_apply_layout")

# --- responsive layout ----------------------------------------------------
#
# The title screen implements the three arrangements from LayoutProfile. WIDE
# reproduces the authored composition exactly; PORTRAIT stacks it; and
# LANDSCAPE_COMPACT keeps the side-by-side shape but on a canvas less than half
# as tall, which mostly means the logo and the characters give up height so the
# menu keeps a tappable one.

func _apply_layout(profile: LayoutProfile) -> void:
	match profile.arrangement:
		LayoutProfile.Arrangement.PORTRAIT:
			_layout_stacked(profile)
		LayoutProfile.Arrangement.LANDSCAPE_COMPACT:
			_layout_side_by_side(profile)
		_:
			_layout_wide(profile)
	_grow_menu_stack($Menu)
	_layout_map(profile)
	_layout_panels(profile)
	# Last, so anything the passes above created is included. Every button in
	# this scene assigned one stylebox to all four states, so until now none of
	# them acknowledged a press at all — see TouchFeedback.
	TouchFeedback.apply_to_tree(self)

## Every overlay was positioned by a hardcoded rect measured against the 640x480
## canvas — 150..490 for the difficulty picker, 16..624 for the reviewer, and so
## on. On a 320-unit phone those run clean off the side of the screen, so they
## are all re-centred against the real design space here, and allowed to go
## near-fullscreen when that is all the room there is.
func _layout_panels(profile: LayoutProfile) -> void:
	_centre_panel(character_panel, CHARACTER_PANEL_SIZE)
	_centre_panel(difficulty_panel, Vector2(340.0, 252.0))
	# Never shrink-to-content: the credits body is a RichTextLabel, which reports
	# almost no minimum height, so fitting the panel to its "content" collapsed
	# it to a title and a Close button with the actual credits clipped away.
	_centre_panel(credits_panel, Vector2(420.0, 250.0), false)
	_centre_panel(options_panel, Vector2(288.0, 168.0))
	# 300 units of status label alone is wider than a small phone.
	if _certificate_status_label != null:
		_certificate_status_label.custom_minimum_size.x = minf(
			300.0, profile.design_size.x * 0.88)
	_centre_panel(_certificate_panel, Vector2(340.0, 226.0))

	# The pickers' buttons were sized for a cursor. A finger needs a target it
	# can hit without aiming, so on touch they grow to 40 design units — about
	# 49 CSS px once the phone's content scale is applied.
	if profile.is_touch:
		for button in [easy_button, medium_button, hard_button, difficulty_back_button,
				male_button, female_button, character_back_button, credits_close_button]:
			button.custom_minimum_size.y = 40.0

	_layout_reviewer(profile)

	# Both of these re-fit their own height around their centre once the content
	# is measured, and that centre has just moved.
	_fit_difficulty_panel()
	_fit_certificate_panel()

	# SettingsPanel captures its pop pivot at build time, so a resize would
	# otherwise leave it scaling from a corner.
	options_panel.pivot_offset = options_panel.size * 0.5

## The reviewer needs its own pass, in a specific order, because its width is
## circular: the panel is as wide as its entries, and the entries wrap to the
## panel's width.
##
## Reading the width off the panel — as this first did — reads the width the
## panel had already been forced to by the 556-unit entries still inside it, so
## it never converged and hung a third of the way off a phone screen. Deciding
## the width from the SCREEN, rebuilding the entries at it, and only then sizing
## the panel breaks the loop.
func _layout_reviewer(profile: LayoutProfile) -> void:
	var d := profile.design_size
	var margin: float = maxf(d.x * 0.03, 10.0)
	# The CHAPTER / LEVEL / TOPIC captions are dropped on compact — 52 units of
	# caption is a sixth of a phone's width, and the tabs beside them already
	# say what they filter.
	for heading in _reviewer_headings:
		heading.visible = profile.is_wide()
	var chrome: float = 52.0 if profile.is_wide() else 24.0
	var target: float = minf(608.0, d.x - margin * 2.0)

	var previous := _reviewer_entry_width
	_reviewer_entry_width = maxf(target - chrome, 150.0)
	if not is_equal_approx(previous, _reviewer_entry_width):
		_refresh_reviewer()
		# Rebuilt labels do not report their new minimum until the next layout
		# pass, and _centre_panel clamps to whatever the minimum is when it runs.
		await get_tree().process_frame
		if not is_instance_valid(_reviewer_panel):
			return
	# Never shrink-to-content: a ScrollContainer reports almost no minimum
	# height, so fitting the reviewer to its content collapses the question list
	# it exists to show.
	_centre_panel(_reviewer_panel, Vector2(target, minf(456.0, d.y - margin * 2.0)), false)
	# This pass can finish a frame after the one in _apply_layout, so anything
	# _refresh_reviewer() just rebuilt would otherwise wait a whole layout change
	# for its pressed state.
	TouchFeedback.apply_to_tree(_reviewer_panel)

## Centres `panel`, capped at `preferred` but never wider or taller than the
## screen can hold. On a phone the cap rarely binds, which is the intent: a
## picker that fills the glass is easier to hit than a faithfully-scaled one.
## `shrink_to_content` off means "fill the space you were given" — for panels
## whose content is a scrolling list, where shrinking to the minimum leaves the
## list nowhere to appear.
func _centre_panel(panel: Control, preferred: Vector2,
		shrink_to_content: bool = true) -> void:
	if panel == null:
		return
	var d := Layout.profile.design_size
	var margin: float = maxf(d.x * 0.03, 10.0)
	var w: float = minf(preferred.x, d.x - margin * 2.0)
	var h: float = minf(preferred.y, d.y - margin * 2.0)
	if shrink_to_content and not Layout.profile.is_wide():
		# Shrink to the content when there is less of it than the authored rect
		# allowed for, so a picker does not sit on a tall slab of empty wood.
		# WIDE keeps the authored height untouched — those rects were composed
		# against this background and are not ours to second-guess.
		panel.size.x = w
		var needed: float = panel.get_combined_minimum_size().y
		if needed > 0.0:
			h = clampf(needed, 0.0, h)
	_place(panel, Rect2((d.x - w) * 0.5, (d.y - h) * 0.5, w, h))
	panel.size = Vector2(w, h)

## The original 640x480 composition, centred in whatever we were given.
##
## Every number here is the scene's own authored offset plus an inset, and the
## characters keep their hand-placed rects rather than going through
## _stand_characters(): those two rects were nudged against this exact
## background crop, and re-deriving them would move desktop for no gain. At
## exactly 640x480 the inset is zero and nothing has moved at all.
func _layout_wide(profile: LayoutProfile) -> void:
	var d := profile.design_size
	var inset: float = maxf((d.x - WIDE_COMPOSITION.x) * 0.5, 0.0)
	var top: float = maxf((d.y - WIDE_COMPOSITION.y) * 0.5, 0.0)
	_place_background(d, top + WIDE_COMPOSITION.y * GROUND_FRACTION)
	_place($TitleLogo, Rect2(inset + 60.0, top + 6.0, 519.0, 136.0))
	title_character.visible = true
	title_character_female.visible = true
	_place(title_character, Rect2(inset + 154.0, top + 237.0, 120.0, 220.0))
	_place(title_character_female, Rect2(inset + 267.0, top + 236.0, 120.0, 220.0))
	_menu_bounds = Rect2(inset + 372.0, top + 144.0, 240.0, 290.0)
	_menu_button_height = 50.0
	_menu_font_size = 21

## Logo band across the top, menu column down the right, characters standing on
## the plaza in the space left over. Used for a phone held sideways, where the
## canvas is only ~270 units tall — so the logo and the characters give up
## height and the menu keeps a tappable one.
func _layout_side_by_side(profile: LayoutProfile) -> void:
	var d := profile.design_size
	var margin := 10.0
	var menu_w := 190.0
	var menu_left: float = d.x - margin - menu_w
	var floor_y: float = d.y - margin
	_place_background(d, floor_y)
	_place($TitleLogo, Rect2(margin, margin, menu_left - margin * 2.0, 62.0))
	_menu_bounds = Rect2(menu_left, margin, menu_w, d.y - margin * 2.0)
	_menu_button_height = 40.0
	_menu_font_size = 17
	title_character.visible = true
	title_character_female.visible = true
	var char_h := 150.0
	_stand_characters(menu_left * 0.5, floor_y, char_h, char_h * 0.52)

## Logo at the top, menu in the sky, characters on the plaza at the bottom.
##
## The unusual part is the menu sitting ABOVE the characters rather than below.
## That is forced by the artwork — see GROUND_FRACTION — and it turns out to be
## the better composition anyway: the buttons land on empty sky where they read
## cleanly, and the pair keep the paving under their feet.
func _layout_stacked(profile: LayoutProfile) -> void:
	var d := profile.design_size
	var margin: float = maxf(d.x * 0.04, 10.0)
	var logo_h: float = minf(d.y * 0.155, 120.0)
	_place($TitleLogo, Rect2(margin, margin, d.x - margin * 2.0, logo_h))

	# Juan and Maria stay on the plaza, but only where there is room to see
	# them. On a phone the menu is the screen's whole job, and two characters
	# sharing it made the buttons compete with the artwork for the same strip;
	# the pair still greet the player on desktop and tablet-landscape.
	var ground := _place_background(d, d.y - margin)
	title_character.visible = false
	title_character_female.visible = false

	# 44 design units is the tap-target floor; on a phone the content scale puts
	# that at roughly 54 CSS px, past the 44 CSS px minimum. _grow_menu_stack
	# shrinks below it only if the band genuinely cannot hold six buttons.
	_menu_button_height = 44.0
	_menu_font_size = 20
	# With the plaza to itself, the stack centres in the space under the logo
	# instead of hugging a character's head.
	var band_top: float = margin + logo_h + 6.0
	var band_bottom: float = d.y - margin
	var count: float = float(maxi($Menu.get_child_count(), 1))
	var separation: float = $Menu.get_theme_constant("separation")
	var wanted: float = _menu_button_height * count + separation * (count - 1.0)
	var slack: float = maxf((band_bottom - band_top - wanted) * 0.5, 0.0)
	var available: float = maxf(band_bottom - band_top - slack * 2.0, 120.0)
	_menu_bounds = Rect2(margin, band_top + slack, d.x - margin * 2.0, available)

## Sizes and offsets the background so the plaza lands on `target_floor`, and
## reports where the ground actually ended up.
##
## The node was anchored full-rect with KEEP_ASPECT_COVERED, which centres its
## crop — fine at 4:3, but on a tall phone it decides for itself which slice of
## the illustration to show, and the answer was "not the ground". Placing the
## rect by hand means we choose the crop, and the return value lets the caller
## stand the characters on whatever we were actually able to give them.
func _place_background(d: Vector2, target_floor: float) -> float:
	var bg: TextureRect = $Background
	var tex := bg.texture
	if tex == null:
		return target_floor
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return target_floor
	# Cover: never leave a bare edge, whatever the aspect.
	var s: float = maxf(d.x / ts.x, d.y / ts.y)
	var drawn := ts * s
	# Slide vertically to put the ground where it was asked for, but never past
	# the point where the image stops covering the screen.
	var wanted: float = target_floor - drawn.y * GROUND_FRACTION
	var y: float = clampf(wanted, minf(d.y - drawn.y, 0.0), 0.0)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	# The node was authored anchored full-rect, which would make the offsets
	# below relative to the far edges instead of the origin.
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 0.0
	bg.anchor_bottom = 0.0
	_place(bg, Rect2((d.x - drawn.x) * 0.5, y, drawn.x, drawn.y))
	return y + drawn.y * GROUND_FRACTION

## Stands Juan and Maria side by side with their FEET on `floor_y`, whatever
## their sprites' transparent padding happens to be.
##
## The scene had their two rects hand-nudged a pixel apart to make the ground
## line look right at one size, which stops being true the moment the size
## changes. AnimatedCharacter.body_rect() reports where the opaque pixels
## actually are inside the node, so aligning against that puts both pairs of
## feet on the same line by construction, at every arrangement.
func _stand_characters(centre_x: float, floor_y: float, height: float, width: float) -> void:
	var overlap: float = width * 0.06
	var pair := [
		{"node": title_character, "x": centre_x - width + overlap},
		{"node": title_character_female, "x": centre_x - overlap},
	]
	for entry in pair:
		var who: AnimatedCharacter = entry["node"]
		who.offset_left = entry["x"]
		who.offset_right = entry["x"] + width
		# Size must be settled before body_rect() is asked, because it measures
		# against the node's current rect to reproduce KEEP_ASPECT_CENTERED.
		who.offset_top = floor_y - height
		who.offset_bottom = floor_y
		who.size = Vector2(width, height)
		var body := who.body_rect()
		var foot_gap: float = height - body.end.y
		who.offset_top += foot_gap
		who.offset_bottom += foot_gap

func _place(node: Control, rect: Rect2) -> void:
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y

## Moves the map illustration and its pins into one Control so they can be
## scaled together. Done in code rather than in main_menu.tscn because the
## editor rewrites that scene whenever it has it open, and this is a subtree
## that would be silently lost.
func _group_map() -> void:
	var artwork := map_panel.get_node_or_null("MapBackground") as TextureRect
	_map_scrim = TextureRect.new()
	_map_scrim.name = "MapScrim"
	_map_scrim.texture = artwork.texture if artwork != null else null
	_map_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_scrim.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Dark enough that the buttons on top carry the contrast, bright enough that
	# the islands are still recognisably there.
	_map_scrim.modulate = Color(0.34, 0.34, 0.36)
	_map_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.add_child(_map_scrim)
	map_panel.move_child(_map_scrim, 0)

	_map_group = Control.new()
	_map_group.name = "MapGroup"
	_map_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_group.size = WIDE_COMPOSITION
	map_panel.add_child(_map_group)
	map_panel.move_child(_map_group, 1)

	# Everything that is pinned to the artwork travels with it. The back button
	# and the "available soon" toast belong to the screen, not the picture, so
	# they stay where they are and get placed against the real design space.
	for child in map_panel.get_children():
		var name_text: String = String(child.name)
		var travels := name_text == "MapBackground" or name_text == "TitleScrim" \
			or name_text.begins_with("Chapter")
		if travels:
			map_panel.remove_child(child)
			_map_group.add_child(child)
	_build_map_list()

## The portrait/landscape stand-in for the illustrated map.
##
## The illustration is a 640-wide picture whose five pins are placed against
## landmarks in it, so it can only ever be shown whole — and whole, on a
## 320-unit phone, means half scale, which puts its chapter captions at about
## six pixels. Rather than ship a map nobody can read, compact screens get the
## same five chapters as a list of full-width buttons, with the artwork kept
## behind them as a backdrop so the screen still feels like the map.
func _build_map_list() -> void:
	_map_list = VBoxContainer.new()
	_map_list.name = "MapList"
	_map_list.add_theme_constant_override("separation", 8)
	map_panel.add_child(_map_list)

	var title := Label.new()
	title.text = "CHOOSE YOUR CHAPTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/fonts/TitanOne-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	_map_list.add_child(title)

	for i in range(1, TOTAL_CHAPTERS + 1):
		var locked := i > unlocked_chapters()
		var button := Button.new()
		button.name = "ListChapter%d" % i
		# The short tab names, not the long map captions: the scroll stylebox
		# spends ~60 units on its decorative ends, and "City Hall Shadows
		# (LOCKED)" runs straight through them on a 320-unit canvas.
		button.text = "%d  %s" % [i, CHAPTER_TABS[i]]
		if locked:
			button.text += "   LOCKED"
		button.clip_text = true
		button.add_theme_font_override("font", load("res://assets/fonts/TitanOne-Regular.ttf"))
		button.add_theme_color_override("font_color", Color(0.2, 0.11, 0.05))
		# Borrow PLAY's boxes so the list is the same wooden scroll as the menu
		# it was reached from, rather than a bare default button.
		for state in ["normal", "pressed", "hover", "focus"]:
			var style := play_button.get_theme_stylebox(state)
			if style != null:
				button.add_theme_stylebox_override(state, style)
		button.self_modulate = Color(0.62, 0.62, 0.6) if locked else Color(0.72, 1.0, 0.72)
		button.pressed.connect(_on_chapter_pressed.bind(i))
		_map_list.add_child(button)

func _layout_map(profile: LayoutProfile) -> void:
	if _map_group == null:
		return
	var d := profile.design_size
	var margin: float = maxf(d.x * 0.03, 10.0)

	# Only a WIDE canvas can show the illustration at a size where its captions
	# are legible; everywhere else the list stands in for it.
	var illustrated := profile.is_wide()
	_map_group.visible = illustrated
	_map_list.visible = not illustrated
	_map_scrim.visible = not illustrated

	if illustrated:
		# Fit, never fill: cropping is not an option when five of the children
		# are tap targets sitting near the picture's edges.
		var fit: float = minf(d.x / WIDE_COMPOSITION.x, d.y / WIDE_COMPOSITION.y)
		_map_group.scale = Vector2(fit, fit)
		_map_group.position = (d - WIDE_COMPOSITION * fit) * 0.5
	else:
		# The list has to share the screen with the Back button, which is placed
		# below. Sizing the rows to the space that is actually left over — rather
		# than to a fixed height — is what keeps a rotated phone, where there are
		# only ~200 units to work with, from stacking the two on top of each
		# other.
		var back_h: float = 44.0 if profile.is_touch else 28.0
		var title_h: float = 26.0 if profile.is_portrait() else 20.0
		# The scroll stylebox is about 30 units tall before its art starts
		# overlapping the row above, so on a short canvas the rows are packed
		# closer together rather than made shorter than the graphic allows.
		var separation: int = 8 if profile.is_portrait() else 3
		_map_list.add_theme_constant_override("separation", separation)
		var available: float = d.y - margin * 2.0 - back_h - 8.0
		var button_h: float = clampf(
			(available - title_h - separation * TOTAL_CHAPTERS) / float(TOTAL_CHAPTERS),
			30.0, 46.0)
		for child in _map_list.get_children():
			if child is Button:
				(child as Button).custom_minimum_size.y = button_h
				# The scroll stylebox spends ~120 units on decorative ends, so
				# the usable text run is much narrower than the button.
				(child as Button).add_theme_font_size_override("font_size",
					16 if d.x >= 400.0 else 12)
		var list_h: float = title_h + (button_h + separation) * TOTAL_CHAPTERS
		_place(_map_list, Rect2(margin, margin + maxf((available - list_h) * 0.5, 0.0),
			d.x - margin * 2.0, list_h))

	var back_size := Vector2(108.0, 28.0) if profile.is_wide() else Vector2(120.0, 44.0)
	_place(map_back_button, Rect2(margin, d.y - margin - back_size.y, back_size.x, back_size.y))
	# Width and stacking only — the height is settled in _show_soon_toast(),
	# once the body label has a width to wrap at. Raised to the top of the map
	# because, as a child added before the chapter list, it was being painted
	# over by the very buttons it is answering.
	var toast_w: float = minf(300.0, d.x - margin * 2.0)
	soon_toast.offset_left = (d.x - toast_w) * 0.5
	soon_toast.offset_right = soon_toast.offset_left + toast_w
	soon_toast.size.x = toast_w
	map_panel.move_child(soon_toast, map_panel.get_child_count() - 1)

## The title composition and the map cannot share the screen once the map is
## fitted rather than stretched — it no longer covers the logo and characters.
func _set_title_visible(visible_now: bool) -> void:
	for piece in _title_pieces:
		piece.visible = visible_now

## Heights the toast to its own text and centres it.
##
## Has to happen while the toast is VISIBLE and has already been given its
## width. Asking a hidden panel for its minimum height measures an autowrap
## label that has no width to wrap at, so every word reports as its own line and
## a two-line notice claims a third of the screen.
func _fit_soon_toast() -> void:
	await get_tree().process_frame
	if not is_instance_valid(soon_toast) or not soon_toast.visible:
		return
	var d := Layout.profile.design_size
	var height: float = clampf(soon_toast.get_combined_minimum_size().y, 60.0, d.y * 0.4)
	soon_toast.offset_top = (d.y - height) * 0.5
	soon_toast.offset_bottom = soon_toast.offset_top + height
	soon_toast.size.y = height

## Wired by index rather than one handler per pin, so adding chapter 6 means
## adding a node and bumping TOTAL_CHAPTERS — no new signal code.
func _connect_chapter_pins() -> void:
	for i in range(1, TOTAL_CHAPTERS + 1):
		var pin := map_panel.get_node_or_null("Chapter%dButton" % i) as Button
		if pin == null:
			push_warning("MainMenu: no map pin for chapter %d" % i)
			continue
		pin.pressed.connect(_on_chapter_pressed.bind(i))
	_refresh_chapter_pins()

## Repaints the map to match what is actually playable. The scene file carries
## "(LOCKED)" baked into every caption past chapter 1, which was true when only
## chapter 1 existed and quietly stops being true the moment another chapter's
## data lands — so the caption and the dimming are both derived here instead.
## Centre of each chapter's numbered marker on the 640x480 map.
##
## The scene's own offsets were authored against the map's ORIGINAL artwork.
## Every island has since been redrawn and repositioned, so those offsets point
## at open water. These come straight out of tools/chapter2/make_map.py, which
## reports a marker point per island once it has placed it -- keeping the two in
## one place is what stops the pins drifting off the art again.
const MARKER_POINTS := {
	1: Vector2(104, 347), 2: Vector2(238, 290), 3: Vector2(352, 155),
	4: Vector2(470, 321), 5: Vector2(556, 178),
}

## Puts a chapter's caption directly under its marker and off its island.
##
## The scene positions the captions against the map's original artwork, where
## they sat beside the old pins. With the islands redrawn they landed squarely
## on the buildings they were naming -- the City Hall caption covered the City
## Hall. Hanging them off the marker keeps the two together wherever the island
## moves, and clamping keeps the rightmost one inside the parchment.
func _place_caption(chapter: int, at: Vector2, marker_h: float) -> void:
	var scrim := map_panel.get_node_or_null("Chapter%dScrim" % chapter) as Control
	if scrim == null:
		return
	var w: float = scrim.size.x
	scrim.position = Vector2(
		clampf(at.x - w * 0.5, 6.0, MAP_ART.x - w - 6.0),
		at.y + marker_h * 0.5 + 4.0)

## The map artwork's own size. Captions are clamped to it rather than to the
## panel, which is larger than the picture on a wide screen.
const MAP_ART := Vector2(640, 480)

func _refresh_chapter_pins() -> void:
	var unlocked := unlocked_chapters()
	for i in range(1, TOTAL_CHAPTERS + 1):
		var locked := i > unlocked
		var marker := map_panel.get_node_or_null("Chapter%dButton" % i) as Control
		if marker != null and MARKER_POINTS.has(i):
			# Centre on the point, not top-left: the buttons are 44px discs.
			var at: Vector2 = MARKER_POINTS[i]
			marker.position = at - marker.size * 0.5
			# Above the scrims, so the number is never hidden by its own label.
			map_panel.move_child(marker, map_panel.get_child_count() - 1)
			_place_caption(i, at, marker.size.y)
		var label := map_panel.get_node_or_null("Chapter%dScrim/Chapter%dLabel" % [i, i]) as Label
		if label != null:
			var title := String(CHAPTER_TITLES.get(i, "Chapter %d" % i))
			label.text = title + ("  (LOCKED)" if locked else "")
			label.modulate = Color(0.72, 0.70, 0.66) if locked else Color.WHITE
		var pin := map_panel.get_node_or_null("Chapter%dButton" % i) as Button
		if pin != null:
			# The gold pin is the scene's "available" look; locked ones keep the
			# grey it was authored with.
			pin.self_modulate = Color(0.62, 0.60, 0.58) if locked else Color(1.0, 0.84, 0.36)

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
	_set_title_visible(false)
	map_panel.show()

func _on_chapter_pressed(chapter: int) -> void:
	if chapter > unlocked_chapters():
		Audio.play_sfx("word_rejected")
		_show_soon_toast()
		return
	# Load it here rather than at _start_run, so everything downstream — the
	# difficulty hints, the certificate panel, the question pool — is already
	# talking about the chapter the player just picked.
	if not GameState.load_chapter(chapter):
		Audio.play_sfx("word_rejected")
		_show_soon_toast()
		return
	Audio.play_sfx("button_click")
	_apply_difficulty_hints()
	# Cleared on every entry: arriving with a stale pick would show a chosen
	# card for a decision the player has not made this time.
	_picked_character = ""
	_paint_character_cards()
	character_panel.show()
	# Re-fitted once it is actually on screen. Sizing it while hidden measured
	# the hint before it had a width to wrap against, which is what left the
	# panel taller than its contents.
	await get_tree().process_frame
	_centre_panel(character_panel, CHARACTER_PANEL_SIZE)

## A self-dismissing notice, so a locked chapter never traps the player behind
## a dialog they have to close.
func _show_soon_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	soon_toast.modulate.a = 1.0
	soon_toast.show()
	await _fit_soon_toast()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(soon_toast, "modulate:a", 0.0, TOAST_FADE)
	_toast_tween.tween_callback(soon_toast.hide)

## Picking a character records it and moves on to difficulty. The choice is
## cosmetic — GameState.PLAYER_CHARACTERS gives both identical clip counts — so
## nothing downstream needs to branch on it.
## Which character the cards are currently showing as chosen. Empty until the
## player picks, which is what keeps the confirm button disabled on arrival.
var _picked_character := ""

## Wraps each preview in a card: a framed plinth with the sprite standing on it
## and a name plate beneath. The previews are REPARENTED rather than rebuilt,
## so their idle animation keeps running -- they are AnimatedCharacters, and a
## fresh TextureRect would have been a still image.
func _build_character_cards() -> void:
	var row := character_panel.get_node_or_null("VBox/PreviewRow") as HBoxContainer
	var buttons := character_panel.get_node_or_null("VBox/ButtonRow") as HBoxContainer
	if row == null or buttons == null or row.has_meta("carded"):
		return
	row.set_meta("carded", true)
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	for spec in [["MalePreview", male_button, "male"],
			["FemalePreview", female_button, "female"]]:
		var preview := row.get_node_or_null(String(spec[0])) as Control
		var button := spec[1] as Button
		if preview == null or button == null:
			continue
		var card := PanelContainer.new()
		card.name = "Card_%s" % spec[2]
		card.add_theme_stylebox_override("panel", CharacterCards.card_style(false))
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(stack)

		row.remove_child(preview)
		stack.add_child(preview)
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# The name button moves INSIDE the card, so the whole card is one
		# target and the label names the thing directly above it.
		buttons.remove_child(button)
		button.add_theme_stylebox_override("normal", CharacterCards.plate_style(false))
		button.add_theme_stylebox_override("hover", CharacterCards.plate_style(false))
		button.add_theme_stylebox_override("pressed", CharacterCards.plate_style(true))
		button.add_theme_stylebox_override("focus", CharacterCards.plate_style(false))
		button.custom_minimum_size = Vector2(96, 26)
		button.add_theme_font_size_override("font_size", 14)
		stack.add_child(button)

		row.add_child(card)
		_character_cards[String(spec[2])] = {"card": card, "button": button,
			"preview": preview}

	buttons.hide()          # emptied; its slot would otherwise still take height

	# Give the hint a width to wrap against. Measured with none, an autowrap
	# Label reports every word as its own line, so its minimum height came out
	# enormous -- and because Godot clamps a Control UP to its minimum at the
	# moment size is assigned, the panel was stretched to 453px and stayed
	# there long after the real minimum settled at 283. That was the slab of
	# empty black below the Back button.
	var hint_label := character_panel.get_node_or_null("VBox/CharacterHint") as Label
	if hint_label != null:
		hint_label.custom_minimum_size.x = CHARACTER_PANEL_SIZE.x - 20.0
	_build_confirm_row()
	_paint_character_cards()

## The panel's authored size. One constant, because it is now used both to fit
## the panel and to give the hint a wrap width -- and those two disagreeing is
## exactly how the panel ended up stretched.
const CHARACTER_PANEL_SIZE := Vector2(340.0, 258.0)

var _character_cards: Dictionary = {}
var _confirm_button: Button = null

## The single "start" action. Disabled until a character is picked, so the
## screen always answers "what do I click next".
func _build_confirm_row() -> void:
	var vbox := character_panel.get_node_or_null("VBox") as VBoxContainer
	var hint := character_panel.get_node_or_null("VBox/CharacterHint") as Label
	if vbox == null or _confirm_button != null:
		return
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.text = "START"
	_confirm_button.custom_minimum_size = Vector2(0, 30)
	_confirm_button.add_theme_font_size_override("font_size", 15)
	_confirm_button.add_theme_color_override("font_color", Color(1, 0.95, 0.82))
	_confirm_button.pressed.connect(_on_character_confirmed)
	vbox.add_child(_confirm_button)
	# Above the hint and the Back button, below the cards: the order the player
	# reads them in.
	if hint != null:
		vbox.move_child(_confirm_button, hint.get_index())

func _paint_character_cards() -> void:
	for key in _character_cards:
		var entry: Dictionary = _character_cards[key]
		var chosen: bool = String(key) == _picked_character
		(entry["card"] as PanelContainer).add_theme_stylebox_override(
			"panel", CharacterCards.card_style(chosen))
		var button := entry["button"] as Button
		button.add_theme_stylebox_override("normal", CharacterCards.plate_style(chosen))
		button.add_theme_stylebox_override("hover", CharacterCards.plate_style(chosen))
		button.add_theme_color_override("font_color", CharacterCards.name_colour(chosen))
		# The unchosen one recedes rather than disappearing -- it is still a
		# live option, just not the current one.
		(entry["preview"] as Control).modulate = (
			Color.WHITE if chosen else Color(0.62, 0.60, 0.58))
	if _confirm_button != null:
		var ready := not _picked_character.is_empty()
		_confirm_button.disabled = not ready
		_confirm_button.add_theme_stylebox_override(
			"normal", CharacterCards.confirm_style(ready))
		_confirm_button.add_theme_stylebox_override(
			"hover", CharacterCards.confirm_style(ready))
		_confirm_button.add_theme_stylebox_override(
			"disabled", CharacterCards.confirm_style(false))
		_confirm_button.text = "START" if ready else "PICK A CHARACTER"

func _on_character_selected(character: String) -> void:
	Audio.play_sfx("button_click")
	_picked_character = character
	_paint_character_cards()

func _on_character_confirmed() -> void:
	if _picked_character.is_empty():
		return
	_on_character_chosen(_picked_character)

func _on_character_chosen(character: String) -> void:
	Audio.play_sfx("button_click")
	GameState.character = character
	character_panel.hide()
	# Refreshed here, not just at boot: this is the moment the player actually
	# sees the panel, and the unlock picture can have changed since — beating
	# Easy earlier in the same sitting is exactly what should show up now.
	_apply_difficulty_hints()
	difficulty_panel.show()

func _on_character_back_pressed() -> void:
	Audio.play_sfx("button_click")
	character_panel.hide()

## Difficulty is recorded on GameState rather than pushed into QuestionBank
## here, because it belongs to the run: the battle scene re-applies it on load,
## so it survives Try Again without the menu being involved.
##
## Re-checks the unlock independently of the button's disabled state, the same
## defensive habit the certificate claim path already follows — a disabled
## button should make this unreachable, but the button is not the source of
## truth and this function should not trust it blindly.
func _start_run(difficulty: String) -> void:
	if not GameState.is_tier_unlocked(GameState.chapter_number(), difficulty):
		return
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
	_set_title_visible(true)

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
## Also GATES the buttons: Medium needs Easy beaten this sitting, Hard needs
## Medium. Called at boot (nothing unlocked yet) and again every time the
## difficulty panel is about to be shown, since the picture can change between
## those two moments — the player may have beaten Easy since the panel was
## last open, in the same continuous session.
func _apply_difficulty_hints() -> void:
	var chapter_no := GameState.chapter_number()
	var buttons := {"easy": easy_button, "medium": medium_button, "hard": hard_button}
	for tier in QuestionBank.DIFFICULTY_ORDER:
		var label := difficulty_panel.get_node_or_null("VBox/%sHint" % tier.capitalize()) as Label
		if label == null:
			push_warning("MainMenu: no hint label for '%s' difficulty" % tier)
			continue
		var button: Button = buttons[tier]
		var unlocked := GameState.is_tier_unlocked(chapter_no, tier)
		button.disabled = not unlocked
		# Dimmed rather than hidden — same convention as the certificate's
		# LOCKED state and the map's locked chapter pins: a player always knows
		# the tier exists rather than wondering if a button went missing.
		button.modulate.a = 1.0 if unlocked else 0.5
		if not unlocked:
			var idx := QuestionBank.DIFFICULTY_ORDER.find(tier)
			var prev: String = QuestionBank.DIFFICULTY_ORDER[idx - 1]
			label.text = "Beat %s first, this sitting, to unlock %s." % [
				prev.capitalize(), tier.capitalize()]
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
	_regrow_panel(difficulty_panel, needed)

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
	# just be confusing. Reusing unlocked_chapters() means this needs no changes
	# when chapter 2 ships — it gains a tab the same moment its map pin opens.
	var chapter_row := _add_tab_row(column, "CHAPTER")
	for chapter_no in QuestionBank.chapters_available():
		if int(chapter_no) > unlocked_chapters():
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
	if count <= 0:
		return
	var separation := menu.get_theme_constant("separation")
	var available: float = _menu_bounds.size.y
	var fitted_height: float = (available - separation * (count - 1)) / float(count)
	var button_height: float = clampf(fitted_height, 30.0, _menu_button_height)
	for child in menu.get_children():
		if child is Button:
			var button := child as Button
			button.custom_minimum_size.y = button_height
			button.add_theme_font_size_override("font_size", _menu_font_size)
	var needed := button_height * count + separation * (count - 1)
	menu.offset_left = _menu_bounds.position.x
	menu.offset_right = _menu_bounds.end.x
	menu.offset_top = _menu_bounds.end.y - needed
	menu.offset_bottom = _menu_bounds.end.y

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
	label.name = "RowHeading"
	label.text = heading
	label.custom_minimum_size = Vector2(52, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.44))
	row.add_child(label)
	_reviewer_headings.append(label)

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
	# A Button reports its label's width as its minimum, so five chapter tabs
	# insisted on ~450 units between them and shouldered the whole reviewer
	# panel off the side of a 320-unit phone. clip_text drops the text from that
	# minimum, letting the row fit and ellipsising whatever does not.
	tab.clip_text = true
	tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	heading.custom_minimum_size = Vector2(_reviewer_entry_width, 0)
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
	label.custom_minimum_size = Vector2(_reviewer_entry_width, 0)
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

## A reward screen, not a settings panel: locked until chapter 1 is beaten on
## EVERY difficulty tier — Easy, Medium and Hard all recorded, not just one
## (GameState.is_chapter_completed, loaded from disk — a save file that
## outlives the current session, not just an in-memory flag) — then a CLAIM
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
	_regrow_panel(_certificate_panel, needed)

## Re-heights a panel around its own centre, then slides it back on screen if
## that pushed it off an edge.
##
## Both fitters grew panels around their centre with no regard for the screen,
## which was invisible at 640x480 — the panels were small and the canvas was
## roomy — and shows up on a phone, where a certificate carrying a name field
## and a claim button is taller than the space above and below its centre.
func _regrow_panel(panel: Control, needed: float) -> void:
	var d := Layout.profile.design_size
	var margin: float = maxf(d.x * 0.03, 10.0)
	var height: float = minf(needed, d.y - margin * 2.0)
	var centre: float = panel.offset_top + panel.size.y * 0.5
	var top: float = clampf(centre - height * 0.5, margin, maxf(d.y - margin - height, margin))
	panel.offset_top = top
	panel.offset_bottom = top + height
	panel.size.y = height

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
## Names exactly which tiers are already beaten THIS SESSION and which remain,
## so a player partway up the climb sees that reflected rather than the same
## generic "Locked." they saw before playing anything at all. Deliberately
## reads session progress, not the permanent record — this message describes
## the current sitting, which is exactly the thing that resets if they leave.
func _certificate_progress_message(chapter_title: String) -> String:
	var done := GameState.session_completed_tiers_for(CERTIFICATE_CHAPTER)
	if done.is_empty():
		return ("Beat %s on Easy, then Medium, then Hard — all in one sitting — to unlock your Certificate of Completion."
			% chapter_title)
	var done_labels: Array[String] = []
	var remaining_labels: Array[String] = []
	for tier in QuestionBank.DIFFICULTY_ORDER:
		if done.has(tier):
			done_labels.append(tier.capitalize())
		else:
			remaining_labels.append(tier.capitalize())
	return ("%s done on %s this sitting! Beat %s next, without leaving, to unlock your Certificate of Completion."
		% [chapter_title, ", ".join(done_labels), " then ".join(remaining_labels)])

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
		# one: "finish the chapter" is a lie when finishing it would not help,
		# and once real progress exists a flat "Locked." reads as a bug rather
		# than the player being partway there.
		if CERTIFICATE_LOCKED:
			_certificate_status_label.text = (
				"Certificates are not available yet. Check back in a later update.")
		else:
			_certificate_status_label.text = _certificate_progress_message(chapter_title)
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
