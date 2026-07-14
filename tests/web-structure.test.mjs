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
  const apiSource = await readFile("web-demo/src/platform/account-api.js", "utf8");

  assert.match(source, /const GAME_VERSION = "7\.18\.8"/);
  assert.doesNotMatch(source, /\bfetch\s*\(/);
  assert.doesNotMatch(
    source,
    /\b(?:localStorage|sessionStorage)\.(?:getItem|setItem|removeItem)\s*\(/,
  );
  const networkSource = `${source}\n${apiSource}`;
  for (const route of ["register", "login", "load", "save", "battle", "board", "version"]) {
    assert.match(networkSource, new RegExp(`/api/${route}`));
  }
});
