# v7.19.14 Player Lord Popup and Command HUD

**Goal:** Restore the frozen Web player-lord interaction exactly: the right-side nameplate and circular command open a paused lord panel, the panel explains current basic attack and command timing, and only its ready-state button performs a manual cast.

**Authority:** `reference/web-v7.19.14/index.html` `lordBtnRect`, `drawLordBar`, `drawLordPop`, `castLord`, `onUp`, and the main-loop pause branch. The Web behavior wins over current Godot behavior and old docs.

## Task 1: Lock the interaction and presentation contract

- [x] Add failing tests for nameplate/command hitboxes, open/close priority, no direct cast, paused combat with live visual time, ready cast button, and exact Liu Bei panel copy.
- [x] Add failing tests for Web-only manual command exceptions: `jiejiang` may be laid with no enemies and `jianhao` remains available during `gewu`.
- [x] Add a pure command visual spec covering ready/auto-ready, cooldown fraction, icon, name, and three-star track.

## Task 2: Implement the lord panel and circular HUD

- [x] Add player-lord popup state and input priority matching Web `onUp`.
- [x] Draw the 350px panel at `(65,150)`, current basic-attack estimate, command card, automatic timing, cooldown/kin line, ready manual-cast button, and paused footer.
- [x] Replace the simplified command control with the Web circle, cooldown sector, breathing-ready border, icon/name, star dots, and integer cooldown label.
- [x] Preserve pure visual animation while the lord panel pauses combat simulation.

## Task 3: Produce paired acceptance evidence

- [x] Capture the same Liu Bei ready-command state at 480×800 from frozen Web and Godot.
- [x] Inspect both images for geometry, hierarchy, wording, and overlay order; correct material differences.
- [x] Update the exact-parity matrix without claiming the whole battle HUD complete.

## Task 4: Verify and deliver

- [x] Run targeted tests, all Godot `test_*.gd`, `npm test`, editor import, capture-size checks, and `git diff --check`.
- [x] Request independent review and close every Critical/Important finding.
- [x] Commit as `feat: match v7.19.14 player lord HUD`, push `godot/parity-v7.19.14`, and verify remote HEAD.
