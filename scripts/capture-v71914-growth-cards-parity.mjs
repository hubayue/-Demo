import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { copyFile, mkdir, readFile } from "node:fs/promises";
import { dirname, extname, isAbsolute, join, normalize } from "node:path";

const root = process.cwd();
const outputDirectory = join(root, "output", "playwright");
const output = join(outputDirectory, "v7.19.14-web-growth-cards.png");
const danceOutput = join(outputDirectory, "v7.19.14-web-gewu-dance.png");
const session = `growth-cards-parity-${process.pid}`;
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
    meta.heroes = {};
    meta.week = 2948;
    newGame(makeWeekLevel(2948, 0));
    applyLevelField();
    applyRuler('liubei');
    state.phase = 'play';
    state.shenP = 0;
    foeLordTick(0);
    state.speed = 0;
    state.wave = 1;
    state.enemies = [];
    state.spawnQueue = [];
    state.slots = Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null));
    state.obstacles = new Set(['0,0', '0,4', '2,0', '2,4']);
    state.traits = {};
    for (let r = 0; r < GRID_ROWS; r++) for (let c = 0; c < GRID_COLS; c++) state.traits[r + ',' + c] = 'haste';
    state.slots[2][2] = makeUnit(GENERALS.find((general) => general.id === 'zhaoyun'));
    state.slots[1][2] = makeUnit(GENERALS.find((general) => general.id === 'zhangfei'));
    computeTeam();
    const titles = new Set(['张飞练兵', '关羽出征', '全军猛攻']);
    state.cards = buildCardPool().filter((card) => titles.has(card.title));
    state.cardAnim = 1;
    state.cardsAt = performance.now() - 1000;
    state.fieldBanner = 0;
    state.floaters = [];
    return { version: GAME_VERSION, titles: state.cards.map((card) => card.title) };
  }`.replace(/\r?\n\s*/g, " ");
  const stateResult = await cli("eval", setup);
  if (!stateResult.includes('"version": "7.19.14"') || !stateResult.includes('"张飞练兵"') || !stateResult.includes('"关羽出征"') || !stateResult.includes('"全军猛攻"')) {
    throw new Error(`Unexpected growth-card state: ${stateResult}`);
  }
  const screenshot = await cli("screenshot");
  const match = screenshot.match(/\(([^)\r\n]+\.png)\)/) || screenshot.match(/([^\r\n]+\.png)/);
  if (!match) throw new Error(`Unable to locate Playwright screenshot path: ${screenshot}`);
  const source = isAbsolute(match[1]) ? match[1] : join(root, match[1]);
  await copyFile(source, output);
  process.stdout.write(`Captured ${output}\n`);

  await cli("eval", "() => { state.cards = null; state.dance = 1.5; state.time = 5; state.fieldBanner = 0; state.floaters = []; return { dance: state.dance, time: state.time }; }");
  const danceScreenshot = await cli("screenshot");
  const danceMatch = danceScreenshot.match(/\(([^)\r\n]+\.png)\)/) || danceScreenshot.match(/([^\r\n]+\.png)/);
  if (!danceMatch) throw new Error(`Unable to locate dance screenshot path: ${danceScreenshot}`);
  const danceSource = isAbsolute(danceMatch[1]) ? danceMatch[1] : join(root, danceMatch[1]);
  await copyFile(danceSource, danceOutput);
  process.stdout.write(`Captured ${danceOutput}\n`);
} finally {
  try { await cli("close"); } catch {}
  await closeServer();
}
