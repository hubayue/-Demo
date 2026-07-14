import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, extname, join, normalize } from "node:path";

const root = process.cwd();
const output = join(root, "godot-demo", "tests", "fixtures", "v7.19.2-team-modifiers.json");
const session = `team-fixture-${process.pid}`;
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
    const type = {
      ".html": "text/html; charset=utf-8",
      ".js": "text/javascript; charset=utf-8",
      ".css": "text/css; charset=utf-8",
    }[extname(path)] || "application/octet-stream";
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
  process.stdout.write(`[team-fixture] playwright-cli ${args[0]}\n`);
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

const expression = `() => {
  const baseCity = (field, theme) => ({
    k:0,ch:1,lvIdx:3,n:3,hpMul:0.95,spdMul:0.93,hpGrow:1.164,affixAdd:-0.06,
    wall:15,obstacles:4,killTarget:450,goldMul:0.66,firstGold:210,field,
    bossName:null,bossKit:null,eliteWave:false,rules:[],foes:{tri:'badao'},theme,
    week:2948,name:'team-fixture',icon:'🧪'
  });
  const cases = [
    {id:'laojiang', field:'gunshi', theme:'tuanjie', heroes:['huangzhong','yanyan'], cells:[[0,0],[2,4]]},
    {id:'nanman_overlap', field:'gunshi', theme:'tuanjie', heroes:['menghuo','zhurong','wutugu'], cells:[[0,0],[0,1],[1,0]]},
    {id:'adjacent_spears', field:'gunshi', theme:null, heroes:['zhangfei','zhaoyun'], cells:[[1,1],[1,2]]},
    {id:'gaodi_archer', field:'gaodi', theme:null, heroes:['huangzhong'], cells:[[1,2]]},
  ];
  const out = [];
  for (const def of cases) {
    const city = baseCity(def.field, def.theme);
    newGame(city);
    applyRuler('caocao');
    state.obstacles = new Set();
    state.traits = {};
    state.field = FIELDS.find(x => x.id === def.field);
    state.phase = 'play';
    def.heroes.forEach((id, index) => {
      const [r,c] = def.cells[index];
      state.slots[r][c] = makeUnit(GENERALS.find(x => x.id === id));
    });
    computeTeam();
    out.push({
      ...def,
      city,
      counts:{...state.team.count},
      activeBonds:[...state.bondSet].sort(),
      units:allUnits().map(u => {
        const p = findUnitPos(u);
        const mods = getUnitMods(u,p[0],p[1]);
        return {
          id:u.type.id,
          bondFx:bondFx(u.type.id),
          dmgMul:mods.dmgMul,
          rateMul:mods.rateMul,
          crit:mods.crit,
          pierceAdd:mods.pierceAdd,
          damage:unitDamage(u,mods),
          rate:unitRate(u,mods),
        };
      }),
    });
  }
  return {source:'Web v7.19.2 browser runtime',version:GAME_VERSION,cases:out};
}`.replace(/\s+/g, " ");

try {
  await listen();
  const { port } = server.address();
  await cli("open", `http://127.0.0.1:${port}/reference/web-v7.19.2/index.html`);
  const stdout = await cli("eval", expression);
  const marker = "### Result\n";
  const start = stdout.indexOf(marker) + marker.length;
  const end = stdout.indexOf("\n### Ran Playwright code", start);
  if (start < marker.length || end < 0) throw new Error(`Unable to parse Playwright output:\n${stdout}`);
  const fixture = JSON.parse(stdout.slice(start, end));
  if (fixture.version !== "7.19.2" || fixture.cases.length !== 4) throw new Error("Unexpected Web fixture payload");
  await writeFile(output, `${JSON.stringify(fixture, null, 2)}\n`, "utf8");
  process.stdout.write(`Captured ${fixture.cases.length} Web v${fixture.version} team cases to ${output}\n`);
} finally {
  try { await cli("close"); } catch {}
  await close();
}
