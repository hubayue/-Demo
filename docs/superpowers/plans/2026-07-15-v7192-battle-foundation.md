# v7.19.2 Battle Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the fake kill-counter animation with the first genuinely playable v7.19.2 battle loop: 3x5 formation, deterministic opening placement, two-second rest, fixed 2x waves, basic auto-attacks, wall damage, kill XP, and the first in-run three-card growth choice.

**Architecture:** Keep authoritative battle state and simulation in a pure `BattleRun` object with an injected JavaScript-compatible random source. Put weighted card generation/application in a separate `BattleCards` object. `main.gd` only translates input, advances real time, and renders the model so later hero skills, bonds, rulers, terrain, relics, and settlement can be added without growing another monolith.

**Tech Stack:** Godot 4.7, GDScript, frozen Web v7.19.2 HTML runtime, Mulberry32 deterministic RNG, headless tests, rendered screenshot capture.

---

### Task 1: Freeze the Web battle-start and first-wave contract

**Files:**
- Create: `scripts/capture-v7192-battle-fixture.mjs`
- Create: `godot-demo/tests/fixtures/v7.19.2-battle-seed-20260715.json`
- Create: `godot-demo/tests/test_battle_run.gd`

- [x] **Step 1: Capture a deterministic browser-runtime fixture**

Load `reference/web-v7.19.2/index.html` with `Math.random` replaced before page execution by Mulberry32 seed `20260715`. Call `newGame()` with the frozen week-2948 city-0 level, set ruler `caocao`, and capture the exact initial obstacle set plus `buildWave(1)` fields needed by the Godot model: delay, hp, speed, radius, class, big/affix, triangle, XP, and wall damage.

- [x] **Step 2: Write the failing BattleRun test**

The test must require this API before production code exists:

```gdscript
var run = BattleRun.new(catalog, Mulberry32.new(20260715))
run.start(city, "caocao", "guanyu")
assert(run.speed == 2)
assert(run.wave == 0 and run.wave_timer == 2.0)
assert(run.units().size() == 1)
assert(run.obstacles.size() == city.obstacles)
run.prepare_next_wave()
assert(run.next_queue == fixture.wave_1)
```

Also assert every grid row retains at least two non-obstacle cells and the opening hero occupies a legal empty cell.

- [x] **Step 3: Verify RED**

Run:

```powershell
.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe --headless --path godot-demo --script res://tests/test_battle_run.gd
```

Expected: failure because `res://src/battle/battle_run.gd` does not exist.

### Task 2: Implement battle state, grid, and exact first-wave generation

**Files:**
- Create: `godot-demo/src/battle/battle_run.gd`
- Test: `godot-demo/tests/test_battle_run.gd`

- [x] **Step 1: Implement the initial run state**

Mirror Web v7.19.2 values: `speed=2`, `wall/wall_max=city.wall`, `wave=0`, `wave_timer=2.0`, `level=1`, `xp=0`, `xp_need=10`, a 3x5 null grid, obstacle placement with at least two free cells per row, and random placement of the chosen opening hero on a legal cell.

- [x] **Step 2: Implement wave-one generation**

Use the executed formulas from the frozen source:

```text
count = min(96, 10 + floor(wave * 3.3))
hp = round(12 * pow(city.hpGrow, wave - 1) * city.hpMul)
speed = clamp(30 + wave * 2, 30, 96) * city.spdMul
base_xp = (2 + floor(wave / 8)) * 0.65
big chance = clamp(0.06 + wave * 0.011, 0, 0.3)
main enemy triangle chance = 85%
```

Preserve random-call order, three enemy visual classes, regular/big radius, delay, HP, speed jitter, XP, and wall damage so the controlled fixture compares field-for-field.

- [x] **Step 3: Verify GREEN**

Run `test_battle_run.gd`; expect `Godot v7.19.2 battle run: PASS`.

- [x] **Step 4: Commit**

```text
feat: port v7.19.2 battle start and first wave
```

### Task 3: Add fixed-2x scheduling, movement, combat, wall damage, and XP

**Files:**
- Modify: `godot-demo/src/battle/battle_run.gd`
- Modify: `godot-demo/tests/test_battle_run.gd`

- [x] **Step 1: Write failing time and combat assertions**

Assert that one real second advances the model by two game seconds, the rest timer starts wave one, the queue spawns enemies by delay, enemies move toward the defense line, a reaching enemy damages the wall and disappears, and a lethal correctly-countering hit uses `x1.5`, increments kills, and awards enemy XP.

