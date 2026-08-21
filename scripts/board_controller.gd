extends Control
class_name BoardController
## A letter board: click any tile in any order to spell a word (no adjacency
## requirement), drop/refill, and a rotating Spark Tile. Combat rules live one
## layer up, in whatever controller owns this board — this node only knows
## about words and tiles.

signal word_accepted(word: String, used_spark: bool, used_gold: bool)
signal word_rejected(word: String)
signal selection_changed(current_text: String)
## A tile was just picked, with the screen rect it occupied. Purely an
## animation cue for the layer above (which flies a ghost tile up to the word
## tray) — the tray's actual contents still come from selection_changed, so a
## dropped or mistimed cue can never desync what the word says.
signal tile_lifted(letter: String, from_global_rect: Rect2)
## A letter was dropped from the word and is going back to its cell, with the
## tray slot it occupied (index within a word of `tray_total` letters) and the
## board rect it is returning to. The counterpart cue to tile_lifted, and just
## as decorative — the selection has already been updated by the time it fires.
signal tile_returned(letter: String, tray_index: int, tray_total: int, to_global_rect: Rect2)
## Fired when an ignored Mudslinging Tile finishes spreading — the layer above
## applies the player-damage penalty.
signal mud_detonated

const COLS := 6
const ROWS := 6
## 6 tiles + 5 gaps = 231px square, which is what the Board node in
## word_battle.tscn is sized to. Changing either of these means resizing that
## node (and BoardFrame around it) to match, or tiles will spill past the frame.
const TILE_SIZE := 36.0
const TILE_GAP := 3.0
const LETTER_POOL := "AAAAAAAAABBCCDDDDEEEEEEEEEEEEFFGGGHHIIIIIIIIIJKLLLLMMNNNNNNOOOOOOOOPPQRRRRRRSSSSTTTTTTUUUUVVWWXYYZ"

## Scrabble-standard letter values — rarer letters hit harder. This is the
## damage base now, replacing plain word length.
const LETTER_VALUES := {
	"A": 1, "E": 1, "I": 1, "O": 1, "U": 1, "L": 1, "N": 1, "S": 1, "T": 1, "R": 1,
	"D": 2, "G": 2,
	"B": 3, "C": 3, "M": 3, "P": 3,
	"F": 4, "H": 4, "V": 4, "W": 4, "Y": 4,
	"K": 5,
	"J": 8, "X": 8,
	"Q": 10, "Z": 10,
}

## A word of this length or longer earns a Gold Tile (spawns on a random
## normal tile once the word resolves).
const GOLD_WORD_LENGTH := 5
## Turns between Mudslinging Tile spawns (only while none is on the board).
const MUD_SPAWN_INTERVAL := 4
## Turns a Mudslinging Tile can be ignored before it detonates.
const MUD_DETONATE_TURNS := 2

@export var tile_scene: PackedScene

var grid: Array = []
var _selected_cells: Array[Vector2i] = []
var _spark_tile: LetterTile = null
## Letters the current question's answer needs. The board guarantees these are
## always present, so a question can never become unanswerable after tiles
## clear and refill.
var _required_answer: String = ""
var _mud_tile: LetterTile = null
var _mud_turns_ignored: int = 0
var _turns_since_mud_spawn: int = 0

static func letter_value(letter: String) -> int:
	return LETTER_VALUES.get(letter.to_upper(), 1)

static func word_value(word: String) -> int:
	var total := 0
	for letter in word:
		total += letter_value(letter)
	return total

func _ready() -> void:
	randomize()
	gui_input.connect(_on_board_gui_input)
	_build_grid()

func _build_grid() -> void:
	grid.clear()
	for col in COLS:
		var col_array: Array = []
		col_array.resize(ROWS)
		grid.append(col_array)
	for col in COLS:
		for row in ROWS:
			_spawn_tile(col, row)
	_designate_spark_tile()

