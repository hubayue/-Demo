import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { copyFile, mkdir, readFile } from "node:fs/promises";
import { dirname, extname, isAbsolute, join, normalize } from "node:path";

const root = process.cwd();
const outputDirectory = join(root, "output", "playwright");
const battleOutput = join(outputDirectory, "v7.19.14-web-battle-shell.png");
const lordOutput = join(outputDirectory, "v7.19.14-web-player-lord-popup.png");
const session = `battle-shell-parity-${process.pid}`;
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

const capture = async (output) => {
  const screenshot = await cli("screenshot");
  const match = screenshot.match(/\(([^)\r\n]+\.png)\)/) || screenshot.match(/([^\r\n]+\.png)/);
  if (!match) throw new Error(`Unable to locate Playwright screenshot path: ${screenshot}`);
  const source = isAbsolute(match[1]) ? match[1] : join(root, match[1]);
  await copyFile(source, output);
  process.stdout.write(`Captured ${output}\n`);
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
    for (const ruler of LORD_RULERS) meta.lords[ruler.id] = { lv: 1, xp: 0 };
    meta.week = 2948;
    newGame(makeWeekLevel(2948, 0));
    applyLevelField();
    applyRuler('liubei');
    state.phase = 'play';
    foeLordTick(0);
    state.cards = null;
    state.speed = 0;
    state.wave = 1;
    state.waveTimer = 2;
    state.waveClock = 0;
    state.waveBudget = 20;
    state.kills = 0;
    state.level = 1;
    state.xp = 0;
    state.xpNeed = 10;
    state.enemies = [];
    state.spawnQueue = [];
    state.slots = Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null));
    state.obstacles = new Set(['0,0', '0,4', '2,0', '2,4']);
    state.traits = {};
    for (let r = 0; r < GRID_ROWS; r++) for (let c = 0; c < GRID_COLS; c++) state.traits[r + ',' + c] = 'haste';
    state.slots[2][2] = makeUnit(GENERALS.find((general) => general.id === 'zhaoyun'));
    state.slots[1][2] = makeUnit(GENERALS.find((general) => general.id === 'zhangfei'));
    computeTeam();
    state.fieldBanner = 9;
    state.floaters = [];
    return { version: GAME_VERSION, phase: state.phase, ruler: state.ruler, units: allUnits().length };
  }`.replace(/\r?\n\s*/g, " ");
  const stateResult = await cli("eval", setup);
  if (!stateResult.includes('"version": "7.19.14"') || !stateResult.includes('"phase": "play"') || !stateResult.includes('"units": 2')) {
    throw new Error(`Unexpected battle shell state: ${stateResult}`);
  }
  await capture(battleOutput);
  const lordState = await cli("eval", "() => { state.fieldBanner = 0; state.lordCd = 0; state.lordCdTotal = lordCdMax(state.lord[0]); lordPop = true; return { lordPop, cd: state.lordCd, total: state.lordCdTotal }; }");
  if (!lordState.includes('"lordPop": true') || !lordState.includes('"cd": 0')) {
    throw new Error(`Unexpected player lord popup state: ${lordState}`);
  }
  await capture(lordOutput);
  const restState = await cli("eval", `() => {
    lordPop = false;
    state.fieldBanner = 0;
    state.level = 7;
    state.wave = 8;
    state.kills = 123;
    state.xp = 7;
    state.xpNeed = 20;
    state.waveTimer = 2.2;
    state.waveBudget = 10;
    state.waveClock = 4.2;
    state.enemies = [];
    state.spawnQueue = [];
    state.slots = Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null));
    state.obstacles = new Set();
    state.traits = {};
    state.nextWavePreview = { themeElems: ['badao'], mutation: null, boss: '张梁', affixes: { shield: 2 }, specials: { cata: 1 } };
    computeTeam();
    draw();
    return { level: state.level, wave: state.wave, empty: allUnits().length, next: state.wave + 1 };
  }`.replace(/\r?\n\s*/g, " "));
  if (!restState.includes('"level": 7') || !restState.includes('"wave": 8') || !restState.includes('"empty": 0') || !restState.includes('"next": 9')) {
    throw new Error(`Unexpected empty-rest state: ${restState}`);
  }
  await capture(join(outputDirectory, "v7.19.14-web-battle-empty-rest.png"));
  const fullState = await cli("eval", `() => {
    state.nextWavePreview = null;
    state.slots = Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null));
    const hero = GENERALS.find((general) => general.id === 'zhaoyun');
    for (let r = 0; r < GRID_ROWS; r++) for (let c = 0; c < GRID_COLS; c++) state.slots[r][c] = makeUnit(hero);
    computeTeam();
    draw();
    return { full: allUnits().length };
  }`.replace(/\r?\n\s*/g, " "));
  if (!fullState.includes('"full": 15')) throw new Error(`Unexpected full-grid state: ${fullState}`);
  await capture(join(outputDirectory, "v7.19.14-web-battle-full-grid.png"));
  const supportLinkState = await cli("eval", `() => {
    state.slots = Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null));
    state.slots[0][1] = makeUnit(GENERALS.find((general) => general.id === 'daqiao'));
    state.slots[0][3] = makeUnit(GENERALS.find((general) => general.id === 'xiaoqiao'));
    state.slots[2][1] = makeUnit(GRANARY_TYPE);
    state.slots[2][2] = makeUnit(GENERALS.find((general) => general.id === 'zhaoyun'));
    computeTeam();
    draw();
    return { units: allUnits().length, erqiao: state.bondSet.has('erqiao'), feed: granaryFeedTarget(2, 1)?.u?.type?.id || null };
  }`.replace(/\r?\n\s*/g, " "));
  if (!supportLinkState.includes('"units": 4') || !supportLinkState.includes('"erqiao": true') || !supportLinkState.includes('"feed": "zhaoyun"')) throw new Error(`Unexpected support-link state: ${supportLinkState}`);
  await capture(join(outputDirectory, "v7.19.14-web-battle-support-links.png"));
} finally {
  try { await cli("close"); } catch {}
  await closeServer();
}