- [x] **Step 2: Verify RED**

Run the focused test and confirm the first missing scheduler/combat assertion fails for the intended reason.

- [x] **Step 3: Implement the minimum authoritative loop**

Add `advance_real(delta)` that performs two Web-style update steps. Implement wave preparation/start, queued spawning, basic enemy movement, wall impact, and the shared triangle table (`霸道 -> 良谋 -> 仁德 -> 霸道`) with correct-hit `x1.5`, wrong-hit `x0.6`, and same-triangle `x1.0`. Implement baseline spear direct attacks, cavalry lane charges, archer projectiles/range, shield no-attack behavior, and support no-damage behavior using catalog damage/rate/range.

- [x] **Step 4: Implement XP thresholds and pause-on-card behavior**

On a kill, add XP. At each threshold, subtract the old requirement, increment level, set:

```text
xp_need = round(10 + (level - 1) * 9 + pow(level, 1.72))
```

and pause battle updates while a card choice is open.

- [x] **Step 5: Verify GREEN**

Run the focused test and all existing Godot tests.

- [x] **Step 6: Commit**

```text
feat: add fixed-speed auto battle loop
```

### Task 4: Port the first in-run three-card choice

**Files:**
- Create: `godot-demo/src/battle/battle_cards.gd`
- Create: `godot-demo/tests/test_battle_cards.gd`
- Modify: `godot-demo/src/battle/battle_run.gd`

- [ ] **Step 1: Write failing card-pool and application tests**

Require three unique weighted cards. The initial pool must include unowned hero cards, one lowest-star upgrade per owned hero, the capped common tactics `全军猛攻`, `击鼓进军`, `青囊秘术`, `招贤纳士`, `神机妙算`, class-conditional tactics, terrain clearing when obstacles remain, triangle refinement for owned attacking elements, ruler basic-attack growth, permanent tactic anchors, `校场演武`, `自刎归天`, and `乐不思蜀`. Verify at minimum unit, upgrade, common buff, element buff, and terrain application mutate real run state.

- [ ] **Step 2: Verify RED**

Run `test_battle_cards.gd`; expect failure because `battle_cards.gd` does not exist.

- [ ] **Step 3: Implement weighted draw without replacement**

Follow Web `rollCards()`: compute total weight, consume one RNG roll per chosen card, remove all cards sharing the selected title, and return three choices. Keep card dictionaries presentation-ready (`kind`, `title`, `icon`, `desc`, optional hero/class/element fields).

- [ ] **Step 4: Implement card application and resume**

Apply the selected card, clear choices, process queued level-ups, and resume only when no choice remains. New heroes land on legal empty cells; upgrades target the lowest-star duplicate and heal it to full.

- [ ] **Step 5: Verify GREEN and commit**

Run both battle tests, then commit:

```text
feat: add first in-run growth draft
```

### Task 5: Replace the placeholder battle screen with the model

**Files:**
- Modify: `godot-demo/src/app/main.gd`
- Modify: `godot-demo/tests/test_main_flow.gd`
- Modify: `godot-demo/tests/capture_map_screen.gd`

- [ ] **Step 1: Write failing integration assertions**

After selecting an opening hero, assert `battle_run` exists, contains that hero in one legal slot, has a two-second wave timer, and retains city wall/kill target. Advance deterministic time and assert the UI model shows real enemies/kills/XP rather than the old `battle_tick` counter. When cards appear, clicking the first card must apply it and resume.

- [ ] **Step 2: Verify RED**

Run `test_main_flow.gd` and confirm failure on missing `battle_run`.

- [ ] **Step 3: Integrate and render**

Construct `BattleRun` in `select_opening_hero()`, delegate `_process(delta)` to it, route card clicks before battlefield clicks, and render: HUD wave/wall/kill/XP, enemy bodies with HP and triangle badges, 3x5 grid, obstacles, units with star/HP/class color, ruler on the wall, fixed `2倍速`, wave countdown/催战 text, and the bottom card overlay.

- [ ] **Step 4: Rendered verification**

Capture `output/godot/v7.19.2-battle-foundation.png` and `output/godot/v7.19.2-first-growth-draft.png` using the normal Godot renderer. Inspect both at original resolution.

- [ ] **Step 5: Full regression and independent review**

Run all Godot headless tests, `npm test`, Godot headless import, rendered capture, and `git diff --check`. Request independent review for Important-or-higher parity or runtime issues and resolve any findings.

- [ ] **Step 6: Commit and push**

```text
feat: make v7.19.2 battle foundation playable
```
