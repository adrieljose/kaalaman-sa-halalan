# Chapter 2 — City Hall

Implementation notes for the City Hall chapter: what is finished, what is a
placeholder, and how to change either.

## What was added

Nine encounters, in progression order, each in its own room:

| # | Room | Rival | HP |
|---|------|-------|----|
| 1 | City Hall Plaza | Fixer Fredo — The Shortcut Dealer | 170 |
| 2 | Citizen Service Lobby | Clerk Kurakot — The Counter Crook | 185 |
| 3 | Business Permit & Licensing | Permit Peke — The Forged Approver | 200 |
| 4 | Records & Notarial Archive | Notaryo Naku — The Seal Schemer | 215 |
| 5 | Treasury & Cashier Office | Cashier Kaltas — The Deduction Collector | 230 |
| 6 | City Budget Office | Budget Bandido — The Fund Raider | 245 |
| 7 | Procurement & Bidding Room | Bidding Bandit — The Auction Schemer | 260 |
| 8 | Sangguniang Panlungsod | Ordinance Ogre — The Rule Twister | 280 |
| 9 | Mayor's Executive Office | **Don Eraptado — The Plunder Supremo** | 480 |

Twenty-eight skills, each with its own choreography, projectile behaviour,
impact effect, sound and per-skill sprite clip. No two skills share an
animation.

## Boss skill naming

The project brief and the design document name Don Eraptado's skills
differently. They were reconciled as follows — the brief's **names**, the
design document's **animations**:

| Shipped skill | From the brief | Animation from the design doc |
|---|---|---|
| Kaban ng Bayan | Kaban ng Bayan | "Kaban Crusher" — cane taps, chest rolled in, chest swing |
| Plunder Supremo | Plunder Supremo | "Plunder Barrage" — seated, sacks fire on their own |
| Jueteng Jackpot | Jueteng Jackpot | *not in the design doc* — newly designed to match |
| Executive Privilege | Executive Privilege (phase 2) | "Executive Order" — lights out, spotlight, cane slam, dash |

**Executive Privilege is the phase-2 exclusive and the counter mechanic.** It
is absent from the rotation until phase 2, and when it lands it also revokes a
banked Power Up — so the boss punishes preparation, not only a wrong answer.

## Boss phases

Don Eraptado enters phase 2 at 50% HP. On the transition the arena darkens and
swaps to `cityhall_mayor_office_phase2.png` (curtains drawn, red-orange light,
vault fully open, documents falling), the rival draws itself up, a banner
reads "THE MASK COMES OFF", and Executive Privilege joins the rotation.

Phases are data-driven, not hard-coded: see `EnemyData.phase_thresholds`,
`phase_backgrounds`, `phase_banners`, and `EnemyMove.min_phase`. Any future
rival can declare any number of phases without touching the battle controller.

## Artwork

The rivals are generated pixel art (PixelLab), front-facing at eye level to
match Chapter 1. Each has an idle, an attack and a hit clip, plus a
head-and-shoulders portrait. The attack template was chosen per rival to suit
its move styles, so the body reads as the right kind of aggression.

| Asset | Path | Notes |
|---|---|---|
| Character frames | `assets/images/characters/<slug>_gen_{idle,attack,hit}/frame_N.png` | ~98-116 wide x 180 tall. One canvas per rival across all three clips -- that shared canvas is what keeps the feet planted when the battle scene switches clips. |
| Portraits | `assets/images/portraits/enemy_<slug>.png` | 128x128, cropped from idle frame 0. |
| Backgrounds | `assets/images/backgrounds/cityhall_*.png` | Generated. 384x256, floor line at 91.25% of image height. |
| Animated props | `assets/images/props/<clip>/frame_N.png` | Generated. 64x64, 9 frames each: `fan`, `papers`, `banner`, `coins`. |
| Move icons | `assets/images/moves/<move_id>.png` | **Still placeholders.** 28x28. |
| Move sounds | `assets/audio/sfx/moves/<move_id>_{cast,hit}.wav` | **Still placeholders.** Mono 16-bit 22.05 kHz. |

