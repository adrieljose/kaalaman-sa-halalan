# Boto Showdown — Development Plan

Companion to `boto-showdown-overview.md` (the concept). This is the technical build plan: phases, engine structure, and which MCP tool does what. Built in Godot 4.7.1 (Mono), driven through Claude Code with two MCP servers:

- **Godot MCP** (`Coding-Solo/godot-mcp`, free/open-source) — 14 tools: `get_godot_version`, `list_projects`, `get_project_info`, `create_scene`, `add_node`, `load_sprite`, `save_scene`, `get_uid`, `update_project_uids`, `launch_editor`, `run_project`, `get_debug_output`, `stop_project`, `export_mesh_library`. Notably **no script-editing or node-property tools** — GDScript files and node properties get authored directly as text (`.gd`/`.tscn`), same as any other source file. The MCP's real jobs here: scaffolding scene trees quickly (`create_scene`/`add_node`/`save_scene`), assigning generated textures once they exist (`load_sprite`), and the playtest loop (`run_project` → `get_debug_output` → `stop_project`) to catch script errors without the user needing to manually press play after every change. `launch_editor` pops the editor open for the user when there's something worth looking at.
- **PixelLab MCP** — real 16-bit-style sprite/tile/UI generation. Account is on a **trial: 40 generations total, no pay-as-you-go balance**. That budget does not get touched until Phase 2 — see below.

## Why art waits

The overview doc is explicit: validate the loop is fun before spending on art. Phase 1 ships with flat-color placeholder rectangles in the Philippine flag palette (navy `#0038A8`, gold `#FCD116`, maroon-red `#CE1126`), not generated sprites. This also protects the 40-generation PixelLab budget until we know what's actually worth spending it on.

---

## Phase 0 — Project Setup

**Goal:** an empty-but-correct Godot skeleton, nothing playable yet.

- Project settings: base viewport `480×270` (16:9 — bumped up from an initial 320×180 pass once it was clear that a trivia question plus four answer buttons needed more breathing room than a GBA-tight grid allows; still clean integer scale to 1080p/1440p), stretch mode `viewport` / aspect `keep` for true pixel-perfect scaling (replacing the current `canvas_items`/`expand` defaults, which blur a fixed-grid pixel-art look), default 2D texture filter → `Nearest`.
- Folder structure:
  ```
  scenes/         battle.tscn, main_menu.tscn, results.tscn (later)
  scenes/ui/       reusable UI components (support_meter, name_box, answer_button, card_panel)
  scripts/         autoloads + non-UI logic
  scripts/ui/      UI component scripts
  data/            .tres Resource files: questions, rivals, cards
  assets/sprites/  assets/backgrounds/  assets/ui/  assets/fonts/  assets/audio/  (empty until Phase 2)
  ```
- Custom Resource types (plain GDScript `class_name` resources, not scenes): `QuestionData.gd` (prompt, category, answers[], correct_index), `RivalData.gd` (name, region, timer_seconds, damage_mult, question_pool), `PowerCardData.gd` (id, name, effect type).
- Autoloads: `GameState.gd` (current match state, which rival, run progress — stubbed for now, fleshed out in Phase 3), `QuestionBank.gd` (loads all `QuestionData` resources, rotates through the 4 categories without immediate repeats).
- Smoke test: `run_project` + `get_debug_output` to confirm the empty project boots with zero errors before building on it.

## Phase 1 — First Playable Duel ⭐ (stop here for your playtest)

**Goal:** exactly what the overview doc calls out — one rival, the validated question set, all three cards, win/lose loop. Placeholder art only.

