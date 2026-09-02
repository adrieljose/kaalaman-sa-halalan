extends Node
## Tracks run-scoped progress: potion stock, and how far through the current
## chapter the player has walked.

## Chapters are addressed by number rather than by one hardcoded path, so
## adding chapter 3 is a matter of dropping chapter_03.tres in beside the
## others — no code change here, and none in the battle scene either.
const CHAPTER_PATH_FORMAT := "res://data/chapters/chapter_%02d.tres"
const FIRST_CHAPTER := 1

static func chapter_path(chapter_no: int) -> String:
	return CHAPTER_PATH_FORMAT % chapter_no

## Whether a chapter's data actually exists on disk. The chapter map asks this
## so a chapter is offered only when there is something behind the button.
static func chapter_exists(chapter_no: int) -> bool:
	return ResourceLoader.exists(chapter_path(chapter_no))

var player_max_hp: int = 100

## The chapter being played and which encounter in it is live. These live here
## rather than in the battle scene because the battle scene is reloaded /
## reset between encounters — progress has to outlive it.
var chapter: ChapterData
var encounter_index: int = 0

## The two playable characters. They differ only in appearance — every clip
## count, and therefore every combat beat, is identical, so picking one has no
## mechanical consequence. Sprite paths live here rather than in the scene so
## the title screen and the battle scene read the same source.
const PLAYER_CHARACTERS := {
	"male": {
		"label": "JUAN",
		"idle_dir": "res://assets/images/characters/player_battle_idle", "idle_count": 4,
		"attack_dir": "res://assets/images/characters/player_battle_attack", "attack_count": 6,
		"hit_dir": "res://assets/images/characters/player_battle_hit", "hit_count": 6,
		"walk_dir": "res://assets/images/characters/player_battle_walk", "walk_count": 8,
	},
	"female": {
		"label": "MARIA",
		"idle_dir": "res://assets/images/characters/player_female_battle_idle", "idle_count": 4,
		"attack_dir": "res://assets/images/characters/player_female_battle_attack", "attack_count": 6,
		"hit_dir": "res://assets/images/characters/player_female_battle_hit", "hit_count": 6,
		"walk_dir": "res://assets/images/characters/player_female_battle_walk", "walk_count": 8,
		# NO flip. The old front-on frames faced the wrong way and were mirrored
		# to compensate; her battle frames are drawn facing the rival, so
		# mirroring them now would turn her back on him again.
	},
}
const DEFAULT_CHARACTER := "male"

## Which character the player picked. Appearance only.
var character: String = DEFAULT_CHARACTER

## Difficulty picked on the title screen, one of QuestionBank.DIFFICULTY_ORDER.
## Stored here (not in QuestionBank) because it is a property of the run, and
## the battle scene re-applies it to the bank on load — that way booting the
## battle scene directly for testing still gets a sensible pool.
var difficulty: String = "easy"

## Seconds to answer before the rival gets a free hit, per difficulty. Harder
## tiers get longer clocks because their answers are longer — HARD includes
## 21-letter answers, which need real time to find on a 36-tile board.
##
## This lives here rather than in the battle scene because two places need the
## same numbers: the scene that counts them down, and the difficulty menu that
## promises them to the player up front. A menu quoting "30 seconds" while the
## battle ran a different clock would be a lie the player can measure.
const QUESTION_TIME_BY_DIFFICULTY := {
	"easy": 30.0,
	"medium": 45.0,
	"hard": 60.0,
}
const DEFAULT_QUESTION_TIME := 30.0

func question_seconds(tier: String = "") -> float:
	var wanted := tier if not tier.is_empty() else difficulty
	return QUESTION_TIME_BY_DIFFICULTY.get(wanted, DEFAULT_QUESTION_TIME)

enum PotionType { HEALTH, POWER, PURIFY }

## Bookworm caps each potion type at ten units; losing a fight wipes the
## stock back to baseline, so hoarding through a loss isn't possible.
const MAX_PER_POTION := 10
const STARTING_POTION_COUNT := 2

var potions: Dictionary = {}

## Whether a chapter's certificate has been earned. Keyed chapter_no -> true.
## This is the game's only persisted state — everything else in GameState is
## scoped to the current run and starts fresh each launch. It has to survive
## the app closing, because the certificate, once earned, should stay earned.
##
## What is deliberately NOT persisted is progress TOWARD earning it — see
## _session_tier_progress below. Earning the certificate requires beating
## Easy, then Medium, then Hard, all in one continuous sitting: leaving and
## coming back (closing the tab, refreshing, relaunching) resets the climb
## back to the start. Only the fact that it was ever fully earned survives.
var certificate_earned: Dictionary = {}

