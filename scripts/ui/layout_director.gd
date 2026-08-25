extends Node
## Autoloaded as `Layout`. The single place that decides what kind of screen the
## game is running on, and the single place that touches the window's content
## scale. Everything else subscribes to `layout_changed` and lays itself out.
##
## ## Why this exists
##
## The game was authored at a locked 640x480 canvas, scaled whole to whatever
## window it landed in. That is fine on a monitor and hostile on a phone: a
## 36px letter tile arrives at ~22 CSS px, roughly half the 44px that a finger
## can reliably hit, and 10px hint text becomes unreadable.
##
## ## The one dial
##
## Rather than resizing a hundred elements per device, we resize the *canvas*.
## With CONTENT_SCALE_MODE_CANVAS_ITEMS + ASPECT_EXPAND, `content_scale_size` is
## a guaranteed-visible minimum and the roomier axis reveals extra design space.
## Asking for a SMALLER base on a phone means fewer design units span the same
## glass, so every unit — tile, button, glyph — becomes physically bigger by the
## same factor, with no art rescaled relative to anything else.
##
## Worked example, phone portrait on a 390 CSS px wide screen: base 320 wide
## gives scale 390/320 = 1.22, so a 36-unit tile lands at ~44 CSS px and a
## 44-unit button at ~54. One number bought both.
##
## ## Why the scale is not integer-snapped
##
## Godot offers CONTENT_SCALE_STRETCH_INTEGER, which is the textbook answer for
## pixel art. We deliberately do not use it: flooring 1.22 to 1.0 would throw
## away exactly the enlargement that makes the phone layout tappable, and hand
## back the letterboxing we are trying to remove. Nearest-neighbour filtering is
## already on globally (project.godot `default_texture_filter=0`), so fractional
## scaling here is crisp-but-slightly-uneven rather than blurry. Fit and
## reachability beat a perfect pixel grid on a device held in one hand.

signal layout_changed(profile: LayoutProfile)

## Base canvas per device. These are the numbers the whole design rests on;
## everything else is derived. See _base_for() for the reasoning behind each.
const BASE_PHONE_PORTRAIT := Vector2i(320, 560)
const BASE_PHONE_LANDSCAPE := Vector2i(480, 270)
const BASE_TABLET_PORTRAIT := Vector2i(480, 640)
const BASE_WIDE := Vector2i(640, 480)

## Phone/tablet line, in CSS pixels of the SHORT screen edge. 600 is the
## conventional break: a 7" tablet is ~600 across, the largest phones stop
## around 480.
const PHONE_MAX_SHORT_SIDE := 600.0

## Tablet/desktop line, measured on the LONG edge rather than the short one.
##
## The short edge cannot tell these apart: a 1280x960 monitor and a 1024x768
## tablet have short edges of 960 and 768, so any threshold that catches the
## monitor also catches plenty of tablets. The long edge separates them cleanly
## — and it is the honest signal anyway, since what actually distinguishes a
## desktop here is total pixel budget, not shape.
const DESKTOP_MIN_LONG_SIDE := 1200.0

## Effect density per class. Phones are the only devices where the heaviest
## signature moves (14 nodes / 32 tweens in a single frame) risk dropping
## frames, so they get the real cut; tablets get a mild one.
const FX_BUDGET_PHONE := 0.55
const FX_BUDGET_TABLET := 0.8
const FX_BUDGET_DESKTOP := 1.0

var profile: LayoutProfile = LayoutProfile.new()

## What we last handed to the window. Applying a content scale itself resizes
## the viewport, which re-fires size_changed — without this the refresh would
## chase its own tail forever.
var _applied_base: Vector2i = Vector2i.ZERO
var _applied_design: Vector2 = Vector2.ZERO

func _ready() -> void:
	get_viewport().size_changed.connect(_refresh)
	_refresh()

## Recomputes the profile and, if anything actually moved, re-applies the
## content scale and tells everyone. Safe to call at any time; converges in two
## passes (one to set the base, one to observe the design size it produced).
func _refresh() -> void:
	var window := get_window()
	if window == null:
		return

	var css := _css_window_size()
	var portrait := css.y >= css.x
	var device := _classify(minf(css.x, css.y), maxf(css.x, css.y), portrait)
	var base := _base_for(device)

	if base != _applied_base:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		window.content_scale_size = base
		_applied_base = base

	# Read the design space back rather than predicting it: EXPAND's exact
	# result depends on rounding we do not want to reimplement here.
	var design := get_viewport().get_visible_rect().size
	if base == _applied_base and design.is_equal_approx(_applied_design) and _applied_design != Vector2.ZERO:
		return
	_applied_design = design

	profile = LayoutProfile.new()
	profile.device = device
	profile.arrangement = _arrangement_for(device)
	profile.base_size = base
	profile.design_size = design
	profile.fx_budget = _fx_budget_for(device)
	profile.is_touch = _is_touch(device)
	layout_changed.emit(profile)

