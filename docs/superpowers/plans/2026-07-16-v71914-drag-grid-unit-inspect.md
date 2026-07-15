# v7.19.14 武将拖动、阵地反馈与点将面板 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Godot 的 15 格阵地、武将按下/拖动/换位/售出/非法落点和原地点将面板与老板 Web v7.19.14 的鼠标、触摸体验一致。

**Architecture:** `BattleDragController` 只保存 Web 指针状态并产出 `inspect/drop/sell/cancel` 意图；`BattleRun` 继续作为编队规则权威；`main.gd` 负责输入优先级、可见反馈、射程/地利预览和点将面板。固定 Web/Godot 场景复用同一阵容、格子、障碍和指针坐标生成可对照截图。

**Tech Stack:** Godot 4.7、GDScript、冻结 Web v7.19.14、Playwright CLI、SceneTree 输入测试、480×800 PNG。

---

### Task 1: 锁定 Web 指针状态机与编队结果

**Files:**
- Modify: `godot-demo/src/input/battle_drag_controller.gd`
- Modify: `godot-demo/src/battle/battle_run.gd`
- Modify: `godot-demo/tests/test_battle_drag_controller.gd`

- [x] **Step 1: Write failing pointer-state tests**

在 `test_battle_drag_controller.gd` 断言：移动距离恰好 14px 仍是点击，超过 14px 才进入拖动；松手不重新采样未发生的 move；未拖动返回 `inspect`；已拖到阵地上方返回 `sell`；侧边/下方阵地外返回 `cancel`。再覆盖邓艾进石头、普通武将进石头、从石头与普通目标换位三种结果。

- [x] **Step 2: Run test and verify RED**

Run: `..\.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe --headless --path godot-demo --script res://tests/test_battle_drag_controller.gd`

Expected: FAIL because the controller currently uses an 8px threshold, resamples on release, and has no `inspect` action.

- [x] **Step 3: Implement the minimal Web state machine**

Set `DRAG_THRESHOLD = 14.0`; change motion to `distance_squared > 14²`; let `finish()` consume the last move position without calling `update()` and return `inspect` when `moved == false`. Keep placement authority in `move_or_swap_unit()` and expose one reason helper for obstacle and swap rejection so the UI can display the correct Web sentence without duplicating rules.

- [x] **Step 4: Run targeted tests and verify GREEN**

Run `test_battle_drag_controller.gd`, `test_battle_run.gd`, and `test_battle_team.gd`; expected PASS.

### Task 2: Restore press/drag visuals, feedback and unit inspection

**Files:**
- Modify: `godot-demo/src/app/main.gd`
- Create: `godot-demo/tests/test_battle_drag_interactions.gd`
- Modify: `godot-demo/tests/test_battle_drag_preview.gd`

- [x] **Step 1: Write failing Main interaction tests**

Use real `InputEventMouseButton`, `InputEventMouseMotion`, `InputEventScreenTouch`, and `InputEventScreenDrag` events. Assert an original-position click opens `{unit,row,col}`; the panel pauses wave simulation but advances visual time; clicking elsewhere closes it and can immediately begin another unit drag; a unit dying during drag cancels the pointer state; illegal obstacle drop and protected last-unit sale create the exact visible feedback.

- [x] **Step 2: Write failing visual-spec tests**

Assert the source unit is lifted as soon as press begins, target cell is `Rect2(GRID_X+c*82+3, GRID_Y+r*82+3, 76,76)`, Web trait copy uses icon/name/description, cavalry includes the main and adjacent two corridors, support copy depends on ripple type, spear aura highlights only attacking allies, and the normal hero panel is `Rect2(85,290,310,206)` with title/HP/badge/description/ultimate/CD/terrain/status fields.

- [x] **Step 3: Run tests and verify RED**

Run `test_battle_drag_interactions.gd` and `test_battle_drag_preview.gd`; expected FAIL on absent inspection state, threshold visuals, feedback model, panel spec, effective range and exact trait/support copy.

- [x] **Step 4: Implement input routing and visible feedback**

Add `unit_info_popup` and one short-lived `battle_interaction_notice` to `main.gd`. Route `inspect/drop/sell/cancel` from `_finish_battle_drag()`, close the panel with Web passthrough semantics, cancel drag if the source unit disappears, and skip battle simulation while the unit panel is open while still advancing `game_time` once per real frame.

- [x] **Step 5: Implement exact drag preview and normal-hero panel**

Draw the lifted unit and range preview for every active press, show sell copy only after movement, use effective range and Web class-specific text, draw trait and spear links, then render the 310×206 unit panel above the battlefield/cards with the source cell and range highlighted. Keep special building/egg/dragon accounting out of this normal-hero panel slice and leave their matrix item open.

- [x] **Step 6: Run targeted tests and verify GREEN**

Run the two new/modified drag tests plus `test_main_flow.gd`, `test_battle_unit_presentation.gd`, and `test_siege_focus.gd`; expected PASS with no script errors.

### Task 3: Capture identical Web/Godot drag, sell and inspect states

**Files:**
- Create: `scripts/capture-v71914-drag-unit-parity.mjs`
- Modify: `godot-demo/tests/capture_v71914_drag_screen.gd`
- Modify: `docs/parity/v7.19.14-exact-parity-matrix.md`

- [x] **Step 1: Create the frozen Web fixtures**

Set week 2948, 刘备, wave 1, 赵云 at row2/col2, 张飞 at row1/col2, four corner obstacles and deterministic haste traits. Capture pointer-over-row0/col2 drag, pointer-y410 sell, and original-position 赵云 inspection as `v7.19.14-web-battle-drag.png`, `...-sell.png`, and `...-unit-info.png`.

- [x] **Step 2: Create matching Godot fixtures**

Use the same state and coordinates in `capture_v71914_drag_screen.gd`, set process false after fixture construction, render three non-empty 480×800 PNGs under `output/godot/`, and fail the script if any image is missing or wrong-sized.

- [x] **Step 3: Compare and correct**

Open all six images at original resolution. Correct every layout, text, color-layer, target highlight and overlay-order difference except unavoidable font rasterization.

- [x] **Step 4: Update the parity matrix**

Mark “拖动与换位” complete only after mouse/touch tests and all three screenshot pairs pass; keep special-unit point-inspection separately listed as incomplete if it is not covered.

### Task 4: Regression, review, commit and push

**Files:**
- Verify all files in this plan

- [x] **Step 1: Run complete verification**

Run all Godot `test_*.gd`, `npm test`, both capture scripts, Godot editor import, `git diff --check`, and verify all six PNGs are 480×800 and non-empty.

- [x] **Step 2: Request independent review**

Review against Web `drawBattle`, `drawUltConfirm`, `onDown`, `onMove`, and `onUp`; fix every Critical/Important issue and rerun targeted/full verification.

- [x] **Step 3: Commit and push**

Commit only this slice with `feat: match v7.19.14 drag interactions` and push `godot/parity-v7.19.14`; verify local HEAD equals the remote branch.
