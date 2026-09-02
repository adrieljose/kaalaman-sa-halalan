class_name DamageBadge
extends Control
## The "this question is worth N" plate that sits beside the question timer.
##
## Drawn rather than assembled out of a PanelContainer, an icon TextureRect and
## a Label, for two reasons. The badge has to survive being 16 units tall on a
## rotated phone and 20 on a desktop, and a three-node container stack at that
## size spends most of its height on margins it cannot be talked out of. And
## there is no sword in assets/images/ui -- every icon in the project is a
## generated 16x16 PNG, and a whole generation spent on one glyph that is nine
## pixels of blade is not a good trade when _draw() renders it crisply at any
## size and tints with the rest of the plate.
##
## This control knows NOTHING about how damage is worked out. It is handed two
## numbers by the battle scene and draws them; see
## WordBattleController._damage_for(), which is the only place the arithmetic
## lives.

## Plate. Matched to the carved-wood panels the rest of the HUD wears rather
## than to a fresh palette, so the badge reads as part of the same furniture.
const PLATE_COLOR := Color(0.14, 0.10, 0.07)
const PLATE_SHADE := Color(0.09, 0.06, 0.04)
const BORDER_COLOR := Color(0.55, 0.41, 0.20)
const BORDER_HOT := Color(1.0, 0.78, 0.30)
const TEXT_COLOR := Color(1.0, 0.87, 0.55)
const TEXT_HOT := Color(1.0, 0.95, 0.72)
const BLADE_COLOR := Color(0.85, 0.88, 0.93)
const BLADE_SHADE := Color(0.55, 0.60, 0.68)
const HILT_COLOR := Color(0.72, 0.55, 0.24)

const PAD_X := 4.0
const ICON_GAP := 3.0

var _low: int = 0
var _high: int = 0
## True while a Power Up is primed. Only changes the plate's colour -- the
## multiplier itself is already baked into _low and _high by the caller.
var _boosted: bool = false
## Drops the " DMG" suffix. Set on the compact arrangements, where the badge
## shares a 46-unit-tall question panel with three lines of prompt.
var _terse: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

## The only entry point. `low == high` prints one number; a spread prints a
## range, which is what the speed bonus makes of an unanswered question -- see
## WordBattleController._potential_damage().
func show_damage(low: int, high: int, boosted: bool) -> void:
	if low == _low and high == _high and boosted == _boosted:
		return
	_low = low
	_high = high
	_boosted = boosted
	_remeasure()
	queue_redraw()

func set_terse(terse: bool) -> void:
	if terse == _terse:
		return
	_terse = terse
	_remeasure()
	queue_redraw()

func damage_text() -> String:
	if _low <= 0 and _high <= 0:
		return "NO DMG"
	var figure := str(_low) if _low == _high else "%d-%d" % [_low, _high]
	return figure if _terse else "%s DMG" % figure

func _font() -> Font:
	var font := get_theme_default_font()
	return font if font != null else ThemeDB.fallback_font

func _font_size() -> int:
	# Two points under the plate height keeps the digits off the border at
	# every size the layout passes ask for, from 14 units to 20.
	return clampi(int(size.y) - 6, 7, 12)

func _icon_width() -> float:
	return maxf(floorf(size.y * 0.5), 7.0)

## A badge in an HBox has to declare its own width; nothing else in the row
## knows how wide "24-31 DMG" renders in the current font.
func _remeasure() -> void:
	var font := _font()
	if font == null:
		return
	var text_w := font.get_string_size(damage_text(), HORIZONTAL_ALIGNMENT_LEFT,
		-1, _font_size()).x
	custom_minimum_size.x = ceilf(PAD_X * 2.0 + _icon_width() + ICON_GAP + text_w)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_remeasure()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var border := BORDER_HOT if _boosted else BORDER_COLOR

	draw_rect(Rect2(0, 0, w, h), border, true)
	draw_rect(Rect2(1, 1, w - 2, h - 2), PLATE_SHADE, true)
	# One-pixel lift along the top and left, the same bevel the wooden panels
	# and the timer track are drawn with.
	draw_rect(Rect2(1, 1, w - 2, h - 3), PLATE_COLOR, true)

	_draw_sword(Rect2(PAD_X, floorf((h - _icon_width() * 1.4) * 0.5),
		_icon_width(), _icon_width() * 1.4))

	var font := _font()
	if font == null:
		return
	var font_size := _font_size()
	var text := damage_text()
	var text_x := PAD_X + _icon_width() + ICON_GAP
	var baseline := floorf((h + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	# Drawn twice: the dark pass underneath is what keeps small gold digits
	# legible against a plate that is itself fairly light.
	draw_string(font, Vector2(text_x, baseline + 1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, PLATE_SHADE)
	draw_string(font, Vector2(text_x, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		TEXT_HOT if _boosted else TEXT_COLOR)

## An upright sword in whole pixels: blade, fuller, crossguard, grip, pommel.
## Sized off `area` so it stays proportionate whether the plate is 14 units
## tall or 20.
func _draw_sword(area: Rect2) -> void:
	var unit: float = maxf(floorf(area.size.x / 5.0), 1.0)
	var cx: float = floorf(area.position.x + area.size.x * 0.5)
	var top: float = floorf(area.position.y)
	var blade_h: float = maxf(floorf(area.size.y * 0.58), 3.0)
	var guard_y: float = top + blade_h
	var grip_h: float = maxf(floorf(area.size.y * 0.24), 2.0)

	draw_rect(Rect2(cx - unit, top, unit * 2.0, blade_h), BLADE_COLOR, true)
	draw_rect(Rect2(cx, top + unit, unit, blade_h - unit), BLADE_SHADE, true)
	draw_rect(Rect2(cx - unit * 2.0, guard_y, unit * 4.0, unit), HILT_COLOR, true)
	draw_rect(Rect2(cx - unit * 0.5, guard_y + unit, unit, grip_h), HILT_COLOR, true)
	draw_rect(Rect2(cx - unit, guard_y + unit + grip_h, unit * 2.0, unit), HILT_COLOR, true)