func _random_letter() -> String:
	return LETTER_POOL[randi() % LETTER_POOL.length()]

func _cell_position(col: int, row: int) -> Vector2:
	return Vector2(col * (TILE_SIZE + TILE_GAP), row * (TILE_SIZE + TILE_GAP))

func _spawn_tile(col: int, row: int) -> void:
	var tile: LetterTile = tile_scene.instantiate()
	tile.position = _cell_position(col, row)
	add_child(tile)
	tile.letter = _random_letter()
	grid[col][row] = tile

func _normal_tile_candidates() -> Array[LetterTile]:
	var candidates: Array[LetterTile] = []
	for col in COLS:
		for row in ROWS:
			var t: LetterTile = grid[col][row]
			if t != null and t.tile_type == LetterTile.TileType.NORMAL:
				candidates.append(t)
	return candidates

func _designate_spark_tile() -> void:
	if _spark_tile != null:
		return
	var candidates := _normal_tile_candidates()
	if candidates.is_empty():
		return
	_spark_tile = candidates[randi() % candidates.size()]
	_spark_tile.tile_type = LetterTile.TileType.SPARK

## Earned by playing a GOLD_WORD_LENGTH+ word: converts a random plain tile
## into a Gold Tile, which doubles the word's damage whenever it's used.
func _spawn_gold_tile() -> void:
	var candidates := _normal_tile_candidates()
	if candidates.is_empty():
		return
	candidates[randi() % candidates.size()].tile_type = LetterTile.TileType.GOLD

## Spawns a Mudslinging Tile on a random plain tile once enough turns have
## passed without one on the board — this is the actual pressure mechanic.
func _maybe_spawn_mud() -> void:
	if _mud_tile != null or _turns_since_mud_spawn < MUD_SPAWN_INTERVAL:
		return
	var candidates := _normal_tile_candidates()
	if candidates.is_empty():
		return
	_mud_tile = candidates[randi() % candidates.size()]
	_mud_tile.tile_type = LetterTile.TileType.MUD
	_turns_since_mud_spawn = 0
	_mud_turns_ignored = 0

## Called on every accepted word that didn't clear the Mudslinging Tile —
## it spreads (figuratively, via the ignored-turn counter) and detonates for
## player damage once MUD_DETONATE_TURNS is reached.
func _advance_mud_pressure() -> void:
	if _mud_tile == null:
		return
	_mud_turns_ignored += 1
	if _mud_turns_ignored >= MUD_DETONATE_TURNS:
		_mud_tile.tile_type = LetterTile.TileType.NORMAL
		_mud_tile = null
		_mud_turns_ignored = 0
		mud_detonated.emit()

## Points the board at a new question's answer and lays the board out fresh so
## those letters are on it. Passing "" drops the requirement entirely.
func set_required_answer(answer: String) -> void:
	_required_answer = answer.to_upper()
	if _required_answer.length() > COLS * ROWS:
		push_warning("BoardController: answer '%s' is longer than the board" % _required_answer)
		_required_answer = ""
	_reseed_board()

func required_answer() -> String:
	return _required_answer

## Scatters the answer's letters across random cells and fills whatever's left
## with the usual random draw, then clears any special tiles so a new question
## starts from a clean board.
func _reseed_board() -> void:
	var cells: Array[Vector2i] = []
	for col in COLS:
		for row in ROWS:
			cells.append(Vector2i(col, row))
	cells.shuffle()

	for i in cells.size():
		var cell: Vector2i = cells[i]
		var tile: LetterTile = grid[cell.x][cell.y]
		if tile == null:
			continue
		# A reseed replaces this cell's letter outright, so any return still
		# flying to it is stale — drop it rather than let it un-hide a letter
		# that no longer belongs here.
		tile.cancel_return()
		tile.tile_type = LetterTile.TileType.NORMAL
		tile.letter = _required_answer[i] if i < _required_answer.length() else _random_letter()

	_clear_selection_visuals()
	_selected_cells.clear()
	_spark_tile = null
	_mud_tile = null
	_mud_turns_ignored = 0
	_turns_since_mud_spawn = 0
	_designate_spark_tile()
	selection_changed.emit("")

