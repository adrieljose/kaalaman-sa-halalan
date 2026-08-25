extends RefCounted
class_name TouchFeedback
## Gives every button a visibly different pressed state.
##
## ## The problem this solves
##
## Almost every button in the game was built like this:
##
##     for state in ["normal", "pressed", "hover", "focus"]:
##         button.add_theme_stylebox_override(state, one_shared_box)
##
## — one stylebox assigned to all four states, in main_menu.gd, in the scroll
## buttons in main_menu.tscn, on the map pins, on the potion buttons. The result
## is a button that looks *identical* whether it is idle, hovered or held down.
##
## On a mouse that is merely flat: the cursor moving over a control is its own
## feedback. On a touchscreen there is no cursor and no hover, so a button that
## does not change on press gives the player nothing at all — no confirmation
## that the tap registered, which is exactly when people start tapping twice.
##
## ## The approach
##
## Rather than hand-authoring three more styleboxes per button across two scenes
## and a dozen builders, derive them: take whatever box the button already uses
## and re-tint copies of it. That keeps every button's own artwork and colour —
## the wooden scroll stays a wooden scroll, the red potion stays red — and only
## changes how light it is.
##
## Buttons that already define a genuinely different pressed or hover box (the
## shared Back button in settings_panel.gd is the only one) are left alone.

## Pressed sinks toward the shadow; hover lifts slightly. Deliberately
## restrained: this multiplies whatever colour the button already has, and a
## heavier hand turns the pixel-art palette muddy.
const PRESS_TINT := Color(0.70, 0.70, 0.74)
const HOVER_TINT := Color(1.12, 1.12, 1.08)
## Disabled has to read as "not available" without looking broken. Desaturating
## toward grey does that better than fading, which on a busy background just
## looks like a rendering glitch.
const DISABLED_TINT := Color(0.52, 0.52, 0.56)

const STATES := ["pressed", "hover", "disabled"]
const TINTS := [PRESS_TINT, HOVER_TINT, DISABLED_TINT]

## Walks `root` and fixes every button under it. Safe to call repeatedly — each
## button is marked once done, so running this on every layout change costs a
## tree walk and nothing else.
static func apply_to_tree(root: Node) -> void:
	for child in root.get_children():
		if child is BaseButton:
			apply(child as BaseButton)
		if child.get_child_count() > 0:
			apply_to_tree(child)

static func apply(button: BaseButton) -> void:
	if button.has_meta("touch_feedback"):
		return
	var normal := button.get_theme_stylebox("normal")
	if normal == null:
		return
	button.set_meta("touch_feedback", true)
	for i in STATES.size():
		var state: String = STATES[i]
		# Only fill in states that are not already saying something. A box that
		# is a different OBJECT from `normal` was authored deliberately —
		# settings_panel.gd's Back button does this — and is not ours to
		# overwrite. A box that is the same object is the flat case above.
		if button.get_theme_stylebox(state) != normal:
			continue
		var tinted := _tinted(normal, TINTS[i])
		if tinted != null:
			button.add_theme_stylebox_override(state, tinted)

## A copy of `box` multiplied by `tint`, or null for a stylebox kind we have no
## sensible way to shade.
static func _tinted(box: StyleBox, tint: Color) -> StyleBox:
	if box is StyleBoxTexture:
		var tex: StyleBoxTexture = (box as StyleBoxTexture).duplicate()
		# Multiplied rather than replaced, so a button that is already tinted
		# (the green PLAY scroll, the red potion) keeps its own hue.
		tex.modulate_color = tex.modulate_color * tint
		return tex
	if box is StyleBoxFlat:
		var flat: StyleBoxFlat = (box as StyleBoxFlat).duplicate()
		flat.bg_color = _shade(flat.bg_color, tint)
		flat.border_color = _shade(flat.border_color, tint)
		return flat
	return null

## Multiplies the colour channels but leaves alpha alone — shading a
## half-transparent panel should not also make it more or less see-through.
static func _shade(color: Color, tint: Color) -> Color:
	return Color(color.r * tint.r, color.g * tint.g, color.b * tint.b, color.a)
