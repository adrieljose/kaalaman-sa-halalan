# Enemy Attack Mechanics — Adaptation Plan

*Draft for review. No code has been written against this yet.*

Source: `Bookworm_Adventures_Enemy_Attack_Mechanics_Volume_1.md` (Volume 1 only —
Warp/Cursed/Fire Tiles, Stasis, Shields and Potion Steal are Volume 2 and out of
scope).

This is an **adaptation**, not a port. Two constraints shape every call below:

1. **We're still simple.** One implemented rival, one word-spelling loop. Adding
   sixteen mechanics at once would bury the core game.
2. **Part of the audience is young kids.** Mechanics that remove player agency
   without warning (multi-turn turn-denial, zeroed-out damage with no
   explanation) are disproportionately punishing for that audience. Several
   recommendations below reject or soften the source mechanic for this reason.

---

## 0. The finding that matters most

**Our enemy currently has no turn.**

The doc's whole architecture assumes an alternating loop: Lex acts → enemy acts.
Ours doesn't work that way. The only way any rival deals damage today is the
**Mudslinging Tile detonating** after being ignored for 2 turns
(`board_controller.gd`, `MUD_DETONATE_TURNS`).

The consequence is a real balance hole: **a player who always works the mud tile
into a word — or spends a Purify Potion — takes zero damage for an entire
match.** The rival becomes a punching bag with a health bar. `EnemyMove` reflects
this too: it has exactly one field, `damage`, because a move is currently just "a
number that fires when mud pops."

Everything else in this plan depends on fixing that first. Giving the enemy a
genuine turn is Phase 0 and is worth more than any individual attack type.

A pleasant discovery while auditing: **Lord Trapo's three existing moves already
describe mechanics we never built.**

| Existing move | Flavour text implies | Doc mechanic |
|---|---|---|
| Dynasty Power | "Three generations of influence, weaponized" | Enemy **Power Up** |
| Padrino Favor | "He makes a call. Somehow the problem disappears" | Enemy **Heal** |
| Smear Campaign | "Mud starts flying — literally and figuratively" | **Plague Tile** |

We wrote the fiction first and can now make it true. Phase 1 gets a lot of
thematic payoff cheaply.

---

## 1. Mechanics worth adopting

Ranked by value-to-complexity for *our* game specifically.

### Adopt early — high value, low complexity, kid-safe

| Mechanic | Why it fits us | Notes |
|---|---|---|
| **Normal Attack (real enemy turn)** | Fixes the hole in §0. Foundational. | Must be telegraphed — we already have the side panel showing the next move. |
| **Power Down** | We already ship a **Power Up Potion whose "cures Power Down" half currently does nothing.** Adding Power Down completes a half-built feature and makes an existing item meaningful. | Gentle: reduces damage, never removes agency. Ideal first debuff. |
| **Enemy Heal** | One line of state. Creates the "race" tension the doc describes and teaches players that stalling costs them. | Cap total healing per match so a fight can't drag forever. |
| **Tile Smash** | Tile stays selectable but scores nothing. We already render per-tile point pips, so the feedback is free — pip visibly drops to 0. | Very readable for kids: *"that letter is worth nothing now."* |

### Adopt in a middle wave — board pressure, moderate complexity

| Mechanic | Why it fits us | Notes |
|---|---|---|
| **Tile Lock** | Clean restriction now that tile selection has no adjacency rule — locking 1–2 tiles is a mild, legible constraint rather than a puzzle-breaker. | Show a countdown on the tile so the wait is visible, not mysterious. |
| **Plague Tile (spreading)** | **We already have 80% of this.** Our Mud Tile is a plague tile that detonates instead of spreading. Making it spread is closer to the doc *and* closer to what "mudslinging" actually means. | Hard-cap the spread (e.g. max 4 plagued tiles) so the board can't become unplayable. |
| **Alter Tiles** | Cheap — we already have a letter pool and a working shuffle routine. Strong disruption without being unfair. | Should never produce an unsolvable board; bias replacements toward usable letters. |
| **Life Leech** | Thematically the strongest mechanic in the whole document for this game: corruption **taking from the public and enriching itself** is literally "Lex HP -= X, Enemy HP += X." | Small numbers. Very strong if over-tuned. |

### Adopt late — sharp edges, needs care

