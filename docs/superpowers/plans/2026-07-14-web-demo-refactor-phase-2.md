# Web Demo Refactor Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove direct network and browser-storage operations from the gameplay monolith while preserving the v7.18.8 server protocol and cache behavior.

**Architecture:** Add two dependency-injected platform adapters. `account-api.js` owns JSON HTTP requests, while `browser-storage.js` owns exception-safe string and JSON access; `main.js` remains the composition root and keeps all current orchestration decisions.

**Tech Stack:** JavaScript ES modules, Fetch API, Web Storage API, Node.js built-in test runner, Playwright CLI.

---

### Task 1: Extract the account API client

**Files:**
- Create: `tests/account-api.test.mjs`
- Create: `web-demo/src/platform/account-api.js`
- Modify: `web-demo/src/main.js`
- Modify: `tests/web-structure.test.mjs`

- [x] **Step 1: Write failing tests for POST, version, and board requests**

```js
const calls = [];
const fetchImpl = async (...args) => {
  calls.push(args);
  return { json: async () => ({ ok: true }) };
};
const client = createAccountApi({ fetchImpl, now: () => 123 });
```

Assert that `post("/api/login", body)` uses JSON POST options, `getVersion()` requests `/api/version?t=123`, and `getBoard()` requests `/api/board`.

- [x] **Step 2: Run the account API test and verify RED**

Run: `node --test tests/account-api.test.mjs`

Expected: FAIL because `web-demo/src/platform/account-api.js` does not exist.

- [x] **Step 3: Implement `createAccountApi`**

```js
export function createAccountApi({ fetchImpl, now = Date.now }) {
  async function readJson(url, options) {
    const response = await fetchImpl(url, options);
    return response.json();
  }

  return Object.freeze({
    post(route, body) {
      return readJson(route, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body || {}),
      });
    },
    getVersion() {
      return readJson(`/api/version?t=${now()}`);
    },
    getBoard() {
      return readJson("/api/board");
    },
  });
}
```

- [x] **Step 4: Wire the adapter into `main.js`**

Keep the existing `api(route, body)` function as a compatibility delegate, and replace only the two direct GET calls.

- [x] **Step 5: Update the structure test**

Assert that `main.js` contains no direct `fetch(` call and that the seven current `/api/*` routes remain present across `main.js` plus `platform/account-api.js`.

- [x] **Step 6: Run all tests and browser smoke verification**

Expected: tests pass without warnings; login overlay loads with no new console error.

- [x] **Step 7: Commit**

```text
refactor: isolate account API transport
```

### Task 2: Extract safe browser storage

**Files:**
- Create: `tests/browser-storage.test.mjs`
- Create: `web-demo/src/platform/browser-storage.js`
- Modify: `web-demo/src/main.js`

- [x] **Step 1: Write failing tests for string, JSON, corrupt data, and denied storage**

The tests use a small in-memory storage object and a storage object whose methods throw. Verify that storage errors never escape and corrupt JSON returns `null`.

- [x] **Step 2: Run the storage tests and verify RED**

Run: `node --test tests/browser-storage.test.mjs`

Expected: FAIL because `web-demo/src/platform/browser-storage.js` does not exist.

- [x] **Step 3: Implement the storage adapter**

```js
export function createBrowserStorage(storage) {
  return Object.freeze({
    get(key) {
      try { return storage ? storage.getItem(key) : null; } catch { return null; }
    },
    set(key, value) {
      try { storage?.setItem(key, value); return true; } catch { return false; }
    },
    remove(key) {
      try { storage?.removeItem(key); return true; } catch { return false; }
    },
    getJson(key) {
      const value = this.get(key);
      if (value == null) return null;
      try { return JSON.parse(value); } catch { return null; }
    },
    setJson(key, value) {
      return this.set(key, JSON.stringify(value));
    },
  });
}
```

- [x] **Step 4: Compose local and session adapters in `main.js`**

Replace the existing direct `localStorage` and `sessionStorage` calls without changing keys, remembered-account behavior, cache fallback, or resume behavior.

- [x] **Step 5: Run all tests and browser smoke verification**

Expected: tests pass without warnings; login overlay and remembered-account controls still render.

- [x] **Step 6: Commit**

```text
refactor: isolate browser storage access
```
