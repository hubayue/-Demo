# v7.19.14 Battle State Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce the frozen Web v7.19.14 unit-state presentation and close the missing multi-rule battle-banner screenshot gate in Godot.

**Architecture:** Keep battle state authoritative in `BattleRun`; extend the existing `_unit_visual_spec()` as a read-only presentation snapshot and draw every state in Web `drawUnit()` order. Capture Web and Godot from equivalent fixed fixtures, without adding test-only behavior to production code.

**Tech Stack:** Godot 4.5.2/GDScript, frozen Web v7.19.14 Canvas source, Playwright CLI, Node.js, 480×800 PNG captures.

---

### Task 1: Lock the Web unit-state snapshot contract

**Files:**
- Modify: `godot-demo/tests/test_battle_unit_presentation.gd`
- Modify: `godot-demo/src/app/main.gd`

- [x] **Step 1: Write the failing unit-state test**

Add a fixed unit with `shen_ids`, profile rebirth, Taoyuan protection, all six `rbuffs`, army attack/haste, reflect, seal, a next-wave resistance hint, and an adjacent shield. Assert the wished-for snapshot:

```gdscript
var status := main._unit_visual_spec(unit, 1, 1)
assert(status.shen_badge_visible)
assert(status.taoyuan_ring_visible)
assert(status.resistance_hint_visible)
assert(status.buff_icons == ["💗", "⚡", "⚔️", "🎯", "🕐", "🌾", "🌾", "🌬️"])
assert(status.reflect_active and status.adjacent_shield and status.sealed)
assert(status.rebirth == 2 and status.rebirth_label == " 2转")
```

- [x] **Step 2: Run the test and verify RED**

Run:

```powershell
& $godot --headless --path godot-demo --script res://tests/test_battle_unit_presentation.gd
```

Expected: FAIL because the new presentation keys and row/column-aware signature do not exist.

- [x] **Step 3: Implement the smallest read-only snapshot**

Extend `_unit_visual_spec(unit, row := -1, col := -1)` with Web-derived flags, ordered icons, rebirth color/label, five-slot ascension star sequence, and shield-skin visibility. Do not move gameplay calculations into the drawing layer.

- [x] **Step 4: Run the targeted test and verify GREEN**

Expected: `Godot v7.19.14 battle unit presentation: PASS`.

### Task 2: Draw state layers in Web order

**Files:**
- Modify: `godot-demo/src/app/main.gd`
- Test: `godot-demo/tests/test_battle_unit_presentation.gd`

- [x] **Step 1: Add failing geometry/color assertions**

Assert the Web anchors and colors for `👼`, `打不动`, shield-protection, buff row y=-33, rebirth colors, and tower-shield geometry.

- [x] **Step 2: Verify RED**

Run the same targeted Godot test and confirm failure is caused by missing geometry.

- [x] **Step 3: Implement the drawing helpers**

Add focused helpers for the tower shield, reflect spikes, ascension star row, and dashed resistance ring. Update `_draw_battle_unit()` to follow frozen Web order: protection/hint → rarity/bond/Shen/ultimate/statuses → body/shield skin → badges/stars → damage/health.

- [x] **Step 4: Verify GREEN and run drag/unit regressions**

```powershell
& $godot --headless --path godot-demo --script res://tests/test_battle_unit_presentation.gd
& $godot --headless --path godot-demo --script res://tests/test_battle_drag_preview.gd
& $godot --headless --path godot-demo --script res://tests/test_special_unit_inspection.gd
```

Expected: all three scripts exit 0.

### Task 3: Produce paired state and multi-rule evidence

**Files:**
- Create: `scripts/capture-v71914-unit-states-parity.mjs`
- Create: `godot-demo/tests/capture_v71914_unit_states.gd`
- Create: `godot-demo/tests/capture_v71914_unit_states.gd.uid`
- Modify: `scripts/capture-v71914-battle-shell-parity.mjs`
- Modify: `godot-demo/tests/capture_v71914_battle_shell.gd`

- [x] **Step 1: Build the Web fixture**

Use the frozen page, set a shield unit plus buffed, reflected, reborn and Shen units, remove unmatched transient layers, draw, and save `v7.19.14-web-unit-states.png`. Add a two-rule field-banner state and save `v7.19.14-web-battle-multi-rule-banner.png`.

- [x] **Step 2: Build the equivalent Godot fixture**

Set the same profile and run fields, render the real main scene at 480×800, and save matching Godot filenames.

- [x] **Step 3: Run both capture paths**

```powershell
node scripts/capture-v71914-unit-states-parity.mjs
& $godot --path godot-demo --script res://tests/capture_v71914_unit_states.gd
node scripts/capture-v71914-battle-shell-parity.mjs
& $godot --path godot-demo --script res://tests/capture_v71914_battle_shell.gd
```

Expected: all four new PNG files are non-empty 480×800 images.

- [x] **Step 4: Inspect both pairs visually**

Compare name discs, shield silhouette, status icon order, rebirth star coloring, overlay height, text baselines, and obstruction/layer order. Any visible non-renderer discrepancy returns to Task 1 or 2 with a failing test.

### Task 4: Close evidence, review, and publish

**Files:**
- Modify: `docs/parity/v7.19.14-exact-parity-matrix.md`

- [x] **Step 1: Update only proven matrix rows**

Mark the rule banner complete only after the two-rule paired screenshot exists. Mark the battle-unit row complete only if all named state families in the frozen Web `drawUnit()` path are represented by test and screenshot evidence.

- [x] **Step 2: Run the full regression suite**

Run all `godot-demo/tests/test_*.gd`, `npm test` in `web-demo`, and `git diff --check`. Expected: 100% pass and no whitespace errors.

- [x] **Step 3: Request independent code review**

Review the diff against frozen Web lines 8569–8848, the tests, and paired screenshots. Fix all Critical, Important, and Minor findings before publication.

- [ ] **Step 4: Commit and push**

```powershell
git add docs godot-demo scripts
git commit -m "feat: match v7.19.14 battle unit states"
git -c http.version=HTTP/1.1 push origin godot/parity-v7.19.14
```
