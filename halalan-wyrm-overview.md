# Halalan Wyrm — Game Overview
*(working title — swap freely)*

## What It Is

A Bookworm-inspired word game about Philippine elections. You play a civically-engaged worm, tunneling through a grid of letters to take down election threats — corrupt-politician archetypes, never real people or parties.

## How It Plays

- 6×6 letter grid. Drag across **adjacent** tiles (true Bookworm rule — including diagonals) to spell a word.
- Words are checked against a bundled dictionary — either **English or Filipino/Tagalog** words are accepted.
- Every valid word deals damage to the enemy equal to its length. Used tiles clear; the column drops and refills from the top.
- A **Spark Tile** lights up periodically. Working it into a word deals bonus damage. Ignore it for 3 words running and the enemy gets a free hit on you.
- Enemy and player each have an HP bar. Win by draining the enemy's HP to zero; lose and it's a clean instant "Try Again," no punishing dead end.

## Planned (not built yet)

- Power-up tiles beyond Spark: **Gold** (bonus damage/points) and **Ballot** (collects a Fact Card into a Voter's Almanac)
- **Shield Tile** — blocks the enemy's next attack
- Multiple chapters/enemies with a difficulty ladder, capstone fight
- Fact-collection meta progression (the "collect facts about PH elections" quest layer)
- Real PixelLab art pass (current build is placeholder color-blocked art only)

## Where It Stands Right Now

First playable milestone: one enemy ("The Vote Buyer"), the full word-spelling/adjacency/damage/Spark Tile loop working end to end, placeholder art. Confirmed booting with zero errors via Godot MCP's `run_project`/`get_debug_output`, but **not yet visually playtested by a human** — that's the next step.

Previous concept (a Pokémon-battle-style trivia game, "Boto Showdown") was built, tested, and set aside after playtesting — its design doc and build are archived in `archive/` rather than deleted, in case anything from it is worth revisiting.