**Scene: `scenes/battle.tscn`**
```
Battle (Control, full rect)
├─ Background (ColorRect, placeholder solid color per region)
├─ RivalNameBox (top-left)      ├─ RivalSupportMeter
├─ PlayerNameBox (top-right)    ├─ PlayerSupportMeter
├─ RivalSprite (ColorRect placeholder, small, upper-right-of-center)
├─ PlayerSprite (ColorRect placeholder, large, lower-left)
├─ DialogueBox (bottom banner)
│   └─ QuestionLabel
├─ QuestionTimerBar (6s countdown, drains visually)
├─ AnswerButtonsRow (4 color-blocked buttons, populated per question)
├─ CardPanel (hidden until a correct answer; Power Strike / Shield / Rally + "Just Attack")
└─ ResultOverlay (hidden; win/lose text + "Try Again" button)
```

**Scripts:**
- `BattleController.gd` (root) — the state machine: `QUESTION_SHOWN → TIMER_RUNNING → (CORRECT → PLAYER_CHOICE → RESOLVE) | (WRONG_OR_TIMEOUT → RIVAL_HITS → RESOLVE) → CHECK_WIN → next question | GAME_OVER`
- `QuestionTimer.gd` — 6s countdown (`Timer` node + a `Tween` or `_process` drain on the bar's `scale`/`size`), fires a signal on expiry that the controller treats identically to a wrong answer
- `SupportMeter.gd` — exposes `set_value(v)`, tweens the bar width, clamps at 0 to trigger the win check
- `AnswerButton.gd` — holds its answer index + correctness, emits a signal on press, gets disabled once any answer is picked (no double-answering)
- `CardPanel.gd` — three buttons that grey out after use (each card is once-per-match); Shield sets an `is_shielded` flag on the controller instead of firing an immediate effect, consumed by the *next* wrong-answer resolution
- `GameOverFlow.gd` (or folded into `BattleController.gd`) — win/lose text + instant restart, no punishing dead end, matching the doc

**Content:** ~16–20 questions hand-authored across the four categories (registration/procedure, fraud & vote-buying, evaluating candidates, why voting matters), one rival (`RivalData` resource) with a 6-second timer. **Flagging this clearly: I'll write these for durable civic accuracy, not from an authoritative live COMELEC feed — anything time-sensitive (exact deadlines, exact required-ID lists) needs your own fact-check pass before this counts as the "validated" set the overview doc refers to.**

**Verification:** `run_project` + `get_debug_output` repeatedly while building, to catch script/parse errors as I go — I can't see the screen, so the actual "is this fun" call is yours once Phase 1 is up, per your original ask.

## Phase 2 — Real Art Pass

Only after Phase 1 is confirmed fun. Swap placeholders using PixelLab MCP, spending generations deliberately:
- `create_character` — player sprite (large, back/three-quarter battle stance) and the first rival's sprite (smaller, facing-off stance)
- `create_image_pro` or `create_image_pixflux` — the region's battle backdrop
- `create_ui_asset` — name box borders, dialogue box frame, color-blocked answer button skins, support meter frame
- `create_font` — a pixel font matching the 16-bit aesthetic, if the default doesn't fit
- `edit_image` / `inpaint_image` — targeted fixes rather than full regenerations, to conserve the budget
- `load_sprite` (Godot MCP) — wire the generated textures onto the placeholder `ColorRect`/`Sprite2D` nodes once approved

## Phase 3 — Content Expansion & Ladder

- `course_select.tscn` — region list, difficulty climbs (faster timers, harder question mixes, tougher rivals), no new mechanics
- Additional `RivalData` + backdrop per Philippine region, capstone "Election Day" rival
- `GameState.gd` fleshed out: which rivals are cleared, unlocks

## Phase 4 — Objectives, Meta-progression & Polish

- Per-match objectives (no-damage win, cards-only win, fewest-questions win) and cross-game tracking (win streak, full clear)
- Animations/juice (hit flashes, meter drain easing, card-play feedback), audio buses + SFX/music
- Menus: main menu, settings

## Phase 5 — Export

- Export presets per target platform, final QA pass

---

**Next step:** build Phase 0, then Phase 1, then hand it back for your playtest before touching Phase 2.