## Which of the answer's letters aren't on the board right now, counting
## duplicates — "SECRECY" needs three E/C/... slots, not just one of each.
func _missing_answer_letters() -> String:
	if _required_answer.is_empty():
		return ""
	var available: Dictionary = {}
	for col in COLS:
		for row in ROWS:
			var tile: LetterTile = grid[col][row]
			if tile != null:
				available[tile.letter] = available.get(tile.letter, 0) + 1
	var missing := ""
	for ch in _required_answer:
		if available.get(ch, 0) > 0:
			available[ch] -= 1
		else:
			missing += ch
	return missing

## Called after tiles clear and refill: spelling an ordinary word can consume
## letters the answer still needs, so any that went missing are written back
## onto random plain tiles. Without this a question could become impossible.
func _restore_answer_letters() -> void:
	var missing := _missing_answer_letters()
	if missing.is_empty():
		return
	var candidates := _normal_tile_candidates()
	candidates.shuffle()
	for i in mini(missing.length(), candidates.size()):
		candidates[i].letter = missing[i]

func has_contamination() -> bool:
	return _mud_tile != null

## Purify Potion: scrubs contamination off the grid without costing a turn.
## The Mudslinging Tile is our only contaminated-tile type so far, so that's
## all there is to clean — the pressure counters reset with it.
func purify() -> bool:
	if _mud_tile == null:
		return false
	_mud_tile.tile_type = LetterTile.TileType.NORMAL
	_mud_tile = null
	_mud_turns_ignored = 0
	_turns_since_mud_spawn = 0
	return true

## Reassigns every tile a fresh random letter and clears all special tiles,
## same as Bookworm's reshuffle — but it costs you: a Mudslinging Tile spawns
## immediately regardless of the normal spawn interval.
##
## The current answer's letters are re-scattered rather than thrown away, so
## shuffling out of a bad board can never strand the question.
func shuffle_board() -> void:
	_reseed_board()
	_turns_since_mud_spawn = MUD_SPAWN_INTERVAL
	_maybe_spawn_mud()

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS

func _position_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / (TILE_SIZE + TILE_GAP)), int(pos.y / (TILE_SIZE + TILE_GAP)))

func _on_board_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_tile_click(mb.position)

## Click-to-build: each tap either adds any unselected tile to the word (no
## adjacency requirement — any tile, any order), or — if you tap a tile that's
## already part of the word — rewinds the selection back to just before it,
## deselecting that tile and everything picked after it. Tapping the first
## letter of the word this way clears the whole selection. Submission happens
## separately, via submit_word() wired to the Attack button.
func _handle_tile_click(pos: Vector2) -> void:
	var cell := _position_to_cell(pos)
	if not _is_valid_cell(cell) or grid[cell.x][cell.y] == null:
		return

	var existing_index := _selected_cells.find(cell)
	if existing_index != -1:
		_truncate_selection(existing_index - 1)
		Audio.play_sfx("tile_tap")
		return

	_selected_cells.append(cell)
	var tile: LetterTile = grid[cell.x][cell.y]
	var letter := tile.letter
	var from_rect := tile.get_global_rect()
	tile.set_selected(true)
	Audio.play_sfx("tile_tap")
	# Order matters: the tray is rebuilt from selection_changed first, so by the
	# time the cue fires there is a destination chip to fly toward.
	_emit_selection_changed()
	tile_lifted.emit(letter, from_rect)

## Deselects the letter at `index` in the current word and everything picked
## after it. Clicking a chip in the word tray routes here, so undoing from the
## tray behaves exactly like tapping the letter's cell on the board.
func deselect_from(index: int) -> void:
	if index < 0 or index >= _selected_cells.size():
		return
	_truncate_selection(index - 1)

