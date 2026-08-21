# Boto Showdown — Game Overview
*(working title — swap freely)*

## What It Is

A turn-based battle game about Philippine elections, styled after the classic Pokémon battle screen. You play a first-time voter facing off against a series of rival candidates across the country — but instead of moves and type advantages, every hit lands or misses based on whether you actually know how elections work. Answer correctly, and you get to fight back. Answer wrong, and you lose your turn entirely.

It's built to be genuinely exciting to play, not a quiz wearing a costume — the stakes, the visible support meters draining, and the choice of how to strike back are what make it feel like a real match rather than a worksheet.

## The Premise

It's election season. You're a young, first-time voter making your way across the Philippines, region by region, squaring off against a rival candidate at each stop. Every match is a test — not of combat skill, but of whether you actually understand what you're voting for and how to protect your vote from being taken advantage of.

There's no villain to defeat and no fantasy stakes. The "opponent" is really the process itself — everything that makes voting well genuinely hard to do — and you get through it by knowing your stuff, not by mashing buttons.

## How It Plays

Both you and your rival start with **100 support**, shown as a meter in a name box — yours in the top-right corner, the rival's top-left, mirroring a classic RPG battle screen. Your sprite stands large in the foreground, bottom-left; the rival stands smaller, further away, top-right — two candidates facing off across the same stage.

A question drops into a dialogue box below the scene, with a handful of answers laid out as color-blocked buttons — no plain, uniform menu, each option reads as its own distinct choice, the way a real battle menu does. You've got six seconds.

- **Answer correctly** → you get a real decision: throw a plain attack, or spend one of your power cards.
- **Answer wrong, or run out the clock** → your turn is skipped entirely. No attack, no card. The rival hits you back.

First to zero out the other side's support wins the match. Lose, and it's a clean "try again" — no punishing dead end, just back to the start.

## The Power Card System

You carry **three power cards into every match**, each usable once:

- **Power Strike** — a heavy hit, double the damage of a plain attack
- **Shield** — doesn't do anything the moment you play it. It sits armed, waiting, and blocks the *next* wrong-answer hit completely when it happens. A card about protecting yourself from your own future mistake.
- **Rally** — recovers some of your support, for when a match is slipping away

Cards are only ever available after a correct answer, same as a plain attack — knowledge is what earns you the choice, every time.

## What You Actually Learn

The question bank is organized around four things, and the game is built so each shows up naturally through play rather than as a lecture:

- **How voting works** — registration, required documents, the actual step-by-step procedure
- **Spotting fraud & vote-buying** — recognizing bribery, ghost voters, tampered counts
- **Evaluating candidates** — telling real substance apart from empty charisma
- **Why voting matters** — what a badly informed vote actually costs, and what a good one protects

Nothing about the battle mechanic changes based on category — the questions rotate through all four, so no single lesson dominates the game.

## Progression — The Ladder

Each rival is one match. A course-select screen lists who's available, and difficulty climbs the further you go — faster timers, tougher question mixes, harder-hitting rivals — without ever introducing a new system to learn. Every region of the Philippines gets its own rival and its own reskinned battle backdrop, so the game stays visually fresh purely through geography, not new mechanics. A capstone rival — the frontrunner, on Election Day itself — caps the ladder as the finale.

## Objectives & Goals

**Each match, optionally:** win without taking any damage, win using only cards and no plain attacks, win in as few questions as possible.

**Across the whole game:** beat every rival, clear every region, string together a full win streak, complete every per-match objective at least once.

## Visual & Audio Style

16-bit-inspired, built entirely from original designs — no reused characters or assets from any existing game, just the *composition* of a classic battle screen: the corner info boxes, the diagonal facing-off sprites, the bordered dialogue box, the color-blocked menu. The palette leans on Philippine flag colors — navy, gold, maroon — and each region's backdrop and rival carry real local flavor rather than a generic fantasy skin.

## Who It's For

Kids and teens, playable solo, no account or internet connection required beyond downloading it. One input to learn — tap an answer — so there's no tutorial standing between a player and the first match.

## Where It Stands Right Now

This isn't a paper concept — every mechanic above was built and tested as a live, playable prototype before a single line of the real game was written. The battle loop, the timer, the card choices, the win/lose states: all of it was played through repeatedly first, in browser, before being locked in as the design.

The real build is now underway in **Godot 4.7.1**, driven through Claude Code with a Godot MCP bridge for live testing and PixelLab MCP for sprite and background generation. Phase 0 (project setup) and Phase 1 (the first playable duel, one rival, the validated question set, all three cards) are built and sitting in the project folder, ready for playtesting before anything further gets added — content expansion, the rival ladder, and real art all come after that loop is confirmed fun on repeat.
