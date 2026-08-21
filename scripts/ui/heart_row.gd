extends HBoxContainer
class_name HeartRow
## Drop-in replacement for HpBar with the same set_max()/set_value() API,
## but drawn as a row of heart icons instead of a bar.

const TEX_FULL := preload("res://assets/images/ui/heart_full.png")
const TEX_EMPTY := preload("res://assets/images/ui/heart_empty.png")
const HP_PER_HEART := 20
const HEART_SIZE := Vector2(15, 15)
const HEART_SEPARATION := 3
## The panel these rows sit in is 250px wide. A boss at 300 HP draws 15 hearts,
## which only fits if the icons shrink — so the row is sized to the space
## available rather than assuming every enemy has six hearts like Lord Trapo.
@export var max_row_width: float = 240.0
## When > 0, always draw exactly this many hearts and let each one stand for a
## share of max HP rather than a fixed 20 points.
##
## The HUD sets 5. It costs the "this boss has more total HP than that one"
## read — restored by the numeric beside the row — and buys two things back:
## a 300 HP boss no longer needs fifteen shrinking icons to fit its plate, and
## both fighters' health become directly comparable at a glance, which is the
## thing a player actually needs mid-fight.
@export var fixed_heart_count: int = 0

## Optional companion label printing the exact numbers beside the hearts.
##
## Hearts answer "roughly how much is left" at a glance; the number answers
## "exactly how much" for anyone who wants it, and is the only thing that
## distinguishes a 300 HP boss from a 120 HP one once both are drawn as a full
## row. Kept here rather than updated by the battle scene so that every
## existing set_value() call site keeps the readout in sync for free.
var readout: Label = null

var max_value: int = 100
var current_value: int = 100

func set_max(value: int) -> void:
	max_value = value
	current_value = value
	_rebuild()

func set_value(v: int, _animate: bool = true) -> void:
	current_value = clampi(v, 0, max_value)
	_refresh_icons()

func _heart_count() -> int:
	if fixed_heart_count > 0:
		return fixed_heart_count
	return maxi(1, ceili(float(max_value) / float(HP_PER_HEART)))

## Largest square that lets `count` hearts plus their gaps fit the row, capped
## at the normal icon size so small enemies don't get comically large hearts.
func _icon_size(count: int) -> Vector2:
	var gaps := float(maxi(0, count - 1) * HEART_SEPARATION)
	var per_heart := (max_row_width - gaps) / float(count)
	var side := minf(HEART_SIZE.x, floorf(per_heart))
	return Vector2(maxf(side, 4.0), maxf(side, 4.0))

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", HEART_SEPARATION)
	var count := _heart_count()
	var icon_size := _icon_size(count)
	for i in count:
		var icon := TextureRect.new()
		icon.custom_minimum_size = icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(icon)
	_refresh_icons()

func _refresh_icons() -> void:
	var count := _heart_count()
	# Floor rather than round, with a floor of one heart while alive: rounding
	# let 90/100 still show a full row, so the first few hits landed with no
	# visible feedback at all. Now the row only reads full when it IS full, and
	# only reads empty when the fighter is actually down.
	var ratio := float(current_value) / float(maxi(max_value, 1))
	var filled := 0
	if current_value > 0:
		filled = clampi(floori(ratio * count), 1, count)
	var children := get_children()
	for i in children.size():
		(children[i] as TextureRect).texture = TEX_FULL if i < filled else TEX_EMPTY
	if readout != null:
		readout.text = "%d/%d" % [current_value, max_value]
