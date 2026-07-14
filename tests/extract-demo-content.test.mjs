import assert from "node:assert/strict";
import test from "node:test";
import { buildSnapshot, extractConstExpression } from "../scripts/extract-demo-content.mjs";

test("extracts a nested constant without stopping inside strings or functions", () => {
  const source = `
    const SAMPLE = [{ id: "a;still-a", fn: () => ({ value: 2 }) }];
    const NEXT = 3;
  `;
  const expression = extractConstExpression(source, "SAMPLE");
  const value = Function(`return (${expression})`)();
  assert.equal(value.length, 1);
  assert.equal(value[0].id, "a;still-a");
  assert.equal(value[0].fn().value, 2);
});

test("builds a JSON-safe snapshot from a supplied manifest", () => {
  const source = `
    const GAME_VERSION = "1.2.3";
    const ITEMS = [{ id: "one", name: "一", apply: () => 3 }];
  `;
  const snapshot = buildSnapshot(source, { items: "ITEMS" });
  assert.deepEqual(snapshot, {
    version: "1.2.3",
    items: [{ id: "one", name: "一" }],
  });
});