| Mechanic | Verdict | Reasoning |
|---|---|---|
| **Damage over time** | Adopt **one** type, not three | Poison/Burn/Bleed are mechanically identical in the doc — duration + damage per tick. Three separate types is bookkeeping with no gameplay difference. Ship **one** DoT and re-flavour it per rival. |
| **Armor** | Adopt, mild only | Flat reduction is fine. But the doc notes Heavy Armor can make short words deal *effectively nothing* — for a young player that reads as "the game is broken." **Never let armor reduce a valid word below 1 damage.** |
| **Word-length minimum** | Adopt, but change the feedback | Good pressure — it teaches longer words. But the doc's version silently deals 0. Instead: **grey the Attack button out** the way we already do for invalid words, with the reason shown ("Needs 4+ letters!"). Same pressure, no confusion. |
| **Enemy Power Up** | Adopt for bosses | Simple, telegraphable, and escalation feels good at the end of a fight. |
| **Stun / Freeze** | Adopt **sparingly**, final boss only | Losing a turn with no counterplay is the single most frustrating thing for a young player. The source game softens this with anti-Stun *Treasures* — **we have no equipment system, so we'd be shipping the punishment without the counter.** Cap at 1 turn, telegraph a full turn ahead. |
| **Petrify** | **Reject** | Multi-turn lockout. Watching the game play itself for two turns is not fun at eight years old, and again we lack the Treasure counterplay. |

### Substitution worth making: "Weakness"

The doc's **Weakness** mechanic keys off *semantic word categories* (metal words,
colour words, mammals). That needs a categorised dictionary we don't have and
would be a large content lift.

**But we ship two dictionaries — English and Filipino.** So we can detect
something more interesting for free: **certain rivals take bonus damage from
Filipino words.**

That's a cheap check (which word list matched), it's culturally apt for a game
about Philippine elections, and it rewards exactly the vocabulary the game is
quietly trying to celebrate. I'd rather build this than a generic "metal words"
system.

---

## 2. Blocked — needs groundwork first

These should **not** be implemented half-supported.

| Mechanic | Missing prerequisite | Why partial implementation is bad |
|---|---|---|
| **Gem Steal** | **Gem Tile tier system.** We have Spark (+10 flat) and Gold (×2) — two ad-hoc bonus tiles, not the Amethyst→Diamond ladder the earlier combat doc describes. | Stealing a "gem" that doesn't exist as a category means stealing one of two lucky tiles. Low drama, confusing. Build gem tiers first. |
| **Enemy Purify** | **Player-inflicted enemy statuses.** The player currently has no way to poison, burn or weaken a rival. | Purify removes debuffs the player can't apply. It would be a move that visibly does nothing. |
| **Anti-Stun / defensive counterplay** | **Treasure / equipment system.** Nothing exists. | The source balances Stun and Tile Smash against Treasures (Boots of Theseus, Tao of Lex). Shipping the attacks without the counters makes them feel arbitrary. This is the main reason Stun is deferred to boss-only above. |
| **Semantic Weakness** | Categorised word data | See the Filipino-word substitution above — recommend doing that instead rather than waiting on a category dataset. |
| **Potion Steal** | — | Volume 2. Explicitly out of scope. Noting only so it isn't reintroduced by accident. |

**Prerequisite ordering:** if we later want Gem Steal and enemy Purify, the
groundwork order is: gem tier system → player status infliction → those two
mechanics. Not before.

---

## 3. Phased rollout

### Phase 0 — Groundwork (no new player-facing mechanics)

Invisible refactor. Nothing new appears on screen; everything after depends on it.

- **Give the enemy a real turn**, decoupled from mud detonation (§0).
- **Refactor `EnemyMove` into the component model** the doc recommends (§13):
  `direct_damage`, `statuses[]`, `tile_effects[]`, `self_effects[]`. Today it's a
  bare `damage: int`, which can't express any mechanic below.
- **Add a status-effect system** with duration ticking, usable on *both* sides.
- **Define the turn-resolution order** once (doc §15) so effects always resolve
  predictably.
- Keep the existing telegraph panel — it already shows the next move and becomes
  much more important once attacks vary.

*Risk if skipped: every later phase re-implements ad-hoc versions of the same
plumbing.*

### Phase 1 — Make fights real

- Normal Attack on a genuine enemy turn
- **Power Down** (completes the Power Up Potion)
- **Enemy Heal**
- **Tile Smash**
- Lord Trapo rebuilt to use his three already-written moves properly

### Phase 2 — Board pressure

- **Tile Lock** (with visible countdown)
- **Plague spreading** — the Mud Tile *becomes* the Plague Tile (confirmed:
  upgrade, not a second hazard alongside it). Same fiction, spreading instead
  of just detonating, spread capped so the board can't lock up.
- **Alter Tiles**
- **Life Leech**

### Phase 3 — Advanced rivals & boss

- One **DoT** type, re-flavoured per rival
- **Armor** (floor of 1 damage)
- **Word-length minimum** (surfaced through the Attack button, not silent zeroes)
- **Enemy Power Up**
- **Filipino-word bonus** (game-wide, not per-rival — see §4.1)
- **Stun** — final boss only, 1 turn, telegraphed

### Phase 4 — Only after prerequisites exist

- Gem tier system → then **Gem Steal**
- Player status infliction → then **enemy Purify**
- Equipment/Treasures → then reconsider Stun elsewhere and Heavy Armor

**Deliberately never:** Petrify.

---

## 4. Mechanic ↔ rival pairings

Assigned thematically, and ordered so complexity ramps with the roster.

