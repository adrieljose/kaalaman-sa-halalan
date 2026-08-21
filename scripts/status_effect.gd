class_name StatusEffect
extends Resource
## A timed effect attached to a combatant. The same shape works for either
## side — an EnemyMove's `statuses` land on the player, its `self_statuses`
## land on the enemy — so there's one type to reason about, not two.
##
## Phase 0: declared so EnemyMove has somewhere to put these once Phase 1+
## starts populating them. Nothing reads or ticks this yet.

enum Type { POWER_UP, POWER_DOWN, DOT }

@export var type: Type = Type.POWER_DOWN
@export var duration_turns: int = 1
## Meaning depends on type: a multiplier for POWER_UP/POWER_DOWN,
## damage-per-turn for DOT.
@export var magnitude: float = 0.0
