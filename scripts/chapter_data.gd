class_name ChapterData
extends Resource
## One chapter: an ordered run of encounters the player walks through from
## left to right, ending at a boss.
##
## Order in `encounters` IS the progression order — there are no per-encounter
## world coordinates here. The reference doc models progression as increasing
## X, but this game fights in a single fixed-layout screen rather than a
## scrolling world, so "walking right" is staged as a transition between
## encounters (see WordBattleController._advance_to_next_encounter) and the
## only thing that actually needs persisting is which index we're on.

@export var chapter_number: int = 1
@export var chapter_name: String = ""
@export var encounters: Array[EnemyData] = []

func encounter_count() -> int:
	return encounters.size()

## Returns null rather than erroring past the end, so callers can treat
## "no more encounters" as the chapter-complete signal.
func encounter_at(index: int) -> EnemyData:
	if index < 0 or index >= encounters.size():
		return null
	return encounters[index]
