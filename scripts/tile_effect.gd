class_name TileEffect
extends Resource
## A board-state effect an enemy move can inflict (Tile Smash now; Lock and
## the Plague upgrade of the Mud Tile arrive in Phase 2). Declared as part of
## the Phase 0 EnemyMove component model — nothing populates or reads this
## yet.

enum Type { SMASH, LOCK, PLAGUE }

@export var type: Type = Type.SMASH
@export var count: int = 1
@export var duration_turns: int = 3
