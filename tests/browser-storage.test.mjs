import assert from "node:assert/strict";
import test from "node:test";
import { createBrowserStorage } from "../web-demo/src/platform/browser-storage.js";

function memoryStorage() {
  const values = new Map();
  return {
    getItem: (key) => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: (key) => values.delete(key),
  };
}

test("stores, reads, and removes string values", () => {
  const store = createBrowserStorage(memoryStorage());

  assert.equal(store.set("key", "value"), true);
  assert.equal(store.get("key"), "value");
  assert.equal(store.remove("key"), true);
  assert.equal(store.get("key"), null);
});

test("round-trips JSON values", () => {
  const store = createBrowserStorage(memoryStorage());
  const value = { gold: 12, heroes: { guanyu: { lv: 3 } } };

  assert.equal(store.setJson("meta", value), true);
  assert.deepEqual(store.getJson("meta"), value);
});

test("returns null for corrupt JSON", () => {
  const store = createBrowserStorage(memoryStorage());
  store.set("meta", "{broken");

  assert.equal(store.getJson("meta"), null);
});

test("contains denied storage errors", () => {
  const denied = {
    getItem() { throw new Error("denied"); },
    setItem() { throw new Error("denied"); },
    removeItem() { throw new Error("denied"); },
  };
  const store = createBrowserStorage(denied);

  assert.equal(store.get("key"), null);
  assert.equal(store.set("key", "value"), false);
  assert.equal(store.remove("key"), false);
  assert.equal(store.getJson("key"), null);
  assert.equal(store.setJson("key", { ok: true }), false);
});
