# v7.19.2 Content Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a source-traceable Godot content catalog containing every static v7.19.2 gameplay definition needed by later out-of-run and battle migration.

**Architecture:** A small Node extractor reads named JavaScript constants from the frozen Web source and emits one deterministic JSON snapshot. Godot loads that JSON through a scene-independent `ContentCatalog`; tests pin authoritative counts and the newest v7.19.2 entities so later systems cannot silently omit content.

**Tech Stack:** Node.js built-in test runner, JavaScript scanner/evaluator, JSON, Godot 4.7, GDScript headless tests.

---

### Task 1: Test the JavaScript constant extractor

**Files:**
- Create: `tests/extract-demo-content.test.mjs`
- Create: `scripts/extract-demo-content.mjs`

- [x] **Step 1: Write the failing scanner test**

```javascript
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
```

- [x] **Step 2: Run the test and verify RED**

Run: `node --test tests/extract-demo-content.test.mjs`

Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `scripts/extract-demo-content.mjs`.

- [x] **Step 3: Implement the scanner**

```javascript
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import vm from "node:vm";

export function extractConstExpression(source, name) {
  const match = new RegExp(`\\bconst\\s+${name}\\s*=`).exec(source);
  if (!match) throw new Error(`Missing const ${name}`);
  const start = match.index + match[0].length;
  const stack = [];
  let quote = null;
  let escaped = false;
  let lineComment = false;
  let blockComment = false;

  for (let index = start; index < source.length; index += 1) {
    const char = source[index];
    const next = source[index + 1];
    if (lineComment) {
      if (char === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char === "*" && next === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (quote) {
      if (escaped) escaped = false;
      else if (char === "\\") escaped = true;
      else if (char === quote) quote = null;
      continue;
    }
    if (char === "/" && next === "/") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (char === "/" && next === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    if (char === '"' || char === "'" || char === "`") {
      quote = char;
      continue;
    }
    if (char === "{" || char === "[" || char === "(") stack.push(char);
    else if (char === "}" || char === "]" || char === ")") stack.pop();
    else if (char === ";" && stack.length === 0) return source.slice(start, index).trim();
  }
  throw new Error(`Unterminated const ${name}`);
}

export function evaluateConst(source, name, context = {}) {
  return vm.runInNewContext(`(${extractConstExpression(source, name)})`, context);
}
```

- [x] **Step 4: Run the scanner test and verify GREEN**

Run: `node --test tests/extract-demo-content.test.mjs`

Expected: one passing test.

### Task 2: Generate the authoritative JSON snapshot

**Files:**
- Modify: `scripts/extract-demo-content.mjs`
- Create: `godot-demo/data/content-v7.19.2.json`

- [x] **Step 1: Add the exact extraction manifest and CLI**

Append to `scripts/extract-demo-content.mjs`:

```javascript
const CONTENT_NAMES = {
  heroes: "GENERALS",
  hero_tiers: "HERO_TIER",
  rarities: "RARITY",
  milestones: "MILES",
  base_scores: "BASE_SCORE",
  bonds: "BONDS",
  affixes: "AFFIXES",
  relics: "RELICS",
  fields: "FIELDS",
  chapters: "CHAPTERS",
  level_names: "LEVEL_NAMES",
  state_names: "STATE_NAMES",
  week_themes: "WEEK_THEMES",
  rulers: "LORD_RULERS",
  lord_kin: "LORD_KIN",
  foe_cards: "FOE_CARDS",
  foe_lords: "FOE_LORDS",
  specials: "SPECIALS",
  special_tips: "SPECIAL_TIPS",
  mutations: "MUTATIONS",
  endless_rules: "ENDLESS_RULES",
  techs: "TECHS",
  achievements: "ACHS",
  items: "ITEMS_DEF"
};

