class_name CharacterCards
extends RefCounted

## Styling for the character-select cards.
##
## Kept out of main_menu.gd because it is pure presentation with no state: the
## menu decides who is selected, this decides what selected LOOKS like. Both
## states are built from the same box so the difference between them is only
## the things meant to differ -- ground, border, glow -- rather than two boxes
## that drifted apart as they were edited.

const GOLD := Color(0.98, 0.78, 0.30)
const GOLD_DIM := Color(0.42, 0.34, 0.20)

## The plinth a character stands on.
static func card_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 4
	box.set_border_width_all(2)
	if selected:
		box.bg_color = Color(0.26, 0.16, 0.09, 0.98)
		box.border_color = GOLD
		# A warm spill under the chosen one, which is what makes the pair read
		# as "this one" rather than "these two, one slightly brighter".
		box.shadow_color = Color(0.98, 0.70, 0.24, 0.34)
		box.shadow_size = 6
	else:
		box.bg_color = Color(0.13, 0.10, 0.08, 0.92)
		box.border_color = GOLD_DIM
		box.shadow_size = 0
	return box


## The name plate under each character.
static func plate_style(selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(3)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	box.set_border_width_all(1)
	if selected:
		box.bg_color = Color(0.52, 0.30, 0.10, 1.0)
		box.border_color = GOLD
	else:
		box.bg_color = Color(0.18, 0.14, 0.11, 1.0)
		box.border_color = Color(0.36, 0.30, 0.22)
	return box


static func name_colour(selected: bool) -> Color:
	return Color(1.0, 0.94, 0.74) if selected else Color(0.66, 0.60, 0.50)


## The confirm button, which is the only thing on the screen that starts a run.
static func confirm_style(enabled: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(3)
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	box.set_border_width_all(2)
	if enabled:
		box.bg_color = Color(0.46, 0.24, 0.08)
		box.border_color = GOLD
	else:
		box.bg_color = Color(0.16, 0.13, 0.11)
		box.border_color = Color(0.30, 0.26, 0.20)
	return box
