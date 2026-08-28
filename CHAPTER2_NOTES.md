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
| Backgrounds | `assets/images/backgrounds/cityhall_*.png` | **Still placeholders.** 384x256, and the floor line must sit at 91.25% of image height. |
| Move icons | `assets/images/moves/<move_id>.png` | **Still placeholders.** 28x28. |
| Move sounds | `assets/audio/sfx/moves/<move_id>_{cast,hit}.wav` | **Still placeholders.** Mono 16-bit 22.05 kHz. |

### Nine clips are synthesised, not generated

The generation trial hit a daily cap partway through the run, so five rivals
lost clips. Rather than leave those as flat placeholders beside real art --
which looks worse than placeholders throughout -- they are built from the
rival's own frames by `tools/chapter2/import_pixellab.py`:

| Rival | Synthesised |
|---|---|
| Cashier Kaltas | attack |
| Budget Bandido | hit |
| Bidding Bandit | attack, hit |
| Ordinance Ogre | attack, hit |
| **Don Eraptado** | idle, attack, hit |

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
- **Environmental reactivity is not implemented.** The design document suggests
  props reacting during attacks (papers lifting off council desks, monitors
  changing during Coin Burst, the photocopier animating). Backgrounds are
  single images, so this would need either animated backdrops or foreground
  prop nodes — neither exists yet.
