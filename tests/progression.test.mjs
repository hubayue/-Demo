import assert from "node:assert/strict";
import test from "node:test";
import {
  starDamageMultiplier,
  starParts,
} from "../web-demo/src/core/progression.js";

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
  assert.equal(
    starDamageMultiplier(11, false),
    Math.pow(1.9, 4) * Math.pow(1.4, 5) * 1.3,
  );
  assert.equal(
    starDamageMultiplier(11, true),
    Math.pow(1.9, 4) * Math.pow(1.5, 5) * 1.4,
  );
});
