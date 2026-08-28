class_name IdlePersonality
extends RefCounted

## How each rival stands when it is not doing anything.
##
## Every Chapter 2 rival's idle clip came from the same `breathing-idle`
## template, so nine different characters all breathed at the same rate, in the
## same pose, on the same four frames. They read as one enemy in nine costumes.
##
## Replacing the clips means regenerating each rival (their frames live on a
## spent account), so the personality is put in the MOTION instead: each rival
## gets its own breath depth and speed, its own sway, and its own resting lean,
## applied on top of whatever frames it has. That is enough to tell a bored
## clerk from a coiled fixer at a glance, and it costs no art.
##
##   breathe    how far the chest rises, as a fraction of height
##   rate       breaths per second
##   sway       how far the body rocks side to side, in degrees
##   sway_rate  rocks per second
##   lean       resting tilt, in degrees; negative leans away from the player
##
## Leans are small on purpose. These are 180px sprites drawn face-on, and past
## about three degrees a lean stops reading as posture and starts reading as a
## sprite that has come loose from the floor.

const STYLES := {
	# Loose, unhurried, already sizing you up. The widest, slowest sway in the
	# chapter: he is the only one who does not think a fight is happening.
	"fixer_fredo": {
		"breathe": 0.010, "rate": 0.62, "sway": 2.2, "sway_rate": 0.34, "lean": -1.6},

	# Heavy and bored. Deep slow breathing, almost no sway -- he has stood at
	# that counter all morning and intends to keep standing.
	"clerk_kurakot": {
		"breathe": 0.020, "rate": 0.40, "sway": 0.5, "sway_rate": 0.22, "lean": 0.0},

	# Nervy. The quickest, shallowest breath of the nine, with a small restless
	# rock: a man expecting to be asked for the original copy.
	"permit_peke": {
		"breathe": 0.007, "rate": 1.35, "sway": 1.5, "sway_rate": 0.95, "lean": 0.8},

	# Theatrical. Rocks the most, leans back like a man about to make a
	# pronouncement rather than a man in a fight.
	"notaryo_naku": {
		"breathe": 0.013, "rate": 0.70, "sway": 3.0, "sway_rate": 0.52, "lean": -2.2},

	# Sharp and still. Barely moves, breathes precisely, tips very slightly
	# forward -- already counting what you owe.
	"cashier_kaltas": {
		"breathe": 0.008, "rate": 0.98, "sway": 0.4, "sway_rate": 0.60, "lean": 1.4},

	# Guarded. Hunched over what he is carrying, heavy breath, minimal sway;
	# the posture of someone shielding a sack.
	"budget_bandido": {
		"breathe": 0.019, "rate": 0.52, "sway": 0.8, "sway_rate": 0.30, "lean": 2.4},

	# Smooth. A slow confident roll, leaning back, in no hurry at all.
	"bidding_bandit": {
		"breathe": 0.011, "rate": 0.66, "sway": 1.9, "sway_rate": 0.40, "lean": -1.2},

	# Enormous. The deepest, slowest breath in the game and a wide ponderous
	# sway, so his size is legible before he moves.
	"ordinance_ogre": {
		"breathe": 0.026, "rate": 0.32, "sway": 1.6, "sway_rate": 0.18, "lean": 0.0},

	# The boss. Deliberate rather than dramatic: a deep, very slow breath and
	# the faintest lean back. He is the only one who does not need to posture.
	"don_eraptado": {
		"breathe": 0.022, "rate": 0.34, "sway": 1.0, "sway_rate": 0.20, "lean": -1.0},
}


## The style for a rival, found from its idle folder ("..._gen_idle" ->
## "..."). An unknown rival returns empty, which leaves its idle exactly as it
## was -- that is how Chapter 1 is untouched by this, and how a Chapter 3 rival
## opts in simply by adding a row above.
static func for_idle_dir(idle_dir: String) -> Dictionary:
	if idle_dir.is_empty():
		return {}
	var stem := idle_dir.get_file()
	for suffix in ["_gen_idle", "_idle"]:
		if stem.ends_with(suffix):
			stem = stem.substr(0, stem.length() - suffix.length())
			break
	return STYLES.get(stem, {})