### Eight clips are synthesised, not generated

The generation trial hit a daily cap partway through the first run, so five
rivals lost clips. Don Eraptado has since been regenerated in full on a second
account -- with a real barong rather than a recoloured suit -- so only four
rivals are still affected. Rather than leave those as flat placeholders beside real art --
which looks worse than placeholders throughout -- they are built from the
rival's own frames by `tools/chapter2/import_pixellab.py`:

| Rival | Synthesised |
|---|---|
| Cashier Kaltas | attack |
| Budget Bandido | hit |

Bidding Bandit and Ordinance Ogre were regenerated in full on the second
account, so only two synthesised clips remain out of the original nine.

A synthesised attack uses the character's `west` rotation -- the same figure in
profile, facing the player -- so the rival turns out of its idle, drives in and
settles back, with every frame real generated art. Offsets are whole pixels,
because translation is lossless on pixel art where rotation and fractional
scaling are not. A synthesised hit is a knockback with a brief flash.

To replace them with real generations, add the clip to `frames.json`, drop the
name from that rival's `synth` list, and re-run the importer.

### Per-skill clips were removed

All 28 moves had their own placeholder clip. There is now one generated attack
clip per rival, so a skill keeping its own clip would change art style
mid-fight. `EnemyMove.attack_dir` is empty everywhere in Chapter 2, which makes
it fall back to the rival's attack clip. The skills remain distinct through
their movement, projectiles and impact effects -- those are code, not frames.

## Regenerating

`tools/chapter2/spec.py` is the single source of truth for the roster: names,
titles, HP, damage, colours, descriptions, and which room each rival occupies.
Edit it, then run whichever generator is affected:

```bash
python tools/chapter2/make_tres.py   # enemy / move / chapter resources
python tools/chapter2/make_art.py    # sprites, portraits, move icons
python tools/chapter2/make_bg.py     # backgrounds + the phase 2 arena
python tools/chapter2/make_sfx.py    # placeholder move audio
```

New PNGs and WAVs need one editor pass to generate their `.import` files:

```bash
"D:\GODOT\standard\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --editor --quit
```

## Adding chapters 3 to 5

The chapter gate is now derived rather than hard-coded. `GameState` addresses
chapters as `chapter_%02d.tres`, and `MainMenu.unlocked_chapters()` counts the
chapter files that actually exist. Dropping `chapter_03.tres` into
`data/chapters/` unlocks Chapter 3 on the map with no code change; the map pin
captions and dimming derive from the same count.

## Known limitations

- **Chapter 2 has 60 questions against Chapter 1's 150.** Enough to play — the
  bank reshuffles — but nine encounters repeat questions sooner than Chapter 1
  does. Adding entries to `data/questions/questions.json` with `"chapter": 2`
  is the fix; no code change needed.
- **The certificate is still Chapter 1 only** (`MainMenu.CERTIFICATE_CHAPTER`).
  Completing Chapter 2 does not award one. Deliberate — left as-is rather than
  changing certificate semantics without being asked.
- **Chapter 1 has no props.** `AmbientProps.ROOMS` only lists Chapter 2 rooms;
  Chapter 1's five backdrops are static. Adding rows there would light them up
  with no code change.

## Animated props

Rooms are single images, so anything that moves in one is a sprite composited
over it. `scripts/ambient_props.gd` maps a background's file stem to its props;
`WordBattleController._build_props` instantiates them on a layer sitting
directly above the backdrop and below the fighters.

Two things to know before adding a room:

* **Positions are fractions of the drawn backdrop, not pixels.** The backdrop
  is rescaled per device, so a pixel offset tuned on desktop slides off the art
  on a phone.
