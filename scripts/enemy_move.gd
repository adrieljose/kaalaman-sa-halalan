class_name EnemyMove
extends Resource
## A telegraphed enemy attack, built from independent components rather than
## a single damage number — matching the doc's "component-based attack
## system" (Bookworm Adventures Vol.1 Enemy Attack Mechanics §12-13). A move
## can carry any combination of these; most will only ever use one or two.
##
## Phase 0 only exercises `direct_damage` — Lord Trapo's three moves still
## just deal damage. The other fields exist so Phase 1+ (Power Down, Heal,
## Tile Smash, ...) don't require touching this shape again.

## Stable slug ("padrino_favor") keying this move's signature animation in
## WordBattleController and its two sound files in assets/audio/sfx/moves.
## One id drives both, so a skill can never end up with one skill's picture and
## another's noise. Left empty it is derived from move_name, and an id with no
## matching animation or audio falls back to the generic attack rather than
## breaking the turn.
@export var move_id: String = ""

@export var move_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

## One-time effects, resolved immediately when the move lands.
@export var direct_damage: int = 0
@export var self_heal: int = 0

## Ongoing effects that persist across turns. `statuses` land on the player;
## `self_statuses` land on the enemy that used the move.
@export var statuses: Array[StatusEffect] = []
@export var self_statuses: Array[StatusEffect] = []

## Board-state effects (Tile Smash, Lock, Plague).
@export var tile_effects: Array[TileEffect] = []

## How this move looks when it lands.
##
## There is no per-skill sprite art — the character sheets have one attack clip
## each — so a move's identity is carried by its motion instead: how the rival
## moves, how many projectiles cross the screen and in what pattern, and how
## hard the hit lands. `animation_style` picks the pattern and `effect_color`
## tints it, so two moves sharing a style still read as different attacks.
##
##   lunge  — one fast bolt, rival drives forward behind it
##   volley — three staggered shots, rival hops back with each
##   slam   — no projectile; the rival looms and the screen takes the hit
##   spray  — a wide fan of small motes
##   curse  — one slow, drifting mote that creeps across
@export_enum("lunge", "volley", "slam", "spray", "curse") var animation_style: String = "lunge"
@export var effect_color: Color = Color(0.75, 0.35, 0.85, 0.95)

## Per-skill attack frames. Empty means "use the rival's default attack clip".
##
## One clip per character was enough while every skill shared the same swing;
## a skill with its own generated animation needs somewhere to name it, and
## naming it here keeps the mapping with the skill rather than in a lookup
## table the battle scene would have to maintain.
@export var attack_dir: String = ""
@export var attack_count: int = 0

## The id to look up, falling back to a slug of the display name so a move
## that never got an explicit id still finds its assets.
func signature_id() -> String:
	if not move_id.is_empty():
		return move_id
	return move_name.strip_edges().to_lower().replace(" ", "_")
