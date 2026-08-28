extends TextureRect
class_name AnimatedCharacter
## Drives a battle character's sprite from folders of pre-rendered PixelLab
## frames: a looping idle, plus one-shot attack/hit clips that play through
## once and then fall back to idle automatically.

## Fires the moment a one-shot clip finishes and idle resumes, so callers can
## chain combat beats instead of firing them all on the same frame.
signal one_shot_finished

@export var idle_dir: String = ""
@export var idle_count: int = 0
@export var attack_dir: String = ""
@export var attack_count: int = 0
@export var hit_dir: String = ""
@export var hit_count: int = 0
## Looping walk clip, used only for the scripted march between encounters.
## Optional — without it, walking falls back to the idle loop while the node
## slides, which still reads as travel.
@export var walk_dir: String = ""
@export var walk_count: int = 0
## Idle rate. Slow on purpose: this is breathing, not action.
@export var fps: float = 6.0
## One rate per clip, because they are different kinds of motion.
##
## Everything used to run at `fps`, so a six-frame attack took a full second
## while the body choreography that drives it strikes in about a tenth of one.
## The sprite was still winding up when the damage landed and was still
## swinging while the body retreated -- the hit never lined up with the blow.
@export var attack_fps: float = 15.0
@export var hit_fps: float = 12.0
@export var walk_fps: float = 8.0

## Rate of whatever clip is playing now.
var _fps: float = 6.0

var _idle_frames: Array[Texture2D] = []
var _attack_frames: Array[Texture2D] = []
var _hit_frames: Array[Texture2D] = []
var _walk_frames: Array[Texture2D] = []
var _current_frames: Array[Texture2D] = []
var _frame_index: int = 0
var _timer: float = 0.0
var _one_shot: bool = false

## Per-rival idle motion (see IdlePersonality). Empty means "stand exactly as
## the frames were drawn", which is what Chapter 1 does.
var idle_style: Dictionary = {}
var _idle_t: float = 0.0
## Set while the battle controller is choreographing this body. The idle pose
## writes rotation and scale every frame, and _body_play tweens the same two
## properties -- without this the idle would fight the skill mid-swing.
var pose_locked: bool = false

func _ready() -> void:
	_reload_frames()

func _reload_frames() -> void:
	_idle_frames = _load_frames(idle_dir, idle_count)
	_attack_frames = _load_frames(attack_dir, attack_count)
	_hit_frames = _load_frames(hit_dir, hit_count)
	_walk_frames = _load_frames(walk_dir, walk_count)
	_play_idle()

## Repoints this character at a different set of sprite folders and reloads
## them immediately. This is how one EnemyCharacter node plays every enemy in
## the chapter instead of the scene carrying five sprite nodes and hiding four,
## and how one PlayerCharacter node plays whichever character was chosen.
func configure_clips(clips: Dictionary) -> void:
	idle_dir = String(clips.get("idle_dir", ""))
	idle_count = int(clips.get("idle_count", 0))
	attack_dir = String(clips.get("attack_dir", ""))
	attack_count = int(clips.get("attack_count", 0))
	hit_dir = String(clips.get("hit_dir", ""))
	hit_count = int(clips.get("hit_count", 0))
	# Only the player has a walk cycle; leaving these out keeps an enemy's
	# existing (empty) walk rather than blanking a clip it never had.
	if clips.has("walk_dir"):
		walk_dir = String(clips["walk_dir"])
		walk_count = int(clips.get("walk_count", 0))
	# Mirrors a character whose frames were drawn facing the wrong way. Always
	# assigned, never left alone: this same node swaps between characters, so a
	# missing flag has to actively un-mirror the previous one rather than let it
	# carry over.
	flip_h = bool(clips.get("flip_h", false))
	idle_style = IdlePersonality.for_idle_dir(String(clips.get("idle_dir", "")))
	_idle_t = 0.0
	_reset_idle_pose()
	_reload_frames()