| # | Rival | Mechanics | Reasoning |
|---|---|---|---|
| 1 | **Lord Trapo** *(dynasty heir)* | Normal Attack, **Power Up** (Dynasty Power), **Heal** (Padrino Favor), light **Plague** (Smear Campaign) | Chapter 1 must stay teachable — no debuffs on the player, nothing that takes away a turn. His existing three moves already map onto Power Up / Heal / Plague, so he demonstrates "enemies do things other than damage" without punishing a new player. |
| 2 | **Sir Balimbing** *(turncoat — "faces every direction")* | **Alter Tiles** | The defining trait is *changing sides*. A rival who rewrites the letters under you is the cleanest possible expression of that. Nothing else in the doc says "turncoat" as well. |
| 3 | **The Padrino** *(vote-buying, patronage)* | **Tile Lock**, **Life Leech** | *Diverging from the Stun suggestion here.* Stun ("you're paid off, skip a turn") is defensible, but **Tile Lock is a sharper metaphor and a kinder mechanic**: those letters aren't destroyed, they're *bought* — reserved, unavailable, still visible. That's patronage exactly. And **Life Leech** is the honest version of the transaction: what he takes from you goes directly into him. Stun would also be the harshest mechanic in the game arriving third, before players are ready. |
| 4 | **Epal** *(credit-grabbing publicity seeker)* | **Tile Smash** | The best pairing in the list. Tile Smash means *"still selectable, contributes nothing"* — which is a precise mechanical definition of **"all flash, no substance."** He plasters his face on your tiles; they still look fine and are worth zero. |
| 5 | **Dr. Disinfo** *(troll farm, fake headlines)* | **Plague (spreading)**, secondary **Alter Tiles** | The defining property of disinformation is that it **spreads**. Plague Tile is the only mechanic in the document whose core rule is contagion, so it belongs to the disinformation rival more than anyone. Balimbing keeps Alter Tiles as his primary so the two stay distinct. |
| 6 | **Ditto Dela Cruz** *(copycat / vote-splitter)* | **Power Down**, duplicate-letter flooding (Alter Tiles variant) | Vote splitting doesn't stop you — it *halves your effectiveness*, which is Power Down almost by definition. Pair it with an Alter Tiles variant that floods the board with **duplicates of one letter**: mechanically a re-parameterised Alter Tiles, thematically confusing near-identical options. |
| 7 | **Bulok the Rotten** *(generic corruption, "rotten/spoiled")* | **DoT** (decay), **Armor** (mild) | Rot is damage that keeps working after the fact — he's the natural home for our single DoT type. Light armor sells "entrenched, hard to clean out." |
| 8 | **The Landslide** *(final boss, frontrunner)* | **Armor**, **Regeneration**, **Power Up**, **word-length minimum**, **Stun** (1 turn, telegraphed) | A landslide should feel like it can't be dented by small efforts — armor plus regeneration creates exactly the race the doc describes, and the word-length minimum forces genuinely big words for the finale. This is the one place Stun is justified: last fight, player is experienced, and it's a memorable spike rather than a recurring frustration. |

**Difficulty curve check:** no player-debuff until #3, no turn-denial until #8,
board attacks introduced one at a time (#2 alter → #3 lock → #4 smash → #5
spread). Each new rival teaches exactly one new idea.

### 4.1 Difficulty curve: HP scaling, not a toggle

**Decided: no difficulty toggle.** Instead, the difficulty curve is carried
entirely by `EnemyData.max_hp` climbing as the roster advances — every rival
after Lord Trapo should have a visibly higher pool than the one before, on top
of whatever new mechanic they introduce from the table above. Two levers
stacking (new mechanic + more HP) is the escalation; there's no separate
easy/hard mode to maintain.

Concretely, `max_hp` should roughly track position in the table above (Lord
Trapo's 120 as the floor, The Landslide as the ceiling). Exact numbers are a
balancing pass once Phase 1 is playable, not something to lock in from a
design doc.

### 4.2 Filipino-word bonus: game-wide

**Decided: game-wide, not per-rival.** Every enemy, every fight — a word that
validates against `data/wordlists/fil.txt` deals bonus damage. This replaces
the "Weakness" line in the Phase 3/rival tables above; it's a standing rule of
combat rather than a trait some enemies have and others don't.

Mechanically this sits in the same place letter-value scoring already lives
(`word_battle_controller.gd` damage calc) — `WordValidator` already tracks
which list a word matched, so the check is "did this word come from the
Filipino list," not a new lookup.

---

## 5. Decisions from this round

1. **Mud Tile → Plague Tile.** Confirmed upgrade, not a second hazard. See
   Phase 2 above.
2. **No difficulty toggle.** Confirmed. Difficulty is carried by per-rival HP
   scaling instead — see §4.1.
3. **Filipino-word bonus is game-wide.** Confirmed — see §4.2.

Nothing here is implemented yet. Next step is Phase 0 (giving the enemy a real
turn) — say the word and I'll start.
