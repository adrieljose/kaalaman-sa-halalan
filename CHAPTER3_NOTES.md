# Chapter 3 — Provincial Capitol

## Current local integration — 2026-09-05

The first eight villains are Bokal Bulsa, Assessor Altapresyo, Treasurer Tago, Auditor Alibi, Planner Palusot, Engineer Eskandalo, Contractor Kutsaba, and Project Padrino. They have local RGBA artwork, articulated movement frames, and two attacks plus one defense/recovery move each. See [regular-villain integration](output/chapter3_villain_concepts/LOCAL_INTEGRATION.md). The ninth encounter is now **CONG MEOW — The Meowjority Leader**, with three dedicated skills and HP-aware AI. See [boss implementation](output/cong_meow/IMPLEMENTATION.md) and [recorded battle preview](output/cong_meow/preview.html). No deployment or release-cap change was made.

The sections below describe the original setup and old roster, retained as history. Do not run the legacy make_chapter3_data.py generator to update the new roster: it writes the old encounter list.

## Skill choreography — 2026-09-06

The eight regular rivals had data, art and clips but **one shared animation
routine for all twenty-four skills**: identical wind-up, identical bolt,
identical recovery, whatever the skill was called. Chapters 1 and 2 gave every
skill its own `_sig_` routine; Chapter 3 never got that. Each skill now has its
own, in the Chapter 3 section at the foot of `word_battle_controller.gd`.

**What carries the motion, and what cannot.** The drawn clips do the limb work
— every rival has `attack` (12 frames), `attack2` (12) and `guard` (10), three
separate hand-drawn motions. Nothing in code can add a limb the frames do not
draw, and there is no skeletal rig. What code *can* do is the cut-out rig
(`AnimatedCharacter.rig_pose`), which splits whichever frame is on screen into
legs / torso / head bands and rotates them independently. So every skill is
built: anticipation and wind-up on the rig (knees compress, torso winds away,
head leads or lags) → the drawn clip for the swing → props and projectiles
released on the frame they leave the hand → follow-through and recovery back on
the rig → the exact idle baseline.

**Props** are the third piece. The coin pouch, valuation stamp, cashbox, red
pen, rolled masterplan, briefcase, barricade, vault door, project board and
golden seal are none of them drawn in the sprites: each spawns at the hand,
travels the arc the swing implies, and dies. That is what puts the named weapon
on screen.

Projectiles are released by the skill rather than by a shared block, so the
three tags of Markup Strike fly straight / curved / heavy, and Keychain Lash's
third lockbox leaves on a leg beat rather than a hand one.

### Checks

`tools/chapter3/probe_ch3_skills.tscn` fires all 24 and asserts damage, guard
and heal land by the right amount, and that the rival returns to its exact
home position, rotation, scale and alpha with the cut-out rig handed back. It
also checks statically that all 24 ids reach a routine of their own — a typo'd
id still animates, just identically to everyone else, which is the bug this
change exists to remove and which no runtime assertion can see.

`tools/chapter3/shot_ch3_skills.tscn` photographs every skill mid-motion
against **both Juan and Maria**, and asserts something is actually happening at
that instant: the body has left its stance, or is posed on the rig, or a prop
is in the air.

Every assertion was tested against a deliberately broken build first. Two
planted faults were *not* reported, and the reason turned out to matter: the
resolver's rig safety-net and `_body_end`'s position restore had absorbed them,
so they were compensated rather than missed. Re-planted downstream of both, the
drift and rig checks fired and the drift accumulated 9 → 18 → 27px across three
turns, which is exactly the invisible-then-obvious failure they exist to catch.

Cong Meow is untouched — the boss has its own controller and its own tests.

## Original setup notes

Decided: Provincial Capitol setting, **nine encounters**, full Chapter 2 parity
on art.

**Stages 1 and 2 are done.** The data layer exists and all ten rooms are in.
The chapter is playable end to end in its real locations; only the rivals are
still borrowed Chapter 2 sprites. The current PixelLab account is down to **2
generations**, which is not enough to start a rival (8 each), so stage 3 waits
on a new account.

Nothing here is deployed. `MainMenu.RELEASE_CAP` is 1, so an exported build
shows chapter 1 only regardless of what is on disk — Chapter 3 cannot reach the
website by accident.

