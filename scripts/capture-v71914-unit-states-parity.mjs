import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { copyFile, mkdir, readFile } from "node:fs/promises";
import { dirname, extname, isAbsolute, join, normalize } from "node:path";

const root = process.cwd();
const outputDirectory = join(root, "output", "playwright");
const session = `unit-states-parity-${process.pid}`;
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
  const timeout = setTimeout(() => child.kill(), 60000);
  child.on("error", (error) => { clearTimeout(timeout); reject(error); });
  child.on("exit", (code) => {
    clearTimeout(timeout);
    if (code !== 0) reject(new Error(`${args.join(" ")}: ${stderr || stdout || `playwright-cli exited ${code}`}`));
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
  process.stdout.write("unit-state capture: preparing server\n");
  await mkdir(outputDirectory, { recursive: true });
  await listen();
  const { port } = server.address();
  process.stdout.write(`unit-state capture: opening frozen Web on ${port}\n`);
  await cli("open", `http://127.0.0.1:${port}/reference/web-v7.19.14/index.html`);
  process.stdout.write("unit-state capture: resizing viewport\n");
  await cli("resize", "480", "800");
  const setup = `() => {
    const accountBox = document.getElementById('acctBox');
    if (accountBox) accountBox.classList.add('hide');
    meta.lords = {};
    for (const ruler of LORD_RULERS) meta.lords[ruler.id] = { lv: 1, xp: 0 };
    meta.heroes = {
      zhaoyun: { lv: 10, xp: 0, rb: 2 },
      yanyan: { lv: 1, xp: 0, rb: 0 },
      zhoutai: { lv: 1, xp: 0, rb: 1 },
      zhangfei: { lv: 1, xp: 0, rb: 0 }
    };
    meta.week = 2948;
    newGame(makeWeekLevel(2948, 0));
    applyLevelField();
    applyRuler('liubei');
    state.phase = 'play';
    let shenPeriod = SHEN_P0;
    while (shenPeriod < SHEN_P0 + 500 && !shenIdsOf(shenPeriod).includes('zhaoyun')) shenPeriod++;
    state.shenP = shenPeriod;
    state.cards = null;
    state.speed = 0;
    state.time = 1.2;
    state.wave = 8;
    state.waveTimer = 3;
    state.waveClock = 0;
    state.waveBudget = 20;
    state.kills = 123;
    state.level = 7;
    state.xp = 7;
    state.xpNeed = 20;
    state.enemies = [];
    state.spawnQueue = [];
    state.foeLord = null;
    state.nextQueue = null;
    state.nextWavePreview = { themeElems: ['liangmou'], mutation: null, boss: null, affixes: {}, specials: {} };
    state.slots = Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null));
    state.obstacles = new Set();
    state.traits = {};
    const shield = makeUnit(GENERALS.find((general) => general.id === 'yanyan'));
    const zhao = makeUnit(GENERALS.find((general) => general.id === 'zhaoyun'));
    const zhou = makeUnit(GENERALS.find((general) => general.id === 'zhoutai'));
    const zhang = makeUnit(GENERALS.find((general) => general.id === 'zhangfei'));
    for (const unit of [shield, zhao, zhou, zhang]) unit.bounce = 0;
    zhao.level = 12;
    zhao.rbuffs = { heal: 4, haste: 4, dmg: 4, crit: 4, cdr: 4, farm: 4 };
    zhou.reflectT = 3;
    zhang.sealedT = 3;
    state.slots[1][0] = shield;
    state.slots[1][1] = zhao;
    state.slots[1][3] = zhou;
    state.slots[2][2] = zhang;
    state.taoyuanT = 3;
    state.armyBuff = { t: 3, mul: 1.3 };
    state.armyHaste = { t: 3, mul: 1.4 };
    state.fieldBanner = 0;
    state.floaters = [];
    computeTeam();
    draw();
    return { version: GAME_VERSION, phase: state.phase, shen: isShen('zhaoyun'), rb: heroRb('zhaoyun'), units: allUnits().length, zhaoIcons: Object.keys(zhao.rbuffs).length, reflected: zhou.reflectT, sealed: zhang.sealedT };
  }`.replace(/\r?\n\s*/g, " ");
  process.stdout.write("unit-state capture: injecting fixed state\n");
  const stateResult = await cli("eval", setup);
  process.stdout.write("unit-state capture: validating fixed state\n");
  if (!stateResult.includes('"version": "7.19.14"') || !stateResult.includes('"shen": true') || !stateResult.includes('"rb": 2') || !stateResult.includes('"units": 4') || !stateResult.includes('"zhaoIcons": 6') || !stateResult.includes('"reflected": 3') || !stateResult.includes('"sealed": 3')) {
    throw new Error(`Unexpected unit-state parity fixture: ${stateResult}`);
  }
  process.stdout.write("unit-state capture: capturing PNG\n");
  await capture("v7.19.14-web-unit-states.png");
} finally {
  try { await cli("close"); } catch {}
  await closeServer();
}
