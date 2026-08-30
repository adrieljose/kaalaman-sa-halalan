class_name BattleShadows
extends Control

## Floor shadows for the battle fighters.
##
## Without them the characters read as pasted onto the backdrop rather than
## standing on it: there is nothing anywhere in the frame connecting a sprite to
## the paving under it, so the eye has no evidence of contact.
##
## One node draws every shadow. They are siblings of the fighters, NOT children:
## a child would inherit the body's transform, and the combat choreography leans,
## rotates and scales that transform constantly — so the shadow would tilt off
## the floor and lean with the punch. A shadow lies on the ground plane whatever
## the body above it does, and the only way to get that is to compute it.
##
## Everything is derived from the subject's live rect each frame, so nothing here
## has to be told when a character moves, when a skill throws it across the
## stage, when the layout changes, or when the next rival is swapped in.

## Registered fighters, each {"who": Control, "tune": Dictionary, "ground": float}.
##
## The ground is stored PER FIGHTER, not once for the stage. The wide
## arrangement reproduces the game's authored composition, which stands the
## player and the rival on lines seven pixels apart — so a single floor value
## would put one of the two shadows off its feet on the layout most players see.
var _subjects: Array[Dictionary] = []

## How far the shadow spreads beyond the footprint it is cast by.
##
## Sized against AnimatedCharacter.foot_rect(), NOT the body: these are
## three-quarter sprites, and the Ogre's coat, Ate Ayuda's sack and Juan's
## raised arm all stick out well past the feet under them. A shadow scaled to
## the silhouette lands off-centre and far too wide, which reads as a puddle the
## character is standing beside.
const SPREAD := 1.22

## Shadow height as a fraction of its width. The rooms are painted from a low
## camera looking slightly down at the paving, and this is the ellipse that
## perspective gives you.
const SQUASH := 0.38

## Nested rings, faintest and widest first, each drawn over the last, so the
## alphas compound to about a quarter at the core.
##
## This is how a pixel artist shades a shadow — a few flat tones arranged in an
## elliptical ramp, not a blur. The count is the tuning that matters: at three
## rings the steps were far enough apart to read as concentric bands, a little
## archery target under each fighter. Five closes the gaps enough that the eye
## reads a falloff instead, while every tone stays a flat run of whole pixels.
const RINGS := [
	{"scale": 1.00, "alpha": 0.052},
	{"scale": 0.86, "alpha": 0.055},
	{"scale": 0.71, "alpha": 0.058},
	{"scale": 0.55, "alpha": 0.062},
	{"scale": 0.37, "alpha": 0.068},
]

## Shadows are cast on warm stone and painted wood, never on black, so they are
## a desaturated brown rather than neutral grey — a grey shadow on this palette
## reads as a hole in the floor.
const SHADOW_TINT := Color(0.16, 0.11, 0.09)

## How far a character has to leave the floor before its shadow has drawn all
## the way in, as a fraction of its own height, and how far it draws in.
##
## The shrink is what sells a lift. It is deliberately gentle: these are small
## hops and lunges, not jumps, and a shadow that collapses to nothing on a
## six-pixel rise draws attention to itself instead of to the character.
const LIFT_SPAN := 0.30
const LIFT_SHRINK := 0.34
const LIFT_FADE := 0.45


func _init() -> void:
	name = "BattleShadows"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## `tune` may carry per-character overrides — "width", "alpha", "squash",
## "offset" — for a character whose art needs one. None do today; the hook is
## here because the roster grows and one odd silhouette should not mean
## rewriting the rule for everybody.
func add_subject(who: Control, tune: Dictionary = {}) -> void:
	for entry in _subjects:
		if entry["who"] == who:
			entry["tune"] = tune
			return
	_subjects.append({"who": who, "tune": tune, "ground": 0.0})


## Reads back where each fighter's feet are RIGHT NOW and takes that as the
## floor it stands on.
##
## Only meaningful straight after a layout pass, which is the one moment the
## fighters are guaranteed to be at rest — the combat choreography moves them
## constantly, and capturing mid-lunge would nail the shadow to wherever the
## character happened to be in the air.
##
## Deriving the floor from the character rather than being told it is what keeps
## this honest across all three arrangements, and across an enemy node that
## plays a different sprite every encounter.
func capture_floors() -> void:
	for entry in _subjects:
		var who: Control = entry["who"]
		if not is_instance_valid(who):
			continue
		entry["ground"] = who.position.y + _body_of(who).end.y