## Why Provincial Capitol

It is the honest next rung. Chapter 1 is the barangay — the government you can
walk to. Chapter 2 is the city — the government that issues your permits.
Chapter 3 is the province: bigger budgets, more distance between the official
and the citizen, and the first tier where the money is large enough that the
corruption stops being petty. The institutions also translate cleanly from
Chapter 2, which keeps the archetypes writable — a provincial treasurer is
recognisably a bigger Cashier Kaltas.

## Roster

Every rival is a **fictional archetype**. None is modelled on a real official,
living or dead, and none should be — the same rule the first two chapters were
built under.

| # | Room | Rival | | HP | Skill damage |
|---|------|-------|---|----|---|
| 1 | Capitol Gate & Guardhouse *(outdoor)* | **Guard Garapal** — The Brazen Gatekeeper | M | 300 | 18–21 |
| 2 | Provincial Assessor's Office | **Assessor Anino** — The Shadow Valuer | F | 320 | 19–23 |
| 3 | Motor Pool & Project Yard *(outdoor)* | **Engineer Epal** — The Tarpaulin King | M | 340 | 20–24 |
| 4 | Provincial Treasury | **Treasurer Tuso** — The Clever Ledger | F | 360 | 21–25 |
| 5 | Capitol Arcade & Bulletin Wall *(outdoor)* | **Auditor Alibi** — The Finding Dodger | M | 380 | 21–26 |
| 6 | Relief Staging Yard *(outdoor)* | **Kalamidad Kiko** — The Calamity Profiteer | M | 400 | 22–27 |
| 7 | Committee Room | **Konsehala Kubli** — The Hidden Agenda | F | 420 | 23–28 |
| 8 | SP Session Hall | **Board Member Bulok** — The Rotten Vote | M | 440 | 24–29 |
| 9 | Governor's Office | **Gobernador Ganid — The Provincial Patron** | M | **700** | 26–40 |

Three women to Chapter 2's one. That is deliberate: Cashier Kaltas was the only
female rival in nine, which is both a poor reflection of a real capitol and a
waste of the pitch range the voice work depends on.

### What each rival is *about*

Each one teaches something a player can carry into a real election, which is
the whole point of the game:

1. **Guard Garapal** — access. Who gets to enter a public building.
2. **Assessor Anino** — property valuation, and why an undervalued friend's lot
   is everyone else's higher tax.
3. **Engineer Epal** — the name and face on the tarpaulin of a project paid for
   with public money. Epal culture is a real and legislated-against thing.
4. **Treasurer Tuso** — provincial funds, and where the money physically sits.
5. **Auditor Alibi** — COA findings, and what happens to an official who
   collects them.
6. **Kalamidad Kiko** — calamity and quick-response funds, the ones spent
   fastest and watched least.
7. **Konsehala Kubli** — committee work, where a bill is actually shaped, and
   how little of it is public.
8. **Board Member Bulok** — the Sangguniang Panlalawigan, the provincial
   legislature almost no voter can name a member of.
9. **Gobernador Ganid** — the office itself: term limits, dynasty, and the
   difference between a patron and a public servant.

## Balance

HP continues Chapter 2's curve (170→280, boss 480) at a steady +20 a rung,
opening above Chapter 2's strongest ordinary rival.

**Damage deliberately does not keep climbing, and this is the one departure
from a straight escalation.** `GameState.player_max_hp` is a flat 100 in every
chapter and is never reassigned anywhere in the project. Chapter 2 already
reaches 26 on its last mook and 34 on its boss — about four hits and three.
Pushing Chapter 3 into the high thirties would leave the player two hits from
dead, which is not a harder chapter so much as a coin-flip one.

So Chapter 3 overlaps Chapter 2's top band and grows the **fight** instead:
300–440 HP is a great deal more board to get through, and every extra turn is
another chance for the clock to land a free hit. The pressure is the timer, not
the number.

If this reads as too gentle in play, the knob to turn first is HP, not damage.

### Boss — two phases

Phase 2 at 50%, the room darkening on transition, banner "THE PROVINCE IS
MINE". Three skills in phase 1; **Emergency Powers** (40) unlocks in phase 2 via
`min_phase`, the same mechanism Don Eraptado's Executive Privilege uses.