func configure_from(enemy: EnemyData) -> void:
	var clips := {
		"idle_dir": enemy.idle_dir, "idle_count": enemy.idle_count,
		"attack_dir": enemy.attack_dir, "attack_count": enemy.attack_count,
		"hit_dir": enemy.hit_dir, "hit_count": enemy.hit_count,
	}
	# ALWAYS assigned, even when empty. One node plays every rival in the
	# chapter, so an absent key leaves the PREVIOUS rival's walk in place —
	# which had Vote Vandal striding around in Lord Trapo's frames. Same trap
	# as flip_h below: a swapped-in character has to clear what it lacks, not
	# just set what it has.
	clips["walk_dir"] = enemy.walk_dir
	clips["walk_count"] = enemy.walk_count
	clips["flip_h"] = enemy.flip_h
	configure_clips(clips)

func _load_frames(dir: String, count: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if dir.is_empty():
		return frames
	for i in count:
		var tex := load("%s/frame_%d.png" % [dir, i]) as Texture2D
		if tex != null:
			frames.append(tex)
	return frames

func _process(delta: float) -> void:
	_tick_idle_pose(delta)
	if _current_frames.size() <= 1:
		return
	_timer += delta
	if _timer < 1.0 / maxf(_fps, 0.1):
		return
	_timer = 0.0
	_frame_index += 1
	if _frame_index >= _current_frames.size():
		if _one_shot:
			_play_idle()
			one_shot_finished.emit()
			return
		_frame_index = 0
	texture = _current_frames[_frame_index]

## Returns true only when a clip actually started and is guaranteed to emit
## one_shot_finished. Callers check the result before awaiting, so a missing
## or single-frame clip can never hang the combat sequence.
func play_attack() -> bool:
	return _play_once(_attack_frames)

func play_hit() -> bool:
	return _play_once(_hit_frames, hit_fps)

## Plays a one-shot clip from an arbitrary folder — the hook a skill uses to
## swing with its OWN animation instead of the rival's shared attack. Frames
## are loaded on demand and cached, so a skill's clip costs nothing until the
## first time that skill is actually used.
var _clip_cache: Dictionary = {}

func play_clip(dir: String, count: int) -> bool:
	if dir.is_empty() or count <= 0:
		return false
	var key := "%s#%d" % [dir, count]
	if not _clip_cache.has(key):
		_clip_cache[key] = _load_frames(dir, count)
	return _play_once(_clip_cache[key])

## Starts the walk loop. Unlike attack/hit this never self-terminates — the
## caller stops it with play_idle() when the character arrives, because the
## walk lasts exactly as long as the travel tween, not a fixed frame count.
func play_walk() -> void:
	if _walk_frames.size() < 2:
		return
	_fps = walk_fps
	_current_frames = _walk_frames
	_frame_index = 0
	_one_shot = false
	_timer = 0.0
	texture = _current_frames[0]

## Public stop for the walk loop; also the way callers reset a character to
## neutral after a transition.
func play_idle() -> void:
	_play_idle()

func _play_once(frames: Array[Texture2D], rate: float = -1.0) -> bool:
	_fps = rate if rate > 0.0 else attack_fps
	if frames.size() < 2:
		if not frames.is_empty():
			texture = frames[0]
		return false
	_current_frames = frames
	_frame_index = 0
	_one_shot = true
	# The pose is NOT reset here. _tick_idle_pose stops while a one-shot runs,
	# so the body simply holds the lean it already had for the length of the
	# clip. Zeroing it instead put a visible snap at the front of every hit
	# reaction, which is the same pop _body_begin used to cause.
	_timer = 0.0
	texture = _current_frames[0]
	return true

## Breathes, sways and leans the sprite according to its personality.
##
## Only rotation and scale are touched, never position: the battle controller
## owns position (melee approach, knockback), and writing it here would fight
## the tweens that close the distance. Both are taken about the FEET rather
## than the sprite centre, so a breath lifts the chest and a sway rocks the
## shoulders instead of sliding the whole rival off the floor.
func _tick_idle_pose(delta: float) -> void:
	if idle_style.is_empty() or _one_shot or pose_locked:
		return
	_idle_t += delta
	pivot_offset = Vector2(size.x * 0.5, size.y)
	var breathe: float = float(idle_style.get("breathe", 0.0))
	var b: float = sin(_idle_t * float(idle_style.get("rate", 0.6)) * TAU)
	# Chest rises as the shoulders narrow, which reads as breathing rather
	# than as the sprite being stretched.
	scale = Vector2(1.0 - breathe * 0.45 * b, 1.0 + breathe * b)
	var sway: float = float(idle_style.get("sway", 0.0))
	rotation = deg_to_rad(float(idle_style.get("lean", 0.0))
		+ sway * sin(_idle_t * float(idle_style.get("sway_rate", 0.4)) * TAU))

func _reset_idle_pose() -> void:
	scale = Vector2.ONE
	rotation = 0.0

func _play_idle() -> void:
	_fps = fps
	_current_frames = _idle_frames
	_frame_index = 0
	_one_shot = false
	_timer = 0.0
	if not _current_frames.is_empty():
		texture = _current_frames[0]

# --- visible bounds -------------------------------------------------------

## Cached opaque bounds per texture. Texture2D.get_image() pulls the image back
## from the GPU, and this is asked for on every melee approach.
var _body_rect_cache: Dictionary = {}

## The character's VISIBLE bounds, in this node's local coordinates.
##
## A frame is a small body on a larger transparent canvas, and that canvas is
## then letterboxed inside a still-larger node by KEEP_ASPECT_CENTERED. The two
## paddings stack: on a 130-wide node holding a 100-wide canvas around a 46-wide
## body there is 42px of nothing on each side. So the node rectangle is a bad
## proxy for where the character actually is -- melee spacing measured node to
## node left the fighters 85-97px apart when the intent was 22, which is why the
## punches visibly failed to land.
##
## Measured from the first idle frame rather than whatever is on screen, so the
## answer cannot drift as a walk cycle's limbs change the silhouette's width
## mid-approach.
func body_rect() -> Rect2:
	var tex: Texture2D = _idle_frames[0] if not _idle_frames.is_empty() else texture
	if tex == null:
		return Rect2(Vector2.ZERO, size)
	var ts := tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return Rect2(Vector2.ZERO, size)

	var key := tex.get_rid()
	if not _body_rect_cache.has(key):
		var img := tex.get_image()
		if img == null:
			return Rect2(Vector2.ZERO, size)
		_body_rect_cache[key] = img.get_used_rect()
	var used: Rect2i = _body_rect_cache[key]

	var fit: float = minf(size.x / ts.x, size.y / ts.y)
	var origin := (size - ts * fit) * 0.5
	var r := Rect2(origin + Vector2(used.position) * fit, Vector2(used.size) * fit)
	if flip_h:
		# The node mirrors its texture about its own centre, so the body's
		# margins swap sides.
		r.position.x = size.x - r.position.x - r.size.x
	return r

## Where `mover` must be positioned so it comes to rest `gap` from `anchor`,
## measured between the two VISIBLE bodies.
##
## `from_left` is which side the mover closes from: false for a rival coming in
## on the player (its left edge stops `gap` past the player's right edge), true
## for the player closing on a rival (its right edge stops `gap` short of the
## rival's left edge). Static and parameterised so the spacing rule can be
## tested without standing up the battle scene, which hangs when instantiated
## headless.
static func melee_rest_x(mover: AnimatedCharacter, anchor: AnimatedCharacter,
		gap: float, from_left: bool = false) -> float:
	if from_left:
		return anchor.position.x + anchor.body_rect().position.x - gap 			- mover.body_rect().end.x
	return anchor.position.x + anchor.body_rect().end.x + gap 		- mover.body_rect().position.x

# --- cutout rig -----------------------------------------------------------
#
# Every character sheet has one attack clip and no per-limb art, so a walk
# cycle cannot come from frames. rig_enable() slices the CURRENT frame into
# head / torso / legs and re-parents them as a hierarchy (legs -> torso ->
# head), which is what lets a melee approach actually stride instead of slide.
#
# Bands overlap by a couple of percent on purpose: rotating a part about its
# joint opens a hairline gap at the cut, and the overlap hides it. Rotations
# are kept small for the same reason — this is a paper cut-out, not a skeleton,
# and it stops reading as a body if a joint swings far enough to show daylight.
#
# The arms are deliberately NOT cut out. On three of the five rivals they are
# merged into a coat or a dress, and slicing them tears the artwork; the arm
# motion comes from the hand-drawn attack clip instead, which is what that clip
# is actually good at.

## Fractions of the sprite's height. Tuned against the silhouettes: the heads
## end around 0.26, the hips sit near 0.58.
const RIG_BANDS := {
	"legs": Vector2(0.575, 1.0),
	"torso": Vector2(0.245, 0.60),
	"head": Vector2(0.0, 0.27),
}

var _rig: Dictionary = {}

func is_rigged() -> bool:
	return not _rig.is_empty()

## Builds the cut-out from whichever frame is on screen right now and hides the
## flat sprite behind it.
func rig_enable() -> void:
	if is_rigged() or texture == null:
		return
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	# The node draws its texture with KEEP_ASPECT_CENTERED, so reproduce that
	# placement or the cut-out lands somewhere the sprite never was.
	var scale_fit: float = minf(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size := tex_size * scale_fit
	var origin := (size - draw_size) * 0.5

	var parent: Control = self
	# Outermost first: rotating the legs has to carry the torso and head with it.
	for part_name: String in ["legs", "torso", "head"]:
		var band: Vector2 = RIG_BANDS[part_name]
		var region := Rect2(0.0, band.x * tex_size.y, tex_size.x, (band.y - band.x) * tex_size.y)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region

		var piece := TextureRect.new()
		piece.name = "Rig_" + part_name
		piece.texture = atlas
		piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		piece.stretch_mode = TextureRect.STRETCH_SCALE
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Child nodes do not inherit flip_h, so each band mirrors itself. The
		# bands span the full texture width and share one centre, so flipping
		# them individually is equivalent to flipping the whole figure -- and
		# without it a mirrored rival would face the wrong way for exactly as
		# long as the rig is up.
		piece.flip_h = flip_h
		piece.size = Vector2(draw_size.x, region.size.y * scale_fit)
		var here := Vector2(origin.x, origin.y + band.x * tex_size.y * scale_fit)
		# Children are positioned relative to their parent part.
		piece.position = here if parent == self else here - _rig[_rig_parent_of(part_name)]["abs"]
		# Legs pivot at the hip (their top); the others at the joint below them.
		piece.pivot_offset = Vector2(piece.size.x * 0.5,
			0.0 if part_name == "legs" else piece.size.y)
		parent.add_child(piece)
		_rig[part_name] = {"node": piece, "abs": here, "home": piece.position}
		parent = piece
	# The flat sprite would show through the joints; the cut-out replaces it.
	self_modulate.a = 0.0

func _rig_parent_of(part_name: String) -> String:
	return "legs" if part_name == "torso" else "torso"

## One rigged pose. Angles in degrees; `bob` lifts the whole figure, `sway`
## shifts it sideways, so a stride can rise and fall as it swings.
func rig_pose(legs_deg: float, torso_deg: float, head_deg: float,
		bob: float = 0.0, sway: float = 0.0, secs: float = 0.12) -> Tween:
	if not is_rigged():
		return null
	var tween := create_tween().set_parallel(true)
	var legs: Dictionary = _rig["legs"]
	tween.tween_property(legs["node"], "rotation", deg_to_rad(legs_deg), secs) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(legs["node"], "position",
		Vector2(legs["home"]) + Vector2(sway, bob), secs) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_rig["torso"]["node"], "rotation", deg_to_rad(torso_deg), secs) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_rig["head"]["node"], "rotation", deg_to_rad(head_deg), secs) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween

## Hands the character back to its hand-drawn frames.
func rig_disable() -> void:
	if not is_rigged():
		return
	var legs: Control = _rig["legs"]["node"]
	legs.queue_free()
	_rig.clear()
	self_modulate.a = 1.0