* **The usable window is much smaller than the image.** The HUD and question
  panel cover the top, the letter board covers the right, and the fighters
  occupy roughly u 0.06-0.18 and u 0.47-0.60. Props belong in the gap between
  them: about **u 0.26-0.42, v 0.40-0.65**. Props outside it render correctly
  and are simply never seen -- the ceiling fans were first placed on the actual
  ceiling and were invisible in all ten rooms.

Rooms also react to every hit: `_react_room` tints the backdrop toward the
skill's `effect_color` and knocks the props about. It is hooked into
`_fx_impact`, the one beat every skill in both chapters already shares, so all
43 skills got it without touching a single skill function.

## Idle personality

Every Chapter 2 rival's idle came from the same `breathing-idle` template, so
nine characters breathed at the same rate in the same pose -- one enemy in nine
costumes. Replacing the clips would mean regenerating each rival, so the
personality lives in the MOTION instead: `scripts/idle_personality.gd` gives
each a breath depth and rate, a sway, and a resting lean, applied over whatever
frames it has.

Two constraints shape it:

* **Rotation and scale only, never position.** The battle controller owns
  position -- melee approach, knockback -- and writing it here would fight
  those tweens. Both are taken about the FEET, so a breath lifts the chest
  rather than sliding the rival off the floor.
* **It yields during a skill.** `_body_play` tweens the same rotation and scale
  it writes, so `_body_begin` sets `pose_locked` and `_body_end` clears it.

A rival with no row keeps its frames exactly as drawn, which is how Chapter 1
is untouched and how a Chapter 3 rival opts in.

## Chapter select map

`tools/chapter2/make_map.py` rebuilds `chapter_map.png` from the untouched
original plus one generated sheet of five government buildings
(`landmarks_raw.png`), so re-running never stacks landmarks.

* The five buildings are cut apart on the alpha channel's **column runs**, not
  fixed cells, so uneven spacing in the generation cannot mis-slice them.
* They arrive near-monochrome and are recoloured by luminance onto a
  per-chapter ramp -- one drawing style across all five, with the palette
  carrying the progression from timber barangay hall to marble Congress.
* Each landmark is **snapped to land**: the pins were placed against the old
  artwork and several sit slightly off their island, so the placer searches
  around the pin for the spot whose footprint is most solidly ground.

## Enemy animation timing

Two things were wrong, and only one of them was what it looked like.

**Clip rate.** Every clip ran at `AnimatedCharacter.fps` (6), so a six-frame
attack took a full second while the body choreography that drives it strikes in
about a tenth of one. The sprite was still winding up when the damage landed and
was still swinging while the body retreated. Attack, hit and walk now have their
own rates (15 / 12 / 8), which puts a clip at 0.20-0.47s against a ~0.34s strike.

**Beat stalls.** `_body_play` created a tween per beat and awaited each, costing
a frame at every junction. Beats now run chained on one tween.

A beat that accelerates into its target (`EASE_IN`) also gets an automatic
follow-through, so a strike carries slightly past its mark and eases back
instead of stopping dead.

### What was NOT wrong

An early probe showed a 72 px/frame "snap" on Stamp Slam. That was the probe:
it fired moves without awaiting them, so the next move's `_body_begin`
snapshotted a mid-flight position. Awaiting properly, every move measures
2.4-3.7 px/frame with zero mid-motion stalls.

`backdoor_dash` still reports a 221 px/frame jump and that is correct -- the
rival teleports behind the player, and the jump happens while `modulate:a` is 0.
`tools/chapter2/probe_motion.tscn` samples position only, so it cannot see that.

## Chapter-select map

`tools/chapter2/make_map.py` composes the map from five whole-island
illustrations in `tools/chapter2/islands/`. Each is ONE generated image --
shoreline, grounds, paths, planting and building drawn together.

The earlier version pasted a building sprite onto the original artwork's
generic islands and always looked pasted, because the building and the terrain
were drawn by different passes and knew nothing about each other. Position
tuning cannot fix that; the two have to be drawn as one picture.