The original idea of a phase-2 move that *punishes a banked Power Up* is **not
built**. It cannot be expressed in data — see the engine note below — so it
would need battle-controller work. Parked, not forgotten.

### Engine constraint worth knowing

`EnemyMove` declares `statuses`, `self_statuses`, `tile_effects` and
`self_heal`, but **`word_battle_controller.gd` never reads any of them.** Zero
references. Only `direct_damage`, `animation_style`, `effect_color` and
`min_phase` do anything. A move built on the other fields lands silently for no
effect, which is why all 28 Chapter 3 skills are direct damage — the same as
all 43 of Chapter 1's and Chapter 2's.

## Placeholder art

Every rival points at a Chapter 2 sprite set, portrait and room. Each pair is a
combination **already verified on screen in Chapter 2**, so the staging numbers
(`battle_scale`, `ground_fraction`, the offsets) come along with it and carry no
new risk. Stage 3 replaces the paths in place.

| Chapter 3 rival | borrows | room |
|---|---|---|
| Guard Garapal | Fixer Fredo | cityhall_plaza |
| Assessor Anino | Clerk Kurakot | cityhall_lobby |
| Engineer Epal | Permit Peke | cityhall_permits |
| Treasurer Tuso | Cashier Kaltas | cityhall_treasury |
| Auditor Alibi | Notaryo Naku | cityhall_archive |
| Kalamidad Kiko | Budget Bandido | cityhall_budget |
| Konsehala Kubli | Senator Sabaw (flipped) | battle_session_hall |
| Board Member Bulok | Ordinance Ogre | cityhall_session_hall |
| Gobernador Ganid | Don Eraptado | cityhall_mayor_office (+ phase 2) |

Skill icons are left null. The moves panel holds its slot size and its rows
around an empty icon — verified, not assumed.

## Generation budget

Measured from what Chapter 2 actually consumed.

**Per rival — 8 generations:** `create_character` v3 eight directions (2),
`animate_character` idle/attack/hit in the 3/4 combat facing (3), two per-skill
attack animations via `animate_image` (2), portrait (1).

| Item | Count | Generations |
|---|---|---|
| Rivals | 9 × 8 | 72 |
| Rooms | 9 (phase 2 is graded, not generated) | 9 |
| Skill icons | 28 | 28 |
| Boss phase-2 sprite variant | | 3 |
| **Subtotal** | | **112** |
| **Retry buffer (+20%)** | | **~134** |

**Rooms carry no retry buffer, on evidence.** Chapter 2 never once regenerated
a room. All three that came back wrong were repaired in post: the session hall's
chair mass was replaced with its own mirrored carpet (`open_session_floor.py`),
Chapter 1's aisle was pushed outward (`widen_aisle.py`), and the bidding room's
flat projector screen was painted (`paint_bidding_screen.py`). The first of
those says so outright -- "there are no generations left to redraw the room, so
the room is edited". A room's characteristic failure is its floor line, and that
is an editing problem, not a generation problem.

The boss's phase-2 arena is **graded, not generated**. Chapter 2 spent a
generation on one and it came back brighter than phase 1 -- the wrong direction
for the lights going out -- so it was graded anyway. `grade_phase2.py` records
why that is the better method regardless: a grade "guarantees phase 2 lines up
with phase 1 pixel for pixel, which is the whole point of an arena that changes
under the player rather than a different room."

The chapter map landmark is **no longer in the budget**. Pin 3 already sits on a
painted domed-capitol island in `chapter_map.png`, and it lights up on its own
now that the chapter data exists — verified in both the illustrated map and the
compact list. That is 2 generations saved against the first estimate.

The buffer is not padding. Chapter 2's facing conversion alone ran **44
generations against a 40 budget**, and further generations were lost to colour
fidelity and two corrupted references. Planning to the subtotal would guarantee
running out.

### What that means for accounts

At 40 generations per PixelLab trial, with **11 remaining** on the current
account: three more accounts gives 131 against a 136 target — tight. **Four is
the realistic number.** This is the actual constraint on Chapter 3; the pipeline
is proven and the tooling exists, the credits do not.

## Questions

**60 already exist** in `data/questions/questions.json` tagged `chapter: 3` —
20 easy, 20 medium, 20 hard, already provincial (governor, vice governor,
capitol, three-term limit, provincial board). Chapters 1 and 2 carry 150 each,
so the gap is **90 more**, not 150 from scratch.