export function buildSnapshot(source, manifest = CONTENT_NAMES) {
  const context = { Math, Set, W: 480, H: 800 };
  const snapshot = { version: evaluateConst(source, "GAME_VERSION", context) };
  for (const [key, name] of Object.entries(manifest)) {
    const value = evaluateConst(source, name, context);
    context[name] = value;
    snapshot[key] = value;
  }
  return JSON.parse(JSON.stringify(snapshot));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const sourcePath = process.argv[2];
  const outputPath = process.argv[3];
  if (!sourcePath || !outputPath) throw new Error("Usage: node scripts/extract-demo-content.mjs <source> <output>");
  const snapshot = buildSnapshot(fs.readFileSync(sourcePath, "utf8"));
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(snapshot, null, 2)}\n`, "utf8");
}
```

- [x] **Step 2: Generate the JSON**

Run:

```powershell
node scripts/extract-demo-content.mjs reference/web-v7.19.2/index.html godot-demo/data/content-v7.19.2.json
```

Expected: a UTF-8 JSON file with `version` equal to `7.19.2`.

- [x] **Step 3: Verify the source inventory counts**

Run:

```powershell
node -e "const c=require('./godot-demo/data/content-v7.19.2.json'); console.log(c.version,c.heroes.length,c.bonds.length,c.rulers.length,c.state_names.length,c.relics.length)"
```

Expected: `7.19.2 45 18 8 64 30`.

### Task 3: Load and validate content in Godot

**Files:**
- Create: `godot-demo/tests/test_content_catalog.gd`
- Create: `godot-demo/src/content/content_catalog.gd`

- [x] **Step 1: Write the failing Godot catalog test**

```gdscript
extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")

func _init() -> void:
    var catalog = ContentCatalog.new()
    assert(catalog.load_from("res://data/content-v7.19.2.json") == OK)
    assert(catalog.version == "7.19.2")
    assert(catalog.list("heroes").size() == 45)
    assert(catalog.list("bonds").size() == 18)
    assert(catalog.list("rulers").size() == 8)
    assert(catalog.list("state_names").size() == 64)
    assert(catalog.list("fields").size() == 11)
    assert(catalog.list("relics").size() == 30)
    assert(catalog.by_id("heroes", "wenchou").name == "文丑")
    assert(catalog.by_id("specials", "cata").name == "投石车")
    assert(catalog.by_id("rulers", "sunquan").special == "shuijun")
    print("Godot v7.19.2 content catalog: PASS")
    quit(0)
```

- [x] **Step 2: Run the test and verify RED**

Run:

```powershell
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --headless --path godot-demo --script res://tests/test_content_catalog.gd
```

Expected: non-zero exit because `content_catalog.gd` does not exist.

- [x] **Step 3: Implement the catalog**

```gdscript
class_name ContentCatalog
extends RefCounted

var version := ""
var content: Dictionary = {}
var indexes: Dictionary = {}

func load_from(path: String) -> Error:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return ERR_PARSE_ERROR
    version = str(parsed.get("version", ""))
    content = parsed
    indexes.clear()
    return OK

func list(key: String) -> Array:
    var value = content.get(key, [])
    if value is Array:
        return value
    if value is Dictionary:
        return value.values()
    return []

func by_id(key: String, id: String) -> Dictionary:
    if not indexes.has(key):
        var index := {}
        var value = content.get(key, [])
        if value is Array:
            for entry in value:
                if entry is Dictionary and entry.has("id"):
                    index[str(entry.id)] = entry
        elif value is Dictionary:
            for entry_id in value:
                var entry = value[entry_id]
                if entry is Dictionary:
                    entry = entry.duplicate()
                    entry["id"] = str(entry_id)
                    index[str(entry_id)] = entry
        indexes[key] = index
    return indexes[key].get(id, {})
```

- [x] **Step 4: Run catalog and regression tests**

Expected: content catalog, main flow and progression tests print `PASS`; `npm test` remains green.

- [x] **Step 5: Commit and push**

```text
feat: add v7.19.2 Godot content catalog
```
