extends Control
class_name LetterTile

enum TileType { NORMAL, GOLD, SPARK, MUD }

const TEX_NORMAL := preload("res://assets/images/tiles/tile_normal.png")
const TEX_SPARK := preload("res://assets/images/tiles/tile_spark.png")
const TEX_GOLD := preload("res://assets/images/tiles/tile_gold.png")
const TEX_MUD := preload("res://assets/images/tiles/tile_mud.png")

@onready var bg: TextureRect = $Bg
@onready var label: Label = $Label
@onready var value_label: Label = $ValueLabel

var letter: String = "A":
	set(value):
		letter = value
		_refresh()

var tile_type: TileType = TileType.NORMAL:
	set(value):
		tile_type = value
		_refresh()

## A selected tile has been lifted off the board into the word tray, so the
## cell it left behind is drawn as an empty socket — sunken and letterless.
const EMPTY_SOCKET_TINT := Color(0.42, 0.36, 0.3, 0.85)
## How long a letter spends travelling between its board cell and the word
## tray, in either direction. Defined here because it is the tile's own travel
## time: the board waits it out before restoring a returning letter, and the
## battle controller matches it when flying the ghost copy across.
const FLIGHT_TIME := 0.26

var is_selected: bool = false
## True while a deselected letter is still flying back from the tray. The cell
## keeps its empty look for that stretch, so the letter is never visible in the
## air and on the board at the same time.
var _returning: bool = false

func _ready() -> void:
	# Scale animations (the pop-back below) grow from the middle rather than
	# the top-left corner.
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	_refresh()

func set_selected(value: bool) -> void:
	is_selected = value
	# Picking a tile cancels any return still in flight for it, so a fast
	# undo-then-reselect can't leave the cell stuck looking empty.
	if value:
		_returning = false
	_refresh()

## Holds the cell empty for the length of the flight home, then pops the letter
## back in with a small overshoot. Self-contained on a tile-owned tween, so
## nothing outside has to remember to finish the animation — and freeing the
## tile mid-flight simply cancels it.
func play_return() -> void:
	if not is_node_ready():
		return
	_returning = true
	_refresh()
	var tween := create_tween()
	tween.tween_interval(FLIGHT_TIME)
	tween.tween_callback(func() -> void:
		_returning = false
		_refresh()
		scale = Vector2(0.6, 0.6))
	tween.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Cancels a pending return immediately — used when the board is reseeded out
## from under an in-flight letter.
func cancel_return() -> void:
	if not _returning:
		return
	_returning = false
	scale = Vector2.ONE
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	label.text = letter
	value_label.text = str(BoardController.letter_value(letter))
	match tile_type:
		TileType.SPARK:
			bg.texture = TEX_SPARK
		TileType.GOLD:
			bg.texture = TEX_GOLD
		TileType.MUD:
			bg.texture = TEX_MUD
		_:
			bg.texture = TEX_NORMAL
	# The letter itself travels to the tray, so it is hidden here rather than
	# merely highlighted — the board should look like the tile physically left.
	# It also stays hidden while the letter is flying back, so it doesn't
	# appear on the board before the returning copy has landed.
	var away := is_selected or _returning
	label.visible = not away
	value_label.visible = not away
	bg.modulate = EMPTY_SOCKET_TINT if away else Color(1, 1, 1)
