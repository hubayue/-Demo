import assert from "node:assert/strict";
import test from "node:test";
import { extractConstExpression } from "../scripts/extract-demo-content.mjs";

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