## Which tiers have been beaten THIS SESSION, per chapter. Keyed
## chapter_no -> Dictionary{tier: true}. Deliberately run-scoped — never
## written by _save_progress(), never read back by _load_progress() — because
## this is what makes the climb "continuous": a fresh process (a relaunch, or
## a page reload on web) starts this at {} again regardless of what the player
## achieved in an earlier sitting.
var _session_tier_progress: Dictionary = {}
## Whatever name the player last typed onto a certificate, remembered so they
## are not retyping it every time they come back to claim one. Empty until
## they claim a certificate for the first time.
var player_name: String = ""

## Whether the player has ever reached the end of the tutorial. Persisted
## alongside the certificate flag, and for the same reason: the only thing the
## first-time prompt must not do is ask a returning player the same question
## every launch. On the web export user:// is backed by IndexedDB, so this
## survives a page reload the same way it survives the desktop app closing.
##
## Skipping does NOT set it. Someone who skips the tutorial before they have
## seen it has not learned the game, and being offered it once more next time
## is a smaller cost than never offering it again. Reaching the last card does
## set it, whichever button they leave by.
var tutorial_completed: bool = false
## True while the tutorial is the thing running. Never saved -- it is a mode
## the battle scene is in, not progress. Everything that writes progress checks
## it, so a tutorial can play a whole exchange without touching the run.
var tutorial_mode: bool = false
## Set by the tutorial's END card when the player leaves it by START GAME, and
## consumed by the title screen on the very next _ready(). A request rather than
## an action: the battle scene has no business choosing a chapter, a character
## and a difficulty on the player's behalf, so it hands the intent back to the
## screen that owns those choices.
var pending_play_request: bool = false
const PROGRESS_SAVE_PATH := "user://progress.save"

func _ready() -> void:
	reset_potions()
	load_chapter(FIRST_CHAPTER)
	_load_progress()

## Swaps in a chapter and rewinds to its first encounter. Returns false and
## leaves the current chapter untouched if the requested one has no data, so a
## bad chapter number can never strand the player in an empty battle scene.
func load_chapter(chapter_no: int) -> bool:
	var path := chapter_path(chapter_no)
	var loaded := load(path) as ChapterData if ResourceLoader.exists(path) else null
	if loaded == null:
		push_warning("GameState: could not load chapter at %s" % path)
		return false
	chapter = loaded
	encounter_index = 0
	return true

## Records ONE difficulty tier as beaten for THIS SESSION, and — if that
## completes the full Easy -> Medium -> Hard climb — marks the certificate
## earned and saves that one fact permanently. Called once, right when the
## last encounter of a run is won.
func mark_difficulty_completed(chapter_no: int, tier: String) -> void:
	var tiers: Dictionary = _session_tier_progress.get(chapter_no, {})
	tiers[tier] = true
	_session_tier_progress[chapter_no] = tiers
	for required in QuestionBank.DIFFICULTY_ORDER:
		if not tiers.get(required, false):
			return
	if certificate_earned.get(chapter_no, false):
		return
	certificate_earned[chapter_no] = true
	_save_progress()

## True once the certificate has actually been earned — Easy, Medium and Hard
## all beaten in one sitting, at some point (this fact persists; the climb
## toward it does not). Finishing tiers across separate sessions never
## satisfies this, by design.
func is_chapter_completed(chapter_no: int) -> bool:
	return certificate_earned.get(chapter_no, false)

## Is `tier` reachable right now, given what has been beaten THIS SESSION?
## Easy is always open; Medium needs Easy done this session; Hard needs Medium
## done this session. Used both to grey out the difficulty buttons and to
## defend _start_run() against launching a tier the player has not actually
## earned access to.
func is_tier_unlocked(chapter_no: int, tier: String) -> bool:
	var idx := QuestionBank.DIFFICULTY_ORDER.find(tier)
	if idx <= 0:
		return true
	var prev_tier: String = QuestionBank.DIFFICULTY_ORDER[idx - 1]
	return _session_tier_progress.get(chapter_no, {}).get(prev_tier, false)

## Which tiers are done THIS SESSION, in fixed order — lets the certificate
## panel show real progress ("Easy, Medium done — this sitting") instead of a
## flat locked/unlocked state. Resets with the session, same as the progress
## it describes.
func session_completed_tiers_for(chapter_no: int) -> Array[String]:
	var tiers: Dictionary = _session_tier_progress.get(chapter_no, {})
	var out: Array[String] = []
	for tier in QuestionBank.DIFFICULTY_ORDER:
		if tiers.get(tier, false):
			out.append(tier)
	return out

