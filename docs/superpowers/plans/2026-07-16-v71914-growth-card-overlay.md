# v7.19.14 局内选卡浮层精确复现 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Godot 的局内三/四/五选一与老板 Web v7.19.14 在布局、字段、入场动画、误触保护、乐不思蜀高亮和点击优先级上保持一致。

**Architecture:** `BattleCards` 负责生成卡牌可观察字段和亲军登场星级，`BattleRun` 保存自动选牌的稳定目标，`main.gd` 只负责 480×800 的卡面布局、动画时间和输入路由。固定 Web/Godot 状态捕获相同的三张牌，用截图和坐标测试共同验收。

**Tech Stack:** Godot 4.7、GDScript、冻结 Web v7.19.14、Playwright CLI、Godot SceneTree 测试、480×800 PNG。

---

### Task 1: 锁定 Web 卡面几何与点击保护

**Files:**
- Modify: `godot-demo/tests/test_battle_hud_controls.gd`
- Modify: `godot-demo/tests/test_battle_cards.gd`
- Modify: `godot-demo/src/app/main.gd`

- [ ] **Step 1: Write the failing geometry and input tests**

断言三选一矩形为 `Rect2(20,294,140,146)`、四选一首尾为 `Rect2(9,294,108,146)` / `Rect2(363,294,108,146)`、五选一首尾为 `Rect2(9,294,86,146)` / `Rect2(385,294,86,146)`；新牌出现 0.35 秒内点击不选牌，超过 0.35 秒后才允许选择；有牌时卡面外点击必须被消费，不能穿透到输出、退出、主公技或敌人。

- [ ] **Step 2: Run tests and verify RED**

Run: `.\.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe --headless --path godot-demo --script res://tests/test_battle_hud_controls.gd`

Expected: FAIL because the current cards use y=278/h=244 and do not implement Web's 350ms guard.

- [ ] **Step 3: Implement minimal card UI timing and routing**

Add `growth_card_age`, `growth_card_anim`, and a choice signature to `main.gd`; sync them after `battle_run.advance_real(delta)`. Route clicks in Web order: gewu wake-up → field banner → cata/foe overlay → growth cards → side buttons/lord/enemy. When cards are open, return even if the click misses every card.

- [ ] **Step 4: Run tests and verify GREEN**

Run both `test_battle_hud_controls.gd` and `test_main_flow.gd`; expected PASS.

### Task 2: 恢复亲军卡字段与登场加星

**Files:**
- Modify: `godot-demo/src/battle/battle_cards.gd`
- Modify: `godot-demo/src/battle/battle_run.gd`
- Modify: `godot-demo/tests/test_battle_cards.gd`

- [ ] **Step 1: Write failing observable-field tests**

在刘备局检查未上阵的关羽卡包含 `✋仁德系 · 🐎骑兵`、图鉴等级、品质色和 `🤝亲军·登场+1星`；在普通/良将亲军样本上检查 `+2星`。选中亲军卡后，实际单位星级必须等于局外等级起始星加亲军赠星并受 15 星上限约束。

- [ ] **Step 2: Run tests and verify RED**

Run: `.\.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe --headless --path godot-demo --script res://tests/test_battle_cards.gd`

Expected: FAIL because current cards omit `info/lvN/tag` and `_make_unit()` omits `kinGiftStars()`.

- [ ] **Step 3: Implement Web card fields and kin gift**

Generate `info`, `infoColor`, `lvN`, `tag`, and `tagBad` when building unit/upgrade cards. Add one `kin_gift_stars(hero_id)` helper in `BattleRun` using current ruler kin and `hero_tiers`; apply it once in `_make_unit()`.

- [ ] **Step 4: Run tests and verify GREEN**

Run `test_battle_cards.gd`, `test_battle_lord.gd`, and `test_battle_run.gd`; expected PASS.

### Task 3: 精确绘制卡面与乐不思蜀选牌高亮

**Files:**
- Modify: `godot-demo/src/app/main.gd`
- Modify: `godot-demo/src/battle/battle_run.gd`
- Modify: `godot-demo/tests/test_battle_unit_presentation.gd`

- [ ] **Step 1: Write failing visual-spec tests**

断言外框 `Rect2(8,260,464,198)`、卡片圆角 12、遗宝/普通卡渐变端色、兵种边框色、完整武将姓名、属性兵种行、星级行、图鉴等级、最多三行描述、标签矩形 `x+6,y+4,76,18`。乐不思蜀必须在前 1 秒轮转索引，后 0.5 秒固定到预先选中的安全卡。

- [ ] **Step 2: Run tests and verify RED**

Run `test_battle_unit_presentation.gd` and `test_battle_cards.gd`; expected FAIL on missing visual spec and stable auto-selection index.

- [ ] **Step 3: Implement minimal rendering**

Replace the full-screen black overlay with the Web bottom panel; use the shared name-disc size rule, vertical rounded gradient strips, Web font sizes and y offsets. Store one `gewu_auto_index` in `BattleRun`, pick it when auto-selection begins, expose the current highlight index to `main.gd`, and clear it after applying/closing cards.

- [ ] **Step 4: Run tests and verify GREEN**

Run the targeted HUD, card, unit-presentation and main-flow tests; expected PASS.

### Task 4: 双端固定截图、全量回归与提交

**Files:**
- Create: `scripts/capture-v71914-growth-cards-parity.mjs`
- Create: `godot-demo/tests/capture_v71914_growth_cards.gd`
- Modify: `docs/parity/v7.19.14-exact-parity-matrix.md`

- [ ] **Step 1: Create matching Web/Godot fixtures**

两端固定为 week 2948、刘备、张飞/赵云阵容、wave 1、`张飞练兵 / 关羽出征 / 全军猛攻` 三张卡、卡动画完成、题面关闭；输出 `output/playwright/v7.19.14-web-growth-cards.png` 与 `output/godot/v7.19.14-growth-cards.png`。

- [ ] **Step 2: Verify captures and regressions**

Run both capture scripts, all Godot `test_*.gd`, `npm test`, Godot check-only/editor import and `git diff --check`; expected all PASS and both images are non-empty 480×800.

- [ ] **Step 3: Self-review and independent review**

Compare against Web `cardRect`, `drawCardArea`, `onDown`, `update` and `makeUnit`; fix every Critical/Important issue, then rerun targeted and full regression.

- [ ] **Step 4: Commit and push**

Run `git add` for only this slice, `git commit -m "feat: match v7.19.14 growth cards"`, then push `godot/parity-v7.19.14`.
