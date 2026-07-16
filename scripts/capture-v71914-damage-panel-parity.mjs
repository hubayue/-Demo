import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { copyFile, mkdir, readFile } from "node:fs/promises";
import { dirname, extname, isAbsolute, join, normalize } from "node:path";

const root = process.cwd();
const outputDirectory = join(root, "output", "playwright");
const session = `damage-panel-parity-${process.pid}`;
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
    for (const ruler of LORD_RULERS) meta.lords[ruler.id] = { lv: 1, xp: 0 };
    meta.week = 2948;
    newGame(makeWeekLevel(2948, 0));
    applyLevelField();
    applyRuler('liubei');
    state.phase = 'play';
    foeLordTick(0);
    state.cards = null;
    state.speed = 0;
    state.wave = 3;
    state.waveTimer = 2;
    state.time = 20;
    state.enemies = [];
    spawnEnemy({ x: 240, y: 20, hp: 100, speed: 0, r: 16, cls: 'spear', xp: 0, dmg: 1 });
    state.spawnQueue = [];
    state.nextQueue = null;
    state.nextWavePreview = null;
    state.slots = Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null));
    state.obstacles = new Set();
    state.traits = {};
    const zhaoyun = makeUnit(GENERALS.find((general) => general.id === 'zhaoyun'));
    const guanyu = makeUnit(GENERALS.find((general) => general.id === 'guanyu'));
    zhaoyun._inRange = 1;
    guanyu._inRange = 0;
    state.slots[2][2] = zhaoyun;
    state.slots[1][2] = guanyu;
    computeTeam();
    state.dmgBook = {
      zhaoyun: { icon: '', name: '赵云', total: 1200, log: [[20, 500]] },
      '@lord': { icon: '👑', name: '主公', total: 450, log: [[20, 100]] },
      '@fire': { icon: '🔥', name: '火燎', total: 180, log: [[19, 60]] },
    };
    state.dmgPanel = true;
    state.fieldBanner = 0;
    state.floaters = [];
    draw();
    return { version: GAME_VERSION, rows: Object.keys(state.dmgBook).length + 1, total: Object.values(state.dmgBook).reduce((sum, item) => sum + item.total, 0) };
  }`.replace(/\r?\n\s*/g, " ");
  const result = await cli("eval", setup);
  if (!result.includes('"version": "7.19.14"') || !result.includes('"rows": 4') || !result.includes('"total": 1830')) throw new Error(`Unexpected damage-panel fixture: ${result}`);
  await capture("v7.19.14-web-damage-panel.png");
} finally {
  try { await cli("close"); } catch {}
  await closeServer();
}
