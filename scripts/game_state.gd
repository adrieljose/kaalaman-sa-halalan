extends Node
## Tracks run-scoped progress: potion stock, and how far through the current
## chapter the player has walked.

const CHAPTER_PATH := "res://data/chapters/chapter_01.tres"

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
		"idle_dir": "res://assets/images/characters/player_idle", "idle_count": 5,
		"attack_dir": "res://assets/images/characters/player_attack", "attack_count": 7,
		"hit_dir": "res://assets/images/characters/player_hit", "hit_count": 5,
		"walk_dir": "res://assets/images/characters/player_walk", "walk_count": 9,
	},
	"female": {
		"label": "MARIA",
		"idle_dir": "res://assets/images/characters/player_female_idle", "idle_count": 5,
		"attack_dir": "res://assets/images/characters/player_female_attack", "attack_count": 7,
		"hit_dir": "res://assets/images/characters/player_female_hit", "hit_count": 5,
		"walk_dir": "res://assets/images/characters/player_female_walk", "walk_count": 9,
		# Her frames were generated facing the other way to the boy's, which
		# read as turning her back on the rival she is fighting. Mirroring is a
		# display flag rather than re-generated art: the sprites are close to
		# front-on, so a flip costs nothing and needs no new PixelLab credits.
		"flip_h": true,
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

## Which chapters the player has beaten at least once, keyed by chapter number.
## This is the game's only persisted state — everything else in GameState is
## scoped to the current run and starts fresh each launch. It has to survive
## the app closing, because "beat chapter 1" is a one-time unlock (the
## certificate) rather than something the current session remembers.
var completed_chapters: Dictionary = {}
## Whatever name the player last typed onto a certificate, remembered so they
## are not retyping it every time they come back to claim one. Empty until
## they claim a certificate for the first time.
var player_name: String = ""
const PROGRESS_SAVE_PATH := "user://progress.save"

func _ready() -> void:
	reset_potions()
	chapter = load(CHAPTER_PATH) as ChapterData
	if chapter == null:
		push_warning("GameState: could not load chapter at %s" % CHAPTER_PATH)
	_load_progress()

## Records a chapter as beaten and saves immediately. Called once, right when
## the last encounter is won — not on every visit — so re-clearing an
## already-completed chapter does not thrash the save file.
func mark_chapter_completed(chapter_no: int) -> void:
	if completed_chapters.get(chapter_no, false):
		return
	completed_chapters[chapter_no] = true
	_save_progress()

func is_chapter_completed(chapter_no: int) -> bool:
	return completed_chapters.get(chapter_no, false)

## Records the name typed onto a certificate. Saved immediately, same as
## mark_chapter_completed — but only when it actually changed, so opening the
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
	# Keys only — a chapter is either completed or it isn't, there's no value
	# worth storing per chapter. JSON.stringify needs an Array, not a
	# Dictionary's raw key set, hence the explicit collection.
	var completed: Array = completed_chapters.keys()
	file.store_string(JSON.stringify({
		"completed_chapters": completed,
		"player_name": player_name,
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
	for chapter_no in data.get("completed_chapters", []):
		completed_chapters[int(chapter_no)] = true
	player_name = String(data.get("player_name", ""))

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
		PotionType.PURIFY: STARTING_POTION_COUNT,
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
