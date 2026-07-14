import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, extname, join, normalize } from "node:path";

const root = process.cwd();
const output = join(root, "godot-demo", "tests", "fixtures", "v7.19.2-battle-seed-20260715.json");
const session = `battle-fixture-${process.pid}`;
const npx = "npx";
const npxCli = process.platform === "win32"
  ? join(dirname(process.execPath), "node_modules", "npm", "bin", "npx-cli.js")
  : null;

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
const close = () => new Promise((resolve) => server.close(resolve));
const cli = (...args) => new Promise((resolve, reject) => {
  process.stdout.write(`[fixture] playwright-cli ${args[0]}\n`);
  const argv = ["--yes", "--package", "@playwright/cli", "playwright-cli", `-s=${session}`, ...args];
  const capture = args[0] === "eval";
  const child = spawn(process.platform === "win32" ? process.execPath : npx, process.platform === "win32" ? [npxCli, ...argv] : argv, {
    cwd: root,
    windowsHide: true,
    stdio: capture ? ["ignore", "pipe", "pipe"] : "inherit",
  });
  let stdout = "";
  let stderr = "";
  if (capture) {
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => { stdout += chunk; });
    child.stderr.on("data", (chunk) => { stderr += chunk; });
  }
  const timeout = setTimeout(() => child.kill(), 30000);
  child.on("error", (error) => {
    clearTimeout(timeout);
    reject(error);
  });
  child.on("exit", (code) => {
    clearTimeout(timeout);
    if (code !== 0) reject(new Error(stderr || stdout || `playwright-cli exited ${code}`));
    else resolve(stdout);
  });
});

const expression = `() => { const mulberry=(seed)=>{let a=seed|0;return()=>{a=(a+0x6D2B79F5)|0;let t=Math.imul(a^(a>>>15),1|a);t=(t+Math.imul(t^(t>>>7),61|t))^t;return((t^(t>>>14))>>>0)/4294967296;};};const city={k:0,ch:1,lvIdx:3,n:3,hpMul:0.95,spdMul:0.93,hpGrow:1.164,affixAdd:-0.06,wall:15,obstacles:4,killTarget:450,goldMul:0.66,firstGold:210,field:'gunshi',bossName:null,bossKit:null,eliteWave:false,rules:[],foes:{tri:'badao'},theme:'tuanjie',week:2948,name:'交州·颍川烽火',icon:'🌴'};Math.random=mulberry(20260715);newGame(city);const obstacles=[...state.obstacles].sort();const traits={...state.traits};Math.random=mulberry(20260715);const q=buildWave(1);const wave=q.map(s=>({delay:s.delay,hp:s.hp,speed:s.speed,r:s.r,cls:s.cls,big:!!s.big,affix:s.affix||null,special:s.special||null,tri:s.tri,xp:s.xp,dmg:s.dmg}));return {source:'Web v7.19.2 browser runtime',version:GAME_VERSION,seed:20260715,city:{k:city.k,ch:city.ch,lvIdx:city.lvIdx,hpMul:city.hpMul,spdMul:city.spdMul,hpGrow:city.hpGrow,affixAdd:city.affixAdd,wall:city.wall,obstacles:city.obstacles,killTarget:city.killTarget,goldMul:city.goldMul,field:city.field,foes:city.foes},layout:{obstacles,traits},wave1:wave,waveMeta:{themeElems:q.themeElems,weakElem:q.weakElem,mutation:q.mutation||null}}; }`;

try {
  await listen();
  const { port } = server.address();
  await cli("open", `http://127.0.0.1:${port}/reference/web-v7.19.2/index.html`);
  const stdout = await cli("eval", expression);
  const start = stdout.indexOf("### Result\n") + "### Result\n".length;
  const end = stdout.indexOf("\n### Ran Playwright code", start);
  if (start < "### Result\n".length || end < 0) throw new Error(`Unable to parse Playwright output:\n${stdout}`);
  const fixture = JSON.parse(stdout.slice(start, end));
  await writeFile(output, `${JSON.stringify(fixture, null, 2)}\n`, "utf8");
  process.stdout.write(`Captured ${fixture.wave1.length} Web v${fixture.version} enemies to ${output}\n`);
} finally {
  try { await cli("close"); } catch {}
  await close();
}
