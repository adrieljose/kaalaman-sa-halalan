class_name TitleDance
extends Node

## Makes Juan and Maria dance on the title screen.
##
## There are no dance frames for them and no generations left to draw any, so
## the motion comes from AnimatedCharacter's existing cut-out rig — the same
## mechanism the battle uses to make the player stride during a melee approach.
## rig_enable() slices the sprite into horizontal bands and re-parents them as a
## chain, so rotating one carries everything above it. Feeding that a four-band
## chain instead of the battle's three gives the shoulders something to turn
## AGAINST the hips, which is most of what separates dancing from swaying.
##
## The pose is computed from a phase every frame rather than played back from
## keyframes. That is what makes the loop seamless: there is no last frame and
## no first frame to meet, only sin() and cos(), which have no seam to pop at.
## It also means the two dancers can share one clock and stay in step forever
## instead of drifting apart the way two independent loops would.
##
## Nothing here redraws the characters. Every pixel is the sprite they already
## had, cut and moved — so their design, proportions, palette and outfits are
## untouched by construction.

## Where to cut the two children. Ordered outermost first, the way rig_enable
## wants.
##
## These are NOT the battle's bands. Those are tuned to adult rivals; Juan and
## Maria are children with shorter proportions, and the useful line here is the
## hem of the shorts and the skirt at ~0.575 — cutting there leaves the skirt on
## the hips, so a hip turn swings it instead of tearing it in half.
##
## The head cut sits at the COLLAR, not the jaw. Cutting at the jaw — where the
## proportions invite it — put the seam straight across both faces, and a five
## degree tilt sheared the chin off the head. Dropping the line to the collar
## puts it on the neck and the raised hand instead, both of which sit within a
## few pixels of the pivot, so the same tilt moves them by a fraction of one.
##
## Overlaps are sized per joint, and there is a real cost on both sides. Too
## SMALL and the band's outer corner — which swings up by (half-width x sin
## angle) as it rotates about the centre of its lower edge — clears the part
## beneath it and punches a notch of background through the character. Too LARGE
## and the rows the two bands share are visible in both at once, offset by the
## rotation, which ghosts a second copy of whatever is drawn there.
##
## So the two lower joints, which sit on plain shorts and plain legs, get a
## generous 10px against angles that need 4. The head joint gets barely 3px,
## because the rows it shares are an ear and a jawline and a doubled ear is far
## more noticeable than a doubled shin.
const DANCE_CHAIN := [
	{"name": "legs", "band": Vector2(0.560, 1.0)},
	{"name": "hips", "band": Vector2(0.395, 0.615)},
	{"name": "chest", "band": Vector2(0.267, 0.450)},
	{"name": "head", "band": Vector2(0.0, 0.288)},
]

## One beat every 0.75s — 80 bpm, an easy step rather than a rave. Both dancers
## share it so they never drift; their personalities come from what they do
## WITHIN the beat, not from dancing at different speeds.
const CYCLE_SECONDS := 1.5

## The two dances.
##
## They are deliberately not mirror images of each other. Juan is upright and
## bouncy and leads with his shoulders; Maria travels further sideways, turns
## more through the hips (which is what swings the skirt) and tips her head into
## the step. Half a cycle apart, so when one is stepping left the other is
## stepping right and they read as a pair rather than as one animation played
## twice.
##
##   phase        offset into the shared cycle, in turns
##   step         sideways travel, as a fraction of the node's height
##   bounce       vertical travel, same units
##   hop          how cusped the bounce is. 1.0 lands softly, lower lands
##                sharply -- this is the "rhythm" difference between them
##   legs/hips/chest/head   swing of each band, in degrees
##   chest_lag    how far the shoulders trail the hips, in turns. The whole
##                reason the body reads as one connected thing rather than four
##                stacked rectangles
##   nod          head rise and fall, as a fraction of height
##   squash       stretch at the top of the bounce, squash at the bottom
const STYLES := {
	"juan": {
		"phase": 0.0,
		"step": 0.030, "bounce": 0.058, "hop": 0.55,
		"legs": 8.5, "hips": 6.0, "chest": 12.0, "head": 3.0,
		"chest_lag": 0.14, "nod": 0.014, "squash": 0.045,
	},
	"maria": {
		"phase": 0.5,
		"step": 0.044, "bounce": 0.036, "hop": 1.0,
		"legs": 6.5, "hips": 10.5, "chest": 8.0, "head": 4.0,
		"chest_lag": 0.09, "nod": 0.019, "squash": 0.030,
	},
}

