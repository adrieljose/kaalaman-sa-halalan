extends Control
class_name HpBar

@onready var bg: ColorRect = $Bg
@onready var fill: ColorRect = $Fill

var max_value: int = 100
var current_value: int = 100

func _ready() -> void:
	fill.size.x = bg.size.x

func set_max(value: int) -> void:
	max_value = value
	current_value = value
	if is_node_ready():
		fill.size.x = bg.size.x

func set_value(v: int, animate: bool = true) -> void:
	current_value = clampi(v, 0, max_value)
	var target_width: float = bg.size.x * (float(current_value) / float(max_value))
	if animate:
		var tween := create_tween()
		tween.tween_property(fill, "size:x", target_width, 0.3).set_trans(Tween.TRANS_CUBIC)
	else:
		fill.size.x = target_width