## Records the name typed onto a certificate. Saved immediately, same as
## mark_difficulty_completed — but only when it actually changed, so opening the
## certificate panel and closing it again without touching the name field
## never writes to disk.
func set_player_name(typed: String) -> void:
	var trimmed := typed.strip_edges()
	if trimmed == player_name:
		return
	player_name = trimmed
	_save_progress()

func _save_progress() -> void:
	var file := FileAccess.open(PROGRESS_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: could not write %s (%s)" % [
			PROGRESS_SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	# Only the earned flag persists -- session climb progress is intentionally
	# never written here. JSON object keys must be strings, so chapter numbers
	# are stringified.
	var serializable: Dictionary = {}
	for chapter_no in certificate_earned:
		serializable[str(chapter_no)] = true
	file.store_string(JSON.stringify({
		"certificate_earned": serializable,
		"player_name": player_name,
		"tutorial_completed": tutorial_completed,
	}))

func _load_progress() -> void:
	if not FileAccess.file_exists(PROGRESS_SAVE_PATH):
		return
	var file := FileAccess.open(PROGRESS_SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("GameState: could not read %s (%s)" % [
			PROGRESS_SAVE_PATH, error_string(FileAccess.get_open_error())])
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState: %s is not a JSON object, ignoring" % PROGRESS_SAVE_PATH)
		return
	var data := parsed as Dictionary
	# Older saves ("completed_chapters", then briefly "completed_difficulties")
	# recorded progress in ways that did not require one continuous sitting.
	# Neither can honestly satisfy the current rule, so neither is migrated --
	# a save from before this change starts the certificate at un-earned
	# rather than crediting a climb that was never actually done in one
	# sitting.
	for chapter_key in data.get("certificate_earned", {}):
		if bool(data["certificate_earned"][chapter_key]):
			certificate_earned[int(chapter_key)] = true
	player_name = String(data.get("player_name", ""))
	tutorial_completed = bool(data.get("tutorial_completed", false))

## Remembers that the tutorial was seen through to its last card. Written
## immediately rather than at the end of the session, so closing the tab on the
## END card still counts.
func mark_tutorial_completed() -> void:
	if tutorial_completed:
		return
	tutorial_completed = true
	_save_progress()

## The enemy for the encounter currently being fought, or null once the player
## has walked past the last one.
func current_enemy() -> EnemyData:
	if chapter == null:
		return null
	return chapter.encounter_at(encounter_index)

## The chosen character's sprite clips, falling back to the default rather
## than returning an empty set if `character` is ever something unexpected.
func character_clips() -> Dictionary:
	return PLAYER_CHARACTERS.get(character, PLAYER_CHARACTERS[DEFAULT_CHARACTER])

## Which chapter the player is in, for filtering questions by topic. Falls back
## to 1 so a missing chapter resource cannot leave the bank with no pool.
func chapter_number() -> int:
	return chapter.chapter_number if chapter != null else 1

## Peek, without advancing — lets the battle scene decide between staging a
## walk to the next encounter and rolling the chapter-complete screen.
func has_next_encounter() -> bool:
	if chapter == null:
		return false
	return chapter.encounter_at(encounter_index + 1) != null

## Steps to the next encounter. Returns false when the chapter is finished,
## which is the caller's cue to show the chapter-complete screen instead of
## staging another walk.
func advance_encounter() -> bool:
	encounter_index += 1
	return current_enemy() != null

## Back to the start of the chapter. Losing sends the player here — the run
## restarts from encounter one rather than retrying the enemy that beat them,
## which is what makes potion stock worth managing across a whole chapter.
func reset_chapter() -> void:
	encounter_index = 0
	reset_potions()

## 1-based, for display ("Encounter 3 of 5").
func encounter_number() -> int:
	return encounter_index + 1

func encounter_total() -> int:
	return chapter.encounter_count() if chapter != null else 0

func reset_potions() -> void:
	potions = {
		PotionType.HEALTH: STARTING_POTION_COUNT,
		PotionType.POWER: STARTING_POTION_COUNT,
		# Shelved, not deleted. Purify's only job was clearing the Mudslinging
		# Tile, and it was the one potion whose purpose was not readable from
		# its button. Starting at zero hides it without unpicking the mechanic:
		# the tile can still be cleared by spelling through it, and restoring
		# the potion is this one line.
		PotionType.PURIFY: 0,
	}

func potion_count(type: PotionType) -> int:
	return potions.get(type, 0)

func add_potion(type: PotionType, amount: int = 1) -> void:
	potions[type] = mini(potion_count(type) + amount, MAX_PER_POTION)

## Spends one unit. Returns false (and spends nothing) when the stock is
## empty, so callers can refuse the action instead of going negative.
func consume_potion(type: PotionType) -> bool:
	if potion_count(type) <= 0:
		return false
	potions[type] -= 1
	return true