var _dancers: Array[Dictionary] = []
var _t: float = 0.0


## `pairs` maps a style key to the character that should dance it.
func setup(pairs: Dictionary) -> void:
	_dancers.clear()
	for key: String in pairs:
		var who: AnimatedCharacter = pairs[key]
		if who == null or not STYLES.has(key):
			continue
		_dancers.append({"node": who, "style": STYLES[key]})
	rebuild()


## Cuts both characters up again.
##
## The rig is built from the node's size and the frame on screen at the time, so
## it goes stale the moment the layout moves or resizes them. Every arrangement
## change has to come back through here or the bands stay where the old rect
## was, floating away from the character they belong to.
func rebuild() -> void:
	for dancer in _dancers:
		var who: AnimatedCharacter = dancer["node"]
		if not is_instance_valid(who):
			continue
		who.rig_disable()
		# Rig the first idle frame rather than whatever the idle loop happens to
		# be showing: the bands capture ONE frame, so capturing a mid-breath one
		# would freeze the character slightly off its resting pose.
		who.play_idle()
		# The idle pose writes rotation and scale every frame. It is inert for
		# the players today, but the dance owns both from here and saying so
		# costs nothing.
		who.pose_locked = true
		who.rig_enable(DANCE_CHAIN)
	_apply(0.0)


func _process(delta: float) -> void:
	if _dancers.is_empty():
		return
	# Wrapped rather than left to grow: a float that has been accumulating for
	# an hour has lost the precision that keeps the motion smooth.
	_t = fmod(_t + delta / CYCLE_SECONDS, 1.0)
	_apply(_t)


func _apply(t: float) -> void:
	for dancer in _dancers:
		var who: AnimatedCharacter = dancer["node"]
		if not is_instance_valid(who) or not who.visible or not who.is_rigged():
			continue
		_pose(who, dancer["style"], t)


func _pose(who: AnimatedCharacter, style: Dictionary, t: float) -> void:
	var p: float = (t + float(style["phase"])) * TAU
	var h: float = who.size.y

	# One full cycle is TWO steps: `swing` is +1 at one extreme and -1 at the
	# other, and passes through 0 at the centre of each pass.
	var swing := sin(p)
	# Highest crossing the centre, lowest with the weight planted at either
	# extreme. `hop` shapes the landing -- below 1 it arrives at the floor with
	# a cusp, which is what makes Juan read as bouncing and Maria as swaying,
	# on the very same beat.
	var lift: float = pow(absf(cos(p)), float(style["hop"]))

	var sway: float = h * float(style["step"]) * swing
	var bob: float = -h * float(style["bounce"]) * lift

	# Feet swing under a body that stays put, then each band above adds a little
	# more sideways travel than the one below. That cascade is what gives the
	# figure a spine instead of four stacked rectangles.
	who.rig_set("legs", -float(style["legs"]) * swing, Vector2(0.0, bob))
	who.rig_set("hips", float(style["hips"]) * swing, Vector2(sway * 0.55, 0.0))
	var chest_swing := sin(p - float(style["chest_lag"]) * TAU)
	who.rig_set("chest", -float(style["chest"]) * chest_swing, Vector2(sway * 0.35, 0.0))
	who.rig_set("head", float(style["head"]) * swing,
		Vector2(sway * 0.18, -h * float(style["nod"]) * lift))

	# Stretch at the top of the bounce, squash at the landing, about the feet so
	# the character never leaves the paving.
	var sq: float = float(style["squash"]) * (lift * 2.0 - 1.0)
	who.pivot_offset = Vector2(who.size.x * 0.5, who.size.y)
	who.scale = Vector2(1.0 - sq * 0.5, 1.0 + sq)