## The window size in CSS pixels — the unit that actually correlates with
## physical size, and therefore the only honest basis for "is this a phone".
##
## Godot reports the window in backing-store pixels, which on a 3x phone is
## three times the CSS size and would classify a 390px phone as a desktop. On
## web we ask the browser directly; elsewhere we divide out the display scale.
func _css_window_size() -> Vector2:
	if OS.has_feature("web"):
		var w: Variant = JavaScriptBridge.eval("window.innerWidth", true)
		var h: Variant = JavaScriptBridge.eval("window.innerHeight", true)
		if w != null and h != null and float(w) > 0.0 and float(h) > 0.0:
			return Vector2(float(w), float(h))
	var size := Vector2(DisplayServer.window_get_size())
	var scale: float = maxf(DisplayServer.screen_get_scale(), 1.0)
	return size / scale

## Which of the five screens are we on?
##
## NOTE (open question for review): the second branch below decides that a
## narrow *desktop browser window* — someone dragging their browser to half the
## monitor — is treated as a phone. That is literally honest about the space
## available, and it is what a responsive website would do. The alternative is
## to trust the pointer instead of the pixels, and keep a narrow desktop window
## on the WIDE layout with a horizontal squeeze. Say the word and this flips.
func _classify(short_side: float, long_side: float, portrait: bool) -> LayoutProfile.Device:
	if short_side < PHONE_MAX_SHORT_SIDE:
		return LayoutProfile.Device.PHONE_PORTRAIT if portrait else LayoutProfile.Device.PHONE_LANDSCAPE
	if long_side >= DESKTOP_MIN_LONG_SIDE:
		return LayoutProfile.Device.DESKTOP
	return LayoutProfile.Device.TABLET_PORTRAIT if portrait else LayoutProfile.Device.TABLET_LANDSCAPE

## The canvas we ask for, per device.
##
## - Phone portrait 320x560: 320 is the narrowest phone still sold (iPhone SE),
##   so it is the width every phone is guaranteed to afford. Taller phones spend
##   their extra aspect on height, which is exactly where the stacked layout
##   wants it.
## - Phone landscape 480x270: a rotated phone has almost no height, so the base
##   height is the binding constraint and 270 is the least that still fits a
##   character, a question and a control row.
## - Tablet portrait 480x640: same stacked arrangement as a phone, but a tablet
##   can afford more units without anything becoming too small to hit.
## - Everything wide 640x480: the original canvas, untouched. A 4:3 window is
##   therefore pixel-identical to the pre-responsive build.
func _base_for(device: LayoutProfile.Device) -> Vector2i:
	match device:
		LayoutProfile.Device.PHONE_PORTRAIT:
			return BASE_PHONE_PORTRAIT
		LayoutProfile.Device.PHONE_LANDSCAPE:
			return BASE_PHONE_LANDSCAPE
		LayoutProfile.Device.TABLET_PORTRAIT:
			return BASE_TABLET_PORTRAIT
		_:
			return BASE_WIDE

func _arrangement_for(device: LayoutProfile.Device) -> LayoutProfile.Arrangement:
	match device:
		LayoutProfile.Device.PHONE_PORTRAIT, LayoutProfile.Device.TABLET_PORTRAIT:
			return LayoutProfile.Arrangement.PORTRAIT
		LayoutProfile.Device.PHONE_LANDSCAPE:
			return LayoutProfile.Arrangement.LANDSCAPE_COMPACT
		_:
			return LayoutProfile.Arrangement.WIDE

func _fx_budget_for(device: LayoutProfile.Device) -> float:
	match device:
		LayoutProfile.Device.PHONE_PORTRAIT, LayoutProfile.Device.PHONE_LANDSCAPE:
			return FX_BUDGET_PHONE
		LayoutProfile.Device.TABLET_PORTRAIT, LayoutProfile.Device.TABLET_LANDSCAPE:
			return FX_BUDGET_TABLET
		_:
			return FX_BUDGET_DESKTOP

## Touch is assumed for anything phone- or tablet-shaped rather than probed,
## because the probe lies in both directions: a touchscreen laptop reports true
## while its owner uses a mouse, and some mobile browsers report false. Sizing
## for fingers on a small screen costs a mouse user nothing; the reverse is a
## screen they cannot operate.
func _is_touch(device: LayoutProfile.Device) -> bool:
	return device != LayoutProfile.Device.DESKTOP or DisplayServer.is_touchscreen_available()

## Convenience for scenes: run the layout pass immediately with the current
## profile, then stay subscribed. Saves every caller writing the same two lines
## and, more importantly, stops a scene that loads mid-session from sitting in
## the wrong arrangement until the next resize.
func bind(target: Object, method: StringName) -> void:
	if not layout_changed.is_connected(Callable(target, method)):
		layout_changed.connect(Callable(target, method))
	Callable(target, method).call(profile)