## Drops every selected cell after `keep_index` (0-based, inclusive of what
## stays). Pass -1 to clear the whole selection.
func _truncate_selection(keep_index: int) -> void:
	# Captured up front: each letter's tray slot has to be described against the
	# word as it looked when the click happened, not as it shrinks mid-loop.
	var tray_total := _selected_cells.size()
	for i in range(tray_total - 1, keep_index, -1):
		var c: Vector2i = _selected_cells[i]
		var tile: LetterTile = grid[c.x][c.y]
		tile.set_selected(false)
		tile.play_return()
		tile_returned.emit(tile.letter, i, tray_total, tile.get_global_rect())
		_selected_cells.remove_at(i)
	_emit_selection_changed()

func _emit_selection_changed() -> void:
	selection_changed.emit(_current_word())

func _current_word() -> String:
	var word := ""
	for cell in _selected_cells:
		word += (grid[cell.x][cell.y] as LetterTile).letter
	return word

## Submits the currently built word. Called by the Attack button.
func submit_word() -> void:
	var word := _current_word()
	var cells := _selected_cells.duplicate()
	_clear_selection_visuals()
	_selected_cells.clear()
	selection_changed.emit("")

	if is_submittable(word):
		var used_spark := _selection_uses_type(cells, LetterTile.TileType.SPARK)
		var used_gold := _selection_uses_type(cells, LetterTile.TileType.GOLD)
		var used_mud := _selection_uses_type(cells, LetterTile.TileType.MUD)
		if used_spark:
			_spark_tile = null
		if used_mud:
			_mud_tile = null
			_mud_turns_ignored = 0
		else:
			_advance_mud_pressure()
		_clear_and_refill(cells)
		_designate_spark_tile()
		if word.length() >= GOLD_WORD_LENGTH:
			_spawn_gold_tile()
		_turns_since_mud_spawn += 1
		_maybe_spawn_mud()
		_restore_answer_letters()
		word_accepted.emit(word, used_spark, used_gold)
	else:
		word_rejected.emit(word)

## While a question is up, the ONLY accepted word is its answer — a valid but
## wrong word can't be attacked with. (Answers like COMELEC aren't dictionary
## words, so the dictionary can't be the gate here anyway.)
##
## With no question loaded the board falls back to plain dictionary rules, so
## it still behaves sensibly if the question bank is missing.
func is_submittable(word: String) -> bool:
	if word.length() < 3:
		return false
	if not _required_answer.is_empty():
		return word.to_upper() == _required_answer
	return WordValidator.is_valid_word(word)

func _selection_uses_type(cells: Array[Vector2i], type: LetterTile.TileType) -> bool:
	for cell in cells:
		var t: LetterTile = grid[cell.x][cell.y]
		if t != null and t.tile_type == type:
			return true
	return false

func _clear_selection_visuals() -> void:
	for cell in _selected_cells:
		var t: LetterTile = grid[cell.x][cell.y]
		if t != null:
			t.set_selected(false)

func _clear_and_refill(cleared_cells: Array[Vector2i]) -> void:
	var affected_cols: Dictionary = {}
	for cell in cleared_cells:
		var tile: LetterTile = grid[cell.x][cell.y]
		if tile:
			tile.queue_free()
		grid[cell.x][cell.y] = null
		affected_cols[cell.x] = true

	for col in affected_cols.keys():
		_collapse_column(col)

func _collapse_column(col: int) -> void:
	var remaining: Array[LetterTile] = []
	for row in ROWS:
		var t: LetterTile = grid[col][row]
		if t != null:
			remaining.append(t)
			grid[col][row] = null

	var write_row := ROWS - 1
	for i in range(remaining.size() - 1, -1, -1):
		var t: LetterTile = remaining[i]
		grid[col][write_row] = t
		t.position = _cell_position(col, write_row)
		write_row -= 1

	for row in range(write_row, -1, -1):
		_spawn_tile(col, row)
