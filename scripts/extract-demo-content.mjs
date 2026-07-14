import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import vm from "node:vm";

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
  boss_kits: "BOSS_KITS",
  level_rules: "LEVEL_RULE_DEFS",
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
  items: "ITEMS_DEF",
};

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

const isMain = process.argv[1]
  && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMain) {
  const sourcePath = process.argv[2];
  const outputPath = process.argv[3];
  if (!sourcePath || !outputPath) {
    throw new Error("Usage: node scripts/extract-demo-content.mjs <source> <output>");
  }
  const snapshot = buildSnapshot(fs.readFileSync(sourcePath, "utf8"));
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(snapshot, null, 2)}\n`, "utf8");
}