Worth knowing when topping up: the existing 60 are largely paired restatements
of the same fact ("The elected head of a province is the ___" beside "A
province's top elected executive is its ___"), so they cover roughly 30 distinct
facts and will repeat noticeably across a nine-encounter run.

## Build order

1. ~~**Data.** `chapter_03.tres`, nine `EnemyData`, 28 `EnemyMove`, HP curve,
   boss phase threshold.~~ **Done.** Generated by
   `tools/chapter3/make_chapter3_data.py`, which holds the balance table — tune
   there and re-run rather than editing 38 files.
2. ~~**Rooms.**~~ **Done -- 9 generations spent, 2 left.** Prompts are recorded in `tools/chapter3/spec.py` --
   Chapter 2's were never saved, so nothing recorded why its rooms look as they
   do. **Four outdoor, five indoor**, all on or in the same 1920s neoclassical
   capitol: every prompt opens with one of two shared paragraphs (the building
   from inside, or its grounds from outside) so the nine read as one place, and
   every one ends with the same open-floor rule. They are ordered so the chapter
   walks inward -- gate, yard, arcade and relief yard are outside; from
   encounter 7 it is indoors for good, through the session hall to the
   governor's office. Nine backgrounds generated, plus the boss arena's phase 2 graded
   from the governor's office rather than generated. Fits the 11 generations on
   the current account with two spare. The chapter looks like somewhere before
   it looks like anyone.
3. **Rivals, in encounter order.** Each one complete before starting the next,
   so a budget that runs out leaves finished rivals rather than nine
   half-built ones.
4. **Skill icons.** 28, batched.
5. **Questions.** 90 more, to reach Chapter 2's 150.
6. **Voices**, once the ElevenLabs account issue is resolved — nine more sets
   plus a boss rage register. `hurt_voice` is left empty meanwhile, which falls
   back to the shared three-take set rather than leaving a rival silent.

## Checks

- `tools/chapter3/probe_chapter3.tscn` — walks all nine encounters, resolves
  every frame each clip claims, asserts the HP curve rises, that no single hit
  can empty a full health bar, that all 28 move ids are distinct, and that the
  boss's phase 2 unlocks exactly one move. Then boots the real battle scene on
  chapter 3. **Every one of these assertions was tested against a deliberately
  broken copy first**, and all four planted faults were caught.
- `tools/chapter3/shot_chapter3_map.tscn` — the pin and caption in both map
  presentations.
- `tools/chapter3/shot_chapter3_battle.tscn` — encounters 1, 6 and 9 on screen,
  including the moves panel with empty icons.

## Room post-work outstanding

Neither needs a generation. Chapter 2 fixed every room defect this way.

- **The treasury's sign reads "POLIFCY"** -- garbled lettering over the central
  doors, and wrong for a treasury whatever it said. Paint it out or replace it
  with the provincial seal. Same job as `paint_bidding_screen.py`.
- **The project yard and relief yard lost their tarpaulin banners.** Both
  prompts asked for a printed vinyl banner with an official's face and neither
  came back with one, which costs Engineer Epal his single most legible image.
  Compositing one in is cheap and is the kind of thing the Chapter 2 tools
  already do.

## Room verification

All nine were audited with `tools/chapter3/fetch_rooms.py`, which measures the
patch each fighter's feet actually occupy against the floor colour, and then
rendered with the fighters standing in them. **The session hall came out right
first time** -- the room Chapter 2 got wrong twice -- because the prompt asked
for tiered desks in the back half only and an open well in front. Its audit
flagged the left foot as dark; the render overruled it, which is what that
check is for: it says "look at this patch", the picture decides.

## Open

- **Skill names for the boss's parked Power-Up counter**, if that move is ever
  built.
- **Room floor lines.** Every Chapter 2 room whose sides are furniture needed a
  per-room `ground_fraction`; the session hall, bidding room and lobby all did.
  Expect the same for the real session hall and committee room -- both prompts
  now ask for the desks in the back half and an open well in front, but the
  measurement time should still be budgeted rather than the generations.
- **Voice casting** is blocked on the ElevenLabs generation failure, not on
  planning.
