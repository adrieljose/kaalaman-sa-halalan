extends Control
## Lightweight, encounter-owned voting board and chamber lighting.
## Drawn behind combat/UI; no timers, input, or gameplay state.
var state: int = 0
var blend: float = 0.0
var elapsed: float = 0.0
var redraw_elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE

func set_stage(value: int) -> void:
	state = value
	set_process(true)
	queue_redraw()

func stop() -> void:
	state = 0
	blend = 0.0
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	redraw_elapsed += delta
	blend = move_toward(blend, float(state), delta * 1.5)
	if redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	var level := clampf(blend, 0.0, 2.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.045, 0.02, level * 0.05))
	var width := clampf(size.x * 0.14, 42.0, 88.0)
	var origin := Vector2(size.x - width - 28.0, size.y * 0.48).round()
	var box := Rect2(origin, Vector2(width, 26))
	draw_rect(box, Color("292521"))
	draw_rect(box, Color("ab8746"), false, 2.0)
	for i in 12:
		var dot := origin + Vector2(7 + (i % 6) * (width - 14) / 6.0, 6 + (i / 6) * 8)
		var lit := Color("75bb7b") if i < 9 else Color("e8c66b")
		var color := Color("45483d").lerp(lit, minf(level, 1.0))
		draw_rect(Rect2(dot.round(), Vector2(4, 4)), color)
	if level > 0.05:
		# A handful of paper slips orbit near the background voting board.
		for i in 5:
			var angle := elapsed * (0.45 + level * 0.14) + float(i) * TAU / 5.0
			var at := origin + Vector2(width / 2.0, 36.0) + Vector2(cos(angle) * width * 0.52, sin(angle) * 14.0)
			draw_rect(Rect2(at.round(), Vector2(4, 3)), Color(0.94, 0.83, 0.56, minf(level, 1.0) * 0.65))