func _process(_delta: float) -> void:
	# The subjects are tweened by the combat choreography, so there is no signal
	# to hang this on — the pose is simply different every frame.
	queue_redraw()


func _draw() -> void:
	for entry in _subjects:
		var who: Control = entry["who"]
		if not is_instance_valid(who) or not who.visible or float(entry["ground"]) <= 0.0:
			continue
		_draw_one(who, entry["tune"], float(entry["ground"]))


func _draw_one(who: Control, tune: Dictionary, ground_at: float) -> void:
	var body := _body_of(who)
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		return

	var ground: float = ground_at + float(tune.get("offset", 0.0))

	# The feet, and the two corners either side of them, carried through
	# whatever the choreography has done to the body. Taking the width from the
	# TRANSFORMED corners rather than from the rect means a leaning or squashing
	# character's shadow foreshortens with it for free.
	var feet := _feet_of(who)
	var to_local := get_global_transform().affine_inverse() * who.get_global_transform()
	var left: Vector2 = to_local * Vector2(feet.position.x, body.end.y)
	var right: Vector2 = to_local * Vector2(feet.end.x, body.end.y)
	var foot: Vector2 = (left + right) * 0.5

	var lift: float = maxf(ground - foot.y, 0.0)
	var k: float = clampf(lift / maxf(body.size.y * LIFT_SPAN, 1.0), 0.0, 1.0)

	var w: float = (right - left).length() * float(tune.get("width", SPREAD)) \
		* (1.0 - LIFT_SHRINK * k)
	var h: float = w * float(tune.get("squash", SQUASH))
	# Follows the body's own fade, so a rival that blinks out for a teleport does
	# not leave its shadow behind on the paving.
	var a: float = who.modulate.a * self_modulate.a * float(tune.get("alpha", 1.0)) \
		* (1.0 - LIFT_FADE * k)
	if a <= 0.01 or w < 2.0:
		return

	var centre := Vector2(foot.x, ground)
	for ring: Dictionary in RINGS:
		var f: float = ring["scale"]
		_ellipse(centre, w * f, h * f, SHADOW_TINT, float(ring["alpha"]) * a)


## An ellipse built from whole-pixel rows, the way a pixel artist would lay one
## down.
##
## The project renders with content_scale_mode = canvas_items, so a drawn
## primitive is rasterised at the window's real resolution — a smooth
## anti-aliased ellipse would be visibly finer-grained than the art it sits
## under and would read as a UI element that had wandered into the scene.
## Snapping every row to integer design units puts the shadow back on the same
## grid as the sprites, at every window size, because the whole canvas scales
## together afterwards.
func _ellipse(centre: Vector2, w: float, h: float, tint: Color, alpha: float) -> void:
	var half_h: float = maxf(h * 0.5, 1.0)
	var rows := int(ceilf(half_h * 2.0))
	var colour := Color(tint.r, tint.g, tint.b, alpha)
	var top: float = roundf(centre.y - half_h)
	for i in rows:
		# Sampled at the middle of each row, so a row is as wide as the ellipse
		# actually is across it rather than at its edge.
		var dy: float = ((float(i) + 0.5) / float(rows)) * 2.0 - 1.0
		var half_w: float = w * 0.5 * sqrt(maxf(1.0 - dy * dy, 0.0))
		if half_w < 0.5:
			continue
		var x0: float = roundf(centre.x - half_w)
		var x1: float = roundf(centre.x + half_w)
		if x1 - x0 < 1.0:
			continue
		draw_rect(Rect2(x0, top + float(i), x1 - x0, 1.0), colour)


func _body_of(who: Control) -> Rect2:
	if who is AnimatedCharacter:
		return (who as AnimatedCharacter).body_rect()
	return Rect2(Vector2.ZERO, who.size)


func _feet_of(who: Control) -> Rect2:
	if who is AnimatedCharacter:
		return (who as AnimatedCharacter).foot_rect()
	return Rect2(Vector2.ZERO, who.size)
