class_name EnemyData
extends Resource

@export var enemy_name: String = ""
@export var title: String = ""
@export var max_hp: int = 100
@export var portrait: Texture2D
## Where this encounter is fought. Each encounter carries its own backdrop, so
## walking right through the chapter visibly travels somewhere rather than
## replaying the same room with a different opponent in it. Left null, the
## previous encounter's backdrop simply stays up.
@export var background: Texture2D
@export_multiline var lore: String = ""
## Chapter bosses get a louder introduction and end the chapter when beaten.
## Flagged explicitly rather than inferred from "last in the list" so a chapter
## can hold a mid-run miniboss later without changing how this is read.
@export var is_boss: bool = false
## Telegraphed attacks, cycled round-robin. The side panel always shows
## whichever move is next; its damage lands when the Mudslinging Tile detonates.
@export var moves: Array[EnemyMove] = []

## Sprite clips, mirroring AnimatedCharacter's own fields so swapping enemies
## mid-chapter is a straight copy across rather than a naming convention the
## two files have to agree on. Frame counts are stored because the loader walks
## frame_0..frame_N-1 and has no way to count the folder at runtime.
@export_dir var idle_dir: String = ""
@export var idle_count: int = 0
@export_dir var attack_dir: String = ""
@export var attack_count: int = 0
@export_dir var hit_dir: String = ""
@export var hit_count: int = 0

## Optional walk cycle. Only rivals with generated walk frames have one; the
## rest fall back to the cut-out rig for their melee approach.
@export var walk_dir: String = ""
@export var walk_count: int = 0

## Mirrors a rival whose frames were drawn facing right. The player stands on
## the left, so a rival that faces right is turned away from the fight. This is
## a display flag rather than re-drawn art: the sprites are near enough to
## front-on that a flip costs nothing and needs no new generation credits.
@export var flip_h: bool = false
