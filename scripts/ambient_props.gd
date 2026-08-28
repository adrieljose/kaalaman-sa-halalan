class_name AmbientProps
extends RefCounted

## Which animated props live in which room.
##
## Keyed by the BACKGROUND's file stem rather than by the rival, because a prop
## belongs to the place, not to whoever is standing in it. A later chapter adds
## rooms by adding rows here; nothing that reads this needs to change, and a
## room with no entry simply has no props.
##
## Positions are fractions of the DRAWN backdrop rect, not pixels. The backdrop
## is scaled per device (see WordBattleController._place_battle_background), so
## a pixel offset that looked right on desktop would drift on a phone; a
## fraction lands in the same spot on the art at every size.
##
## Only a narrow WINDOW of the backdrop is usable, and it is much tighter than
## it looks. The HUD and question panel cover the top of the room, the letter
## board covers the right of it, and the two fighters occupy roughly u 0.06-0.18
## and u 0.47-0.60 -- the stage stops at the board, so the rival is nearer the
## middle than the edge. What is left is the gap between the fighters, about
## u 0.26-0.42 by v 0.40-0.65.
##
## Both mistakes here were only visible in a real screenshot: props on the
## actual ceiling never appeared at all, and props at u 0.46 sat squarely on the
## rival's head.
##
##   u, v   centre of the prop, as a fraction of the drawn backdrop
##   scale  width of the prop, as a fraction of the backdrop width
##   fps    playback speed
##   drift  optional per-frame motion, in fractions of the backdrop per second
##   sway   optional horizontal rock, in degrees
##   count  how many copies to scatter (each gets its own phase)

const CLIP_DIR := "res://assets/images/props/%s"

const ROOMS := {
	"cityhall_plaza": [
		{"clip": "papers", "u": 0.33, "v": 0.60, "scale": 0.08, "fps": 8.0,
			"drift": Vector2(0.02, 0.03), "count": 2},
	],
	"cityhall_lobby": [
		{"clip": "fan", "u": 0.32, "v": 0.42, "scale": 0.11, "fps": 12.0},
	],
	"cityhall_permits": [
		{"clip": "fan", "u": 0.30, "v": 0.42, "scale": 0.11, "fps": 12.0},
		{"clip": "papers", "u": 0.38, "v": 0.56, "scale": 0.09, "fps": 8.0,
			"drift": Vector2(0.01, 0.05)},
	],
	"cityhall_archive": [
		{"clip": "papers", "u": 0.33, "v": 0.45, "scale": 0.10, "fps": 8.0,
			"drift": Vector2(0.0, 0.06), "count": 3},
	],
	"cityhall_treasury": [
		{"clip": "coins", "u": 0.32, "v": 0.52, "scale": 0.08, "fps": 10.0, "count": 2},
	],
	"cityhall_budget": [
		{"clip": "fan", "u": 0.30, "v": 0.42, "scale": 0.11, "fps": 12.0},
		{"clip": "coins", "u": 0.38, "v": 0.58, "scale": 0.07, "fps": 10.0},
	],
	"cityhall_bidding": [
		{"clip": "papers", "u": 0.34, "v": 0.48, "scale": 0.09, "fps": 8.0,
			"drift": Vector2(0.0, 0.05), "count": 2},
	],
	"cityhall_session_hall": [
		{"clip": "banner", "u": 0.30, "v": 0.42, "scale": 0.09, "fps": 6.0, "sway": 5.0},
	],
	"cityhall_mayor_office": [
		{"clip": "coins", "u": 0.35, "v": 0.52, "scale": 0.08, "fps": 10.0},
	],
	# Phase 2 is the room coming apart: the vault is open and the paperwork is
	# in the air, so it gets the heaviest prop load in the chapter.
	"cityhall_mayor_office_phase2": [
		{"clip": "papers", "u": 0.33, "v": 0.44, "scale": 0.11, "fps": 10.0,
			"drift": Vector2(0.0, 0.09), "count": 4},
		{"clip": "coins", "u": 0.39, "v": 0.58, "scale": 0.08, "fps": 12.0},
	],
}


## Prop rows for a background texture, or an empty array when the room has none.
static func for_background(texture: Texture2D) -> Array:
	if texture == null:
		return []
	var stem := texture.resource_path.get_file().get_basename()
	return ROOMS.get(stem, [])


## Frames of one prop clip, in order. Returns an empty array if the clip is
## missing, so a room referencing art that has not been produced yet degrades
## to "no prop" instead of printing a load error every frame.
static func load_clip(clip: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var dir := CLIP_DIR % clip
	var i := 0
	while true:
		var path := "%s/frame_%d.png" % [dir, i]
		if not ResourceLoader.exists(path):
			break
		var tex := load(path) as Texture2D
		if tex == null:
			break
		frames.append(tex)
		i += 1
	return frames