The islands are dropped onto an EMPTY lagoon: `empty_lagoon()` erases the
original islands a row at a time, treating anything between the leftmost and
rightmost sea pixel of a row as enclosed land. The parchment border and compass
fall outside that span on every row, so they need no special case.

`MARKER_POINTS` in `main_menu.gd` comes from this script's own output. Keeping
the marker positions and the island positions in one place is what stops the
pins drifting onto open water when the art moves -- which is exactly what
happened when the islands were first redrawn.

## Idle-to-attack handover

`_body_begin` used to zero rotation and scale before handing a body to a skill,
so every rival snapped its idle lean upright in a single frame at the start of
every attack -- 2.9 degrees on Budget Bandido, measured. It did that because
moving a Control's pivot while the node is rotated shifts every rendered pixel.

`_repivot()` now cancels that shift exactly: a Control renders as
`position + pivot + M*(p - pivot)`, so changing the pivot moves the picture by
`(I - M)*(p0 - p1)`, and subtracting it from the position leaves the image
where it was at any rotation and scale. The live pose is kept and becomes the
pose the first beat tweens from, so an attack grows out of the stance.
`tools/chapter2/probe_pop.tscn` measures the handover; it now reports 0.00
degrees for all nine rivals.

## Battle orientation

The rivals fought front-on, looking at the camera instead of at the player.
They were animated from their `south` rotation because that is the one the
importer took first -- but create_character produced FOUR directions for each
of them, and `west` is the same character, drawn by the same model, in profile
facing left. The player stands on the left of the stage, so west is the way a
rival should be looking.

`tools/chapter2/make_west_clips.py` builds idle/attack/hit from those west
rotations. It does NOT mirror the front pose: a mirrored front pose is still a
front pose. Motion is layered on because the game already supplies most of it
-- the skill choreography does the travel and follow-through in tweens, and
IdlePersonality supplies the breathing -- so the clips only have to add POSE.
That is done by shearing the sprite in bands about the hips, the same cut-out
idea `AnimatedCharacter.rig_enable` uses in-engine, at whole-pixel offsets so
nothing is resampled.

The front-facing `<slug>_gen_*` folders are left on disk. Reverting is a
`repoint_tres.py` away.

**Superseded.** Both the rivals and the players are now in 3/4 -- see below.

## 3/4 battle poses (supersedes the profile pass)

The `west` rotations fixed the direction but were a flat profile: one eye, no
shoulder line, props edge-on. `create_character(mode="v3", reference_image_*)`
rotates a sprite you ALREADY HAVE into eight directions rather than inventing a
character, so feeding each existing sprite back in is a repose, not a redesign
-- the same cap, lanyard, briefcase and law book come back, turned.

Two of the eight directions are used:

    south-west   a rival's 3/4 facing LEFT, toward the player
    south-east   the player's 3/4 facing RIGHT, toward the rival

`make_battle_clips.py` builds idle/attack/hit for all eleven characters from
those poses. Rivals and players differ only by the sign of `forward`, so one
code path serves both.

Two things that are not cosmetic:

* **Everything is padded to a 180-tall canvas.** The character TextureRects use
  KEEP_ASPECT_CENTERED, so a shorter canvas is scaled UP to fill the node -- a
  rival that happened to crop to 132px would have rendered noticeably larger
  than one cropping to 171px. Padding rather than scaling keeps each
  character's true pixel height, so the Ogre still towers over Fredo.

* **Maria's `flip_h` is gone.** It existed only because her old front-on frames
  faced the wrong way; mirroring her correctly-facing battle frames would turn
  her back on the rival again.

Cost: 32 generations for eleven characters (v3 is 1-2 for a cropped reference,
4 for a full 180x180 one, so cropped references were used wherever the base64
fit inline).

**Chapter 1's five rivals are still front-facing.** The player now faces them,
so that chapter reads as one fighter confronting an opponent who is posing for
the camera. Fixing it is the same recipe and about ten more generations.
