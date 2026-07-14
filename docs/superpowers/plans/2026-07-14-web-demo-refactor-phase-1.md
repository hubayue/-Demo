# Web Demo Refactor Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the v7.18.8 single-file Demo into a testable multi-file web application without changing gameplay, data, visuals, input, or network behavior.

**Architecture:** Preserve the current Canvas runtime and global execution order while extracting the HTML shell, CSS, and JavaScript into focused files. Add Node built-in tests for source invariants and pure progression math, then verify the refactored page against the captured live baseline in a real browser.

**Tech Stack:** HTML5 Canvas, JavaScript ES modules, Node.js built-in test runner, Playwright CLI, Git.

---

### Task 1: Add the structural regression harness

**Files:**
- Create: `package.json`
- Create: `tests/web-structure.test.mjs`

- [x] **Step 1: Write the failing structure test**

```js
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("web shell loads external stylesheet and module entrypoint", async () => {
  const html = await readFile("web-demo/index.html", "utf8");
  assert.match(html, /<link rel="stylesheet" href="\.\/styles\/main\.css">/);
  assert.match(html, /<script type="module" src="\.\/src\/main\.js"><\/script>/);
  assert.doesNotMatch(html, /<style>/);
  assert.doesNotMatch(html, /<script>\s*"use strict"/);
});

test("extracted runtime retains the live version and server routes", async () => {
  const source = await readFile("web-demo/src/main.js", "utf8");
  assert.match(source, /const GAME_VERSION = "7\.18\.8"/);
  for (const route of ["register", "login", "load", "save", "battle", "board", "version"]) {
    assert.match(source, new RegExp(`/api/${route}`));
  }
});
```

- [x] **Step 2: Configure the test command**

```json
{
  "name": "sanguo-demo-modernization",
  "private": true,
  "scripts": {
    "test": "node --test"
  }
}
```

- [x] **Step 3: Run the tests and verify RED**

Run: `npm test`

Expected: FAIL because `web-demo/index.html` still contains inline style/script blocks and `web-demo/src/main.js` does not exist.

### Task 2: Mechanically split the monolith

**Files:**
- Modify: `web-demo/index.html`
- Create: `web-demo/styles/main.css`
- Create: `web-demo/src/main.js`

- [x] **Step 1: Extract the current style block byte-for-byte into `styles/main.css`**

- [x] **Step 2: Extract the current script body byte-for-byte into `src/main.js`**

- [x] **Step 3: Replace the inline blocks with these exact tags**

```html
<link rel="stylesheet" href="./styles/main.css">
<script type="module" src="./src/main.js"></script>
```

- [x] **Step 4: Run the tests and verify GREEN**

Run: `npm test`

Expected: both structure tests PASS.

- [x] **Step 5: Serve `web-demo/` over HTTP and verify the login overlay in Playwright**

Expected: the login overlay, Canvas background, version `v7.18.8`, and navigation buttons match the saved remote baseline; no new console errors appear.

- [x] **Step 6: Commit**

```text
refactor: split web demo shell from runtime
```

### Task 3: Extract pure progression math

**Files:**
- Create: `web-demo/src/core/progression.js`
- Modify: `web-demo/src/main.js`
- Create: `tests/progression.test.mjs`

- [x] **Step 1: Write failing tests for the 1-15 star display segments**

```js
import assert from "node:assert/strict";
import test from "node:test";
import { starParts, starDamageMultiplier } from "../web-demo/src/core/progression.js";

test("starParts maps each five-star tier", () => {
  assert.deepEqual(starParts(1), { t2: 0, hi: 0, lo: 1 });
  assert.deepEqual(starParts(5), { t2: 0, hi: 0, lo: 5 });
  assert.deepEqual(starParts(6), { t2: 0, hi: 1, lo: 4 });
  assert.deepEqual(starParts(10), { t2: 0, hi: 5, lo: 0 });
  assert.deepEqual(starParts(11), { t2: 1, hi: 4, lo: 0 });
  assert.deepEqual(starParts(15), { t2: 5, hi: 0, lo: 0 });
});

test("starDamageMultiplier preserves normal and phoenix scaling", () => {
  assert.equal(starDamageMultiplier(1, false), 1);
  assert.equal(starDamageMultiplier(6, false), Math.pow(1.9, 4) * 1.4);
  assert.equal(starDamageMultiplier(11, false), Math.pow(1.9, 4) * Math.pow(1.4, 5) * 1.3);
  assert.equal(starDamageMultiplier(11, true), Math.pow(1.9, 4) * Math.pow(1.5, 5) * 1.4);
});
```

- [x] **Step 2: Run the progression tests and verify RED**

Run: `node --test tests/progression.test.mjs`

Expected: FAIL because `web-demo/src/core/progression.js` does not exist.

- [x] **Step 3: Implement the pure module**

```js
export function starParts(level) {
  if (level <= 5) return { t2: 0, hi: 0, lo: level };
  if (level <= 10) return { t2: 0, hi: level - 5, lo: 10 - level };
  return { t2: level - 10, hi: 15 - level, lo: 0 };
}

export function starDamageMultiplier(level, hasPhoenixFeather) {
  const ascended = hasPhoenixFeather ? 1.5 : 1.4;
  const ascended2 = hasPhoenixFeather ? 1.4 : 1.3;
  return Math.pow(1.9, Math.min(level, 5) - 1)
    * Math.pow(ascended, Math.max(0, Math.min(level, 10) - 5))
    * Math.pow(ascended2, Math.max(0, level - 10));
}
```

- [x] **Step 4: Import the module in `main.js` and delegate the existing helpers**

```js
import { starParts, starDamageMultiplier } from "./core/progression.js";
```

The existing rendering-facing `starDmgMul(level)` remains as a compatibility adapter that reads the current relic state and calls `starDamageMultiplier(level, hasPhoenixFeather)`.

- [x] **Step 5: Run all tests and verify GREEN**

Run: `npm test`

Expected: all tests PASS.

- [x] **Step 6: Repeat the Playwright login-screen smoke test**

Expected: no visual or console regression from the baseline.

- [x] **Step 7: Commit**

```text
refactor: extract progression math from demo runtime
```

### Task 4: Record the next architecture boundaries

**Files:**
- Create: `docs/architecture/web-demo-boundaries.md`

- [ ] **Step 1: Document the current dependency seams**

Record these next extraction boundaries in order: account API, persistence/cache, static content data, battle state/update, Canvas rendering, and pointer/keyboard input.

- [ ] **Step 2: Define the Godot handoff contract**

Specify that portable gameplay rules must be represented as pure functions plus serializable data before the corresponding Godot system is implemented.

- [ ] **Step 3: Run `npm test` and `git diff --check`**

Expected: all tests PASS and no whitespace errors.

- [ ] **Step 4: Commit**

```text
docs: define web refactor boundaries for Godot migration
```
