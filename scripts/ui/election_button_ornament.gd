extends Control
class_name ElectionButtonOrnament

## Draws the civic details that turn a plain menu row into a ballot notice:
## a coloured ribbon, a checked ballot box, document rules and a seal.  It is
## event-driven rather than animated; redraws happen only when the button's
## hover, press, focus or size state changes.

var accent_color := Color(0.16, 0.34, 0.50)
var _button: Button


func setup(button: Button, accent: Color) -> void:
	_button = button
	accent_color = accent
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	if not button.mouse_entered.is_connected(queue_redraw):
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)
		button.focus_entered.connect(queue_redraw)
		button.focus_exited.connect(queue_redraw)
	if not resized.is_connected(queue_redraw):
		resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if _button == null or size.x < 84.0 or size.y < 24.0:
		return
	var accent := accent_color
	if _button.is_pressed():
		accent = accent.darkened(0.18)
	elif _button.is_hovered() or _button.has_focus():
		accent = accent.lightened(0.16)

	var h := size.y
	var centre_y := floorf(h * 0.5) + 0.5
	var ribbon_w := clampf(h * 0.18, 7.0, 10.0)
	var gold := Color(0.78, 0.57, 0.20, 0.95)
	var ink := Color(0.22, 0.13, 0.07, 0.82)

	# Notched civic ribbon at the left edge. The hard polygon and un-antialiased
	# rules stay crisp beside the project's pixel art.
	draw_colored_polygon(PackedVector2Array([
		Vector2(5.0, 5.0), Vector2(5.0 + ribbon_w, 5.0),
		Vector2(5.0 + ribbon_w, h - 5.0), Vector2(5.0, h - 5.0),
		Vector2(8.0, centre_y),
	]), accent)
	draw_line(Vector2(5.0 + ribbon_w + 3.0, 6.0),
		Vector2(5.0 + ribbon_w + 3.0, h - 6.0), gold, 1.0, false)

	# A tiny checked ballot box. It is deliberately drawn, not a Unicode glyph,
	# so it looks the same on every platform and cannot fall back to a smooth
	# system font.
	var box_size := clampf(h * 0.24, 9.0, 12.0)
	var box := Rect2(21.0, floorf(centre_y - box_size * 0.5), box_size, box_size)
	draw_rect(box, Color(0.98, 0.91, 0.72, 0.62), true)
	draw_rect(box, accent, false, 2.0, false)
	draw_polyline(PackedVector2Array([
		box.position + Vector2(2.0, box_size * 0.55),
		box.position + Vector2(box_size * 0.43, box_size - 2.0),
		box.position + Vector2(box_size + 3.0, -2.0),
	]), accent, 2.0, false)

	# Document rules guide the eye to the label without competing with it.
	draw_line(Vector2(38.0, 7.0), Vector2(size.x - 38.0, 7.0),
		Color(ink, 0.34), 1.0, false)
	draw_line(Vector2(38.0, h - 7.0), Vector2(size.x - 38.0, h - 7.0),
		Color(ink, 0.24), 1.0, false)

	# Official-looking seal and perforation at the right edge.
	var seal_at := Vector2(size.x - 20.0, centre_y)
	draw_circle(seal_at, 7.0, Color(accent, 0.22), true, -1.0, false)
	draw_arc(seal_at, 7.0, 0.0, TAU, 16, accent, 2.0, false)
	draw_circle(seal_at, 2.0, gold, true, -1.0, false)
	for y in range(8, maxi(int(h) - 7, 9), 4):
		draw_rect(Rect2(size.x - 35.0, float(y), 1.0, 1.0), Color(ink, 0.55), true)

	if _button.has_focus():
		# Corner brackets make keyboard focus explicit without a modern glow.
		var c := Color(0.98, 0.82, 0.38)
		draw_line(Vector2(2.0, 2.0), Vector2(13.0, 2.0), c, 2.0, false)
		draw_line(Vector2(2.0, 2.0), Vector2(2.0, 12.0), c, 2.0, false)
		draw_line(Vector2(size.x - 2.0, h - 2.0), Vector2(size.x - 13.0, h - 2.0), c, 2.0, false)
		draw_line(Vector2(size.x - 2.0, h - 2.0), Vector2(size.x - 2.0, h - 12.0), c, 2.0, false)
