extends RefCounted
class_name LayoutProfile
## One immutable description of "what kind of screen are we on right now", handed
## to every scene that lays itself out. Scenes never measure the window
## themselves — they read this — so there is exactly one place where a device is
## classified and exactly one set of numbers everyone agrees on.
##
## Lives in its own file (rather than inside the Layout autoload) so scenes can
## write `LayoutProfile.Arrangement.PORTRAIT` in a typed match without depending
## on the singleton being loaded — which matters for headless script tests,
## where autoloads are not compile-time identifiers.

## The five screens we recognise. Kept separate from Arrangement because two
## devices can want the same shape at different sizes: a tablet in landscape and
## a desktop monitor both want the WIDE layout, they just get it bigger or
## smaller. Distinguishing them anyway lets effects and tap targets differ even
## when the arrangement does not.
enum Device {
	PHONE_PORTRAIT,
	PHONE_LANDSCAPE,
	TABLET_PORTRAIT,
	TABLET_LANDSCAPE,
	DESKTOP,
}

## The three layouts actually authored. Every screen in the game implements
## these three and no more — five devices collapsing to three arrangements is
## what keeps this maintainable.
enum Arrangement {
	## Tall and narrow. Everything stacks vertically, secondary panels collapse
	## behind taps. Phones and tablets held upright.
	PORTRAIT,
	## Short and wide. Two columns, because there is no vertical room to stack
	## in. Phones held sideways.
	LANDSCAPE_COMPACT,
	## The original desktop composition. Tablets in landscape and every desktop.
	WIDE,
}

var device: Device = Device.DESKTOP
var arrangement: Arrangement = Arrangement.WIDE

## The design-space rect scenes should lay out into — the *result* of the
## content scale, not the window size. On a 16:9 desktop with a 640x480 base
## this is 853x480: the extra width is real, usable design space.
var design_size: Vector2 = Vector2(640, 480)

## What we asked the window for. Guaranteed to be fully visible; design_size is
## this or larger on one axis.
var base_size: Vector2i = Vector2i(640, 480)

## How much effect density this device should get, 0..1. Every effect still
## plays — this scales counts (splatter bits, bolts, shake steps), never removes
## a move's identity. See _fx_scaled() in word_battle_controller.gd.
var fx_budget: float = 1.0

## True when the primary input is a finger. Drives tap-target sizing and whether
## hover-only affordances need a tap equivalent.
var is_touch: bool = false

func is_portrait() -> bool:
	return arrangement == Arrangement.PORTRAIT

func is_wide() -> bool:
	return arrangement == Arrangement.WIDE

func is_phone() -> bool:
	return device == Device.PHONE_PORTRAIT or device == Device.PHONE_LANDSCAPE

## Centre of the usable design space. Written out because almost every panel
## placement wants it and `design_size * 0.5` reads as arithmetic rather than as
## intent at the call site.
func centre() -> Vector2:
	return design_size * 0.5

func describe() -> String:
	return "%s %dx%d (base %dx%d, fx %.2f)" % [
		Device.keys()[device], int(design_size.x), int(design_size.y),
		base_size.x, base_size.y, fx_budget]
