import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { copyFile, mkdir, readFile } from "node:fs/promises";
import { dirname, extname, isAbsolute, join, normalize } from "node:path";

const root = process.cwd();
const outputDirectory = join(root, "output", "playwright");
const session = `special-unit-parity-${process.pid}`;
const npxCli = join(dirname(process.execPath), "node_modules", "npm", "bin", "npx-cli.js");

const server = createServer(async (request, response) => {
  try {
    const relative = decodeURIComponent(request.url.split("?")[0]).replace(/^\/+/, "");
    const path = normalize(join(root, relative));
    if (!path.startsWith(normalize(root))) throw new Error("path outside workspace");
    const body = await readFile(path);
    const type = { ".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8" }[extname(path)] || "application/octet-stream";
    response.writeHead(200, { "content-type": type });
    response.end(body);
  } catch (error) {
    response.writeHead(404);
    response.end(String(error));
  }
});

const listen = () => new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const closeServer = () => new Promise((resolve) => server.close(resolve));
const cli = (...args) => new Promise((resolve, reject) => {
  const argv = [npxCli, "--yes", "--package", "@playwright/cli", "playwright-cli", `-s=${session}`, ...args];
  const child = spawn(process.execPath, argv, { cwd: root, windowsHide: true, stdio: ["ignore", "pipe", "pipe"] });
  let stdout = "";
  let stderr = "";
  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");
  child.stdout.on("data", (chunk) => { stdout += chunk; });
  child.stderr.on("data", (chunk) => { stderr += chunk; });
  const timeout = setTimeout(() => child.kill(), 30000);
  child.on("error", (error) => { clearTimeout(timeout); reject(error); });
  child.on("exit", (code) => {
    clearTimeout(timeout);
    if (code !== 0) reject(new Error(stderr || stdout || `playwright-cli exited ${code}`));
    else resolve(stdout);
  });
});

const capture = async (filename) => {
  const screenshot = await cli("screenshot");
  const match = screenshot.match(/\(([^)\r\n]+\.png)\)/) || screenshot.match(/([^\r\n]+\.png)/);
  if (!match) throw new Error(`Unable to locate Playwright screenshot path: ${screenshot}`);
  const source = isAbsolute(match[1]) ? match[1] : join(root, match[1]);
  const destination = join(outputDirectory, filename);
  await copyFile(source, destination);
  process.stdout.write(`Captured ${destination}\n`);
};

try {
  await mkdir(outputDirectory, { recursive: true });
  await listen();
  const { port } = server.address();
  await cli("open", `http://127.0.0.1:${port}/reference/web-v7.19.14/index.html`);
  await cli("resize", "480", "800");
  const setup = `() => {
    const accountBox = document.getElementById('acctBox');
    if (accountBox) accountBox.classList.add('hide');
    meta.lords = {};
    for (const ruler of LORD_RULERS) meta.lords[ruler.id] = { lv: ruler.id === 'liubiao' ? 5 : 1, xp: 0 };
    meta.heroes = {};
    meta.week = 2948;
    newGame(makeWeekLevel(2948, 0));
    applyLevelField();
    applyRuler('caocao');
    state.phase = 'play';
    state.shenP = 0;
    foeLordTick(0);
    state.cards = null;
    state.speed = 0;
    state.wave = 10;
    state.waveTimer = 2;
    state.level = 1;
    state.xp = 0;
    state.xpNeed = 20;
    state.enemies = [];
    state.spawnQueue = [];
    state.nextQueue = null;
    state.nextWavePreview = null;
    state.slots = Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null));
    state.obstacles = new Set();
    state.traits = {};
    state.fieldBanner = 0;
    state.floaters = [];
    const fighter = makeUnit(GENERALS.find((general) => general.id === 'zhaoyun'));
    fighter.level = 6;
    fighter.hpMax = unitMaxHp(fighter.type, 6, 0);
    fighter.hp = fighter.hpMax;
    state.slots[1][1] = fighter;
    const unit = makeUnit(GRANARY_TYPE);
    unit.level = 2;
    unit.hpMax = unitMaxHp(unit.type, 2, 0);
    unit.hp = unit.hpMax;
    unit.farmAcc = 9;
    state.slots[1][2] = unit;
    state.traits['1,2'] = 'guard';
    computeTeam();
    state.ultConfirm = { unit, r: 1, c: 2 };
    return { version: GAME_VERSION, unit: unit.type.id, progress: Math.round(unit.farmAcc / granaryStarNeed() * 100) };
  }`.replace(/\r?\n\s*/g, " ");
  const stateResult = await cli("eval", setup);
  if (!stateResult.includes('"version": "7.19.14"') || !stateResult.includes('"unit": "granary"') || !stateResult.includes('"progress": 25')) throw new Error(`Unexpected granary state: ${stateResult}`);
  await capture("v7.19.14-web-granary-info.png");

  const eggState = await cli("eval", `() => {
    applyRuler('liubiao');
    state.relics = [RELICS.find((relic) => relic.id === 'longxian')];
    const unit = makeUnit(EGG_TYPE);
    unit.level = 2;
    unit.hpMax = unitMaxHp(unit.type, 2, 0);
    unit.hp = unit.hpMax;
    unit.hatchBonus = .2;
    unit.rbuffs = { farm: 5 };
    state.slots[1][2] = unit;
    state.traits['1,2'] = 'elem';
    computeTeam();
    state.ultConfirm = { unit, r: 1, c: 2 };
    return { unit: unit.type.id, chance: hatchChance(unit) };
  }`.replace(/\r?\n\s*/g, " "));
  if (!eggState.includes('"unit": "dragonegg"') || !eggState.includes('"chance": 0.9')) throw new Error(`Unexpected egg state: ${eggState}`);
  await capture("v7.19.14-web-egg-info.png");

  const dragonState = await cli("eval", `() => {
    const unit = makeUnit(DRAGON_TYPE);
    unit.dragonRank = 2;
    state.slots[1][2] = unit;
    state.dragonN = 1;
    state.traits['1,2'] = 'heal';
    computeTeam();
    state.ultConfirm = { unit, r: 1, c: 2 };
    return { unit: unit.type.id, damage: dragonDmg(unit), rank: unit.dragonRank };
  }`.replace(/\r?\n\s*/g, " "));
  if (!dragonState.includes('"unit": "yinglong"') || !dragonState.includes('"rank": 2')) throw new Error(`Unexpected dragon state: ${dragonState}`);
  await capture("v7.19.14-web-dragon-info.png");
} finally {
  try { await cli("close"); } catch {}
  await closeServer();
}
