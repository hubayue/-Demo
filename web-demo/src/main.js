"use strict";
/* ============================================================
   三国 · 黄巾之乱 —— 塔防肉鸽
   黄巾大军攻城！武将列阵自动迎敌，击杀攒经验，
   升级三选一强化；兵种克制 + 武将羁绊 + 前后排站位 + 计策。
   目标：击破 900 黄巾！
   ============================================================ */

const W = 480, H = 800;
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

/* ---------- 自适应缩放 ----------
   v5.9.4 手机排版加固：微信/iOS WebView 首帧 innerWidth/innerHeight 常没稳定（URL栏收放也不触发 resize），
   首屏就会按错误尺寸缩放——画布溢出屏幕、右侧按钮被切。三招：①尺寸取 innerXX/clientXX/visualViewport 三者最小
   ②多监听 orientationchange/visualViewport/pageshow ③加载后 300ms/1200ms 各补算一拍 */
let scale = 1;
function viewSize() {
  const de = document.documentElement;
  const vv = window.visualViewport;
  return {
    w: Math.min(window.innerWidth || 1e9, (de && de.clientWidth) || 1e9, (vv && vv.width) || 1e9),
    h: Math.min(window.innerHeight || 1e9, (de && de.clientHeight) || 1e9, (vv && vv.height) || 1e9),
  };
}
function resize() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const v = viewSize();
  if (!(v.w > 0) || !(v.h > 0)) return;
  scale = Math.min(v.w / W, v.h / H) * 0.98;
  canvas.style.width = W * scale + "px";
  canvas.style.height = H * scale + "px";
  canvas.width = W * dpr;
  canvas.height = H * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
}
window.addEventListener("resize", resize);
window.addEventListener("orientationchange", () => setTimeout(resize, 80));
window.addEventListener("pageshow", resize);
if (window.visualViewport) window.visualViewport.addEventListener("resize", resize);
setTimeout(resize, 300);
setTimeout(resize, 1200);
resize();

/* ---------- 常量 ---------- */
const KILL_TARGET = 1000;
const GRID_COLS = 5, GRID_ROWS = 3;
const CELL = 82;
const GRID_X = (W - GRID_COLS * CELL) / 2;
const GRID_Y = 492;                        // 三行阵地，城池垫在阵地下方（v7.0 上移22px：城墙加高，主公站上墙）
const DEFENSE_LINE = GRID_Y + GRID_ROWS * CELL + 8;   // 城池受击线（穿过阵地才碰到）
const GAME_VERSION = "7.18.8";   // 每次发布云端 +1（发布流程同时在 changelog.html 顶部追加条目）
/* 势力值三常量（放这么早是因为 rolloverWeek 在存档规整时就要算分——TDZ 坑，别往下挪） */
const WEEK_STAR_MUL = [0, 1, 1.25, 1.5];            // 威望：打得越漂亮城池贡献越高
const WEEK_ENDLESS_PER = 0.25;                      // 讨伐每多撑1波 +25%——墙压近后每一波都更值钱，高手分差的主引擎
const TAOFA_TOP_N = 10;                             // 十大功绩：功勋图只记你最辉煌的十役（K由叙事锁死）
const MAX_LEVEL = 15;   // v5.2 上限5→10（6~10星=升华×1.4/星）；v7.5.0 用户拍板10→15：11星起「二阶升华」蓝星×1.3/星——无尽后期练兵坑再挖深一层
const GRANARY_MAX = 5;  // 粮仓星上限仍是5（10星粮仓=经验聚变堆，与英雄星解耦）
/* 星显示压缩（用户定的规矩）：最多画5颗——升华星（第6星起）一颗顶两颗。总星s>5时画(s-5)颗升华星+(10-s)颗普通星。
   v5.4.5 用户拍板：升华星不用菱形✦，还是五角星、用烈焰橙红色区分（drawStarRow）；starText 的✦只剩测试在用 */
/* 星行三段（v7.5.0）：1~5金★ / 6~10一阶升华红★ / 11~15二阶升华蓝★——一行永远≤5颗，颜色报段位 */
function starParts(lv) {
  if (lv <= 5) return { t2: 0, hi: 0, lo: lv };
  if (lv <= 10) return { t2: 0, hi: lv - 5, lo: 10 - lv };
  return { t2: lv - 10, hi: 15 - lv, lo: 0 };
}
function starText(lv) { const p = starParts(lv); return "✪".repeat(p.t2) + "✦".repeat(p.hi) + "★".repeat(p.lo); }
/* 星行绘制（v5.4.5 用户拍板：升华星不用菱形，同样的五角星换颜色表示）：
   升华星=烈焰橙红★(固定色SUPER_STAR_COLOR，避开转生四色和新星绿)+同色辉光、大一号；
   blinkLast=最后一颗呼吸闪动（练兵卡：新星马上到手）。返回总宽，便于在后面接"N转"等文字 */
const SUPER_STAR_COLOR = "#ff7a3a";
const SUPER2_STAR_COLOR = "#3a9aff";   // 二阶升华=湛蓝★（避开转生青#5ae8ff/一阶红/金/新星绿）
function drawStarRow(cx, cy, lv, px, color, opts = {}) {
  const p = starParts(lv);
  const seq = [];   // 2=二阶蓝 1=一阶红 0=普通金
  for (let i = 0; i < p.t2; i++) seq.push(2);
  for (let i = 0; i < p.hi; i++) seq.push(1);
  for (let i = 0; i < p.lo; i++) seq.push(0);
  if (!seq.length) return 0;
  const fHi = `bold ${px + 2}px sans-serif`, fLo = `bold ${px}px sans-serif`;
  const pad = Math.max(1, Math.round(px * 0.1));
  let total = -pad;
  const ws = seq.map(hi => {
    ctx.font = hi ? fHi : fLo;
    const w = ctx.measureText("★").width;
    total += w + pad;
    return w;
  });
  const prevAlign = ctx.textAlign;
  ctx.textAlign = "left";
  let x = cx - total / 2;
  for (let i = 0; i < seq.length; i++) {
    const hi = seq[i], isLast = i === seq.length - 1;
    if (opts.blinkLast && isLast) ctx.globalAlpha = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(state.time * 6));
    const col = opts.newColor && isLast ? opts.newColor : hi === 2 ? SUPER2_STAR_COLOR : hi ? SUPER_STAR_COLOR : color;
    ctx.font = hi ? fHi : fLo;
    if (opts.outline) {
      ctx.strokeStyle = "rgba(0,0,0,.7)";
      ctx.lineWidth = 3;
      ctx.strokeText("★", x, cy);
    }
    if (hi) { ctx.shadowColor = col; ctx.shadowBlur = 6; }
    ctx.fillStyle = col;
    ctx.fillText("★", x, cy);
    ctx.shadowBlur = 0;
    x += ws[i] + pad;
    ctx.globalAlpha = 1;
  }
  ctx.textAlign = prevAlign;
  return total;
}
/* 星级伤害乘区：前5星×1.9/星，6星起（升华星）×1.4/星；凤凰翎遗宝把升华星放大到×1.5 */
function starDmgMul(lv) {
  const fh = typeof state !== "undefined" && state && state.relics && state.relics.some(r => r.id === "fenghuang");
  const sub = fh ? 1.5 : 1.4, sub2 = fh ? 1.4 : 1.3;   // 一阶升华×1.4/星、二阶×1.3/星（凤凰翎各+0.1）
  return Math.pow(1.9, Math.min(lv, 5) - 1) * Math.pow(sub, Math.max(0, Math.min(lv, 10) - 5)) * Math.pow(sub2, Math.max(0, lv - 10));
}
const REBIRTH_MUL = 1.4;   // 局内转生已退役（v5.2 转生外迁局外）：乘区代码保留兼容（u.rebirth 恒0）
const REBIRTH_COLOR = ["#ffe45a", "#ff7ad2", "#c96aff", "#5ae8ff"];   // 0转金/1转品红/2转紫/3转青——局外转生的星色
const CARD_AREA_Y = GRID_Y - 198;   // 三选一浮层：阵地上方，压在战场底部（换一批已退役）

/* 兵种：建筑学定位——
   枪兵=前线短程+战阵光环（强化相邻近战） 骑兵=中程+周期冲锋 弓兵=远程/全场火力
   射程按武将个体设定（rng，0=全场） */
const CLASSES = {
  spear:  { name: "枪兵", icon: "🔱", color: "#6fd44e", trait: "短程战阵 · 光环强化相邻友军" },
  cav:    { name: "骑兵", icon: "🐎", color: "#4ab0ff", trait: "平A即冲锋 · 左中右挑贼多的道冲 · 乱军越多越猛" },
  archer: { name: "弓兵", icon: "🏹", color: "#ff6b4a", trait: "远程火力 · 射程因人而异" },
  shield: { name: "盾兵", icon: "🛡️", color: "#e8c96a", trait: "挡刀反伤 · 拉仇恨：贼的远箭七成冲他 · 蓄势反击 · 边打边回血" },
  support:{ name: "辅兵", icon: "🎐", color: "#d97bff", trait: "无平A · 周期水波增益友军" },
  granary:{ name: "粮仓", icon: "🌾", color: "#e8c86a", trait: "不打人 · 产粮喂旁边武将升星" },
  egg:    { name: "龙蛋", icon: "🥚", color: "#c9a8ff", trait: "干孵着没别的用 · 三阶觉醒成应龙" },
  dragon: { name: "神兽", icon: "🐉", color: "#8ad2ff", trait: "龙息直取最强贼头 · 镇住不让它作法" },
};
/* 敌军造型仍沿用三大类（兵种克制已删，纯外观） */
const ENEMY_CLS = ["spear", "cav", "archer"];

/* 屯田粮仓（曹操专属）：不是武将——局内三选一抽的经济建筑，占一格产粮。
   v5.4 改口：产粮不再进经验条（那和招贤/杀敌没差别，最后都是抽牌），改成直接喂身边武将升星——
   经济建筑产的是"练兵"，放在谁旁边头一次有了讲究。
   有血会被拆（挡刀=有风险的投资）；升星产粮×1.6，全5星后还能开新仓。 */
const GRANARY_TYPE = { id: "granary", name: "粮仓", cls: "granary", elem: "rende",
  dmg: 0, rate: 9, speed: 0, hp: 260, char: "粮",
  desc: "不打人，产粮喂旁边武将升星；敌人能拆它" };
const GRANARY_G0 = 0.8, GRANARY_G1 = 0.12, GRANARY_STAR = 1.6;
const GRANARY_WAVE_CAP = 30;   // 产率的波数项到30波打止：粮仓是中前期经济，别在无尽里变成经验聚变堆（v4.0.1超模修复）
function granaryRate(u) {
  return (GRANARY_G0 + GRANARY_G1 * Math.min(state.wave, GRANARY_WAVE_CAP)) * Math.pow(GRANARY_STAR, u.level - 1)
    * (u.rbuffs?.farm > 0 ? 1.5 : 1)   // 鲁肃加攻波喂它：产粮+50%
    * (state.ruler === "caocao" ? 1 + 0.03 * lordLv("caocao") : 1);   // 屯田制（曹操专属）：产粮+3%/主公级
}
/* v5.4 屯田改口：粮仓的粮不再进经验条（那是抽牌轴，和招贤/杀敌没差别），
   改为直接喂身边武将升星（练兵轴）——粮仓放在谁旁边第一次有了讲究。
   一颗星的粮价挂当前 xpNeed（随局势自然涨，节奏形状和老粮仓一致），K 由 A/B sim 校准。 */
const GRANARY_FEED_SKIP = new Set(["granary", "egg", "dragon"]);
const GRANARY_STAR_K = 1.8;   // 一颗星 = K × 当前升级所需经验（v7.16 1.4→1.8：实测粮仓养将碾压其他练兵轴，减速22%）
function granaryStarNeed() { return state.xpNeed * GRANARY_STAR_K; }
function granaryFeedTarget(r, c) {
  // 喂身边八格里星最低、还没满星的武将（物件不喂）
  let best = null;
  for (let dr = -1; dr <= 1; dr++)
    for (let dc = -1; dc <= 1; dc++) {
      if (!dr && !dc) continue;
      const rr = r + dr, cc = c + dc;
      if (rr < 0 || rr >= GRID_ROWS || cc < 0 || cc >= GRID_COLS) continue;
      const uu = state.slots[rr][cc];
      if (!uu || GRANARY_FEED_SKIP.has(uu.type.cls) || uu.level >= MAX_LEVEL) continue;
      if (!best || uu.level < best.u.level) best = { u: uu, r: rr, c: cc };
    }
  return best;
}
function feedStar(u, r, c) {
  u.level++;
  u.bounce = 1;
  u.hpMax = unitMaxHp(u.type, u.level, u.rebirth || 0);
  u.hp = u.hpMax;   // 升星整备，满血归队
  if (u.level >= 5) unlockAch("star5");
  const p = slotCenter(r, c);
  burst(p.x, p.y, "#e8c86a", 22, 200);
  addFloater(p.x, p.y - 40, `🌾屯田练兵！${u.type.name} ${u.level}★`, "#e8c86a", 17);
  SFX.levelUp();
}

/* 应龙之卵：破顶用的风险投资——顶必须存在（敌血指数涨、龙只线性涨，墙永远在，只是往后挪几波）。
   无尽一律进池（头一次保底见一次）；平推局要打赢8仗的老手且第10波起。一次只孵一颗，孵出来才能再抽。
   v5.7 养龙提速（用户"费半天劲一次都没养起来过"）：10星+局外60级时代，老蛋线（5阶×5成把握≈10张卡）投入产出
   彻底倒挂——阶数5→3、基础把握5成→6成，期望投入≈5张卡；龙息底涨到(300+波×55)对齐新战力口径。
   第N条龙伤害×(1+0.25×(N-1))递增，给续养动力。顶仍有限（一局最多2条）。 */
const EGG_TYPE = { id: "dragonegg", name: "龙蛋", cls: "egg", elem: "badao",
  dmg: 0, rate: 9, speed: 0, hp: 300, char: "蛋",
  desc: "干孵着没别的用；孵成应龙比满星武将还猛" };
const DRAGON_TYPE = { id: "yinglong", name: "应龙", cls: "dragon", elem: "badao",
  dmg: 0, rate: 2.8, speed: 0, hp: 520, char: "龍",
  desc: "龙息直取最强贼头：重击+镇住不让它作法" };
const EGG_MAX = 3, DRAGON_RANK_MUL = 0.25;
function hatchChance(u) {
  let ch = 0.6 + (u.hatchBonus || 0);   // 软保底：失败+2成，成功清零
  const pos = findUnitPos(u);
  if (pos && cellTrait(pos[0], pos[1]) === "elem") ch += 0.10;   // 灵脉孕龙
  if (hasRelic("longxian")) ch += 0.20;
  if (u.rbuffs?.farm > 0) ch += 0.15;   // 鲁肃后勤波：蛋吃饱了这口温养更稳（v5.4.4 配套扩展）
  if (state.ruler === "liubiao") ch += 0.01 * lordLv("liubiao");   // 养龙术（刘表专属）：温养把握+1%/主公级
  return Math.min(0.9, ch);
}
/* 龙息伤害：base/slope 出自 /tmp/sanguo-dragon-sim.js 边际格子对比（v5.7 按10星时代上调），
   墙的真核是机制（贼首召援洪水/锤车撞墙），所以龙的主战力是"镇住"+集火最大威胁，伤害只是把账补齐 */
function dragonDmg(u) {
  /* v7.17.6 应龙掉队修复（📊面板实测32波占比1%、太史慈57%）：v5.0定标"比五星还猛"，练兵天花板
     已经到15星+转生，龙没跟着长——①乘队伍星级比 starDmgMul(全队最高星)/starDmgMul(5)（5星时代原价）；
     ②改吃 getUnitMods 全套乘区（此前连刘表自家的坐保江汉都不吃）。顶不破：星级/卡全封顶，龙对波次仍线性 */
  const pos = findUnitPos(u);
  const mods = pos ? getUnitMods(u, pos[0], pos[1]) : null;
  const team = allUnits().filter(x => !["dragon", "egg", "granary"].includes(x.type.cls));
  const topLv = team.length ? Math.max(...team.map(x => x.level)) : 5;
  return Math.round((300 + state.wave * 55)
    * (1 + DRAGON_RANK_MUL * ((u.dragonRank || 1) - 1))
    * Math.max(1, starDmgMul(topLv) / starDmgMul(5))
    * (mods ? mods.dmgMul : state.buffs.dmg * (state.armyBuff ? state.armyBuff.mul : 1) * (state.gewu ? 1.3 : 1)));
}

/* 格子特质：全部15格开局随机分配，障碍清除后显露 */
const TRAITS = {
  atk:   { icon: "⚔️", name: "沃土", desc: "伤害+15%" },
  haste: { icon: "⚡", name: "风口", desc: "出手快+12%" },
  guard: { icon: "🛡️", name: "坚岩", desc: "少挨打20%" },
  heal:  { icon: "💧", name: "灵泉", desc: "回血翻倍" },
  crit:  { icon: "🎯", name: "高台", desc: "多10%机会双倍暴击" },
  elem:  { icon: "🔮", name: "灵脉", desc: "站这打谁都算克制(怕!)" },
};

/* 攻击属性：武将各持一种，怪物有抗性——选将针对抗性是每局的核心决策 */
/* 三角克制（v6.0 用户拍板：五行+抗性表整体退役——"要记一堆怕什么不怕什么，信息爆炸干脆不看了"）：
   ✊霸道 砸 ✌️良谋 剪 ✋仁德 包 ✊……全游戏只剩这一张图，图标=猜拳手势，直觉零成本。
   克制×1.5(怕!) / 被克×0.6(不疼!) / 同系原价。 */
const ELEMENTS = {
  badao:    { name: "霸道", icon: "✊", color: "#ff6b4a" },
  liangmou: { name: "良谋", icon: "✌️", color: "#4aa8ff" },
  rende:    { name: "仁德", icon: "✋", color: "#7ad86a" },
};
const TRI_KE = { badao: "liangmou", liangmou: "rende", rende: "badao" };   // X 克 TRI_KE[X]（石头砸剪刀、剪刀剪布、布包石头）
const triCounterOf = tri => (tri === "liangmou" ? "badao" : tri === "rende" ? "liangmou" : tri === "badao" ? "rende" : null);   // 谁克 tri

/* 武将（cost=稀有度参考，全员开放，等级用金币升）
   elem=攻击属性 rng=射程(0=全场) bounce=箭矢弹射次数；骑兵平A=纵贯冲锋 */
const GENERALS = [
  { id: "zhangfei",   name: "张飞",   char: "飞", cls: "spear", elem: "badao", rng: 240,
    dmg: 21, rate: 1.10, speed: 300, splash: 58, desc: "一打一片" },
  { id: "zhaoyun",    name: "赵云",   char: "赵", cls: "spear", elem: "rende", rng: 270,
    dmg: 16, rate: 0.90, speed: 340, pierce: 2,  desc: "一枪穿俩" },
  { id: "machao",     name: "马超",   char: "马", cls: "spear", elem: "badao", rng: 250,
    dmg: 12, rate: 0.40, speed: 430,             desc: "出手飞快" },
  { id: "huangzhong", name: "黄忠",   char: "黄", cls: "archer", elem: "rende", rng: 0,
    dmg: 24, rate: 1.50, speed: 520,             desc: "全场都能射" },
  { id: "xiahouyuan", name: "夏侯渊", char: "夏", cls: "archer", elem: "badao", rng: 420,
    dmg: 4,  rate: 0.20, speed: 500, bounce: 2,  desc: "箭会弹着打" },
  { id: "luxun",      name: "陆逊",   char: "陆", cls: "archer", elem: "liangmou", rng: 400,
    dmg: 16, rate: 1.00, speed: 360, burn: true, firebrand: true, desc: "点火·着火的多挨他打" },
  { id: "guanyu",     name: "关羽",   char: "关", cls: "cav", elem: "rende", rng: 360,
    dmg: 46, rate: 5.5, speed: 380,
    desc: "冲锋伤害高" },
  { id: "lvbu",       name: "吕布",   char: "吕", cls: "cav", elem: "badao", rng: 340,
    dmg: 85, rate: 8.0, speed: 340, splash: 40,
    desc: "冲得宽又疼" },
  { id: "zhangliao",  name: "张辽",   char: "辽", cls: "cav", elem: "liangmou", rng: 380,
    dmg: 34, rate: 5.0, speed: 400,
    desc: "冲得勤快" },
  { id: "taishici",   name: "太史慈", char: "太", cls: "archer", elem: "rende", rng: 450,
    dmg: 11, rate: 0.75, speed: 420, spread: 2, bounce: 1, desc: "两箭齐发" },
  { id: "dianwei",    name: "典韦",   char: "典", cls: "spear", elem: "badao", rng: 230,
    dmg: 22, rate: 1.50, speed: 300, splash: 65, desc: "一锤一大片·战死爆经验" },
  { id: "sunce",      name: "孙策",   char: "策", cls: "cav", elem: "badao", rng: 360,
    dmg: 40, rate: 6.0, speed: 400,
    desc: "冲得快又猛" },
  { id: "xuchu",      name: "许褚",   char: "许", cls: "spear", elem: "badao", rng: 240, cost: 300,
    dmg: 18, rate: 1.20, speed: 320, splash: 55, desc: "抡锤砸一片" },
  { id: "weiyan",     name: "魏延",   char: "魏", cls: "spear", elem: "liangmou", rng: 260, cost: 400,
    dmg: 16, rate: 1.00, speed: 360, pierce: 1,  desc: "毒枪捅穿" },
  { id: "ganning",    name: "甘宁",   char: "甘", cls: "cav", elem: "badao", rng: 380, cost: 500,
    dmg: 30, rate: 5.0, speed: 430,
    desc: "冲得最快" },
  { id: "diaochan",   name: "貂蝉",   char: "蝉", cls: "archer", elem: "liangmou", rng: 380, cost: 600,
    dmg: 9,  rate: 0.85, speed: 380, slowShot: true, desc: "射中变慢" },
  { id: "zhouyu",     name: "周瑜",   char: "瑜", cls: "archer", elem: "liangmou", rng: 440, cost: 800,
    dmg: 18, rate: 0.90, speed: 380, burn: true, desc: "火烧得更疼" },
  { id: "jiangwei",   name: "姜维",   char: "姜", cls: "cav", elem: "liangmou", rng: 370, cost: 1000,
    dmg: 45, rate: 6.5, speed: 400, burn: true,
    desc: "边冲边点火" },
  { id: "zhugeliang", name: "诸葛亮", char: "亮", cls: "archer", elem: "liangmou", rng: 0, cost: 1200,
    dmg: 22, rate: 1.10, speed: 400, slowShot: true, desc: "全场射，中箭变慢" },   // 2026-07-06 毒→物理：八阵是谋略不是下毒，毒系被抗41/64关把金卡按在板凳上
  { id: "caoren",     name: "曹仁",   char: "仁", cls: "shield", elem: "rende", rng: 150,
    dmg: 0,  rate: 99,  speed: 0,                  desc: "挡刀还反伤" },
  { id: "zhoutai",    name: "周泰",   char: "泰", cls: "shield", elem: "rende", rng: 150,
    dmg: 0,  rate: 99,  speed: 0,                  desc: "扛揍还反伤·免死一次" },
  { id: "huatuo",     name: "华佗",   char: "佗", cls: "support", elem: "rende", rng: 0,
    dmg: 0,  rate: 6.0, speed: 0, ripple: "heal",  desc: "一圈奶12%还持续回" },
  { id: "xiaoqiao",   name: "小乔",   char: "乔", cls: "support", elem: "rende", rng: 0,
    dmg: 0,  rate: 7.0, speed: 0, ripple: "haste", desc: "一圈提速+22%" },
  { id: "lusu",       name: "鲁肃",   char: "肃", cls: "support", elem: "rende", rng: 0,
    dmg: 0,  rate: 7.5, speed: 0, ripple: "dmg",   desc: "一圈加攻+25%；粮仓龙蛋吃了更起劲" },
  { id: "huanggai",   name: "黄盖",   char: "盖", cls: "shield", elem: "badao", rng: 150,
    dmg: 0,  rate: 99,  speed: 0,                  desc: "挡刀反伤·会苦肉计" },
  { id: "xuhuang",    name: "徐晃",   char: "晃", cls: "shield", elem: "liangmou", rng: 150, cost: 400,
    dmg: 0,  rate: 99,  speed: 0,                  desc: "挡刀反伤·钉拒马挡路" },
  { id: "daqiao",     name: "大乔",   char: "大", cls: "support", elem: "rende", rng: 0,
    dmg: 0,  rate: 6.5, speed: 0, ripple: "slow",  desc: "一圈冻慢敌人" },
  { id: "huangyueying", name: "黄月英", char: "月", cls: "support", elem: "liangmou", rng: 0, cost: 800,
    dmg: 0,  rate: 7.0, speed: 0, ripple: "crit",  desc: "一圈多15%机会双倍暴击" },
  /* —— 2026-07-05 扩池六将：协同效应是技能设计的关键 —— */
  { id: "caiwenji",   name: "蔡文姬", char: "姬", cls: "support", elem: "rende", rng: 0,
    dmg: 0,  rate: 6.5, speed: 0, ripple: "soothe", desc: "一圈解封还回血" },
  { id: "gaoshun",    name: "高顺",   char: "顺", cls: "spear", elem: "liangmou", rng: 250, cost: 300,
    dmg: 14, rate: 1.00, speed: 340, pierce: 1,  desc: "扎得又稳又穿" },
  { id: "zhanghe",    name: "张郃",   char: "郃", cls: "cav", elem: "liangmou", rng: 380, cost: 400,
    dmg: 30, rate: 6.0, speed: 400,
    desc: "不限左中右，全场哪列人多冲哪列" },
  { id: "zhurong",    name: "祝融夫人", char: "祝", cls: "archer", elem: "badao", rng: 400, cost: 500,
    dmg: 20, rate: 1.6, speed: 380, boomerang: true, desc: "飞刀打出去还会飞回来" },
  { id: "wutugu",     name: "兀突骨", char: "兀", cls: "shield", elem: "badao", rng: 150, cost: 600, hp: 420,
    dmg: 0,  rate: 99,  speed: 0,                  desc: "挡刀反伤·身边一圈冒毒" },
  { id: "simayi",     name: "司马懿", char: "懿", cls: "support", elem: "liangmou", rng: 0, cost: 800,
    dmg: 0,  rate: 7.0, speed: 0, ripple: "cdr",  desc: "一圈大招转更快" },
  /* —— 克制矩阵轮扩池（2026-07-07）：六将机制各管一路克制 —— */
  { id: "pangde",     name: "庞德",   char: "德", cls: "spear", elem: "rende", rng: 250, cost: 500,
    dmg: 16, rate: 1.05, speed: 340, pierce: 1,  desc: "血越少扎得越狠" },
  { id: "yanliang",   name: "颜良",   char: "颜", cls: "cav", elem: "badao", rng: 380, cost: 600,
    dmg: 34, rate: 5.5, speed: 420,               desc: "专斩贼里的头目" },
  { id: "sunshangxiang", name: "孙尚香", char: "香", cls: "archer", elem: "badao", rng: 400, cost: 400,
    dmg: 13, rate: 1.5, speed: 480,               desc: "箭带火还推人" },
  { id: "yanyan",     name: "严颜",   char: "严", cls: "shield", elem: "rende", rng: 150, cost: 400, hp: 360,
    dmg: 0,  rate: 99,  speed: 0,                 desc: "挡刀反伤·打他的会被冻慢" },
  { id: "caohong",    name: "曹洪",   char: "洪", cls: "shield", elem: "rende", rng: 150, cost: 300, hp: 330,
    dmg: 0,  rate: 99,  speed: 0,                 desc: "替旁边兄弟挨四分之一的刀" },
  { id: "xushu",      name: "徐庶",   char: "庶", cls: "support", elem: "liangmou", rng: 0, cost: 600,
    dmg: 0,  rate: 6.5, speed: 0, ripple: "sunder", desc: "一圈卸劲：被克的减免失效" },
  /* —— v7.6.0 扩池五将：每人占一个体系钩子（百搭亲兵/恒克制/障碍地形/复活链/单挑锁定） —— */
  { id: "jiaxu",      name: "贾诩",   char: "诩", cls: "archer", elem: "liangmou", rng: 400, cost: 700,
    dmg: 17, rate: 1.1, speed: 380,               desc: "毒士百搭：谁当主公都算亲兵" },
  { id: "zuoci",      name: "左慈",   char: "慈", cls: "archer", elem: "rende", rng: 380, cost: 500,
    dmg: 10, rate: 1.2, speed: 360,               desc: "幻变符箭：打谁都算克制" },
  { id: "dengai",     name: "邓艾",   char: "艾", cls: "spear", elem: "liangmou", rng: 260, cost: 800,
    dmg: 15, rate: 1.0, speed: 340, pierce: 1,    desc: "唯一能站石头上·居高临下更疼" },
  { id: "menghuo",    name: "孟获",   char: "获", cls: "shield", elem: "badao", rng: 150, cost: 600, hp: 380,
    dmg: 0,  rate: 99,  speed: 0,                 desc: "挡刀反伤·被打死原地站起来（最多6次）" },
  { id: "wenchou",    name: "文丑",   char: "丑", cls: "cav", elem: "badao", rng: 380, cost: 400,
    dmg: 28, rate: 5.8, speed: 410,               desc: "点名最肥的贼单挑：它只打我，我打它更疼" },
];

/* 绝技：自动释放 = 内部CD转好 + 触发条件满足。
   分五类，与属性/射程/建筑学联动；cond 返回 true 才放（避免空放） */
const ULT_TYPES = {
  dmg:  { name: "伤害", color: "#ff8a5a" },
  ctrl: { name: "控制", color: "#8ad2ff" },
  def:  { name: "守御", color: "#9adf5a" },
  exec: { name: "斩杀", color: "#ffd24a" },
  util: { name: "军略", color: "#c9a8ff" },
};
/* 条件辅助 */
function aliveEnemies() { return state.enemies.filter(e => !e.dead); }
function enemiesNearWall(d = 130) { return aliveEnemies().filter(e => e.y > GRID_Y - d); }
function eliteOrBoss() { return aliveEnemies().filter(e => e.boss || e.affix); }
const ULTS = {
  /* 每个大招=一种独门几何机制，一眼看得出谁放的 */
  zhangfei:   { name: "燕人怒喝", type: "ctrl", cd: 13,
    desc: "吼一嗓子推飞一圈",           // 推开：冲击环把周围敌人齐齐顶回去
    condDesc: "跟前敌人≥3", cond: u => u._inRange >= 3 },
  zhaoyun:    { name: "七探盘蛇", type: "dmg", cd: 10,
    desc: "扇形连刺14枪",              // 散射：正面扇形弹幕
    condDesc: "跟前有敌人", cond: u => u._inRange >= 1 },
  machao:     { name: "雷光分驰", type: "dmg", cd: 12,
    desc: "一道雷劈中再分两叉",         // 分叉射线：主雷+两条支叉
    condDesc: "跟前敌人≥2", cond: u => u._inRange >= 2 },
  huangzhong: { name: "百步穿杨", type: "exec", cd: 9,
    desc: "狙掉场上最肉的",             // 狙击：锁最强单体一箭大伤害
    condDesc: "场上有大怪", cond: () => eliteOrBoss().length >= 1 },
  xiahouyuan: { name: "连珠掠阵", type: "dmg", cd: 11,
    desc: "大箭弹墙来回扫",             // 弹射（弹墙）：Z字折线穿全场
    condDesc: "敌人≥5", cond: () => aliveEnemies().length >= 5 },
  luxun:      { name: "火烧连营", type: "dmg", cd: 15,
    desc: "丢3个火罐烧3片地",           // 投掷+火堆：抛物线落地生火圈
    condDesc: "敌人≥8", cond: () => aliveEnemies().length >= 8 },
  guanyu:     { name: "青龙偃月斩", type: "dmg", cd: 12,
    desc: "一道刀光劈穿一列",           // 射线（竖）：本列从头劈到尾
    condDesc: "这列敌人≥2", cond: u => u._inColumn >= 2 },
  lvbu:       { name: "无双戟舞", type: "dmg", cd: 18,
    desc: "画戟弹着连打9个",            // 弹射（弹怪）：戟在敌群里连环跳
    condDesc: "敌人≥6", cond: () => aliveEnemies().length >= 6 },
  zhangliao:  { name: "威震逍遥津", type: "ctrl", cd: 14,
    desc: "吓跑全场2秒",               // 控制（恐惧）：全场掉头跑
    condDesc: "敌人冲进阵", cond: () => enemiesNearWall().length >= 1 },
  taishici:   { name: "箭雨遮天", type: "dmg", cd: 11,
    desc: "人最挤处落一片箭",           // 范围AOE：圆圈里箭如雨下
    condDesc: "敌人扎堆≥5", cond: () => { const c = densestCluster(130); return c && c.n >= 5; } },
  dianwei:    { name: "双戟破阵", type: "dmg", cd: 14,
    desc: "一锤下去炸一大片",           // 溅射：主目标重击+大圈溅射
    condDesc: "跟前敌人≥3", cond: u => u._inRange >= 3 },
  sunce:      { name: "霸王冲阵", type: "dmg", cd: 10,
    desc: "巨马冲一列全撞飞",           // 推开：超级冲锋，撞谁谁倒飞
    condDesc: "这列敌人≥3", cond: u => u._inColumn >= 3 },
  xuchu:      { name: "虎痴拒马", type: "def", cd: 18,
    desc: "放拒马挡路4秒",             // 拒马：横一排路障谁也过不来
    condDesc: "冲进阵敌人≥3", cond: () => enemiesNearWall(150).length >= 3 },
  weiyan:     { name: "子午伏兵", type: "dmg", cd: 12,
    desc: "埋3个毒陷阱踩了炸",          // 陷阱：埋在敌人前路，踩中爆毒
    condDesc: "敌人≥3", cond: () => aliveEnemies().length >= 3 },
  ganning:    { name: "锦帆乱掷", type: "dmg", cd: 14,
    desc: "乱丢5颗炸弹",               // 随机+投掷：炸弹雨落点随缘
    condDesc: "敌人≥5", cond: () => aliveEnemies().length >= 5 },
  diaochan:   { name: "闭月迷心", type: "ctrl", cd: 15,
    desc: "封贼技5秒·迷敌多挨打",     // 沉默：巫医不奶/旗手不吹/弓贼不射；普通兵被迷心多挨打30%
    condDesc: "有贼首特种，或敌人≥5",
    cond: () => aliveEnemies().some(e => e.special || e.boss) || aliveEnemies().length >= 5 },
  zhouyu:     { name: "业火横江", type: "dmg", cd: 13,
    desc: "一条火线横扫点燃",           // 射线（横）：拦腰一道火线
    condDesc: "敌人≥6", cond: () => aliveEnemies().length >= 6 },
  jiangwei:   { name: "麒麟火矢", type: "dmg", cd: 16,
    desc: "放8支追人火箭",             // 追踪弹：拐弯咬人还点火
    condDesc: "敌人≥4", cond: () => aliveEnemies().length >= 4 },
  zhugeliang: { name: "八阵锁敌", type: "util", cd: 18,
    desc: "锁5只怪打一个全掉血",        // 死亡链接：锁链共享掉血
    condDesc: "敌人≥5", cond: () => aliveEnemies().length >= 5 },
  caoren:     { name: "铁壁震荡", type: "ctrl", cd: 16,
    desc: "地震一圈晕1秒",             // 范围AOE+晕：扩散冲击环
    condDesc: "跟前有敌人", cond: u => u._inRange >= 1 },
  zhoutai:    { name: "冰棘迸发", type: "def", cd: 14,
    desc: "自奶45%冰刺炸一圈",          // 守御+径向散射：回血反伤翻倍+八方冰刺
    condDesc: "自己血少于60%", cond: u => u.hp < u.hpMax * 0.6 },
  huatuo:     { name: "青囊济世", type: "util", cd: 15,
    desc: "绿线全军奶35%还持续回",     // 治疗连线：绿线一人一根 + 药香持续回血
    condDesc: "有人血少于70%", cond: () => allUnits().some(u2 => u2.hp < u2.hpMax * 0.7) },
  xiaoqiao:   { name: "东风助阵", type: "util", cd: 20,
    desc: "刮大风全军提速40%",          // 大风圈：粉色大波纹罩全场
    condDesc: "敌人≥6", cond: () => aliveEnemies().length >= 6 },
  lusu:       { name: "天降粮草", type: "util", cd: 18,
    desc: "天上掉粮白拿经验加攻",       // 空投：粮包抛物线砸下来
    condDesc: "敌人≥8", cond: () => aliveEnemies().length >= 8 },
  huanggai:   { name: "苦肉诈降", type: "dmg", cd: 16,
    desc: "扣自己血烧全场还攒经验",     // 自残换爆发：苦肉计，独门机制
    condDesc: "敌人≥5、自己血还多", cond: u => u.hp > u.hpMax * 0.35 && aliveEnemies().length >= 5 },
  xuhuang:    { name: "钉阵拒马", type: "def", cd: 17,
    desc: "钉两排拒马挡5秒",           // 拒马（第2人）：两排短栅错开，正面挡死
    condDesc: "冲进阵敌人≥2", cond: () => enemiesNearWall(160).length >= 2 },
  daqiao:     { name: "寒江凝波", type: "util", cd: 18,
    desc: "全场冻慢还给全军回血",       // 全场冰环：敌我一环两用，独门机制
    condDesc: "敌人≥5", cond: () => aliveEnemies().length >= 5 },
  huangyueying: { name: "连弩机关", type: "dmg", cd: 18,
    desc: "架一座连弩塔扫射8秒",        // 炮台：临时连弩塔，独门机制
    condDesc: "敌人≥4", cond: () => aliveEnemies().length >= 4 },
  caiwenji:   { name: "胡笳十八拍", type: "ctrl", cd: 18,
    desc: "一曲唱睡全场3秒·挨打会醒",   // 催眠：独门机制，配合AOE收割是协同核心
    condDesc: "敌人≥6", cond: () => aliveEnemies().length >= 6 },
  gaoshun:    { name: "陷阵无前", type: "dmg", cd: 14,
    desc: "把左右敌人拽成一堆重击",     // 聚怪：拉到一起，喂给全场AOE
    condDesc: "这列敌人≥3", cond: u => u._inColumn >= 3 },
  zhanghe:    { name: "雷骑掠阵", type: "dmg", cd: 16,
    desc: "三列同时小冲锋",             // 多列冲锋：平A只冲一列，大招铺三列
    condDesc: "敌人≥8", cond: () => aliveEnemies().length >= 8 },
  zhurong:    { name: "火神降世", type: "dmg", cd: 15,
    desc: "扇形丢5把飞刀全点着",        // 散射+点燃：给陆逊烙印/火系淬炼递火种
    condDesc: "敌人≥6", cond: () => aliveEnemies().length >= 6 },
  wutugu:     { name: "藤甲毒瘴", type: "dmg", cd: 18,
    desc: "毒雾变大变毒8秒",            // 光环爆发：唯一持续输出的盾兵
    condDesc: "跟前敌人≥2", cond: u => u._inRange >= 2 },
  pangde:     { name: "抬棺冲杀", type: "dmg", cd: 14,
    desc: "顺着本列突刺一趟，个个挨扎",
    condDesc: "这列敌人≥2", cond: u => u._inColumn >= 2 },
  yanliang:   { name: "斩将夺旗", type: "exec", cd: 15,
    desc: "直取最强的特种/精锐，残了直接枭首",
    condDesc: "场上有特种或精锐", cond: () => aliveEnemies().some(e => (e.special || e.affix) && !e.boss) },
  sunshangxiang: { name: "翻身背射", type: "dmg", cd: 13,
    desc: "扇面十支火箭，点着还推人",
    condDesc: "敌人≥5", cond: () => aliveEnemies().length >= 5 },
  yanyan:     { name: "断头怒喝", type: "ctrl", cd: 16,
    desc: "吼冻身边一圈敌人，自己回血",
    condDesc: "阵前敌人≥3", cond: () => aliveEnemies().filter(e => e.y > GRID_Y - 220).length >= 3 },
  caohong:    { name: "毁家纾难", type: "def", cd: 16,
    desc: "自己回血，还替兄弟挨更多的刀（3秒六成）",
    condDesc: "有人残血", cond: () => allUnits().some(x => x.hp < x.hpMax * 0.6) },
  xushu:      { name: "破敌机先", type: "util", cd: 17,
    desc: "5秒内全场贼的属性减免失效（被克照样打全额）",
    condDesc: "敌≥6", cond: () => aliveEnemies().length >= 6 },
  simayi:     { name: "天命在我", type: "util", cd: 16,
    desc: "全军大招快转8秒还送经验",    // CD回收：全队大招轴心，武将越多越赚
    condDesc: "武将≥5", cond: () => allUnits().length >= 5 },
  /* —— v7.6.0 五将 —— */
  jiaxu:      { name: "乱武", type: "ctrl", cd: 16,
    desc: "血最厚的4个贼倒戈互殴3秒",   // 复活离间遗产：turncoatT行为链
    condDesc: "普通贼≥6", cond: () => aliveEnemies().filter(e => !e.special && !e.boss).length >= 6 },
  zuoci:      { name: "群羊变", type: "ctrl", cd: 15,
    desc: "最肥的3个贼变羊5秒：不能动还多挨三成打",
    condDesc: "普通贼≥3", cond: () => aliveEnemies().filter(e => !e.special && !e.boss).length >= 3 },
  dengai:     { name: "凿山", type: "dmg", cd: 14,
    desc: "同排贼全挨一记重锤，站石头上砸得更狠（石头不碎，接着占高地）",
    condDesc: "敌人≥5", cond: () => aliveEnemies().length >= 5 },
  menghuo:    { name: "南蛮战吼", type: "ctrl", cd: 15,
    desc: "吼跑全场普通贼1.5秒，自己回三成血",
    condDesc: "敌人≥6", cond: () => aliveEnemies().length >= 6 },
  wenchou:    { name: "阵前枭首", type: "exec", cd: 13,
    desc: "对单挑目标一刀八倍处决",
    condDesc: "有单挑目标", cond: () => state.enemies.some(e => !e.dead && e.duelT > 0) },
};
/* 找敌群圆心（taishici 用） */
function densestCluster(rad) {
  let best = null;
  for (const e of aliveEnemies()) {
    let n = 0;
    for (const e2 of aliveEnemies())
      if (dist2(e.x, e.y, e2.x, e2.y) < rad * rad) n++;
    if (!best || n > best.n) best = { x: e.x, y: e.y, n };
  }
  return best;
}

/* 局外成长：金币（打仗赚、升英雄花）+ 英雄图鉴等级 + 5主将格（localStorage 持久化）
   存档管理：3个独立档位（各自金币/英雄/兵法/成就），sanguo_slot 记住正在用哪个 */
const META_KEY = "sanguo_meta_v6";   // v6：v4.8.3 公平开局清档起用（老缓存不再读取；账号密码不受影响）
const CACHE_KEY = `${META_KEY}_cache`;   // 本地只做断网缓存，正档在服务器（账号制）
/* —— v4.0 赛季化：抽卡/卡组退役，全部武将对所有人开放；每局开打前从全图鉴随机25人主池，
     5个主将格必进主池；金币的去处=升英雄等级（跨赛季保留）+ 兵法。
     经济模型：/tmp/sanguo-season-model.js（升级曲线/换将定价/广告单价都从模型来） —— */
const HERO_LV_MAX = 30;                 // 英雄等级上限（金币升级，官职碎片制已退役）
const HERO_LV_BONUS = 0.08;             // 每级 攻+8% 血+8%（满级+232%，升级驱动轮：一级一个脚印，整条16州梯子=从裸号到毕业的成长跨度）
/* v5.2 双段价：前30级 1.33→1.22 大幅提速（累计≈14.6万，老曲线的1/8——升级爽点更密）；
   31~60级 1.13 缓涨拉长总坑（3转60级单将累计≈千万级，是长线荣誉不是必需品）。
   v5.2.2 品质分价：卡越金越贵（白×0.8/绿×1/蓝×1.3/金×1.7）——强卡投入大，冷门卡便宜好养 */
const heroUpCost = (lv, id) => {
  const base = lv <= 30 ? 100 * Math.pow(1.22, lv - 1) : 100 * Math.pow(1.22, 29) * Math.pow(1.13, lv - 30);
  const mul = id ? (RARITY[heroRarity(id)].costMul || 1) : 1;
  return Math.round(base * mul / 10) * 10;
};
/* 品质四档（按强度模型分划档，颜色必须不骗人：同兵种里金>蓝>绿>白）
   注意：品质和"初始免费"是两回事——关羽是初始将但也是金卡，他的重复卡走金卡概率档
   2026-07-06 名望对齐：知名武将机制加强升档（关羽/赵云进金，张飞/马超/张辽/陆逊进蓝），
   黄盖/黄月英/兀突骨按真实强度回落到蓝 */
const HERO_TIER = {
  lvbu: "epic", jiangwei: "epic", zhugeliang: "epic", zhouyu: "epic",
  simayi: "epic", guanyu: "epic", zhaoyun: "epic",
  huanggai: "rare", huangyueying: "rare", wutugu: "rare", sunce: "rare", weiyan: "rare",
  ganning: "rare", huangzhong: "rare", taishici: "rare", dianwei: "rare",
  zhangfei: "rare", machao: "rare", zhangliao: "rare", luxun: "rare",
  zhurong: "uncommon", zhanghe: "uncommon", caoren: "uncommon",
  xiahouyuan: "uncommon", xuhuang: "uncommon", xuchu: "uncommon",
  gaoshun: "uncommon", zhoutai: "uncommon",
  pangde: "rare", yanliang: "rare", xushu: "rare",
  sunshangxiang: "uncommon", yanyan: "uncommon", caohong: "uncommon",
  jiaxu: "rare", dengai: "rare", menghuo: "rare", zuoci: "uncommon", wenchou: "uncommon",
  // 其余（貂蝉/鲁肃/小乔/蔡文姬/大乔/华佗）= 白卡
};
function heroRarity(id) {
  return HERO_TIER[id] || "common";
}
const RARITY = {
  common:   { name: "白卡", color: "#cfd6dc", w: 40, costMul: 0.8 },
  uncommon: { name: "绿卡", color: "#7ad86a", w: 30, costMul: 1.0 },
  rare:     { name: "蓝卡", color: "#4aa8ff", w: 20, costMul: 1.3 },
  epic:     { name: "金卡", color: "#ffd24a", w: 10, costMul: 1.7 },
};
/* 英雄等级（官职退役）：局外等级叫"升级"，和局内星级（练兵）区分开 */
function heroLv(id) { return (meta.heroes && meta.heroes[id]) ? meta.heroes[id].lv : 1; }
function heroLvMul(id) {
  // 神将周：基础×1.25 且 每级加成翻倍（8%→16%）——攻血同吃，等级越高神将放大越狠
  if (typeof isShen === "function" && isShen(id)) return SHEN_BASE * (1 + (heroLv(id) - 1) * SHEN_LV_BONUS);
  return 1 + (heroLv(id) - 1) * HERO_LV_BONUS;
}
/* 等级里程碑（机制成长，不是纯数值）：4级=登场自带1星，7级=大招转快15%，10级=再带1星+金名
   10级往后到30级是纯数值长线（金币深坑，跨赛季保留） */
const MILE_STAR1 = 4, MILE_ULT = 7, MILE_STAR2 = 10, MILE_FASTULT = 15, MILE_CRIT = 20, MILE_ULT2 = 25;
/* 等级里程碑链（2026-07-08 留存方向2）：升级不只加数值，到档解锁看得见的真本事——
   给"没风景的直路"铺上路牌；15/20/25/30 是新增的中后段钩子（便利/小数值/荣誉，不破平衡） */
const MILES = [
  { lv: 4,  txt: "登场自带1星" },
  { lv: 7,  txt: "大招转快15%" },
  { lv: 10, txt: "再自带1星·金色名" },
  { lv: 15, txt: "开局大招就转好大半" },
  { lv: 20, txt: "登场自带4星·头像镶银边" },
  { lv: 25, txt: "开局大招直接就绪" },
  { lv: 30, txt: "满级·登场自带5星·完全体金边" },
];
/* 战力分：来自强度模型（/tmp/sanguo-model.js 34将FAME段，2026-07-06名望对齐），改武将强度时同步这张表
   纯辅助（司马懿等）在模型分上叠"隐藏属性防废卡"溢价 */
const BASE_SCORE = {
  zhangfei: 62, zhaoyun: 85, machao: 78, huangzhong: 60, xiahouyuan: 45, luxun: 58,
  guanyu: 90, lvbu: 164, zhangliao: 64, taishici: 58, dianwei: 58, sunce: 75,
  xuchu: 45, weiyan: 69, ganning: 63, diaochan: 32, zhouyu: 72, jiangwei: 119,
  zhugeliang: 86, caoren: 49, zhoutai: 44, huatuo: 25, xiaoqiao: 34, lusu: 37,
  huanggai: 78, xuhuang: 45, daqiao: 28, huangyueying: 57, caiwenji: 29,
  gaoshun: 45, zhanghe: 50, zhurong: 51, wutugu: 70, simayi: 65,
  pangde: 66, yanliang: 64, sunshangxiang: 50, yanyan: 47, caohong: 44, xushu: 58,
  jiaxu: 56, zuoci: 52, dengai: 62, menghuo: 55, wenchou: 54,
};
/* —— 羁绊（2026-07-08 拆门槛）：成员同场上阵就生效——一句话讲完。
   等级门槛退役：羁绊的乐趣在局内凑人（总池随机抽，"再来个庞德就成西凉铁骑"），
   同场=格子+抽卡运气，本身就是代价；等级照样让成员更猛（加成乘在身上），只是不再当开关。
   效果只挂成员身上（+25~35%，压得过局内噪音），全队向的只留三分谋主一个；
   六张白卡全部入绊——低使用率英雄靠羁绊拉回牌桌。 */
const BONDS = [
  // —— 门槛5级：小本经营的惊喜 ——
  { id: "erqiao",   name: "江东二乔", icon: "🌸", need: 5, members: ["daqiao", "xiaoqiao"],
    fx: { rate: 1.45, rippleRad: 60 }, desc: "两人的水波大一大圈、放得勤快多了" },
  { id: "shenyi",   name: "杏林妙音", icon: "🌿", need: 5, members: ["huatuo", "caiwenji"],
    fx: { rate: 1.5, hp: 1.35 }, desc: "两人的水波放得勤、人也耐打得多" },
  { id: "laojiang", name: "老当益壮", icon: "🏔️", need: 5, members: ["huangzhong", "yanyan"],
    fx: { dmg: 1.45, hp: 1.45 }, desc: "两位老将疼硬各+45%" },
  { id: "caoshi",   name: "曹家兄弟", icon: "🤝", need: 5, members: ["caoren", "caohong"],
    fx: { dmg: 1.35, hp: 1.4 }, desc: "兄弟同心，疼+35%耐打+40%" },
  { id: "juma",     name: "拒马双璧", icon: "🚧", need: 5, members: ["xuhuang", "xuchu"],
    fx: { palisade: 2 }, desc: "两人的拒马耐久和时长翻倍" },
  // —— 门槛9级：练出点名堂才点得亮 ——
  { id: "xiliang",  name: "西凉铁骑", icon: "🐎", need: 9, members: ["machao", "pangde"],
    fx: { dmg: 1.45 }, desc: "两人伤害+45%" },
  { id: "shuijing", name: "水镜高徒", icon: "📜", need: 9, members: ["xushu", "zhugeliang"],
    fx: { dmg: 1.35, sunder: true }, desc: "徐庶卸劲更狠(+20%)，两人更疼" },
  { id: "fengyi",   name: "凤仪亭",   icon: "💘", need: 9, members: ["lvbu", "diaochan"],
    fx: { dmg: 1.35, rate: 1.35 }, desc: "两人疼和出手各+35%" },
  { id: "jiangdong", name: "江东双督", icon: "⛵", need: 9, members: ["zhouyu", "lusu"],
    fx: { dmg: 1.35, rate: 1.4 }, desc: "两人更疼、水波勤快得多" },
  { id: "shensu",   name: "神速奇袭", icon: "💨", need: 9, members: ["xiahouyuan", "zhanghe"],
    fx: { rate: 1.35, dmg: 1.25 }, desc: "两人出手快35%还更疼" },
  // —— 门槛13级：深水区的大坑 ——
  { id: "sanfen",   name: "三分谋主", icon: "☯️", need: 13, members: ["zhugeliang", "zhouyu", "simayi"],
    fx: { ultHaste: 0.2 }, desc: "全军大招转快20%" },
  { id: "wuhu",     name: "五虎上将", icon: "🐯", need: 13, members: ["guanyu", "zhangfei", "zhaoyun", "machao", "huangzhong"],
    fx: { dmg: 1.4 }, desc: "五虎同场，各伤害+40%" },
  /* —— v7.6.0 扩池羁绊：新五将每人至少一条，顺手接活冷卡 —— */
  { id: "hebei",    name: "河北双璧", icon: "⚔️", need: 9, members: ["yanliang", "wenchou"],
    fx: { dmg: 1.45 }, desc: "颜良文丑同场，各伤害+45%" },
  { id: "manwang",  name: "蛮王夫妇", icon: "🌺", need: 5, members: ["menghuo", "zhurong"],
    fx: { dmg: 1.35, hp: 1.35 }, desc: "夫妇同场，疼硬各+35%" },
  { id: "nanman",   name: "南蛮同盟", icon: "🐘", need: 13, members: ["menghuo", "zhurong", "wutugu"],
    fx: { dmg: 1.2, hp: 1.3 }, desc: "南中三雄齐聚，更疼更耐打" },
  { id: "fangwai",  name: "方外之人", icon: "🀄", need: 5, members: ["zuoci", "huatuo"],
    fx: { rate: 1.5, hp: 1.3 }, desc: "方士医仙，出手勤人耐打" },
  { id: "yingshi",  name: "鹰视狼顾", icon: "🦅", need: 13, members: ["jiaxu", "simayi"],
    fx: { dmg: 1.3, rate: 1.3 }, desc: "两只老狐狸，又疼又勤" },
  { id: "qifeng",   name: "棋逢对手", icon: "♟️", need: 13, members: ["dengai", "jiangwei"],
    fx: { dmg: 1.4 }, desc: "宿敌同场较劲，各伤害+40%" },
];
function bondReady() { return true; }   // 门槛已退役（2026-07-08）：留个壳给老调用
function bondHas(id) { return !!state.bondSet?.has(id); }                        // 局内：同场上阵生效中
function bondFx(id) {
  const f = { dmg: 1, rate: 1, hp: 1, rippleRad: 0 };
  if (!state.bondSet) return f;
  for (const b of BONDS) {
    if (!state.bondSet.has(b.id) || !b.members.includes(id)) continue;
    f.dmg *= b.fx.dmg || 1;
    f.rate *= b.fx.rate || 1;
    f.hp *= b.fx.hp || 1;
    f.rippleRad += b.fx.rippleRad || 0;
  }
  const bmul = (state.relics?.some(r => r.id === "jinlan") ? 1.5 : 1) * (state.weekTheme === "tuanjie" ? 1.3 : 1);
  if (bmul !== 1) {   // 金兰谱×1.5 + 周主题·众志成城×1.3（叠乘）
    f.dmg = 1 + (f.dmg - 1) * bmul;
    f.rate = 1 + (f.rate - 1) * bmul;
    f.hp = 1 + (f.hp - 1) * bmul;
    f.rippleRad *= bmul;
  }
  return f;
}
function heroScore(id) {
  const lv = heroLv(id);
  let s = (BASE_SCORE[id] || 40) * (1 + (lv - 1) * HERO_LV_BONUS);
  if (lv >= MILE_STAR1) s *= 1.15;
  if (lv >= MILE_ULT) s *= 1.08;
  if (lv >= MILE_STAR2) s *= 1.15;
  return s;
}
/* 全队战力总分：主池是随机的，看的是"平均能拉出什么阵容"=全图鉴平均分×15格；升英雄/练主公都会让这个数动 */
function deckPower() {
  let s = 0;
  for (const g of GENERALS) s += heroScore(g.id);
  let ll = 0;
  for (const r of LORD_RULERS) ll += lordLv(r.id) - 1;   // v5.0 兵法项换主公项：五位共95级满
  return Math.round(s / GENERALS.length * 15 + ll * 1.6);
}
/* 每关推荐战力（v7.11.2 改实测标定，弃 sim 锚点）：
   旧曲线 420×1.18^k 是拿 sim 梯子校准的，但真人（对症/羁绊/操作）比 sim 策略强约6.5倍——
   k31 推荐 7.1万 而实际先锋战力才 1900~2000，虚高30倍，"还得练"变成永远在骂人。
   新标定：49名真实玩家 (deckPower, 本周前线) 对数拟合 → 前线战力 ≈ 938×1.029^k；
   推荐取拟合值×0.8（≈通关者的下四分位）：同前线的典型玩家绿灯、明显欠练的才红。
   巧合的好处：1.029^63 外推 ≈ 5700 正好贴满命战力天花板，一条公式64城通吃不用分段。
   复标定方法：拉全量用户档 → (deckPower, max weekBest k) 按 ln(pow)=A+Bk 最小二乘。 */
function recPower(k) { return Math.round(750 * Math.pow(1.029, k)); }
function freshMeta() {
  const heroes = {};
  for (const g of GENERALS) heroes[g.id] = { lv: 1 };   // v4.0：全将开放，等级=金币升
  return { gold: 0, heroes, pins: [], ach: [], achClaimed: [], totalKills: 0, wins: 0, tech: {},
    levelClears: {}, levelBest: {}, levelStars: {}, lastLevel: 0 };
}
function normalizeMeta(m) {
  m.ach ||= []; m.achClaimed ||= []; m.totalKills ||= 0; m.wins ||= 0; m.tech ||= {};
  m.goldTotal ??= m.gold || 0;   // 老档没这字段：拿余额垫底
  if (m.shards) { m.gold += m.shards * 40; delete m.shards; }   // 碎片机制已退役（被吞噬取代），存量折金币
  m.levelClears ||= {};   // 每关通关次数 { idx: n }
  m.levelBest ||= {};     // 每关最好成绩 { idx: { kills, wave } }，赢输都记
  m.levelStars ||= {};    // 每关三星评价 { idx: 1~3 }，取历史最高——战役榜按总星数排
  // 三星功能上线前的老档：通关过=保底1星（显示/总星/榜单三处一致），想要满星再打一遍
  for (const k of Object.keys(m.levelClears)) if (!m.levelStars[k]) m.levelStars[k] = 1;
  m.endlessBest ||= 0;    // 无尽最深打到第几波（全局荣誉纪录）
  delete m.trialBest;     // 周试炼已退役（被周赛季取代）
  m.lastLevel ??= 0;
  // 周赛季（Phase2→v7.11 天下争夺）：每周64城四区，周一换图——进度/势力值清零，金币/英雄等级/兵法保留
  m.weekBest ||= {};      // 每州郡本周最高分 { k: { score, stars, endless } }
  m.weekStars ||= {};     // 每州郡本周最好星数 { k: 1~3 }
  m.weekClears ||= {};    // 每州郡本周通关次数（首通大赏按这个判）
  m.weekBands ||= 0;      // 本周已领到第几档分数段奖
  m.weekTech ||= {};      // 每城本周最好韬略分 { k: tech }——韬略榜（比打法不比肝，周清零）
  m.adTotal ||= 0;        // 累计看广告次数（后台留档，将来接真广告）
  m.adN ||= 0;            // 今日已看次数
  m.adWeek ||= 0;
  m.rebirthTotal ||= 0;   // 累计转生次数（名将录收集墙）
  m.seppukuN ||= 0;       // 自刎归天次数（彩蛋成就）
  m.saveSeq ||= 0;        // 存档单调序号（v5.9.2 乐观锁：双设备后写覆盖防护）
  m.danceN ||= 0;         // 歌舞升平次数（彩蛋成就）
  // v5.7 贾诩→韩遂改名迁移（贾诩不是主公——用户指正；等级经验原样搬家）
  if (m.lords?.jiaxu) { m.lords.hansui ||= m.lords.jiaxu; delete m.lords.jiaxu; }
  if (m.lastRuler === "jiaxu") m.lastRuler = "hansui";
  if (m.rulersUsed?.jiaxu) { m.rulersUsed.hansui = 1; delete m.rulersUsed.jiaxu; }
  // v7.0 主公整合：马腾/韩遂/张鲁退役——三家总经验（含已升等级折算）相加灌给袁术，投入不清零。
  // TDZ 铁律：normalizeMeta 在 meta 初始化时执行，早于 LORD_LV_MAX/lordXpNeed 声明——只用内联算式（30+15v、封顶20）
  if (m.lords && (m.lords.mateng || m.lords.hansui || m.lords.zhanglu) && !m.lordsMergedV7) {
    let pool = 0;
    for (const cut of ["mateng", "hansui", "zhanglu"]) {
      const L = m.lords[cut];
      if (!L) continue;
      for (let v = 1; v < (L.lv || 1); v++) pool += 30 + 15 * v;   // 已升等级折回经验
      pool += L.xp || 0;
      delete m.lords[cut];
    }
    if (pool > 0) {
      const Y = (m.lords.yuanshu ||= { lv: 1, xp: 0 });
      Y.xp += pool;
      while (Y.lv < 20 && Y.xp >= 30 + 15 * Y.lv) { Y.xp -= 30 + 15 * Y.lv; Y.lv++; }
      if (Y.lv >= 20) Y.xp = Math.min(Y.xp, 30 + 15 * 20);
    }
    m.lordsMergedV7 = 1;
  }
  if (["mateng", "hansui", "zhanglu"].includes(m.lastRuler)) m.lastRuler = "liubei";
  for (const cut of ["mateng", "hansui", "zhanglu"])
    if (m.rulersUsed?.[cut]) { m.rulersUsed.yuanshu = 1; delete m.rulersUsed[cut]; }
  m.bondsSeen = m.bondsSeen || {};    // 局内触发过的羁绊 id
  m.rulersUsed = m.rulersUsed || {};  // 用过的主公 id         // 本赛季（本周）看广告次数——上榜给大家看
  m.adDay ??= 0;
  m.bossKills ||= 0;      // 累计斩贼首（成就链）
  m.perfectWins ||= 0;    // 累计三星通关（成就链）
  m.items ||= {};         // 道具背包 { visitToken/tupo: n }（v5.1；v7.17 转生石并入突破石）
  if (m.items.zhuansheng) { m.items.tupo = (m.items.tupo || 0) + m.items.zhuansheng * 5; delete m.items.zhuansheng; }   // 存量1💎折5🪨=正好一次转生的价，权益不倒退
  m.visitN ||= 0;         // 今日已领活跃奖励次数
  m.visitDay ??= 0;
  m.visitPos ||= 0;       // 寻访棋盘上站的格子
  m.visitBuffs ||= {};    // 黄历奇遇卡 { score/gold/again: 到期时间戳ms }（v7.17 寻访钩子）
  m.taofaDay ??= 0;       // 讨伐赏（v7.17）：日期戳/各州当日最深/今日已发令牌
  m.taofaBest ||= {};
  m.taofaGot ||= 0;
  rolloverWeek(m);
  // v4.0 迁移：抽卡/卡组退役——全将解锁，攒着的重复卡按碎片老价折金币，卡组字段作废
  m.heroes ||= {};
  for (const g of GENERALS) m.heroes[g.id] ||= { lv: 1 };
  for (const id of Object.keys(m.heroes)) {
    const h = m.heroes[id];
    h.lv = Math.min(HERO_LV_MAX + (h.rb || 0) * 10, h.lv || 1);   // v5.2：上限随转数走，别把转生将压回30
    if (h.cards) { m.gold += h.cards * 40; delete h.cards; }
  }
  delete m.deck;
  if (!Array.isArray(m.pins)) m.pins = [];   // 主将制已退役（v4.6）：字段留着兼容老档，不再有任何作用
  // v5.0 兵书归主公：已花的兵书金币一次性折算成主公经验（5位平分，全满兵书≈每位16级）。
  // 老 m.tech 字段冻结保留（不再读、不再卖）；注意此函数在兵书/主公常量声明前就会跑一次（fresh档），
  // 所以只有"真有兵书投入"的档才碰 TECHS/LORD_RULERS（那时全脚本已装载完）
  if (!m.lordsMigrated) {
    if (!Object.values(m.tech || {}).some(v => v > 0)) m.lordsMigrated = 1;
    else {
      let spent = 0;
      for (const t of TECHS) for (let i = 0; i < ((m.tech || {})[t.id] || 0); i++) spent += TECH_COSTS[i];
      const per = Math.round(spent / 750);
      for (const r of LORD_RULERS) lordAddXp(m, r.id, per);
      m.lordsMigrated = 1;
    }
  }
  return m;
}
/* —— 存档云端化：meta 整包存服务器（服务端当黑盒），登录成功后替换本地这份 —— */
let meta = normalizeMeta(freshMeta());
function saveMeta() {
  meta.lastPlayed = Date.now();
  try { localStorage.setItem(CACHE_KEY, JSON.stringify(meta)); } catch (e) {}
  netPushSoon();
}
/* 收金币统一走这：排行榜按"累计赚到的"排名，花掉不掉名次 */
function earnGold(n) {
  meta.gold += n;
  meta.goldTotal = (meta.goldTotal || 0) + n;
}

/* —— 账号网络层（浏览器才启用；冒烟测试没有 DOM，自动整层跳过） —— */
const IS_BROWSER = typeof document !== "undefined" && typeof document.createElement === "function";
const NET = { name: null, token: null, epoch: 0, timer: 0, board: null, boardAt: 0, stale: false };   // epoch=清档纪元；stale=另一设备档更新→本机停推
function netScore() { return Math.round((meta.goldTotal || 0) + frontierLevel() * 500); }
function buildSummary() {
  // 排行榜只需要这几个数——摘要格式不随游戏改版变，服务端永远不用懂 meta
  const prog = frontierLevel();
  const weekLevels = {};
  // v7.11：weekLevels 改存讨伐值（先锋=每城讨伐最深者，不再比总分）——全服讨伐值为0的城先锋虚位以待
  for (const k of Object.keys(meta.weekBest || {})) weekLevels[k] = cityTaofaOf(+k, meta.weekBest[k]);
  return {
    score: netScore(),
    goldTotal: meta.goldTotal || 0,
    prog,
    progTag: `第${(meta.week || trialWeekNow()) - WEEK0 + 1}期`,
    cleared: Object.keys(meta.weekClears || {}).length,
    wins: meta.wins,
    stars: weekStarsTotal(),
    endless: meta.endlessBest || 0,
    adTotal: meta.adTotal || 0,     // 广告观看留档（将来接真广告的底数）
    tech: weekTechTotal(),          // 韬略榜：本周用兵最漂亮的十役之和（比打法不比肝，与势力榜互不换算）
    // 账号快照（供后台抓取分析）：英雄等级 / 资源 / 兵书——服务端存进 summary，便于跨号查询不用拆 meta 黑盒
    heroLv: Object.fromEntries(Object.entries(meta.heroes || {}).map(([id, v]) => [id, v.lv || 1])),
    techLv: { ...(meta.tech || {}) },
    lords: Object.fromEntries(LORD_RULERS.map(r => [r.id, lordLv(r.id)])),   // v5.0：主公等级快照
    items: { ...(meta.items || {}) },   // v5.1：道具快照
    gold: meta.gold || 0,
    // 势力榜：本周势力值 + 各城讨伐值（先锋归属） + 上周终榜分（发排名奖用——没登录的人week还停在上周，登录过的看prev）
    week: { week: meta.week, score: weekScore(), stars: weekStarsTotal(), cleared: Object.keys(meta.weekClears || {}).length, ads: meta.adWeek || 0 },
    weekLevels,
    weekPrev: meta.pendingWeek ? { week: meta.pendingWeek.week, score: meta.pendingWeek.score }
      : meta.lastWeekReport ? { week: meta.lastWeekReport.week, score: meta.lastWeekReport.score } : null,
  };
}
async function api(route, body) {
  const r = await fetch(route, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body || {}),
  });
  return r.json();
}
function netPushSoon() {
  if (!IS_BROWSER || !NET.token || NET.stale) return;
  clearTimeout(NET.timer);
  NET.timer = setTimeout(netPushNow, 1500);
}
async function netPushNow() {
  if (!NET.token || NET.stale) return;
  try {
    meta.saveSeq = (meta.saveSeq || 0) + 1;   // 乐观锁（v5.9.2）：每次上云序号+1，服务端拒收比库里旧的
    const r = await api("/api/save", { name: NET.name, token: NET.token, ver: GAME_VERSION, epoch: NET.epoch, meta, summary: buildSummary() });
    if (r && r.stale) {
      // 另一台设备的档更新：本机立刻闭嘴，别把人家的进度盖了——刷新页面重新同步
      NET.stale = true;
      if (typeof addFloater === "function") addFloater(W / 2, 300, "⚠️ 另一台设备的存档更新——本机已停止保存，刷新页面同步", "#ff8a6a", 18);
    }
  } catch (e) {
    NET.timer = setTimeout(netPushNow, 8000);   // 掉线了，过会儿自动重试
  }
}
/* 切回前台/从冻结恢复时重新拉云端（v7.6.2 双端换玩根治）：手机浏览器会冻结后台标签页，
   切回来还端着几小时前的旧档——它既会把旧进度显示给玩家（"进度回退了"），玩起来推档还可能
   反盖另一台的新档。这里在标签页重新可见/BFCache 恢复时拉一次云端：云端 saveSeq 更大=另一台
   有更新的进度，本机在闲时(标题/地图)直接采用，正在打的这局(play/结算)只停推防覆盖+提示刷新。 */
function netResync() {
  if (!IS_BROWSER || !NET.token) return;
  const now = Date.now();
  if (now - (NET.resyncAt || 0) < 3000) return;   // 防抖：频繁切前台不狂拉
  NET.resyncAt = now;
  api("/api/load", { name: NET.name, token: NET.token }).then((r) => {
    if (!r || !r.ok || !r.meta) return;
    const cloudSeq = typeof r.meta.saveSeq === "number" ? r.meta.saveSeq : 0;
    const localSeq = typeof meta.saveSeq === "number" ? meta.saveSeq : 0;
    if (cloudSeq <= localSeq) return;   // 本机同样新或更新——别覆盖本机还没推上去的进度
    const idle = state.phase === "title" || state.phase === "pickDiff";
    if (idle) {
      // 另一台设备的档更新，且本机没在打——直接采用云端最新档
      clearTimeout(NET.timer);          // 取消可能待发的旧档推送（否则会带着新序号把云端盖回旧的）
      meta = normalizeMeta(r.meta);
      NET.epoch = r.epoch || NET.epoch;
      NET.stale = false;                // 顺带从"另一台更新已停推"的状态里自动恢复，不用手动刷新
      try { localStorage.setItem(CACHE_KEY, JSON.stringify(meta)); } catch (e) {}
      if (typeof addFloater === "function") addFloater(W / 2, 300, "☁️ 已同步另一台设备的最新进度", "#7ad86a", 18);
    } else {
      // 正在打这局：换内存档会搅乱进行中的对局——只停推防覆盖云端，打完回标题刷新即同步
      NET.stale = true;
    }
  }).catch(() => {});
}
/* 战斗流水（供数据分析）：每次结算把这一局关键数据 + 账号快照发后台，追加进 battles.jsonl。
   fire-and-forget，掉线丢一条不重试——分析数据不值得拖累游戏 */
function buildBattleRecord(type) {
  const d = state.diff || {};
  const units = allUnits();
  return {
    type,                                     // clear=通关那刻 / over=城破
    ver: GAME_VERSION,
    week: d.week ?? null, k: d.k ?? null, theme: d.theme || null,
    stars: state.stars || 0,
    wave: state.wave || 0, winWave: state.winWave || 0,
    endless: !!state.endless,
    endlessWaves: state.winWave ? Math.max(0, state.wave - state.winWave) : 0,
    tech: state.runTech || 0,
    counterPct: state.totalDmg > 0 ? Math.round(100 * state.counterDmg / state.totalDmg) : 0,
    cityHP: state.baseHP || 0, cityMax: state.baseHPMax || 0,
    dur: Math.round(state.time || 0), kills: state.kills || 0,
    ults: state.ultsUsed || 0, lordUsed: state.lordUsed || 0, deaths: state.unitDeaths || 0,
    gewu: state.gewu ? 1 : 0,   // 歌舞升平·不早朝（v5.9）：这局有没有躺平——用量和强度都要看数据
    gold: state.goldEarned || 0,
    ruler: state.ruler || null,
    lineup: units.map(u => ({ id: u.type.id, lv: u.level, elem: u.type.elem, cls: u.type.cls })),
    shen: units.filter(u => isShen(u.type.id)).map(u => u.type.id),   // 本局上阵的神将（验证神将机制拉不拉得动使用率）
    bonds: state.bondSet ? [...state.bondSet] : [],
    elems: state.elemsUsed ? [...state.elemsUsed] : [],
    // 账号快照：这一局打的时候，这个号的英雄等级/资源/兵书是什么样
    acct: {
      gold: meta.gold || 0, goldTotal: meta.goldTotal || 0,
      heroLv: Object.fromEntries(Object.entries(meta.heroes || {}).map(([id, v]) => [id, v.lv || 1])),
      tech: { ...(meta.tech || {}) }, techTotal: techTotal(),
      rebirth: meta.rebirthTotal || 0, wins: meta.wins || 0, prog: frontierLevel(),
      lords: Object.fromEntries(LORD_RULERS.map(r => [r.id, lordLv(r.id)])),   // v5.0：主公等级快照
      items: { ...(meta.items || {}) },   // v5.1：道具快照
    },
  };
}
/* 主公经验结算（v5.0 主公府）：通关=6+州阶+星×2（k15三星≈27），败仗=3+州阶/2 安慰，无尽收尾=2。
   带谁出征谁涨全额；v7.14 陪练经验：其余七家旁听拿1/2——实测头部玩家清一色只带曹操，
   根子是换人=从Lv1残血体验重开；陪练把弱势主公的底子垫起来，试用不再是折磨 */
function settleLordXp(kind) {
  const rid = state.ruler;
  if (!rid) return;
  const k = state.diff?.k ?? 0;
  const gain = kind === "clear" ? 6 + k + (state.stars || 0) * 2
    : state.winWave ? 2 : 3 + Math.floor(k / 2);
  const before = lordLv(rid);
  lordAddXp(meta, rid, gain);
  const side = Math.max(1, Math.round(gain / 2));   // v7.14.1 加码：1/3→1/2，板凳更快有底子
  for (const r of LORD_RULERS) if (r.id !== rid) lordAddXp(meta, r.id, side);
  state.lordXpGot = { rid, gain, up: lordLv(rid) > before, lv: lordLv(rid) };
}
function netLogBattle(type) {
  if (!IS_BROWSER || !NET.token) return;
  api("/api/battle", { name: NET.name, token: NET.token, ver: GAME_VERSION, epoch: NET.epoch, rec: buildBattleRecord(type) }).catch(() => {});
}
/* 无感热更（v7.18.8）：结算时悄悄问一嘴服务器版本，不同则记下；
   玩家点"回地图/回首页"时带标记刷新页面——回来直接跳回该在的地方并提示已更新。
   只在结算出口刷新，绝不打断战斗中 */
let newVerSeen = null;
function netCheckNewVer() {
  if (!IS_BROWSER) return;
  fetch("/api/version?t=" + Date.now()).then(r => r.json()).then(j => {
    if (j && j.ok && j.ver && j.ver !== GAME_VERSION) newVerSeen = j.ver;
  }).catch(() => {});
}
function reloadForUpdate(where) {
  try {
    sessionStorage.setItem("sanguo_resume", where);
  } catch (e) {}
  location.replace(location.pathname + "?v=" + encodeURIComponent(newVerSeen || Date.now()));
}
async function netFetchBoard(force = false) {
  if (!IS_BROWSER) return null;
  if (!force && NET.board && Date.now() - NET.boardAt < 60000) return NET.board;
  try {
    const r = await fetch("/api/board").then((x) => x.json());
    if (r.ok) { NET.board = r; NET.boardAt = Date.now(); }
  } catch (e) {}
  return NET.board;
}
function ownsHero(id) { return !!(meta.heroes && meta.heroes[id]); }
/* 三星评价：赢1星 + 城墙无伤1星 + 无人阵亡1星 */
function calcStars() { return 1 + (state.wallHurt ? 0 : 1) + (state.unitDeaths ? 0 : 1); }
/* 本局能上场的武将 = 全图鉴40人（v4.6 点将台/主将退役：开局和局内三选一都从总池随机——
   每局都是新牌桌，抽拉了重开，抽天胡巨爽） */
function availableGenerals() { return GENERALS; }

/* —— 图鉴升级（金币的主坑，等级跨赛季保留）：升到第 lv 级价 = heroUpCost(lv)。
   v5.2 突破/转生：上限=30+10×转数（最多3转=60）；10级要1颗、20级要2颗突破石随金币一起扣；
   v7.17 材料合一：转生石退役并入突破石——满上限转生花 5/8/12 颗突破石（上限+10，显示N转），
   🪨=唯一的等级材料（过坎小额、转生大额），"好用但升不动"的钩子全摆在明面 —— */
const HERO_RB_MAX = 3;
const RB_STONES = [5, 8, 12];   // 第1/2/3转的突破石价（越往后越金贵）
function heroRb(id) { return (meta.heroes && meta.heroes[id] && meta.heroes[id].rb) || 0; }
function heroCap(id) { return HERO_LV_MAX + heroRb(id) * 10; }
function heroGateStones(lv) { return lv === 10 ? 1 : lv === 20 ? 2 : 0; }   // 升过这一级要几颗突破石
function heroUp(id) {
  const h = meta.heroes[id];
  if (!h || h.lv >= heroCap(id)) return false;
  const stones = heroGateStones(h.lv);
  if (stones && itemN("tupo") < stones) return false;
  const cost = heroUpCost(h.lv + 1, id);
  if (meta.gold < cost) return false;
  if (stones) addItem("tupo", -stones);
  meta.gold -= cost;
  h.lv++;
  addHeroXp(id, 0);   // 突破后寻访攒的经验立刻结转
  achSweep();   // 英雄等级/五虎齐心成就链
  saveMeta();
  return true;
}
/* 局外转生：满上限+RB_STONES[转数]颗突破石→上限+10（只扩上限不给数值，数值靠继续升级） */
function heroRebirth(id) {
  const h = meta.heroes[id];
  if (!h || h.lv < heroCap(id) || heroRb(id) >= HERO_RB_MAX || itemN("tupo") < RB_STONES[heroRb(id)]) return false;
  addItem("tupo", -RB_STONES[heroRb(id)]);
  h.rb = (h.rb || 0) + 1;
  meta.rebirthTotal = (meta.rebirthTotal || 0) + 1;   // 名将录收集墙延续
  unlockAch("rebirth1");
  addHeroXp(id, 0);
  achSweep();
  saveMeta();
  return true;
}
/* 重置英雄（v7.8.0：升级升错了能反悔）：全额退回升级金币 + 突破石（含转生花的），等级回1、转生清零。
   退款只进可花余额 meta.gold，不动 goldTotal（退款不是赚钱，别刷排行榜分）。 */
function heroResetPreview(id) {
  const h = meta.heroes && meta.heroes[id];
  if (!h) return null;
  const rb = heroRb(id);
  if (h.lv <= 1 && !rb) return null;   // 1级又没转生：没练过，没啥好退
  let gold = 0;
  for (let lv = 2; lv <= h.lv; lv++) gold += heroUpCost(lv, id);
  let stones = (h.lv > 10 ? 1 : 0) + (h.lv > 20 ? 2 : 0);   // 突破石：过10级付了1颗、过20级再付2颗
  for (let i = 0; i < rb; i++) stones += RB_STONES[i];      // 转生花的石头也全退（按现价）
  return { gold, stones };
}
function heroReset(id) {
  const pv = heroResetPreview(id);
  if (!pv) return null;
  const h = meta.heroes[id];
  meta.gold += pv.gold;
  if (pv.stones) addItem("tupo", pv.stones);
  h.lv = 1; h.rb = 0; h.xp = 0;
  achSweep();
  saveMeta();
  return pv;
}
const SHOP_BTN  = { x: 10,  y: 650, w: 110, h: 44 };
const TECH_BTN  = { x: 126, y: 650, w: 110, h: 44 };
const VISIT_BTN = { x: 242, y: 650, w: 110, h: 44 };   // 寻访入口（v5.1）
const ACH_BTN   = { x: 358, y: 650, w: 110, h: 44 };
const BAG_BTN   = { x: W / 2 - 58, y: H - 44, w: 116, h: 32 };   // 背包（底栏中间）
/* —— 假广告（Phase2，IAA演练）：15秒假进度条换金币，每日限次；累计次数进摘要给后台留档。
   将来接真广告SDK只用换播放那一段，入口和记账不动 —— */
const AD_GOLD = 360, AD_DAILY = 10, AD_SECS = 3;   // 2026-07-13 每日15→10次（寻访令牌上限放开，看广告收敛点）；2026-07-11 单价翻倍180→360；2026-07-08 等待15秒→3秒（测试期别折磨自己人；接真广告时长由广告SDK定）
const AD_TOKEN_P = 0.5;   // 2026-07-11 看完广告50%概率额外掉1块寻访令
/* 假广告创意池（v7.15.1 用户点名：10条轮换着播）——三国风恰饭文案，随机不重复上一条 */
const AD_CREATIVES = [
  { icon: "🐎", name: "的卢宝马行",     s1: "「妨主？不存在的，跳个檀溪你就知道了」", s2: "蹄如踏雪 · 日行千里 · 童叟无欺" },
  { icon: "🍷", name: "杜康酒庄",       s1: "「何以解忧？唯有本店」",                 s2: "曹丞相同款 · 对酒当歌 · 假一罚十" },
  { icon: "🪶", name: "卧龙鹅毛扇",     s1: "「扇子一摇，锦囊自来」",                 s2: "隆中直营 · 夏凉冬暖 · 送三个锦囊" },
  { icon: "⚕️", name: "华佗养生馆",     s1: "「五禽戏包教包会，刮骨不疼不收费」",     s2: "行医四方 · 药到病除 · 预约从速" },
  { icon: "🛏️", name: "南阳草庐民宿",   s1: "「三顾茅庐同款，住满三晚保出山」",       s2: "带躬耕体验 · 梁父吟晨叫 · 好评如潮" },
  { icon: "🗡️", name: "青釭剑专卖",     s1: "「削铁如泥，赵将军长坂坡亲测」",         s2: "夏侯恩泪目 · 限量发售 · 先到先得" },
  { icon: "📜", name: "水镜兵法函授班", s1: "「熟读三十六计，前五计免费试听」",       s2: "司马徽亲授 · 卧龙凤雏都是校友" },
  { icon: "🍑", name: "桃园结义主题园", s1: "「缺两个兄弟？拜把子套餐今日特惠」",     s2: "含乌牛白马祭品 · 誓词代写 · 合影留念" },
  { icon: "🏹", name: "草船借箭租赁",   s1: "「十万支箭，雾天三日达」",               s2: "曹氏箭厂友情赞助 · 信用免押 · 只借不还" },
  { icon: "🐂", name: "木牛流马物流",   s1: "「蜀道难？我们不觉得」",                 s2: "丞相监制 · 祁山专线 · 全年无休" },
];
const AD_BTN   = { x: W / 2 - 160, y: 692, w: 320, h: 44 };   // v7.17.2 从首页搬进寻访页底部
const AD_CLAIM = { x: W / 2 - 110, y: 500, w: 220, h: 48 };
const AD_QUIT  = { x: W / 2 - 60,  y: 574, w: 120, h: 34 };
let adWatch = null;   // { start, ad } 播放中（ad=本次创意）
let adLastIdx = -1;
function adPick() {
  let i = Math.floor(Math.random() * AD_CREATIVES.length);
  if (i === adLastIdx) i = (i + 1) % AD_CREATIVES.length;   // 不和上一条重复
  adLastIdx = i;
  return AD_CREATIVES[i];
}
function adTodayN() {
  if (meta.adDay !== dayKeyNow()) { meta.adDay = dayKeyNow(); meta.adN = 0; }
  return meta.adN;
}
function adClick(p) {
  const done = (performance.now() - adWatch.start) / 1000 >= AD_SECS;
  if (done && inBtn(p, AD_CLAIM)) {
    adTodayN();   // 顺带跨天清零
    meta.adN++;
    meta.adTotal = (meta.adTotal || 0) + 1;
    meta.adWeek = (meta.adWeek || 0) + 1;
    earnGold(AD_GOLD);
    if (Math.random() < AD_TOKEN_P) {   // 50%概率额外掉寻访令
      addItem("visitToken", 1);
      addFloater(W / 2, 360, "🧭 寻访令 +1！", "#8ad2ff", 20);
    }
    achSweep();   // 广告/金币累计成就链
    saveMeta();
    SFX.buff();
    adWatch = null;
    return;
  }
  if (!done && inBtn(p, AD_QUIT)) adWatch = null;
}
function drawAdOverlay() {
  const t = clamp((performance.now() - adWatch.start) / 1000, 0, AD_SECS);
  const done = t >= AD_SECS;
  ctx.fillStyle = "rgba(0,0,0,.82)";
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = "rgba(30,24,12,.97)";
  roundRect(W / 2 - 190, 220, 380, 410, 16);
  ctx.fill();
  ctx.strokeStyle = "#e8c86a";
  ctx.lineWidth = 2;
  roundRect(W / 2 - 190, 220, 380, 410, 16);
  ctx.stroke();
  ctx.textAlign = "center";
  ctx.font = "bold 15px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("—— 广告 ——", W / 2, 252);
  const adC = adWatch.ad || (adWatch.ad = adPick());
  ctx.font = "bold 30px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`${adC.icon} ${adC.name}`, W / 2, 320);
  ctx.font = "16px sans-serif";
  ctx.fillStyle = "#e8dcc0";
  ctx.fillText(adC.s1, W / 2, 358);
  ctx.fillText(adC.s2, W / 2, 386);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText(`（假广告，练手用——看满${AD_SECS}秒领钱，将来换成真的）`, W / 2, 420);
  // 进度条
  ctx.fillStyle = "rgba(255,255,255,.10)";
  roundRect(W / 2 - 150, 448, 300, 16, 8);
  ctx.fill();
  ctx.fillStyle = done ? "#9adf5a" : "#ffb84a";
  roundRect(W / 2 - 150, 448, Math.max(8, 300 * (t / AD_SECS)), 16, 8);
  ctx.fill();
  if (done) {
    drawButton(AD_CLAIM, `🎁 领 ${AD_GOLD}💰`, "#3a6a2a");
    ctx.font = "12px sans-serif";
    ctx.fillStyle = "#8ad2ff";
    ctx.fillText("（半数机会额外掉 🧭 寻访令 +1）", W / 2, 568);
  } else {
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = "#d5c9a8";
    ctx.fillText(`还剩 ${Math.ceil(AD_SECS - t)} 秒`, W / 2, 528);
    drawButton(AD_QUIT, "不看了", "#5a4a3a");
  }
}

/* —— 道具背包 + 活跃奖励 + 寻访（v5.1.0）——
   活跃奖励：通关一场=3块寻访令牌，每日30场满额；满额后走「讨伐赏」深度轴（每州当日最深一役，5波=3块，日封顶30）。
   突破石先入包攒着——过坎、转生都用它（v7.17 材料合一，钩子摆在明面上） —— */
const ITEMS_DEF = [
  { id: "visitToken", icon: "🧭", name: "寻访令牌", desc: "寻访掷骰用。通关战斗攒（每天30场满额），讨伐撑得深另有讨伐赏（每天最多再+30）" },
  { id: "tupo",       icon: "🪨", name: "突破石",   desc: "过坎和转生都用它：10级1颗、20级2颗，转生5/8/12颗——寻访里拿" },
];
function itemN(id) { return (meta.items && meta.items[id]) || 0; }
function addItem(id, n) { meta.items ||= {}; meta.items[id] = (meta.items[id] || 0) + n; }
function visitTodayN() {
  if (meta.visitDay !== dayKeyNow()) { meta.visitDay = dayKeyNow(); meta.visitN = 0; }
  return meta.visitN;
}
/* 活跃奖励：只认通关（城破不算），每日30次满额——state.visitGot 驱动结算页那一行。
   v5.4.6 每次1块→3块；v7.2.0 日上限10→20；v7.17 上限20→30。
   超额部分不走次数轴（挂机刷贱关能薅），走下面的「讨伐赏」深度轴 */
const VISIT_PER = 3;
const VISIT_DAILY = 30;   // v7.17 日上限 20→30
function settleActive() {
  if (visitTodayN() >= VISIT_DAILY) { state.visitGot = 0; return; }
  meta.visitN++;
  addItem("visitToken", VISIT_PER);
  state.visitGot = VISIT_PER;
}
/* 讨伐赏（v7.17）：通关次数满额后的令牌产出挂在讨伐深度轴上——每座城每天只认当日最深一役，
   讨伐每多撑5波=+3令牌（跨档当场发），全天封顶30块。同州同深度重复打=0，防挂机刷贱关；
   深度由1.18复利定价（防露营不变量守门），高base无尽玩家正是拿最多的人 */
const TAOFA_STEP = 5, TAOFA_STEP_TOKENS = 3, TAOFA_TOKEN_DAILY = 30;
function taofaSync() {
  if (meta.taofaDay !== dayKeyNow()) { meta.taofaDay = dayKeyNow(); meta.taofaBest = {}; meta.taofaGot = 0; }
}
function grantTaofaTokens(k, waves) {
  taofaSync();
  const prev = (meta.taofaBest || {})[k] || 0;
  if (!(waves > prev)) return 0;   // 没破这州今日最深，一分不多给
  meta.taofaBest[k] = waves;
  const units = Math.floor(waves / TAOFA_STEP) - Math.floor(prev / TAOFA_STEP);
  if (units <= 0) return 0;
  const give = Math.min(units * TAOFA_STEP_TOKENS, TAOFA_TOKEN_DAILY - (meta.taofaGot || 0));
  if (give <= 0) return 0;
  meta.taofaGot = (meta.taofaGot || 0) + give;
  addItem("visitToken", give);
  state.taofaGot = (state.taofaGot || 0) + give;
  if (state.phase === "play") addFloater(W / 2, 330, `🗡️ 讨伐赏 +${give}令牌（今日 ${meta.taofaGot}/${TAOFA_TOKEN_DAILY}）`, "#ffd24a", 17);
  return give;
}
/* 英雄经验（寻访产出）：白得的升级进度——攒满下一级的金币价自动升级（金币购买照旧，互不干扰）。
   自动升级不跨突破关口（10/20级停下等突破石），也不跨转生上限——攒着的经验突破/转生后立刻结转 */
function addHeroXp(id, n) {
  const h = meta.heroes[id];
  if (!h) return null;
  const from = h.lv, xp0 = h.xp || 0;
  h.xp = xp0 + n;
  while (h.lv < heroCap(id) && !heroGateStones(h.lv) && h.xp >= heroUpCost(h.lv + 1, id)) { h.xp -= heroUpCost(h.lv + 1, id); h.lv++; }
  if (h.lv >= HERO_LV_MAX + HERO_RB_MAX * 10) h.xp = 0;   // 3转满级：经验没用了
  return { from, to: h.lv, xp0, xp: h.xp, need: h.lv < heroCap(id) && !heroGateStones(h.lv) ? heroUpCost(h.lv + 1, id) : 0 };
}
/* 兵法研究 2.0（金币购买的永久加成，12项×5级：兵种操练/通用/战备） */
const TECH_COSTS = [300, 1200, 5000, 25000, 110000];   // 长线轮：全满≈中度19周（奖金池×3后4/5级联动加深）；前两级依旧新手买得起
const TECHS = [
  { id: "d_spear",  icon: "🔱", grp: "操练", name: "枪术操练", max: 5, per: "枪兵伤害+3%",     desc: l => `枪兵伤害+${l * 3}%` },
  { id: "d_archer", icon: "🏹", grp: "操练", name: "箭术操练", max: 5, per: "弓兵伤害+3%",     desc: l => `弓兵伤害+${l * 3}%` },
  { id: "d_cav",    icon: "🐎", grp: "操练", name: "马术操练", max: 5, per: "骑兵伤害+3%",     desc: l => `骑兵伤害+${l * 3}%` },
  { id: "d_shield", icon: "🛡️", grp: "操练", name: "坚盾操练", max: 5, per: "盾兵血量+4%",     desc: l => `盾兵血量+${l * 4}%` },
  { id: "d_supp",   icon: "🎐", grp: "操练", name: "医术操练", max: 5, per: "辅兵水波转快+3%", desc: l => `辅兵水波转快+${l * 3}%` },
  { id: "wall",     icon: "🏯", grp: "通用", name: "城防加固", max: 5, per: "城墙上限+1",      desc: l => `城墙上限+${l}` },
  { id: "farm",     icon: "🌾", grp: "通用", name: "军屯广积", max: 5, per: "杀敌经验+4%",     desc: l => `杀敌经验+${l * 4}%` },
  { id: "bounty",   icon: "💰", grp: "通用", name: "犒赏有方", max: 5, per: "金币+4%",         desc: l => `金币+${l * 4}%` },
  { id: "supply",   icon: "👑", grp: "通用", name: "帅印传家", max: 5, per: "主公技转快4%",    desc: l => `主公技转快${l * 4}%` },
  { id: "pick",     icon: "🛡️", grp: "战备", name: "固守金汤", max: 5, per: "开局城墙护盾+2",   desc: l => `开局城墙护盾 +${l * 2}` },
  { id: "vet",      icon: "🎖️", grp: "战备", name: "老兵传承", max: 5, per: "开局自带10经验",  desc: l => `开局自带${l * 10}经验` },
  { id: "mend",     icon: "🧱", grp: "战备", name: "缮城营造", max: 5, per: "每5波城墙回1",    desc: l => `每5波城墙回${l}` },
];
function techLv(id) {
  // v5.0 兵书归主公：被动只在带对应主公的局里生效（等级随主公等级解锁）；局外/未点主公=0
  return (typeof state !== "undefined" && state && state.ruler) ? lordPassiveLv(state.ruler, id) : 0;
}
/* —— 主公养成（v5.0 主公府）：主公可升级（不手动喂金币——战斗结算给经验，后续寻访再加渠道）。
   等级驱动三件事：招牌技威力、兵书被动解锁、专属机制强度。局内不成长。 —— */
const LORD_LV_MAX = 20;
function lordXpNeed(lv) { return 30 + 15 * lv; }   // 升到下一级要的经验；1→20累计≈3700
function lordLv(id) { return (meta.lords && meta.lords[id] && meta.lords[id].lv) || 1; }
function lordXpNow(id) { return (meta.lords && meta.lords[id] && meta.lords[id].xp) || 0; }
function lordAddXp(m, id, n) {
  m.lords ||= {};
  const L = (m.lords[id] ||= { lv: 1, xp: 0 });
  L.xp += n;
  let ups = 0;
  while (L.lv < LORD_LV_MAX && L.xp >= lordXpNeed(L.lv)) { L.xp -= lordXpNeed(L.lv); L.lv++; ups++; }
  if (L.lv >= LORD_LV_MAX) L.xp = Math.min(L.xp, lordXpNeed(LORD_LV_MAX));   // 满级封顶：别无限攒
  return ups;
}
/* 招牌技威力=主公等级映射（1/9/17级各升一档，共3档=LORD_MAX_LV） */
function lordSkillLv(id) { return Math.min(3, 1 + Math.floor((lordLv(id) - 1) / 8)); }
/* 某主公的某本兵书被动当前几级：被动表里查解锁门槛（同一本兵书可在多位主公处出现，取最高） */
function lordPassiveLv(rulerId, techId) {
  const r = LORD_RULERS.find(x => x.id === rulerId);
  if (!r) return 0;
  let lv = 0;
  for (const ps of r.passives) if (ps.id === techId) lv = Math.max(lv, ps.at.filter(t => lordLv(rulerId) >= t).length);
  return lv;
}

/* 成就 */
/* 成就：达成后有金币可领（点成就页里的行领取），没领的在首页按钮上亮红点 */
/* —— 成就 2.0（2026-07-07 扩充轮）：15个→52个，切细成链条（杀敌/胜场/势力值/英雄等级各分档），
   四类页签排版；带 prog 的是计数成就（页面上有进度条），achSweep 统一巡检解锁；
   没 prog 的是事件成就，打点处 unlockAch。奖金总池≈3.1万（一次性，摊在数月里，不冲周薪盘子） —— */
const heroMaxLv = () => Math.max(...Object.values(meta.heroes).map(h => h.lv || 1));
const techTotal = () => Object.values(meta.tech).reduce((s, v) => s + v, 0);   // 老兵书总级（冻结字段，只做迁移与留档）
const lordsTotal = () => LORD_RULERS.reduce((s, r) => s + lordLv(r.id), 0);   // 主公总等级（成就/名将录用；v5.6起八位，8起步160满）
const ACHS = [
  // —— 战功：杀出来的 ——
  { id: "first100",  grp: "战功", name: "初阵告捷", desc: "一局杀 100 个黄巾", gold: 100 },
  { id: "slay800",   grp: "战功", name: "一骑当千", desc: "一局杀 800 个", gold: 300 },
  { id: "kills1k",   grp: "战功", name: "小有战功", desc: "累计杀 1000 个", gold: 150, prog: () => [meta.totalKills, 1000] },
  { id: "kills5000", grp: "战功", name: "万人之敌", desc: "累计杀 5000 个", gold: 500, prog: () => [meta.totalKills, 5000] },
  { id: "kills20k",  grp: "战功", name: "尸山血海", desc: "累计杀 2 万个", gold: 800, prog: () => [meta.totalKills, 20000] },
  { id: "kills60k",  grp: "战功", name: "杀神降世", desc: "累计杀 6 万个", gold: 1500, prog: () => [meta.totalKills, 60000] },
  { id: "win",       grp: "战功", name: "克敌制胜", desc: "打赢头一仗", gold: 150 },
  { id: "wins10",    grp: "战功", name: "连战连捷", desc: "打赢 10 仗", gold: 300, prog: () => [meta.wins, 10] },
  { id: "wins30",    grp: "战功", name: "百战老兵", desc: "打赢 30 仗", gold: 600, prog: () => [meta.wins, 30] },
  { id: "wins100",   grp: "战功", name: "常胜将军", desc: "打赢 100 仗", gold: 1200, prog: () => [meta.wins, 100] },
  { id: "boss10",    grp: "战功", name: "猎首者",   desc: "斩 10 个贼首", gold: 300, prog: () => [meta.bossKills || 0, 10] },
  { id: "boss50",    grp: "战功", name: "贼首克星", desc: "斩 50 个贼首", gold: 800, prog: () => [meta.bossKills || 0, 50] },
  { id: "zhangjiao", grp: "战功", name: "斩首行动", desc: "干掉贼首张角", gold: 400 },
  // —— 讨伐：州郡和周榜的路 ——
  { id: "weekclear1",  grp: "讨伐", name: "出师告捷", desc: "拿下头一个州郡", gold: 100, prog: () => [Object.keys(meta.weekClears || {}).length, 1] },
  { id: "weekclear8",  grp: "讨伐", name: "半壁江山", desc: "一周内拿下 8 个州郡", gold: 400, prog: () => [Object.keys(meta.weekClears || {}).length, 8] },
  { id: "weekclear16", grp: "讨伐", name: "东境已定", desc: "一周内拿下东部 16 城", gold: 1000, prog: () => [Object.keys(meta.weekClears || {}).length, 16] },
  { id: "weekclear32", grp: "讨伐", name: "问鼎洛阳", desc: "一周内拿下东部+南部 32 城（打进洛阳）", gold: 3000, prog: () => [Object.keys(meta.weekClears || {}).length, 32] },
  { id: "weekclear48", grp: "讨伐", name: "西定巴蜀", desc: "一周内拿下 48 城（西征入成都）", gold: 5000, prog: () => [Object.keys(meta.weekClears || {}).length, 48] },
  { id: "weekclear64", grp: "讨伐", name: "混一天下", desc: "一周内 64 城全拿下（北境打穿）", gold: 8000, prog: () => [Object.keys(meta.weekClears || {}).length, 64] },
  { id: "hellwin",   grp: "讨伐", name: "北伐先锋", desc: "拿下幽州以北的硬茬州郡", gold: 800 },
  { id: "shurawin",  grp: "讨伐", name: "直捣广宗", desc: "拿下广宗，端了黄巾老巢", gold: 2000 },
  { id: "star3first", grp: "讨伐", name: "旗开得胜", desc: "头一次三星通关", gold: 200 },
  { id: "perfect10", grp: "讨伐", name: "常胜之师", desc: "三星通关累计 10 次", gold: 600, prog: () => [meta.perfectWins || 0, 10] },
  { id: "wscore5k",  grp: "讨伐", name: "崭露头角", desc: "势力值单周打到 4000", gold: 300, prog: () => [weekScore(), 4000] },
  { id: "wscore20k", grp: "讨伐", name: "名震一方", desc: "势力值单周打到 1 万 2", gold: 800, prog: () => [weekScore(), 12000] },
  { id: "wscore45k", grp: "讨伐", name: "天下无双", desc: "势力值单周打到 2 万 5", gold: 2000, prog: () => [weekScore(), 25000] },
  { id: "wave20",    grp: "讨伐", name: "坚壁清野", desc: "一局撑到第 20 波", gold: 300 },
  { id: "wave35",    grp: "讨伐", name: "中流砥柱", desc: "无尽撑到第 35 波", gold: 800 },
  { id: "lordwin",   grp: "讨伐", name: "割据一方", desc: "当上一城的先锋（讨伐全服最深）", gold: 500 },
  // —— 养成：钱花在哪的路 ——
  { id: "hero5",     grp: "养成", name: "初露锋芒", desc: "把一个英雄升到 5 级", gold: 150, prog: () => [heroMaxLv(), 5] },
  { id: "hero10",    grp: "养成", name: "精兵强将", desc: "把一个英雄升到 10 级", gold: 300, prog: () => [heroMaxLv(), 10] },
  { id: "hero20",    grp: "养成", name: "千锤百炼", desc: "把一个英雄升到 20 级", gold: 800, prog: () => [heroMaxLv(), 20] },
  { id: "hero30",    grp: "养成", name: "登峰造极", desc: "把一个英雄升到满级 30", gold: 2000, prog: () => [heroMaxLv(), 30] },
  { id: "pins5lv5",  grp: "养成", name: "五虎齐心", desc: "让五虎上将羁绊在一局里生效", gold: 400 },
  { id: "gold10k",   grp: "养成", name: "第一桶金", desc: "累计赚 1 万金币", gold: 200, prog: () => [meta.goldTotal || 0, 10000] },
  { id: "gold50k",   grp: "养成", name: "家底殷实", desc: "累计赚 5 万金币", gold: 500, prog: () => [meta.goldTotal || 0, 50000] },
  { id: "gold200k",  grp: "养成", name: "富可敌国", desc: "累计赚 20 万金币", gold: 1200, prog: () => [meta.goldTotal || 0, 200000] },
  { id: "tech5",     grp: "养成", name: "深谙韬略", desc: "主公升到共 12 级", gold: 300, prog: () => [lordsTotal(), 12] },
  { id: "tech20",    grp: "养成", name: "熟读兵书", desc: "主公升到共 40 级", gold: 800, prog: () => [lordsTotal(), 40] },
  { id: "tech60",    grp: "养成", name: "韬略大成", desc: "主公总等级练到 100", gold: 2500, prog: () => [lordsTotal(), 100] },
  { id: "ad10",      grp: "养成", name: "军情灵通", desc: "看广告累计 10 次", gold: 150, prog: () => [meta.adTotal || 0, 10] },
  { id: "ad100",     grp: "养成", name: "广告金主", desc: "看广告累计 100 次", gold: 800, prog: () => [meta.adTotal || 0, 100] },
  // —— 奇趣：玩出来的花活 ——
  { id: "star5",     grp: "奇趣", name: "五星上将", desc: "把一个武将练到 5★", gold: 200 },
  { id: "fullhouse", grp: "奇趣", name: "满编出击", desc: "同时11人在场（要先炸石头）", gold: 250 },
  { id: "tactic10",  grp: "奇趣", name: "运筹帷幄", desc: "一局放 10 次主公技", gold: 200 },
  { id: "ult15",     grp: "奇趣", name: "怒不可遏", desc: "一局放 15 次大招", gold: 200 },
  { id: "relic5",    grp: "奇趣", name: "藏宝将军", desc: "一局攒齐 5 件宝贝", gold: 250 },
  { id: "ironwall",  grp: "奇趣", name: "固若金汤", desc: "第 10 波打完城墙满血", gold: 300 },
  { id: "seal",      grp: "奇趣", name: "破除妖法", desc: "杀 1 个妖术师", gold: 150 },
  { id: "dragon1",   grp: "奇趣", name: "真龙天子", desc: "孵出头一条应龙", gold: 500 },
  { id: "dragon2",   grp: "奇趣", name: "双龙戏珠", desc: "一局孵出两条应龙", gold: 1000 },
  { id: "granary40", grp: "奇趣", name: "屯田大户", desc: "一局里屯田喂出五颗星", gold: 400 },
  { id: "swap10",    grp: "奇趣", name: "如鱼得水", desc: "头一次在局内触发羁绊", gold: 200 },
  { id: "rebirth1",  grp: "奇趣", name: "浴火重生", desc: "头一次让五星武将转生", gold: 300 },
  { id: "maxhit5k",  grp: "奇趣", name: "力拔山兮", desc: "一击打出 5000 伤害", gold: 400 },
  { id: "goldrun2k", grp: "奇趣", name: "盆满钵满", desc: "一局赚 2000 金币", gold: 300 },
  { id: "seppuku3",  grp: "奇趣", name: "无颜见江东", desc: "自刎归天 3 次", gold: 2000, prog: () => [meta.seppukuN || 0, 3] },
  { id: "dance5",    grp: "奇趣", name: "此间乐", desc: "乐不思蜀 5 次", gold: 2000, prog: () => [meta.danceN || 0, 5] },
];
const ACH_GRPS = ["战功", "讨伐", "养成", "奇趣"];
/* 计数成就统一巡检：数到了就解锁（事件成就靠打点处 unlockAch） */
function achSweep() {
  for (const a of ACHS) {
    if (!a.prog || meta.ach.includes(a.id)) continue;
    const [cur, need] = a.prog();
    if (cur >= need) unlockAch(a.id);
  }
}
function achClaimableCount() {
  return meta.ach.filter(id => !(meta.achClaimed || []).includes(id)).length;
}
function unlockAch(id) {
  if (meta.ach.includes(id)) return;
  const a = ACHS.find(x => x.id === id);
  if (!a) return;
  meta.ach.push(id);
  saveMeta();
  SFX.ach();
  addFloater(W / 2, 300, `🏆「${a.name}」达成！${a.gold}💰待领`, "#ffd24a", 21);
  shake = Math.max(shake, 0.3);
}

/* 精英词缀 */
const AFFIXES = {
  shield: { icon: "🛡️", name: "铁盾" },   // 附加护盾条，先破盾再掉血
  split:  { icon: "🧬", name: "分裂" },   // 死亡分裂两只小兵
  frenzy: { icon: "😤", name: "狂暴" },   // 血量低于40%加速60%
  regen:  { icon: "💚", name: "回春" },   // 每秒回2%最大生命
};

/* 遗物（击败贼首掉落，三选一，全局被动） */
const RELICS = [
  { id: "qinggang", icon: "🗡️", name: "青釭剑",   desc: "双倍暴击变三倍暴击" },
  { id: "longxian", icon: "🐲", name: "龙涎香",   desc: "孵化成功率+20%",
    need: () => allUnits().some(u => u.type.cls === "egg") },
  { id: "dilu",     icon: "🐴", name: "的卢马",   desc: "骑兵伤害+30%" },
  { id: "shemao",   icon: "🐍", name: "铁脊蛇矛", desc: "枪兵20%几率推开敌人" },
  { id: "lianhuan", icon: "⛓️", name: "连环铠",   desc: "城墙每次少扣1血" },
  { id: "jiuhu",    icon: "🍶", name: "酒葫芦",   desc: "武将大招伤害+50%" },
  { id: "yuxi",     icon: "💎", name: "传国玉玺", desc: "金币翻倍" },
  { id: "mengde",   icon: "📕", name: "孟德新书", desc: "武将大招转快28%" },   // 和孙子兵法(主公号令)是两套CD，文案说死防混淆
  { id: "qixing",   icon: "🕯️", name: "七星灯",   desc: "城墙每30秒回1血" },
  { id: "sunzi",    icon: "📘", name: "孙子兵法", desc: "主公号令转快25%" },
  { id: "yiji",     icon: "🎁", name: "遗计锦囊", desc: "选牌三张变四张" },
  { id: "bagua",    icon: "☯️", name: "八卦阵图", desc: "全军出手快+10%" },
  { id: "yushan",   icon: "🪶", name: "白羽扇",   desc: "羽扇轻摇：主公号令冷却-15%，亲射出手快25%" },   // v7.15.3 重做：原来和八卦阵图撞了（天时退役的遗留），改走主公轴
  { id: "guding",   icon: "⚔️", name: "古锭刀",   desc: "打大怪更疼+25%" },
  { id: "hanshu",   icon: "📗", name: "汉书残卷", desc: "升级更快12%" },
  { id: "tongque",  icon: "🏛️", name: "铜雀香炉", desc: "凶险突变提前两波预警，那一波金币+50%" },
  { id: "liannu",   icon: "🏹", name: "元戎连弩", desc: "攻击多穿一个人" },
  { id: "baihu",    icon: "🐯", name: "白虎兵符", desc: "每波第一下必双倍暴击" },
  /* —— 机制遗宝：带 need 的只在阵中有对应武将/兵种时才进池（rollRelics 过滤，防废卡） —— */
  { id: "jiguan",  icon: "⚙️", name: "机关图谱", who: "魏延/月英", desc: "魏延多埋2雷，炮台多撑3秒",
    need: () => ownsGeneral("weiyan") || ownsGeneral("huangyueying") },
  { id: "huoyou",  icon: "🛢️", name: "火油车", who: "带点火的武将",   desc: "烧着的贼掉血更快(+50%)，火堆多烧2秒",
    need: () => allUnits().some(u => u.type.burn || u.type.id === "huanggai") },
  { id: "xuantie", icon: "🔗", name: "玄铁锁链", who: "诸葛亮", desc: "诸葛亮多锁2只，掉血更狠",
    need: () => ownsGeneral("zhugeliang") },
  { id: "chensha", icon: "⚓", name: "沉沙折戟", who: "貂蝉", desc: "贼技封更久，被封的多挨打",
    need: () => ownsGeneral("diaochan") || ownsGeneral("zhangliao") },   // v7.0 监军令随马腾退役：沉默源=貂蝉/张辽
  { id: "madeng",  icon: "🏇", name: "马镫", who: "骑兵",     desc: "骑兵撞人飞更远，多顶一会",
    need: () => state.team.count.cav >= 1 },
  { id: "jili",    icon: "🌵", name: "蒺藜骨朵", who: "许褚/徐晃", desc: "拒马撑更久，挡住的人掉血",
    need: () => ownsGeneral("xuchu") || ownsGeneral("xuhuang") },
  { id: "dujing",  icon: "☠️", name: "毒经", who: "兀突骨",     desc: "兀突骨的毒雾更毒一半",
    need: () => ownsGeneral("wutugu") },
  { id: "jiaowei", icon: "🎵", name: "焦尾琴", who: "蔡文姬/大乔",   desc: "催眠和冻慢多撑30%",
    need: () => ownsGeneral("caiwenji") || ownsGeneral("daqiao") },
  /* —— 2026-07-08 新机制放大器：徐庶卸抗/羁绊/转生/盾兵保护线 —— */
  { id: "shuijingshu", icon: "📜", name: "水镜遗书", who: "徐庶", desc: "徐庶卸抗多撑近一倍时间",
    need: () => ownsGeneral("xushu") },
  { id: "jinlan",  icon: "🤝", name: "金兰谱", who: "羁绊流",   desc: "生效中的羁绊效果多五成",
    need: () => !!state.bondSet?.size },
  { id: "fenghuang", icon: "🦚", name: "凤凰翎", who: "高星将", desc: "升华星更猛：一阶1.4→1.5倍、二阶1.3→1.4倍",
    need: () => allUnits().some(u => u.level >= 5 && ULTS[u.type.id]) },
  { id: "hufu",    icon: "🛡️", name: "护主盾符", who: "盾兵", desc: "盾护更厚，盾墙挡得更多",
    need: () => state.team.count.shield >= 1 },
];

/* 地利战场（开局随机一种，横幅告知；全局地形机制） */
const FIELDS = [
  { id: "hulao",    icon: "🏔️", name: "虎牢雄关", narrow: true, wallAdd: 5,
    desc: "城墙+5｜敌人挤中路 好群伤" },
  { id: "chibi",    icon: "🌊", name: "赤壁水岸", burnMul: 1.5,
    band: { y1: 360, y2: 425, type: "water", slow: 0.6 },
    desc: "敌人过江慢40%｜火烧+50%" },
  { id: "guandu",   icon: "🌾", name: "官渡粮道", xpMul: 1.15, goldMul: 1.5,
    desc: "杀敌经验+15%｜金币+50%" },
  { id: "changban", icon: "🐎", name: "长坂坡",   spdMul: 1.12, xpMul: 1.35,
    desc: "敌人跑快12%｜杀敌经验+35%" },
  { id: "nizhao",   icon: "🥾", name: "泥沼洼地", hpMul: 1.1,
    band: { y1: 395, y2: 470, type: "mud", slow: 0.55 },
    desc: "敌人陷泥慢45%｜敌人血+10%" },
  { id: "fengsui",  icon: "🗼", name: "烽燧高地", tower: true,
    desc: "烽火台自动放箭帮你守城" },
  /* —— 2026-07-05 扩充：地形随机化后池子加深，摊上哪个都有得玩 —— */
  { id: "gaodi",    icon: "🏹", name: "高地平原", archerRng: 1.1, archerMul: 1.4, tip: "多带弓",
    desc: "站得高看得远｜弓伤+40% 射程+10%" },
  { id: "zhulin",   icon: "🎋", name: "竹林小道", cavMul: 1.5, tip: "多带骑",
    desc: "林间道好冲锋｜骑兵伤害+50%" },
  { id: "huoshan",  icon: "🌋", name: "火山口",   volcano: 20,
    desc: "每20秒喷一回火｜烧一片还点燃" },
  { id: "xueyuan",  icon: "❄️", name: "冰封雪原", spdMul: 0.88,
    desc: "天寒地冻｜敌人全程跑慢12%" },
  { id: "gunshi",   icon: "🪨", name: "滚石坡",   boulder: 18,
    desc: "每18秒滚下巨石｜碾穿人最多的一列" },
];

/* —— 讨贼战役：8章×8关=64关，强度平滑上涨，逐关解锁；首通发大赏 —— */
const CHAPTERS = [
  { name: "蛾贼初起", icon: "🌾", color: "#6fd44e", boss: "程远志" },
  { name: "颍川烽火", icon: "🔥", color: "#e8a84a", boss: "波才" },
  { name: "汝南剿匪", icon: "🏹", color: "#e8c86a", boss: "何仪" },
  { name: "广宗鏖兵", icon: "⚔️", color: "#ff8a5a", boss: "张梁" },
  { name: "曲阳血战", icon: "🌀", color: "#c96aff", boss: "张宝" },
  { name: "冀州决战", icon: "⚡", color: "#ff5a3a", boss: "张角" },
  { name: "余孽复燃", icon: "💀", color: "#8fb8e8", boss: "郭太" },
  { name: "修罗炼狱", icon: "🔮", color: "#ff4a8a", boss: "张角·天公化神" },
];
const BOSS_KITS = ["summon", "firepot", "volley", "split", "sealwave", "thunder", "affixlord", "avatar"];   // 各章贼首绝活
const LEVEL_NAMES = [
  ["村口小患", "烧粮草的", "官道劫匪", "夜袭粮仓", "流寇聚啸", "围堵驿站", "贼势渐成", "决战·程远志"],
  ["火起颍川", "风助火势", "焦土行军", "断桥阻敌", "火海余生", "烈焰围城", "火烧连营", "决战·波才"],
  ["山道伏兵", "弓贼四起", "飞石如雨", "巫医作祟", "旗手督战", "泥沼设伏", "群匪会盟", "决战·何仪"],
  ["人海初现", "前仆后继", "尸山血海", "越杀越多", "精锐压阵", "车轮鏖战", "十面埋伏", "决战·张梁"],
  ["妖风骤起", "封印之阵", "咒术连绵", "雪夜苦战", "妖法护体", "巫祝倾巢", "血染曲阳", "决战·张宝"],
  ["大军压境", "精锐尽出", "雷声隐隐", "黑云压城", "死战不退", "背水一战", "兵临城下", "决战·张角"],
  ["死灰复燃", "铁盾成墙", "狂暴之血", "裂而再生", "回春妖体", "词缀成灾", "白波再起", "决战·郭太"],
  ["修罗入门", "无间行军", "炼狱火海", "万军丛中", "天崩地裂", "有去无回", "最后一搏", "天公化神"],
];
/* 每关固定地形（按章节主题分配，点将台上可针对性换将） */
const CH_FIELDS = [
  ["guandu", "gaodi", "zhulin", "guandu", "hulao", "gaodi", "xueyuan", "hulao"],
  ["huoshan", "chibi", "huoshan", "changban", "chibi", "huoshan", "chibi", "huoshan"],
  ["nizhao", "gaodi", "gunshi", "fengsui", "changban", "nizhao", "gunshi", "fengsui"],
  ["hulao", "zhulin", "changban", "hulao", "gunshi", "zhulin", "changban", "hulao"],
  ["xueyuan", "fengsui", "nizhao", "xueyuan", "chibi", "fengsui", "xueyuan", "nizhao"],
  ["gaodi", "huoshan", "gunshi", "changban", "hulao", "guandu", "chibi", "hulao"],
  ["zhulin", "nizhao", "gunshi", "fengsui", "changban", "xueyuan", "huoshan", "gaodi"],
  ["huoshan", "gunshi", "changban", "chibi", "nizhao", "fengsui", "xueyuan", "hulao"],
];
/* —— 关卡敌情：每关固定"抗2系+怕1系"（2026-07-05 反最优解轮：属性从每波乱摇改成关卡的题面，
   选将/淬炼/换阵容才有关前意义）。r1=章的身份整章不变，r2s/ws=副抗和怕系的轮替池。
   排池铁律（防死局，改前先跑 /tmp/sanguo-elem-pool-model.js 巡检）：
   ①前两章怕系只出初始将打得出的 冰/雷/物理；②抗性对不许把初始输出打剩不到4人——物理绝不和冰/雷同关做抗性；
   ③五系出场公平：抗∈[15,33]关、怕∈[9,17]关（2026-07-06 诸葛亮吃瘪轮：旧池毒被抗41关/被怕4关、
   火40/6、物理8/26——毒火武将常年坐板凳；重排后 毒32/13 火27/10 物17/15 冰23/14 雷29/12） —— */
/* 题面（v6.0 三角克制）：每州一个主属性轮转——三系每周各占5~6州。
   贼85%是主属性、15%杂色（防单一克制队全程躺）；玩家带"克主属性"的那一系=对症。 */
const TRI_KEYS = ["badao", "liangmou", "rende"];
function levelFoes(i) {
  return { tri: TRI_KEYS[((i % 8) + Math.floor(i / 8)) % 3] };
}
/* 特殊规则：叠在强度曲线上，给关卡加"题面"；tip=开局横幅上的大白话 */
const LEVEL_RULE_DEFS = {
  twinBoss: { short: "双贼首",  tip: "贼首带着影子一起上", apply: lv => { lv.eliteWave = true; } },
  rush:     { short: "急行军",  tip: "敌人跑得更快", apply: lv => { lv.spdMul = +(lv.spdMul * 1.08).toFixed(2); } },
  ruin:     { short: "城防失修", tip: "城墙比平时矮", apply: lv => { lv.wall = Math.max(3, lv.wall - 2); } },
  rich:     { short: "缴获丰厚", tip: "金币掉得多", apply: lv => { lv.goldMul = +(lv.goldMul * 1.5).toFixed(2); } },
  rocks:    { short: "乱石密布", tip: "石头障碍更多", apply: lv => { lv.obstacles = Math.min(9, lv.obstacles + 2); } },   // 上限9=每行留2空的可堵极限
  elite:    { short: "精锐云集", tip: "精锐词缀更多", apply: lv => { lv.affixAdd = +(lv.affixAdd + 0.15).toFixed(2); } },
  /* —— 换打法型规则（2026-07-05 反最优解轮）：打折不清零，逼你换阵不逼你死 —— */
  smoke:    { short: "烟瘴弥漫", tip: "烟大看不远，弓兵射程-35%", apply: lv => { lv.archerRngMul = 0.65; } },
  mud:      { short: "泥沼遍地", tip: "泥深马难行，骑兵冲锋只有一半远", apply: lv => { lv.cavChargeMul = 0.55; } },
  crossbow: { short: "连弩贼",   tip: "弓贼投石兵成倍地来，护住武将", apply: lv => { lv.rangedMul = 2.2; } },
};
const LEVEL_RULES = {
  9: ["smoke"],
  10: ["rush"], 12: ["rich"], 13: ["smoke"], 14: ["rocks"],
  17: ["crossbow"], 18: ["elite"], 19: ["crossbow"], 20: ["rush"], 21: ["mud"], 22: ["ruin"],
  25: ["mud"], 26: ["rich"], 27: ["crossbow"], 28: ["elite"], 29: ["smoke"], 30: ["rush"],
  33: ["ruin"], 34: ["smoke"], 35: ["elite"], 37: ["mud"], 38: ["rich"],
  41: ["rocks"], 42: ["crossbow"], 43: ["elite"], 44: ["mud"], 45: ["rush", "ruin"], 46: ["smoke"], 47: ["elite"],
  49: ["elite", "rush"], 50: ["crossbow"], 51: ["ruin"], 52: ["mud"], 53: ["rocks", "elite"], 54: ["smoke"], 55: ["twinBoss"],
  56: ["crossbow"], 57: ["rush", "elite"], 58: ["ruin", "rocks"], 59: ["twinBoss"],
  60: ["elite", "rush"], 61: ["twinBoss", "ruin"], 62: ["rush", "rocks", "elite"], 63: ["twinBoss", "elite"],
};
function makeLevel(i) {
  const ch = Math.floor(i / 8), n = i % 8;
  const t = i / 63;                 // 0→1 全程进度
  const boss = n === 7;             // 章尾=决战关
  const lv = {
    key: "lv" + i, idx: i, ch, n,
    name: `${ch + 1}-${n + 1} ${LEVEL_NAMES[ch][n]}`,
    tag: `${ch + 1}-${n + 1}`,   // 顶栏短徽章，全名太长会和击破进度条重叠
    icon: CHAPTERS[ch].icon, color: CHAPTERS[ch].color,
    hpMul: +(0.95 * Math.pow(6.0 / 0.95, t) * (boss ? 1.1 : 1)).toFixed(2),   // 压力重构轮：下限0.7→0.95（前期不再无伤平推）、上限2.95→6.0（顶层台阶要毕业号+对症才啃得动），配合抗性全覆盖用压力模拟器校准
    spdMul: +(0.92 + 0.40 * Math.pow(t, 1.25)).toFixed(2),
    hpGrow: +(1.16 + 0.085 * t).toFixed(3),
    affixAdd: +(-0.08 + 0.53 * Math.pow(t, 1.15)).toFixed(2),
    wall: Math.max(10, 15 - Math.round(10 * t)),   // v7.14.1 下限5→10：深关两口锤车就见底，容错太少
    obstacles: Math.min(7, 4 + Math.floor(4 * t)),   // v7.14.3 降密度6→11改4→7：开局站位要有得选
    killTarget: Math.round((400 + 600 * t) / 50) * 50,
    goldMul: +(0.6 + 2.9 * Math.pow(t, 1.3)).toFixed(2),
    field: CH_FIELDS[ch][n],
    firstGold: Math.round((180 + 1620 * Math.pow(t, 1.35)) / 10) * 10,   // 首通大赏
    bossName: boss ? CHAPTERS[ch].boss : null,
    bossKit: boss ? BOSS_KITS[ch] : null,
    eliteWave: false,
    rules: LEVEL_RULES[i] || [],
    foes: levelFoes(i),   // 敌情（v6.0）：{ tri: 主属性 }——关卡的"题面"，带克它的那系=对症
  };
  for (const r of lv.rules) LEVEL_RULE_DEFS[r].apply(lv);
  const ruleTxt = lv.rules.map(r => LEVEL_RULE_DEFS[r].short).join("·");
  lv.desc = `敌血×${lv.hpMul} · 杀${lv.killTarget}${ruleTxt ? " · " + ruleTxt : ""}`;
  return lv;
}
const LEVELS = Array.from({ length: 64 }, (_, i) => makeLevel(i));
/* 进度前沿（老64关战役口径，只给旧榜摘要兼容用）：第一个还没通关的关 */
function frontierLevel() {
  let i = 0;
  while (i < LEVELS.length - 1 && meta.levelClears[i]) i++;
  return i;
}
/* 战役总星数：每关三星（赢1星/城墙无伤1星/无人阵亡1星）取历史最高——战役榜的排名依据 */
function totalStars() {
  let s = 0;
  for (const k of Object.keys(meta.levelStars || {})) s += meta.levelStars[k];
  return s;
}

/* —— 赛季周关卡（2026-07-06 Phase2）：每周16个州郡，日期做种子全服同图。
   不从64关里简单抽：难度走死梯子 t=(3+4k)/63——每周上限下限一模一样、台阶差距拉满；
   周与周只换题面：8个章节主题每周洗牌（每章1平关+1决战）、敌情从该章已巡检的轮替池抽、
   地形袋装11种全出（最多重复2次）、规则袋装每种最多3关、五系每周至少2关主场。
   巡检模型 /tmp/sanguo-week16-model.js（400周断言全过），改参数先跑模型 —— */
function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function localDays() { return Math.floor((Date.now() - new Date().getTimezoneOffset() * 60000) / 86400000); }
const WEEK0 = 2948;   // 2026-07 上线那周＝第1期
function trialWeekNow() { return Math.floor((localDays() + 3) / 7); }   // 周一换图（1970-01-01是周四）
function dayKeyNow() { return localDays(); }
const WEEK_N = 64;   // v7.11 天下争夺：32→64城，东/南/西/北四区选项卡各16城（v7.2.0 的上下篇扩成四区）
const STATE_NAMES = ["交州", "益州", "扬州", "荆州", "凉州", "徐州", "豫州", "兖州",
  "青州", "司隶", "雍州", "并州", "幽州", "常山", "巨鹿", "广宗",
  // 南部（原下篇 v7.2.0）：破了黄巾老巢广宗，挥师直取京师——一路打到洛阳
  "陈留", "颍川", "南阳", "汝南", "官渡", "白马", "延津", "邺城",
  "晋阳", "上党", "河东", "函谷", "潼关", "华阴", "长安", "洛阳",
  // 西部（v7.11）：出散关定西凉、下汉中、入巴蜀——西征之路
  "陈仓", "街亭", "天水", "冀城", "祁山", "武都", "阳平关", "定军山",
  "汉中", "葭萌", "剑阁", "涪城", "绵竹", "雒城", "成都", "江州",
  // 北部（v7.11）：渡河北上平幽燕、出卢龙塞远征塞外——北伐之路
  "黎阳", "邯郸", "信都", "南皮", "平原", "易京", "涿郡", "蓟县",
  "渔阳", "右北平", "卢龙塞", "柳城", "白狼山", "襄平", "乐浪", "单于庭"];
const WEEK_RULE_POOL = ["smoke", "mud", "crossbow", "rush", "elite", "ruin", "rocks", "twinBoss"];
const WEEK_WEAK_MIN = 2;      // 每系每周至少2关吃香
const WEEK_TWIN_MIN_K = 10;   // 双贼首只出高台阶
function weekRulesN(k) { return k < 2 ? 0 : k < 8 ? 1 : k < 14 ? 1 + (k % 2) : k < 24 ? 2 : k < 48 ? 2 + (k % 2) : 3; }   // 西部尾段最多3条，北部恒3条
function shuffledBy(rng, arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
var _weekSlots = { week: -1, slots: null };   // var：rolloverWeek 在存档规整时就会摸它，得先有身子
function makeWeekSlots(week) {
  if (_weekSlots.week === week) return _weekSlots.slots;
  // 前32城（东/南）严格复刻 v7.2.0 的 rng 消耗顺序——v7.11 落在周中，老玩家本周题面一个字不能变
  const rng = mulberry32(Math.imul(week, 2654435761) ^ 987654321);
  const chOrder = shuffledBy(rng, [0, 1, 2, 3, 4, 5, 6, 7]);        // 东部章序
  const chOrder2 = shuffledBy(rng, [0, 1, 2, 3, 4, 5, 6, 7]);       // 南部章序（独立洗牌）
  const fieldIds = FIELDS.map(f => f.id);
  const fieldBag = shuffledBy(rng, [...fieldIds, ...fieldIds, ...shuffledBy(rng, fieldIds).slice(0, 32 - fieldIds.length * 2)]);   // 11地形×3=33 取32，每种≤3
  const ruleBag = shuffledBy(rng, WEEK_RULE_POOL.flatMap(r => [r, r, r, r, r, r]));
  const triBag = shuffledBy(rng, [...Array(30)].map((_, i) => i % 3).concat([Math.floor(rng() * 3), Math.floor(rng() * 3)]));   // 三系各≥10城
  // 西/北两区（v7.11 扩张）走独立种子的新 rng 流，与前32城互不干扰
  const rng2 = mulberry32(Math.imul(week, 1597334677) ^ 123456789);
  const chOrder3 = shuffledBy(rng2, [0, 1, 2, 3, 4, 5, 6, 7]);      // 西部章序
  const chOrder4 = shuffledBy(rng2, [0, 1, 2, 3, 4, 5, 6, 7]);      // 北部章序
  const fieldBag2 = shuffledBy(rng2, [...fieldIds, ...fieldIds, ...shuffledBy(rng2, fieldIds).slice(0, 32 - fieldIds.length * 2)]);
  const ruleBag2 = shuffledBy(rng2, WEEK_RULE_POOL.flatMap(r => Array(11).fill(r)));   // 西北需求≈88条，8种×11=88
  const triBag2 = shuffledBy(rng2, [...Array(30)].map((_, i) => i % 3).concat([Math.floor(rng2() * 3), Math.floor(rng2() * 3)]));
  const chOrders = [chOrder, chOrder2, chOrder3, chOrder4];
  const slots = [];
  for (let k = 0; k < WEEK_N; k++) {
    const west = k >= 32;   // 西/北用第二套袋子，袋内下标回到 0
    const bagK = west ? k - 32 : k, rb = west ? ruleBag2 : ruleBag;
    const ch = chOrders[Math.floor(k / 16)][Math.floor((k % 16) / 2)];
    const rules = [];
    for (let n = 0; n < weekRulesN(k); n++) {
      const idx = rb.findIndex(r => !rules.includes(r) && (r !== "twinBoss" || k >= WEEK_TWIN_MIN_K));
      if (idx < 0) break;
      rules.push(rb.splice(idx, 1)[0]);
    }
    slots.push({ k, ch, tri: TRI_KEYS[(west ? triBag2 : triBag)[bagK]], field: (west ? fieldBag2 : fieldBag)[bagK], rules });   // v6.0：题面=三角主属性
  }
  _weekSlots = { week, slots };
  return slots;
}
/* 州郡关：台阶k的题面来自本周槽位；敌血曲线独立于64关口径（升级驱动轮）——
   前陡后缓：k5≈×3掐住裸号、k10≈×6.5、k15≈×12留给毕业号+对症，账号每一档往前推4~5州，
   改曲线/成长先跑 tests/pressure-sim.js 的 ladder 模式验收 */
/* —— 周主题（2026-07-08 留存轮方向1+4）：每周一条全局军略，周种子轮换——
   既改解法（逼玩家重新构筑，治"背答案"）又给赛季风味。有好有坏，不是纯buff/纯debuff。
   第1期固定「众志成城」（温和正向）当新手起点 —— */
const WEEK_THEMES = [
  { id: "tuanjie",  icon: "🎐", name: "众志成城", short: "羁绊效果多三成", desc: "羁绊效果多三成——多凑几对搭子", fav: "羁绊流" },
  { id: "liaoyuan", icon: "🔥", name: "燎原之势", short: "贼快·带火烧他", desc: "着火烧得凶、贼也跑得快——带火/点燃抢在到城前烧死", fav: "火/点燃流" },
  { id: "jiancheng", icon: "🛡️", name: "坚城拒守", short: "贼厚·拼持久输出", desc: "贼血厚得多、走得慢——没持久输出磨不穿", fav: "持久AOE" },
  { id: "jifeng",   icon: "⚡", name: "疾风迅雷", short: "贼飞快·靠控场拦", desc: "贼跑得飞快但血薄——没控场/近战墙就漏怪压城", fav: "控制/近战" },
  { id: "yunchou",  icon: "📜", name: "运筹帷幄", short: "特种多·勤放主公技", desc: "主公技转更快，但贼里特种更多", fav: "主公流" },
];
function weekThemeOf(week, region = 0) {
  // v7.2.0 双主题→v7.11 四区四主题：东/南沿用旧公式（周中部署不换题），西/北从剩下三条里按周种子抽，四区互不相同
  const i0 = week === WEEK0 ? 0 : Math.floor(mulberry32(week * 131 + 7)() * WEEK_THEMES.length);
  if (!region) return WEEK_THEMES[i0];
  const shift = 1 + Math.floor(mulberry32(week * 613 + 29)() * (WEEK_THEMES.length - 1));
  const i1 = (i0 + shift) % WEEK_THEMES.length;
  if (region === 1) return WEEK_THEMES[i1];
  const rest = [0, 1, 2, 3, 4].filter(i => i !== i0 && i !== i1);
  const order = shuffledBy(mulberry32(week * 977 + 53), rest);
  return WEEK_THEMES[order[region - 2]];
}
function makeWeekLevel(week, k) {
  const s = makeWeekSlots(week)[k];
  // v7.2.0 南部（k16~31）：战场参数钉在k15水位（tC），敌血继续爬（×1.09/城）、奖励温和放大
  // v7.11 西部（k32~47）×1.05/城、北部（k48~63）×1.025/城——放缓依据：英雄成长硬顶3转60级（满命=5.72×裸号），
  //   sim校准真人天花板≈敌血×170（lv60 sim过k23、真人均级10.5清k31→操作系数≈6.5×），k63≈154 压线：
  //   满命+顶级手操才摸得到北境尽头，方向A"从刷不通到刷通"留了均级10→60的赛季跑道，尾段永远是墙
  const tRaw = (3 + 4 * k) / 63, boss = k % 2 === 1;
  const tC = Math.min(1, tRaw), kx = Math.min(16, Math.max(0, k - 15)), kw = Math.max(0, k - 31);   // kx=南部深度(封顶16) kw=西北深度
  const hpBase = (k <= 15 ? 0.95 * Math.pow(12.0 / 0.95, Math.pow(k / 15, 0.72))
    : k <= 31 ? 12.0 * Math.pow(1.09, k - 15)
    : k <= 47 ? 47.66 * Math.pow(1.05, k - 31)
    : 104.0 * Math.pow(1.025, k - 47))
    * (k === 8 ? 1.1 : 1);   // 州8口袋收紧（v7.11 实测通关率98%+全图最深均无尽23波——性价比洼地会被Top10口径精准嗅出，对齐邻居；巡检指标=无尽深度离群值）
  const lv = {
    key: `w${week}k${k}`, idx: -1, lvIdx: Math.min(63, 3 + 4 * k), week, k, ch: s.ch, n: boss ? 7 : 3,   // lvIdx=64关口径的进度当量（特种兵闸门用）
    name: `${STATE_NAMES[k]} · ${CHAPTERS[s.ch].name}`, tag: STATE_NAMES[k],
    icon: CHAPTERS[s.ch].icon, color: CHAPTERS[s.ch].color,
    hpMul: +(hpBase * (boss ? 1.1 : 1)).toFixed(2),
    spdMul: +(0.92 + 0.40 * Math.pow(tC, 1.25)).toFixed(2),
    hpGrow: +(1.16 + 0.085 * tC).toFixed(3),
    affixAdd: +(-0.08 + 0.53 * Math.pow(tC, 1.15)).toFixed(2),
    wall: Math.max(10, 15 - Math.round(10 * tC)),   // v7.14.1 下限5→10（同 LEVELS 口径）
    obstacles: Math.min(7, 4 + Math.floor(4 * tC)),   // v7.14.3 降密度（同 LEVELS 口径）
    killTarget: Math.round((400 + 600 * tC) / 50) * 50 + kx * 50 + kw * 25,
    goldMul: +(0.6 + 2.9 * Math.pow(tC, 1.3) + kx * 0.12 + kw * 0.06).toFixed(2),
    firstGold: Math.round((180 + 1620 * Math.pow(tC, 1.35)) / 10) * 10 + kx * 90 + kw * 45,   // 首通大赏每周重置＝周薪基本盘；南部+90/城、西北+45/城（半斜率控通胀）严格递增
    field: s.field,
    bossName: boss ? CHAPTERS[s.ch].boss : null,
    bossKit: boss ? BOSS_KITS[s.ch] : null,
    eliteWave: false, rules: [...s.rules],
    foes: { tri: s.tri },   // v6.0 三角题面
  };
  for (const r of lv.rules) LEVEL_RULE_DEFS[r].apply(lv);
  // 周主题：数值类当场叠进 lv，行为类（羁绊/主公CD/特种率/燃烧）留给 state.weekTheme 各处读
  // v4.19.0 基本盘加码：放大战场倾斜，逼不适配的通用队换构筑（v7.11 起四区各一条主题）
  const th = weekThemeOf(week, Math.floor(k / 16));
  lv.theme = th.id;
  if (th.id === "liaoyuan") lv.spdMul = +(lv.spdMul * 1.15).toFixed(2);   // 燎原：敌更快，火/点燃靠burn×1.5抢在到城前烧死
  else if (th.id === "jiancheng") { lv.hpMul = +(lv.hpMul * 1.22).toFixed(2); lv.spdMul = +(lv.spdMul * 0.75).toFixed(2); }   // 坚城：更厚，逼持久高DPS磨（v7.7 崩盘率57%回调 1.32→1.22）
  else if (th.id === "jifeng") { lv.hpMul = +(lv.hpMul * 0.85).toFixed(2); lv.spdMul = +(lv.spdMul * 1.48).toFixed(2); }   // 疾风：更快，逼控场/近战墙拦
  const ruleTxt = lv.rules.map(r => LEVEL_RULE_DEFS[r].short).join("·");
  lv.desc = `敌血×${lv.hpMul} · 杀${lv.killTarget}${ruleTxt ? " · " + ruleTxt : ""}`;
  return lv;
}
/* —— 神将（v4.21.0 拉动非典型武将；v4.22.0 提速到半周轮换）：每周一、周四各换一批，
   每批从全图鉴随机点6人封神（期种子、全服一致、与上一批不重复）——每周12人有高光。
   名字冠"神"，攻血加成走等级乘区：基础×1.25 且 每级8%→16%翻倍——等级越高神将越猛，
   逼玩家宽养非主流将（纯固定数值拉不动升级，挂等级上才有养成动机）。
   榜单/结算仍按整周走，神将只是新鲜感层提速（用户拍板的中间路线，不动经济不伤周末玩家） —— */
const SHEN_N = 6;
const SHEN_BASE = 1.25, SHEN_LV_BONUS = 0.16;
/* 神将技·天命加身（v4.24.0）：弱卡封神登场补星（品质越低补越多），白/绿神将大招开局就绪。
   补偿逻辑：等级乘区的翻倍对"本来就优先培养的强卡"放大更多，弱卡神将吃不到——
   把补偿做在与投资无关的登场轴上，冷门白绿卡封神当周即有"高投资待遇"的即战力 */
const SHEN_GIFT_STARS = { common: 3, uncommon: 2, rare: 1, epic: 0 };
const SHEN_P0 = WEEK0 * 2;   // 第1期上线那周的前半周
/* 当前神将期：周一0点、周四0点翻篇——每周两期（前半周一~三 / 后半周四~日） */
function shenPeriodNow() {
  const d = localDays() + 3;   // +3 对齐周一（1970-01-01是周四）
  return Math.floor(d / 7) * 2 + (d % 7 >= 3 ? 1 : 0);
}
/* 下次换将：给界面报"哪天换、还剩几天"，规则明示不让玩家猜 */
function shenNextInfo() {
  const dow = (localDays() + 3) % 7;   // 0=周一
  return dow < 3 ? { day: "周四", left: 3 - dow } : { day: "周一", left: 7 - dow };
}
var _shenCache = {};   // { period: [id×6] }
function shenIdsOf(p) {
  if (!p || p < SHEN_P0) return [];
  if (_shenCache[p]) return _shenCache[p];
  let prev = [];
  for (let w = SHEN_P0; w <= p; w++) {
    if (_shenCache[w]) { prev = _shenCache[w]; continue; }
    const pset = new Set(prev);   // 与上一批不重复：本期洗牌后跳过上批6人再取前6
    const order = shuffledBy(mulberry32(Math.imul(w, 668265263) ^ 20260708), GENERALS.map(g => g.id));
    _shenCache[w] = prev = order.filter(id => !pset.has(id)).slice(0, SHEN_N);
  }
  return _shenCache[p];
}
/* 生效的期：对局中（含结算页）以开打时锁定的 state.shenP 为准——打到一半跨周一/周四不换人；
   回到首页/地图就读实时期，翻篇立刻见新批 */
function isShen(id) {
  const inRun = typeof state !== "undefined" && state && state.shenP != null
    && ["pickLord", "pickStart", "play", "over", "win"].includes(state.phase);
  return shenIdsOf(inRun ? state.shenP : shenPeriodNow()).includes(id);
}
function shenName(id, name) { return isShen(id) ? "神·" + name : name; }
/* —— 势力值计分（v7.11 天下争夺）：城池贡献 = 繁荣度×威望 ×(1+0.25×讨伐波)。
   势力值 = Σ全部已破城[繁荣度×威望] + 十大功绩(讨伐值Top10)——
   进度项全量入账（纵刷即时反馈），无界的讨伐值只取10城（肝面积封顶：
   "每座城都伺候一遍无尽"不再是最优，肝帝和普通人优化的是同一块地）。
   防"全通后蹲简单城刷讨伐"的承重墙是造波处的无尽增压1.18复利（见 RAMP 注释），别在这找 —— */
// WEEK_STAR_MUL / WEEK_ENDLESS_PER / TAOFA_TOP_N 定义挪到了文件头 GAME_VERSION 旁——
// rolloverWeek 在存档规整（页面加载）时就会调 weekScoreOf，const 放这里会 TDZ 白屏
const WEEK_BANDS = [                                 // 分数段奖：打到就发，当场落袋（v7.2.0 下篇16州加两档）
  { at: 2000, gold: 500 }, { at: 6000, gold: 1200 },
  { at: 13000, gold: 2500 }, { at: 25000, gold: 4000 },
  { at: 45000, gold: 6000 }, { at: 80000, gold: 9000 }];
const WEEK_RANK_GOLD = [105000, 66000, 42000, 27000, 21000, 16500, 13500, 11400, 9600, 8400];   // 排名奖前10（二次加肥×3）：榜首≈中度自摸一周半，奖金池是顶层的主要收入
/* 繁荣度（每城固有价值）：四段几何缓坡防通胀——东1.2/南1.15/西1.12/北1.10。
   放缓不影响防露营（露营安全性只取决于无尽增压1.18 vs 每波+25%，与繁荣度增速无关） */
function weekLevelBase(k) {
  if (k <= 15) return Math.round(100 * Math.pow(1.2, k));           // 东部（k15≈1541）
  if (k <= 31) return Math.round(1541 * Math.pow(1.15, k - 15));    // 南部（k31≈1.44万）
  if (k <= 47) return Math.round(14421 * Math.pow(1.12, k - 31));   // 西部（k47≈8.8万）
  return Math.round(88409 * Math.pow(1.10, k - 47));                // 北部（k63≈40.6万）
}
function weekAttemptScore(k, stars, endlessWaves) {   // 本局城池贡献（破纪录浮字/结算展示口径）
  return Math.round(weekLevelBase(k) * WEEK_STAR_MUL[clamp(stars, 1, 3)]
    * Math.max(1, 1 + WEEK_ENDLESS_PER * (endlessWaves || 0)));
}
/* 城池贡献两件套：进度项（有界，威望封顶3星）与讨伐值（无界，随无尽波数走） */
function cityProgOf(k, b) { return Math.round(weekLevelBase(k) * WEEK_STAR_MUL[clamp(b.stars || 1, 1, 3)]); }
function cityTaofaOf(k, b) { return Math.round(weekLevelBase(k) * WEEK_STAR_MUL[clamp(b.stars || 1, 1, 3)] * WEEK_ENDLESS_PER * (b.endless || 0) * (b.guest ? 1.3 : 1) * (b.hl ? 1.2 : 1)); }   // guest=客卿录的讨伐（v7.14.1 加码×1.3）；hl=黄历·宜征伐期间录的讨伐（v7.17 ×1.2）
/* 客卿（v7.14 抬弱势主公）：每周从冷板凳五家里请两位坐上宾——带客卿打下的讨伐值×1.3。
   实测曹操占62%局数、头部玩家清一色只带他；客卿给刷十大功绩的人一个换人的经济理由（答案定价原则）。
   周种子全服同批；候选池是使用率<3%的五家，袁绍袁术曹操不进池 */
const GUEST_POOL = ["liubei", "sunquan", "liubiao", "gongsunzan", "dongzhuo"];
function weekGuestLords(week) {
  const rng = mulberry32(Math.imul(week || 0, 2654435761) ^ 887654321);
  const i = Math.floor(rng() * GUEST_POOL.length);
  let j = Math.floor(rng() * (GUEST_POOL.length - 1));
  if (j >= i) j++;
  return [GUEST_POOL[i], GUEST_POOL[j]];
}
/* 十大功绩门槛：讨伐值排第10的那档（不足10城时为0，新讨伐值>它即入功勋图） */
function taofaCut(wb) {
  const v = Object.keys(wb || {}).map(k => cityTaofaOf(+k, wb[k])).filter(x => x > 0).sort((a, b) => b - a);
  return v.length >= TAOFA_TOP_N ? v[TAOFA_TOP_N - 1] : 0;
}
/* 顺应天时：本局是否契合当周主题——韬略分 ×1.3，奖励周周按主题换构筑（Part B 的奖励侧） */
function themeFit(themeId) {
  const c = state.team?.count || {};
  switch (themeId) {
    case "tuanjie":   return !!state.bondEver;                                   // 众志：凑齐过羁绊
    case "liaoyuan":  return allUnits().some(u => u.type.burn || ULTS[u.type.id]?.name?.includes("火")); // 燎原：带了会点火的人（v6.0 火系属性退役，看火机制）
    case "yunchou":   return state.lordUsed > 0;                                 // 运筹：放过主公技
    case "jifeng":    return (c.spear || 0) + (c.cav || 0) + (c.shield || 0) >= 3; // 疾风：近战/控场墙
    case "jiancheng": return (c.archer || 0) > 0 && allUnits().some(u => u.type.splash > 0); // 坚城：持久AOE
    default: return false;
  }
}
/* 韬略分（v7.11 原技术分，通关那一刻结算一次）：比"打得漂亮"不比"刷得久"——对症×少损×顺应天时，不吃讨伐波数。
   与势力榜（讨伐为主）互不换算，单开韬略榜。糙窄队≈base×0.36、满配≈base×1.68 */
function weekTechScore(k) {
  const hasWeak = state.diff.foes && state.diff.foes.tri;
  const counterPct = hasWeak ? (state.totalDmg > 0 ? state.counterDmg / state.totalDmg : 0) : 0.5;
  const hpFrac = state.baseHPMax > 0 ? clamp(state.baseHP / state.baseHPMax, 0, 1) : 1;
  const fit = themeFit(state.diff.theme) ? 1.3 : 1.0;
  return Math.round(weekLevelBase(k) * (0.6 + 0.8 * counterPct) * (0.6 + 0.6 * hpFrac) * fit);
}
function weekTechTotal() {   // 韬略榜（v7.11）：同十大功绩口径——只记你用兵最漂亮的十役
  const v = Object.values(meta.weekTech || {}).map(x => x | 0).sort((a, b) => b - a);
  let s = 0;
  for (let i = 0; i < Math.min(TAOFA_TOP_N, v.length); i++) s += v[i];
  return s;
}
/* 势力值：进度项全量 + 讨伐值Top10。抽成 weekScoreOf 让 rolloverWeek 对旧档也能按新口径结算 */
function weekScoreOf(wb) {
  let s = 0;
  const taofa = [];
  for (const k of Object.keys(wb || {})) {
    s += cityProgOf(+k, wb[k]);
    taofa.push(cityTaofaOf(+k, wb[k]));
  }
  taofa.sort((a, b) => b - a);
  for (let i = 0; i < Math.min(TAOFA_TOP_N, taofa.length); i++) s += taofa[i];
  return s;
}
function weekScore() { return weekScoreOf(meta.weekBest); }
function weekStarsTotal() {
  let s = 0;
  for (const k of Object.keys(meta.weekStars || {})) s += meta.weekStars[k];
  return s;
}
/* 本城战绩入账：赢的当下记一笔（不打讨伐也有威望分），讨伐每多撑一波再更新——中途退出也不丢已撑的波数。
   威望与讨伐波数分开取历史最优（允许来自不同局——一局3星浅讨伐、一局2星深讨伐各记各的，对玩家宽厚） */
function recordWeekScore(endlessWaves) {
  if (state.diff.week == null || !state.stars) return;
  const k = state.diff.k;
  grantTaofaTokens(k, endlessWaves || 0);   // 讨伐赏（v7.17）：破这州今日最深就发令牌，跨5波档当场飘字
  const g = weekGuestLords(state.diff.week).includes(state.ruler) ? 1 : 0;   // 客卿（v7.14.1）：这局讨伐值×1.3
  const hl = visitBuffOn("score") ? 1 : 0;   // 黄历·宜征伐（v7.17）：这30分钟录的讨伐值×1.2，与客卿同一套"实效值+标记"存法
  const sc = weekAttemptScore(k, state.stars, (endlessWaves || 0) * (g ? 1.3 : 1) * (hl ? 1.2 : 1));
  state.runScore = Math.max(state.runScore || 0, sc);
  const b = meta.weekBest[k];
  const nb = { stars: Math.max(state.stars, b?.stars || 0) };
  // 讨伐记录按"客卿/黄历加成后的实效值"比大小，波数和加成标记成对保存——9波客卿(=10.8)能顶掉10波素人
  const newEff = (endlessWaves || 0) * (g ? 1.3 : 1) * (hl ? 1.2 : 1), oldEff = (b?.endless || 0) * (b?.guest ? 1.3 : 1) * (b?.hl ? 1.2 : 1);
  if (newEff >= oldEff) { nb.endless = endlessWaves || 0; if (g && nb.endless) nb.guest = 1; if (hl && nb.endless) nb.hl = 1; }
  else { nb.endless = b?.endless || 0; if (b?.guest) nb.guest = 1; if (b?.hl) nb.hl = 1; }
  nb.score = cityProgOf(k, nb) + cityTaofaOf(k, nb);   // score=城池贡献（地图节点/破纪录基准沿用这个字段）
  if (state.prevBest > 0 && nb.score > state.prevBest && !state.newRecord) {
    state.newRecord = true;   // 破纪录：只跟开局前的老纪录比，当场报喜
    if (state.phase === "play") addFloater(W / 2, 300, `🎉 破纪录！这城的贡献刷到 ${nb.score}势力`, "#ffd24a", 22);
  }
  if (!b || nb.score > b.score || nb.stars > (b.stars || 0) || nb.endless > (b.endless || 0))
    meta.weekBest[k] = nb;
  checkWeekBands();
}
/* 分数段奖：势力值每跨一段当场发金币（结算页/地图都能看到进到哪段了） */
function checkWeekBands() {
  const s = weekScore();
  let got = 0;
  while ((meta.weekBands || 0) < WEEK_BANDS.length && s >= WEEK_BANDS[meta.weekBands].at) {
    got += WEEK_BANDS[meta.weekBands].gold;
    meta.weekBands++;
  }
  if (got) {
    earnGold(got);
    state.bandGold = (state.bandGold || 0) + got;
  }
}
/* 周一换图：城池进度/势力值清零，金币/英雄等级/兵法一概保留；上周成绩存起来等发榜 */
function rolloverWeek(m) {
  const wk = trialWeekNow();
  if (m.week === wk) return;
  const sc = weekScoreOf(m.weekBest);   // v7.11 新口径：进度全量+讨伐Top10（旧档也按stars/endless重算）
  if (m.week && sc > 0) m.pendingWeek = { week: m.week, score: sc };
  m.week = wk;
  m.weekBest = {};
  m.weekStars = {};
  m.weekClears = {};
  m.weekBands = 0;
  m.weekTech = {};   // 韬略榜也按周清零，周周重新比打法
  m.adWeek = 0;   // 广告次数按赛季记，周一清零
  _weekSlots = { week: -1, slots: null };
}
/* 发上周榜：从榜单里凑齐上周的同榜人（还没换周的看week、换过的看prev），算名次发排名奖 */
let weekReportShow = false;
async function settleLastWeek() {
  const pw = meta.pendingWeek;
  if (!pw) return;
  const b = await netFetchBoard(true);
  if (!b || !Array.isArray(b.week)) return;   // 拿不到榜：pending 留着，下次再结
  const cohort = [];
  for (const e of b.week) {
    const sc = e.week === pw.week ? e.score : e.prev && e.prev.week === pw.week ? e.prev.score : null;
    if (sc != null && sc > 0 && e.name !== NET.name) cohort.push(sc);
  }
  const rank = 1 + cohort.filter(sc => sc > pw.score).length;
  const gold = rank <= WEEK_RANK_GOLD.length ? WEEK_RANK_GOLD[rank - 1] : 0;
  if (gold) earnGold(gold);
  meta.lastWeekReport = { week: pw.week, score: pw.score, rank, n: cohort.length + 1, gold };
  delete meta.pendingWeek;
  weekReportShow = true;
  saveMeta();
}
/* 势力榜行：服务器榜按本周过滤，再把自己本地的分合并进去——
   推送要绕一圈服务器（防抖1.5s+缓存10s），没登录更是不上传；自己的成绩不能等，本地先上榜 */
function weekBoardRows() {
  const b = NET.board;
  if (!b) return null;
  const rows = (b.week || []).filter(e => e.week === trialWeekNow() && e.score > 0);
  const mine = weekScore();
  const myName = NET.name || "我(没登录)";
  if (mine > 0 && !rows.some(e => e.name === NET.name)) {
    rows.push({ name: myName, week: trialWeekNow(), score: mine,
      stars: weekStarsTotal(), cleared: Object.keys(meta.weekClears || {}).length, ads: meta.adWeek || 0 });
  }
  return rows.sort((x, y) => y.score - x.score);
}
/* 韬略榜行：仿势力榜——服务器榜按本周过滤，自己本地韬略分合并进去先上榜 */
function techBoardRows() {
  const b = NET.board;
  if (!b) return null;
  const rows = (b.tech || []).filter(e => e.week === trialWeekNow() && e.tech > 0);
  const mine = weekTechTotal();
  const myName = NET.name || "我(没登录)";
  if (mine > 0 && !rows.some(e => e.name === NET.name)) {
    rows.push({ name: myName, week: trialWeekNow(), tech: mine });
  }
  return rows.sort((x, y) => y.tech - x.tech);
}
/* 先锋（v7.11 原州牧）：本周该城讨伐值最高的玩家（挂在地图节点上，等你去抢）——讨伐值全0时虚位以待 */
/* 州郡逐级解锁：通了上一州才开下一州（周一换图从交州重新开）——没解锁的州画灰，不透题面 */
function weekLocked(k) { return k > 0 && !meta.weekClears[k - 1]; }
function weekLordOf(k) {
  const b = NET.board;
  if (!b || !Array.isArray(b.week)) return null;
  let top = null;
  for (const e of b.week) {
    if (e.week !== trialWeekNow() || !e.levels) continue;
    const sc = e.levels[k];
    if (sc > 0 && (!top || sc > top.score)) top = { name: e.name, score: sc };
  }
  return top;
}
/* 主公技：右侧3槽，开局全空；三选一获取，重复获取升级（至3级）。
   点击释放，独立冷却——玩家手里唯一的主动按钮，一按要有一按的份量。
   设计边界（2026-07-06 重做）：凡是武将大招能干的（奶/控/增伤/提速）主公技一律不做——
   主公只管武将碰不到的四条轴：时间（东风/冰封）、属性（破敌五行）、敌技（监军令）、
   波次经济（诱敌深入）、城防（筑城）。按之前要先看题：敌情/预告/城墙余量 */
const LORD_MAX_LV = 3;
const LORDS = {
  /* 借东风：时间轴救命技——全场敌人往回吹一大段，贼首减半。
     数值换算：中期敌速约55px/s，吹回200px≈走回来3.6秒+后滑0.7秒≈喘4秒 */
  huoshi: { icon: "🌪️", name: "借东风", cd: 24,
    desc: l => `全场吹回去，喘${3 + l}秒`,
    stat: l => ({ push: 140 + l * 60 }),
    hot: () => aliveEnemies().filter(e => e.y > GRID_Y - 220).length >= 8 },
  bingfeng: { icon: "🧊", name: "冰封", cd: 30,
    desc: l => `全场定住 ${(1 + l * 0.7).toFixed(1)}秒`,
    stat: l => ({ t: 1 + l * 0.7 }),
    hot: () => aliveEnemies().length >= 22 },
  /* 三才破敌（v7.16 重做）：属性题的保险丝——窗口期被克减免失效+全军+15%，克制×1.5仍要真带对系 */
  wuxing: { icon: "☯️", name: "三才破敌", cd: 30,
    desc: l => `${6 + l * 2}秒内被克的亏全免，全军伤害再+15%`,
    stat: l => ({ t: 6 + l * 2 }),
    hot: () => aliveEnemies().length >= 8 },
  /* 监军令（换掉天威——恐惧/沉默是张辽貂蝉的活）：敌技轴。
     只对特种兵和贼首生效：闭嘴（巫医不奶/旗手不督/弓贼不射/贼首绝活哑火）还多挨打。
     看波次预告里的特种构成再按 */
  jianjun: { icon: "🎖️", name: "监军令", cd: 26,
    desc: l => `特种和贼首闭嘴${6 + l * 2}秒，多挨${10 + l * 5}%打`,
    stat: l => ({ t: 6 + l * 2, amp: 0.10 + l * 0.05 }),
    hot: () => state.enemies.filter(e => !e.dead && (e.special || e.boss) && !(e.silencedT > 0)).length >= 2 },
  /* 诱敌深入（换掉征伐——提速是小乔的活）：波次经济轴，唯一的风险决策技。
     下一波多3成人但个个脆皮，经验金币加成——阵地稳时滚雪球，城墙告急时是自杀键。
     账：波总血量×1.3×0.6≈0.78省两成二，但上墙的嘴多三成 */
  youdi: { icon: "🐑", name: "诱敌深入", cd: 65,
    desc: l => `下一波多3成、个个皮薄，整波经验金币+${30 + l * 10}%`,
    stat: l => ({ hpK: 0.83 - l * 0.03, gainK: 1.3 + l * 0.1 }),
    hot: () => !state.youdi && !!state.nextQueue && state.baseHP >= state.baseHPMax * 0.75 },
  zhucheng: { icon: "🏯", name: "筑城", cd: 40,
    desc: l => `城墙+${l}血 +${1 + l}盾`,
    stat: l => ({ hp: l, sh: 1 + l }),
    hot: () => state.baseHP <= state.baseHPMax * 0.5 },
  /* —— 主公制新技（2026-07-08）：三个新轴——复活（刘备）、地形（孙权）、卡牌（袁绍/刘表） —— */
  /* 桃园义 v7.3.0 重做（用户裁决：复活价值不大——人死时=敌战力临界，拉回来也没表现机会）：
     改全军金身——有兄弟血量<35%时自动释放，全员无敌几秒扛过临界点；CD拉长防无敌循环 */
  taoyuan: { icon: "🍑", name: "桃园义", cd: 55,
    desc: l => `全军金身${4 + l * 2}秒刀枪不入（亲兵越多越久）；金身落幕，扛住的伤全额奉还成全场冲击（附1秒眩晕），实伤的8%再换成经验`,
    stat: l => ({ invT: 4 + l * 2 }),   // v7.5.1 用户"时间太短没起作用"：4/5/6→6/8/10秒
    hot: () => allUnits().some(u => !["granary", "egg", "dragon"].includes(u.type.cls) && u.hp < u.hpMax * 0.55)
      || aliveEnemies().some(e => e.y > DEFENSE_LINE - 150) },   // v7.4.3 复合危难（血线35%→55%+贼近墙）：真实局实测纯血线3分钟0触发
  jiejiang: { icon: "🌊", name: "截江断流", cd: 32,
    desc: l => `拦腰一道大江${5 + l * 2}秒：江里的贼变慢40%、挨打多${20 + l * 10}%，弓贼投石在江里放不了箭`,
    stat: l => ({ t: 5 + l * 2, amp: 0.2 + l * 0.1 }),
    hot: () => aliveEnemies().filter(e => e.y < 400).length >= 12 },
  mensheng: { icon: "📜", name: "门生故吏", cd: 48,
    desc: l => `接下来 ${l} 次升级选卡变五选一；手里正摊着牌就当场加宽`,
    stat: l => ({ wide: l }),
    hot: () => !state.widePicks && state.wave >= 2 },
  /* v5.6 三新主公（用户拍板）：城墙轴/敌阵轴/金币轴——招牌技尽量复用退役老技，收买是唯一新技 */
  shoumai: { icon: "💰", name: "收买", cd: 40,
    desc: l => `最多买通 ${[0, 8, 12, 16][l]} 个普通小兵拿钱走人——花账上金币（每个 10+波×2 金），不给经验金币；精英贼首不吃这套`,
    stat: l => ({ n: [0, 8, 12, 16][l] }),
    hot: () => state.enemies.filter(e => !e.dead && !e.special && !e.boss && !e.affix && !e.big).length >= 12
      && meta.gold >= (10 + state.wave * 2) * 4 },
  /* —— v7.0 三新大招（自动释放，从城墙上的主公主体发出，吃亲兵加成 kinPower） —— */
  /* 白马义从（公孙瓒·主公下场实验）：主公骑白马冲下城墙，无敌几秒专砍关键怪——界桥亲冲的本人 */
  baima: { icon: "🐎", name: "白马义从", cd: 30,
    desc: l => `主公亲自下场${5 + l * 2}秒：无敌白马专砍特种兵和贼首（亲兵越多砍得越疼越久）`,
    stat: l => ({ t: 5 + l * 2, dmgK: 1.1 + l * 0.3 }),   // v7.3.1 时长7/9/11秒；v7.14.1 加码：砍击 0.8+0.2l→1.1+0.3l（约+40%）
    hot: () => state.enemies.some(e => !e.dead && (e.special || e.boss)) || aliveEnemies().length >= 8 },
  /* 火烧雒阳（董卓·残血流实验）：烧自家城墙血换全场巨焰——城血是弹药 */
  fenluo: { icon: "🔥", name: "火烧雒阳", cd: 28,
    desc: l => `烧掉自家2点城墙血，从主公喷出全场扇形巨焰（点燃；亲兵越多烧得越疼）；每烧1血全军攻击+4%（本局永久）`,
    stat: l => ({ dmgK: 0.8 + l * 0.2 }),
    hot: () => aliveEnemies().length >= 6 && state.baseHP >= 5 },
  /* 僭号称帝（袁术·献祭实验）：吃掉一个最弱的兵换大把经验（够连抽几次卡）。
     双保险：战斗单位≥5才发动、只吃星≤3的最低星（粮仓/龙蛋/龙不吃）——绝不吃你喂大的主力 */
  jianhao: { icon: "🪙", name: "僭号称帝", cd: 45,
    desc: l => `吃掉一个最弱的兵（星≤3、场上≥5人才动口）连升${l >= 2 ? 3 : 2}级，祭品每有1星再多升1级；每献祭一次，下道号令等得更久（45→57→69…）`,
    stat: l => ({ ups: l >= 2 ? 3 : 2 }),   // v7.3.2 用户"吃一个才摸一个白瞎"：+祭品星级=吃得越肥吐得越多（1星祭品=3~4级）
    hot: () => !!jianhaoTarget() },
};
/* 僭号称帝的双保险选人：场上战斗单位≥5 且 存在星≤3 的单位，返回其中星最低的（并列取图鉴等级低的） */
function jianhaoTarget() {
  const fighters = allUnits().filter(u => u.type.cls !== "granary" && u.type.cls !== "egg" && u.type.cls !== "dragon");
  if (fighters.length < 5) return null;
  const cand = fighters.filter(u => u.level <= 3);
  if (!cand.length) return null;
  cand.sort((a, b) => a.level - b.level || heroLv(a.type.id) - heroLv(b.type.id));
  return cand[0];
}

/* —— 主公制 v5.0（主公府）：每位主公=1个招牌技 + 3~4本兵书被动（随主公等级解锁，只在带他的局里生效）
     + 至多1个专属机制。看题面选人：五位各管一类题，被动强弱对冲招牌技强弱，别偏科。
     局内不成长（lordUp参悟卡已退役）；升级在局外——战斗结算给经验，后续寻访再加渠道。
     被动解锁拍子：主被动 1/5/9/13/17，其余错开一级排到20（满级全被动5级）。 —— */
const LORD_SPECIALS = {
  tuntian:  { icon: "🌾", name: "屯田制", desc: id => `独家：粮仓卡——产粮喂旁边武将升星，产量+${lordLv(id) * 3}%` },
  yanglong: { icon: "🐉", name: "养龙术", desc: id => `独家：三选一出龙蛋卡——干孵期间每秒吐纳经验（蛋阶越高越多，+${lordLv(id) * 2}%），觉醒成应龙镇场；温养把握+${lordLv(id)}%` },
  qiangnu:  { icon: "🏹", name: "城头强弩", desc: id => `独家：城墙自动放箭射最贴近防线的贼（墙越满箭越狠，伤害+${lordLv(id) * 3}%）；首级记功：白马/强弩亲手击杀经验×3` },
  lijian:   { icon: "💔", name: "离间计", desc: id => `独家：每波开打，血最厚的2个小兵倒戈${(3 + 0.1 * (lordLv(id) - 1)).toFixed(1)}秒殴打同伙` },
  henzheng: { icon: "🧧", name: "横征暴敛", desc: id => `独家：杀敌金币+${lordLv(id) * 2}%；火葬收魂：着火烧死的贼经验×2` },
  luoyangchan: { icon: "🪏", name: "洛阳铲", desc: id => "独家：开山凿石卡变洛阳铲——铲子存着，点铲子自己挑哪块障碍挖；挖开有三成陪葬金" },
  qinwang:  { icon: "🐎", name: "勤王义军", desc: id => `独家：每波开打来一队义军铁骑，冲人最多的列（伤害+${lordLv(id) * 3}%）` },
  yishe:    { icon: "🍚", name: "义舍", desc: id => `独家：义舍管饭——全军回血快${Math.round((0.8 + 0.02 * lordLv(id)) * 100)}%` },
  shuijun:  { icon: "⚓", name: "水军都督", desc: id => `独家·江东通饷：杀敌经验+30%（江中击杀×2）；每波自动起江${(4.5 + lordLv(id) * 0.15).toFixed(1)}秒（变慢40%·挨打多${20 + Math.round(lordLv(id) * 0.5)}%·弓贼哑火）` },
};
/* 主公亲射外显+调参表（v7.15）：每家的招式名/打法/伤害倍率。
   mul>1 是弱势主公的火力抬升（用户拍板"平衡到和强势主公一样的出场率"）——
   强势三家（曹操/袁绍/袁术）单体1.0，弱势群体招直接加量；公孙瓒的倍率吃在城头强弩上 */
const LORD_ATK = {
  caocao:     { icon: "🗡️", name: "掷戟",     how: "单体：投戟点最贴墙的贼",                mul: 1.0 },
  yuanshao:   { icon: "🏹", name: "门客暗箭", how: "单体：紫电冷箭点最深的贼",              mul: 1.0 },
  yuanshu:    { icon: "🪙", name: "玉玺砸人", how: "单体：金光一道砸最深的贼",              mul: 1.0 },
  sunquan:    { icon: "🌊", name: "楼船连弩", how: "群体：三连水箭射最贴墙的3个贼",         mul: 1.6 },
  liubiao:    { icon: "❄️", name: "寒江霜箭", how: "群体：命中炸寒雾，附近的贼挨打还减速",  mul: 1.6 },
  liubei:     { icon: "⚔️", name: "双股剑气", how: "群体：横扫剑光，连坐左右最多4贼",       mul: 1.5 },
  dongzhuo:   { icon: "🔥", name: "火油瓶",   how: "群体：小片火再点燃",                    mul: 1.5 },
  gongsunzan: { icon: "🏹", name: "城头强弩", how: "单体：城墙自动放箭，墙越满箭越狠",      mul: 1.4 },
};
const LORD_RULERS = [
  { id: "caocao",  name: "曹操", title: "乱世奸雄", skill: "wuxing", special: "tuntian",
    passives: [{ id: "bounty", at: [1, 5, 9, 13, 17] }, { id: "farm", at: [3, 7, 11, 15, 19] }, { id: "supply", at: [4, 8, 12, 16, 20] }],
    desc: "屯田养兵：三才破敌免掉被克的亏，独家粮仓喂人升星——家底厚，答题还是要自己答" },
  { id: "liubei",  name: "刘备", title: "仁德载世", skill: "taoyuan", special: null,
    passives: [{ id: "wall", at: [1, 5, 9, 13, 17] }, { id: "mend", at: [2, 6, 10, 14, 18] }, { id: "d_spear", at: [3, 7, 11, 15, 19] }, { id: "d_supp", at: [4, 8, 12, 16, 20] }],
    desc: "守护续航：兄弟危难全军金身，落幕把扛的伤全数奉还还换经验——扛得越狠，反击越疼粮饷越足" },
  { id: "sunquan", name: "孙权", title: "坐断东南", skill: "jiejiang", special: "shuijun",
    passives: [{ id: "d_cav", at: [1, 5, 9, 13, 17] }, { id: "d_archer", at: [2, 6, 10, 14, 18] }, { id: "bounty", at: [3, 7, 11, 15, 19] }, { id: "pick", at: [4, 8, 12, 16, 20] }],
    desc: "江东通饷：杀敌经验+30%直通抽卡雪球，江中击杀经验×2——每波自动起江，按住贼收粮" },
  { id: "yuanshao", name: "袁绍", title: "四世三公", skill: "mensheng", special: null,
    passives: [{ id: "vet", at: [1, 5, 9, 13, 17] }, { id: "farm", at: [2, 6, 10, 14, 18] }, { id: "supply", at: [3, 7, 11, 15, 19] }, { id: "wall", at: [4, 8, 12, 16, 20] }],
    desc: "门路宽广：门生故吏把升级选卡变五选一、牌好有得挑，开局还自带老兵——雪球滚得稳" },
  { id: "liubiao", name: "刘表", title: "坐保江汉", skill: "bingfeng", special: "yanglong",
    passives: [{ id: "d_shield", at: [1, 5, 9, 13, 17] }, { id: "wall", at: [2, 6, 10, 14, 18] }, { id: "pick", at: [3, 7, 11, 15, 19] }],
    desc: "深沟高垒：龙蛋孵着吐经验、觉醒成应龙镇场；讨伐每多撑1波全军攻击+5%——从容养蛋，越守越强" },
  /* v5.6 三新主公：城墙轴（墙是武器）/ 敌阵轴（让贼窝里斗）/ 金币轴（真金白银买命） */
  /* v7.0 实验机制主公（用户拍板：砍马腾/韩遂/张鲁三家凑数的，机制给真有名的） */
  { id: "gongsunzan", name: "公孙瓒", title: "白马将军", skill: "baima", special: "qiangnu",
    passives: [{ id: "wall", at: [1, 5, 9, 13, 17] }, { id: "mend", at: [2, 6, 10, 14, 18] }, { id: "d_archer", at: [3, 7, 11, 15, 19] }, { id: "pick", at: [4, 8, 12, 16, 20] }],
    desc: "亲冒矢石：白马下场砍关键怪、强弩看家——主公亲手击杀经验×3，将军的首级换全军的粮饷" },
  { id: "dongzhuo", name: "董卓", title: "相国", skill: "fenluo", special: "luoyangchan",
    passives: [{ id: "bounty", at: [1, 5, 9, 13, 17] }, { id: "vet", at: [2, 6, 10, 14, 18] }, { id: "d_cav", at: [3, 7, 11, 15, 19] }, { id: "supply", at: [4, 8, 12, 16, 20] }],
    desc: "焚掘无度：烧城血换巨焰+4%永久攻，着火烧死的贼经验×2——火葬收魂，烧得越旺学得越快",
    special2: "henzheng" },
  { id: "yuanshu", name: "袁术", title: "仲家皇帝", skill: "jianhao", special: null,
    passives: [{ id: "farm", at: [1, 5, 9, 13, 17] }, { id: "supply", at: [2, 6, 10, 14, 18] }, { id: "pick", at: [3, 7, 11, 15, 19] }, { id: "bounty", at: [4, 8, 12, 16, 20] }],
    desc: "帝业吃人：定期吃掉最弱的兵换大把经验连抽卡——留个便宜祭品位，帝业才滚得快" },
];
function rulerOf() { return LORD_RULERS.find(x => x.id === state.ruler) || null; }
function rulerKit() { const r = rulerOf(); return r ? [r.skill] : Object.keys(LORDS); }
/* 嫡系（v5.8 用户拍板"跟对主公的人，上场就带资历"）：每家3人、偏冷门讲出身、金卡最多1个——
   带自家主公出征：白/绿嫡系登场+2星、蓝/金+1星（登场轴补偿，不吃图鉴等级——神将天命同款原则，防大佬叠乘区）；
   该主公局内嫡系武将卡权重+6并标「亲」。带动冷板凳的原理：选主公=选班底，差异长在牌桌上 */
const LORD_KIN = {
  caocao:     ["caoren", "caohong", "xuchu", "dianwei"],          // 三曹家将+宿卫典韦
  liubei:     ["yanyan", "huangyueying", "xushu", "zhangfei"],    // 老将/巧匠/徐元直+桃园三弟
  sunquan:    ["daqiao", "xiaoqiao", "lusu", "zhoutai"],          // 江东三辅+救主周泰
  yuanshao:   ["yanliang", "zhanghe", "xuhuang", "wenchou"],      // 河北武人+文丑
  liubiao:    ["huangzhong", "weiyan", "caiwenji", "ganning"],    // 荆州旧部+江夏客将甘宁
  gongsunzan: ["zhaoyun", "sunshangxiang", "xiahouyuan", "taishici"], // 白马义从·骑射立家
  dongzhuo:   ["lvbu", "diaochan", "gaoshun", "jiaxu"],           // 凤仪亭一家人+西凉毒士
  yuanshu:    ["sunce", "huanggai", "huatuo"],                    // 质玉玺的孙策+孙坚旧部+游医（贾诩百搭补第4）
};
/* 贾诩百搭（v7.6.0）：一生换了多少主子——谁的主公局他都算亲兵（呼应v5.7他被踢出主公席） */
function isKin(id) { return !!(state.ruler && (id === "jiaxu" || (LORD_KIN[state.ruler] && LORD_KIN[state.ruler].includes(id)))); }
function kinGiftStars(id) {
  if (!isKin(id)) return 0;
  const r = heroRarity(id);
  return r === "common" || r === "uncommon" ? 2 : 1;
}
function kinLordOf(id) {
  for (const rl of LORD_RULERS) if (LORD_KIN[rl.id] && LORD_KIN[rl.id].includes(id)) return rl;
  return null;
}

const BOSS_NAMES = ["程远志", "邓茂", "波才", "张梁", "张宝", "张角"];

/* ---------- 音效引擎（Web Audio 合成，零素材） ---------- */
const SFX = (() => {
  let ac = null, master = null, muted = false;
  let lastPlay = {};   // 每类音效节流

  function ensure() {
    if (!ac) {
      ac = new (window.AudioContext || window.webkitAudioContext)();
      master = ac.createGain();
      master.gain.value = 0.35;
      master.connect(ac.destination);
    }
    if (ac.state === "suspended") ac.resume();
    return ac;
  }

  // 基础音：振荡器 + 包络
  function tone({ freq = 440, freqEnd = null, type = "square", dur = 0.1,
                  vol = 1, attack = 0.004, when = 0 }) {
    if (muted || !ac) return;
    const t0 = ac.currentTime + when;
    const o = ac.createOscillator();
    const g = ac.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t0);
    if (freqEnd) o.frequency.exponentialRampToValueAtTime(Math.max(1, freqEnd), t0 + dur);
    g.gain.setValueAtTime(0, t0);
    g.gain.linearRampToValueAtTime(vol, t0 + attack);
    g.gain.exponentialRampToValueAtTime(0.001, t0 + dur);
    o.connect(g).connect(master);
    o.start(t0);
    o.stop(t0 + dur + 0.02);
  }

  // 噪声（爆炸/撞击）
  function noise({ dur = 0.2, vol = 1, freq = 800, when = 0 }) {
    if (muted || !ac) return;
    const t0 = ac.currentTime + when;
    const len = Math.max(1, Math.floor(ac.sampleRate * dur));
    const buf = ac.createBuffer(1, len, ac.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
    const src = ac.createBufferSource();
    src.buffer = buf;
    const f = ac.createBiquadFilter();
    f.type = "lowpass";
    f.frequency.setValueAtTime(freq, t0);
    f.frequency.exponentialRampToValueAtTime(Math.max(40, freq * 0.15), t0 + dur);
    const g = ac.createGain();
    g.gain.setValueAtTime(vol, t0);
    g.gain.exponentialRampToValueAtTime(0.001, t0 + dur);
    src.connect(f).connect(g).connect(master);
    src.start(t0);
  }

  function throttled(key, ms) {
    const now = performance.now();
    if (lastPlay[key] && now - lastPlay[key] < ms) return true;
    lastPlay[key] = now;
    return false;
  }

  const api = {
    unlock() { ensure(); },
    toggleMute() { muted = !muted; return muted; },
    get muted() { return muted; },

    shoot(cls) {
      if (!ac || throttled("shoot", 45)) return;
      // 三兵种音色区分
      if (cls === "archer") tone({ freq: 1300, freqEnd: 500, type: "square", dur: 0.06, vol: 0.16 });
      else if (cls === "cav") tone({ freq: 480, freqEnd: 190, type: "sawtooth", dur: 0.09, vol: 0.2 });
      else tone({ freq: 800, freqEnd: 320, type: "triangle", dur: 0.07, vol: 0.22 });
    },
    hit() {
      if (!ac || throttled("hit", 60)) return;
      noise({ dur: 0.06, vol: 0.14, freq: 1600 });
    },
    kill() {
      if (!ac || throttled("kill", 80)) return;
      tone({ freq: 300, freqEnd: 90, type: "square", dur: 0.14, vol: 0.25 });
      noise({ dur: 0.1, vol: 0.18, freq: 900 });
    },
    crit() {
      if (!ac || throttled("crit", 100)) return;
      tone({ freq: 1500, freqEnd: 2200, type: "square", dur: 0.08, vol: 0.2 });
    },
    wallHit() {
      noise({ dur: 0.3, vol: 0.5, freq: 500 });
      tone({ freq: 120, freqEnd: 45, type: "sine", dur: 0.3, vol: 0.5 });
    },
    levelUp() {
      [523, 659, 784, 1047].forEach((f, i) =>
        tone({ freq: f, type: "triangle", dur: 0.16, vol: 0.3, when: i * 0.07 }));
    },
    pick() {
      tone({ freq: 660, type: "triangle", dur: 0.08, vol: 0.3 });
      tone({ freq: 990, type: "triangle", dur: 0.1, vol: 0.25, when: 0.06 });
    },
    ult() {
      tone({ freq: 200, freqEnd: 800, type: "sawtooth", dur: 0.3, vol: 0.4 });
      noise({ dur: 0.4, vol: 0.3, freq: 2000, when: 0.1 });
      tone({ freq: 1200, freqEnd: 300, type: "square", dur: 0.35, vol: 0.25, when: 0.12 });
    },
    tactic() {
      tone({ freq: 880, freqEnd: 440, type: "sine", dur: 0.2, vol: 0.35 });
      tone({ freq: 1320, freqEnd: 660, type: "sine", dur: 0.25, vol: 0.25, when: 0.08 });
    },
    buff() {   // 增益类大招：上扬三连音，跟爆炸声区分开
      if (!ac || throttled("buff", 200)) return;
      [523, 659, 880].forEach((f, i) =>
        tone({ freq: f, freqEnd: f * 1.25, type: "sine", dur: 0.16, vol: 0.3, when: i * 0.07 }));
      tone({ freq: 1760, type: "triangle", dur: 0.25, vol: 0.15, when: 0.22 });
    },
    dance() {   // 歌舞升平：三秒温柔乡小曲（五声琶音上去再下来，配低八度衬底）
      if (!ac) return;
      const mel = [523, 587, 659, 784, 880, 1047, 880, 784, 659, 587, 523, 659];
      mel.forEach((f, i) => {
        tone({ freq: f, type: "triangle", dur: 0.26, vol: 0.28, when: i * 0.24 });
        tone({ freq: f / 2, type: "sine", dur: 0.4, vol: 0.12, when: i * 0.24 });
      });
    },
    bossSpawn() {
      tone({ freq: 110, freqEnd: 55, type: "sawtooth", dur: 0.5, vol: 0.5 });
      tone({ freq: 165, freqEnd: 82, type: "sawtooth", dur: 0.5, vol: 0.35, when: 0.15 });
      noise({ dur: 0.5, vol: 0.2, freq: 300, when: 0.1 });
    },
    bossDie() {
      [200, 150, 100, 60].forEach((f, i) =>
        tone({ freq: f, freqEnd: f * 0.5, type: "square", dur: 0.25, vol: 0.35, when: i * 0.1 }));
      noise({ dur: 0.6, vol: 0.4, freq: 700, when: 0.05 });
    },
    relic() {
      [523, 659, 784, 1047, 1319].forEach((f, i) =>
        tone({ freq: f, type: "sine", dur: 0.3, vol: 0.28, when: i * 0.09 }));
    },
    bond() {
      tone({ freq: 440, type: "triangle", dur: 0.2, vol: 0.3 });
      tone({ freq: 554, type: "triangle", dur: 0.2, vol: 0.3, when: 0.1 });
      tone({ freq: 659, type: "triangle", dur: 0.3, vol: 0.35, when: 0.2 });
    },
    waveStart() {
      tone({ freq: 330, freqEnd: 660, type: "triangle", dur: 0.18, vol: 0.3 });
    },
    ach() {
      [784, 988, 1175, 1568].forEach((f, i) =>
        tone({ freq: f, type: "square", dur: 0.14, vol: 0.22, when: i * 0.08 }));
    },
    gameOver() {
      [392, 349, 311, 262].forEach((f, i) =>
        tone({ freq: f, type: "triangle", dur: 0.4, vol: 0.35, when: i * 0.25 }));
    },
    win() {
      [523, 659, 784, 1047, 784, 1047, 1319].forEach((f, i) =>
        tone({ freq: f, type: "triangle", dur: 0.22, vol: 0.32, when: i * 0.14 }));
    },
  };
  return api;
})();

/* ---------- 游戏状态 ---------- */
let state, last = 0, shake = 0, showShop = false, showAch = false, showTech = false;
let showVisit = false, showBag = false;   // 寻访/背包页（v5.1）
let visit = null;   // 寻访运行态 { steps, lastStep, dice, lines, banner }
let showBoard = false, boardLogoutArm = false;   // 排行榜浮层（里面带退出登录）
const BOARD_BTN = { x: 14, y: H - 44, w: 116, h: 32 };
const LOG_BTN = { x: W - 130, y: H - 44, w: 116, h: 32 };

function newGame(lvIdx = 0) {
  // 兼容旧调用（测试/遗留）：难度名映射到代表关；传对象＝州郡周关等合成关
  if (typeof lvIdx === "string") lvIdx = { easy: 4, normal: 24, hell: 44, shura: 60 }[lvIdx] ?? 24;
  const diff = typeof lvIdx === "object" ? lvIdx : LEVELS[clamp(lvIdx, 0, LEVELS.length - 1)];
  if (diff.idx >= 0) meta.lastLevel = diff.idx;
  const wall = diff.wall;   // v5.0 兵书归主公：城防加固等开局被动在 applyRuler 补算（此刻主公未定，且旧局 ruler 可能残留）
  state = {
    phase: "title",          // title | pickDiff | pickStart | play | over | win
    diff,
    shenP: typeof shenPeriodNow === "function" ? shenPeriodNow() : null,   // 锁定本局神将批次（打到一半跨周一/周四不换人）
    kills: 0,
    baseHP: wall,
    baseHPMax: wall,
    wave: 0,
    waveTimer: 2.0,
    waveClock: 0,       // 贼军不等人：本波已耗时（秒）
    waveBudget: 0,      // 本波时间预算 = 出兵总时长 + 宽限；耗尽则下一波强行压上
    rushWarned: false,  // 催战预警已发（每波一次）
    scoredWave: 0,      // 无尽计分到哪一波（清场才算撑过）
    runScore: 0,        // 本局在这州打出的分
    prevBest: (diff && diff.week != null && meta.weekBest) ? (meta.weekBest[diff.k]?.score || 0) : 0,   // 开局前的历史最高（破纪录判定基准）
    newRecord: false,   // 本局破了这州的历史纪录
    spawnQueue: [],
    spawnTimer: 0,
    slots: Array.from({ length: GRID_ROWS }, () => Array(GRID_COLS).fill(null)),
    enemies: [],
    bullets: [],
    slashes: [],
    riders: [],
    particles: [],
    floaters: [],
    time: 0,
    speed: 2,                 // 固定2倍速（v7.13：砍掉调速钮——1速拖沓3速看不清，留2速一档就够）
    endless: false,
    drag: null,
    bossCount: 0,
    // —— 肉鸽经验/卡牌 ——
    level: 1,
    xp: 0,   // 老兵传承（袁绍被动）在 applyRuler 补算
    xpNeed: 10,
    cards: null,
    cardAnim: 0,
    pendingPicks: 0,
    widePicks: 0,               // 门生故吏：接下来几次选卡是五选一
    // —— 全局增益（兵法研究注入初值） ——
    buffs: { dmg: 1, rate: 1,
             xpGain: 1, critCh: 0, bulletSize: 1, extraShot: 0,
             ultHaste: 0, spearAura: 0, cavWide: 0, archerRange: 0, archerDmg: 0, cavDmg: 0,
             shieldReflect: 0, rippleRad: 0,
             elemBoost: { badao: 0, liangmou: 0, rende: 0 } },
    // —— 计策库存 ——
    lord: [null, null, null],   // 主公技槽 { id, lv }（CD共用：lordCd）
    lordCd: 0,                  // 主公号令共用CD：按谁就按谁的CD锁全家——号令越重下一道等得越久
    lordCdTotal: 1,             // 本次锁定的总时长（画冷却比例用）
    ruler: null,                // 本局主公（LORD_RULERS.id）——他的三张主公技就是这局的卡
    weekTheme: (diff && diff.theme) || null,   // 本局周主题id（行为类效果各处读它）
    flood: null,                // 截江断流 { y1, y2, amp, t }——江里挨打多amp+减速40%（v7.14.1）、弓贼投石哑火
    tyranny: 0,                 // 暴政印记（v7.14.1 董卓）：烧1城血=全军攻击+4%，本局永久
    lordAtkBuff: 0,             // 御驾亲征卡（v7.15）：主公亲射/强弩伤害加成（+0.4/张，可叠）
    lordAtkGap: 1,              // 神机连弩卡（v7.15）：亲射/强弩出手间隔倍率（×0.75/张，下限0.4）
    taoyuanAbsorb: 0,           // 桃园反击（v7.14 刘备）：本轮金身扛住的伤害账本
    wuxingT: 0,                 // 三才破敌：窗口剩余秒（全军打谁都算克制）
    taoyuanT: 0,                // 桃园义全军金身（v7.3.0）：剩余秒（全员刀枪不入）
    baima: null,                // 白马义从（v7.0）：主公下场实体 { x, y, t, hitT, dmg }
    shovels: 0,                 // 洛阳铲（v7.0 董卓）：存着的铲子数
    // —— 永久战术卡（v7.16 三改：锦囊袋退役——一次性小爆发竞争不过升星/出征的复利，改成锚流派的永久构筑卡）——
    luanshiOn: false,           // 乱石穿空：每波贼上齐时全障碍齐射（障碍流/邓艾流）
    huoshaoOn: false,           // 火烧连营：着火的贼死亡爆燃传火（火流）
    zhanshouOn: false,          // 擒贼擒王：精锐/贼首登场吃主公亲射×5（主公普攻流）
    luojingOn: false,           // 落井下石：受制的贼挨打+30%（控制流）
    shuiyanOn: false,           // 水淹七军：每波贼进场自动起江4秒（控制流引擎）
    luanshiWave: 0, shuiyanWave: 0,   // 每波触发去重
    pofuN: 0,                   // 破釜沉舟用过没（一局一釜）
    pofuBuff: 0,                // 破釜沉舟：×1.5乘算
    digMode: false,             // 洛阳铲挖掘模式：点铲子牌进入，点障碍格挖、点别处取消
    youdi: null,                // 诱敌深入：{ hpK, gainK }，buildWave 消费后清空
    team: { count: { spear: 0, cav: 0, archer: 0, shield: 0, support: 0 } },
    bondSet: null,           // 生效中的羁绊 id（computeTeam 维护）
    bondAnnounced: false,    // 开打第一帧把就位的羁绊广播一遍
    nextWavePreview: null, // 下波预告 { counts, affixes, boss }
    mutations: rollMutations(diff),   // 波次突变表 { 波号: 突变key }，预告提前一波亮牌
    // —— 本局金币/统计 ——
    goldEarned: 0,
    lordUsed: 0,
    ultsUsed: 0,
    shieldBlocks: 0,
    maxHit: 0,
    dmgBook: {},               // 伤害统计（v7.17.5 用户点名：验证搭配的输出）——按来源记账 {key:{icon,name,total,log:[[秒,伤]]}}
    dmgPanel: false,           // 📊实时输出面板开关
    // —— 三星/对症统计（结算评价 + 战役星数 + "换打法有没有用"的可见反馈） ——
    wallHurt: false,           // 城墙掉过血就没二星
    unitDeaths: 0,             // 有人阵亡就没三星
    counterDmg: 0,             // 打在贼怕处的伤害
    totalDmg: 0,
    xpAll: 0,                  // 本局全部经验（含加成后）
    farmStars: 0,              // 屯田喂出的星数——结算页可见 + 屯田大户成就
    stars: 0,                  // 本局评到几星（赢了才算）
    winWave: 0,                // 通关时打到第几波——无尽系数按超出的波数算
    elemsUsed: new Set(),      // 本局用过的攻击属性（顺应天时/宽度判定）
    bondEver: false,           // 本局凑齐过羁绊没（顺应天时·众志成城）
    runTech: 0,                // 本局通关时算出的韬略分（结算页展示）
    bandGold: 0,               // 本局跨分数段领到的奖金（结算页展示）
    // —— 无尽军令：无尽/试炼里每5波换一条，阵成型了问题还在流动 ——
    endlessMod: null,          // 生效中 { key, name, tip, mod, until }
    endlessPending: null,      // 提前一波预告的下一条
    endlessFoes: null,         // 换皮妖法：临时换掉的怕系
    cardPicks: {},             // 各卡已选次数（重复越多权重越衰减）
    granaryOffered: false,     // 屯田粮仓保底：每局第2波起的头一次选卡必见一次
    eggOffered: false,         // 应龙之卵保底：头一次进无尽的选卡必见一次（破顶工具得让人知道有）
    dragonN: 0,                // 本局已觉醒几条应龙（第N条伤害递增）
    dragonWaves: [],           // 各条觉醒于第几波（结算战报）
    killTarget: diff.killTarget || KILL_TARGET,
    // —— 遗物 ——
    relics: [],
    relicQueue: 0,
    pickingRelic: false,
    wallRegenT: 30,
    // —— 地利 ——
    field: null,
    fieldBanner: 0,           // 开局地形横幅剩余秒数（选将期常驻，开打后倒计时淡出）
    towerT: 15,
    volcanoT: 12,             // 火山口地形：喷发计时
    boulderT: 8,              // 滚石坡地形：滚石计时
    baihuReady: false,
    waveInfo: null,
    ultConfirm: null,
    obstacles: new Set(),      // 障碍格 "r,c"（不可放武将）
    traits: {},               // 格子特质 "r,c" -> TRAITS key
    inspect: null,            // 点击敌人查看属性（查看时暂停）
    // —— 新战场特效/弹道 ——
    ripples: [],              // 辅兵水波 { x, y, r, max, color, kind }
    shocks: [],               // 冲击波环 { x, y, r, max, dmg, stun, elem, color, hit:Set }
    beams: [],                // 射线（纯视觉） { x1, y1, x2, y2, t, color }
    lobs: [],                 // 我方抛掷（纯视觉） { x0, y0, x1, y1, t, dur, icon, color }
    elobs: [],                // 敌方投石 { x0, y0, x1, y1, t, dur, dmg }
    ebullets: [],             // 敌方冷箭 { x, y, target, spd, dmg }
    flobs: [],                // 我方投掷（有伤害，update推进） { x0,y0,x1,y1,t,dur,dmg,splash,elem,icon,color,pit }
    homers: [],               // 追踪弹（姜维） { x,y,vx,vy,target,spd,dmg,elem,life,color }
    traps: [],                // 陷阱（魏延） { x,y,r,dmg,splash,elem,t }
    firePits: [],             // 火堆（陆逊） { x,y,r,t,dmg }
    deathLink: null,          // 死亡链接（诸葛亮） { members:[敌], t }
    // —— 绝技衍生战场效果 ——
    wallShield: 0,   // 固守金汤（主公被动）在 applyRuler 补算；典韦/筑城也加这个
    blockade: null,           // 许褚：拒马 { t, y }
    palisades: [],            // 徐晃钉阵：短拒马 { x, hw, y, t }（update推进）
    turrets: [],              // 黄月英连弩塔 { x, y, t, cd, rng, rate, dmg, elem }（update推进）
    armyBuff: null,           // 鲁肃等：全军增益 { t, mul }
    armyHaste: null,          // 主公技·征伐/小乔 { t, mul }
    flash: 0,                 // 主公技·天威：全屏雷光闪（纯视觉，updateFx 衰减）
    dance: 0,                 // 歌舞升平：美人歌舞倒计时秒（入场演出）
    gewu: false,              // 歌舞升平·不早朝（v5.9）：真到局末——不弹卡/号令罢工/全军攻击+30%
  };
  // 初始障碍（乱石/断木）随难度递增：新兵4→修罗7（v7.14.3 从6→11降下来：15格堵11格开局只剩4格，
  // 固化成"必抓高伤弓手+等挖石"）。且每行至少留2空格——不许把整条横带堵死，近战开局才有站位可选
  let obTry = 0;
  while (state.obstacles.size < (diff.obstacles ?? 7) && obTry++ < 200) {
    const r = randi(0, GRID_ROWS - 1), c = randi(0, GRID_COLS - 1);
    if (state.obstacles.has(r + "," + c)) continue;
    let rowN = 1;
    for (let cc = 0; cc < GRID_COLS; cc++) if (state.obstacles.has(r + "," + cc)) rowN++;
    if (rowN > GRID_COLS - 2) continue;   // 这行已只剩2空格，换别行
    state.obstacles.add(r + "," + c);
  }
  // 全部15格随机特质（含障碍格，清出后显露）
  const traitKeys = Object.keys(TRAITS);
  for (let r = 0; r < GRID_ROWS; r++)
    for (let c = 0; c < GRID_COLS; c++)
      state.traits[r + "," + c] = pick(traitKeys);
}

/* ---------- 工具 ---------- */
const rand = (a, b) => a + Math.random() * (b - a);
const randi = (a, b) => Math.floor(rand(a, b + 1));
const pick = arr => arr[Math.floor(Math.random() * arr.length)];
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const dist2 = (ax, ay, bx, by) => (ax - bx) ** 2 + (ay - by) ** 2;

function slotCenter(r, c) {
  return { x: GRID_X + c * CELL + CELL / 2, y: GRID_Y + r * CELL + CELL / 2 };
}
function isObstacle(r, c) { return state.obstacles.has(r + "," + c); }
function cellTrait(r, c) {
  return (r != null && c != null && state.traits) ? state.traits[r + "," + c] : null;
}
/* 盾墙：同列上方有盾兵，帮身后挡下一半投石/落石 */
function shieldCover(r, c) {
  for (let rr = 0; rr < r; rr++) {
    const nb = state.slots[rr][c];
    if (nb && nb.type.cls === "shield") return true;
  }
  return false;
}
/* 钉阵拒马（徐晃）：短拒马挡半路，正面挡死、两侧能绕 */
function palisadeStopY(e) {
  // 返回挡住 e 的那面拒马（最上面一面），拿到对象才能"挤破"它
  let bp = null;
  for (const pa of state.palisades) {
    if (Math.abs(e.x - pa.x) > pa.hw + e.r * 0.5) continue;
    if (e.y + e.r >= pa.y && e.y - e.r < pa.y + 24)
      if (!bp || pa.y < bp.y) bp = pa;
  }
  return bp;
}
/* 蒺藜骨朵遗宝：被拒马/钉阵挡住的敌人每0.5秒被蒺藜扎一下（只在 update 调用，随暂停冻结） */
function barbTick(e, dt) {
  e.barbT = (e.barbT ?? 0.5) - dt;
  if (e.barbT <= 0) {
    e.barbT = 0.5;
    damageEnemy(e, Math.max(2, Math.round(1 + state.wave)), e.x, e.y - e.r, "#9adf5a", "", null, "@relic");
  }
}
/* 盾护：相邻8格是否有盾兵 */
function hasAdjacentShield(r, c) {
  if (r == null || c == null) return false;
  for (let rr = Math.max(0, r - 1); rr <= Math.min(GRID_ROWS - 1, r + 1); rr++)
    for (let cc = Math.max(0, c - 1); cc <= Math.min(GRID_COLS - 1, c + 1); cc++) {
      if (rr === r && cc === c) continue;
      const nb = state.slots[rr][cc];
      if (nb && nb.type.cls === "shield") return true;
    }
  return false;
}
function findUnitPos(u) {
  for (let r = 0; r < GRID_ROWS; r++)
    for (let c = 0; c < GRID_COLS; c++)
      if (state.slots[r][c] === u) return [r, c];
  return null;
}
function emptySlots() {
  const out = [];
  for (let r = 0; r < GRID_ROWS; r++)
    for (let c = 0; c < GRID_COLS; c++)
      if (!state.slots[r][c] && !isObstacle(r, c)) out.push([r, c]);
  return out;
}
function allUnits() {
  const out = [];
  for (let r = 0; r < GRID_ROWS; r++)
    for (let c = 0; c < GRID_COLS; c++)
      if (state.slots[r][c]) out.push(state.slots[r][c]);
  return out;
}
function ownsGeneral(id) { return allUnits().some(u => u.type.id === id); }
function addFloater(x, y, text, color, size = 16) {
  state.floaters.push({ x, y, text, color, size, life: 1 });
}
function burst(x, y, color, n = 10, spd = 120) {
  for (let i = 0; i < n; i++) {
    const a = rand(0, Math.PI * 2), s = rand(spd * 0.3, spd);
    state.particles.push({
      x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s,
      life: rand(0.35, 0.7), maxLife: 0.7, color, size: rand(2, 5),
    });
  }
}

/* ---------- 队伍加成计算 ---------- */
function computeTeam() {
  const count = {};
  for (const k of Object.keys(CLASSES)) count[k] = 0;
  for (const u of allUnits()) count[u.type.cls]++;
  state.team = { count };
  // 羁绊：练到门槛 + 同场上阵 = 生效（成员阵亡/卖掉立刻失效）
  const on = new Set(allUnits().map(u => u.type.id));
  const prev = state.bondSet;
  state.bondSet = new Set(BONDS.filter(b => b.members.every(id => on.has(id))).map(b => b.id));
  // 韬略分统计：累计本局用过的攻击属性 + 凑齐过羁绊没（顺应天时判定，只算真打人的兵）
  for (const u of allUnits()) if (elemMatters(u.type) && unitAttacks(u.type)) (state.elemsUsed ||= new Set()).add(u.type.elem);
  if (state.bondSet.size) state.bondEver = true;
  if (state.phase === "play")
    for (const bid of state.bondSet)
      if (!prev?.has(bid)) {
        const b = BONDS.find(x => x.id === bid);
        addFloater(W / 2, 280, `🔗 羁绊「${b.name}」生效！${b.desc}`, "#ffd24a", 19);
        unlockAch("swap10");
        if (bid === "wuhu") unlockAch("pins5lv5");
        (meta.bondsSeen ||= {})[bid] = 1;
        SFX.buff?.();
      }
}
function hasRelic(id) { return state.relics.some(r => r.id === id); }
/* 焦尾琴遗宝：催眠/冻慢时长+30%（蔡文姬/大乔的控制轴） */
function ctrlDur(s) { return s * (hasRelic("jiaowei") ? 1.3 : 1); }
/* 攻坚增压（v7.17.4 袁绍铁桶僵局）：1.18血量增压只压玩家火力侧，防守侧的百分比续航（回春/盾反/金身/义舍）
   没人压——贼刀全是线性(1+波×0.06)，深水区必然僵成"贼下不来、我上不去"的死局，波次还不等清场压上，贼越堆越卡。
   无尽超出通关波5波起（与hpK增压同一触发点），贼对武将的刀另乘×1.10/波复利：比1.18缓（扛揍流天然比爆发流
   多撑几波，保留身份），但任何奶量终会被砍穿——局必有终，是1.18承重墙的镜像不变量 */
function foeDmgK() {
  const extra = state.endless && state.winWave ? Math.max(0, state.wave - state.winWave - 5) : 0;
  return (state.foeRageT > 0 ? 1.3 : 1) * (extra ? Math.pow(1.10, extra) : 1);   // 贼胆：渠帅牌+30%（12秒有界）
}
/* 深水区韧性（v7.17.11 控制永动机）：攻坚增压保证刀越来越重，这条保证刀挥得出来——
   张辽/司马懿/貂蝉CD链把控制覆盖率转到100%=敌方输出永久×0，是百分比防御的极限形态
   （孙权百分比伤害漏洞的镜像）。同拍触发（无尽超通关波5波起）：贼身上的控制计时走表加速，
   每多1波等效控制时长×0.93、下限12%——控制从永动机退化成喘息期，配合刀×1.10复利，局必有终 */
function foeTenacity() {
  const extra = state.endless && state.winWave ? Math.max(0, state.wave - state.winWave - 5) : 0;
  return extra ? Math.max(0.12, Math.pow(0.93, extra)) : 1;
}

/* ============ 贼营渠帅（v7.18.0）============
   敌方的"主公"：坐镇贼寨不参战不受击，间歇抽牌直接生效——你有主公抽卡，贼也有渠帅抽卡。
   每关渠帅不同（week+k定席）=关卡新环境（题目要对应解法）；局内定期抽牌=动态压力。
   铁律：效果全有界（不叠加超顶）、伤武将最低留1血（三星判定不被随机绑架）、
   口嗨牌既是喘息也是人格；讨伐周关+无尽先行，战役老关不动 */
function topDmgUnit() {
  const us = allUnits().filter(u => !["egg", "granary"].includes(u.type.cls));
  if (!us.length) return null;
  let best = null, bt = -1;
  for (const u of us) { const t = (state.dmgBook && state.dmgBook[u.type.id] && state.dmgBook[u.type.id].total) || 0; if (t > bt) { bt = t; best = u; } }
  return best;
}
function foeHitUnit(u, frac) {
  const cut = Math.max(1, Math.round(u.hp * frac));
  u.hp = Math.max(1, u.hp - cut);   // 铁律：渠帅的牌打不死武将——压力转成回血经济，不随机绑架三星
  u.hurtFlash = 1;
  const pos = findUnitPos(u);
  if (pos) { const p = slotCenter(pos[0], pos[1]); addFloater(p.x, p.y - 40, `-${cut}`, "#ff7a7a", 14); burst(p.x, p.y - 10, "#ff7a3a", 8, 120); }
}
function foeSealUnit(u, t) {
  if (!u) return;
  u.sealedT = Math.max(u.sealedT || 0, t);
  const pos = findUnitPos(u);
  if (pos) { const p = slotCenter(pos[0], pos[1]); addFloater(p.x, p.y - 46, `🌀 被封印${t}秒!`, "#c96aff", 14); burst(p.x, p.y, "#c96aff", 10, 130); }
}
function foeSummon(special, count, mid) {
  const base = buildWave(state.wave).find(sp => !sp.special && !sp.big) || buildWave(state.wave)[0];
  const M = { runner: [0.5, 2.2, 14, 1], shaman: [1.8, 0.75, 21, 2], ram: [6.0, 0.5, 27, 4],
              assassin: [1.4, 1.6, 16, 2], bomber: [0.9, 1.1, 18, 2] }[special];
  for (let i = 0; i < count; i++)
    spawnEnemy({ ...base, hp: Math.round(base.hp * M[0]), speed: base.speed * M[1], r: M[2], dmg: M[3],
      special, xp: base.xp,   // 渠帅召的是杂兵价经验——不给喂经验流白送肉
      x: mid ? rand(60, W - 60) : null, y: mid ? rand(250, 340) : null });
}
const FOE_CARDS = {
  rage:     { name: "贼胆",   tip: "贼的刀+30%（12秒）", cast: () => { state.foeRageT = 12; } },
  shieldup: { name: "披甲",   tip: "现存贼人人套一层盾", cast: () => { for (const e of aliveEnemies()) { e.shield = Math.max(e.shield || 0, Math.round(e.hpMax * 0.18)); e.shieldMax = Math.max(e.shieldMax || 0, e.shield); } } },
  heal:     { name: "黄天庇佑", tip: "全场贼回血25%", cast: () => { for (const e of aliveEnemies()) e.hp = Math.min(e.hpMax, e.hp + Math.round(e.hpMax * 0.25)); } },
  curse:    { name: "咒缚",   tip: "全军攻击-25%（10秒）", cast: () => { state.foeCurseT = 10; } },
  sealone:  { name: "摄魂",   tip: "封印你最能打的武将6秒", cast: () => foeSealUnit(topDmgUnit(), 6) },
  sealrow:  { name: "锁阵",   tip: "封印一整排武将3.5秒", cast: () => { const rr = Math.floor(rand(0, GRID_ROWS)); for (let c = 0; c < GRID_COLS; c++) { const u = state.slots[rr][c]; if (u && !["egg", "granary"].includes(u.type.cls)) foeSealUnit(u, 3.5); } } },
  firerain: { name: "火雨",   tip: "三名武将挨烧（掉当前血30%，烧不死）", cast: () => { const us = allUnits().filter(u => !["egg", "granary"].includes(u.type.cls)).sort(() => Math.random() - 0.5).slice(0, 3); for (const u of us) foeHitUnit(u, 0.3); } },
  snipe:    { name: "冷箭",   tip: "点名你最能打的（掉当前血45%，打不死）", cast: () => { const u = topDmgUnit(); if (u) foeHitUnit(u, 0.45); } },
  ramwall:  { name: "撞门",   tip: "城墙-3", cast: () => { state.baseHP = Math.max(0, state.baseHP - 3); shake = Math.max(shake, 0.6); SFX.wallHit(); addFloater(W / 2, GRID_Y - 30, "🪓 城墙-3！", "#ff5a5a", 18); } },
  dispel:   { name: "拆台",   tip: "扫掉你的临时增益", cast: () => { state.armyBuff = null; state.wuxingT = 0; } },
  drop:     { name: "空投死士", tip: "中场空降2名刺客", cast: () => foeSummon("assassin", 2, true) },
  reinforce:{ name: "增员",   tip: "一小队快腿压上", cast: () => foeSummon("runner", 3, false) },
  ramcall:  { name: "破城槌", tip: "召2辆锤车（死物免控直撞城墙）", cast: () => foeSummon("ram", 2, false) },
  shaman2:  { name: "妖人助阵", tip: "召2个妖术师", cast: () => foeSummon("shaman", 2, false) },
  taunt:    { name: "口嗨",   tip: "光说不练", cast: () => {} },
};
const FOE_LORDS = [
  { id: "zhangjiao", name: "张角", title: "天公将军", icon: "🧙",
    taunts: ["苍天已死，黄天当立！", "岁在甲子，天下大吉！", "尔等官军，也配挡我黄天？"],
    deck: ["heal", "shaman2", "curse", "sealone", "rage", "dispel", "firerain", "taunt", "shieldup", "heal"] },
  { id: "zhangbao", name: "张宝", title: "地公将军", icon: "🌀",
    taunts: ["呼风唤雨，撒豆成兵！", "我兄长的道法，你们学不来。"],
    deck: ["sealrow", "sealone", "curse", "dispel", "shieldup", "taunt", "firerain", "drop", "heal", "sealrow"] },
  { id: "zhangliang", name: "张梁", title: "人公将军", icon: "⚔️",
    taunts: ["跟他们讲什么道法！抄家伙！", "二位兄长看着，某先登！"],
    deck: ["rage", "rage", "ramcall", "shieldup", "firerain", "snipe", "reinforce", "taunt", "drop", "heal"] },
  { id: "guanhai", name: "管亥", title: "青州渠帅", icon: "🪓",
    taunts: ["城里的米，借了！", "北海孔融都挡不住我，你算什么？"],
    deck: ["snipe", "snipe", "ramwall", "ramwall", "rage", "firerain", "drop", "shieldup", "taunt", "reinforce"] },
  { id: "heyi", name: "何仪", title: "汝南黄巾", icon: "🍗",
    taunts: ["兄弟们，看我干嘛？上啊！", "那个……容我想想下一步。", "别打脸！说了别打脸！", "等我大哥来了你们就完了！"],
    deck: ["taunt", "taunt", "taunt", "taunt", "reinforce", "reinforce", "dispel", "shieldup", "drop", "heal"] },
  { id: "zhangyan", name: "张燕", title: "黑山飞燕", icon: "🦅",
    taunts: ["黑山百万众，来去如飞燕！", "你守你的城，我抄我的道。"],
    deck: ["reinforce", "reinforce", "drop", "drop", "snipe", "sealone", "taunt", "rage", "shieldup", "firerain"] },
  { id: "yudu", name: "于毒", title: "黑山渠帅", icon: "☠️",
    taunts: ["名字就叫于毒，你说我玩什么路数？", "慢慢烂掉吧。"],
    deck: ["curse", "curse", "dispel", "dispel", "firerain", "sealone", "taunt", "heal", "snipe", "drop"] },
  { id: "bocai", name: "波才", title: "颍川渠帅", icon: "🔥",
    taunts: ["长社的火我记着呢——今天烧回来！", "风助火势，火助我威！"],
    deck: ["firerain", "firerain", "firerain", "rage", "drop", "snipe", "taunt", "shieldup", "ramwall", "sealone"] },
];
function foeShuffleDeck(L) { return [...L.deck].sort(() => Math.random() - 0.5); }
function foeLordFor(week, k) { return FOE_LORDS[(((week || 0) * 31 + (k || 0) * 7) >>> 0) % FOE_LORDS.length]; }
function foeCast(cid) {
  const F = state.foeLord, L = F.def, C = FOE_CARDS[cid];
  if (cid === "taunt") {
    addFloater(W / 2, 320, `${L.icon}${L.name}：「${pick(L.taunts)}」`, "#ffd2a8", 18);
    return;
  }
  addFloater(W / 2, 318, `${L.icon}${L.name}「${C.name}」`, "#ff8a8a", 20);
  addFloater(W / 2, 344, C.tip, "#ffb08a", 14);
  SFX.ult();
  C.cast();
}
function foeLordTick(dt) {
  if ((!state.diff || state.diff.week == null) && !state.endless) return;   // 讨伐周关+无尽先行
  if (state.phase !== "play") return;
  if (!state.foeLord) {   // 开局就立帅——渠帅是关卡环境，进关就该看见对手是谁（第8波才开手）
    const L = foeLordFor(state.diff.week, state.diff.k);
    state.foeLord = { def: L, deck: foeShuffleDeck(L), idx: 0, drawT: 30, told: false };
    addFloater(W / 2, 300, `${L.icon} 贼营立帅——${L.name}·${L.title}坐镇（第8波开手）`, "#ff9a7a", 19);
    return;
  }
  if (state.wave < 8) return;   // 8波前按兵不动：倒计时都不走
  const F = state.foeLord;
  F.drawT -= dt;
  if (!F.told && F.drawT <= 10) {   // 提前10秒亮牌：玩家有准备，牌也混脸熟
    F.told = true;
    const C = FOE_CARDS[F.deck[F.idx]];
    addFloater(W / 2, 300, `${F.def.icon}${F.def.name}亮出「${C.name}」`, "#ffb08a", 17);
    addFloater(W / 2, 324, `${C.tip}——10秒后生效`, "#c9a8ff", 13);
  }
  if (F.drawT <= 0) {
    F.drawT = state.endless && state.winWave ? 75 : 100;   // 深水区渠帅手更快
    F.told = false;
    foeCast(F.deck[F.idx++]);
    if (F.idx >= F.deck.length) { F.deck = foeShuffleDeck(F.def); F.idx = 0; }   // 抽完立即重洗——"下一张"永远可预告
  }
}
/* 大数中文缩写：结算"最重一击"出过1.28e19的20位裸数字（孙权永动机时代的遗产）——显示保险 */
const fmtBigN = n => n >= 1e16 ? (n / 1e16).toFixed(1) + "亿亿" : n >= 1e12 ? (n / 1e12).toFixed(1) + "万亿"
  : n >= 1e8 ? (n / 1e8).toFixed(1) + "亿" : n >= 1e5 ? (n / 1e4).toFixed(1) + "万" : String(Math.round(n));
/* —— 伤害统计（v7.17.5 用户点名：验证各种搭配的输出能力）——
   记账点在 damageEnemy 闸门（全场唯一伤害出口），来源=武将对象（子弹带owner/大招现场有u）
   或类目字符串；记实际扣血（含破盾、不含溢出）——一击1e19的秒杀流不虚报。
   实时看📊面板（累计排序+近10秒秒伤），结算看"输出前三" —— */
const DMG_CATS = { "@lord": ["👑", "主公"], "@fan": ["🛡️", "盾反"], "@fire": ["🔥", "火燎"],
  "@rock": ["🪨", "乱石"], "@relic": ["🧿", "遗宝"], "@field": ["🌋", "地形"], "@misc": ["🎲", "其他"] };
function dmgLedger(src, amt) {
  if (!state.dmgBook || !(amt > 0)) return;
  let k, icon, name;
  if (src && src.type) { k = src.type.id; icon = ""; name = src.type.name; }
  else { k = typeof src === "string" && DMG_CATS[src] ? src : "@misc"; [icon, name] = DMG_CATS[k]; }
  const b = state.dmgBook[k] ||= { icon, name, total: 0, log: [] };
  b.total += amt;
  const sec = Math.floor(state.time || 0), L = b.log;
  if (L.length && L[L.length - 1][0] === sec) L[L.length - 1][1] += amt; else L.push([sec, amt]);
  while (L.length && L[0][0] < sec - 10) L.shift();
}
function dmgTopStr(n = 3) {
  const es = Object.values(state.dmgBook || {}).filter(b => b.total > 0).sort((a, b) => b.total - a.total);
  const sum = es.reduce((s, b) => s + b.total, 0);
  if (!sum) return "";
  return es.slice(0, n).map(b => `${b.icon || ""}${b.name}${Math.round(b.total / sum * 100)}%`).join(" · ");
}
/* 暴击文案跟着青釭剑走：没剑=双倍暴击，有剑=三倍暴击（面板写的必须是真话） */
const critWord = () => hasRelic("qinggang") ? "三倍暴击" : "双倍暴击";
const critText = (s) => hasRelic("qinggang") ? s.replace("双倍暴击", "三倍暴击") : s;

/* 单位实际属性（含格子特质 / 战阵光环 / 兵种人数 / 全局buff）
   建筑学核心：枪兵战阵光环——相邻(含斜角)全兵种友军伤害+10%（多枪可叠，至+30%） */
/* 这些武将不靠属性打伤害（纯奶/纯buff/纯阻挡）：只拦机制——不进淬炼卡池、不打克制标、不亮被克警示（防废卡陷阱）。
   v7.14.2 起显示不归它管：三角克制时代属性人人有，角标/文字全员照画（用户点名统一） */
const ELEM_COSMETIC = new Set(["huatuo", "xiaoqiao", "lusu", "daqiao", "xuhuang", "caiwenji", "simayi", "xushu", "caohong", "granary", "dragonegg", "yinglong"]);
const elemMatters = (t) => !ELEM_COSMETIC.has(t.id);
/* 不打人的武将（盾/辅，dmg=0）：攻击类加成对他们没意义——不吃、不显示、枪阵不连线，防"被加成了个寂寞" */
const unitAttacks = (t) => t.dmg > 0;

/* 实际射程（含高地平原地形加成、烟瘴关减成）——开火、拖动虚线圈、信息面板圈统一用它，圈到哪箭就到哪 */
function effRange(t) {
  return t.rng ? t.rng * (t.cls === "archer" ? (1 + state.buffs.archerRange) * (state.field?.archerRng || 1) * (state.diff?.archerRngMul || 1) * (state.endlessMod?.mod?.archerRngMul || 1) : 1) : 0;
}
function getUnitMods(u, row, col) {
  const b = state.buffs, t = state.team;
  let dmgMul = b.dmg, rateMul = b.rate, crit = b.critCh, pierceAdd = 0;
  if (state.gewu) dmgMul *= 1.3;   // 歌舞升平（v5.9）：不早朝换来的全军攻击+30%（到局末）
  // 坐保江汉（v7.14 抬弱势主公）：刘表讨伐期间每多撑1波全军攻击+5%无上限——"无尽深潜找他"从人设做成数值
  if (state.ruler === "liubiao" && state.endless && state.winWave) dmgMul *= 1 + 0.05 * Math.max(0, state.wave - state.winWave);   // v7.14.1 加码 3%→5%
  // 暴政印记（v7.14.1 加码）：董卓每烧1点城血全军攻击+4%（本局永久）——烧血从自残变投资
  if (state.tyranny) dmgMul *= 1 + state.tyranny / 100;
  if (state.pofuBuff) dmgMul *= 1 + state.pofuBuff;   // 破釜沉舟（v7.16）：×1.5乘算，在猛攻封顶之外

  // 三角淬炼：该属性系加成
  dmgMul *= 1 + (b.elemBoost[u.type.elem] || 0);
  // 邓艾·居高临下（v7.6.0）：站在障碍石头上伤害×1.4（被洛阳铲/开山挖掉就失效——isObstacle实时判）
  if (u.type.id === "dengai" && row != null && isObstacle(row, col)) dmgMul *= 1.4;
  // 射程补偿：短腿兵种出手窗口小，伤害更高（枪兵尤甚；2026-07-04 玩家反馈近战开局弱，1.5→1.65）
  if (u.type.cls === "spear") dmgMul *= 1.65 * (1 + techLv("d_spear") * 0.03);
  else if (u.type.cls === "cav") dmgMul *= 1.15 * (1 + techLv("d_cav") * 0.03) * (1 + b.cavDmg);
  else if (u.type.cls === "archer") dmgMul *= (1 + techLv("d_archer") * 0.03) * (1 + b.archerDmg);
  if (u.type.cls === "support") rateMul *= 1 + techLv("d_supp") * 0.03;   // 医术操练：水波更勤
  // 羁绊：成员同场生效
  const bf = bondFx(u.type.id);
  dmgMul *= bf.dmg;
  rateMul *= bf.rate;
  // 遗宝：的卢马=骑兵伤害+30%，八卦阵图=全军攻速+10%
  if (hasRelic("dilu") && u.type.cls === "cav") dmgMul *= 1.3;
  if (hasRelic("bagua")) rateMul *= 1.1;
  // 竹林小道地形：骑兵冲锋更疼
  if (state.field?.cavMul && u.type.cls === "cav") dmgMul *= state.field.cavMul;
  if (state.field?.archerMul && u.type.cls === "archer") dmgMul *= state.field.archerMul;
  // 格子特质：所站之地的加成
  const trait = cellTrait(row, col);
  if (trait === "atk") dmgMul *= 1.15;
  else if (trait === "haste") rateMul *= 1.12;
  else if (trait === "crit") crit += 0.10;
  // 灵脉(elem)：v7.9.0 呼应三角克制——站这的武将普攻自带破敌(打谁都算克制×1.5)，在攻击时(atkElemOf)处理，不在这加平伤
  // 枪兵战阵光环：数相邻枪兵（自己除外），强化相邻全兵种友军
  if (col != null) {
    let auraN = 0;
    for (let rr = Math.max(0, row - 1); rr <= Math.min(GRID_ROWS - 1, row + 1); rr++)
      for (let cc = Math.max(0, col - 1); cc <= Math.min(GRID_COLS - 1, col + 1); cc++) {
        if (rr === row && cc === col) continue;
        const nb = state.slots[rr][cc];
        if (nb && nb.type.cls === "spear") auraN++;
      }
    if (auraN) dmgMul *= 1 + Math.min(3, auraN) * (0.10 + b.spearAura);
  }
  // 兵种人数
  const n = t.count[u.type.cls];
  if (u.type.cls === "spear")  { if (n >= 2) dmgMul *= 1.25; if (n >= 4) dmgMul *= 1.25; }
  if (u.type.cls === "archer") { if (n >= 2) rateMul *= 1.2;  if (n >= 4) rateMul *= 1.2; }
  if (u.type.cls === "cav")    { if (n >= 2) pierceAdd += 1;  if (n >= 4) dmgMul *= 1.4; }
  if (u.type.cls === "support"){ if (n >= 2) rateMul *= 1.15; if (n >= 4) rateMul *= 1.15; }  // 水波更勤
  if (hasRelic("liannu")) pierceAdd += 1;
  // 鲁肃天降粮草等全军增益
  if (state.armyBuff) dmgMul *= state.armyBuff.mul;
  if (state.foeCurseT > 0) dmgMul *= 0.75;   // 渠帅「咒缚」（v7.18.0）：全军攻击-25%
  // 主公技·征伐
  if (state.armyHaste) rateMul *= state.armyHaste.mul;
  // 绝技临时增益（马超/许褚）
  if (u.buffT > 0) rateMul *= u.buffMul;
  // 辅兵水波增益（多计时器，dmg/haste/crit 可共存）
  if (u.rbuffs) {
    if (u.rbuffs.dmg > 0) dmgMul *= 1.25;
    if (u.rbuffs.haste > 0) rateMul *= 1.22;
    if (u.rbuffs.crit > 0) crit += 0.15;
  }
  return { dmgMul, rateMul, crit, pierceAdd };
}

/* 武将血量：盾兵340铁壁（兀突骨420特厚），近战皮厚（枪120/骑100），辅兵90，弓兵脆皮60；升星+25%/星；英雄等级每级+8% */
function unitMaxHp(type, level = 1, rb = 0) {
  const base = type.hp ? type.hp
    : type.cls === "shield" ? 340
    : type.cls === "spear" ? 120
    : type.cls === "cav" ? 100
    : type.cls === "support" ? 90 : 60;
  return Math.round(base * (1 + (level - 1) * 0.25)
    * Math.pow(typeof state !== "undefined" && state?.relics?.some(r => r.id === "fenghuang") ? 1.55 : REBIRTH_MUL, rb)
    * heroLvMul(type.id) * (type.cls === "shield" ? 1.5 * (1 + techLv("d_shield") * 0.04) : 1)   // v7.18.5 盾兵加肉+15%→+50%：肉得像一堵墙才叫盾
    * (typeof state !== "undefined" && state?.bondSet ? bondFx(type.id).hp : 1));
}
function makeUnit(type, level = 1) {
  // 等级里程碑登场自带星（宽养的即战力转化）：4级+1、10级+1、20级+1、满级30级+1——
  // 宽养到高级的英雄一登场就是高星，转型补位不用在局内从头练兵
  if (level === 1) {
    const ol = heroLv(type.id);
    level = Math.min(MAX_LEVEL, 1 + (ol >= MILE_STAR1 ? 1 : 0) + (ol >= MILE_STAR2 ? 1 : 0)
      + (ol >= MILE_CRIT ? 1 : 0) + (ol >= HERO_LV_MAX ? 1 : 0));
    // 神将技·天命加身：弱卡封神登场补星（白+3/绿+2/蓝+1/金0）——没养过的冷门将封神当周也有即战力
    if (isShen(type.id)) level = Math.min(MAX_LEVEL, level + (SHEN_GIFT_STARS[heroRarity(type.id)] || 0));
    // 嫡系（v5.8）：跟对主公登场带资历——白/绿+2星、蓝/金+1星
    level = Math.min(MAX_LEVEL, level + kinGiftStars(type.id));
  }
  const shenGiftUlt = isShen(type.id) && (SHEN_GIFT_STARS[heroRarity(type.id)] || 0) >= 2;   // 白/绿神将：大招开局就绪
  return { type, level, rebirth: 0, cd: rand(0, 0.3), bounce: 1, buffT: 0, buffMul: 1, sealedT: 0,
    hp: unitMaxHp(type, level), hpMax: unitMaxHp(type, level),
    hurtFlash: 0, regenT: 0, rbuffs: {}, reflectT: 0,
    ultCd: ULTS[type.id] ? ULTS[type.id].cd * (shenGiftUlt || heroLv(type.id) >= MILE_ULT2 ? 0 : heroLv(type.id) >= MILE_FASTULT ? rand(0.08, 0.22) : rand(0.4, 0.7)) : 0,   // 15级开局转好大半、25级开局直接就绪（便利，长局无影响）；白/绿神将开局就绪
    _inRange: 0, _inColumn: 0 };
}
function unitDamage(u, mods) {
  const pd = u.type.id === "pangde" && u.hp < u.hpMax * 0.5 ? 1.5 : 1;   // 庞德抬棺：残血伤害+50%
  return Math.round(u.type.dmg * starDmgMul(u.level) * Math.pow(hasRelic("fenghuang") ? 1.55 : REBIRTH_MUL, u.rebirth || 0) * mods.dmgMul * heroLvMul(u.type.id) * pd);
}
function unitRate(u, mods) {
  return u.type.rate * Math.pow(0.93, u.level - 1) / mods.rateMul;
}
/* 骑兵·乱军冲杀（v4.23.0 职业机制）：场上活敌越多冲锋越猛——10个起步每多1个+2%，封顶+35%。
   收割定位：平时几乎无感（普通波次≤10人），深水人海/催战压上时兑现——正对"后期杀不动"的时刻。
   保守档位：classpull 模拟里骑兵堆本不弱(k7~13均≥基线)，起步8/顶50%时k11冲到+6.5波有超模苗头→收到10/35% */
function cavCrowdMul() {
  let n = 0;
  for (const e of state.enemies) if (!e.dead && e.y > -10) n++;
  return 1 + Math.min(0.35, 0.02 * Math.max(0, n - 10));
}

/* ---------- 三选一卡池 ---------- */
/* 敌情标签：武将/淬炼卡按本关"怕什么/抗什么"打标——绿标=对症，红标=吃瘪 */
function elemTagFor(elem, foes) {
  if (!foes) return { tag: null, tagBad: false, dw: 0 };
  if (!foes.tri) return { tag: null, tagBad: false, dw: 0 };
  if (TRI_KE[elem] === foes.tri) return { tag: null, tagBad: false, dw: 10 };   // 克这州的贼：暗中加权（明标已退役，玩家自己看三角图例）
  if (TRI_KE[foes.tri] === elem) return { tag: null, tagBad: false, dw: -5 };   // 被克：暗中降权
  return { tag: null, tagBad: false, dw: 0 };
}
/* 主公技对症表：本关规则→哪个主公技好使（卡池加权+绿标，选卡跟着关卡走） */
/* LORD_COUNTER（军令→好使的主公技）已随参悟卡退役；题面适配写在各主公 desc 里让玩家自己选 */
function buildCardPool() {
  const pool = [];
  const empties = emptySlots();
  const units = allUnits();
  const owned = new Set(units.map(u => u.type.id));
  const foes = curFoesNow();   // v5.4.2：跟着当前波实情走（无尽深水轮换后别再按开局题面偏卡）

  if (empties.length) {
    for (const t of availableGenerals()) {
      if (owned.has(t.id)) continue;
      // 能凑兵种人数的武将权重更高；属性对上本关敌情的加权并打标（吃瘪的降权仍可选）
      let w = 8;
      if (state.team.count[t.cls] === 1 || state.team.count[t.cls] === 3) w += 4;
      const et = elemMatters(t) ? elemTagFor(t.elem, foes) : { tag: null, tagBad: false, dw: 0 };
      // 羁绊提示：搭子已上阵，上他就点亮 → 绿标加权
      const bb = BONDS.find(x => x.members.includes(t.id) && x.members.every(m => m === t.id || owned.has(m)));
      const shen = isShen(t.id);   // 本期神将：加权+金标，把每期点的6人往玩家手里递
      const kin = isKin(t.id);     // 主公嫡系（v5.8）：加权+「亲」标——自家班底在牌桌上更常见
      w = Math.max(2, w + et.dw + (bb ? 8 : 0) + (shen ? 6 : 0) + (kin ? 6 : 0));
      const bondTag = bb ? `🔗成羁绊「${bb.name}」!` : null;
      pool.push({
        kind: "unit", type: t, weight: w,
        title: `${shen ? "神·" : ""}${t.name}出征`,
        icon: null, unitType: t, cls: t.cls,
        tag: (shen ? "👼本期神将!" : null) || bondTag || (kin ? `🤝亲军·登场+${kinGiftStars(t.id)}星` : null) || et.tag,
        tagBad: shen || bondTag || kin ? false : et.tagBad,
        info: `${ELEMENTS[t.elem].icon}${ELEMENTS[t.elem].name}系 · ${CLASSES[t.cls].icon}${CLASSES[t.cls].name}`,
        infoColor: ELEMENTS[t.elem].color,
        lvN: heroLv(t.id),
        desc: critText(t.desc),
      });
    }
  }
  const seen = new Set();
  const NOT_HERO = new Set(["granary", "egg", "dragon"]);   // 练兵是武将的事：粮仓走"扩建"、龙蛋走"温养"（有掷骰）、应龙没有星
  for (const u of units) {
    if (u.level >= MAX_LEVEL || seen.has(u.type.id) || NOT_HERO.has(u.type.cls)) continue;
    seen.add(u.type.id);
    // 和 applyCard 一致：升的是同名武将里星级最低的那个，卡面直接写升完几星
    let low = u;
    for (const v of units)
      if (v.type.id === u.type.id && v.level < MAX_LEVEL && v.level < low.level) low = v;
    pool.push({
      kind: "upgrade", typeId: u.type.id, weight: 13, stars0: low.rebirth || 0, lvN: heroLv(u.type.id),
      info: `${ELEMENTS[u.type.elem].icon}${ELEMENTS[u.type.elem].name}系 · ${CLASSES[u.type.cls].icon}${CLASSES[u.type.cls].name}`,
      infoColor: ELEMENTS[u.type.elem].color,
      title: `${shenName(u.type.id, u.type.name)}练兵`,
      icon: null, unitType: u.type, cls: u.type.cls,
      stars: low.level + 1,   // 卡面直接画升完的星数
      // 盾/辅不打伤害，"伤害×1.9"对他们是废话——按兵种写真话；6星起是升华星×1.4
      desc: u.type.cls === "shield" ? (u.type.id === "wutugu" ? "更耐打，毒雾更毒" : "更耐打，反伤更疼")
        : u.type.cls === "support" ? "水波更勤快，人更耐打"
        : low.level + 1 > 10 ? "二阶升华：伤害×1.3" : low.level + 1 > 5 ? "升华星：伤害×1.4" : `伤害×1.9`,
    });
  }
  // —— 局内转生卡已退役（v5.2）：转生外迁到局外（图鉴里花突破石转生扩上限）；
  //    5星以上的后期练兵坑由6~10星「升华星」接棒（伤害×1.4/星，练兵卡直接继续升） ——
  // —— 通用军略（v4.0.1超模修复：全部封顶，到顶退出卡池——无尽293级+800%伤害的事故不能再有；
  //      招贤纳士的顶最要紧：经验加成喂出更多卡、更多卡再加经验，是永动机的芯） ——
  const b = state.buffs;
  if (b.dmg < 3)
    pool.push({ kind: "buff", buff: "dmg", val: 0.25, weight: 9, title: "全军猛攻",
      icon: "⚔️", desc: "全军伤害+25%（叠到+200%封顶）" });
  if (b.rate < 2)
    pool.push({ kind: "buff", buff: "rate", val: 0.2, weight: 9, title: "击鼓进军",
      icon: "🥁", desc: "全军出手快+20%（叠到+100%封顶）" });
  if (b.critCh < 0.5)
    pool.push({ kind: "buff", buff: "critCh", val: 0.1, weight: 7, title: "青囊秘术",
      icon: "💥", desc: `多10%机会${critWord()}（叠到50%封顶）` });
  if (b.xpGain < 2)
    pool.push({ kind: "buff", buff: "xpGain", val: 0.25, weight: 6, title: "招贤纳士",
      icon: "📜", desc: "杀敌经验+25%（叠到+100%封顶）" });
  if (b.ultHaste < 0.48)
    pool.push({ kind: "buff", buff: "ultHaste", val: 0.12, weight: 8, title: "神机妙算",
      icon: "🧠", desc: "武将大招转快12%（有封顶）" });
  // —— 主公技参悟卡已退役（v5.0 主公府）：局内不成长，威力=局外主公等级映射 ——
  // —— 兵种军略（只在阵中有该兵种时出现；v4.0.1超模修复：一律封顶，到顶退出卡池） ——
  const cnt = state.team.count;
  if (cnt.spear >= 1 && b.spearAura < 0.2)   // 封顶0.5→0.2（枪辅流200%修正：单枪光环上限+180%→+90%）
    pool.push({ kind: "buff", buff: "spearAura", val: 0.05, weight: 8, title: "战阵精修",
      icon: "🔱", desc: "枪兵带人变强再+5%（有封顶）" });
  if (cnt.cav >= 1 && b.cavWide < 100)
    pool.push({ kind: "buff", buff: "cavWide", val: 10, weight: 8, title: "铁骑列装",
      icon: "🐎", desc: "骑兵冲得更宽+10（有封顶）" });
  if (cnt.cav >= 1 && b.cavDmg < 1.2)
    pool.push({ kind: "buff", buff: "cavDmg", val: 0.12, weight: 8, title: "冲势如虹",
      icon: "🐎", desc: "骑兵伤害+12%（叠到+120%封顶）" });
  if (cnt.archer >= 1 && b.archerDmg < 1.0)
    pool.push({ kind: "buff", buff: "archerDmg", val: 0.10, weight: 8, title: "箭术精修",
      icon: "🏹", desc: "弓兵伤害+10%（叠到+100%封顶）" });
  if (cnt.shield >= 1 && b.shieldReflect < 0.1)
    pool.push({ kind: "buff", buff: "shieldReflect", val: 0.01, weight: 8, title: "荆棘重甲",
      icon: "🛡️", desc: "盾兵反弹更疼 +25%（有封顶）" });
  if (cnt.support >= 1 && b.rippleRad < 175)
    pool.push({ kind: "buff", buff: "rippleRad", val: 35, weight: 8, title: "波纹深远",
      icon: "🎐", desc: "辅兵那圈更大+35（有封顶）" });
  // —— 开山凿石：清障露出地形特质（障碍越多越急需）。董卓局变洛阳铲：存铲子自己挑着挖（v7.0） ——
  if (state.obstacles.size > 0)
    pool.push(state.ruler === "dongzhuo"
      ? { kind: "terrain", weight: state.obstacles.size >= 6 ? 16 : 8, title: "洛阳铲",
          icon: "🪏", desc: "存一把铲子——想挖哪块自己挑，还可能挖出陪葬金" }
      : { kind: "terrain", weight: state.obstacles.size >= 6 ? 16 : 8, title: "开山凿石",
          icon: "🧹", desc: "炸掉 1 块石头，露出宝地" });
  else {
    const mg = Math.min(150, 25 + state.wave);   // 犒赏跟波次走：73波的人别再拿25金
    pool.push({ kind: "merit", weight: 5, val: mg, title: "犒赏三军",
      icon: "💰", desc: `金币+${mg}，落袋为安` });
  }
  // —— 屯田粮仓（v5.0 归曹操专属）：带曹操才有这条经济线——占一格自动攒经验，产量随曹操等级涨 ——
  if (state.ruler === "caocao") {
    let lowG = null;
    for (const u of units)
      if (u.type.cls === "granary" && u.level < GRANARY_MAX && (!lowG || u.level < lowG.level)) lowG = u;
    if (lowG)
      pool.push({ kind: "granary", weight: 13, title: "粮仓扩建", icon: "🌾",
        cls: "granary", stars: lowG.level + 1, desc: "产粮×1.6" });
    else if (empties.length)
      pool.push({ kind: "granary", weight: units.some(u => u.type.cls === "granary") ? 9 : 15,
        title: "屯田粮仓", icon: "🌾",
        cls: "granary", desc: "产粮喂旁边武将升星，敌人能拆它" });
  }
  // —— 应龙之卵（v5.0 归刘表专属）：破顶的风险投资——无尽一律进池（蛋就是无尽冲分的玩点，头一次还保底见蛋）；
  //    平推局要老手门槛（打赢8仗）且第10波起，别把新手的选卡池搅浑 ——
  if (state.ruler === "liubiao" && (state.endless || (meta.wins >= 8 && state.wave >= 10))) {
    const eggReady = units.find(u => u.type.cls === "egg" && u.level >= EGG_MAX);
    const eggGrow = units.find(u => u.type.cls === "egg" && u.level < EGG_MAX);
    if (eggReady)
      pool.push({ kind: "egg", sub: "awaken", weight: 14, title: "应龙觉醒", icon: "🐉",
        cls: "dragon", desc: "破壳！觉醒应龙，火力锚着你的顶星武将" });
    else if (eggGrow)
      pool.push({ kind: "egg", sub: "grow", weight: 14, title: "温养龙蛋", icon: "🥚",
        cls: "egg", stars: eggGrow.level + 1,
        desc: `把握${Math.round(hatchChance(eggGrow) * 10)}成，败了白搭` });
    else if (empties.length && !units.some(u => u.type.cls === "egg") && state.dragonN < 2)
      pool.push({ kind: "egg", sub: "place", weight: 8, title: "天降龙蛋", icon: "🥚",
        cls: "egg", desc: "孵着就每秒吐纳经验（喂到高阶吐得更多），三阶觉醒成应龙——经验引擎+后期战力（一局最多两条）" });
  }
  // —— 三角淬炼（针对阵中已有属性；克本州贼的那系暗中加权） ——
  const ownedElems = [...new Set(units.filter(u => elemMatters(u.type)).map(u => u.type.elem))];
  for (const el of ownedElems) {
    const cur = state.buffs.elemBoost[el] || 0;
    if (cur >= 0.9) continue;
    const et = elemTagFor(el, foes);
    pool.push({
      kind: "elem", elem: el, val: 0.3, weight: Math.max(3, 7 + et.dw),
      title: `${ELEMENTS[el].name}淬炼`,
      icon: ELEMENTS[el].icon, tag: et.tag, tagBad: et.tagBad,
      desc: `${ELEMENTS[el].icon}${ELEMENTS[el].name}系伤害 +30%`,
    });
  }
  if (state.buffs.extraShot < 2 && cnt.archer >= 1)
    pool.push({ kind: "buff", buff: "extraShot", val: 1, weight: 4, title: "万箭齐发",
      icon: "🌠", desc: "弓兵多射一箭" });
  if (state.baseHP < state.baseHPMax)
    pool.push({ kind: "heal", weight: 8, title: "修筑城防",
      icon: "🏯", desc: "城墙补3点血" });
  // —— 主公亲射强化（v7.15 用户点名：主公普攻可养成）：伤害卡叠到+200%封顶（5张），攻速卡叠到间隔40%封顶 ——
  //    v7.17.3 孙权130波挂机事故：无上限伤害卡是全场唯一不退池的卡，深水区其他卡到顶退光后
  //    乐不思蜀就纯喂它，乘上亲射的3%目标血=无视1.18复利的永动机——回归 v4.0.1「全部封顶、到顶退池」铁律
  if (state.ruler) {
    const atkName = state.ruler === "gongsunzan" ? "城头强弩" : `亲射「${(LORD_ATK[state.ruler] || {}).name || "亲射"}」`;
    const rlName = (rulerOf() || {}).name || "主公";   // 👑角标+名字：一眼看出这卡是喂主公的，不是喂武将的
    if ((state.lordAtkBuff || 0) < 2)
      pool.push({ kind: "lordatk", weight: 7, title: "御驾亲征", icon: "🎯",
        tag: `👑主公·${rlName}`,
        desc: `${rlName}的${atkName}伤害+40%（叠到+200%封顶${state.lordAtkBuff ? `，已+${Math.round(state.lordAtkBuff * 100)}%` : ""}）` });
    if ((state.lordAtkGap || 1) > 0.4)
      pool.push({ kind: "lordhaste", weight: 5, title: "神机连弩", icon: "⚙️",
        tag: `👑主公·${rlName}`,
        desc: `${rlName}的${atkName}出手快25%${state.lordAtkGap < 1 ? `（现间隔×${state.lordAtkGap.toFixed(2)}）` : ""}` });
  }
  // —— 彩蛋常青卡（v5.5.1 用户拍板：不等抽光、全程低权重在池，抽光后权重抬高凑热闹）——
  //    rollCards 同名去重=每张一桌最多一张，池底还有犒赏/战鼓垫着，绝不会三张全是自刎
  const drained = pool.length < 3;   // 抽光判定先拍：只看正经卡（锦囊/破釜/偷梁是战术层，不算）
  // —— 永久战术卡（v7.16 三改）：一局各一张，每张锚定一个流派吃协同——强弱取决于你的build ——
  if (!state.luanshiOn && state.obstacles.size > 0)
    pool.push({ kind: "tacperm", tp: "luanshi", weight: 6, title: "乱石穿空", icon: "🪨",
      desc: `此后每波贼上齐时，每块障碍向最近的贼砸一击（现有${state.obstacles.size}块）——石头是弹药，挖掉就没了` });
  if (!state.huoshaoOn && (allUnits().some(u => u.type.burn || u.type.firebrand || u.type.id === "huanggai") || state.ruler === "dongzhuo"))
    pool.push({ kind: "tacperm", tp: "huoshao", weight: 6, title: "火烧连营", icon: "🔥",
      desc: "此后着火的贼死亡时爆燃：炸伤周围还把火传过去——火越多，营越连" });
  if (!state.zhanshouOn && state.ruler)
    pool.push({ kind: "tacperm", tp: "zhanshou", weight: 6, title: "擒贼擒王", icon: "🎯",
      desc: "此后精锐/贼首一登场就挨主公一记重击（威力=亲射×5——御驾亲征/神机连弩/亲兵都算数）" });
  if (!state.luojingOn)
    pool.push({ kind: "tacperm", tp: "luojing", weight: 6, title: "落井下石", icon: "🕳️",
      desc: "受制的贼（减速/眩晕/恐惧/催眠/魅惑/江里泡着）挨打+30%——控得越多赚得越多" });
  if (!state.shuiyanOn)
    pool.push({ kind: "tacperm", tp: "shuiyan", weight: state.ruler === "sunquan" ? 8 : 5, title: "水淹七军", icon: "🌊",
      desc: state.ruler === "sunquan" ? "和都督的江合流成长江天堑：每波起江7秒·挨打多40%·捞货照算——坐断东南的完全体"
        : "此后每波贼进场自动拦腰起江4秒：变慢40%·挨打多25%——和落井下石是一对" });
  // 破釜沉舟：主动砸锅换乘算输出（不毁三星），一局只有一次——
  // v7.16 用户抓虫：首版+25%和全军猛攻平价还倒贴城墙，纯坑卡；改成猛攻+200%封顶之外的独立×1.5乘区
  if (state.baseHPMax > 6 && !(state.pofuN || 0))
    pool.push({ kind: "pofu", weight: 5, title: "破釜沉舟", icon: "🍳",
      desc: "城墙上限-2，全军伤害×1.5——乘在所有加成外面、不占猛攻封顶（一局仅此一釜）" });
  // 偷梁换柱：重摸这一手（池子真抽干就别发了——换来换去都是池底那几张）
  if (!drained)
    pool.push({ kind: "reroll", weight: 5, title: "偷梁换柱", icon: "🎲",
      desc: "这手牌全不要，当场重摸一手" });
  // 校场演武（v7.15.3）：常青经济卡——立刻升一级再摸一手；放抽光判定后面，别把"池干"顶成"池没干"
  pool.push({ kind: "levelup", weight: drained ? 6 : 4, title: "校场演武", icon: "🎓",
    desc: "全军演武：立刻升一级，当场再摸一手牌" });
  pool.push({ kind: "seppuku", weight: drained ? 6 : 3, title: "自刎归天",
    icon: "🗡️", desc: "拔剑自刎当场收兵，本局分数+10%——见好就收" });
  pool.push({ kind: "dance", weight: drained ? 6 : 3, title: "乐不思蜀",
    icon: "💃", desc: "此间乐：全军攻击+30%，自动抽卡挂机到局末——点屏幕随时回神" });
  if (drained)
    pool.push({ kind: "drums", weight: 10, title: "战鼓雷动",
      icon: "🥁", desc: "全军攻速+30%，就15秒，过时不候" });
  return pool;
}

function rollCards() {
  // 乐不思蜀（v7.12）：不再压制弹卡——牌照常弹，挂机引擎自动抽
  const pool = buildCardPool();
  const granaryCard = pool.find(cd => cd.kind === "granary");   // 保底要用：三选一权重太稀，核心经济选择不能靠脸抽
  const eggCard = pool.find(cd => cd.kind === "egg");
  const shenCards = pool.filter(cd => cd.kind === "unit" && isShen(cd.type.id));   // 神将保底候选（还没上阵的本期神将）
  // 选过越多次的卡越少见，压后期重复感（孵蛋卡豁免：温养要连抽十来张，衰减会把破顶路衰没）
  for (const cd of pool) {
    if (cd.kind === "egg") continue;
    const n = state.cardPicks[cd.title] || 0;
    if (n) cd.weight = Math.max(1, cd.weight / (1 + n * 0.4));
  }
  const cards = [];
  let nPick = hasRelic("yiji") ? 4 : 3;
  if (state.widePicks > 0) { nPick = 5; state.widePicks--; }   // 门生故吏：这次五选一
  for (let i = 0; i < nPick && pool.length; i++) {
    let total = pool.reduce((s, c) => s + c.weight, 0);
    let roll = Math.random() * total;
    let idx = 0;
    for (; idx < pool.length; idx++) {
      roll -= pool[idx].weight;
      if (roll <= 0) break;
    }
    idx = Math.min(idx, pool.length - 1);
    cards.push(pool[idx]);
    const t = pool[idx].title;
    for (let j = pool.length - 1; j >= 0; j--)
      if (pool[j].title === t) pool.splice(j, 1);
  }
  // 屯田粮仓保底：第2波起的头一次选卡必见一次——选不选随玩家，但每局都得正面见到这个选择
  if (!state.granaryOffered) {
    if (cards.some(cd => cd.kind === "granary")) state.granaryOffered = true;
    else if (state.wave >= 2 && granaryCard) {
      cards[cards.length - 1] = granaryCard;
      state.granaryOffered = true;
    }
  }
  // 应龙之卵保底：头一次进无尽的选卡必见一次（破顶工具得让人知道有；换掉一张非粮仓的）
  if (!state.eggOffered) {
    if (cards.some(cd => cd.kind === "egg")) state.eggOffered = true;
    else if (state.endless && eggCard) {
      let ri = cards.length - 1;
      while (ri > 0 && cards[ri].kind === "granary") ri--;
      cards[ri] = eggCard;
      state.eggOffered = true;
    }
  }
  // 神将保底（v4.24.0）：连着3轮没见神将卡→下一轮必塞一张——神将是每期主推玩法，不能全靠脸抽
  if (cards.some(cd => cd.kind === "unit" && isShen(cd.type.id))) state.shenDry = 0;
  else if (shenCards.length) {
    state.shenDry = (state.shenDry || 0) + 1;
    if (state.shenDry >= 3) {
      let ri = cards.length - 1;
      while (ri > 0 && (cards[ri].kind === "granary" || cards[ri].kind === "egg")) ri--;
      cards[ri] = shenCards[Math.floor(Math.random() * shenCards.length)];
      state.shenDry = 0;
    }
  }
  if (!cards.length) {   // 全部军略到顶、练兵满星后可能真发不出牌：这级白升，别弹空面板锁死
    state.cards = null;
    return;
  }
  state.cards = cards;
  state.cardAnim = 0;
  state.cardsAt = performance.now();   // 开牌保护期起点（v5.5.4：突然弹牌0.35秒内不吃点击）
}

/* 开局选将：三名随机武将（盾/辅最多1个，保证至少2个输出兵种，避免无伤害死局） */
function startPick() {
  // 开局选将：对上本关敌情的微加权（只是偏一偏——全给克制将就成新的自动驾驶了），卡面打标让玩家自己挑；
  // 嫡系微加权（v5.8）：自家班底更容易出现在开局三选
  const foes = curFoesNow();   // v5.4.2：跟着当前波实情走（无尽深水轮换后别再按开局题面偏卡）
  const bias = t => (!foes || !elemMatters(t) ? 0
    : TRI_KE[t.elem] === foes.tri ? 0.15 : TRI_KE[foes.tri] === t.elem ? -0.12 : 0)
    + (isKin(t.id) ? 0.18 : 0);
  const shuffled = [...availableGenerals()]
    .map(t => ({ t, s: Math.random() + bias(t) }))
    .sort((a, b) => b.s - a.s)
    .map(x => x.t);
  const opts = [];
  let nonDps = 0;
  for (const t of shuffled) {
    const isDps = t.cls !== "shield" && t.cls !== "support";
    if (!isDps) {
      if (nonDps >= 1) continue;
      nonDps++;
    }
    opts.push(t);
    if (opts.length >= 3) break;
  }
  state.cards = opts.map(t => {
    const et = elemMatters(t) ? elemTagFor(t.elem, foes) : { tag: null, tagBad: false };
    return {
      kind: "unit", type: t,
      // 开局选将也要认得出神将（2026-07-10 修复：这里是独立拼卡路径，之前只改了局内三选一）；嫡系同理（v5.8）
      title: `${shenName(t.id, t.name)}出征`, icon: null, unitType: t, cls: t.cls,
      tag: isShen(t.id) ? "👼本期神将!" : isKin(t.id) ? `🤝亲军·登场+${kinGiftStars(t.id)}星` : et.tag,
      tagBad: isShen(t.id) || isKin(t.id) ? false : et.tagBad,
      info: `${ELEMENTS[t.elem].icon}${ELEMENTS[t.elem].name}系 · ${CLASSES[t.cls].icon}${CLASSES[t.cls].name}`,
        infoColor: ELEMENTS[t.elem].color,
        lvN: heroLv(t.id),
        desc: critText(t.desc),
    };
  });
  state.cardAnim = 0;
  state.cardsAt = performance.now();
  state.phase = "pickStart";
}


/* 选关（周赛季）：州郡地图上下篇各16关（v7.2.0）——每关标强度，周一全图换新。
   不逐关解锁：轻度玩家打得动前排边郡，北边硬茬留给追分的人——差距摆在图上 */
const PICK_BACK_BTN = { x: W / 2 - 80, y: 744, w: 160, h: 42 };
function gotoLevelSelect() {
  rolloverWeek(meta);
  settleLastWeek();   // 有上周成绩没发榜就去结（拿不到榜单会留着下次再试）
  achSweep();         // 计数成就兜底巡检（比如排名奖把金币顶过了档）
  weekMapTab = -1;    // 每次进图重新聚焦前线所在篇（v7.2.0 上下篇）
  state.phase = "pickDiff";
  netFetchBoard();
}
/* 每篇16州共用这张位置表（k%16）：上篇南方边郡杀到广宗，下篇陈留一路打进洛阳 */
const STATE_POS = [
  { x: 168, y: 650 }, { x: 76, y: 578 },  { x: 356, y: 630 }, { x: 244, y: 568 },   // 交州 益州 扬州 荆州
  { x: 66, y: 430 },  { x: 396, y: 496 }, { x: 282, y: 476 }, { x: 348, y: 392 },   // 凉州 徐州 豫州 兖州
  { x: 414, y: 302 }, { x: 206, y: 416 }, { x: 118, y: 336 }, { x: 176, y: 258 },   // 青州 司隶 雍州 并州
  { x: 404, y: 176 }, { x: 250, y: 186 }, { x: 322, y: 250 }, { x: 310, y: 132 },   // 幽州 常山 巨鹿 广宗
];
const STATE_R = 26;
let pickMsg = null;   // 地图上的小提示条（点了没解锁的州）
let weekMapTab = -1;  // 讨贼地图四区（v7.11）：0东 1南 2西 3北；-1=进图时自动跳到前线所在区
const WEEK_TAB_RC = [0, 1, 2, 3].map(i => ({ x: 48 + i * 97, y: 706, w: 93, h: 34 }));   // 挂地图底部：顶部被神将行占满、广宗节点又在y132
let statePop = null;  // 州详情弹窗 { k }——题面/推荐战力/奖励都在窗里看，窗里点进军才开打
let shenPop = false;  // 神将规则弹窗：点地图上的神将行打开——是谁/多强/什么时候换，一窗说清
let lordPop = false;  // 主公面板：点👑名牌或圆形大招图标弹出——大招介绍/自动时机/立刻施放都在这
let lordPopCast = null;   // 面板里"立刻施放"按钮热区（就绪时才有）
/* 自动时机大白话（面板里讲清楚：什么时候会自己放） */
const LORD_AUTO_TIPS = {
  wuxing: "场上贼≥8个", bingfeng: "场上贼≥6个", taoyuan: "有兄弟掉到半血，或贼冲到城墙跟前（金身期间不叠）",
  jiejiang: "江区里贼≥4个", mensheng: "CD一转好就铺门路",
  baima: "有特种/贼首上场，或贼≥8个", fenluo: "贼≥6个且城血≥5（残血不烧）",
  jianhao: "场上≥5人且有星≤3的祭品",
};
const STATE_GO_BTN = { x: W / 2 - 90, y: 0, w: 180, h: 42 };   // y 画弹窗时定
const SHEN_LINE_BTN = { x: 20, y: 88, w: W - 40, h: 22 };      // 地图上的神将行：点开规则弹窗
let meritPop = false;  // 战功手记（v7.11）：势力值的账本——破城进度合计+十大功绩逐条
const MERIT_BTN = { x: W - 104, y: 20, w: 88, h: 30 };         // 地图右上角的战功手记按钮（带框带底，一眼是个按钮）
function drawDiffPick() {
  rolloverWeek(meta);   // 看图这一刻跨过周一：当场换图（上周成绩自动进待发榜）
  ctx.fillStyle = "rgba(20,14,6,.94)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  ctx.font = "bold 25px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`🗺️ 讨贼地图 · 第${meta.week - WEEK0 + 1}期`, W / 2, 42);
  // v7.11 四区：进图自动跳到前线所在区
  if (weekMapTab < 0) {
    let front = 0;
    for (let k = 0; k < WEEK_N; k++) if (!meta.weekClears[k]) { front = k; break; }
    weekMapTab = Math.floor(front / 16);
  }
  const wth = weekThemeOf(meta.week, weekMapTab);
  // 头部三行做减法（2026-07-08 用户"排版拥挤字太小"）：军略只留短白话、字加大、废话删光
  ctx.font = "bold 16px sans-serif";
  ctx.fillStyle = "#ffb84a";
  ctx.fillText(`${wth.icon} ${wth.name}：${wth.short}`, W / 2, 64);
  const myPow = deckPower(), sc = weekScore();
  const nb = meta.weekBands || 0;
  ctx.font = "14px sans-serif";
  ctx.fillStyle = "#d5c9a8";
  ctx.fillText(`⚡战力 ${myPow}　🏅势力 ${sc}　${nb >= WEEK_BANDS.length ? "🎁奖已领完" : `🎁${WEEK_BANDS[nb].at}势力奖${WEEK_BANDS[nb].gold}💰`}`, W / 2, 84);
  // 战功手记按钮（右上角）：描边+底色和四区选项卡同款，看着就能点
  ctx.fillStyle = "rgba(30,24,12,.9)";
  roundRect(MERIT_BTN.x, MERIT_BTN.y, MERIT_BTN.w, MERIT_BTN.h, 8);
  ctx.fill();
  ctx.strokeStyle = "#ffd24a";
  ctx.lineWidth = 1.5;
  roundRect(MERIT_BTN.x, MERIT_BTN.y, MERIT_BTN.w, MERIT_BTN.h, 8);
  ctx.stroke();
  ctx.font = "bold 12px sans-serif";
  ctx.fillStyle = "#ffe8b0";
  ctx.fillText("📜 战功手记", MERIT_BTN.x + MERIT_BTN.w / 2, MERIT_BTN.y + 20);
  ctx.font = "bold 16px sans-serif";
  ctx.fillStyle = "#ffd24a";
  ctx.fillText(`👼神将·${shenNextInfo().day}换批：${shenIdsOf(shenPeriodNow()).map(id => GENERALS.find(g => g.id === id)?.name || id).join(" ")}`, W / 2, 103);
  // 四区选项卡（v7.11）：东/南/西/北各16城，四主题各自标注
  for (let tb = 0; tb < 4; tb++) {
    const rcT = WEEK_TAB_RC[tb], on = weekMapTab === tb;
    const thT = weekThemeOf(meta.week, tb);
    ctx.fillStyle = on ? "#5a4426" : "rgba(30,24,12,.85)";
    roundRect(rcT.x, rcT.y, rcT.w, rcT.h, 9);
    ctx.fill();
    ctx.strokeStyle = on ? "#ffd24a" : "rgba(140,125,95,.5)";
    ctx.lineWidth = on ? 2.5 : 1.5;
    roundRect(rcT.x, rcT.y, rcT.w, rcT.h, 9);
    ctx.stroke();
    const clearedN = Object.keys(meta.weekClears || {}).filter(k => Math.floor(+k / 16) === tb).length;
    ctx.font = "bold 12px sans-serif";
    ctx.fillStyle = on ? "#ffe8b0" : "#9a8f70";
    ctx.fillText(`${["东部", "南部", "西部", "北部"][tb]}${thT.icon}${clearedN}/16`, rcT.x + rcT.w / 2, rcT.y + 22);
  }
  const kOff = weekMapTab * 16;
  // 进军虚线：台阶顺序连出进军路线（逐州解锁，沿线往上打）
  ctx.strokeStyle = "rgba(255,228,90,.14)";
  ctx.lineWidth = 2;
  ctx.setLineDash([4, 7]);
  ctx.beginPath();
  STATE_POS.forEach((q, k) => k ? ctx.lineTo(q.x, q.y) : ctx.moveTo(q.x, q.y));
  ctx.stroke();
  ctx.setLineDash([]);
  // 该打哪：当前开着的没通关州加金框（逐州解锁，金框就是前线）
  let hint = -1;
  for (let k = 0; k < WEEK_N; k++) if (!meta.weekClears[k]) { hint = k; break; }
  for (let ki = 0; ki < 16; ki++) {
    const k = kOff + ki;
    const q = STATE_POS[ki], lv = makeWeekLevel(meta.week, k);
    const cleared = !!meta.weekClears[k];
    const locked = weekLocked(k);
    const boss = k % 2 === 1;
    if (locked) {
      // 没解锁：灰圈+锁，只留州名——题面（抗性/贼首/奖励）打到跟前再揭
      ctx.fillStyle = "rgba(26,22,14,.85)";
      ctx.beginPath();
      ctx.arc(q.x, q.y, STATE_R, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(120,110,90,.45)";
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(q.x, q.y, STATE_R, 0, Math.PI * 2);
      ctx.stroke();
      ctx.font = "13px sans-serif";
      ctx.fillStyle = "#6a6152";
      ctx.fillText("🔒", q.x, q.y - 5);
      ctx.font = "bold 12px 'Kaiti SC', 'STKaiti', serif";
      ctx.fillText(STATE_NAMES[k], q.x, q.y + 13);
      continue;
    }
    ctx.fillStyle = cleared ? "rgba(120,200,110,.15)" : "rgba(30,24,12,.92)";
    ctx.beginPath();
    ctx.arc(q.x, q.y, STATE_R, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = k === hint ? "#ffd24a" : cleared ? "#7ac86a" : lv.color;
    ctx.lineWidth = k === hint ? 3.5 : 2;
    ctx.beginPath();
    ctx.arc(q.x, q.y, STATE_R, 0, Math.PI * 2);
    ctx.stroke();
    ctx.font = "14px sans-serif";
    ctx.fillText(`${boss ? "👑" : ""}${lv.icon}`, q.x, q.y - 6);
    ctx.font = "bold 13px 'Kaiti SC', 'STKaiti', serif";
    ctx.fillStyle = cleared ? "#bfe8b0" : "#e8dcc0";
    ctx.fillText(STATE_NAMES[k], q.x, q.y + 12);
    // 节点下只留自己的战绩（威望星+城池贡献）——敌情/推荐战力/奖励收进点开的详情窗，地图清爽
    ctx.font = "bold 11.5px sans-serif";
    if (cleared) {
      const st = meta.weekStars[k] || 1, best = meta.weekBest[k];
      ctx.fillStyle = st === 3 ? "#ffd24a" : "#9adf5a";
      ctx.fillText(`${"★".repeat(st)}${"☆".repeat(3 - st)} ${best ? best.score + "势力" : ""}`, q.x, q.y + STATE_R + 13);
    }
    // 先锋（v7.11 原州牧）：这城全服讨伐最深的人——名字挂在城下，等你去抢
    const lord = weekLordOf(k);
    if (lord && NET.name && lord.name === NET.name) unlockAch("lordwin");
    if (lord) {
      ctx.font = "10.5px sans-serif";
      ctx.fillStyle = "#ffd24a";
      const nm = [...lord.name].length > 5 ? [...lord.name].slice(0, 5).join("") + "…" : lord.name;
      ctx.fillText(`⚔️${nm} 伐${lord.score}`, q.x, q.y + STATE_R + 26);
    }
  }
  ctx.textAlign = "center";
  if (pickMsg && pickMsg.t > 0) {
    pickMsg.t--;
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = "rgba(20,14,6,.92)";
    roundRect(W / 2 - 150, 96, 300, 30, 8);
    ctx.fill();
    ctx.fillStyle = "#ffb84a";
    ctx.fillText(pickMsg.text, W / 2, 116);
  }
  drawButton(PICK_BACK_BTN, "🏠 返回首页", "#5a4a3a");
  drawStatePop(myPow);
  drawWeekReport();
  drawShenPop();
  drawMeritPop();
}
/* 神将规则弹窗：是谁（6头像）/多强（等级翻倍）/什么时候换（周一周四+倒计时），一窗说清不让玩家猜 */
function drawShenPop() {
  if (!shenPop) return;
  const ids = shenIdsOf(shenPeriodNow());
  const sni = shenNextInfo();
  ctx.fillStyle = "rgba(12,9,4,.88)";
  ctx.fillRect(0, 0, W, H);
  const rc = { x: 28, y: 152, w: W - 56, h: 400 };
  ctx.fillStyle = "#241c10";
  roundRect(rc.x, rc.y, rc.w, rc.h, 16);
  ctx.fill();
  ctx.strokeStyle = "#ffd24a";
  ctx.lineWidth = 2.5;
  roundRect(rc.x, rc.y, rc.w, rc.h, 16);
  ctx.stroke();
  ctx.textAlign = "center";
  ctx.font = "bold 22px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText("👼 本期神将", W / 2, rc.y + 38);
  // 6人头像一排（名字在圆盘里，等级星条在圆盘下缘）
  const step = (rc.w - 24) / SHEN_N;
  ids.forEach((id, i) => {
    const g = GENERALS.find(x => x.id === id);
    if (g) drawShopDisc(g, rc.x + 12 + step * (i + 0.5), rc.y + 96, 24, false);
  });
  // 规则四句 + 换批倒计时（金字）
  ctx.font = "14px sans-serif";
  ctx.fillStyle = "#e8dcc0";
  ctx.fillText("每周一、周四 0点各换一批（与上批不重复）", W / 2, rc.y + 168);
  ctx.fillText("神将攻血大涨：每级加成 8%→16% 翻倍再+25%", W / 2, rc.y + 194);
  ctx.fillText("天命加身：卡越白登场星越高（白+3 绿+2 蓝+1）", W / 2, rc.y + 220);
  ctx.fillText("白/绿神将开局大招就绪 · 选卡3轮没见必给一张", W / 2, rc.y + 246);
  ctx.font = "bold 16px sans-serif";
  ctx.fillStyle = "#ffd24a";
  ctx.fillText(`⏳ 下次换批：${sni.day} 0点（还剩${sni.left}天）`, W / 2, rc.y + 288);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("排行榜和奖励仍按整周结算 · 点任意处关闭", W / 2, rc.y + rc.h - 16);
}
/* 战功手记（v7.11）：势力值的账本——总账一行、破城进度一行、十大功绩逐条列。
   每条功绩=城名+威望星+讨伐波数+讨伐值；不满十席的画虚位，满十席标出末席门槛（想入册就得超它） */
function drawMeritPop() {
  if (!meritPop) return;
  const wb = meta.weekBest || {};
  const items = Object.keys(wb).map(k => ({
    k: +k, stars: wb[k].stars || 1, waves: wb[k].endless || 0, guest: !!wb[k].guest,
    prog: cityProgOf(+k, wb[k]), taofa: cityTaofaOf(+k, wb[k]),
  }));
  const progSum = items.reduce((a, x) => a + x.prog, 0);
  const merits = items.filter(x => x.taofa > 0).sort((a, b) => b.taofa - a.taofa);
  const top = merits.slice(0, TAOFA_TOP_N);
  const meritSum = top.reduce((a, x) => a + x.taofa, 0);
  ctx.fillStyle = "rgba(12,9,4,.88)";
  ctx.fillRect(0, 0, W, H);
  const rc = { x: 26, y: 108, w: W - 52, h: 548 };
  ctx.fillStyle = "#241c10";
  roundRect(rc.x, rc.y, rc.w, rc.h, 16);
  ctx.fill();
  ctx.strokeStyle = "#ffd24a";
  ctx.lineWidth = 2.5;
  roundRect(rc.x, rc.y, rc.w, rc.h, 16);
  ctx.stroke();
  ctx.textAlign = "center";
  ctx.font = "bold 22px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText("📜 战功手记", W / 2, rc.y + 36);
  ctx.font = "bold 15px sans-serif";
  ctx.fillStyle = "#ffd24a";
  ctx.fillText(`势力值 ${progSum + meritSum} ＝ 破城进度 ${progSum} ＋ 十大功绩 ${meritSum}`, W / 2, rc.y + 64);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#a89a76";
  ctx.fillText(`破城进度：已破${items.length}城的 繁荣度×威望 全数入账 · 功绩只记讨伐最辉煌的十役`, W / 2, rc.y + 84);
  // 十大功绩逐条：城名 威望 讨伐波数 → 讨伐值
  ctx.textAlign = "left";
  const rowY = rc.y + 112, rowH = 27;
  for (let i = 0; i < TAOFA_TOP_N; i++) {
    const y = rowY + i * rowH;
    const m = top[i];
    const rowFont = i < 3 ? "bold 14px sans-serif" : "13.5px sans-serif";
    ctx.font = rowFont;
    if (m) {
      // v7.13：序号/城名/区序三段分开画——序号右对齐成列，区序小一号淡色缀后，不再挤成一坨
      const tag = `${["东", "南", "西", "北"][Math.floor(m.k / 16)]}${m.k % 16 + 1}`;   // 区+第几城，和地图四区页签对得上
      ctx.textAlign = "right";
      ctx.fillStyle = i < 3 ? "#ffd24a" : "#9adf5a";
      ctx.fillText(`${i + 1}.`, rc.x + 44, y);
      ctx.textAlign = "left";
      const name = STATE_NAMES[m.k];
      ctx.fillText(name, rc.x + 52, y);
      const nw = ctx.measureText(name).width;
      ctx.font = "11px sans-serif";
      ctx.fillStyle = "#8a7d5a";
      ctx.fillText(tag, rc.x + 52 + nw + 7, y);
      ctx.font = rowFont;
      ctx.fillStyle = "#e8dcc0";
      ctx.fillText(`${"★".repeat(m.stars)}${"☆".repeat(3 - m.stars)} 讨伐+${m.waves}波${m.guest ? "🍵" : ""}`, rc.x + 160, y);   // 🍵=客卿录的（×1.3已计入）
      ctx.textAlign = "right";
      ctx.fillStyle = i < 3 ? "#ffd24a" : "#c9bd9a";
      ctx.fillText(`${m.taofa}`, rc.x + rc.w - 24, y);
      ctx.textAlign = "left";
    } else {
      ctx.textAlign = "right";
      ctx.fillStyle = "#5a4f3a";
      ctx.fillText(`${i + 1}.`, rc.x + 44, y);
      ctx.textAlign = "left";
      ctx.fillText("—— 虚位以待 ——", rc.x + 52, y);
    }
  }
  ctx.textAlign = "center";
  ctx.font = "bold 13px sans-serif";
  ctx.fillStyle = "#8ad2ff";
  const footY = rowY + TAOFA_TOP_N * rowH + 12;
  if (merits.length > TAOFA_TOP_N)
    ctx.fillText(`末席门槛 ${top[TAOFA_TOP_N - 1].taofa} · 另有${merits.length - TAOFA_TOP_N}城讨伐值没排上——超过门槛就入册`, W / 2, footY);
  else if (merits.length)
    ctx.fillText(`还有 ${TAOFA_TOP_N - merits.length} 席虚位——通关后乘胜追击，讨伐值就能记上一功`, W / 2, footY);
  else
    ctx.fillText("还没有战功——破城后乘胜追击（打讨伐），战果记在这里", W / 2, footY);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("点一下关闭", W / 2, rc.y + rc.h - 16);
}
/* 城池详情弹窗（v7.11.1 模块化重排）：三个分区子卡片——⚔️敌情（打什么）/🏙️城池（值多少）/🎖️我的战绩（挣了多少），
   先锋一行做脚注；分区框+左对齐，一眼知道每行属于哪件事；进军按钮在窗里 */
function drawStatePop(myPow) {
  if (!statePop) return;
  const k = statePop.k, lv = makeWeekLevel(meta.week, k);
  const cleared = !!meta.weekClears[k];
  const rec = recPower(k), lord = weekLordOf(k);
  // —— 三个分区的内容 ——
  const secs = [];
  const enemy = { title: "⚔️ 敌情", rows: [
    { t: `贼是 ${ELEMENTS[lv.foes.tri].icon}${ELEMENTS[lv.foes.tri].name} · 带${ELEMENTS[triCounterOf(lv.foes.tri)].icon}${ELEMENTS[triCounterOf(lv.foes.tri)].name}克他`, c: "#5aff9a", f: "bold 15px sans-serif" },
    { t: `敌血×${lv.hpMul} · 杀${lv.killTarget}${lv.bossName ? ` · 👑${lv.bossName}` : ""}`, c: "#e8dcc0", f: "13.5px sans-serif" },
  ] };
  if (lv.rules.length)
    enemy.rows.push({ t: `⚠️ ${lv.rules.map(r => LEVEL_RULE_DEFS[r].short).join("、")}`, c: "#ffb84a", f: "bold 13.5px sans-serif" });
  enemy.rows.push({ t: `⚡ 推荐 ${rec} · 我的 ${myPow}${myPow >= rec ? "，够了" : "，还得练"}`, c: myPow >= rec ? "#9adf5a" : "#ff8a6a", f: "bold 13.5px sans-serif" });
  secs.push(enemy);
  secs.push({ title: "🏙️ 城池", rows: [
    { t: `繁荣度 ${weekLevelBase(k)} · ${cleared ? "🎁首胜奖已领" : `🎁首胜 ${lv.firstGold}💰`}`, c: "#e8dcc0", f: "bold 13.5px sans-serif" },
  ] });
  const mine = { title: "🎖️ 我的战绩", rows: [] };
  if (cleared) {
    const b = meta.weekBest[k] || { stars: meta.weekStars[k] || 1, endless: 0 };
    const taofa = cityTaofaOf(k, b);
    const inTop = taofa > 0 && taofa >= taofaCut(meta.weekBest);
    mine.rows.push({ t: `威望 ${"★".repeat(b.stars || 1)}${"☆".repeat(3 - (b.stars || 1))} · 此城贡献 ${cityProgOf(k, b) + taofa}势力`, c: "#9adf5a", f: "bold 13.5px sans-serif" });
    mine.rows.push({ t: b.endless ? `讨伐 +${b.endless}波 · 讨伐值 ${taofa}${inTop ? " · 🏅十大功绩" : ""}` : "还没打过讨伐——通关后选乘胜追击", c: b.endless ? (inTop ? "#ffd24a" : "#e8dcc0") : "#8a7d5a", f: "13.5px sans-serif" });
  } else {
    mine.rows.push({ t: "未破城——破城后威望和讨伐记在这", c: "#8a7d5a", f: "13.5px sans-serif" });
  }
  secs.push(mine);
  // —— 布局：头74 + Σ(分区=题22+行×24+底8) + 间隔10 + 先锋26 + 按钮区70 ——
  const ROW_H = 24, SEC_HEAD = 22, SEC_PAD = 8, SEC_GAP = 10;
  const secH = sec => SEC_HEAD + sec.rows.length * ROW_H + SEC_PAD;
  const bodyH = secs.reduce((a, x) => a + secH(x), 0) + SEC_GAP * (secs.length - 1);
  const px = W / 2 - 170, pw = 340;
  const ph = 74 + bodyH + 26 + 70;
  const py = Math.max(96, Math.round((H - ph) / 2) - 40);
  ctx.fillStyle = "rgba(0,0,0,.6)";
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = "rgba(30,24,12,.97)";
  roundRect(px, py, pw, ph, 14);
  ctx.fill();
  ctx.strokeStyle = lv.color;
  ctx.lineWidth = 2;
  roundRect(px, py, pw, ph, 14);
  ctx.stroke();
  // 头：城名 + 章节/地形
  ctx.textAlign = "center";
  ctx.font = "bold 24px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`${lv.icon} ${STATE_NAMES[k]}`, W / 2, py + 34);
  const f = FIELDS.find(x => x.id === lv.field);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText(`${CHAPTERS[lv.ch].name}${f ? ` · ${f.icon}${f.name}${f.tip ? `·${f.tip}` : ""}` : ""}`, W / 2, py + 56);
  // 分区子卡片
  let y = py + 74;
  for (const sec of secs) {
    const h = secH(sec);
    ctx.fillStyle = "rgba(0,0,0,.28)";
    roundRect(px + 12, y, pw - 24, h, 10);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,210,74,.22)";
    ctx.lineWidth = 1;
    roundRect(px + 12, y, pw - 24, h, 10);
    ctx.stroke();
    ctx.textAlign = "left";
    ctx.font = "bold 12px sans-serif";
    ctx.fillStyle = "#c9a85a";
    ctx.fillText(sec.title, px + 24, y + 16);
    sec.rows.forEach((L, i) => {
      ctx.font = L.f;
      ctx.fillStyle = L.c;
      ctx.fillText(L.t, px + 28, y + SEC_HEAD + 16 + i * ROW_H);
    });
    y += h + SEC_GAP;
  }
  // 先锋脚注
  ctx.textAlign = "center";
  ctx.font = "13px sans-serif";
  ctx.fillStyle = lord ? "#ffd24a" : "#8a7d5a";
  ctx.fillText(`⚔️ 先锋：${lord ? `${lord.name} · 讨伐值${lord.score}` : "虚位以待——第一个打出讨伐值的人"}`, W / 2, y + 12);
  STATE_GO_BTN.y = py + ph - 56;
  drawButton(STATE_GO_BTN, cleared ? "⚔️ 再战" : "⚔️ 进军", "#7a3a2a");
  ctx.font = "11px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("点空白处关闭", W / 2, py + ph + 18);
}
/* 上周战报弹窗：周一头一次进地图弹一次——名次+排名奖入账 */
function drawWeekReport() {
  if (!weekReportShow || !meta.lastWeekReport) return;
  const r = meta.lastWeekReport;
  ctx.fillStyle = "rgba(0,0,0,.65)";
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = "rgba(30,24,12,.97)";
  roundRect(W / 2 - 170, 280, 340, 210, 14);
  ctx.fill();
  ctx.strokeStyle = "#ffd24a";
  ctx.lineWidth = 2;
  roundRect(W / 2 - 170, 280, 340, 210, 14);
  ctx.stroke();
  ctx.textAlign = "center";
  ctx.font = "bold 22px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`📜 第${r.week - WEEK0 + 1}期战报`, W / 2, 318);
  ctx.font = "bold 16px sans-serif";
  ctx.fillStyle = "#e8dcc0";
  ctx.fillText(`势力值 ${r.score} · 第 ${r.rank} 名（共${r.n}人上榜）`, W / 2, 356);
  ctx.font = "bold 17px sans-serif";
  if (r.gold) {
    ctx.fillStyle = "#ffd24a";
    ctx.fillText(`🏅 排名奖 +${r.gold}💰 已入账`, W / 2, 392);
  } else {
    ctx.fillStyle = "#c9b69a";
    ctx.fillText(`前${WEEK_RANK_GOLD.length}名有排名奖，本期再冲冲`, W / 2, 392);
  }
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#9adf5a";
  ctx.fillText("本期新图已开，进度和分数从零开始", W / 2, 428);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("点一下关闭", W / 2, 466);
}
function diffPickClick(p) {
  if (weekReportShow) { weekReportShow = false; return; }
  if (shenPop) { shenPop = false; return; }
  if (meritPop) { meritPop = false; return; }
  if (statePop) {
    if (inBtn(p, STATE_GO_BTN)) {
      const k = statePop.k;
      statePop = null;
      newGame(makeWeekLevel(meta.week, k));
      applyLevelField();
      state.phase = "pickLord";   // 先点主公：他的三张主公技就是这局的牌
      return;
    }
    statePop = null;   // 点空白处关闭
    return;
  }
  if (inBtn(p, PICK_BACK_BTN)) { state.phase = "title"; return; }
  if (inBtn(p, MERIT_BTN)) { meritPop = true; SFX.pick(); return; }
  if (inBtn(p, SHEN_LINE_BTN)) { shenPop = true; return; }
  for (let tb = 0; tb < 4; tb++)   // 四区选项卡（v7.11）
    if (inBtn(p, WEEK_TAB_RC[tb])) { weekMapTab = tb; SFX.pick(); return; }
  for (let ki = 0; ki < 16; ki++) {
    const k = weekMapTab * 16 + ki;
    const q = STATE_POS[ki];
    if (dist2(p.x, p.y, q.x, q.y) <= (STATE_R + 7) * (STATE_R + 7)) {
      if (weekLocked(k)) { pickMsg = { t: 150, text: `🔒 先拿下${STATE_NAMES[k - 1]}，再进${STATE_NAMES[k]}` }; return; }
      statePop = { k };
      return;
    }
  }
}

/* —— 点主公（2026-07-08 主公制）：进军后先选君主——只能带一位，他的三张主公技就是这局的三张牌。
     看地形横幅和州题面再点人：每位主公有明确的好用处和短板 —— */
const LORD_ROW_H = 122;
const LORD_TOP = 130;
const LORD_BACK_BTN = { x: 14, y: 22, w: 90, h: 34 };
/* 行距自适应（v5.6 八主公）：≤5位照旧122，多了压扁成紧凑行全塞一屏 */
function lordRowP() { return Math.min(LORD_ROW_H, Math.floor((H - LORD_TOP - 6) / LORD_RULERS.length)); }
function lordRowRect(i) { const rp = lordRowP(); return { x: 8, y: LORD_TOP + i * rp, w: W - 16, h: rp - 8 }; }
/* 对题提示（v7.14）：题面→最对口的主公，选将行上打👍。只标特色对口，曹操万金油不占提示位 */
function lordHintsFor(diff, cleared) {
  const h = new Set();
  if (cleared) h.add("liubiao");                                  // 再战=冲讨伐：坐保江汉波增+养龙
  for (const r of diff?.rules || []) {
    if (r === "rush" || r === "crossbow") h.add("sunquan");       // 急行军=截江减速；连弩贼在江里哑火
    if (r === "ruin") h.add("liubei");                            // 城矮：金身扛临界+桃园反击
    if (r === "twinBoss" || r === "elite") h.add("gongsunzan");   // 贼首/精锐：白马专砍
    if (r === "rocks" || r === "rich") h.add("dongzhuo");         // 乱石=洛阳铲；缴获=横征暴敛
  }
  return h;
}
function drawPickLord() {
  ctx.fillStyle = "rgba(20,14,6,.96)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  ctx.font = "bold 26px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText("👑 点主公 👑", W / 2, 46);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#d5c9a8";
  ctx.fillText("只能带一位——他的招牌技和被动就是这局的底牌，看好题面再点", W / 2, 74);
  const foes = state.diff?.foes;
  if (foes?.tri) {
    ctx.font = "bold 13px sans-serif";
    ctx.fillStyle = "#c9b69a";
    ctx.fillText(`这州的贼是 ${ELEMENTS[foes.tri].icon}${ELEMENTS[foes.tri].name}，${ELEMENTS[triCounterOf(foes.tri)].icon}${ELEMENTS[triCounterOf(foes.tri)].name}克他 · ${state.field ? state.field.icon + state.field.name : ""}${state.diff.rules?.length ? " · ⚠️" + state.diff.rules.map(r => LEVEL_RULE_DEFS[r].short).join("、") : ""}`, W / 2, 96);
    const th2 = weekThemeOf(state.diff.week, state.diff.k >= 16 ? 1 : 0);
    ctx.font = "bold 12.5px sans-serif";
    ctx.fillStyle = "#ffd24a";
    ctx.fillText(`${th2.icon} ${state.diff.k >= 16 ? "下篇" : "上篇"}军略：${th2.name}——${th2.desc}`, W / 2, 116);
  }
  const compact = lordRowP() < 100;   // 八主公紧凑排版：三行制（名号/技能/流派一行）
  const hints = lordHintsFor(state.diff, !!(state.diff && meta.weekClears && meta.weekClears[state.diff.k]));   // v7.14 对题提示
  const guests = weekGuestLords(state.diff?.week ?? meta.week);                                                  // v7.14 客卿
  LORD_RULERS.forEach((rl, i) => {
    const rc = lordRowRect(i);
    const last = meta.lastRuler === rl.id;
    ctx.fillStyle = last ? "rgba(255,215,74,.10)" : "rgba(255,255,255,.05)";
    roundRect(rc.x, rc.y, rc.w, rc.h, 12);
    ctx.fill();
    ctx.strokeStyle = last ? "rgba(255,215,74,.7)" : "rgba(120,110,90,.35)";
    ctx.lineWidth = last ? 2.2 : 1.2;
    roundRect(rc.x, rc.y, rc.w, rc.h, 12);
    ctx.stroke();
    // 头像盘
    const ar = compact ? 19 : 26, ax = rc.x + (compact ? 32 : 40), ay = rc.y + (compact ? rc.h / 2 : 44);
    drawNameDisc(rl.name, ar, ax, ay, true);
    ctx.strokeStyle = "#ffd24a";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(ax, ay, ar + 1, 0, Math.PI * 2);
    ctx.stroke();
    ctx.textAlign = "left";
    const tx = rc.x + (compact ? 62 : 80);
    ctx.font = `bold ${compact ? 15 : 17}px 'Kaiti SC', 'STKaiti', serif`;
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(`${rl.name} · ${rl.title}${last ? "（上回带的）" : ""}`, tx, rc.y + (compact ? 20 : 28));
    {  // v7.14 徽章（行首右上角）：👍对题=这关题面他最对口；🍵客卿=本周带他讨伐值+30%
      const badges = [];
      if (guests.includes(rl.id)) badges.push({ t: "🍵客卿·讨伐+30%", c: "#9adf5a" });
      if (hints.has(rl.id)) badges.push({ t: "👍对题", c: "#ffd24a" });
      if (badges.length) {
        ctx.textAlign = "right";
        ctx.font = `bold ${compact ? 10.5 : 11.5}px sans-serif`;
        let bx = rc.x + rc.w - 8;
        for (const bg of badges) {
          ctx.fillStyle = bg.c;
          ctx.fillText(bg.t, bx, rc.y + (compact ? 20 : 28));
          bx -= ctx.measureText(bg.t).width + 10;
        }
        ctx.textAlign = "left";
      }
    }
    ctx.font = `bold ${compact ? 12 : 13}px sans-serif`;
    ctx.fillStyle = "#8ad2ff";
    {
      const sk = LORDS[rl.skill];
      const sp = rl.special ? LORD_SPECIALS[rl.special] : null;
      const sp2 = rl.special2 ? LORD_SPECIALS[rl.special2] : null;
      const kinNames = (LORD_KIN[rl.id] || []).map(id => GENERALS.find(g => g.id === id)?.name || "").join("·");
      const la = LORD_ATK[rl.id];   // v7.15：普攻招式外显在选将行（倍率>1的弱势家标↑）
      const line2 = `Lv.${lordLv(rl.id)}　${sk.icon}${sk.name}${sp ? `　${sp.icon}${sp.name}` : ""}${sp2 ? `${sp2.icon}` : ""}${la ? `　${la.icon}${la.name}${la.mul > 1 ? "↑" : ""}` : ""}　🤝${kinNames}`;
      let f2 = compact ? 12 : 13;
      ctx.font = `bold ${f2}px sans-serif`;
      while (f2 > 10 && ctx.measureText(line2).width > rc.w - (tx - rc.x) - 8) {
        f2 -= 0.5;
        ctx.font = `bold ${f2}px sans-serif`;
      }
      ctx.fillText(line2, tx, rc.y + (compact ? 38 : 50));
    }
    ctx.fillStyle = "#c9b69a";
    const d = rl.desc;
    if (compact) {
      // 流派说明一行放下：放不下就缩字号
      let fs = 11.5;
      ctx.font = `${fs}px sans-serif`;
      while (fs > 9.5 && ctx.measureText(d).width > rc.w - (tx - rc.x) - 10) {
        fs -= 0.5;
        ctx.font = `${fs}px sans-serif`;
      }
      ctx.fillText(d, tx, rc.y + 57);
    } else {
      ctx.font = "11.5px sans-serif";
      const cut2 = d.indexOf("——");
      if (cut2 > 0) {
        ctx.fillText(d.slice(0, cut2), tx, rc.y + 72);
        ctx.fillText(d.slice(cut2), tx, rc.y + 90);
      } else {
        ctx.fillText(d, tx, rc.y + 72);
      }
    }
    ctx.textAlign = "center";
  });
  drawButton(LORD_BACK_BTN, "← 选关", "#5a4a3a");
}
function pickLordClick(p) {
  if (inBtn(p, LORD_BACK_BTN)) { newGame(); gotoLevelSelect(); return; }
  for (let i = 0; i < LORD_RULERS.length; i++) {
    if (inBtn(p, lordRowRect(i))) {
      applyRuler(LORD_RULERS[i].id);
      meta.lastRuler = LORD_RULERS[i].id;
      (meta.rulersUsed ||= {})[LORD_RULERS[i].id] = 1;
      saveMeta();
      SFX.pick();
      startPick();
      return;
    }
  }
}
/* 点定主公：发1张招牌技（威力=主公等级映射）+ 补算他的开局类被动（newGame 时主公未定，techLv 全是0） */
function applyRuler(rid) {
  state.ruler = rid;
  const r = LORD_RULERS.find(x => x.id === rid);
  state.lord = [{ id: r.skill, lv: lordSkillLv(rid) }];
  state.lordCd = 18; state.lordCdTotal = 18;   // 开局主公技进冷却：第一波纯靠阵容，堵开局白嫖门生
  state.jianhaoN = 0;   // v7.7 袁术本局献祭次数：僭号CD随它递增
  const wl = techLv("wall");
  if (wl) { state.baseHP += wl; state.baseHPMax += wl; }
  const vet = techLv("vet");
  if (vet) state.xp += vet * 10;
  state.buffs.xpGain = 1 + techLv("farm") * 0.04;
  const pk = techLv("pick");
  if (pk) state.wallShield += pk * 2;
}

/* ---------- 地利：每关固定地形，开局横幅告知（rollField 保留给无尽/测试用） ---------- */
function applyLevelField() {
  const f = FIELDS.find(x => x.id === state.diff.field) || pick(FIELDS);
  state.field = f;
  if (f.wallAdd) { state.baseHP += f.wallAdd; state.baseHPMax += f.wallAdd; }
  state.fieldBanner = 9;
}
function rollField() {
  const f = pick(FIELDS);
  state.field = f;
  if (f.wallAdd) { state.baseHP += f.wallAdd; state.baseHPMax += f.wallAdd; }
  state.fieldBanner = 9;   // 开局横幅：选将期常驻，开打后自动淡出，点一下也能关
}
const FIELD_BANNER_RC = { x: 8, y: 138, w: 392, h: 92 };   // v5.9.4 右缘让开右侧按钮列（手机上压住帮助/音效很乱）
function drawFieldBanner() {
  if (!(state.fieldBanner > 0) || !state.field) return;
  const f = state.field;
  const rc = FIELD_BANNER_RC;
  const foes = state.diff.foes;
  const tips = (state.diff.rules || []).map(r => `${LEVEL_RULE_DEFS[r].short}：${LEVEL_RULE_DEFS[r].tip}`);
  rc.h = 92 + (foes ? 22 : 0) + tips.length * 17;   // 敌情/军令多一行横幅高一截（点击判定共用这个 rc）
  const a = clamp(state.fieldBanner, 0, 1);   // 最后1秒淡出
  ctx.save();
  ctx.globalAlpha = a;
  ctx.fillStyle = "rgba(24,18,8,.92)";
  roundRect(rc.x, rc.y, rc.w, rc.h, 12);
  ctx.fill();
  ctx.strokeStyle = "#e8c86a";
  ctx.lineWidth = 2;
  roundRect(rc.x, rc.y, rc.w, rc.h, 12);
  ctx.stroke();
  ctx.textAlign = "center";
  const bcx = rc.x + rc.w / 2;   // 横幅左移后文字跟着框走，别再钉死屏幕中线
  ctx.font = "bold 19px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`${state.diff.icon} ${state.diff.name} · ${f.icon}${f.name}`, bcx, rc.y + 30);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#e8dcc0";
  ctx.fillText(f.desc.split("｜").join("，"), bcx, rc.y + 55);
  let by = rc.y + 55;
  if (foes) {
    by += 22;
    ctx.font = "bold 13px sans-serif";
    ctx.fillStyle = "#9adf5a";
    const tt = ELEMENTS[foes.tri], kk = ELEMENTS[triCounterOf(foes.tri)];
    ctx.fillText(`这州的贼是${tt.icon}${tt.name}——带${kk.icon}${kk.name}打他最疼`, bcx, by);
  }
  if (state.diff.week != null) {   // 本关渠帅（v7.18.7）：进关前就知道出题人是谁
    by += 20;
    const FL7 = foeLordFor(state.diff.week, state.diff.k);
    ctx.font = "bold 13px sans-serif";
    ctx.fillStyle = "#ff9a8a";
    ctx.fillText(`${FL7.icon} 本关渠帅：${FL7.name}·${FL7.title}（第8波起施法）`, bcx, by);
  }
  for (const t of tips) {
    by += 17;
    ctx.font = "11.5px sans-serif";
    ctx.fillStyle = "#ffb84a";
    ctx.fillText(`⚠️ ${t}`, bcx, by);
  }
  ctx.font = "11px sans-serif";
  ctx.fillStyle = "rgba(255,255,255,.5)";
  ctx.fillText("点一下知道了 · 左上角小牌子随时能再看", bcx, rc.y + rc.h - 14);
  ctx.restore();
}

/* ---------- 遗物三选一 ---------- */
function rollRelics() {
  // 乐不思蜀（v7.12）：宝贝也照常弹，挂机引擎自动挑
  // 机制遗宝（带 need）：阵中没对应武将/兵种就不进池——不给玩家发废卡
  const avail = RELICS.filter(r => !hasRelic(r.id) && (!r.need || r.need()));
  if (!avail.length) return;
  if (state.cards) { state.relicQueue++; return; }  // 正在选卡就排队
  const opts = [...avail].sort(() => Math.random() - 0.5).slice(0, Math.min(3, avail.length));
  state.cards = opts.map(r => ({
    kind: "relic", relic: r,
    title: r.name, icon: r.icon, desc: critText(r.desc),
    // 机制遗宝标明归属（2026-07-10 用户反馈）：这件宝是给谁/哪条线用的，一眼看清再选
    info: r.who ? `🔒 ${r.who}专属` : null, infoColor: "#ffd24a",
  }));
  state.cardAnim = 0;
  state.cardsAt = performance.now();
  state.pickingRelic = true;
}

function applyCard(card) {
  state.cardPicks[card.title] = (state.cardPicks[card.title] || 0) + 1;
  SFX.pick();
  if (card.kind === "unit") {
    let empties = emptySlots();
    // 邓艾（v7.6.0）：唯一能站障碍格的武将——落位时优先挑一块石头站
    if (card.type.id === "dengai") {
      const rocks = [];
      for (let r2 = 0; r2 < GRID_ROWS; r2++)
        for (let c2 = 0; c2 < GRID_COLS; c2++)
          if (!state.slots[r2][c2] && isObstacle(r2, c2)) rocks.push([r2, c2]);
      if (rocks.length) empties = rocks;
    }
    if (empties.length) {
      const [r, c] = pick(empties);
      state.slots[r][c] = makeUnit(card.type);
      const p = slotCenter(r, c);
      burst(p.x, p.y, "#ffe08a", 16, 160);
      addFloater(p.x, p.y - 40, `${card.type.name}参战！`, "#ffe45a", 17);
      computeTeam();
      if (allUnits().length >= GRID_ROWS * GRID_COLS - 4) unlockAch("fullhouse");
    }
  } else if (card.kind === "upgrade") {
    let best = null;
    for (const u of allUnits())
      if (u.type.id === card.typeId && u.level < MAX_LEVEL && (!best || u.level < best.level))
        best = u;
    if (best) {
      best.level++;
      best.bounce = 1;
      best.hpMax = unitMaxHp(best.type, best.level, best.rebirth || 0);
      best.hp = best.hpMax;   // 升星整备，满血归队
      if (best.level >= 5) unlockAch("star5");
      for (let r = 0; r < GRID_ROWS; r++)
        for (let c = 0; c < GRID_COLS; c++)
          if (state.slots[r][c] === best) {
            const p = slotCenter(r, c);
            burst(p.x, p.y, "#ffe45a", 22, 200);
            addFloater(p.x, p.y - 40, `${best.type.name} ${best.level}★！`, "#ffe45a", 18);
          }
      shake = Math.max(shake, 0.25);
    }
  } else if (card.kind === "granary") {
    // 有未满星的仓先升星（和练兵同规矩：升最低星那个）；全满或没仓则立新仓
    let lowG = null;
    for (const u of allUnits())
      if (u.type.cls === "granary" && u.level < GRANARY_MAX && (!lowG || u.level < lowG.level)) lowG = u;
    if (lowG) {
      lowG.level++;
      lowG.bounce = 1;
      lowG.hpMax = unitMaxHp(lowG.type, lowG.level);
      lowG.hp = lowG.hpMax;   // 升星整备，满血归队
      const gpos = findUnitPos(lowG);
      if (gpos) {
        const p = slotCenter(gpos[0], gpos[1]);
        burst(p.x, p.y, "#e8c86a", 20, 180);
        addFloater(p.x, p.y - 40, `🌾 粮仓 ${lowG.level}★！产粮更快`, "#ffe45a", 17);
      }
    } else {
      const gEmpties = emptySlots();
      if (gEmpties.length) {
        const [r, c] = pick(gEmpties);
        state.slots[r][c] = makeUnit(GRANARY_TYPE);
        const p = slotCenter(r, c);
        burst(p.x, p.y, "#e8c86a", 16, 160);
        addFloater(p.x, p.y - 40, "🌾 粮仓开张，产粮喂旁边人升星", "#ffe45a", 16);
        computeTeam();
      }
    }
  } else if (card.kind === "egg") {
    if (card.sub === "place") {
      const es = emptySlots();
      if (es.length) {
        const [r, c] = pick(es);
        state.slots[r][c] = makeUnit(EGG_TYPE);
        const p = slotCenter(r, c);
        burst(p.x, p.y, "#c9a8ff", 16, 160);
        addFloater(p.x, p.y - 40, "🥚 龙蛋落阵！好生看护", "#c9a8ff", 16);
        computeTeam();
      }
    } else if (card.sub === "grow") {
      const egg = allUnits().find(u => u.type.cls === "egg" && u.level < EGG_MAX);
      if (egg) {
        const ch = hatchChance(egg);
        const epos = findUnitPos(egg);
        const p = epos ? slotCenter(epos[0], epos[1]) : { x: W / 2, y: 400 };
        if (Math.random() < ch) {
          egg.level++;
          egg.hatchBonus = 0;   // 软保底清零
          egg.bounce = 1;
          egg.hpMax = unitMaxHp(egg.type, egg.level);
          egg.hp = egg.hpMax;
          burst(p.x, p.y, "#c9a8ff", 22, 200);
          addFloater(p.x, p.y - 40, `咔！蛋壳裂了一道（${egg.level}阶）`, "#c9a8ff", 17);
          if (egg.level >= EGG_MAX) addFloater(p.x, p.y - 62, "🐉 再抽到就觉醒！", "#ffd24a", 15);
          shake = Math.max(shake, 0.25);
        } else {
          egg.hatchBonus = (egg.hatchBonus || 0) + 0.2;   // 失败不掉阶：下次把握+2成
          addFloater(p.x, p.y - 40, "……没动静（下次把握+2成）", "#c9b69a", 15);
        }
      }
    } else if (card.sub === "awaken") {
      const egg = allUnits().find(u => u.type.cls === "egg" && u.level >= EGG_MAX);
      const epos = egg && findUnitPos(egg);
      if (epos) {
        state.dragonN++;
        unlockAch("dragon1");
        if (state.dragonN >= 2) unlockAch("dragon2");
        const d = makeUnit(DRAGON_TYPE);
        d.dragonRank = state.dragonN;
        state.slots[epos[0]][epos[1]] = d;
        state.dragonWaves.push(state.wave);
        const p = slotCenter(epos[0], epos[1]);
        burst(p.x, p.y, "#ffd24a", 30, 260);
        burst(p.x, p.y, "#8ad2ff", 22, 200);
        state.flash = Math.max(state.flash, 0.7);
        addFloater(W / 2, 300, state.dragonN > 1 ? `🐉 第${state.dragonN}条应龙觉醒！更猛` : "🐉 应龙觉醒！", "#ffd24a", 23);
        SFX.relic();
        shake = Math.max(shake, 0.8);
        computeTeam();
      }
    }
  } else if (card.kind === "buff") {
    state.buffs[card.buff] += card.val;
    addFloater(W / 2, 300, card.title + "！", "#9adf5a", 22);
  } else if (card.kind === "elem") {
    state.buffs.elemBoost[card.elem] += card.val;
    addFloater(W / 2, 300, `${card.icon} ${card.title} +${Math.round(card.val * 100)}%`, "#9adf5a", 21);
  } else if (card.kind === "lord") {
    const idx = state.lord.findIndex(sl => !sl);
    if (idx >= 0) {
      state.lord[idx] = { id: card.lordId, lv: 1, cd: 0 };
      addFloater(W / 2, 300, `👑 学会【${LORDS[card.lordId].name}】！`, "#ffd24a", 22);
      burst(W / 2, 320, "#ffd24a", 20, 200);
    }
  } else if (card.kind === "relic") {
    state.relics.push(card.relic);
    if (state.relics.length >= 5) unlockAch("relic5");
    SFX.relic();
    addFloater(W / 2, 300, `${card.icon}「${card.relic.name}」到手！`, "#ffd24a", 21);
    burst(W / 2, 320, "#ffd24a", 26, 220);
    shake = Math.max(shake, 0.35);
  } else if (card.kind === "heal") {
    state.baseHP = Math.min(state.baseHPMax, state.baseHP + 3);
    addFloater(W / 2, 300, "城池 +3 🏯", "#ff9a9a", 22);
  } else if (card.kind === "tacperm") {
    state[card.tp + "On"] = true;
    addFloater(W / 2, 300, `${card.icon} 「${card.title}」立营！此后全程生效`, "#ffd24a", 20);
  } else if (card.kind === "pofu") {
    // 破釜沉舟：主动砸锅不置 wallHurt（不毁三星），乘区在 getUnitMods
    state.pofuN = 1;
    state.pofuBuff = 0.5;   // ×1.5 乘算（getUnitMods），独立于猛攻+200%封顶
    state.baseHPMax = Math.max(3, state.baseHPMax - 2);
    state.baseHP = Math.min(state.baseHP, state.baseHPMax);
    shake = Math.max(shake, 0.5);
    addFloater(W / 2, 300, "🍳 破釜沉舟！城墙上限-2，全军伤害×1.5（乘算·永久）", "#ff9a6a", 21);
  } else if (card.kind === "reroll") {
    state.pendingPicks = (state.pendingPicks || 0) + 1;   // 尾部会立刻再发一手
    addFloater(W / 2, 300, "🎲 偷梁换柱！这手不要了，重摸", "#c9a8ff", 20);
  } else if (card.kind === "levelup") {
    state.level++;
    state.xpNeed = Math.round((10 + (state.level - 1) * 9 + Math.pow(state.level, 1.72))
      * (hasRelic("hanshu") ? 0.88 : 1));   // 和 gainXP 同一条升级曲线
    state.pendingPicks = (state.pendingPicks || 0) + 1;
    burst(W / 2, 90, "#ffe45a", 20, 200);
    SFX.levelUp();
    addFloater(W / 2, 300, `🎓 校场演武！Lv.${state.level}，再摸一手`, "#ffe45a", 22);
  } else if (card.kind === "lordatk") {
    state.lordAtkBuff = Math.min(2, (state.lordAtkBuff || 0) + 0.4);   // v7.17.3 封顶+200%（5张），到顶退池
    addFloater(W / 2, 300, `🎯 御驾亲征！主公${state.ruler === "gongsunzan" ? "强弩" : "亲射"}伤害+${Math.round(state.lordAtkBuff * 100)}%`, "#ffd24a", 20);
  } else if (card.kind === "lordhaste") {
    state.lordAtkGap = Math.max(0.4, +(((state.lordAtkGap || 1) * 0.75)).toFixed(3));
    addFloater(W / 2, 300, `⚙️ 神机连弩！主公出手间隔降到${Math.round(state.lordAtkGap * 100)}%`, "#8ad2ff", 20);
  } else if (card.kind === "terrain") {
    // 洛阳铲（v7.0 董卓专属）：不随机炸——存一把铲子，点铲子牌自己挑着挖
    if (state.ruler === "dongzhuo") {
      state.shovels++;
      SFX.pick();
      addFloater(W / 2, 300, `🪏 洛阳铲+1（共${state.shovels}把）：点铲子牌挑一块障碍挖`, "#ffd24a", 20);
    } else {
      // 开山凿石：随机清除障碍，露出格子特质
      const n = Math.min(1, state.obstacles.size);
      const keys = [...state.obstacles];
      for (let i = 0; i < n; i++) {
        const k = keys.splice(Math.floor(Math.random() * keys.length), 1)[0];
        state.obstacles.delete(k);
        const [r, c] = k.split(",").map(Number);
        const p = slotCenter(r, c);
        burst(p.x, p.y, "#c9b69a", 18, 170);
        burst(p.x, p.y, "#8a7a5a", 10, 110);
        const tr = TRAITS[state.traits[k]];
        addFloater(p.x, p.y - 26, `🧹 炸开！露出${tr ? tr.icon + tr.name : "平地"}`, "#ffe45a", 14);
      }
      shake = Math.max(shake, 0.3);
    }
  } else if (card.kind === "merit") {
    const mg = card.val || 25;
    earnGold(mg);
    state.goldEarned += mg;
    saveMeta();
    addFloater(W / 2, 300, `💰 金币 +${mg}`, "#ffb84a", 22);
  } else if (card.kind === "drums") {
    // 池底常青：临时爆发，不叠不留（已有更猛的提速就不覆盖）
    if (!state.armyHaste || state.armyHaste.mul <= 1.3) state.armyHaste = { t: 15, mul: 1.3 };
    SFX.buff();
    addFloater(W / 2, 300, "🥁 战鼓雷动！全军攻速+30%·15秒", "#ffb84a", 20);
  } else if (card.kind === "seppuku") {
    // 彩蛋转正（v5.9）：主公自刎=体面收兵——走正常城破结算，本局讨伐波数按110%记档（见好就收的理由）
    // v7.11 计分拆项后：+10%落在讨伐波上（星是打出来的没法送），效果与原"总分+10%"相当
    meta.seppukuN = (meta.seppukuN || 0) + 1;
    if (meta.seppukuN >= 3) unlockAch("seppuku3");
    if (state.runScore > 0 && state.diff.week != null && state.winWave) {
      const extra = Math.ceil(Math.max(0, state.wave - state.winWave) * 1.1);
      recordWeekScore(extra);
      addFloater(W / 2, 340, `🗡️ 体面收兵：讨伐战果按 ${extra} 波记档（+10%）`, "#ffd24a", 20);
    }
    addFloater(W / 2, 300, "🗡️ 主公自刎，全军挂孝收兵……", "#ff8a6a", 22);
    shake = 1;
    cityFall();
  } else if (card.kind === "dance") {
    // 乐不思蜀（v7.12 重做，原歌舞升平）：三秒歌舞后进入挂机——全军攻击+30%，
    // 卡牌照弹但自动随机抽（扫牌动画见 update/drawCards，避开自刎归天和乐不思蜀），直到局末或玩家点屏幕回神
    meta.danceN = (meta.danceN || 0) + 1;
    if (meta.danceN >= 5) unlockAch("dance5");
    saveMeta();
    state.dance = 3;
    state.gewu = true;
    SFX.dance();
    addFloater(W / 2, 300, "🍷 此间乐，不思蜀：全军攻击+30%·自动抽卡挂机——点击屏幕随时回神", "#ff9ac8", 20);
  }
  state.cards = null;
  state.pickingRelic = false;
  if (state.phase === "pickStart") state.phase = "play";
  if (state.phase !== "play") { state.relicQueue = 0; state.pendingPicks = 0; state.widePicks = 0; return; }   // 自刎/城破后别再往结算页发牌
  if (state.relicQueue > 0) {
    state.relicQueue--;
    rollRelics();
  } else if (state.pendingPicks > 0) {
    state.pendingPicks--;
    rollCards();
  }
}

function gainXP(n, src) {
  let mul = state.buffs.xpGain;
  if (state.field?.xpMul) mul *= state.field.xpMul;
  const v = n * mul;
  state.xp += v;
  state.xpAll = (state.xpAll || 0) + v;
  while (state.xp >= state.xpNeed) {
    state.xp -= state.xpNeed;
    state.level++;
    // 平滑指数曲线：前期升得快建立阵容，后期约每1.5波升一级
    state.xpNeed = Math.round((10 + (state.level - 1) * 9 + Math.pow(state.level, 1.72))
      * (hasRelic("hanshu") ? 0.88 : 1));
    if (state.cards) state.pendingPicks++;
    else rollCards();
    burst(W / 2, 90, "#ffe45a", 20, 200);
    SFX.levelUp();
  }
}

/* ---------- 主公技释放 ---------- */
/* v7.0 主公主体：主公站在城墙正中——所有大招从这里发出（涟漪/冰波/江流/火扇/白马的原点） */
function lordPos() { return { x: W / 2, y: DEFENSE_LINE + 26 }; }
/* 亲射估伤（v7.15.1 面板/城墙共用一套账）：{atk,per,itv}——per=当前每击约多少伤（另加3%目标血），itv=出手间隔秒 */
function lordAtkEst() {
  const atk = LORD_ATK[state.ruler];
  if (!atk) return null;
  const gap = (state.lordAtkGap || 1) * (hasRelic("yushan") ? 0.8 : 1), buff = 1 + (state.lordAtkBuff || 0);   // 白羽扇：亲射出手快25%（间隔×0.8）
  if (state.ruler === "gongsunzan")
    return { atk, itv: 2.5 * gap, per: (6 + state.wave * 1.2) * (state.baseHP / Math.max(1, state.baseHPMax)) * (1 + 0.03 * lordLv("gongsunzan")) * atk.mul * buff };
  return { atk, itv: 3 * gap, per: (7 + state.wave * 0.75) * (1 + 0.02 * lordLv(state.ruler)) * kinPower() * atk.mul * buff };
}
function lordCdMax(slot) {
  let cd = LORDS[slot.id].cd;
  // v7.7 袁术压狂抽：僭号称帝越献祭，下一道号令等得越久（45→57→69…），压真人农祭品刷星流（数据实锤硬州77%通关全场最高）
  if (slot.id === "jianhao") cd += Math.min(6, state.jianhaoN || 0) * 12;
  cd *= 1 - techLv("supply") * 0.04;
  if (hasRelic("sunzi")) cd *= 0.75;
  if (hasRelic("yushan")) cd *= 0.85;   // 白羽扇（v7.15.3 重做）：羽扇轻摇，号令冷却-15%
  return cd;
}
/* —— v7.0 自动大招框架：待命机器退役——CD好了、时机对了，主公自己放。
   lordAutoOk = 每技的"时机对了"判定；手动点就绪的圆形图标=抢时机提前放（底线拦截防浪费CD） —— */
/* 亲兵加成：场上存活嫡系越多，主公大招越强（0~3人 → ×1.0~×1.6）——选主公=选班底的战斗延伸 */
function kinPower() {
  if (!state.ruler || !LORD_KIN[state.ruler]) return 1;
  return Math.min(1.8, 1 + 0.2 * allUnits().filter(u => isKin(u.type.id)).length);   // v7.6.0 四亲兵+贾诩百搭：封顶×1.8
}
function lordAutoOk(id) {
  switch (id) {
    case "wuxing":   return aliveEnemies().length >= 8;
    case "bingfeng": return aliveEnemies().length >= 6;
    case "taoyuan":  return !(state.taoyuanT > 0) && aliveEnemies().length > 0
      && (allUnits().some(u => !["granary", "egg", "dragon"].includes(u.type.cls) && u.hp < u.hpMax * 0.55)
        || aliveEnemies().some(e => e.y > DEFENSE_LINE - 150));   // v7.4.3 复合危难：掉半血 或 贼冲进阵地纵深——单看血线正常局根本触发不了
    case "jiejiang": return aliveEnemies().filter(e => e.y > 300 && e.y < 430).length >= 4;
    case "mensheng": return !state.widePicks && state.wave >= 2;
    case "baima":    return state.enemies.some(e => !e.dead && (e.special || e.boss)) || aliveEnemies().length >= 8;
    case "fenluo":   return aliveEnemies().length >= 6 && state.baseHP >= 5;
    case "jianhao":  return !!jianhaoTarget();
    default: return aliveEnemies().length > 0;
  }
}
function castLord(i, manual) {
  if (state.gewu) {
    if (manual) addFloater(W / 2, 300, "🍷 乐不思蜀，号令没人接", "#ff9ac8", 18);
    return;
  }
  const slot = state.lord[i];
  if (!slot || state.lordCd > 0) return;
  const L = LORDS[slot.id];
  const st = L.stat(slot.lv);
  // 手动抢放的底线拦截（自动路径由 lordAutoOk 把关，走不到这里）：拦住必然浪费CD/自杀的按法
  const needEnemy = ["huoshi", "bingfeng", "wuxing", "fenluo", "baima", "taoyuan"].includes(slot.id);   // 金身没贼=白烧CD，一并拦
  if (needEnemy && !aliveEnemies().length) {
    if (manual) addFloater(W / 2, 300, `${L.icon}${L.name}：场上没贼，时机一到自动放`, "#c9b69a", 18);
    return;
  }
  if (slot.id === "taoyuan" && state.taoyuanT > 0) {
    if (manual) addFloater(W / 2, 300, "🍑 金身还护着呢，不用叠", "#ffd2a8", 18);
    return;
  }
  if (slot.id === "mensheng" && state.widePicks > 0 && !(state.cards && !state.pickingRelic && state.cards.length < 5)) {
    if (manual) addFloater(W / 2, 300, `📜 门路还没用完：还有${state.widePicks}次五选一，升级选卡就见`, "#d8bfff", 18);
    return;
  }
  if (slot.id === "fenluo" && state.baseHP < 3) {
    if (manual) addFloater(W / 2, 300, "🔥 城墙都快塌了，烧不得（城血≥3才能点火）", "#ff9a8a", 18);
    return;
  }
  if (slot.id === "jianhao" && !jianhaoTarget()) {
    if (manual) addFloater(W / 2, 300, "🪙 玉玺无处下口：场上不足5人，或没有星≤3的祭品", "#ffd24a", 18);
    return;
  }
  state.lordCdTotal = lordCdMax(slot);
  state.lordCd = state.lordCdTotal;
  state.lordUsed++;
  if (state.lordUsed >= 10) unlockAch("tactic10");
  SFX.tactic();
  shake = Math.max(shake, 0.45);
  if (slot.id === "huoshi") {
    // 借东风：全场敌人往回吹一大段（复用 e.kb 平滑击退，主循环以300px/s消耗），贼首减半
    for (const e of state.enemies) {
      if (e.dead) continue;
      e.kb = Math.max(e.kb || 0, e.boss ? st.push * 0.5 : st.push);
    }
    // 大风视觉：满屏风叶向上卷 + 三道风环
    for (let i2 = 0; i2 < 46; i2++)
      state.particles.push({
        x: rand(20, W - 20), y: rand(90, GRID_Y - 20),
        vx: rand(-40, 40), vy: rand(-300, -160),
        life: rand(0.4, 0.9), maxLife: 0.9, color: i2 % 3 ? "#bfe8d2" : "#8ad2ff", size: rand(2, 5),
      });
    for (let i2 = 0; i2 < 3; i2++)
      state.ripples.push({ x: W / 2, y: GRID_Y - 60 - i2 * 40, r: 6 + i2 * 30, max: 420, color: "#9ae8c8", kind: "wind" });
    addFloater(W / 2, 240, "🌪️ 借东风！全场吹回去", "#9ae8c8", 24);
    shake = 0.6;
  } else if (slot.id === "bingfeng") {
    const tB = st.t * kinPower();   // 亲兵助威：冻更久
    for (const e of state.enemies) {
      if (e.dead) continue;
      e.stunT = Math.max(e.stunT, e.boss ? tB * 0.6 : tB);
      e.slowT = Math.max(e.slowT, ctrlDur(tB + 2));
    }
    const lpB = lordPos();
    state.ripples.push({ x: lpB.x, y: lpB.y - 16, r: 8, max: 620, color: "#8ad2ff", kind: "wind" });
    for (let i2 = 0; i2 < 26; i2++) {   // 寒气从主公扇形喷出去铺满场
      const ang = -Math.PI / 2 + rand(-0.9, 0.9);
      const spd = rand(300, 520);
      state.particles.push({
        x: lpB.x + rand(-14, 14), y: lpB.y - 14,
        vx: Math.cos(ang) * spd, vy: Math.sin(ang) * spd,
        life: rand(0.5, 1.0), maxLife: 1.0, color: i2 % 2 ? "#8ad2ff" : "#e8f8ff", size: rand(3, 6),
      });
    }
    for (let i2 = 0; i2 < 24; i2++)
      burst(rand(30, W - 30), rand(60, GRID_Y - 40), "#8ad2ff", 4, 120);
    addFloater(W / 2, 240, `🧊 全场定住${(st.t * kinPower()).toFixed(1)}秒！`, "#8ad2ff", 24);
  } else if (slot.id === "wuxing") {
    // 三才破敌（v6.0）：窗口期打谁都按克制算（伤害钩子在 damageEnemy）；播报配当前州属性的克星色
    state.wuxingT = st.t * kinPower();   // 亲兵助威：窗口更长
    const cf0 = curFoesNow();
    const wk = cf0 && cf0.tri ? triCounterOf(cf0.tri) : null;
    const col = wk ? ELEMENTS[wk].color : "#ffe45a";
    const lpW = lordPos();
    state.ripples.push({ x: lpW.x, y: lpW.y - 16, r: 8, max: 620, color: col, kind: "wind" });
    const lpWx = lordPos();
    for (let r = 0; r < GRID_ROWS; r++)
      for (let c = 0; c < GRID_COLS; c++)
        if (state.slots[r][c]) {
          const pp = slotCenter(r, c);
          state.beams.push({ x1: lpWx.x, y1: lpWx.y - 14, x2: pp.x, y2: pp.y, t: 0.5, color: col, w: 3 });
          burst(pp.x, pp.y, col, 10, 130);
        }
    SFX.buff();
    addFloater(W / 2, 240, `☯️ 三才破敌！${(st.t * kinPower()).toFixed(0)}秒内全军打谁都算克制`, col, 22);
  } else if (slot.id === "jianjun") {
    // 监军令：特种兵和贼首闭嘴（复用 silencedT，巫医/旗手/弓贼/贼首绝活全哑）还多挨打
    const silT = st.t + (hasRelic("chensha") ? 2 : 0);   // 沉沙折戟：封更久
    let hit = 0;
    for (const e of state.enemies) {
      if (e.dead || !(e.special || e.boss)) continue;
      e.silencedT = Math.max(e.silencedT || 0, silT);
      e.jianjunT = Math.max(e.jianjunT || 0, silT);
      e.jianjunAmp = st.amp;
      burst(e.x, e.y, "#ffd24a", 6, 100);
      hit++;
    }
    SFX.ult();
    addFloater(W / 2, 240, `🎖️ 按住${hit}个贼头目！多挨${Math.round(st.amp * 100)}%打`, "#ffd24a", 22);
  } else if (slot.id === "youdi") {
    // 诱敌深入：下一波变肥羊（buildWave 消费 state.youdi，只吃一波）
    state.youdi = { hpK: st.hpK, gainK: st.gainK };
    if (state.nextQueue) { state.nextQueue = null; state.nextWavePreview = null; }   // 预告已生成：作废重造，立刻带上肥羊题
    SFX.buff();
    addFloater(W / 2, 240, `🐑 下波多而脆，收成+${Math.round((st.gainK - 1) * 100)}%`, "#ffb84a", 22);
  } else if (slot.id === "zhucheng") {
    state.baseHPMax += st.hp;
    state.baseHP = Math.min(state.baseHPMax, state.baseHP + st.hp);
    state.wallShield += st.sh;
    addFloater(W / 2, DEFENSE_LINE - 20, `🏯 筑城！城墙+${st.hp}血 +${st.sh}盾`, "#9adf5a", 22);
  } else if (slot.id === "taoyuan") {
    // 桃园义 v7.3.0：全军金身——仁德光从主公连到每个人，全员刀枪不入几秒
    const tT = st.invT * kinPower();   // 亲兵助威：金身更久
    state.taoyuanT = tT;
    state.taoyuanAbsorb = 0;   // 桃园反击（v7.14）：这轮金身的账本从零记
    const lpT = lordPos();
    for (let r2 = 0; r2 < GRID_ROWS; r2++)
      for (let c2 = 0; c2 < GRID_COLS; c2++)
        if (state.slots[r2][c2]) {
          const pp2 = slotCenter(r2, c2);
          state.beams.push({ x1: lpT.x, y1: lpT.y - 14, x2: pp2.x, y2: pp2.y, t: 0.5, color: "#ffd2a8", w: 4 });
          burst(pp2.x, pp2.y, "#ffd278", 10, 130);
        }
    state.ripples.push({ x: lpT.x, y: lpT.y - 16, r: 8, max: 620, color: "#ffd2a8", kind: "wind" });
    state.flash = 0.22;
    shake = Math.max(shake, 0.5);
    SFX.buff();
    addFloater(W / 2, 280, `🍑 桃园义！全军金身${tT.toFixed(1)}秒`, "#ffd2a8", 24);
  } else if (slot.id === "jiejiang") {
    // 水战之利：江面不减速——江里的贼挨打多（damageEnemy 钩子）、弓贼投石兵在江里放不了箭
    const ampJ = st.amp * kinPower();   // 亲兵助威：江里更疼
    state.flood = { y1: 330, y2: 415, amp: ampJ, t: st.t };
    const lpJ = lordPos();
    state.ripples.push({ x: lpJ.x, y: lpJ.y - 16, r: 8, max: 560, color: "#8ad2ff", kind: "wind" });
    for (let i2 = 0; i2 < 30; i2++)   // 大江从主公脚下涌出去，一路浪花推到江区
      state.particles.push({
        x: lpJ.x + rand(-20, 20), y: lpJ.y - 12 - i2 * 12,
        vx: rand(-60, 60), vy: rand(-420, -280),
        life: rand(0.4, 0.9), maxLife: 0.9, color: i2 % 3 ? "#8ad2ff" : "#d8f2ff", size: rand(3, 7),
      });
    addFloater(W / 2, 372, `🌊 截江断流！江里的贼变慢40%·挨打多${Math.round(ampJ * 100)}%·${st.t}秒`, "#8ad2ff", 20);
  } else if (slot.id === "mensheng") {
    // 门生故吏也要看得见从主公来：金色卷轴从主体喷向天空
    {
      const lpM = lordPos();
      for (let i2 = 0; i2 < 18; i2++)
        state.particles.push({
          x: lpM.x + rand(-12, 12), y: lpM.y - 16,
          vx: rand(-90, 90), vy: rand(-380, -220),
          life: rand(0.5, 0.9), maxLife: 0.9, color: i2 % 2 ? "#d8bfff" : "#ffd24a", size: rand(3, 6),
        });
      state.ripples.push({ x: lpM.x, y: lpM.y - 16, r: 6, max: 200, color: "#d8bfff", kind: "wind" });
    }
    // 门路广（v5.4.6 纯质量轴 / v5.5.2 补即时反馈）：不白得选卡——白给卡数就是抽牌引擎（sim实测独一档）。
    // 手里正摊着牌：当场把这一桌加宽到五张（立竿见影，消耗一次门路）；没摊牌：铺给接下来的升级选卡
    state.widePicks = (state.widePicks || 0) + st.wide;
    if (state.cards && !state.pickingRelic && state.cards.length < 5) {
      const pool = buildCardPool();
      const have = new Set(state.cards.map(cd => cd.title));
      let guard = 0;
      while (state.cards.length < 5 && guard++ < 40) {
        const cand = pool.filter(cd => !have.has(cd.title));
        if (!cand.length) break;
        let total = cand.reduce((s, cd2) => s + cd2.weight, 0), roll = Math.random() * total, idx = 0;
        for (; idx < cand.length - 1; idx++) { roll -= cand[idx].weight; if (roll <= 0) break; }
        state.cards.push(cand[idx]);
        have.add(cand[idx].title);
      }
      state.widePicks--;
      SFX.buff();
      addFloater(W / 2, 300, `📜 门生故吏！这桌当场加宽到${state.cards.length}张${state.widePicks > 0 ? `（还罩${state.widePicks}次）` : ""}`, "#d8bfff", 20);
    } else {
      SFX.buff();
      addFloater(W / 2, 300, `📜 门路铺好！接下来${st.wide}次升级选卡都是五张里挑`, "#d8bfff", 20);
    }
  } else if (slot.id === "shoumai") {
    // 收买（董卓专属，v5.6）：花账上金币让普通小兵拿钱走人——不给经验不给金币，
    // 连击破计数都不给（放弃收成换活命）；从最贴近城墙的开始买
    const price = 10 + state.wave * 2;
    const cand = state.enemies
      .filter(e => !e.dead && !e.special && !e.boss && !e.affix && !e.big)
      .sort((a, b) => b.y - a.y);
    const n = Math.min(st.n, cand.length, Math.floor(meta.gold / price));
    let cost = 0;
    for (let i2 = 0; i2 < n; i2++) {
      const e = cand[i2];
      e.dead = true;
      e.bought = true;
      cost += price;
      addFloater(e.x, e.y - e.r - 10, "💰", "#ffd24a", 16);
      burst(e.x, e.y, "#ffd24a", 8, 90);
    }
    meta.gold -= cost;
    saveMeta();
    SFX.pick();
    addFloater(W / 2, 300, `💰 买通 ${n} 个小的消灾，花了 ${cost} 金`, "#ffd24a", 22);
  } else if (slot.id === "baima") {
    // 白马义从（v7.0 公孙瓒·主公下场实验）：主公骑白马冲下城墙，无敌几秒专砍关键怪
    const lpB2 = lordPos();
    const tB2 = st.t * kinPower();
    state.baima = { x: lpB2.x, y: lpB2.y - 12, t: tB2, hitT: 0,
      dmg: (20 + state.wave * 2.5) * st.dmgK * kinPower() };
    burst(lpB2.x, lpB2.y - 12, "#e8f4ff", 20, 200);
    addFloater(W / 2, 300, `🐎 白马义从！主公亲自下场${tB2.toFixed(1)}秒`, "#e8f4ff", 22);
  } else if (slot.id === "fenluo") {
    // 火烧雒阳（v7.0 董卓·残血流实验）：烧自家2点城墙血，从主公喷全场扇形巨焰。
    // 主动烧墙是技能代价，不置 wallHurt（不毁三星）；castLord 头部已拦 baseHP<3
    state.baseHP = Math.max(1, state.baseHP - 2);
    state.tyranny = (state.tyranny || 0) + 8;   // 暴政印记（v7.14.1 加码）：烧1血=全军攻击+4%（本局永久），乘区在 getUnitMods
    const lpF = lordPos();
    const dmgF = (35 + state.wave * 4) * st.dmgK * kinPower();
    let hitN = 0;
    for (const e of aliveEnemies()) {
      const dx = e.x - lpF.x, dy = lpF.y - e.y;
      if (dy <= 0 || Math.abs(dx) > dy * 1.25) continue;   // 从主公张开的扇形（约±51°）
      damageEnemy(e, dmgF, e.x, e.y, "#ff7a3a", "", null, "@lord");
      e.burnT = Math.max(e.burnT || 0, 3);
      e.burnDmg = Math.max(e.burnDmg || 0, 6 + state.wave);
      e.burnSrc = "@lord";
      hitN++;
    }
    for (let i2 = 0; i2 < 40; i2++)
      state.particles.push({
        x: lpF.x + rand(-16, 16), y: lpF.y - 14,
        vx: rand(-200, 200), vy: rand(-520, -260),
        life: rand(0.5, 1.0), maxLife: 1.0, color: i2 % 3 ? "#ff7a3a" : "#ffd24a", size: rand(3, 7),
      });
    shake = 0.7;
    state.flash = 0.2;
    addFloater(W / 2, 300, `🔥 火烧雒阳！${hitN}个贼陷入火海·暴政印记：全军攻击+${state.tyranny}%`, "#ff7a3a", 22);
  } else if (slot.id === "jianhao") {
    // 僭号称帝（v7.0 袁术·献祭实验）：吃掉最弱的兵换大把经验——castLord 头部已保证 jianhaoTarget 非空
    const tgt = jianhaoTarget();
    let pr = -1, pc = -1;
    for (let r2 = 0; r2 < GRID_ROWS; r2++)
      for (let c2 = 0; c2 < GRID_COLS; c2++)
        if (state.slots[r2][c2] === tgt) { pr = r2; pc = c2; }
    if (pr >= 0) {
      state.slots[pr][pc] = null;
      computeTeam();   // 被吃不计 unitDeaths 不进 fallen：代价已付，不再毁三星
      const pp2 = slotCenter(pr, pc);
      const lpY = lordPos();
      state.beams.push({ x1: pp2.x, y1: pp2.y, x2: lpY.x, y2: lpY.y - 14, t: 0.5, color: "#ffd24a", w: 5 });
      burst(pp2.x, pp2.y, "#ffd24a", 26, 220);
      // 连升N级（精确档位，不受经验曲线段位影响）+祭品星级追加；亲兵助威折成下一级的进度
      const mulX = Math.max(0.01, state.buffs.xpGain * (state.field?.xpMul || 1));
      const upsT = st.ups + (tgt.level || 1);   // v7.3.2 祭品每星多1级：吃的投入吐回来还有赚
      const lvT = state.level + upsT;
      let guard = 0;
      while (state.level < lvT && guard++ < 200) gainXP(Math.max(1, state.xpNeed - state.xp) / mulX, "jianhao");
      if (kinPower() > 1) gainXP(state.xpNeed * (kinPower() - 1) * 0.8 / mulX, "jianhao");
      SFX.buff();
      addFloater(W / 2, 300, `🪙 僭号称帝！${tgt.type.name}(${tgt.level}星)为帝业献身，连升${upsT}级连抽${upsT}次`, "#ffd24a", 22);
      state.jianhaoN = (state.jianhaoN || 0) + 1;   // v7.7 献祭越多，下一道僭号号令等得越久
    }
  }
}

/* ---------- 波次生成 ---------- */
/* 特种黄巾：奔袭(快)、巫医(治疗光环)、旗手(加速光环)、妖术师(封印武将) */
const SPECIALS = {
  runner: { icon: "💨", name: "奔袭", minWave: 3,  ch: n => clamp(0.06 + n * 0.006, 0, 0.2) },
  healer: { icon: "🧙", name: "巫医", minWave: 6,  ch: n => clamp(0.03 + n * 0.005, 0, 0.12) },
  shooter:{ icon: "🏹", name: "弓贼", minWave: 7,  ch: n => clamp(0.03 + n * 0.005, 0, 0.12) },
  banner: { icon: "🚩", name: "旗手", minWave: 8,  ch: n => clamp(0.03 + n * 0.004, 0, 0.1) },
  thrower:{ icon: "💣", name: "投石兵", minWave: 9, ch: n => clamp(0.025 + n * 0.004, 0, 0.1) },
  shaman: { icon: "🌀", name: "妖术师", minWave: 10, ch: n => clamp(0.02 + n * 0.004, 0, 0.09) },
  /* —— 64关战役新特种（lvMin=第几关起会出现） —— */
  rattan: { icon: "🎋", name: "藤甲兵", minWave: 4, lvMin: 16, ch: n => clamp(0.03 + n * 0.004, 0, 0.1) },
  ram:    { icon: "🛞", name: "锤车",   minWave: 5, lvMin: 24, ch: n => clamp(0.02 + n * 0.003, 0, 0.08) },
  warden: { icon: "👺", name: "督军",   minWave: 6, lvMin: 32, ch: n => clamp(0.02 + n * 0.003, 0, 0.08) },
  /* —— 克制矩阵轮（2026-07-07）：补齐"没人怕它/没人克它"的空档——
     爆竹兵惩罚近战贴脸（弓的主场）、刺客跳后排捅弓辅（盾奶的活）、橹楯车克弹道（枪骑的活） —— */
  bomber:  { icon: "💥", name: "爆竹兵", minWave: 5, lvMin: 20, ch: n => clamp(0.035 + n * 0.005, 0, 0.13) },
  assassin:{ icon: "🗡️", name: "刺客",   minWave: 7, lvMin: 28, ch: n => clamp(0.03 + n * 0.005, 0, 0.12) },
  pavise:  { icon: "🐢", name: "橹楯车", minWave: 6, lvMin: 36, ch: n => clamp(0.025 + n * 0.004, 0, 0.1) },
};
/* 点开敌人面板时的大白话提示：这怪是干嘛的、该拿他怎么办 */
const SPECIAL_TIPS = {
  runner: "跑得飞快，小心漏进来",
  healer: "给周围的怪回血，先杀他",
  shooter: "远远放冷箭，会慢慢逼近",
  banner: "给周围的怪加速，先杀他",
  thrower: "扔石头砸一片，看红圈躲",
  shaman: "会封住武将不能动，赶紧杀",
  rattan: "藤甲厚皮血多，点燃烧他照样疼",
  ram: "死物免控：吓不倒迷不住锤只顿半拍，不理武将直奔城墙——半路用伤害磨死它",
  warden: "红圈里的怪都少挨打，先杀他",
  bomber: "死了原地炸一圈，别让近战贴着杀——弓兵远远点掉",
  assassin: "飞进阵里专捅后排，盾兵奶妈护着点",
  pavise: "大盾车：箭射不动，近战拆它最快",
};
const KIT_TIPS = {
  summon: "不停召援军，拖越久人越多，快点杀!",
  firepot: "往阵地扔火罐，武将别扎堆",
  volley: "乱箭点名武将，奶得跟上",
  split: "死了会裂成小的，小的还会再裂",
  sealwave: "一口气封俩武将，蔡文姬华佗能解",
  thunder: "天雷劈人，还免死一次——要杀他两遍",
  affixlord: "铁盾+回春+越残越疯，憋大招一口气打死",
  avatar: "张角全部本事都会，稳住别慌",
};

/* 抗性生成（2026-07-07 压力重构轮）：全员带题面——以前小怪第6波前裸抗、之后半数裸抗，
   实测撞抗阵容和对症阵容城血一模一样，"选将针对抗性"是句空话；现在小怪也从第1波起吃抗吃怕，
   带错属性真打不动（×0.45~0.5）、对症真的疼（×1.5）——题面从"点缀"变"必修"
   res = { fire: 0.7, ... } 受到该属性伤害 ×(1-值) */
/* v6.0：抗性表退役。每个怪一个三角属性——85%州主属性、15%杂色；贼首必是主属性 */
function rollTri(foes) {
  const main = foes && foes.tri;
  if (!main) return pick(TRI_KEYS);
  return Math.random() < 0.85 ? main : pick(TRI_KEYS.filter(k => k !== main));
}

/* 波次突变：一局里随机几波换题面，提前一波在预告里亮牌——阵成了也得随机应变 */
const MUTATIONS = {
  frenzy:   { icon: "😤", name: "狂暴之潮", desc: "这波个个狂奔，跑快35%" },
  horde:    { icon: "🐜", name: "人海之潮", desc: "小怪多七成，但个个只有七成血" },
  volley:   { icon: "🏹", name: "冷箭之潮", desc: "弓贼投石兵扎堆来，护住武将" },
  ironhide: { icon: "🔄", name: "变性之潮", desc: "这波贼集体换了属性，看清再打" },
  fat:      { icon: "🐑", name: "肥羊之潮", desc: "这波经验翻倍，别放跑了", good: true },
  /* 天气突变（天时退役并进来的）：提前一波预告，逼你换一波输出重心 */
  eastwind: { icon: "🌬️", name: "东风之潮", desc: "这波火烧翻倍、火伤+60%", good: true },
  rainstorm:{ icon: "🌧️", name: "大雨之潮", desc: "这波浇灭了火，带火/点燃流抓瞎" },
};
/* 天气查询：催战叠波时按最新一波的天气算 */
function wxRain() { return state.waveInfo?.mutation === "rainstorm"; }
function wxEast() { return state.waveInfo?.mutation === "eastwind"; }
/* 无尽军令（2026-07-05 长线留存轮）：无尽/试炼里每5波换一条、提前一波预告——
   阵成型之后问题还在流动，"成型后只剩刷数值"在无限模式下就此破掉 */
const ENDLESS_RULES = [
  { key: "smoke",    name: "烟瘴弥漫", tip: "弓兵射程-35%",           mod: { archerRngMul: 0.65 } },
  { key: "mud",      name: "泥沼遍地", tip: "骑兵冲锋只有一半远",     mod: { cavChargeMul: 0.55 } },
  { key: "crossbow", name: "连弩贼",   tip: "弓贼投石兵成倍地来",     mod: { rangedMul: 2.2 } },
  { key: "rush",     name: "急行军",   tip: "敌人跑快15%",           mod: { spdMul: 1.15 } },
  { key: "shift",    name: "换皮妖法", tip: "贼换了怕的属性，看预告", mod: {} },
];
function rollMutations(lv) {
  const m = {};
  const slots = lv.ch === 0 ? [[6, 8], [11, 14]] : [[5, 7], [9, 12], [14, 16]];   // 第一章温柔点
  const keys = Object.keys(MUTATIONS);
  for (const [a, b] of slots) {
    const w = randi(a, b);
    let k = pick(keys);
    if (k === "volley" && w < 8) k = "frenzy";     // 弓贼投石兵还没登场的波次换题
    if (k === "ironhide" && w < 8) k = "fat";      // 前期抗性还没铺开，反转没意义
    m[w] = k;
  }
  return m;
}

/* 无尽军令轮转：n=马上要造的下一波。提前一波探马预告，逢5生效换新（在造波前调，波才吃到新军令） */
function endlessRuleTick(n) {
  if (state.endlessMod && n > state.endlessMod.until) { state.endlessMod = null; state.endlessFoes = null; }
  if (state.endlessPending && n % 5 === 0) {
    state.endlessMod = { ...state.endlessPending, until: n + 4 };
    state.endlessPending = null;
    if (state.endlessMod.key === "shift") {
      // 换皮妖法：临时换一个怕系（基于本关原敌情，不叠加）
      const f = state.diff.foes;
      if (f && f.tri) state.endlessFoes = { tri: pick(TRI_KEYS.filter(k => k !== f.tri)) };   // v6.0：临时换个属性
    } else state.endlessFoes = null;
    addFloater(W / 2, 246, `⚔️ 军令「${state.endlessMod.name}」：${state.endlessMod.tip}`, "#ff9a6a", 16);
  } else if (!state.endlessPending && (n + 1) % 5 === 0 && n >= 4) {
    state.endlessPending = pick(ENDLESS_RULES.filter(r => r.key !== state.endlessMod?.key));
    addFloater(W / 2, 246, `🐎 下波军令「${state.endlessPending.name}」：${state.endlessPending.tip}`, "#ffb84a", 15);
  }
}

/* 深水区抗性轮换——已退役（v5.10.2 用户裁决）：每6波换怕系的实际效果是"教玩家无视属性"——
   后期压力下换阵容不现实，跟不上就干脆全程不看怕系，连开局按州选对症都省了。
   现在本州怕系一局到底：对症选将的回报重新成立；带预告的临时换皮妖法军令保留（明牌五波事件）。 */
/* 当前生效的敌情（v5.4.2）：军令换皮 > 当前波实情(waveInfo，异抗对调体现在里面) > 关卡题面。
   所有"现在怕什么"的读点必须走这里——直读 diff.foes 会漏掉军令/突变（破敌五行曾因此转错属性） */
function curFoesNow() {
  if (state.endlessFoes) return state.endlessFoes;
  if (state.waveInfo && state.waveInfo.themeElems && state.waveInfo.themeElems.length)
    return { tri: state.waveInfo.themeElems[0] };
  return state.diff?.foes || null;
}

function buildWave(n) {
  const q = [];
  const diff = state.diff;
  // 突变判定：预排的波次表优先；无尽模式（18波后）现场摇
  let mut = state.mutations?.[n] || (n >= 18 && Math.random() < 0.25 ? pick(Object.keys(MUTATIONS)) : null);
  // 铜雀香炉 v2「灾变成财」（2026-07-10 用户拍板）：不再取消凶险突变——改为提前两波预警+突变波金币+50%（预警画在预告框、金币在killGold）
  // 本关敌情（没有就按老规矩每波乱摇，留给测试/无尽兜底）；换皮妖法军令期间用临时怕系。
  // 深水怕系轮换已退役（v5.10.2）：本州怕系一局到底——对症选将的回报重新成立
  let foes = state.endlessFoes || diff.foes;
  if (!foes) foes = { tri: pick(TRI_KEYS) };   // 兜底（测试/无题面）
  if (mut === "ironhide" && foes && foes.tri)   // 变性之潮（v6.0）：这波贼集体换属性（顺移一格）
    foes = { tri: TRI_KE[foes.tri] };
  let count = Math.min(96, 10 + Math.floor(n * 3.3));
  if (mut === "horde") count = Math.min(130, Math.round(count * 1.7));
  // 诱敌深入：只吃一波——多3成人、个个脆皮、经验金币加成
  const yd = state.youdi;
  if (yd) { state.youdi = null; count = Math.min(130, Math.round(count * 1.3)); }
  let hpK = (mut === "horde" ? 0.7 : 1) * (yd ? yd.hpK : 1);
  // 无尽增压（缓坡版）：头5波热身不加压，之后 1.06/1.09/1.12/1.15 四级渐入，再恒定每波×1.18——
  // 顶还在（1.18复利兜底），入山的路多铺了几波（玩家要求整体顺延3~5波）
  // ⚠️ 设计不变量（v7.11 势力值口径）：这个1.18是防"全通后蹲简单城刷讨伐值"的唯一承重墙。
  //    露营安全条件 0.25/ln(增压) < 1+0.25×band深度：增压1.18时往低走一关只多撑约1.1波、亏17%繁荣度，必亏；
  //    若增压降到≈1.10以下，蹲简单城翻成最优策略——想放缓无尽墙前必须先重算这条不等式（与繁荣度梯度无关）。
  const extraW = state.endless && state.winWave ? Math.max(0, n - state.winWave - 5) : 0;
  if (extraW) {
    const RAMP = [1.06, 1.09, 1.12, 1.15];   // 渐入四级，然后 1.18 到底
    for (let i = 1; i <= extraW; i++) hpK *= RAMP[i - 1] || 1.18;
  }
  // 深水区瘦身补血：一波超过72个就减人头、把血补回去（波总血量不变）——后期不再96个怪挤一屏，手机不卡
  const rawCount = count;
  if (count > 72 && mut !== "horde" && !yd) {
    count = 72;
    hpK *= rawCount / count;
  }
  const spdK = mut === "frenzy" ? 1.35 : 1;
  const hp = Math.round(12 * Math.pow(diff.hpGrow, n - 1) * diff.hpMul * hpK);
  const spd = clamp(30 + n * 2.0, 30, 96) * diff.spdMul * spdK * (state.endlessMod?.mod?.spdMul || 1);
  // 粮仓轮：杀怪经验砍到65%，另一条收入线给粮仓——零仓照样能打（约现节奏的82~86%），贪仓才吃到大头
  const baseXp = (2 + Math.floor(n / 8)) * 0.65 * (mut === "fat" ? 2 : 1) * (yd ? yd.gainK / 1.3 : 1);   // 后期单杀经验提升，保持选卡节奏；诱敌除以量因子1.3——整波收成恰=gainK，堵"人头×经验"双重计费（v5.6 贾诩sim揪出的复利口）
  // 远程怪加倍：连弩贼规则 × 冷箭之潮突变 × 无尽军令
  const rangedK = (diff.rangedMul || 1) * (state.endlessMod?.mod?.rangedMul || 1) * (mut === "volley" ? 4 : 1);
  const themeElems = foes && foes.tri ? [foes.tri] : [];   // v6.0：波的属性=主属性（85%纯度）
  for (let i = 0; i < count; i++) {
    const cls = pick(ENEMY_CLS);
    // 特种兵优先判定
    let special = null;
    for (const [key, sp] of Object.entries(SPECIALS)) {
      const ranged = key === "shooter" || key === "thrower";
      const minWave = ranged && mut === "volley" ? Math.min(sp.minWave, 5) : sp.minWave;   // 冷箭之潮：弓贼提前登场
      let ch = Math.min(0.6, sp.ch(n) * (ranged ? rangedK : 1) * (state.weekTheme === "yunchou" ? 1.6 : 1));
      // 锤车中后期常驻（v7.17.12）：不再锁战役24关——任何关12波起一点点混入；
      // 深水区出场率爬坡：纯控制推怪/无限回血挡得住兵，挡不住直奔城墙的死物——城防的价值立起来
      let lvOk = !sp.lvMin || (state.diff.lvIdx ?? state.diff.idx) >= sp.lvMin;
      if (key === "ram") {
        if (n >= 12) lvOk = true;
        if (state.endless && state.winWave) ch = Math.min(0.3, ch + Math.max(0, n - state.winWave - 5) * 0.012);
      }
      if (n >= minWave && lvOk && Math.random() < ch) { special = key; break; }
    }
    if (special) {
      const mul = { runner: [0.5, 2.2], healer: [1.6, 0.7], banner: [2.2, 0.8], shaman: [1.8, 0.75],
                    shooter: [1.9, 0.85], thrower: [2.2, 0.7],
                    rattan: [3.0, 0.8], ram: [6.0, 0.5], warden: [2.5, 0.75],
                    bomber: [0.9, 1.1], assassin: [1.4, 1.6], pavise: [2.8, 0.65] }[special];
      q.push({
        delay: i === 0 ? 0 : rand(0.3, Math.max(0.35, 1.0 - n * 0.03)),
        hp: Math.round(hp * mul[0]), speed: spd * mul[1],
        r: special === "runner" ? 14 : special === "ram" ? 27 : special === "shooter" || special === "thrower" ? 23
          : special === "assassin" ? 16 : special === "pavise" ? 25 : special === "bomber" ? 18 : 21,
        cls, big: false, affix: null, special,
        tri: rollTri(foes),
        xp: baseXp * (special === "runner" ? 1 : 3),
        dmg: special === "ram" ? 4 : special === "runner" ? 1 : 2,
      });
      continue;
    }
    const big = Math.random() < clamp(0.06 + n * 0.011, 0, 0.3);
    // 第4波起，大个子有概率带词缀成为精英
    let affix = null;
    if (big && n >= 3 && Math.random() < clamp(0.34 + n * 0.025 + diff.affixAdd, 0, 0.9))
      affix = pick(Object.keys(AFFIXES));
    q.push({
      delay: i === 0 ? 0 : rand(0.3, Math.max(0.35, 1.0 - n * 0.03)),
      hp: big ? hp * (affix ? 4.5 : 3.2) : hp,
      speed: big ? spd * 0.65 : spd * rand(0.85, 1.15),
      r: big ? 26 : randi(15, 19),
      cls, big, affix,
      tri: rollTri(foes),
      xp: big ? (affix ? baseXp * 4 : baseXp * 3) : baseXp,
      dmg: big ? 3 : 1,
    });
  }
  if (n % 5 === 0) {
    const bossName = state.diff.bossName || BOSS_NAMES[Math.min(n / 5 - 1, BOSS_NAMES.length - 1)];
    const mega = bossName.includes("张角");
    const bossSpec = {
      delay: 1.2,
      hp: hp * (mega ? 26 : 16), speed: spd * 0.45, r: mega ? 46 : 40,
      cls: pick(ENEMY_CLS),
      boss: true, bossName, xp: baseXp * (mega ? 25 : 14), dmg: mega ? 10 : 6,
      affix: mega || state.diff.bossKit === "affixlord" ? "shield" : null,
      tri: foes && foes.tri ? foes.tri : pick(TRI_KEYS),
      summoner: n >= 10 || state.diff.bossKit === "summon" || state.diff.bossKit === "avatar",
      kit: state.diff.bossKit || null,
      kitSplit: state.diff.bossKit === "split" ? 2 : 0,
    };
    q.push(bossSpec);
    // 修罗：双贼首
    if (diff.eliteWave)
      q.push({ ...bossSpec, delay: 2.5, hp: Math.round(bossSpec.hp * 0.75), bossName: bossName + "·影" });
  }
  q.themeElems = themeElems;
  q.weakElem = foes && foes.tri ? triCounterOf(foes.tri) : null;   // 沿用字段名：weakElem=克这波贼的那一系
  q.mutation = mut;
  if (yd) { q.youdi = true; for (const s of q) s.bounty = yd.gainK; }   // 金币加成挂每个兵身上（damageEnemy 结账时乘）
  return q;
}

/* 从波次队列生成预告摘要 */
function summarizeWave(q) {
  const counts = { spear: 0, cav: 0, archer: 0 };
  const affixes = {};
  const specials = {};
  let boss = null;
  for (const s of q) {
    counts[s.cls]++;
    if (s.affix) affixes[s.affix] = (affixes[s.affix] || 0) + 1;
    if (s.special) specials[s.special] = (specials[s.special] || 0) + 1;
    if (s.boss) boss = s.bossName;
  }
  return { counts, affixes, specials, boss, themeElems: q.themeElems, weakElem: q.weakElem, mutation: q.mutation, youdi: q.youdi };
}

/* —— 波次推进（贼军不等人）——
 * prepareNextWave：预生成下一波+预告（休整期开头、或催战预警时提前亮牌）
 * startNextWave：正式开波——休整倒计时走完、或本波预算耗尽被强行压上，都走这一条路 */
function prepareNextWave() {
  if (state.nextQueue) return;
  if (state.endless) endlessRuleTick(state.wave + 1);   // 军令先定，再造波——下波才吃得到新军令
  state.nextQueue = buildWave(state.wave + 1);
  state.nextWavePreview = summarizeWave(state.nextQueue);
}
function startNextWave() {
  prepareNextWave();
  state.wave++;
  if (state.endless) meta.endlessBest = Math.max(meta.endlessBest || 0, state.wave);   // 无尽深度上榜
  // 攻坚增压开闸横幅（v7.17.4）：贼刀开始复利的那一波明牌告知——规则变了不搞暗算
  if (state.endless && state.winWave && state.wave === state.winWave + 6) {
    addFloater(W / 2, 372, "⚔️ 贼势攻坚！撑得越深，贼的刀越重", "#ff8a5a", 18);
    addFloater(W / 2, 396, "⛓️ 贼练出韧性了！镣铐越锁越松", "#c9a8ff", 16);
  }
  if (state.wave % 5 === 0 && techLv("mend") && state.baseHP > 0 && state.baseHP < state.baseHPMax) {
    state.baseHP = Math.min(state.baseHPMax, state.baseHP + techLv("mend"));
    addFloater(W / 2, DEFENSE_LINE - 60, `🧱 缮城 +${techLv("mend")}`, "#9adf5a", 15);
  }
  state.spawnQueue = state.nextQueue;
  state.waveInfo = { themeElems: state.nextQueue.themeElems, weakElem: state.nextQueue.weakElem, mutation: state.nextQueue.mutation };
  state.nextQueue = null;
  state.nextWavePreview = null;
  state.spawnTimer = 0;
  state.waveTimer = 3.4;
  // 时间预算 = 本波出兵总时长 + 宽限14秒（贼首波再多给6秒）——预算耗尽下一波不等清场直接压上
  const spawnDur = state.spawnQueue.reduce((a, s) => a + s.delay, 0);
  state.waveBudget = spawnDur + 14 + (state.spawnQueue.some(s => s.boss) ? 6 : 0);
  state.waveClock = 0;
  state.rushWarned = false;
  addFloater(W / 2, 160, `—— 黄巾第 ${state.wave} 波 ——`, "#e8c86a", 22);
  if (state.waveInfo.mutation) {
    const mu = MUTATIONS[state.waveInfo.mutation];
    addFloater(W / 2, 228, `${mu.icon}「${mu.name}」${mu.desc}`, "#ff9a6a", 16);
  }
  SFX.waveStart();
  if (state.wave >= 20) unlockAch("wave20");
  if (state.wave >= 35) unlockAch("wave35");
  if (state.wave === 11 && state.baseHP >= state.baseHPMax) unlockAch("ironwall");
  state.baihuReady = hasRelic("baihu");
}

function spawnEnemy(spec) {
  let hp = spec.hp, speed = spec.speed;
  const f = state.field;
  if (f?.hpMul) hp = Math.round(hp * f.hpMul);
  if (f?.spdMul) speed *= f.spdMul;
  // 出生点：全宽随机（虎牢关收窄）
  const xMin = f?.narrow ? W * 0.28 : 40;
  const xMax = f?.narrow ? W * 0.72 : W - 40;
  const sx = rand(xMin, xMax);
  state.enemies.push({
    x: spec.x ?? sx, y: spec.y ?? -40,   // 渠帅空投（v7.18.0）：可指定落点
    tri: spec.tri || null,   // 三角属性（v6.0）：抗性表退役
    hp, hpMax: hp,
    baseSpeed: speed, r: spec.r,
    cls: spec.cls, big: !!spec.big, boss: !!spec.boss,
    bossName: spec.bossName,
    affix: spec.affix || null,
    shield: spec.affix === "shield" ? Math.round(hp * 0.6) : 0,
    shieldMax: spec.affix === "shield" ? Math.round(hp * 0.6) : 0,
    xp: spec.xp, dmg: spec.dmg, bounty: spec.bounty || 1,
    special: spec.special || null,
    summoner: !!spec.summoner,
    summonT: spec.kit === "summon" || spec.kit === "avatar" ? 3.5 : 6,   // 程远志/化神第一波援军也来得快
    kit: spec.kit || null, kitSplit: spec.kitSplit || 0,
    auraT: 0, sealT: 0,
    slowT: 0, burnT: 0, burnDmg: 0, burnTick: 0, regenTick: 0, charmT: 0, stunT: 0, fearT: 0, silencedT: 0,
    wob: rand(0, Math.PI * 2),
    face: spec.boss ? spec.bossName.replace("\u00b7\u5f71", "")
      : spec.affix ? AFFIXES[spec.affix].name
      : spec.special ? SPECIALS[spec.special].name
      : spec.big ? "\u529b\u58eb" : "\u5175",
    hitFlash: 0,
  });
  if (spec.boss) {
    SFX.bossSpawn();
    addFloater(W / 2, 200, `⚠️ 贼首「${spec.bossName}」来袭 ⚠️`, "#ff5a5a", 24);
    if (spec.kit && KIT_TIPS[spec.kit]) addFloater(W / 2, 232, KIT_TIPS[spec.kit], "#ffb84a", 15);
  }
}

/* ---------- 武将受击/阵亡 ---------- */
function hurtUnit(u, dmg, r, c) {
  // 桃园义全军金身（v7.3.0）：结义期间全员刀枪不入（v7.5.1 挡刀飘"免!"——不然玩家不知道金身在干活）
  if (state.taoyuanT > 0) {
    state.taoyuanAbsorb = (state.taoyuanAbsorb || 0) + dmg;   // 桃园反击（v7.14）的账本：金身扛住的每一刀都记着
    u.hurtFlash = 0.2;
    const pcI = slotCenter(r, c);
    addFloater(pcI.x + rand(-10, 10), pcI.y - 34, "免!", "#ffd278", 13);
    return;
  }
  // 曹洪·舍身：相邻曹洪替兄弟挨25%的刀（大招期间60%）——直接扣血不递归
  if (u.type.id !== "caohong") {
    for (let rr = Math.max(0, r - 1); rr <= Math.min(GRID_ROWS - 1, r + 1); rr++)
      for (let cc = Math.max(0, c - 1); cc <= Math.min(GRID_COLS - 1, c + 1); cc++) {
        const ch = state.slots[rr][cc];
        if (ch && ch.type.id === "caohong" && ch.hp > 1) {
          const share = Math.min(ch.hp - 1, Math.round(dmg * (ch.guardT > 0 ? 0.6 : 0.25)));
          if (share > 0) { ch.hp -= share; ch.hurtFlash = 1; dmg -= share; }
          rr = 99; break;   // 只找一个曹洪
        }
      }
  }
  // 坚岩特质：所站格受伤-20%
  if (cellTrait(r, c) === "guard") dmg = Math.round(dmg * 0.8);
  // 盾护：相邻盾兵为友军减伤25%（虎符35%；盾兵自身不吃）——v7.18.5 站盾边上要有安全感
  if (u.type.cls !== "shield" && hasAdjacentShield(r, c)) dmg = Math.round(dmg * (hasRelic("hufu") ? 0.65 : 0.75));
  dmg = Math.max(1, dmg);
  u.hp -= dmg;
  u.hurtFlash = 1;
  const p = slotCenter(r, c);
  if (Math.random() < 0.5) addFloater(p.x + rand(-10, 10), p.y - 30, `-${dmg}`, "#ff7a6a", 12);
  // 盾系·蓄势反击（v4.23.0 职业机制）：扛下的伤害攒进怒气，攒满自身血上限60%就对周围敌人轰回去（攒的×0.8）。
  // 抗得越多打得越疼——把"能抗住但杀不掉"的抗伤转成输出，且随波次压力自动放大（后期敌人打得疼→反得也疼）
  if (u.type.cls === "shield" && u.hp > 0) {
    u.tanked = (u.tanked || 0) + dmg;
    if (u.tanked >= u.hpMax * 0.6) {
      const ret = Math.round(u.tanked * 0.8);
      u.tanked = 0;
      let hitN = 0;
      for (const e of state.enemies) {
        if (e.dead) continue;
        if (Math.abs(e.x - p.x) < CELL * 1.6 && Math.abs(e.y - p.y) < CELL * 1.6) {
          damageEnemy(e, ret, e.x, e.y - e.r, "#ffd24a", hitN ? "" : "蓄势反击!", null, u);
          hitN++;
        }
      }
      if (hitN) burst(p.x, p.y, "#ffd24a", 18, 150);
      else u.tanked = Math.round(u.hpMax * 0.6);   // 周围没人（挨的是投石/毒雾）：怒气憋着，等贼近身再轰
    }
  }
  if (u.hp <= 0) {
    // 周泰·不屈：每局免死一次，半血站起来
    if (u.type.id === "zhoutai" && !u.revived) {
      u.revived = true;
      u.hp = Math.round(u.hpMax * 0.5);
      burst(p.x, p.y, "#8ad2ff", 26, 210);
      addFloater(p.x, p.y - 44, "不屈！周泰又站起来了", "#8ad2ff", 15);
      return;
    }
    // 孟获·七擒七纵（v7.6.0）：阵亡原地站起来（最多6次，血上限每次×0.85递减），复活即嘲讽立威。
    // 七擒之内不算真死（不计unitDeaths不毁三星）；第7次才走正常死亡
    if (u.type.id === "menghuo" && (u.mhRevives || 0) < 6) {
      u.mhRevives = (u.mhRevives || 0) + 1;
      u.hpMax = Math.max(60, Math.round(u.hpMax * 0.85));
      u.hp = u.hpMax;
      u.rageN = (u.rageN || 0);   // 蓄势怒气保留
      burst(p.x, p.y, "#ff8a5a", 30, 240);
      for (const e of aliveEnemies())   // 复活立威：一声怒吼震退周围的贼
        if (Math.hypot(e.x - p.x, e.y - p.y) < 180) e.fearT = Math.max(e.fearT || 0, 1.0);
      addFloater(p.x, p.y - 44, `七擒七纵！孟获第${u.mhRevives}次站起来`, "#ff8a5a", 15);
      SFX.buff();
      return;
    }
    // 典韦·舍身：战死爆一大波经验（半级）
    if (u.type.id === "dianwei") {
      gainXP(Math.max(10, Math.round(state.xpNeed * 0.5)));
      addFloater(p.x, p.y - 58, "典韦舍身！经验+一大截", "#ffe45a", 15);
    }
    state.slots[r][c] = null;
    if (u.type.cls !== "granary" && u.type.cls !== "egg") state.unitDeaths++;

    if (state.drag && state.drag.unit === u) state.drag = null;  // 阵亡瞬间正被拖动：取消拖动，防"鬼将"落格
    computeTeam();
    if (state.ultConfirm && state.ultConfirm.unit === u) state.ultConfirm = null;
    burst(p.x, p.y, "#ff6a5a", 24, 200);
    burst(p.x, p.y, "#3a3024", 12, 120);
    addFloater(p.x, p.y - 40, u.type.cls === "granary" ? "💥 粮仓被拆了！"
      : u.type.cls === "egg" ? "💔 龙蛋碎了！血本无归" : `💀 ${u.type.name}阵亡！`, "#ff5a5a", 18);
    SFX.gameOver && SFX.kill();
    shake = Math.max(shake, 0.5);
  }
}

/* ---------- 伤害结算 ---------- */
let linkProp = false;   // 死亡链接传导中（防递归）
/* 城破收场（敌人撞墙扣光 / 自刎归天共用）：清弹道、结算主公经验、流水入库。
   幂等（v5.8.1 后台数据揪出：同一帧多个敌人撞墙会连环触发——875条流水里115条是重复城破，
   结算/主公经验/入库全×N）：进过 over 就不再走第二遍 */
function cityFall() {
  if (state.phase === "over") return;
  state.baseHP = 0;
  state.phase = "over";
  state.ebullets = [];   // 清掉飞行中的弹道/机关，结算画面不留残影
  state.elobs = [];
  state.flobs = [];
  state.homers = [];
  state.traps = [];
  state.firePits = [];
  state.deathLink = null;
  state.palisades = [];
  state.turrets = [];
  if (state.maxHit >= 5000) unlockAch("maxhit5k");
  settleLordXp("over");   // 主公经验：败仗也有安慰（无尽收尾另算小额）
  achSweep();
  saveMeta();   // 势力值在讨伐里每撑完一波就已记账，城破这波不算
  netLogBattle("over");   // 战斗流水：城破的这一局数据入库（含无尽撑到多少波）
  netCheckNewVer();        // 无感热更：结算期悄悄比对版本，出门时若有新版带标记自刷新
  SFX.gameOver();
}
function inFlood(e) {
  const fl = state.flood;
  return !!(fl && fl.t > 0 && e.y > fl.y1 && e.y < fl.y2);
}
function damageEnemy(e, dmg, hx, hy, color = "#ffffff", tag = "", elem = null, src = null) {
  // 三才破敌 v7.16 重做（用户："全算克制=抄答案，影响答题变化"，实测曹操克制命中率69% vs 他家52~58）：
  // 窗口期改为"被克的减免全部失效+全军伤害+15%"——答错不挨罚，但×1.5仍留给真正带对系的人
  if (state.wuxingT > 0 && elem) {
    if (e.tri && TRI_KE[e.tri] === elem) elem = null;   // 被克→按同系原价
    dmg *= 1.15;
  }
  if (e.charmT > 0) dmg *= 1.3;
  // 沉沙折戟遗宝：被封住嘴的敌人多挨15%打
  if (e.silencedT > 0 && hasRelic("chensha")) dmg *= 1.15;
  // 监军令：被按住的贼头目多挨打
  if (e.jianjunT > 0) dmg *= 1 + (e.jianjunAmp || 0.2);
  // 截江断流（水战之利）：江里的贼挨打多
  if (inFlood(e)) dmg *= 1 + (state.flood.amp || 0.3);
  // 落井下石（v7.16 永久战术卡）：受制的贼挨打+30%——控制流的输出转化器
  if (state.luojingOn && (e.slowT > 0 || e.stunT > 0 || e.fearT > 0 || e.sleepT > 0 || e.charmT > 0 || inFlood(e))) dmg *= 1.3;
  // 督军督战光环
  if (e._guarded) dmg *= 0.7;
  // 三角克制（v6.0 全游戏唯一克制表）：克制×1.5 / 被克×0.6 / 同系原价。
  // 徐庶卸抗新语义：armorBreakT 期间"被克减免"失效——撞系保险丝（水镜遗书/羁绊时还多挨一成）
  let triHit = 0;   // 1=克制 -1=被克
  if (elem && e.tri) {
    if (TRI_KE[elem] === e.tri) {
      triHit = 1;
      dmg *= 1.5;
      if (!tag) { tag = "怕!"; color = "#5aff9a"; }
    } else if (TRI_KE[e.tri] === elem) {
      triHit = -1;
      if (e.armorBreakT > 0) dmg *= bondHas("shuijing") ? 1.2 : hasRelic("shuijingshu") ? 1.1 : 1;   // 羁绊1.2＞遗宝1.1，同有取大
      else {
        dmg *= 0.6;
        if (!tag) { tag = "不疼!"; color = "#9a9a9a"; }
      }
    }
  }
  dmg = Math.max(1, Math.round(dmg));
  if (dmg > state.maxHit) state.maxHit = dmg;
  // 伤害统计（v7.17.5）：记实际能扣掉的血（含破盾、不含溢出）——秒杀流不虚报
  dmgLedger(src, Math.min(dmg, Math.max(0, e.shield || 0) + Math.max(0, e.hp)));
  // 对症统计：克制伤害占比，结算页给玩家看"换打法有没有用"
  state.totalDmg += dmg;
  if (triHit === 1) state.counterDmg += dmg;
  // 铁盾：先破盾
  if (e.shield > 0) {
    const absorbed = Math.min(e.shield, dmg);
    e.shield -= absorbed;
    dmg -= absorbed;
    e.hitFlash = 1;
    if (e.shield <= 0) addFloater(e.x, e.y - e.r - 14, "破盾!", "#8ad2ff", 15);
    else if (Math.random() < 0.3) addFloater(hx, hy - 10, `⛨${absorbed}`, "#8ad2ff", 11);
    if (dmg <= 0) return;
  }
  e.hp -= dmg;
  e.hitFlash = 1;
  // 胡笳催眠：挨打惊醒（睡着≠白挨打，配合AOE要一波收掉）
  if (e.sleepT > 0) e.sleepT = 0;
  // 死亡链接（诸葛亮）：链上一只挨打，其余全跟着掉血
  if (!linkProp && state.deathLink && state.deathLink.t > 0 && state.deathLink.members.includes(e)) {
    linkProp = true;
    const share = Math.max(1, Math.round(dmg * (hasRelic("xuantie") ? 0.7 : 0.55)));   // 玄铁锁链：共享比例更高
    const DL = state.deathLink;   // 先抓住再循环：分摊若打死最后一个敌人，通关结算会把 state.deathLink 置空——现取就是 null.src 炸主循环（v7.17.7回归，两位玩家卡死）
    for (const m of DL.members)
      if (m !== e && !m.dead) damageEnemy(m, share, m.x, m.y, "#c9a8ff", "", null, DL.src);
    linkProp = false;
  }
  SFX.hit();
  if (tag || dmg >= 30 || Math.random() < 0.25)
    addFloater(hx + rand(-8, 8), hy - 10, `${dmg}${tag}`, color, tag ? 15 : 12);
  if (e.hp <= 0 && !e.dead) {
    // 张角/天公化神：天命未绝，免死一次（4成血站起来）
    if (e.boss && (e.kit === "thunder" || e.kit === "avatar") && !e.revived) {
      e.revived = true;
      e.hp = Math.round(e.hpMax * 0.4);
      state.flash = Math.max(state.flash || 0, 0.4);
      burst(e.x, e.y, "#ffe45a", 30, 240);
      addFloater(e.x, e.y - e.r - 22, "⚡ 天命未绝！又站起来了", "#ffe45a", 17);
      return;
    }
    e.dead = true;
    state.kills++;
    meta.totalKills++;
    SFX.kill();
    // 火烧连营（v7.16）：着火的贼死亡爆燃——炸伤周围还把火传过去，火越多营越连
    if (state.huoshaoOn && e.burnT > 0 && e.burnDmg > 0) {
      burst(e.x, e.y, "#ff8a3a", 14, 160);
      for (const e2 of state.enemies) {
        if (e2.dead || e2 === e || dist2(e.x, e.y, e2.x, e2.y) > 90 ** 2) continue;
        damageEnemy(e2, e.burnDmg * 3, e2.x, e2.y, "#ff7a3a", "燎!", null, e.burnSrc || "@fire");
        if (!e2.dead && !wxRain()) {
          e2.burnT = Math.max(e2.burnT || 0, 2);
          e2.burnDmg = Math.max(e2.burnDmg || 0, Math.round(e.burnDmg * 0.8));
          e2.burnSrc = e.burnSrc || e2.burnSrc;
        }
      }
    }
    let goldGain = (e.boss ? 10 : 1) * (e.bounty || 1);   // 诱敌深入：肥羊波金币加成
    if (hasRelic("yuxi")) goldGain *= 2;
    if (state.field?.goldMul) goldGain *= state.field.goldMul;
    // 无尽金币递减（2026-07-08 经济修正）：通关线后每多一波杀敌金×0.88——
    // 首日实测无尽是印钞机（头部一天刷出两周半收入，英雄等级一天毕业），
    // 讨伐比的是深度换讨伐值，不是提款机；平推和通关线前的收入一分不动
    const goldDecayW = state.endless && state.winWave ? Math.max(0, state.wave - state.winWave) : 0;
    if (goldDecayW) goldGain *= Math.pow(0.88, goldDecayW);
    // 铜雀香炉「灾变成财」：凶险突变波打贼金币+50%
    if (hasRelic("tongque") && state.waveInfo?.mutation && !MUTATIONS[state.waveInfo.mutation].good) goldGain *= 1.5;
    // 江东通饷（v7.16.5 孙权重构）：杀敌经验+30%全时、江中击杀经验×2——只走经验不碰金币：
    // 经验是局内资源刷不走；金币是局外资产，×2等于开"低关孙权刷金"后门（用户抓的）
    const drown = state.ruler === "sunquan" && inFlood(e);
    goldGain = Math.max(1, Math.round(goldGain * state.diff.goldMul * (1 + techLv("bounty") * 0.04)
      * (state.ruler === "dongzhuo" ? 1 + 0.02 * lordLv("dongzhuo") : 1)   // 董卓·横征暴敛（v5.6）
      * (visitBuffOn("gold") ? 1.2 : 1)));   // 黄历·宜求财（v7.17 寻访奇遇卡）：30分钟杀敌金币×1.2
    state.goldEarned += goldGain;
    earnGold(goldGain);
    burst(e.x, e.y, "#e8c86a", e.boss ? 40 : 14, e.boss ? 260 : 150);
    burst(e.x, e.y, CLASSES[e.cls].color, 8, 120);
    if (drown) addFloater(e.x, e.y - e.r - 8, "⚓双粮!", "#8ad2ff", 12);
    // 经验引擎按主公结算（v7.16.5 弱势主公统一上经验轴）：
    // 孙权·通饷=全时1.3/江中2；公孙瓒·首级记功=主公亲手（白马/强弩）击杀×2；董卓·火葬收魂=着火烧死的×1.5
    let xpMul = 1;
    if (state.ruler === "sunquan") xpMul = drown ? 2 : 1.3;
    else if (state.ruler === "gongsunzan" && state._lordKill) { xpMul = 3; addFloater(e.x, e.y - e.r - 8, "🐎首级!", "#e8f4ff", 12); }   // v7.16.5 定标×3：探针测基线12%主公杀→2.7手，投资后30%→5.5手（投资才起飞）
    else if (state.ruler === "dongzhuo" && e.burnT > 0) { xpMul = 2; if (Math.random() < 0.3) addFloater(e.x, e.y - e.r - 8, "🔥收魂!", "#ff9a6a", 12); }   // 定标×2：着火死占~35%→3.5手
    gainXP(e.xp * xpMul);
    // 张梁：裂而再生——死了分成两个小号，小号再死还裂一次
    if (e.kitSplit > 0) {
      for (let i = 0; i < 2; i++) {
        state.enemies.push({
          x: clamp(e.x + rand(-36, 36), 16, W - 16), y: e.y + rand(-10, 10),
          hp: Math.round(e.hpMax * 0.4), hpMax: Math.round(e.hpMax * 0.4),
          baseSpeed: e.baseSpeed * 1.25, r: Math.max(22, e.r - 12),
          cls: e.cls, big: true, boss: false, affix: null,
          shield: 0, shieldMax: 0, tri: e.tri,
          xp: Math.max(2, Math.round(e.xp * 0.25)), dmg: 3,
          special: null, summoner: false, summonT: 0, auraT: 0, sealT: 0,
          kitSplit: e.kitSplit - 1,
          slowT: 0, burnT: 0, burnDmg: 0, burnTick: 0, regenTick: 0, charmT: 0, stunT: 0, fearT: 0, silencedT: 0,
          wob: rand(0, Math.PI * 2), face: "梁", hitFlash: 0,
        });
      }
      addFloater(e.x, e.y, "裂开了!", "#ff8a5a", 16);
    }
    // 爆竹兵：死了原地炸一圈——贴脸杀他的近战吃满，远程点杀白嫖（盾墙照旧挡一半）
    if (e.special === "bomber") {
      burst(e.x, e.y, "#ff7a3a", 22, 200);
      shake = Math.max(shake, 0.4);
      const bDmg = Math.round(14 + state.wave * 1.0);
      for (let rr = 0; rr < GRID_ROWS; rr++)
        for (let cc = 0; cc < GRID_COLS; cc++) {
          const uu = state.slots[rr][cc];
          if (!uu) continue;
          const pc = slotCenter(rr, cc);
          if (dist2(pc.x, pc.y, e.x, e.y) > (115 + 20) ** 2) continue;
          const cover = uu.type.cls !== "shield" && shieldCover(rr, cc);
          hurtUnit(uu, cover ? Math.round(bDmg * (hasRelic("hufu") ? 0.35 : 0.5)) : bDmg, rr, cc);
          if (cover && !uu.dead) addFloater(pc.x, pc.y - 30, "盾墙挡一半!", "#e8c96a", 12);
        }
      addFloater(e.x, e.y, "💥 炸了!", "#ff8a4a", 16);
    }
    // 分裂：死亡放出两只小兵
    if (e.affix === "split") {
      for (let i = 0; i < 2; i++) {
        state.enemies.push({
          x: clamp(e.x + rand(-24, 24), 16, W - 16), y: e.y + rand(-10, 10),
          hp: Math.round(e.hpMax * 0.2), hpMax: Math.round(e.hpMax * 0.2),
          baseSpeed: e.baseSpeed * 1.5, r: 13,
          cls: e.cls, big: false, boss: false, affix: null,
          shield: 0, shieldMax: 0, tri: e.tri,
          xp: 1, dmg: 1,
          slowT: 0, burnT: 0, burnDmg: 0, burnTick: 0, regenTick: 0, charmT: 0, stunT: 0, fearT: 0,
          wob: rand(0, Math.PI * 2), face: "\u5352", hitFlash: 0,
        });
      }
      addFloater(e.x, e.y, "分裂!", "#c9a8ff", 14);
    }
    if (e.boss) {
      shake = 0.9;
      SFX.bossDie();
      addFloater(W / 2, 240, `「${e.bossName}」授首！金币+${goldGain}`, "#9aff8a", 24);
      if (e.bossName === "张角") unlockAch("zhangjiao");
      meta.bossKills = (meta.bossKills || 0) + 1;
      saveMeta();
      rollRelics();
    }
    if (state.kills >= 100) unlockAch("first100");
    if (state.kills >= 800) unlockAch("slay800");
    if (state.kills >= state.killTarget && !state.endless) {
      state.phase = "win";
      state.ebullets = [];   // 清掉飞行中的弹道/机关，结算画面不留残影
      state.elobs = [];
      state.flobs = [];
      state.homers = [];
      state.traps = [];
      state.firePits = [];
      state.deathLink = null;
      state.palisades = [];
      state.turrets = [];
      meta.wins++;
      // 三星评价：赢1星 + 城墙无伤1星 + 无人阵亡1星——对症打法的分数差在这看得见
      state.stars = calcStars();
      state.winWave = state.wave;
      if (state.diff.week != null) {
        const wk = state.diff.k;
        const firstClear = !meta.weekClears[wk];
        meta.weekClears[wk] = (meta.weekClears[wk] || 0) + 1;
        meta.weekStars[wk] = Math.max(meta.weekStars[wk] || 0, state.stars);
        if (firstClear) {   // 首通大赏：每周每关一次（周一换图重置＝周薪基本盘）
          state.firstClearGold = state.diff.firstGold;
          earnGold(state.diff.firstGold);
          state.goldEarned += state.diff.firstGold;
        }
        recordWeekScore(0);   // 先按不打无尽记一笔分，接着打无尽每撑一波再涨
        // 韬略分：通关那一刻算一次（对症×少损×顺应天时），入韬略榜，不吃讨伐波数
        state.runTech = weekTechScore(wk);
        meta.weekTech[wk] = Math.max(meta.weekTech[wk] || 0, state.runTech);
        if (wk >= 12) unlockAch("hellwin");
        if (wk === 15) unlockAch("shurawin");
      }
      if (state.stars === 3) {
        meta.perfectWins = (meta.perfectWins || 0) + 1;
        unlockAch("star3first");
      }
      if (state.goldEarned >= 2000) unlockAch("goldrun2k");
      if (state.maxHit >= 5000) unlockAch("maxhit5k");
      unlockAch("win");
      settleLordXp("clear");   // 主公经验：带谁出征谁涨（v5.0 主公府）
      settleActive();          // 活跃奖励：通关给寻访令牌，每日30场满额；超额激励走讨伐赏（v7.17）
      achSweep();   // 计数成就（杀敌/胜场/城池数/势力值…）统一在结算时巡检
      saveMeta();
      netLogBattle("clear");   // 战斗流水：通关那一刻的这一局数据入库
      netCheckNewVer();        // 无感热更：结算期悄悄比对版本
      SFX.win();
    }
    if (e.special === "shaman") unlockAch("seal");
  }
}

/* ---------- 武将绝技（自动释放：CD转好+条件满足） ---------- */
function ultCdMax(u) {
  let cd = ULTS[u.type.id].cd;
  if (hasRelic("mengde")) cd *= 0.72;
  if (heroLv(u.type.id) >= MILE_ULT) cd *= 0.85;   // 等级里程碑：7级大招转快15%
  cd *= Math.max(0.5, 1 - state.buffs.ultHaste);
  if (bondHas("sanfen")) cd *= 0.8;   // 羁绊·三分谋主：全军大招转快20%
  if (state.weekTheme === "yunchou") cd *= 0.75;   // 周主题·运筹帷幄：主公技转更快
  return cd;
}

function castUlt(u, r, c) {
  state.ultsUsed++;
  if (state.ultsUsed >= 15) unlockAch("ult15");
  SFX.ult();
  const p = slotCenter(r, c);
  const mods = getUnitMods(u, r, c);
  const base = unitDamage(u, mods) * (hasRelic("jiuhu") ? 1.5 : 1);
  const id = u.type.id;
  const ult = ULTS[id];
  addFloater(p.x, p.y - 60, `【${ult.name}】`, "#ffd24a", 22);
  burst(p.x, p.y - 20, "#ffd24a", 24, 220);
  shake = Math.max(shake, 0.5);

  const fan = (n, mult, pierce, spd) => {
    for (let i = 0; i < n; i++) {
      const a = -Math.PI / 2 + (i - (n - 1) / 2) * (Math.PI * 0.9 / n);
      state.bullets.push({
        x: p.x, y: p.y - 18,
        vx: Math.cos(a) * spd, vy: Math.sin(a) * spd,
        dmg: Math.round(base * mult), cls: u.type.cls, crit: mods.crit,
        pierce, splash: 0, burn: !!u.type.burn,
        r: 6 + u.level, life: 2.2, color: "#ffd24a", owner: u,
      });
    }
  };

  switch (id) {
    case "zhangfei": {  // 推开：怒喝冲击环，把一圈敌人齐齐顶回去还吓得腿软
      state.shocks.push({
        x: p.x, y: p.y - 10, r: 20, max: u.type.rng + 60,
        stun: 0, kb: 140, fear: 1.2, elem: u.type.elem, color: "#ffd24a",
        dmg: Math.round(base * 1.2), hit: new Set(),
      });
      addFloater(p.x, p.y - 80, "😱 都给我滚！", "#ffd24a", 18);
      break;
    }
    case "zhaoyun": fan(14, 1.6, 99, 420); break;  // 散射：正面扇形14枪
    case "machao": {  // 分叉射线：主雷劈最硬的，再分两叉劈旁边的
      let t1 = null, hp1 = -1;
      const rngM = (u.type.rng + 40) ** 2;
      for (const e of state.enemies) {
        if (e.dead || dist2(e.x, e.y, p.x, p.y - 18) > rngM) continue;
        if (e.hp > hp1) { hp1 = e.hp; t1 = e; }
      }
      if (t1) {
        const tx = t1.x, ty = t1.y;
        state.beams.push({ x1: p.x, y1: p.y - 18, x2: tx, y2: ty, t: 0.32, color: "#ffd24a", w: 2 });
        damageEnemy(t1, base * 7, tx, ty, "#ffd24a", "雷!", u.type.elem, u);
        burst(tx, ty, "#ffd24a", 14, 180);
        const branches = state.enemies
          .filter(e2 => e2 !== t1 && !e2.dead && dist2(e2.x, e2.y, tx, ty) < 200 ** 2)
          .sort((a, b2) => dist2(a.x, a.y, tx, ty) - dist2(b2.x, b2.y, tx, ty))
          .slice(0, 3);
        for (const e2 of branches) {
          state.beams.push({ x1: tx, y1: ty, x2: e2.x, y2: e2.y, t: 0.32, color: "#ffd24a", w: 1.4 });
          damageEnemy(e2, base * 3, e2.x, e2.y, "#ffd24a", "叉!", u.type.elem, u);
          burst(e2.x, e2.y, "#ffd24a", 8, 130);
        }
      }
      break;
    }
    case "pangde": {  // 抬棺冲杀：顺着本列突刺一趟（枪版小冲锋）
      const lane = aliveEnemies().filter(e => Math.abs(e.x - p.x) < 46);
      state.beams.push({ x1: p.x, y1: p.y - 18, x2: p.x, y2: 40, t: 0.35, color: "#e8dcc0", w: 4 });
      for (const e of lane) {
        damageEnemy(e, base * 2.4, e.x, e.y, "#e8dcc0", "扎!", u.type.elem, u);
        burst(e.x, e.y, "#e8dcc0", 5, 90);
      }
      break;
    }
    case "yanliang": {  // 斩将夺旗：直取最强特种/精锐（克巫医旗手督军的定点工具），残血直接枭首
      const ts = aliveEnemies().filter(e => (e.special || e.affix) && !e.boss).sort((a, b) => b.hp - a.hp).slice(0, 1);
      for (const e of ts) {
        state.riders.push({ x: p.x, y: p.y, char: "颜", color: "#ff8a5a", vy: -820, hit: new Set(), dmg: 0, hw: 30 });
        damageEnemy(e, base * 4.5, e.x, e.y, "#ff8a5a", "斩!", u.type.elem, u);
        if (!e.dead && !e.boss && e.hp < e.hpMax * 0.25) {
          damageEnemy(e, e.hp + 99, e.x, e.y, "#ffd24a", "枭首!", null, u);
        }
        burst(e.x, e.y, "#ff8a5a", 20, 220);
      }
      break;
    }
    case "sunshangxiang": {  // 翻身背射：扇面火箭+击退（弓里唯一的推人）
      fan(10, 1.5, 0, 520);
      for (const b of state.bullets.slice(-10)) { b.burn = true; b.color = "#ff9a5a"; }
      break;
    }
    case "yanyan": {  // 断头怒喝：吼冻一圈+自回（老将镇场）
      for (const e of aliveEnemies()) {
        if (dist2(e.x, e.y, p.x, p.y) > 210 * 210) continue;
        e.slowT = Math.max(e.slowT, ctrlDur(4));
        burst(e.x, e.y, "#8ad2ff", 4, 70);
      }
      u.hp = Math.min(u.hpMax, u.hp + u.hpMax * 0.2);
      state.ripples.push({ x: p.x, y: p.y - 8, r: 6, max: 210, color: "#8ad2ff", kind: "slow" });
      break;
    }
    case "caohong": {  // 毁家纾难：自回+短时间替兄弟挨更多刀
      u.hp = Math.min(u.hpMax, u.hp + u.hpMax * 0.35);
      u.guardT = 3;
      addFloater(p.x, p.y - 44, "回血35%·替刀翻倍3秒", "#e8c96a", 15);
      break;
    }
    case "xushu": {  // 破敌机先：全场卸劲——被克阵容的保险丝（卸劲期间×0.6不打折），配三才破敌是一套
      let n = 0;
      for (const e of aliveEnemies()) { e.armorBreakT = Math.max(e.armorBreakT || 0, hasRelic("shuijingshu") ? 9 : 5); n++; }
      addFloater(W / 2, 240, `📜 卸掉${n}个贼的劲道·5秒内打谁都不打折`, "#c9a8ff", 20);
      state.flash = 0.25;
      break;
    }
    case "huangzhong": {  // 狙击：锁场上最肉的单体，一箭大伤害
      const ts = eliteOrBoss().sort((a, b) => b.hp - a.hp).slice(0, 1);
      const ts2 = ts.length ? ts : aliveEnemies().sort((a, b) => b.hp - a.hp).slice(0, 1);
      for (const e of ts2) {
        state.beams.push({ x1: p.x, y1: p.y - 18, x2: e.x, y2: e.y, t: 0.35, color: "#ffd24a", w: 2.5 });
        damageEnemy(e, base * 16, e.x, e.y, "#ff8a5a", "狙!", u.type.elem, u);
        burst(e.x, e.y, "#ffd24a", 22, 230);
      }
      break;
    }
    case "xiahouyuan": {  // 弹射（弹墙）：巨箭斜射，撞墙折返来回扫
      const dir = p.x < W / 2 ? 1 : -1;
      state.bullets.push({
        x: p.x, y: p.y - 18, vx: dir * 430, vy: -115,
        dmg: Math.round(base * 2.5), cls: u.type.cls, elem: u.type.elem, crit: mods.crit,
        pierce: 999, splash: 0, burn: false,
        r: 9, life: 5, wallBounce: 6, color: ELEMENTS[u.type.elem].color, owner: u,
      });
      addFloater(p.x, p.y - 80, "↯ 弹墙连珠箭！", "#9adf5a", 15);
      break;
    }
    case "luxun": {  // 投掷+火堆：3个火罐砸向3个不同目标，落地各烧一片5秒
      const es = [...aliveEnemies()].sort(() => Math.random() - 0.5);
      for (let i = 0; i < 3; i++) {
        let tx, ty;
        const e = es[i] || (es.length ? pick(es) : null);   // 三罐分砸三个不同目标，不再全糊一处
        if (e) {
          tx = clamp(e.x + rand(-30, 30), 40, W - 40);
          ty = clamp(e.y + rand(-20, 20), 100, GRID_Y - 60);
        } else { tx = W * (0.25 + i * 0.25); ty = 360; }
        state.flobs.push({
          x0: p.x, y0: p.y - 18, x1: tx, y1: ty, t: 0, dur: 0.7 + i * 0.12,
          dmg: 0, splash: 0, elem: u.type.elem, src: u, icon: "🏺", color: "#ff7a3a",
          pit: { r: 85, t: 5 + (hasRelic("huoyou") ? 2 : 0), dmg: Math.max(4, Math.round(base * 0.72)) },  // 火油车：火堆多烧2秒
        });
      }
      addFloater(p.x, p.y - 80, "🔥 火罐伺候！", "#ff8a4a", 18);
      break;
    }
    case "guanyu": {  // 射线（竖）：一道刀光劈穿本列
      const laneCx = GRID_X + c * CELL + CELL / 2;
      state.beams.push({ x1: laneCx, y1: p.y - 18, x2: laneCx, y2: 20, t: 0.35, color: "#7aff9a", w: 3 });
      for (const e of state.enemies) {
        if (e.dead || Math.abs(e.x - laneCx) > 50) continue;
        damageEnemy(e, base * 3.5, e.x, e.y, "#7aff9a", "斩!", u.type.elem, u);
        burst(e.x, e.y, "#7aff9a", 8, 140);
      }
      break;
    }
    case "lvbu": {  // 弹射（弹怪）：画戟飞出去，在敌群里连环跳9次
      let nt = null, nd = Infinity;
      for (const e of state.enemies) {
        if (e.dead) continue;
        const d = dist2(e.x, e.y, p.x, p.y - 18);
        if (d < nd) { nd = d; nt = e; }
      }
      if (nt) {
        const a = Math.atan2(nt.y - (p.y - 18), nt.x - p.x);
        state.bullets.push({
          x: p.x, y: p.y - 18, vx: Math.cos(a) * 520, vy: Math.sin(a) * 520,
          dmg: Math.round(base * 6), cls: u.type.cls, elem: u.type.elem, crit: mods.crit,
          pierce: 0, bounces: 9, splash: 0, burn: false,
          r: 13, life: 3.5, color: "#ffd24a", owner: u, icon: "⚔️",
        });
      }
      break;
    }
    case "zhangliao":  // 控制（恐惧）：全场吓得掉头跑
      for (const e of state.enemies) {
        if (e.dead) continue;
        e.fearT = Math.max(e.fearT, e.boss ? 1.2 : 2.5);
      }
      addFloater(W / 2, 240, "😨 敌人吓得掉头跑！", "#8ad2ff", 20);
      break;
    case "taishici": {  // 范围AOE：人最挤的圆圈里箭如雨下
      const cl = densestCluster(130);
      if (cl) {
        for (const e of state.enemies)
          if (!e.dead && dist2(e.x, e.y, cl.x, cl.y) < 130 ** 2)
            damageEnemy(e, base * 2.8, e.x, e.y, "#ff8a5a", "雨!", u.type.elem, u);
        // 落箭视觉：一片箭从天而降
        for (let i = 0; i < 10; i++) {
          const a2 = rand(0, Math.PI * 2), rr = rand(0, 120);
          const lx = cl.x + Math.cos(a2) * rr, ly = cl.y + Math.sin(a2) * rr;
          state.lobs.push({ x0: lx + rand(-30, 30), y0: -20, x1: lx, y1: ly, t: 0, dur: rand(0.25, 0.5), icon: "🏹", color: "#ffd24a" });
        }
        for (let i = 0; i < 18; i++) burst(cl.x + rand(-120, 120), cl.y + rand(-120, 120), "#ffd24a", 4, 140);
      }
      break;
    }
    case "dianwei": {  // 溅射：锁最前面的敌人一锤爆一大片
      let tgt = null, by = -Infinity;
      const rngD = (u.type.rng + 40) ** 2;
      for (const e of state.enemies) {
        if (e.dead || dist2(e.x, e.y, p.x, p.y - 18) > rngD) continue;
        if (e.y > by) { by = e.y; tgt = e; }
      }
      if (tgt) {
        const tx = tgt.x, ty = tgt.y;
        state.slashes.push({ x1: p.x, y1: p.y - 18, x2: tx, y2: ty, life: 0.18, maxLife: 0.18, color: "#d5c9a8", w: 6 });
        damageEnemy(tgt, base * 4, tx, ty, "#ffd24a", "锤!", u.type.elem, u);
        for (const e2 of state.enemies) {
          if (e2 === tgt || e2.dead) continue;
          if (dist2(e2.x, e2.y, tx, ty) < (120 + e2.r) ** 2)
            damageEnemy(e2, base * 2, e2.x, e2.y, "#ffd24a", "", u.type.elem, u);
        }
        burst(tx, ty, "#ffd24a", 26, 230);
        burst(tx, ty, "#d5c9a8", 14, 150);
        shake = Math.max(shake, 0.6);
      }
      break;
    }
    case "sunce": {  // 推开：巨马冲垮本列，撞谁谁倒飞
      const laneCx = GRID_X + c * CELL + CELL / 2;
      state.riders.push({
        x: laneCx, y: p.y - 20, vy: -340,
        w: 60 + state.buffs.cavWide,
        dmg: Math.round(base * 2.5), elem: u.type.elem,
        crit: mods.crit, burn: false,
        hit: new Set(), owner: u,
        char: u.type.char, color: ELEMENTS[u.type.elem].color,
        trail: 0, kbMul: 2, mega: true,
      });
      addFloater(laneCx, p.y - 80, "🐎 霸王冲阵！", "#8ad2ff", 18);
      break;
    }
    case "xuchu":  // 拒马：横一排路障，4秒谁也过不来（蒺藜骨朵：6秒）
      const juK = bondHas("juma") ? 2 : 1;   // 羁绊·拒马双璧
      state.blockade = { t: (hasRelic("jili") ? 6 : 4) * juK, y: GRID_Y - 30, hp: Math.round((hasRelic("jili") ? 18 : 14) * juK), hpMax: Math.round((hasRelic("jili") ? 18 : 14) * juK) };
      addFloater(W / 2, GRID_Y - 70, "🚧 拒马放好，过不来！", "#9adf5a", 18);
      break;
    case "weiyan": {  // 陷阱：埋在敌人前路，踩中爆毒（机关图谱：多埋2个）
      const es = aliveEnemies();
      const nTrap = 3 + (hasRelic("jiguan") ? 2 : 0);
      for (let i = 0; i < nTrap; i++) {
        let tx, ty;
        if (es.length) {
          const e = pick(es);
          tx = clamp(e.x + rand(-50, 50), 30, W - 30);
          ty = clamp(e.y + rand(50, 110), 120, GRID_Y - 60);
        } else { tx = rand(60, W - 60); ty = rand(200, 380); }
        state.traps.push({ x: tx, y: ty, r: 26, dmg: Math.round(base * 3), splash: 80, elem: u.type.elem, src: u, t: 10 });
      }
      while (state.traps.length > (hasRelic("jiguan") ? 15 : 9)) state.traps.shift();
      addFloater(p.x, p.y - 80, `☠️ 埋下${nTrap}个陷阱！`, "#9adf5a", 16);
      break;
    }
    case "ganning": {  // 随机+投掷：5颗炸弹乱丢，落点随缘
      const es = aliveEnemies();
      for (let i = 0; i < 5; i++) {
        let tx, ty;
        if (es.length) {
          const e = pick(es);
          tx = clamp(e.x + rand(-46, 46), 30, W - 30);
          ty = clamp(e.y + rand(-36, 36), 80, GRID_Y - 50);
        } else { tx = rand(60, W - 60); ty = rand(120, 400); }
        state.flobs.push({
          x0: p.x, y0: p.y - 18, x1: tx, y1: ty, t: 0, dur: 0.55 + i * 0.1,
          dmg: Math.round(base * 2.2), splash: 70, elem: u.type.elem, src: u,
          icon: "🧨", color: "#ffd24a",
        });
      }
      addFloater(p.x, p.y - 80, "⛵ 炸弹乱丢！", "#ffd24a", 18);
      break;
    }
    case "diaochan": {  // 沉默：封住特种怪/贼首的邪招5秒（沉沙折戟：+2秒）；普通兵被迷心4秒多挨打30%
      let n = 0, m = 0;
      const silT = 5 + (hasRelic("chensha") ? 2 : 0);
      for (const e of state.enemies) {
        if (e.dead || !(e.special || e.boss)) continue;
        e.silencedT = silT;
        state.beams.push({ x1: p.x, y1: p.y - 18, x2: e.x, y2: e.y, t: 0.35, color: "#ff9ad2", w: 1.5 });
        burst(e.x, e.y, "#ff9ad2", 8, 100);
        n++;
      }
      // 迷心：最靠前的5个普通兵神魂颠倒，多挨打30%（没特种也不空放）
      const mobs = aliveEnemies().filter(e => !e.special && !e.boss)
        .sort((a, b2) => b2.y - a.y).slice(0, 5);
      for (const e of mobs) {
        e.charmT = Math.max(e.charmT || 0, 4);
        state.beams.push({ x1: p.x, y1: p.y - 18, x2: e.x, y2: e.y, t: 0.3, color: "#ff9ad2", w: 1.2 });
        burst(e.x, e.y, "#ff9ad2", 5, 80);
        m++;
      }
      const parts = [];
      if (n) parts.push(`封${n}个贼技`);
      if (m) parts.push(`迷${m}个多挨30%打`);
      addFloater(W / 2, 240, `💃 ${parts.join("，") || "闭月迷心！"}`, "#ff9ad2", 19);
      break;
    }
    case "zhouyu": {  // 射线（横）：挑人最多的一行，拦腰一道火线
      const es = aliveEnemies();
      let bestY = null, bestN = 0;
      for (const e of es) {
        let n = 0;
        for (const e2 of es) if (Math.abs(e2.y - e.y) < 45) n++;
        if (n > bestN) { bestN = n; bestY = e.y; }
      }
      if (bestY != null) {
        state.beams.push({ x1: 0, y1: bestY, x2: W, y2: bestY, t: 0.4, color: "#ff7a3a", w: 3 });
        for (const e of es) {
          if (e.dead || Math.abs(e.y - bestY) > 45) continue;
          damageEnemy(e, base * 2.9, e.x, e.y, "#ff8a5a", "焚!", u.type.elem, u);
          if (!e.dead && !wxRain()) {
            e.burnT = Math.max(e.burnT, 4);
            let bd = Math.max(2, Math.round(base * 0.5));
            if (wxEast()) bd *= 2;
            e.burnDmg = Math.max(e.burnDmg, bd);
            e.burnSrc = u;
          }
        }
        for (let i = 0; i < 16; i++) burst(rand(20, W - 20), bestY + rand(-20, 20), "#ff7a3a", 4, 130);
      }
      break;
    }
    case "jiangwei": {  // 追踪弹：8支火箭拐着弯咬人，还点火
      const es = aliveEnemies();
      if (es.length) {
        for (let i = 0; i < 8; i++) {
          state.homers.push({
            x: p.x + rand(-14, 14), y: p.y - 18,
            vx: rand(-180, 180), vy: -240,
            target: es[i % es.length], spd: 340,
            dmg: Math.round(base * 2), elem: u.type.elem, src: u, life: 4, color: "#ff7a3a",
          });
        }
        addFloater(p.x, p.y - 80, "🔥 火矢追人！", "#ff8a4a", 17);
      }
      break;
    }
    case "zhugeliang": {  // 死亡链接：锁最硬的5只，打一个全掉血（玄铁锁链：锁7只更狠）
      const ms = [...aliveEnemies()].sort((a, b2) => b2.hp - a.hp).slice(0, hasRelic("xuantie") ? 7 : 5);
      if (ms.length >= 2) {
        state.deathLink = { members: ms, t: 7, src: u };
        for (const m of ms) burst(m.x, m.y, "#c9a8ff", 10, 120);
        addFloater(W / 2, 240, `⛓️ 锁住${ms.length}只！打一个全掉血`, "#c9a8ff", 20);
      }
      break;
    }
    case "caoren":  // 范围AOE+晕：冲击环扩散，扫到就晕1秒
      state.shocks.push({
        x: p.x, y: p.y - 10, r: 20, max: 280, stun: 1, kb: 0, elem: u.type.elem, color: "#e8c96a",
        dmg: Math.round((16 + state.wave * 4) * (1 + u.level * 0.3) * (hasRelic("jiuhu") ? 1.5 : 1)),
        hit: new Set(),
      });
      addFloater(p.x, p.y - 80, "🛡️ 大地震荡！", "#e8c96a", 18);
      break;
    case "zhoutai": {  // 守御+径向散射：自奶45%反伤翻倍，八方喷冰刺
      u.hp = Math.min(u.hpMax, u.hp + u.hpMax * 0.45);
      u.reflectT = 3;
      const sd = Math.round((10 + state.wave * 3) * (1 + u.level * 0.3) * (hasRelic("jiuhu") ? 1.5 : 1));
      for (let i = 0; i < 8; i++) {
        const a2 = i * (Math.PI * 2 / 8);
        state.bullets.push({
          x: p.x, y: p.y - 10, vx: Math.cos(a2) * 380, vy: Math.sin(a2) * 380,
          dmg: sd, cls: u.type.cls, elem: u.type.elem, crit: 0,
          pierce: 0, splash: 0, burn: false,
          r: 6, life: 0.55, color: "#6ad2ff", owner: u,
        });
      }
      burst(p.x, p.y, "#8ad2ff", 16, 150);
      SFX.buff();
      addFloater(p.x, p.y - 44, "回血45%·反伤翻倍3秒", "#8ad2ff", 15);
      break;
    }
    case "huatuo": {  // 治疗连线：绿线一人一根，全军奶35%解封，再挂6秒药香持续回血
      for (let r2 = 0; r2 < GRID_ROWS; r2++)
        for (let c2 = 0; c2 < GRID_COLS; c2++) {
          const u2 = state.slots[r2][c2];
          if (!u2) continue;
          u2.hp = Math.min(u2.hpMax, u2.hp + u2.hpMax * 0.35);
          (u2.rbuffs ||= {}).heal = Math.max(u2.rbuffs.heal || 0, 6);   // 药香：6秒每秒再回2%
          if (u2.sealedT > 0) u2.sealedT = 0;
          u2.bounce = Math.max(u2.bounce, 0.5);
          const pp = slotCenter(r2, c2);
          state.beams.push({ x1: p.x, y1: p.y - 18, x2: pp.x, y2: pp.y, t: 0.4, color: "#8aff9a", w: 1.5 });
          burst(pp.x, pp.y, "#8aff9a", 8, 100);
        }
      SFX.buff();
      addFloater(W / 2, 240, "🧪 全军奶35%，还持续回血", "#8aff9a", 20);
      break;
    }
    case "xiaoqiao":  // 大风圈：全军提速+40%（5秒）
      state.armyHaste = { t: 5, mul: 1.4 };
      state.ripples.push({ x: p.x, y: p.y - 8, r: 6, max: 300, color: "#ff9ad2", kind: "haste" });
      SFX.buff();
      addFloater(W / 2, 240, "🌬️ 全军提速40%·5秒", "#ff9ad2", 20);
      break;
    case "lusu": {  // 空投：粮包从天上砸到武将头上，白拿经验+全军加攻
      const gain = Math.round(aliveEnemies().length * 1.2);
      gainXP(gain);
      state.armyBuff = { t: 6, mul: 1.3 };
      // 粮包保底：随机挑最多4个在场武将，包包砸头上，落地飘"+N经验"
      const occ2 = [];
      for (let r2 = 0; r2 < GRID_ROWS; r2++)
        for (let c2 = 0; c2 < GRID_COLS; c2++)
          if (state.slots[r2][c2]) occ2.push([r2, c2]);
      occ2.sort(() => Math.random() - 0.5);
      const nPack = Math.min(4, Math.max(1, occ2.length));
      const per = Math.max(1, Math.round(gain / nPack));
      for (let i = 0; i < nPack && i < occ2.length; i++) {
        const pp = slotCenter(occ2[i][0], occ2[i][1]);
        state.lobs.push({ x0: W / 2, y0: -20, x1: pp.x, y1: pp.y - 10, t: 0, dur: rand(0.55, 0.95),
          icon: "🌾", color: "#e8c86a", label: `+${per}经验` });
      }
      SFX.buff();
      addFloater(W / 2, 240, "🌾 全军加攻30%·6秒", "#c9a8ff", 20);
      break;
    }
    case "huanggai": {  // 自残换爆发：苦肉计——扣自己血，全场点火+立攒经验（独门机制）
      const cut = Math.round(u.hp * 0.4);
      u.hp = Math.max(1, u.hp - cut);   // 扣不死：最多剩1血
      u.hurtFlash = 1;
      const bd = Math.max(2, Math.round((1 + state.wave * 0.5) * (1 + u.level * 0.2)
        * (hasRelic("jiuhu") ? 1.5 : 1) * (wxEast() ? 2 : 1)));
      let nBurn = 0;
      for (const e of state.enemies) {
        if (e.dead) continue;
        nBurn++;
        if (!wxRain()) {
          e.burnT = Math.max(e.burnT, 4);
          e.burnDmg = Math.max(e.burnDmg, bd);
          e.burnSrc = u;
        }
        if (Math.random() < 0.6) burst(e.x, e.y, "#ff7a3a", 5, 140);
      }
      gainXP(Math.max(4, Math.round(nBurn * 0.8)));
      state.ripples.push({ x: p.x, y: p.y - 8, r: 6, max: 560, color: "#ff7a3a", kind: "fire" });
      addFloater(p.x, p.y - 44, `自己扣${cut}血`, "#ff8a5a", 14);
      addFloater(W / 2, 240, wxRain()
        ? "🔥 苦肉诈降！可惜大雨点不着…"
        : "🔥 苦肉诈降！全场点火，经验白拿", "#ff8a4a", 20);
      shake = Math.max(shake, 0.6);
      break;
    }
    case "xuhuang": {  // 拒马（钉阵版）：两排短拒马错开落位，正面挡死、绕路也要多走（蒺藜骨朵：更耐久）
      const es = aliveEnemies().sort((a, b2) => b2.y - a.y);
      const x1 = clamp(es.length ? es[0].x : W / 2, 100, W - 100);
      const cl = densestCluster(120);
      let x2 = clamp(cl ? cl.x : W - x1, 100, W - 100);
      // 两排贴太近=留一大边活路：强制错开去另半场
      if (Math.abs(x2 - x1) < 140) x2 = clamp(x1 < W / 2 ? x1 + 190 : x1 - 190, 100, W - 100);
      const juK2 = bondHas("juma") ? 2 : 1;   // 羁绊·拒马双璧
      const paT = (hasRelic("jili") ? 6.5 : 5.5) * juK2;
      const paHp = Math.round((hasRelic("jili") ? 16 : 12) * juK2);   // 耐久：被挡敌人每秒挤掉1点（贼首2.5）——人多必被冲破，防无敌墙
      state.palisades.push(
        { x: x1, hw: 108, y: GRID_Y - 36, t: paT, hp: paHp, hpMax: paHp },
        { x: x2, hw: 108, y: GRID_Y - 108, t: paT, hp: paHp, hpMax: paHp },
      );
      addFloater(W / 2, GRID_Y - 70, "🚧 钉阵拒马！两排钉死", "#e8c96a", 17);
      break;
    }
    case "daqiao": {  // 全场冰环：一环两用——敌人冻慢+全军回血（独门机制）
      state.shocks.push({
        x: p.x, y: p.y - 10, r: 20, max: 640, dmg: 0, stun: 0, kb: 0, slow: 4,
        elem: u.type.elem, color: "#6ad2ff", hit: new Set(),
      });
      for (let r2 = 0; r2 < GRID_ROWS; r2++)
        for (let c2 = 0; c2 < GRID_COLS; c2++) {
          const u2 = state.slots[r2][c2];
          if (!u2) continue;
          u2.hp = Math.min(u2.hpMax, u2.hp + u2.hpMax * 0.12);
          u2.bounce = Math.max(u2.bounce, 0.5);
          const pp = slotCenter(r2, c2);
          burst(pp.x, pp.y, "#8ad2ff", 6, 90);
        }
      SFX.buff();
      addFloater(W / 2, 240, "❄️ 全场冻慢4秒·全军回血", "#8ad2ff", 20);
      break;
    }
    case "huangyueying": {  // 炮台：架一座临时连弩塔，8秒自动扫射最近敌人（独门机制）
      // 落点：挑离敌群最近的石头架炮——炮要架在敌人头上才有用；没石头就架在敌群前
      const cl = densestCluster(140);
      let tx, ty;
      const obs = [...state.obstacles];
      if (obs.length) {
        let bestK = obs[0], bestD = Infinity;
        for (const k of obs) {
          const [orr, occ] = k.split(",").map(Number);
          const op = slotCenter(orr, occ);
          const d = cl ? dist2(op.x, op.y, cl.x, cl.y) : op.y;
          if (d < bestD) { bestD = d; bestK = k; }
        }
        const [orr, occ] = bestK.split(",").map(Number);
        const op = slotCenter(orr, occ);
        tx = op.x; ty = op.y - 8;
      } else {
        tx = clamp(cl ? cl.x : W / 2 + rand(-70, 70), 60, W - 60);
        ty = GRID_Y - 90;
      }
      const twLife = 10 + (hasRelic("jiguan") ? 3 : 0);   // 机关图谱：炮台多撑3秒
      state.turrets.push({
        x: tx, y: ty, t: twLife, tMax: twLife, cd: 0.2, rng: 420, rate: 0.32,
        // 炮弹随战局成长：波数越深越疼，还吃全军猛攻/五行淬炼
        dmg: Math.max(4, Math.round((5 + state.wave * 1.6) * (1 + (u.level - 1) * 0.35)
          * (1 + (state.buffs.elemBoost[u.type.elem] || 0)) * state.buffs.dmg * (hasRelic("jiuhu") ? 1.5 : 1))),
        elem: u.type.elem,
      });
      state.lobs.push({ x0: p.x, y0: p.y - 18, x1: tx, y1: ty, t: 0, dur: 0.5, icon: "⚙️", color: "#ffd24a" });
      addFloater(tx, ty - 30, "⚙️ 连弩机关，架好了！", "#ffd24a", 15);
      break;
    }
    case "caiwenji": {  // 催眠：一曲唱睡全场（贼首减半，挨打即醒）——给AOE队友喂"睡着的靶子"
      let n = 0;
      for (const e of state.enemies) {
        if (e.dead) continue;
        e.sleepT = Math.max(e.sleepT || 0, ctrlDur(e.boss ? 1.5 : 3));
        n++;
      }
      state.ripples.push({ x: p.x, y: p.y - 8, r: 6, max: 620, color: "#bfe8ff", kind: "soothe" });
      SFX.buff();
      addFloater(W / 2, 240, `🎵 唱睡${n}个（挨打会醒）`, "#bfe8ff", 19);
      break;
    }
    case "gaoshun": {  // 聚怪：左右两列的敌人拽到本列聚成一堆，再一记重击——把散怪喂给全场AOE
      const laneCx = GRID_X + c * CELL + CELL / 2;
      const my = p.y - 18;
      const targets = aliveEnemies().filter(e =>
        Math.abs(e.x - laneCx) < CELL * 1.5 + 30 && dist2(e.x, e.y, laneCx, my) < 400 ** 2);
      if (targets.length) {
        // 聚点：拽向被拉敌人的"重心"，落在本列中轴上
        let gy = 0;
        for (const e of targets) gy += e.y;
        gy = clamp(gy / targets.length, 80, GRID_Y - 60);
        for (const e of targets) {
          const cap = e.boss ? 30 : 90;   // 单个最多拽90px，贼首只挪30px
          const dx = laneCx - e.x, dy = gy - e.y;
          const d = Math.hypot(dx, dy) || 1;
          const step = Math.min(cap, d);
          e.x = clamp(e.x + dx / d * step, e.r, W - e.r);
          e.y = e.y + dy / d * step;
          state.beams.push({ x1: p.x, y1: my, x2: e.x, y2: e.y, t: 0.25, color: "#d5c9a8", w: 1.3 });
        }
        // 聚点重击：半径90内 250%
        for (const e of aliveEnemies())
          if (dist2(e.x, e.y, laneCx, gy) < (90 + e.r) ** 2)
            damageEnemy(e, base * 2.5, e.x, e.y, "#ffd24a", "陷!", u.type.elem, u);
        burst(laneCx, gy, "#ffd24a", 22, 200);
        shake = Math.max(shake, 0.5);
        addFloater(laneCx, gy - 40, `⚔️ 拽来${targets.length}个，一锅端！`, "#ffd24a", 16);
      }
      break;
    }
    case "zhanghe": {  // 多列冲锋：挑人最多的三列各来一记60%小冲锋——平A只冲一列，大招铺开三列
      const counts = [];
      for (let cc = 0; cc < GRID_COLS; cc++) {
        const cx = GRID_X + cc * CELL + CELL / 2;
        let n = 0;
        for (const e of aliveEnemies()) if (Math.abs(e.x - cx) < 60) n++;
        counts.push({ cc, n, cx });
      }
      counts.sort((a, b2) => b2.n - a.n);
      const lanes = counts.filter(l => l.n > 0).slice(0, 3);
      for (const l of lanes) {
        state.riders.push({
          x: l.cx, y: p.y - 20, vy: -340,
          w: 34 + state.buffs.cavWide,
          dmg: Math.round(base * 0.6), elem: u.type.elem,
          crit: mods.crit, burn: false,
          hit: new Set(), owner: u,
          char: u.type.char, color: ELEMENTS[u.type.elem].color,
          trail: 0,
        });
      }
      addFloater(p.x, p.y - 80, `⚡ 雷骑掠阵！${lanes.length}列齐冲`, "#ffd24a", 17);
      break;
    }
    case "zhurong": {  // 散射+点燃：扇形5把飞刀全点着——给陆逊烙印/火系淬炼递火种
      for (let i = 0; i < 5; i++) {
        const a = -Math.PI / 2 + (i - 2) * (Math.PI * 0.7 / 5);
        state.bullets.push({
          x: p.x, y: p.y - 18,
          vx: Math.cos(a) * 420, vy: Math.sin(a) * 420,
          dmg: Math.round(base * 2.2), cls: u.type.cls, elem: u.type.elem, crit: mods.crit,
          pierce: 2, splash: 0, burn: true,
          r: 7 + u.level, life: 2.2, color: "#ff7a3a", owner: u, icon: "🔥",
        });
      }
      addFloater(p.x, p.y - 80, "🔥 火神降世！飞刀全点着", "#ff8a4a", 17);
      break;
    }
    case "wutugu": {  // 光环爆发：毒雾8秒变大变毒（半径×2.2 伤害×2）——站桩盾里唯一的输出型
      u.ultT = 8;
      u.auraTick = 0;   // 立刻毒一口
      state.ripples.push({ x: p.x, y: p.y - 8, r: 6, max: 90 * 2.2, color: "#9adf5a", kind: "fire" });
      SFX.buff();
      addFloater(p.x, p.y - 44, "☠️ 毒雾变大变毒·8秒", "#9adf5a", 15);
      break;
    }
    case "simayi": {  // CD回收：全军大招立减10秒+白送经验——武将越多越赚，全队大招轴心
      for (let r2 = 0; r2 < GRID_ROWS; r2++)
        for (let c2 = 0; c2 < GRID_COLS; c2++) {
          const u2 = state.slots[r2][c2];
          if (!u2 || u2 === u) continue;
          u2.ultCd = Math.max(0, u2.ultCd - 10);
          const pp = slotCenter(r2, c2);
          state.beams.push({ x1: p.x, y1: p.y - 18, x2: pp.x, y2: pp.y, t: 0.35, color: "#c9a8ff", w: 1.5 });
          burst(pp.x, pp.y, "#c9a8ff", 6, 90);
        }
      gainXP(20);
      SFX.buff();
      addFloater(W / 2, 240, "🕐 天命在我！全军大招快转10秒", "#c9a8ff", 19);
      break;
    }
    /* —— v7.6.0 五将大招 —— */
    case "jiaxu": {   // 乱武：血最厚的4个普通贼倒戈互殴（复活休眠的离间行为链）
      const cands = aliveEnemies().filter(e => !e.special && !e.boss && !e.affix && !e.big)
        .sort((a, b) => b.hpMax - a.hpMax).slice(0, 4);
      for (const e of cands) {
        e.turncoatT = 3;
        e.tcSrc = u;   // 记账：倒戈互殴算贾诩的输出
        addFloater(e.x, e.y - e.r - 12, "💔 倒戈！", "#ff7ab8", 15);
        burst(e.x, e.y, "#ff7ab8", 10, 110);
      }
      SFX.ult();
      addFloater(W / 2, 240, `🕶️ 乱武！${cands.length}个贼自相残杀`, "#c9a8ff", 20);
      break;
    }
    case "zuoci": {   // 群羊变：最肥3个普通贼变羊——定身5秒+多挨三成打（face只渲染，中途改无副作用）
      const sheep = aliveEnemies().filter(e => !e.special && !e.boss)
        .sort((a, b) => b.hpMax - a.hpMax).slice(0, 3);
      for (const e of sheep) {
        e.stunT = Math.max(e.stunT || 0, 5);
        e.jianjunT = Math.max(e.jianjunT || 0, 5);
        e.jianjunAmp = Math.max(e.jianjunAmp || 0, 0.3);
        e.face = "羊";
        addFloater(e.x, e.y - e.r - 12, "🐑 咩！", "#e8f4ff", 15);
        burst(e.x, e.y, "#e8f4ff", 12, 130);
      }
      SFX.buff();
      addFloater(W / 2, 240, `🐑 群羊变！${sheep.length}个贼变羊5秒`, "#8ad2ff", 20);
      break;
    }
    case "dengai": {   // 凿山：脚踏石头借势重锤同排贼（×5），石头不碎、邓艾接着占着高地；平地×3（v7.8.0：大招不再砸石头，别再毁自己的居高临下）
      const rowY = slotCenter(r, c).y;
      const onRock = isObstacle(r, c);
      if (onRock) {
        addFloater(p.x, p.y - 26, `⛏️ 踏石借力！`, "#ffe45a", 14);
        burst(p.x, p.y, "#c9b69a", 20, 190);
      }
      const dmgZ = unitDamage(u, getUnitMods(u, r, c)) * (onRock ? 5 : 3);
      let hitZ = 0;
      for (const e of aliveEnemies()) {
        if (Math.abs(e.y - rowY) > 70) continue;
        damageEnemy(e, dmgZ, e.x, e.y, "#c9b69a", "", u.type.elem, u);
        e.stunT = Math.max(e.stunT || 0, 0.6);
        hitZ++;
      }
      state.slashes.push({ x1: 10, y1: rowY, x2: W - 10, y2: rowY, life: 0.22, maxLife: 0.22, color: "#c9b69a", w: 8 });
      shake = Math.max(shake, 0.5);
      SFX.ult();
      addFloater(W / 2, 240, `⛏️ 凿山！同排${hitZ}个贼挨了重锤${onRock ? "（踏石加倍）" : ""}`, "#ffe45a", 20);
      break;
    }
    case "menghuo": {   // 南蛮战吼：吼跑全场普通贼+自己回三成血
      let fearN = 0;
      for (const e of aliveEnemies()) {
        if (e.special || e.boss) continue;
        e.fearT = Math.max(e.fearT || 0, 1.5);
        fearN++;
      }
      u.hp = Math.min(u.hpMax, u.hp + Math.round(u.hpMax * 0.3));
      state.ripples.push({ x: p.x, y: p.y, r: 6, max: 400, color: "#ff8a5a", kind: "wind" });
      SFX.ult();
      addFloater(W / 2, 240, `🐘 南蛮战吼！吓跑${fearN}个贼，自己回了血`, "#ff8a5a", 20);
      break;
    }
    case "wenchou": {   // 阵前枭首：对单挑目标一刀八倍处决
      let tgtW = null;
      for (const e of aliveEnemies()) if (e.duelT > 0 && (!tgtW || e.hpMax > tgtW.hpMax)) tgtW = e;
      if (tgtW) {
        const dmgW = unitDamage(u, getUnitMods(u, r, c)) * 8;
        state.slashes.push({ x1: p.x, y1: p.y - 18, x2: tgtW.x, y2: tgtW.y, life: 0.2, maxLife: 0.2, color: "#ff8a5a", w: 7 });
        damageEnemy(tgtW, dmgW, tgtW.x, tgtW.y, "#ff8a5a", "斩!", u.type.elem, u);
        shake = Math.max(shake, 0.4);
        SFX.ult();
        addFloater(W / 2, 240, "⚔️ 阵前枭首！", "#ff8a5a", 20);
      }
      break;
    }
  }
  return true;
}

/* ---------- 辅兵水波：扩散环 + 立即施加范围效果 ---------- */
/* 大乔的冰波打敌人，圈更大才够得着 */
function rippleMax(type) {
  return (type.ripple === "slow" ? 230 : 130) + state.buffs.rippleRad + bondFx(type.id).rippleRad;
}
function castRipple(u, r, c) {
  const p = slotCenter(r, c);
  const kind = u.type.ripple || "heal";
  const max = rippleMax(u.type);
  const color = kind === "heal" ? "#8aff9a" : kind === "haste" ? "#8ad2ff"
    : kind === "slow" ? "#6ad2ff" : kind === "crit" ? "#ffd24a"
    : kind === "soothe" ? "#bfe8ff" : kind === "cdr" ? "#c9a8ff" : kind === "sunder" ? "#c9a8ff" : "#ff9a5a";
  const icon = kind === "heal" ? "💗" : kind === "haste" ? "⚡"
    : kind === "slow" ? "❄️" : kind === "crit" ? "🎯"
    : kind === "soothe" ? "🎵" : kind === "cdr" ? "🕐" : kind === "sunder" ? "📜" : "⚔️";
  state.ripples.push({ x: p.x, y: p.y - 8, r: 6, max, color, kind });
  addFloater(p.x, p.y - 46, icon, color, 15);
  // 徐庶卸抗波：圈里敌人的抗性掉一截4秒——撞抗不再是死局
  if (kind === "sunder") {
    for (const e of state.enemies) {
      if (e.dead || e.y < -10) continue;
      if (dist2(e.x, e.y, p.x, p.y - 8) > max * max) continue;
      e.armorBreakT = Math.max(e.armorBreakT || 0, hasRelic("shuijingshu") ? 7 : 4);
    }
    return;
  }
  // 大乔冰波：辅兵首个攻击型水波——圈里敌人全冻慢
  if (kind === "slow") {
    for (const e of state.enemies) {
      if (e.dead || e.y < -10) continue;
      if (dist2(e.x, e.y, p.x, p.y - 8) > max * max) continue;
      e.slowT = Math.max(e.slowT, ctrlDur(2.5));
    }
    return;
  }
  for (let rr = 0; rr < GRID_ROWS; rr++)
    for (let cc = 0; cc < GRID_COLS; cc++) {
      const u2 = state.slots[rr][cc];
      if (!u2) continue;
      const pp = slotCenter(rr, cc);
      if (dist2(pp.x, pp.y, p.x, p.y) > max * max) continue;
      if (kind === "heal") {
        if (u2.hp < u2.hpMax) {
          u2.hp = Math.min(u2.hpMax, u2.hp + u2.hpMax * 0.12);
          (u2.rbuffs ||= {}).heal = Math.max(u2.rbuffs.heal || 0, 4.5);   // 药香：4.5秒每秒再回2%
          burst(pp.x, pp.y - 10, color, 5, 70);
        }
      } else if (kind === "soothe") {
        // 蔡文姬安抚波：解开妖术封印 + 小奶8%——妖术师的天然克星
        if (u2.sealedT > 0) {
          u2.sealedT = 0;
          addFloater(pp.x, pp.y - 40, "🎵 封印解了！", "#bfe8ff", 13);
          burst(pp.x, pp.y - 10, color, 8, 100);
        }
        if (u2.hp < u2.hpMax) {
          u2.hp = Math.min(u2.hpMax, u2.hp + u2.hpMax * 0.08);
          burst(pp.x, pp.y - 10, color, 4, 60);
        }
      } else {
        // 后勤协同（v5.4.4 随物件归主公配套扩展）：鲁肃的加攻波喂物件——
        // 粮仓吃了产粮+50%（曹操局）、龙蛋吃了这口温养把握+1成5（刘表局）；别的波它们不吃
        if (u2.type.cls === "granary" || u2.type.cls === "egg") {
          if (kind === "dmg") {
            (u2.rbuffs ||= {}).farm = Math.max(u2.rbuffs.farm || 0, 5.5);
            addFloater(pp.x, pp.y - 36, u2.type.cls === "granary" ? "🌾吃饱了，喂星快+50%" : "🥚吃饱了，温养+1成5", "#ffb84a", 12);
          }
          continue;
        }
        // 攻击类水波别糊给不打人的：加攻/暴击只给输出位；提速辅兵能吃（水波放更勤）盾兵不吃；大招转快人人有份
        if (!unitAttacks(u2.type)) {
          if (kind === "dmg" || kind === "crit") continue;
          if (kind === "haste" && u2.type.cls === "shield") continue;
        }
        // buff 5.5秒 ≈ 放波间隔：邻居基本"常亮"（辅兵偏弱补强 2026-07-04）
        (u2.rbuffs ||= {})[kind] = Math.max(u2.rbuffs[kind] || 0, 5.5);
      }
    }
}

/* ---------- 投石：向随机有人格抛掷（投石兵/贼首共用） ---------- */
/* 铁壁嘲讽（v5.10 用户拍板"盾兵更肉+吸引火力"）：贼的远程点名七成概率改冲最近的盾兵——
   覆盖=弓贼的箭/投石落点/贼首投掷/火罐/乱箭；刺客除外（专捅软柿子是他的本职，盾护和奶是他的反制）。
   嘲讽引来的伤害攒蓄势怒气=盾兵越拉越能打，闭环 */
/* v7.6.0 攻击出口的两个可测帮手：左慈恒克制转系 / 文丑单挑增伤 */
function atkElemOf(owner, e, elem, ley) { return (ley || owner?.type?.id === "zuoci") && e.tri ? triCounterOf(e.tri) : elem; }   // 左慈幻变 / 灵脉自带破敌：打谁都按克制算
function duelMulOf(owner, e) { return e.duelT > 0 && owner?.type?.id === "wenchou" ? 1.5 : 1; }
function tauntUnit(ex, ey) {
  if (Math.random() >= 0.7) return null;
  let best = null, bd = Infinity;
  for (let r = 0; r < GRID_ROWS; r++)
    for (let c = 0; c < GRID_COLS; c++) {
      const u = state.slots[r][c];
      if (!u || u.type.cls !== "shield") continue;
      const p = slotCenter(r, c);
      const d = dist2(ex, ey, p.x, p.y);
      if (d < bd) { bd = d; best = { u, r, c, p }; }
    }
  return best;
}
function throwLob(e, mul = 1) {
  const occ = [];
  for (let r = 0; r < GRID_ROWS; r++)
    for (let c = 0; c < GRID_COLS; c++)
      if (state.slots[r][c]) occ.push([r, c]);
  if (!occ.length) return;
  const tt = tauntUnit(e.x, e.y);   // 铁壁嘲讽：落点七成冲盾兵
  const [r, c] = tt ? [tt.r, tt.c] : pick(occ);
  const p = slotCenter(r, c);
  const hitDmg = Math.round((e.boss ? 30 : 16) * (1 + state.wave * 0.06) * foeDmgK());
  state.elobs.push({
    x0: e.x, y0: e.y, x1: p.x + rand(-14, 14), y1: p.y + rand(-8, 8),
    t: 0, dur: 1.1, dmg: Math.max(1, Math.round(hitDmg * mul)),
  });
}

/* ---------- 战斗更新 ---------- */
function update(dt) {
  state.time += dt;
  computeTeam();
  // 开局地形横幅：开打后倒计时淡出
  if (state.fieldBanner > 0) state.fieldBanner = Math.max(0, state.fieldBanner - dt);

  /* 七星灯：城墙缓回 */
  if (hasRelic("qixing") && state.baseHP < state.baseHPMax) {
    state.wallRegenT -= dt;
    if (state.wallRegenT <= 0) {
      state.wallRegenT = 30;
      state.baseHP++;
      addFloater(80, DEFENSE_LINE - 10, "🕯️+1", "#9adf5a", 14);
    }
  }

  /* 火山口地形：定时喷发——敌堆中央烧一片还点燃 */
  if (state.field?.volcano) {
    state.volcanoT -= dt;
    if (state.volcanoT <= 0 && state.enemies.some(e => !e.dead)) {
      state.volcanoT = state.field.volcano;
      const cl = densestCluster(110);
      const vx = cl ? cl.x : rand(60, W - 60), vy = cl ? cl.y : rand(150, 400);
      const dmg = Math.round(10 + state.wave * 2.5);
      for (const e of state.enemies) {
        if (e.dead) continue;
        if (dist2(e.x, e.y, vx, vy) < (110 + e.r) ** 2) {
          damageEnemy(e, dmg, e.x, e.y, "#ff8a4a", "喷!", null, "@field");
          if (!e.dead && !wxRain()) {
            e.burnT = Math.max(e.burnT, 3);
            e.burnDmg = Math.max(e.burnDmg, Math.max(2, Math.round(dmg * 0.2)));
            e.burnSrc = "@field";
          }
        }
      }
      burst(vx, vy, "#ff5a2a", 30, 260);
      burst(vx, vy, "#ffd24a", 18, 180);
      shake = Math.max(shake, 0.5);
      SFX.wallHit();
      addFloater(vx, vy - 30, "🌋 火山喷发！", "#ff8a4a", 18);
    }
  }

  /* 滚石坡地形：定时滚巨石碾穿人最多的一列（复用骑手实体，向下滚） */
  if (state.field?.boulder) {
    state.boulderT -= dt;
    if (state.boulderT <= 0 && state.enemies.some(e => !e.dead)) {
      state.boulderT = state.field.boulder;
      let bestC = 0, bestN = -1;
      for (let cc = 0; cc < GRID_COLS; cc++) {
        const cx = GRID_X + cc * CELL + CELL / 2;
        let n = 0;
        for (const e of state.enemies) if (!e.dead && Math.abs(e.x - cx) < 60) n++;
        if (n > bestN) { bestN = n; bestC = cc; }
      }
      const cx = GRID_X + bestC * CELL + CELL / 2;
      state.riders.push({
        x: cx, y: 42, vy: 300, w: 40, boulder: true,
        dmg: Math.round(12 + state.wave * 3), elem: null, crit: 0, burn: false,
        hit: new Set(), owner: "@field", char: "石", color: "#c9b89a", trail: 0, kbMul: 0.5,
      });
      SFX.wallHit();
      addFloater(cx, 70, "🪨 巨石滚下来了！", "#e8c86a", 16);
    }
  }

  /* 烽燧高地：烽火台定时齐射火矢 */
  if (state.field?.tower) {
    state.towerT -= dt;
    if (state.towerT <= 0 && state.enemies.length) {
      state.towerT = 15;
      const dmg = Math.round(8 + state.wave * 3);
      const ts = [...state.enemies].filter(e => !e.dead).sort((a, b) => b.y - a.y).slice(0, 5);
      for (const e of ts) {
        damageEnemy(e, dmg, e.x, e.y, "#ff8a4a", "烽!", null, "@field");
        e.burnT = Math.max(e.burnT, 2);
        e.burnDmg = Math.max(e.burnDmg, Math.max(2, Math.round(dmg * 0.15)));
        e.burnSrc = "@field";
        burst(e.x, e.y, "#ff7a3a", 10, 150);
      }
      addFloater(W / 2, 220, "🗼 烽火齐射！", "#ff9a5a", 18);
      SFX.tactic();
    }
  }

  /* 绝技战场效果计时（拒马被敌人挤破 hp≤0 也消失） */
  if (state.blockade) {
    state.blockade.t -= dt;
    if (state.blockade.hp <= 0) {
      addFloater(W / 2, state.blockade.y - 14, "🚧 拒马被挤破了！", "#ffb84a", 15);
      state.blockade = null;
    } else if (state.blockade.t <= 0) state.blockade = null;
  }
  if (state.palisades.length) {
    for (const pa of state.palisades) {
      pa.t -= dt;
      if (pa.hp <= 0 && pa.t > 0) addFloater(pa.x, pa.y - 14, "🚧 拒马被挤破了！", "#ffb84a", 15);
    }
    state.palisades = state.palisades.filter(pa => pa.t > 0 && pa.hp > 0);
  }
  if (state.armyBuff) {
    state.armyBuff.t -= dt;
    if (state.armyBuff.t <= 0) state.armyBuff = null;
  }
  if (state.armyHaste) {
    state.armyHaste.t -= dt;
    if (state.armyHaste.t <= 0) state.armyHaste = null;
  }
  if (state.flood) {
    state.flood.t -= dt;
    if (state.flood.t <= 0) state.flood = null;
  }
  state.wuxingT = Math.max(0, (state.wuxingT || 0) - dt);
  state.foeCurseT = Math.max(0, (state.foeCurseT || 0) - dt);   // 渠帅咒缚（v7.18.0）
  state.foeRageT = Math.max(0, (state.foeRageT || 0) - dt);     // 渠帅贼胆
  foeLordTick(dt);
  if (state.lordCd > 0) state.lordCd = Math.max(0, state.lordCd - dt);
  if (!state.bondAnnounced) {
    state.bondAnnounced = true;
    let by = 268;
    for (const bid of state.bondSet || []) {
      const b = BONDS.find(x => x.id === bid);
      addFloater(W / 2, by, `🔗 羁绊「${b.name}」生效！${b.desc}`, "#ffd24a", 19);
      by += 30;
    }
  }

  /* 波次调度（贼军不等人：每波有时间预算，拖到预算耗尽，下一波不等清场直接压上） */
  const fieldClear = state.spawnQueue.length === 0 && state.enemies.length === 0;
  if (fieldClear) {
    // 休整期：清场才算撑过本波（无尽计分挂这里），预生成下波并展示预告
    if (state.endless && state.winWave && state.scoredWave !== state.wave) {
      state.scoredWave = state.wave;
      recordWeekScore(state.wave - state.winWave);   // 撑完一整波才算数——中途退出也不丢已到手的分
      saveMeta();
    }
    prepareNextWave();
    state.waveTimer -= dt;
    if (state.waveTimer <= 0) startNextWave();
  } else {
    // 战斗中：预算计时
    if (state.waveBudget) {
      state.waveClock += dt;
      if (!state.rushWarned && state.waveClock >= state.waveBudget - 6) {
        state.rushWarned = true;
        prepareNextWave();   // 提前亮下波预告
        addFloater(W / 2, 330, "🥁 催战！下一波马上压上", "#ff7a5a", 18);   // 330=让开预告框（框顶130+最多6行）
        SFX.waveStart();
      }
      if (state.waveClock >= state.waveBudget) startNextWave();
    }
    if (state.spawnQueue.length) {
      state.spawnTimer -= dt;
      if (state.spawnTimer <= 0) {
        const spec = state.spawnQueue.shift();
        spawnEnemy(spec);
        state.spawnTimer = state.spawnQueue.length ? state.spawnQueue[0].delay : 0;
      }
    }
  }

  /* 敌人移动 + 燃烧 */
  const _banners = state.enemies.filter(x => x.special === "banner" && !x.dead && !(x.silencedT > 0));
  const _wardens = state.enemies.filter(x => x.special === "warden" && !x.dead && !(x.silencedT > 0));
  const cdt = dt / foeTenacity();   // 深水区韧性：控制计时走表加速（等效控制时长×韧性系数）
  if (cdt > dt * 1.001) {   // 韧性外显（v7.17.12）：被锁的贼间歇迸发挣脱——让"镣铐越锁越松"看得见
    state.tenPulseT = (state.tenPulseT ?? 3) - dt;
    if (state.tenPulseT <= 0) {
      state.tenPulseT = 5;
      let shown = 0;
      for (const e2 of state.enemies) {
        if (e2.dead || shown >= 3) continue;
        if (e2.stunT > 0.3 || e2.fearT > 0.3 || e2.sleepT > 0.3 || e2.charmT > 0.3) {
          addFloater(e2.x, e2.y - e2.r - 16, "⛓️挣脱!", "#c9a8ff", 13);
          burst(e2.x, e2.y, "#c9a8ff", 6, 90);
          shown++;
        }
      }
    }
  }
  for (const e of state.enemies) {
    e.wob += dt * 4;
    e.slowT = Math.max(0, e.slowT - cdt);
    e.charmT = Math.max(0, (e.charmT || 0) - cdt);
    e.stunT = Math.max(0, (e.stunT || 0) - cdt);
    e.sleepT = Math.max(0, (e.sleepT || 0) - cdt);
    e.fearT = Math.max(0, (e.fearT || 0) - cdt);
    e.silencedT = Math.max(0, (e.silencedT || 0) - cdt);
    if (e.special === "ram") {   // 锤车是死物：心智类控制全免，物理类只顿半拍，撞开就滚回来
      e.fearT = 0; e.charmT = 0; e.sleepT = 0;
      e.stunT = Math.max(0, e.stunT - cdt);
      e.slowT = Math.max(0, e.slowT - cdt);
      e.kb = Math.min(e.kb || 0, 10);
    }
    e.jianjunT = Math.max(0, (e.jianjunT || 0) - dt);
    e.armorBreakT = Math.max(0, (e.armorBreakT || 0) - dt);
    e.hitFlash = Math.max(0, e.hitFlash - dt * 6);
    /* 特种兵光环/技能（被貂蝉沉默时全部哑火） */
    if (e.special === "healer" && !e.dead && !(e.silencedT > 0)) {
      e.auraT -= dt;
      if (e.auraT <= 0) {
        e.auraT = 1.5;
        let healed = false;
        for (const e2 of state.enemies) {
          if (e2.dead || e2 === e || e2.hp >= e2.hpMax) continue;
          if (dist2(e.x, e.y, e2.x, e2.y) < 110 ** 2) {
            e2.hp = Math.min(e2.hpMax, e2.hp + Math.round(e2.hpMax * 0.06));
            healed = true;
          }
        }
        if (healed) burst(e.x, e.y, "#8aff9a", 6, 80);
      }
    }
    if (e.special === "shaman" && !e.dead && e.y > 60 && !(e.silencedT > 0)) {
      e.sealT -= dt;
      if (e.sealT <= 0) {
        e.sealT = 7;
        const units = allUnits().filter(u => !(u.sealedT > 0));
        if (units.length) {
          const u = pick(units);
          u.sealedT = 3;
          for (let r = 0; r < GRID_ROWS; r++)
            for (let c = 0; c < GRID_COLS; c++)
              if (state.slots[r][c] === u) {
                const pp = slotCenter(r, c);
                addFloater(pp.x, pp.y - 46, "🌀 被封印3秒!", "#c96aff", 14);
                burst(pp.x, pp.y, "#c96aff", 12, 130);
              }
        }
      }
    }
    if (e.summoner && !e.dead && !(e.silencedT > 0)) {
      e.summonT -= dt;
      if (e.summonT <= 0) {
        e.summonT = e.kit === "summon" || e.kit === "avatar" ? 3.5 : 6;   // 程远志/化神召得更疯
        const nS = e.kit === "summon" || e.kit === "avatar" ? 4 : 3;
        for (let i = 0; i < nS; i++) {
          state.enemies.push({
            x: clamp(e.x + rand(-50, 50), 16, W - 16), y: Math.max(-20, e.y - rand(10, 40)),
            hp: Math.round(e.hpMax * 0.04), hpMax: Math.round(e.hpMax * 0.04),
            baseSpeed: e.baseSpeed * 1.8, r: 13,
            cls: pick(ENEMY_CLS), big: false, boss: false, affix: null,
            shield: 0, shieldMax: 0, xp: 1, dmg: 1, res: {},
            special: null, summoner: false, summonT: 0, auraT: 0, sealT: 0,
            slowT: 0, burnT: 0, burnDmg: 0, burnTick: 0, regenTick: 0, charmT: 0, stunT: 0, fearT: 0,
            wob: rand(0, Math.PI * 2), face: "\u63f4", hitFlash: 0,
          });
        }
        addFloater(e.x, e.y - e.r - 24, "召援军!", "#ff8a5a", 13);
      }
    }
    if (e.burnT > 0 && !wxRain()) {
      e.burnT -= dt;
      e.burnTick -= dt;
      if (e.burnTick <= 0) {
        e.burnTick = 0.5;
        // 火油车遗宝：点着的火更疼一半
        damageEnemy(e, e.burnDmg * (state.field?.burnMul || 1) * (hasRelic("huoyou") ? 1.5 : 1) * (state.weekTheme === "liaoyuan" ? 1.5 : 1) * (wxEast() ? 1.6 : 1), e.x, e.y, "#ff9a5a", "", null, e.burnSrc || "@fire");   // v6.0 天时改挂点燃本体（东风烧更旺；大雨在外层直接熄火）
        if (Math.random() < 0.5)
          state.particles.push({
            x: e.x + rand(-6, 6), y: e.y - e.r, vx: rand(-8, 8), vy: rand(-50, -30),
            life: 0.5, maxLife: 0.5, color: "#ff8a3a", size: rand(3, 5),
          });
      }
      if (e.dead) continue;
    }
    // 减速带：地形自带的水/泥（截江的大江 v7.14.1 减速40%且保留挨打多——孙权抬升）
    const band = state.field?.band;
    let bandK = 1;
    if (band && e.y > band.y1 && e.y < band.y2) bandK = Math.min(bandK, band.slow);
    // 旗手光环：周围敌军加速（旗手名单每帧只算一次，不做怪×怪全遍历）
    let bannerMul = 1;
    if (!e.special) {
      for (const e2 of _banners) {
        if (dist2(e.x, e.y, e2.x, e2.y) < 120 ** 2) { bannerMul = 1.35; break; }
      }
    }
    // 督军督战：圈内小怪少挨打30%（先杀督军）
    e._guarded = false;
    if (!e.special) {
      for (const e2 of _wardens) {
        if (dist2(e.x, e.y, e2.x, e2.y) < 130 ** 2) { e._guarded = true; break; }
      }
    }
    const spd = e.baseSpeed * (e.slowT > 0 ? 0.55 : 1)
      * bandK * bannerMul
      * (inFlood(e) ? 0.6 : 1)   // 截江断流（v7.14.1 加码）：江里的贼变慢40%——从"多打一点"变成半个冰封+增伤
      * ((e.affix === "frenzy" || e.kit === "affixlord") && e.hp < e.hpMax * 0.4 ? 1.6 : 1);
    // 回春
    if ((e.affix === "regen" || e.kit === "affixlord") && e.hp < e.hpMax) {
      e.regenTick -= dt;
      if (e.regenTick <= 0) {
        e.regenTick = 1;
        e.hp = Math.min(e.hpMax, e.hp + Math.max(1, Math.round(e.hpMax * 0.02)));
      }
    }
    // 骑兵冲撞后坐力：被撞平滑往后滑一段，起延迟作用
    if (e.kb > 0) {
      const step = Math.min(e.kb, 300 * dt);
      e.y = Math.max(-30, e.y - step);
      e.kb -= step;
    }
    // —— 只守本路：敌军只被自己纵列上的武将拦截，本列无人就直冲城墙 ——
    // （不跨列寻人，空路必须靠城墙硬扛或调兵补防）
    let blocker = null, stopY = Infinity;
    if (e.special !== "ram" && e.y > GRID_Y - (e.special === "shooter" ? 330 : e.special === "thrower" ? 340 : 150)) {
      const cc = clamp(Math.floor((e.x - GRID_X) / CELL), 0, GRID_COLS - 1);
      for (let rr = 0; rr < GRID_ROWS; rr++) {
        const uu = state.slots[rr][cc];
        if (!uu) continue;
        const sy = GRID_Y + rr * CELL + 6 - e.r * 0.4;
        // 只拦"还没走过这格"的敌人：冲过前排的去打后排，全走过了就直奔城墙——
        // 堵"前排死了补个新人，把已经压到城下的贼首整列拉回拦截线"的传送门（玩家实测出的无限守城）
        if (e.y > sy + 6) continue;
        blocker = { u: uu, r: rr, c: cc };
        stopY = sy;
        break;
      }
      // 有拦截者时向本列中心对齐（贴合近战动画，不算跨列）
      if (blocker) {
        const tx = GRID_X + cc * CELL + CELL / 2;
        if (Math.abs(tx - e.x) > 4)
          e.x += Math.sign(tx - e.x) * Math.min(130 * dt, Math.abs(tx - e.x));
      }
    }
    // 眩晕定住；恐惧倒退跑；结界拦停；弓贼/投石驻足远程；武将拦截近战；否则正常推进
    const pal = state.palisades.length ? palisadeStopY(e) : null;
    if (e.stunT > 0) {
      // 原地不动
    } else if (e.sleepT > 0) {
      // 睡着了：原地打盹（挨打即醒，见 damageEnemy）
    } else if (e.turncoatT > 0) {
      // 贾诩·离间：倒戈期原地掉头殴打身边同伙（伤害算玩家的——经验金币照拿）
      e.turncoatT -= dt;
      e.tcTick = (e.tcTick ?? 0.2) - dt;
      if (e.tcTick <= 0) {
        e.tcTick = 0.8;
        let mate = null, best2 = Infinity;
        for (const e2 of state.enemies) {
          if (e2 === e || e2.dead || e2.turncoatT > 0) continue;
          const d2 = dist2(e.x, e.y, e2.x, e2.y);
          if (d2 < best2) { best2 = d2; mate = e2; }
        }
        if (mate && best2 < 160 ** 2) {
          damageEnemy(mate, Math.max(3, Math.round(e.hpMax * 0.08)), mate.x, mate.y, "#ff7ab8", "", null, e.tcSrc || null);
          state.beams.push({ x1: e.x, y1: e.y, x2: mate.x, y2: mate.y, t: 0.18, color: "#ff7ab8", w: 2 });
        }
      }
    } else if (e.fearT > 0) {
      e.y -= spd * 0.8 * dt;
    } else if (state.blockade && e.y + e.r >= state.blockade.y) {
      e.y = Math.min(e.y, state.blockade.y - e.r);
      state.blockade.hp -= dt * (e.boss ? 2.5 : 1);   // 人挤人拆墙：挡的越多破得越快
      if (hasRelic("jili")) barbTick(e, dt);   // 蒺藜骨朵：挡住的人掉血
    } else if (pal) {
      e.y = Math.min(e.y, pal.y - e.r);
      pal.hp -= dt * (e.boss ? 2.5 : 1);
      if (hasRelic("jili")) barbTick(e, dt);
    } else if (e.special === "assassin" && e.y > GRID_Y - 170) {
      // 刺客：摸到阵前就飞爪跃进阵里，专捅最后排的武将（弓辅的克星，盾奶的用武之地）
      if (!e.leapT) {
        let tgt = null;
        for (let rr = GRID_ROWS - 1; rr >= 0 && !tgt; rr--) {   // 从最靠墙的一排找起
          const cand = [];
          for (let cc = 0; cc < GRID_COLS; cc++) if (state.slots[rr][cc]) cand.push({ r: rr, c: cc });
          if (cand.length) {
            // 优先捅不打人的和弓兵（软柿子）
            const soft = cand.filter(x => ["archer", "support", "granary", "egg"].includes(state.slots[x.r][x.c].type.cls));
            tgt = pick(soft.length ? soft : cand);
          }
        }
        if (tgt) {
          const pc = slotCenter(tgt.r, tgt.c);
          e.x = pc.x + rand(-14, 14);
          e.y = pc.y - 30;
          e.leapT = 1;
          e.assR = tgt.r; e.assC = tgt.c;
          burst(e.x, e.y, "#c9a8ff", 12, 150);
          addFloater(e.x, e.y - 24, "🗡️ 刺客跃阵!", "#ff9ad2", 14);
        } else {
          e.y += spd * dt;   // 阵上没人：照常冲墙
        }
      } else {
        const uu = state.slots[e.assR]?.[e.assC];
        if (uu && uu.hp > 0) {
          e.atkT = (e.atkT || 0.5) - dt;
          if (e.atkT <= 0) {
            e.atkT = 0.85;
            hurtUnit(uu, Math.round(9 * (1 + state.wave * 0.06) * foeDmgK()), e.assR, e.assC);
            burst(e.x, e.y + 10, "#ff8a6a", 4, 80);
          }
        } else {
          e.leapT = 0;   // 目标没了：重新找下一个（还在阵里，直接再跃）
        }
      }
    } else if (e.special === "shooter" && !(e.silencedT > 0) && !inFlood(e) && blocker && stopY - e.y < 300 && e.y < stopY) {
      // 弓贼：边放箭边慢慢压上来（四成速度），贴到拦截位就转近战——不能在射程外白耗武将
      e.y = Math.min(stopY, e.y + spd * 0.4 * dt);
      e.shootT = (e.shootT ?? 0.9) - dt;
      if (e.shootT <= 0) {
        e.shootT = 2.2;
        const hitDmg = Math.round(7 * (1 + state.wave * 0.06) * foeDmgK());
        const ttS = tauntUnit(e.x, e.y);   // 铁壁嘲讽：箭七成冲盾兵
        state.ebullets.push({ x: e.x, y: e.y + e.r * 0.5, target: ttS ? ttS.u : blocker.u, spd: 260, dmg: Math.max(1, Math.round(hitDmg * 0.9)) });
        burst(e.x, e.y, "#ff5a4a", 4, 70);
      }
    } else if (e.special === "thrower" && !(e.silencedT > 0) && !inFlood(e) && blocker && e.y > GRID_Y - 340 && e.y < stopY) {
      // 投石兵：边扔边慢慢逼近（本列无人照常冲城），贴脸后转近战
      e.y = Math.min(stopY, e.y + spd * 0.35 * dt);
      e.throwT = (e.throwT ?? 1.4) - dt;
      if (e.throwT <= 0) { e.throwT = 4; throwLob(e, 0.8); }
    } else if (blocker && e.y >= stopY) {
      e.y = stopY;
      e.atkT = (e.atkT || 0) - dt;
      if (e.atkT <= 0) {
        e.atkT = e.boss ? 1.6 : 1.2;
        const hitDmg = Math.round((e.boss ? 30 : e.big ? 16 : 7) * (1 + state.wave * 0.06) * foeDmgK());
        hurtUnit(blocker.u, hitDmg, blocker.r, blocker.c);
        // 盾兵反伤=自身最大血量4%（周泰坚守时翻倍），物理系；挡刀还攒经验
        if (blocker.u.type.cls === "shield") {
          const ref = Math.round(blocker.u.hpMax * (0.04 + state.buffs.shieldReflect) * (blocker.u.reflectT > 0 ? 2 : 1));
          if (ref > 0) damageEnemy(e, ref, e.x, e.y - e.r, "#e8c96a", "反!", null, "@fan");
          if (blocker.u.type.id === "yanyan") e.slowT = Math.max(e.slowT, ctrlDur(1.5));   // 严颜：打他的被冻慢
          gainXP(1);
          state.shieldBlocks++;
          if (Math.random() < 0.15) {
            const bp = slotCenter(blocker.r, blocker.c);
            addFloater(bp.x, bp.y - 34, "挡刀+经验", "#ffe45a", 11);
          }
        }
        burst(e.x, e.y + e.r, "#ff8a6a", 5, 90);
      }
    } else {
      e.y += spd * dt;
    }
    // BOSS 投掷（第10波起的贼首行进中也会丢落石；被沉默/在江里时不丢）
    if (e.boss && state.wave >= 10 && !e.dead && !(e.silencedT > 0) && !inFlood(e)) {
      e.bossThrowT = (e.bossThrowT ?? 5) - dt;
      if (e.bossThrowT <= 0 && allUnits().length) { e.bossThrowT = 5; throwLob(e, 0.8); }
    }
    // —— 章尾决战Boss独门机制 ——
    if (e.boss && e.kit && !e.dead && !(e.silencedT > 0)) {
      if (e.kit === "firepot") {   // 波才：双火罐砸阵地
        e.kitT = (e.kitT ?? 5) - dt;
        if (e.kitT <= 0 && allUnits().length) {
          e.kitT = 4.5;
          throwLob(e, 1.25);
          throwLob(e, 1.25);
          addFloater(e.x, e.y - e.r - 24, "🔥 火罐齐掷!", "#ff8a3a", 14);
        }
      } else if (e.kit === "volley") {   // 何仪：乱箭点名
        e.kitT = (e.kitT ?? 4) - dt;
        if (e.kitT <= 0) {
          const us = allUnits();
          if (us.length) {
            e.kitT = 3.5;
            const vd = Math.round(9 * (1 + state.wave * 0.06));
            for (let i = 0; i < 4; i++) {
              const ttV = tauntUnit(e.x, e.y);   // 铁壁嘲讽：乱箭每支七成冲盾兵
              state.ebullets.push({ x: e.x + rand(-12, 12), y: e.y + e.r * 0.5, target: ttV ? ttV.u : pick(us), spd: 280, dmg: vd });
            }
            addFloater(e.x, e.y - e.r - 24, "🏹 乱箭齐发!", "#ffb84a", 14);
          }
        }
      }
      if (e.kit === "sealwave" || e.kit === "avatar") {   // 张宝/化神：群体封印
        e.sealKitT = (e.sealKitT ?? 8) - dt;
        if (e.sealKitT <= 0) {
          e.sealKitT = 9;
          const us = allUnits().filter(u => !(u.sealedT > 0));
          let sealed = 0;
          for (let i = 0; i < 2 && us.length; i++) {
            const u = us.splice(Math.floor(Math.random() * us.length), 1)[0];
            u.sealedT = 2.5;
            sealed++;
            for (let r = 0; r < GRID_ROWS; r++)
              for (let c = 0; c < GRID_COLS; c++)
                if (state.slots[r][c] === u) {
                  const pp = slotCenter(r, c);
                  addFloater(pp.x, pp.y - 46, "🌀 被封印2.5秒!", "#c96aff", 14);
                  burst(pp.x, pp.y, "#c96aff", 12, 130);
                }
          }
          if (sealed) addFloater(e.x, e.y - e.r - 24, "🌀 妖法封印!", "#c96aff", 15);
        }
      }
      if (e.kit === "thunder" || e.kit === "avatar") {   // 张角/化神：天雷点名
        e.thunderKitT = (e.thunderKitT ?? 7) - dt;
        if (e.thunderKitT <= 0) {
          const us = allUnits();
          if (us.length) {
            e.thunderKitT = 7;
            const u = pick(us);
            for (let r = 0; r < GRID_ROWS; r++)
              for (let c = 0; c < GRID_COLS; c++)
                if (state.slots[r][c] === u) {
                  const pp = slotCenter(r, c);
                  hurtUnit(u, Math.round(12 + state.wave), r, c);
                  addFloater(pp.x, pp.y - 46, "⚡ 天雷击顶!", "#ffe45a", 15);
                  burst(pp.x, pp.y, "#ffe45a", 18, 170);
                }
            state.flash = Math.max(state.flash || 0, 0.35);
          }
        }
      }
    }
    e.x += Math.sin(e.wob) * 14 * dt;
    e.x = clamp(e.x, e.r, W - e.r);
    if (e.y > DEFENSE_LINE - 6) {
      let wallDmg = hasRelic("lianhuan") ? Math.max(1, e.dmg - 1) : e.dmg;
      // 典韦护盾先挡
      if (state.wallShield > 0) {
        const ab = Math.min(state.wallShield, wallDmg);
        state.wallShield -= ab;
        wallDmg -= ab;
        addFloater(e.x, DEFENSE_LINE - 40, `🛡️-${ab}`, "#9adf5a", 16);
      }
      if (wallDmg > 0) {
        state.baseHP -= wallDmg;
        state.wallHurt = true;   // 城墙掉过血：本局二星没了
        addFloater(e.x, DEFENSE_LINE - 20, `-${wallDmg}`, "#ff5a5a", 20);
      }
      SFX.wallHit();
      shake = Math.min(shake + 0.35 + wallDmg * 0.06, 1.2);
      burst(e.x, DEFENSE_LINE, "#8a6a3a", 16, 180);
      e.dead = true;
      if (state.baseHP <= 0) cityFall();
    }
  }

  /* 武将攻击 */
  for (let r = 0; r < GRID_ROWS; r++) {
    for (let c = 0; c < GRID_COLS; c++) {
      const u = state.slots[r][c];
      if (!u) continue;
      u.bounce = Math.max(0, u.bounce - dt * 3);
      u.buffT = Math.max(0, u.buffT - dt);
      u.hurtFlash = Math.max(0, (u.hurtFlash || 0) - dt * 4);
      u.sealedT = Math.max(0, (u.sealedT || 0) - dt);
      u.reflectT = Math.max(0, (u.reflectT || 0) - dt);
      u.ultT = Math.max(0, (u.ultT || 0) - dt);   // 兀突骨藤甲毒瘴等"大招持续期"计时
      if (u.rbuffs) for (const k of Object.keys(u.rbuffs)) {
        u.rbuffs[k] -= dt;
        if (u.rbuffs[k] <= 0) delete u.rbuffs[k];
      }
      // 华佗药香：水波/大招后的持续回血（计时内每秒回2%）
      if (u.rbuffs && u.rbuffs.heal > 0 && u.hp < u.hpMax)
        u.hp = Math.min(u.hpMax, u.hp + u.hpMax * 0.02 * dt);
      // 脱战回血：3秒没挨打则每秒回3%（灵泉特质翻倍）
      u.regenT = (u.hurtFlash > 0) ? 3 : Math.max(0, (u.regenT || 0) - dt);

      if (u.regenT <= 0 && u.hp < u.hpMax)
        u.hp = Math.min(u.hpMax, u.hp + u.hpMax * 0.03 * dt * (cellTrait(r, c) === "heal" ? 2 : 1));
      else if (u.type.cls === "shield" && u.hp < u.hpMax)   // 盾兵边挨打边回，扛得住才叫盾（v7.18.5 1.5%→3%/秒，与脱战持平——盾兵的战场就是挨打中）
        u.hp = Math.min(u.hpMax, u.hp + u.hpMax * 0.03 * dt * (cellTrait(r, c) === "heal" ? 2 : 1));
      if (u.sealedT > 0) continue;   // 被妖术封印，无法攻击
      // 粮仓（曹操屯田）：产粮直接喂身边星最低的武将升星（v5.4 起不进经验条；鲁肃加攻波喂它+50%；被封就停产）
      if (u.type.cls === "granary") {
        const tgt = granaryFeedTarget(r, c);
        u.farmT = (u.farmT ?? 4) - dt;
        if (tgt) {
          u.farmAcc = (u.farmAcc || 0) + granaryRate(u) * dt;
          const need = granaryStarNeed();
          if (u.farmAcc >= need) {
            u.farmAcc -= need;
            feedStar(tgt.u, tgt.r, tgt.c);
            state.farmStars = (state.farmStars || 0) + 1;
            if (state.farmStars >= 5) unlockAch("granary40");
          }
          // 喂星进度：4秒一报，别刷屏
          if (u.farmT <= 0) {
            u.farmT = 4;
            const pf = slotCenter(r, c);
            addFloater(pf.x + rand(-8, 8), pf.y - 36, `🌾喂星${Math.min(99, Math.round(u.farmAcc / need * 100))}%`, "#e8c86a", 12);
          }
        } else if (u.farmT <= 0) {
          // 身边没人可喂（都满星/全是物件）：停产提醒
          u.farmT = 4;
          const pf = slotCenter(r, c);
          addFloater(pf.x, pf.y - 36, "旁边没人可喂", "#c9b69a", 11);
        }
        continue;
      }
      // 龙蛋吐纳（v7.16.5 刘表经验轴，用户点名"龙蛋随时间产经验"）：干孵不再是死投资——
      // 孵着就往经验条吐灵气，蛋阶越高吐纳越多；镜像曹操粮仓（粮仓产星/龙蛋产经验），孵化后引擎换成应龙战力
      if (u.type.cls === "egg") {
        u.eggT = (u.eggT ?? 1) - dt;
        if (u.eggT <= 0) {
          u.eggT = 1;
          const tunaXp = (0.6 + 0.1 * Math.min(state.wave, GRANARY_WAVE_CAP)) * u.level
            * (1 + 0.02 * lordLv("liubiao"));   // 养龙术加持
          gainXP(tunaXp, "egg");
          u.eggTick = (u.eggTick || 0) + 1;
          if (u.eggTick % 5 === 0) {   // 5秒一报，别刷屏
            const pe = slotCenter(r, c);
            addFloater(pe.x + rand(-8, 8), pe.y - 36, `🥚吐纳+${Math.round(tunaXp * 5)}`, "#c9a8ff", 12);
          }
        }
        continue;
      }
      // 兀突骨·毒雾光环：身边一圈每秒冒毒（吃五行淬炼毒系；毒经遗宝×1.5；大招期变大变毒）
      if (u.type.id === "wutugu") {
        u.auraTick = (u.auraTick ?? 0.5) - dt;
        if (u.auraTick <= 0) {
          u.auraTick = 1;
          const pw = slotCenter(r, c);
          const aR = 90 * (u.ultT > 0 ? 2.2 : 1);
          const aDmg = (4 + state.wave * 0.5) * (1 + (u.level - 1) * 0.25) * heroLvMul(u.type.id)
            * (1 + (state.buffs.elemBoost[u.type.elem] || 0))
            * (hasRelic("dujing") ? 1.5 : 1) * (u.ultT > 0 ? 2 : 1);
          let hitN = 0;
          for (const e of state.enemies) {
            if (e.dead || e.y < -10) continue;
            if (dist2(e.x, e.y, pw.x, pw.y - 10) > aR * aR) continue;
            damageEnemy(e, aDmg, e.x, e.y, "#9adf5a", "", u.type.elem, u);
            hitN++;
          }
          if (hitN) burst(pw.x, pw.y - 10, "#9adf5a", 5 + Math.min(8, hitN * 2), 90);
        }
      }
      // —— 感知战场（供绝技条件用） ——
      const laneCx = GRID_X + c * CELL + CELL / 2;
      const muzzle = slotCenter(r, c);
      let rng = effRange(u.type);
      if (u.type.id === "dengai" && isObstacle(r, c)) rng += 60;   // 邓艾·居高临下：站石头上看得远（v7.6.0）
      const rng2 = rng ? rng * rng : Infinity;
      u._inRange = 0; u._inColumn = 0;
      let target = null, best = -Infinity;
      let laneTarget = null, laneBest = -Infinity;
      for (const e of state.enemies) {
        if (e.dead || e.y < -10) continue;
        if (Math.abs(e.x - laneCx) < 60) u._inColumn++;
        if (dist2(e.x, e.y, muzzle.x, muzzle.y - 18) > rng2) continue;
        u._inRange++;
        if (e.y > best) { best = e.y; target = e; }
        if (Math.abs(e.x - laneCx) < 60 && e.y > laneBest) { laneBest = e.y; laneTarget = e; }
      }
      // —— 绝技：CD 转好 + 条件满足 → 自动释放 ——
      const ult = ULTS[u.type.id];
      if (ult) {
        // 司马懿水波：大招CD走1.5倍速
        u.ultCd = Math.max(0, u.ultCd - dt * (u.rbuffs && u.rbuffs.cdr > 0 ? 1.7 : 1));
        if (u.ultCd <= 0 && state.enemies.length && ult.cond(u)) {
          castUlt(u, r, c);
          u.ultCd = ultCdMax(u);
        }
      }
      // —— 平A ——
      u.cd -= dt;
      if (u.cd > 0) continue;
      const t = u.type;
      // 盾兵：完全不攻击，只拦截反伤
      if (t.cls === "shield") { u.cd = 9; continue; }
      // 龙蛋：干孵着，什么都不干（挡刀全靠壳硬）
      if (t.cls === "egg") { u.cd = 9; continue; }
      // 应龙：龙息直取全场最大的威胁（血最厚的），重击+镇住不让它作法——
      // 已被稳稳镇住的作法贼头降权，让第二条龙/下一口自动补别的威胁（锤车不作法，纯看血量）
      if (t.cls === "dragon") {
        let dt2 = null, dtScore = -Infinity;
        for (const e of state.enemies) {
          if (e.dead || e.y < 20) continue;
          const caster = e.summoner || e.kit || e.special === "shooter" || e.special === "thrower" || e.special === "shaman" || e.special === "healer" || e.special === "banner";
          const sc = e.hpMax * (caster && e.silencedT > 1 ? 0.25 : 1);
          if (sc > dtScore) { dtScore = sc; dt2 = e; }
        }
        if (!dt2) { u.cd = 0.4; continue; }
        u.cd = t.rate;
        u.bounce = Math.max(u.bounce, 0.7);
        const dmg = dragonDmg(u);
        const pd = slotCenter(r, c);
        state.beams.push({ x1: pd.x, y1: pd.y - 26, x2: dt2.x, y2: dt2.y, t: 0.35, color: "#8ad2ff" });
        // 神威镇压：主目标被震住不敢作法（召援/投掷/绝活全哑）——破顶的真核，贼首悬崖=召援洪水
        const wasQuiet = dt2.silencedT > 0;
        dt2.silencedT = Math.max(dt2.silencedT, 3.2);
        if (!wasQuiet && (dt2.boss || dt2.special))
          addFloater(dt2.x, dt2.y - dt2.r - 26, "😱被神威镇住", "#8ad2ff", 14);
        damageEnemy(dt2, dmg * 3, dt2.x, dt2.y, "#8ad2ff", "龙息!", null, u);   // 主目标重击
        let hitN = 0;
        for (const e of state.enemies) {
          if (e.dead || e.y < -10 || e === dt2) continue;
          if (dist2(e.x, e.y, dt2.x, dt2.y) > (130 + e.r) ** 2) continue;
          damageEnemy(e, dmg, e.x, e.y, "#8ad2ff", "", null, u);
          hitN++;
        }
        for (const e of [dt2, ...state.enemies]) {   // 主目标+溅射圈都点燃
          if (e.dead || wxRain()) continue;
          if (e !== dt2 && dist2(e.x, e.y, dt2.x, dt2.y) > (130 + e.r) ** 2) continue;
          e.burnT = Math.max(e.burnT, 2.5);
          e.burnDmg = Math.max(e.burnDmg, Math.max(2, Math.round(dmg * 0.12)));
          e.burnSrc = u;
        }
        burst(dt2.x, dt2.y, "#8ad2ff", 16, 200);
        SFX.shoot("archer");
        continue;
      }
      // 辅兵：无平A，周期释放水波增益
      if (t.cls === "support") {
        const mods = getUnitMods(u, r, c);
        u.cd = unitRate(u, mods);
        castRipple(u, r, c);
        continue;
      }
      // 骑兵平A=纵贯冲锋（v5.4.1 三路择线）：自己列和左右邻列里挑贼最多的一条道冲——
      // 骑兵不用再跟别的兵种抢"对着敌人"的站位；平手优先自己列；拐弯冲的劲小两成（正面冲还是最狠）。
      // 张郃独门仍更野：全场哪列人多冲哪列，不打折
      if (t.cls === "cav") {
        let chargeX = laneCx, sideK = 1;
        if (t.id === "zhanghe") {
          let bestC = -1, bestN = 0;
          for (let cc = 0; cc < GRID_COLS; cc++) {
            const cx = GRID_X + cc * CELL + CELL / 2;
            let n = 0;
            for (const e of state.enemies) if (!e.dead && e.y > -10 && Math.abs(e.x - cx) < 60) n++;
            if (n > bestN) { bestN = n; bestC = cc; }
          }
          if (bestN < 1) continue;
          chargeX = GRID_X + bestC * CELL + CELL / 2;
        } else {
          let bestC = -1, bestN = 0;
          for (const cc of [c, c - 1, c + 1]) {   // 自己列先查：平手不拐弯
            if (cc < 0 || cc >= GRID_COLS) continue;
            const cx = GRID_X + cc * CELL + CELL / 2;
            let n = 0;
            for (const e of state.enemies) if (!e.dead && e.y > -10 && Math.abs(e.x - cx) < 60) n++;
            if (n > bestN) { bestN = n; bestC = cc; }
          }
          if (bestN < 1) continue;   // 三条道都没贼：不冲
          if (bestC !== c) sideK = 0.8;
          chargeX = GRID_X + bestC * CELL + CELL / 2;
        }
        const mods = getUnitMods(u, r, c);
        u.cd = unitRate(u, mods);
        u.bounce = Math.max(u.bounce, 0.8);
        SFX.shoot("cav");
        state.riders.push({
          x: chargeX, y: muzzle.y - 20,
          vy: -300,                             // 冲锋速度（慢，压阵感）
          w: (t.splash ? 46 : 34) + state.buffs.cavWide,   // 冲锋走廊半宽
          dmg: Math.round(unitDamage(u, mods) * cavCrowdMul() * sideK), elem: t.elem,
          crit: mods.crit, burn: !!t.burn, ley: cellTrait(r, c) === "elem",
          hit: new Set(), owner: u,
          char: t.char, color: ELEMENTS[t.elem].color,
          trail: 0,
        });
        continue;
      }
      if (laneTarget) target = laneTarget;
      if (!target) continue;
      const mods = getUnitMods(u, r, c);
      u.cd = unitRate(u, mods);
      SFX.shoot(t.cls);
      const p = slotCenter(r, c);
      const muzzleY = p.y - 18;

      if (t.cls === "archer") {
        // 弓兵：真正的弹道，飞行距离硬性=射程（全场弓按对角线算）
        const ang = Math.atan2(target.y - muzzleY, target.x - p.x);
        const shots = (t.spread || 1) + state.buffs.extraShot;
        const maxDist = rng || Math.hypot(W, H);
        for (let s = 0; s < shots; s++) {
          const a = ang + (s - (shots - 1) / 2) * 0.22;
          state.bullets.push({
            x: p.x, y: muzzleY,
            vx: Math.cos(a) * t.speed, vy: Math.sin(a) * t.speed,
            dmg: unitDamage(u, mods), cls: t.cls, elem: t.elem,
            crit: mods.crit,
            pierce: t.boomerang ? 999 : (t.pierce || 0) + mods.pierceAdd,
            boomerang: !!t.boomerang,
            bounces: t.bounce || 0,
            splash: t.splash || 0, burn: !!t.burn, slowShot: !!t.slowShot,
            firebrand: !!t.firebrand,
            r: (4 + u.level) * state.buffs.bulletSize,
            dist: 0, maxDist,          // 按飞行距离消散，不再飞出屏幕
            color: ELEMENTS[t.elem].color, owner: u, ley: cellTrait(r, c) === "elem",
          });
        }
      } else {
        // 枪/骑：近身武技，无弹道——直接命中主目标（+溅射/穿透打同列纵深）
        u.bounce = Math.max(u.bounce, 0.5);   // 出手前倾动画
        const elemCol = ELEMENTS[t.elem].color;
        meleeStrike(u, mods, target, p, elemCol, cellTrait(r, c) === "elem");
        // 刺击特效：从武将到目标的短促斩线
        state.slashes.push({
          x1: p.x, y1: muzzleY, x2: target.x, y2: target.y,
          life: 0.14, maxLife: 0.14, color: elemCol,
          w: t.splash ? 5 : 3,
        });
      }
    }
  }

  /* 子弹（弓兵箭矢/绝技弹幕）：按飞行距离消散，射程即弹道尽头 */
  for (const b of state.bullets) {
    const mx = b.vx * dt, my = b.vy * dt;
    b.x += mx;
    b.y += my;
    if (b.maxDist != null) {
      b.dist += Math.hypot(mx, my);
      if (b.dist >= b.maxDist) {
        if (b.boomerang && !b.ret) {
          // 祝融夫人飞刀：飞到头折返，回程七成伤害把沿路的再扫一遍
          b.ret = true;
          b.vx = -b.vx; b.vy = -b.vy;
          b.dist = 0;
          b.dmg = Math.round(b.dmg * 0.7);
          if (b.hitSet) b.hitSet.clear();
          burst(b.x, b.y, b.color, 5, 80);
        } else {
          // 消散特效：箭矢落地
          burst(b.x, b.y, b.color, 3, 40);
          b.dead = true;
          continue;
        }
      }
    } else {
      b.life -= dt;
      if (b.life <= 0) { b.dead = true; continue; }
    }
    // 弹墙（夏侯渊）：撞到左右墙就折返
    if (b.wallBounce > 0) {
      if ((b.x <= b.r + 2 && b.vx < 0) || (b.x >= W - b.r - 2 && b.vx > 0)) {
        b.vx = -b.vx;
        b.wallBounce--;
        burst(b.x, b.y, b.color, 6, 100);
      }
    }
    if (b.x < -20 || b.x > W + 20 || b.y < -30 || b.y > H) { b.dead = true; continue; }
    for (const e of state.enemies) {
      if (e.dead || b.hitSet && b.hitSet.has(e)) continue;
      if (dist2(b.x, b.y, e.x, e.y) < (b.r + e.r) ** 2) {
        bulletHit(e, b, b.x, b.y);
        if (b.splash) {
          const spl = b.splash * (state.field?.narrow ? 1.3 : 1);
          for (const e2 of state.enemies) {
            if (e2 === e || e2.dead) continue;
            if (dist2(b.x, b.y, e2.x, e2.y) < (spl + e2.r) ** 2)
              bulletHit(e2, b, e2.x, e2.y, 0.6);
          }
          burst(b.x, b.y, b.color, 12, 160);
        }
        if (b.pierce > 0) {
          b.pierce--;
          (b.hitSet ||= new Set()).add(e);
        } else if (b.bounces > 0) {
          // 弹射：飞向最近的未命中敌人
          b.bounces--;
          (b.hitSet ||= new Set()).add(e);
          let nt = null, nd = Infinity;
          for (const e2 of state.enemies) {
            if (e2.dead || b.hitSet.has(e2)) continue;
            const d = dist2(b.x, b.y, e2.x, e2.y);
            if (d < nd) { nd = d; nt = e2; }
          }
          if (nt && nd < 300 ** 2) {
            const sp = Math.hypot(b.vx, b.vy);
            const a = Math.atan2(nt.y - b.y, nt.x - b.x);
            b.vx = Math.cos(a) * sp;
            b.vy = Math.sin(a) * sp;
            if (b.maxDist != null) b.maxDist = b.dist + Math.sqrt(nd) + 40;  // 续航到弹射目标
            else b.life = Math.max(b.life, 0.8);
            b.dmg = Math.round(b.dmg * 0.75);   // 每次弹射衰减
          } else {
            b.dead = true;
          }
        } else {
          b.dead = true;
        }
        break;
      }
    }
  }

  /* 骑手冲锋：沿列向上冲到顶，路上撞谁打谁 */
  for (const rd of state.riders) {
    rd.y0 ??= rd.y;   // 出发点：泥沼关按它算冲了多远
    rd.y += rd.vy * dt;
    rd.trail -= dt;
    if (rd.trail <= 0) {
      rd.trail = 0.03;
      state.particles.push({
        x: rd.x + rand(-rd.w * 0.5, rd.w * 0.5), y: rd.y + rand(6, 18),
        vx: rand(-20, 20), vy: rand(30, 80),
        life: 0.35, maxLife: 0.35, color: rd.color, size: rand(2, 4),
      });
    }
    // 泥沼遍地规则/无尽军令：骑兵冲锋走到一半陷马，提前消散（滚石不受影响）
    const ccm = state.diff?.cavChargeMul || state.endlessMod?.mod?.cavChargeMul;
    if (ccm && rd.vy < 0 && (rd.y0 - rd.y) >= (rd.y0 - 30) * ccm) {
      burst(rd.x, rd.y, "#8a6a4a", 10, 100);
      rd.dead = true;
      continue;
    }
    if (rd.y < 30 || (rd.vy > 0 && rd.y > GRID_Y - 40)) {   // 冲到顶（或滚石滚到阵前）：消散
      burst(rd.x, clamp(rd.y, 34, GRID_Y - 40), rd.color, 8, 120);
      rd.dead = true;
      continue;
    }
    for (const e of state.enemies) {
      if (e.dead || rd.hit.has(e)) continue;
      if (Math.abs(e.x - rd.x) < rd.w + e.r * 0.5 && Math.abs(e.y - rd.y) < e.r + 14) {
        rd.hit.add(e);
        const fake = {
          dmg: rd.dmg, cls: "cav", elem: rd.elem,
          crit: rd.crit, burn: rd.burn, slowShot: false, ley: rd.ley,
        };
        bulletHit(e, fake, e.x, e.y);
        if (!e.dead) {
          const stirrup = hasRelic("madeng") ? 1.5 : 1;   // 马镫遗宝：撞飞更远
          const push = (e.boss ? 14 : e.big || e.affix ? 42 : 72) * (rd.kbMul || 1) * stirrup;
          e.kb = Math.min((rd.kbMul > 1 ? 190 : 130) * stirrup, (e.kb || 0) + push);  // 冲撞后推，多骑叠加封顶（孙策巨马推更狠）
        }
      }
    }
  }
  state.riders = state.riders.filter(rd => !rd.dead);

  /* 近战武技命中：主目标全额；溅射打目标周围，穿透打同列纵深 */
  function meleeStrike(u, mods, target, p, elemCol, ley) {
    const t = u.type;
    const fake = {   // 复用 bulletHit 的暴击/遗物/点燃逻辑
      dmg: unitDamage(u, mods), cls: t.cls, elem: t.elem,
      crit: mods.crit, burn: !!t.burn, slowShot: !!t.slowShot, owner: u, ley: !!ley,
    };
    bulletHit(target, fake, target.x, target.y);
    // 溅射（张飞/典韦/许褚/吕布）
    if (t.splash) {
      const spl = t.splash * (state.field?.narrow ? 1.3 : 1);
      for (const e2 of state.enemies) {
        if (e2 === target || e2.dead) continue;
        if (dist2(target.x, target.y, e2.x, e2.y) < (spl + e2.r) ** 2)
          bulletHit(e2, fake, e2.x, e2.y, 0.6);
      }
      burst(target.x, target.y, elemCol, 12, 160);
    }
    // 穿透（赵云/关羽/魏延等）：命中目标身后同一路线的纵深敌人
    const pierceN = (t.pierce || 0) + mods.pierceAdd;
    if (pierceN > 0) {
      const behind = state.enemies
        .filter(e2 => e2 !== target && !e2.dead
          && Math.abs(e2.x - target.x) < 45 && e2.y < target.y)
        .sort((a, b2) => b2.y - a.y)
        .slice(0, pierceN);
      for (const e2 of behind) bulletHit(e2, fake, e2.x, e2.y, 0.8);
    }
    // 三向（张辽）：额外打最近两名其他敌人
    if (t.spread) {
      const others = state.enemies
        .filter(e2 => e2 !== target && !e2.dead
          && dist2(e2.x, e2.y, p.x, p.y - 18) < (t.rng + 40) ** 2)
        .sort((a, b2) => dist2(a.x, a.y, p.x, p.y) - dist2(b2.x, b2.y, p.x, p.y))
        .slice(0, t.spread - 1);
      for (const e2 of others) {
        bulletHit(e2, fake, e2.x, e2.y, 0.85);
        state.slashes.push({
          x1: p.x, y1: p.y - 18, x2: e2.x, y2: e2.y,
          life: 0.14, maxLife: 0.14, color: elemCol, w: 2.5,
        });
      }
    }
  }

  function bulletHit(e, b, hx, hy, mul = 1) {
    let dmg = b.dmg * mul;
    if (b.owner?.type?.id === "sunshangxiang" && !e.boss) e.kb = Math.min((e.kb || 0) + 14, 60);   // 孙尚香：箭带小击退
    dmg *= duelMulOf(b.owner, e);   // 文丑·搦战：打单挑目标更疼（v7.6.0）
    // 橹楯车：大盾挡箭，弹道只吃两成半（近战/冲锋/大招照常）
    if (e.special === "pavise") { dmg *= 0.25; if (Math.random() < 0.25) addFloater(hx, hy - 10, "叮!", "#c9b69a", 11); }
    let tag = "", color = "#ffffff";
    let forceCrit = false;
    if (state.baihuReady) { state.baihuReady = false; forceCrit = true; }
    if (forceCrit || Math.random() < b.crit) {
      const critMul = hasRelic("qinggang") ? 3 : 2;
      dmg *= critMul;
      tag = critMul === 3 ? "三倍暴击!" : "双倍暴击!";
      color = "#ff8a5a"; SFX.crit();
    }
    // 古锭刀：对精锐/贼首增伤
    if (hasRelic("guding") && (e.boss || e.affix)) dmg *= 1.25;
    // 火烙印（陆逊）：已经着火的多挨他50%打
    if (b.firebrand && e.burnT > 0) dmg *= 1.5;
    // 铁脊蛇矛：枪兵击退
    if (b.cls === "spear" && hasRelic("shemao") && Math.random() < 0.2 && !e.boss)
      e.y = Math.max(-30, e.y - 50);
    if (b.burn && !wxRain()) {
      let dur = 2.5;
      e.burnT = Math.max(e.burnT, dur);
      let bd = Math.max(1, Math.round(b.dmg * 0.12));
      if (wxEast()) bd *= 2;
      e.burnDmg = Math.max(e.burnDmg, bd);
      e.burnSrc = b.owner || e.burnSrc;
    }
    if (b.slowShot) e.slowT = Math.max(e.slowT, ctrlDur(1.2));
    // 左慈·幻变（v7.6.0）/ 灵脉自带破敌（v7.9.0）：打谁都恒定按克制算——elem按目标的系现场转
    damageEnemy(e, dmg, hx, hy, color, tag, atkElemOf(b.owner, e, b.elem, b.ley), b.owner);
  }

  /* 敌方冷箭：追踪目标武将（目标阵亡/离场则消散） */
  for (const eb of state.ebullets) {
    const pos = findUnitPos(eb.target);
    if (!pos || eb.target.hp <= 0) { eb.dead = true; continue; }
    const pp = slotCenter(pos[0], pos[1]);
    const tx = pp.x, ty = pp.y - 10;
    const d = Math.hypot(tx - eb.x, ty - eb.y);
    if (d < 14) {
      eb.dead = true;
      hurtUnit(eb.target, eb.dmg, pos[0], pos[1]);
      burst(eb.x, eb.y, "#ff5a4a", 6, 100);
      continue;
    }
    eb.vx = (tx - eb.x) / d * eb.spd;
    eb.vy = (ty - eb.y) / d * eb.spd;
    eb.x += eb.vx * dt;
    eb.y += eb.vy * dt;
  }
  state.ebullets = state.ebullets.filter(eb => !eb.dead);

  /* 敌方投石：落地对半径70内友军范围伤害 */
  for (const lb of state.elobs) {
    lb.t += dt;
    if (lb.t >= lb.dur) {
      lb.dead = true;
      burst(lb.x1, lb.y1, "#ff6a3a", 22, 200);
      burst(lb.x1, lb.y1, "#5a4632", 12, 130);
      shake = Math.max(shake, 0.3);
      for (let r = 0; r < GRID_ROWS; r++)
        for (let c = 0; c < GRID_COLS; c++) {
          const u = state.slots[r][c];
          if (!u) continue;
          const pp = slotCenter(r, c);
          if (dist2(pp.x, pp.y, lb.x1, lb.y1) <= 70 * 70) {
            const cover = u.type.cls !== "shield" && shieldCover(r, c);
            hurtUnit(u, cover ? Math.round(lb.dmg * (hasRelic("hufu") ? 0.35 : 0.5)) : lb.dmg, r, c);
            if (cover && !u.dead) addFloater(pp.x, pp.y - 30, "盾墙挡一半!", "#e8c96a", 12);
          }
        }
    }
  }
  state.elobs = state.elobs.filter(lb => !lb.dead);

  /* 我方投掷（甘宁炸弹/陆逊火罐）：落地结算溅射伤害 / 生成火堆 */
  for (const fl of state.flobs) {
    fl.t += dt;
    if (fl.t >= fl.dur) {
      fl.dead = true;
      burst(fl.x1, fl.y1, fl.color, 16, 180);
      if (fl.dmg > 0) {
        for (const e of state.enemies) {
          if (e.dead) continue;
          if (dist2(e.x, e.y, fl.x1, fl.y1) <= (fl.splash + e.r) ** 2)
            damageEnemy(e, fl.dmg, e.x, e.y, fl.color, "轰!", fl.elem, fl.src);
        }
        shake = Math.max(shake, 0.25);
      }
      if (fl.pit)
        state.firePits.push({ x: fl.x1, y: fl.y1, r: fl.pit.r, t: fl.pit.t, dmg: fl.pit.dmg, src: fl.src });
    }
  }
  state.flobs = state.flobs.filter(fl => !fl.dead);

  /* 火堆（陆逊）：圈内敌人持续被点燃 */
  for (const fp of state.firePits) {
    fp.t -= dt;
    for (const e of state.enemies) {
      if (e.dead) continue;
      if (dist2(e.x, e.y, fp.x, fp.y) <= fp.r * fp.r) {
        e.burnT = Math.max(e.burnT, 0.8);
        e.burnDmg = Math.max(e.burnDmg, fp.dmg);
        e.burnSrc = fp.src || e.burnSrc;
      }
    }
  }
  state.firePits = state.firePits.filter(fp => fp.t > 0);

  /* 陷阱（魏延）：敌人踩中就炸一圈毒 */
  for (const tp of state.traps) {
    tp.t -= dt;
    if (tp.t <= 0) { tp.dead = true; continue; }
    for (const e of state.enemies) {
      if (e.dead || e.y < 0) continue;
      if (dist2(e.x, e.y, tp.x, tp.y) <= (tp.r + e.r) ** 2) {
        tp.dead = true;
        burst(tp.x, tp.y, "#9adf5a", 22, 200);
        shake = Math.max(shake, 0.2);
        addFloater(tp.x, tp.y - 16, "☠️ 踩雷了！", "#9adf5a", 15);
        for (const e2 of state.enemies) {
          if (e2.dead) continue;
          if (dist2(e2.x, e2.y, tp.x, tp.y) <= (tp.splash + e2.r) ** 2)
            damageEnemy(e2, tp.dmg, e2.x, e2.y, "#9adf5a", "", tp.elem, tp.src);
        }
        break;
      }
    }
  }
  state.traps = state.traps.filter(tp => !tp.dead);

  /* 连弩塔（黄月英）：临时炮台，自动射最近敌人，8秒到点拆掉 */
  for (const tw of state.turrets) {
    tw.t -= dt;
    if (tw.t <= 0) { tw.dead = true; burst(tw.x, tw.y, "#ffd24a", 12, 130); continue; }
    tw.cd -= dt;
    if (tw.cd > 0) continue;
    let nt = null, nd = tw.rng * tw.rng;
    for (const e of state.enemies) {
      if (e.dead || e.y < -10) continue;
      const d = dist2(e.x, e.y, tw.x, tw.y);
      if (d < nd) { nd = d; nt = e; }
    }
    if (!nt) continue;
    tw.cd = tw.rate;
    const a = Math.atan2(nt.y - (tw.y - 8), nt.x - tw.x);
    state.bullets.push({
      x: tw.x, y: tw.y - 8, vx: Math.cos(a) * 540, vy: Math.sin(a) * 540,
      dmg: tw.dmg, cls: "archer", elem: tw.elem, crit: 0,
      pierce: 0, splash: 0, burn: false,
      r: 3.5, dist: 0, maxDist: tw.rng + 60, color: ELEMENTS[tw.elem].color,
    });
  }
  state.turrets = state.turrets.filter(tw => !tw.dead);

  /* 追踪弹（姜维）：拐弯咬人，目标没了就找最近的 */
  for (const hm of state.homers) {
    hm.life -= dt;
    if (hm.life <= 0) { hm.dead = true; continue; }
    if (!hm.target || hm.target.dead) {
      let nt = null, nd = Infinity;
      for (const e of state.enemies) {
        if (e.dead) continue;
        const d = dist2(e.x, e.y, hm.x, hm.y);
        if (d < nd) { nd = d; nt = e; }
      }
      if (!nt) { hm.dead = true; burst(hm.x, hm.y, hm.color, 5, 80); continue; }
      hm.target = nt;
    }
    const d = Math.hypot(hm.target.x - hm.x, hm.target.y - hm.y) || 1;
    if (d < 14) {
      damageEnemy(hm.target, hm.dmg, hm.x, hm.y, "#ff8a5a", "", hm.elem, hm.src);
      if (!hm.target.dead && !wxRain()) {
        hm.target.burnT = Math.max(hm.target.burnT, 2.5);
        hm.target.burnDmg = Math.max(hm.target.burnDmg, Math.max(2, Math.round(hm.dmg * 0.15)));
        hm.target.burnSrc = hm.src || hm.target.burnSrc;
      }
      burst(hm.x, hm.y, hm.color, 8, 130);
      hm.dead = true;
      continue;
    }
    // 追踪转向：先窜出去再拐弯咬回来
    hm.vx += (hm.target.x - hm.x) / d * 900 * dt;
    hm.vy += (hm.target.y - hm.y) / d * 900 * dt;
    const sp = Math.hypot(hm.vx, hm.vy) || 1;
    hm.vx = hm.vx / sp * hm.spd;
    hm.vy = hm.vy / sp * hm.spd;
    hm.x += hm.vx * dt;
    hm.y += hm.vy * dt;
  }
  state.homers = state.homers.filter(hm => !hm.dead);

  /* 死亡链接（诸葛亮）：计时+剔除死怪，人数<2 就散 */
  if (state.deathLink) {
    state.deathLink.t -= dt;
    state.deathLink.members = state.deathLink.members.filter(m => !m.dead);
    if (state.deathLink.t <= 0 || state.deathLink.members.length < 2) state.deathLink = null;
  }

  /* 冲击波：环推进+扫过的敌人结算一次（随战斗一起暂停，不在 updateFx 偷跑） */
  for (const sk of state.shocks) {
    sk.r += 320 * dt;
    for (const e of state.enemies) {
      if (e.dead || sk.hit.has(e)) continue;
      if (dist2(e.x, e.y, sk.x, sk.y) <= (sk.r + e.r) ** 2) {
        sk.hit.add(e);
        if (sk.dmg > 0) {
          const b4sk = e.hp;
          damageEnemy(e, sk.dmg, e.x, e.y, sk.color, "震!", sk.elem, "@lord");
          if (sk.tao) sk.taoDealt = (sk.taoDealt || 0) + Math.max(0, b4sk - e.hp);   // 桃园反击记账：实打出的伤换经验
        }
        if (!e.dead) {
          if (sk.stun) e.stunT = Math.max(e.stunT, e.boss ? 0.5 : sk.stun);
          if (sk.slow) e.slowT = Math.max(e.slowT, ctrlDur(sk.slow));
          if (sk.fear) e.fearT = Math.max(e.fearT, e.boss ? sk.fear * 0.5 : sk.fear);
          if (sk.kb) e.kb = Math.min(160, (e.kb || 0) + (e.boss ? sk.kb * 0.25 : sk.kb));
        }
      }
    }
  }
  for (const sk of state.shocks) {
    // 桃园义济（v7.15.2 刘备再加强）：反击环走完，按实际打出的伤2%一次性换经验——仁德之师，血债也要变粮饷
    if (sk.tao && sk.r >= sk.max && (sk.taoDealt || 0) > 0) {
      const xpTy = Math.max(1, Math.round(sk.taoDealt * 0.08));   // 路径2%→5%→8%（v7.16.5 探针定标：2次大反击≈3.3手牌，进3.5~4.5手达标带）
      gainXP(xpTy, "taoyuan");
      addFloater(W / 2, 330, `🍑 桃园义济：反击打出${Math.round(sk.taoDealt)}伤，换 ${xpTy} 经验`, "#ffd278", 17);
    }
  }
  state.shocks = state.shocks.filter(sk => sk.r < sk.max);

  state.enemies = state.enemies.filter(e => !e.dead);
  state.bullets = state.bullets.filter(b => !b.dead);
  /* —— 主公战斗段（v7.3.3 从 updateFx 迁回）：updateFx 在暂停面板期间也跑（粒子渐隐），
     自动大招/白马/强弩/亲射/金身倒计时放那边=暂停时主公照打怪涨经验（v5.6 强弩起就漏）——只能住在 update 里 —— */
  {
    const tyPrev = state.taoyuanT || 0;
    state.taoyuanT = Math.max(0, tyPrev - dt);   // 桃园义全军金身倒计时
    // 桃园反击（v7.14 抬弱势主公）：金身落幕，把扛住的伤全额攒成一记全场冲击——扛得越狠反击越疼，防御变蓄力
    if (tyPrev > 0 && state.taoyuanT === 0 && (state.taoyuanAbsorb || 0) > 0) {
      const lpTy = lordPos();
      const dmgTy = Math.max(1, Math.round(state.taoyuanAbsorb));   // v7.15.1 再加码 0.6→1.0：扛多少还多少，字面意义的全数奉还
      state.taoyuanAbsorb = 0;
      state.shocks.push({ x: lpTy.x, y: lpTy.y - 12, r: 20, max: 900, stun: 1.0, kb: 90, elem: null, color: "#ffd2a8", dmg: dmgTy, hit: new Set(), tao: 1 });
      state.ripples.push({ x: lpTy.x, y: lpTy.y - 16, r: 8, max: 620, color: "#ffd2a8", kind: "wind" });
      addFloater(W / 2, 300, `🍑 桃园反击！结义扛下的伤全数奉还（每贼${dmgTy}）`, "#ffd2a8", 20);
      SFX.buff();
    }
  }
  // —— v7.0 自动大招：CD好了、时机对了（lordAutoOk），主公自己放——从城墙上的主公主体发出 ——
  if (state.phase === "play" && state.lord && state.lord[0] && state.lordCd <= 0 && !state.gewu
    && lordAutoOk(state.lord[0].id)) castLord(0);
  // —— 永久战术卡触发（v7.16 三改）：每波自动来，不用点 ——
  if (state.phase === "play" && (state.luanshiOn || state.shuiyanOn || state.zhanshouOn || state.ruler === "sunquan")) {
    const liveT = aliveEnemies().filter(e => e.y > 0);
    // 乱石穿空：本波贼上齐（≥5在场）时全障碍齐射一轮
    if (state.luanshiOn && state.luanshiWave !== state.wave && liveT.length >= 5 && state.obstacles.size) {
      state.luanshiWave = state.wave;
      let hitN = 0;
      for (const k of state.obstacles) {
        const [r2, c2] = k.split(",").map(Number);
        const pc = slotCenter(r2, c2);
        let tgt = null, nd = Infinity;
        for (const e of liveT) { if (e.dead) continue; const d = dist2(e.x, e.y, pc.x, pc.y); if (d < nd) { nd = d; tgt = e; } }
        if (!tgt) break;
        state.lobs.push({ x0: pc.x, y0: pc.y, x1: tgt.x, y1: tgt.y, t: 0, dur: 0.3, color: "#c9b69a", icon: "🪨" });
        damageEnemy(tgt, (12 + state.wave * 2.5) + tgt.hpMax * 0.04, tgt.x, tgt.y, "#c9b69a", "砸!", null, "@rock");
        hitN++;
      }
      if (hitN) { addFloater(W / 2, 330, `🪨 乱石穿空！${hitN}块障碍齐发`, "#c9b69a", 18); shake = Math.max(shake, 0.35); }
    }
    // 水淹七军/水军都督：本波贼进场（有人过河线）自动起江——
    // 孙权固有弱版3秒（v7.16.2 独家线：八家里就他没专属机制），水淹卡标准4秒，两者兼得=长江天堑6秒
    const rvOwn = state.ruler === "sunquan", rvCard = state.shuiyanOn;
    if ((rvOwn || rvCard) && state.shuiyanWave !== state.wave && !(state.flood && state.flood.t > 0) && liveT.some(e => e.y > 250)) {
      state.shuiyanWave = state.wave;
      const rvT = rvOwn && rvCard ? 7 : rvCard ? 4 : 4.5 + lordLv("sunquan") * 0.15;   // v7.16.3 略强：固有3→4.5秒起步（3秒覆盖率太低），天堑6→7
      const rvAmp = rvOwn && rvCard ? 0.4 : rvCard ? 0.25 : 0.2 + 0.005 * lordLv("sunquan");   // v7.16.2 二段：固有20%起步、天堑40%
      state.flood = { y1: 330, y2: 415, amp: rvAmp, t: rvT };
      state.ripples.push({ x: W / 2, y: 372, r: 8, max: 560, color: "#8ad2ff", kind: "wind" });
      addFloater(W / 2, 372, rvOwn && rvCard ? "🌊 长江天堑！大江拦腰7秒" : rvOwn ? `⚓ 水军都督！起江${rvT.toFixed(1)}秒` : "🌊 水淹七军！大江拦腰4秒", "#8ad2ff", 18);
    }
    // 擒贼擒王：精锐/贼首/大块头登场即挨主公一记重击（吃亲射全部加成——御驾亲征/连弩/亲兵/弱势倍率）
    if (state.zhanshouOn) for (const e of liveT) {
      if (e._qz || !(e.boss || e.special || e.big || e.affix)) continue;
      e._qz = 1;
      const est = lordAtkEst();
      const dm = (est ? est.per * 5 : 25 + state.wave * 3) + e.hpMax * 0.05;
      const lpQ = lordPos();
      state.beams.push({ x1: lpQ.x, y1: lpQ.y - 14, x2: e.x, y2: e.y, t: 0.3, color: "#ffd24a", w: 4 });
      damageEnemy(e, dm, e.x, e.y, "#ffd24a", "擒!", null, "@lord");
    }
  }
  // —— 公孙瓒·白马义从（v7.0 主公下场实验）：无敌白马专砍特种/贼首/高伤怪，时间到回城 ——
  if (state.baima && state.baima.t > 0) {
    const B = state.baima;
    B.t -= dt;
    let tgtB = null, bestSc = -Infinity;
    for (const e of state.enemies) {
      if (e.dead || e.y < -10) continue;
      const sc = (e.special ? 3000 : 0) + (e.boss ? 2000 : 0) + (e.dmg || 0) * 50
        - Math.hypot(e.x - B.x, e.y - B.y) * 0.5;
      if (sc > bestSc) { bestSc = sc; tgtB = e; }
    }
    if (tgtB) {
      const dxB = tgtB.x - B.x, dyB = tgtB.y - B.y, dB = Math.hypot(dxB, dyB) || 1;
      if (dB > tgtB.r + 14) { B.x += dxB / dB * 300 * dt; B.y += dyB / dB * 300 * dt; }
      B.hitT -= dt;
      if (dB <= tgtB.r + 24 && B.hitT <= 0) {
        B.hitT = 0.35;
        state._lordKill = 1;   // 首级记功（v7.16.5）：主公亲手砍死的算首级
        damageEnemy(tgtB, B.dmg, tgtB.x, tgtB.y, "#e8f4ff", "", null, "@lord");
        state._lordKill = 0;
        burst(tgtB.x, tgtB.y, "#e8f4ff", 6, 90);
      }
    }
    if (Math.random() < 0.5)
      state.particles.push({ x: B.x + rand(-8, 8), y: B.y + 12, vx: rand(-20, 20), vy: rand(20, 60),
        life: 0.4, maxLife: 0.4, color: "#e8f4ff", size: rand(2, 4) });
    if (B.t <= 0) { addFloater(B.x, B.y, "🐎 回城！", "#e8f4ff", 14); state.baima = null; }
  }
  // —— 公孙瓒·城头强弩（v5.6 城墙轴）：城墙自动放箭射最贴近防线的贼——墙越满箭越狠 ——
  if (state.ruler === "gongsunzan" && state.enemies.length) {
    state.nuT = (state.nuT ?? 1.5) - dt;
    if (state.nuT <= 0) {
      let tgt = null, deep = -Infinity;
      for (const e of state.enemies) if (!e.dead && e.y > 0 && e.y > deep) { deep = e.y; tgt = e; }
      if (tgt) {
        state.nuT = 2.5 * (state.lordAtkGap || 1) * (hasRelic("yushan") ? 0.8 : 1);   // 神机连弩卡/白羽扇：强弩也上弦更快
        const dmg = ((6 + state.wave * 1.2) * (1 + (state.lordAtkBuff || 0)) + tgt.hpMax * 0.03) * (state.baseHP / Math.max(1, state.baseHPMax))
          * (1 + 0.03 * lordLv("gongsunzan")) * LORD_ATK.gongsunzan.mul;   // v7.17.3：御驾亲征只加基数——3%目标血是保底口粮，不许被卡叠成引擎
        const lpN = lordPos();
        state.beams.push({ x1: lpN.x, y1: lpN.y - 14, x2: tgt.x, y2: tgt.y, t: 0.3, color: "#e8dcc0", w: 3 });
        const b4n = tgt.hp;
        state._lordKill = 1;   // 首级记功：强弩射死的也算主公首级
        damageEnemy(tgt, dmg, tgt.x, tgt.y, "#e8dcc0", "", null, "@lord");
        state._lordKill = 0;
        addFloater(tgt.x + rand(-8, 8), tgt.y - tgt.r - 10, `-${Math.max(1, Math.round(b4n - tgt.hp))}`, "#e8dcc0", 12.5);
        SFX.shoot("archer");
      }
    }
  }
  // —— 文丑·搦战（v7.6.0）：每8秒点名场上最肥的普通贼单挑4秒——它只冲文丑来，文丑打它×1.5（bulletHit分支） ——
  {
    let wc = null, wcR = -1, wcC = -1;
    for (let r2 = 0; r2 < GRID_ROWS && !wc; r2++)
      for (let c2 = 0; c2 < GRID_COLS && !wc; c2++)
        if (state.slots[r2][c2]?.type.id === "wenchou") { wc = state.slots[r2][c2]; wcR = r2; wcC = c2; }
    if (wc && state.phase === "play") {
      state.wenchouT = (state.wenchouT ?? 3) - dt;
      if (state.wenchouT <= 0) {
        state.wenchouT = 8;
        let fat = null;
        for (const e of aliveEnemies())
          if (!e.special && !e.boss && !(e.duelT > 0) && e.y > 0 && (!fat || e.hpMax > fat.hpMax)) fat = e;
        if (fat) {
          fat.duelT = 4;
          fat.duelX = slotCenter(wcR, wcC).x;
          addFloater(fat.x, fat.y - fat.r - 14, "⚔️ 搦战！", "#ff8a5a", 15);
          burst(fat.x, fat.y, "#ff8a5a", 10, 120);
        }
      }
    }
    for (const e of state.enemies) {
      if (!(e.duelT > 0) || e.dead) continue;
      e.duelT -= dt;
      if (e.duelX != null && !e.stunT && !e.fearT)   // 应战：一边走一边横移到文丑那列
        e.x += Math.max(-1, Math.min(1, (e.duelX - e.x) / 40)) * 90 * dt;
    }
  }
  // —— 主公亲射（v7.1 基础平A / v7.4.0 各家一套招式）：站在墙上不是雕像——每3秒出一手。
  //    伤害吃主公等级+亲兵助威(kinPower ×1.0~1.6)；范围大伤害高的招分给弱势主公（孙权/刘表/刘备），
  //    强势家（曹操/袁绍/袁术/董卓）单体点到为止；公孙瓒有更狠的强弩不重复；不早朝=不上墙 ——
  if (state.ruler && state.ruler !== "gongsunzan" && !state.gewu && !(state.baima && state.baima.t > 0)
    && state.phase === "play" && state.enemies.length) {
    state.lordAtkT = (state.lordAtkT ?? 1.5) - dt;
    if (state.lordAtkT <= 0) {
      // 按贴墙深度排序的活贼名单（多数招式的目标源）
      const live = state.enemies.filter(e => !e.dead && e.y > 0).sort((a, b) => b.y - a.y);
      if (live.length) {
        state.lordAtkT = 3 * (state.lordAtkGap || 1) * (hasRelic("yushan") ? 0.8 : 1);   // 神机连弩卡/白羽扇：出手更勤
        // v7.4.2 整体重定价（用户"刮痧没什么用，调整请全体考虑"）：伤害=基数+3%×目标血上限——
        // 第1波到无尽深水都保持"一击啃一口"的占比，不随敌血曲线贬值；亲兵/主公等级照乘
        // v7.15：再乘 LORD_ATK 弱势倍率；v7.17.3 孙权130波事故：御驾亲征只乘基数部分——
        // 3%目标血是"不贬值的保底口粮"，一旦被卡叠加成倍放大就变成无视1.18复利的引擎
        const lordMod = (1 + 0.02 * lordLv(state.ruler)) * kinPower()
          * ((LORD_ATK[state.ruler] || {}).mul || 1);
        const dmgOf = (e, k) => ((7 + state.wave * 0.75) * (1 + (state.lordAtkBuff || 0)) + e.hpMax * 0.03) * k * lordMod;
        const lpA = lordPos();
        const beamTo = (e, color, w = 2.5) => state.beams.push({ x1: lpA.x, y1: lpA.y - 14, x2: e.x, y2: e.y, t: 0.28, color, w });
        // 主公的刀必飘数字（damageEnemy 对<30的伤害只有25%显示——玩家看不见掉血）
        const lordHit = (e, dm, color) => {
          const b4 = e.hp;
          damageEnemy(e, dm, e.x, e.y, color, "", null, "@lord");
          addFloater(e.x + rand(-8, 8), e.y - e.r - 10, `-${Math.max(1, Math.round(b4 - e.hp))}`, color, 12.5);
        };
        const tgtL = live[0];
        switch (state.ruler) {
          case "sunquan": {   // 楼船连弩：三连水箭射最贴墙的3个贼——弱势主公拿群体火力（v7.16.3 每箭0.8→1.0）
            for (const e of live.slice(0, 3)) {
              beamTo(e, "#4ab0ff", 2.5);
              lordHit(e, dmgOf(e, 1.0), "#4ab0ff");
            }
            break;
          }
          case "liubiao": {   // 寒江霜箭：射最深的贼并炸开寒雾——命中者周围80px挨打+减速（守成之主的控场）
            beamTo(tgtL, "#8ad2ff", 3);
            state.ripples.push({ x: tgtL.x, y: tgtL.y, r: 6, max: 80, color: "#8ad2ff", kind: "wind" });
            for (const e of live) {
              if (Math.hypot(e.x - tgtL.x, e.y - tgtL.y) > 80) continue;
              lordHit(e, dmgOf(e, e === tgtL ? 1 : 0.6), "#8ad2ff");
              e.slowT = Math.max(e.slowT || 0, 1.2);
            }
            break;
          }
          case "liubei": {   // 双股剑气：一道横扫剑光——命中者与其左右90px内的兄弟贼一起挨
            beamTo(tgtL, "#ffe8c0", 3.5);
            state.slashes.push({ x1: tgtL.x - 60, y1: tgtL.y - 8, x2: tgtL.x + 60, y2: tgtL.y + 8, life: 0.2, maxLife: 0.2, color: "#ffe8c0", w: 7 });
            let cut = 0;
            for (const e of live) {
              if (Math.abs(e.y - tgtL.y) > 40 || Math.abs(e.x - tgtL.x) > 90 || cut >= 4) continue;
              lordHit(e, dmgOf(e, e === tgtL ? 1 : 0.7), "#ffe8c0");
              cut++;
            }
            break;
          }
          case "dongzhuo": {   // 火油瓶：抛一瓶火砸最深的贼——小片火+点燃（相国的做派）
            state.lobs.push({ x0: lpA.x, y0: lpA.y - 14, x1: tgtL.x, y1: tgtL.y, t: 0, dur: 0.35, color: "#ff8a3a", icon: "🔥" });
            for (const e of live) {
              if (Math.hypot(e.x - tgtL.x, e.y - tgtL.y) > 65) continue;
              lordHit(e, dmgOf(e, e === tgtL ? 0.9 : 0.55), "#ff8a3a");
              e.burnT = Math.max(e.burnT || 0, 2);
              e.burnDmg = Math.max(e.burnDmg || 0, 2 + state.wave * 0.4);
              e.burnSrc = "@lord";
            }
            break;
          }
          case "yuanshao": {   // 门客暗箭：紫电冷箭，点最深的贼（四世三公出手不沾血）
            beamTo(tgtL, "#c9a8ff", 2.5);
            lordHit(tgtL, dmgOf(tgtL, 1), "#c9a8ff");
            break;
          }
          case "yuanshu": {   // 玉玺砸人：金光一道（僭越的家伙用国宝开路）
            beamTo(tgtL, "#ffd24a", 3);
            lordHit(tgtL, dmgOf(tgtL, 1), "#ffd24a");
            break;
          }
          default: {   // 曹操·掷戟（及兜底）：单体快手
            beamTo(tgtL, "#ffd24a", 2.5);
            lordHit(tgtL, dmgOf(tgtL, 1), "#ffd24a");
          }
        }
        SFX.shoot("archer");
      }
    }
  }
  updateFx(dt);
}

function updateFx(dt) {
  for (const p of state.particles) {
    p.x += p.vx * dt; p.y += p.vy * dt;
    p.vy += 220 * dt;
    p.life -= dt;
  }
  state.particles = state.particles.filter(p => p.life > 0);
  for (const f of state.floaters) { f.y -= 34 * dt; f.life -= dt * 0.9; }
  state.floaters = state.floaters.filter(f => f.life > 0);
  for (const sl of state.slashes) sl.life -= dt;
  state.slashes = state.slashes.filter(sl => sl.life > 0);
  // 水波环扩散
  for (const rp of state.ripples) rp.r += 300 * dt;
  state.ripples = state.ripples.filter(rp => rp.r < rp.max + 40);
  // （冲击波环的推进与伤害结算都在 update，暂停时冻结）
  // 射线渐隐
  for (const bm of state.beams) bm.t -= dt;
  state.beams = state.beams.filter(bm => bm.t > 0);
  // 我方抛掷（纯视觉，落地散花；带 label 的落地飘大字——鲁肃粮包"+N经验"）
  for (const lb of state.lobs) {
    lb.t += dt;
    if (lb.t >= lb.dur) {
      lb.dead = true;
      burst(lb.x1, lb.y1, lb.color, 14, 160);
      if (lb.label) addFloater(lb.x1, lb.y1 - 12, lb.label, "#ffe45a", 17);
    }
  }
  state.lobs = state.lobs.filter(lb => !lb.dead);
  // 天威雷光闪衰减（纯视觉）
  state.flash = Math.max(0, (state.flash || 0) - dt * 2.2);
  state.dance = Math.max(0, (state.dance || 0) - dt);
  // 乐不思蜀挂机（v7.12）：歌舞演完后有牌就自动抽——1秒扫牌轮盘+0.5秒定格，随机拍板（避开自刎归天/乐不思蜀）
  if (state.gewu && state.phase === "play" && state.cards && !state.dance) {
    if (!state.autoSel) {
      const ok = state.cards.map((c, i) => i).filter(i => state.cards[i].kind !== "seppuku" && state.cards[i].kind !== "dance");
      state.autoSel = { t: 0, idx: ok.length ? ok[Math.floor(Math.random() * ok.length)] : 0 };
    }
    state.autoSel.t += dt;
    if (state.autoSel.t >= 1.5) {
      const card = state.cards[state.autoSel.idx];
      state.autoSel = null;
      applyCard(card);
    }
  } else if (!state.cards) state.autoSel = null;

  shake = Math.max(0, shake - dt * 2.2);
}

/* ---------- 绘制 ---------- */
function roundRect(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function draw() {
  ctx.save();
  if (shake > 0) ctx.translate(rand(-1, 1) * shake * 7, rand(-1, 1) * shake * 7);

  /* 背景：古战场 */
  const sky = ctx.createLinearGradient(0, 0, 0, H);
  sky.addColorStop(0, "#2a2012");
  sky.addColorStop(0.5, "#3a2c18");
  sky.addColorStop(0.62, "#44341e");
  sky.addColorStop(1, "#2a2012");
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, W, H);

  // 烽烟点缀
  ctx.fillStyle = "rgba(255,220,150,.14)";
  for (let i = 0; i < 26; i++) {
    const sx = (i * 137.5) % W;
    const sy = (i * 89.3 + state.time * 6) % (GRID_Y - 60);
    ctx.fillRect(sx, sy, 2, 2);
  }

  /* 地利地形 */
  if (state.field) {
    const f = state.field;
    if (state.flood) {
      const fl2 = state.flood;
      ctx.fillStyle = "rgba(90,170,255,.22)";
      ctx.fillRect(0, fl2.y1, W, fl2.y2 - fl2.y1);
      ctx.font = "12px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "rgba(160,210,255,.8)";
      ctx.fillText(`🌊 大江横流 ${Math.ceil(fl2.t)}s · 江里的贼挨打多${Math.round((fl2.amp || 0.3) * 100)}%`, W / 2, (fl2.y1 + fl2.y2) / 2 + 4);
    }
    if (f.band) {
      const water = f.band.type === "water";
      const g = ctx.createLinearGradient(0, f.band.y1, 0, f.band.y2);
      g.addColorStop(0, water ? "rgba(58,110,160,.30)" : "rgba(80,62,34,.38)");
      g.addColorStop(0.5, water ? "rgba(74,140,200,.42)" : "rgba(96,76,42,.5)");
      g.addColorStop(1, water ? "rgba(58,110,160,.30)" : "rgba(80,62,34,.38)");
      ctx.fillStyle = g;
      ctx.fillRect(0, f.band.y1, W, f.band.y2 - f.band.y1);
      // 波纹 / 泥泡
      ctx.strokeStyle = water ? "rgba(160,210,255,.35)" : "rgba(140,115,70,.4)";
      ctx.lineWidth = 1.5;
      for (let i = 0; i < 6; i++) {
        const wy = f.band.y1 + 10 + ((i * 41 + state.time * (water ? 16 : 6)) % (f.band.y2 - f.band.y1 - 16));
        ctx.beginPath();
        for (let x = 20 + i * 12; x <= W - 30; x += 8)
          ctx.lineTo(x, wy + Math.sin(x * 0.08 + state.time * 2 + i) * 3);
        ctx.stroke();
      }
      ctx.font = "13px sans-serif";
      ctx.textAlign = "left";
      ctx.fillStyle = water ? "rgba(160,210,255,.6)" : "rgba(190,160,100,.6)";
      ctx.fillText(`${f.icon} ${water ? "大江" : "泥沼"}`, 8, f.band.y1 + 17);
    }
    if (f.narrow) {
      // 两侧峭壁
      ctx.fillStyle = "rgba(46,36,22,.85)";
      ctx.fillRect(0, 0, W * 0.2, GRID_Y - 6);
      ctx.fillRect(W * 0.8, 0, W * 0.2, GRID_Y - 6);
      ctx.fillStyle = "rgba(255,220,150,.10)";
      for (let i = 0; i < 12; i++) {
        const yy = (i * 67.7) % (GRID_Y - 40);
        ctx.fillText("⛰️", 12 + (i % 3) * 26, yy + 30);
        ctx.fillText("⛰️", W * 0.8 + 10 + (i % 3) * 26, ((i * 53.3) % (GRID_Y - 40)) + 30);
      }
    }
    if (f.tower) {
      ctx.font = "30px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("🗼", 30, GRID_Y - 16);
      ctx.fillText("🗼", W - 30, GRID_Y - 16);
      // 充能条
      const chg = 1 - state.towerT / 15;
      ctx.fillStyle = "rgba(0,0,0,.4)";
      ctx.fillRect(14, GRID_Y - 12, 32, 4);
      ctx.fillRect(W - 46, GRID_Y - 12, 32, 4);
      ctx.fillStyle = "#ff9a5a";
      ctx.fillRect(14, GRID_Y - 12, 32 * chg, 4);
      ctx.fillRect(W - 46, GRID_Y - 12, 32 * chg, 4);
    }
  }

  /* 城池：阵地下方垫一层城墙造型（垛口砖墙），受击面在武将身后 */
  {
    const wy = DEFENSE_LINE - 2;
    const g2 = ctx.createLinearGradient(0, wy, 0, H);
    g2.addColorStop(0, "#5a4832");
    g2.addColorStop(1, "#3a2e1e");
    ctx.fillStyle = g2;
    ctx.fillRect(0, wy, W, H - wy);
    // 垛口
    ctx.fillStyle = "#6a563c";
    for (let x = 0; x < W; x += 40) ctx.fillRect(x + 4, wy - 8, 24, 8);
    // 砖缝
    ctx.strokeStyle = "rgba(0,0,0,.25)";
    ctx.lineWidth = 1;
    for (let x = 0; x < W; x += 48) {
      ctx.beginPath(); ctx.moveTo(x, wy + 8); ctx.lineTo(x, H); ctx.stroke();
    }
    ctx.beginPath(); ctx.moveTo(0, wy + 14); ctx.lineTo(W, wy + 14); ctx.stroke();
    // 受击闪红
    if (shake > 0.5) {
      ctx.globalAlpha = (shake - 0.5) * 0.5;
      ctx.fillStyle = "#ff4a3a";
      ctx.fillRect(0, wy - 8, W, H - wy + 8);
      ctx.globalAlpha = 1;
    }
    // v7.0 主公主体：站在城墙正中（白马下场期间人不在墙上）
    const rl7 = rulerOf();
    if (rl7 && !(state.baima && state.baima.t > 0)) {
      const lp = lordPos();
      ctx.beginPath(); ctx.arc(lp.x, lp.y, 20, 0, Math.PI * 2);
      const gL = ctx.createRadialGradient(lp.x, lp.y - 6, 4, lp.x, lp.y, 20);
      gL.addColorStop(0, "#8a6a3a"); gL.addColorStop(1, "#5a4224");
      ctx.fillStyle = gL; ctx.fill();
      const kp = kinPower();
      ctx.strokeStyle = kp > 1 ? "#ffd24a" : "rgba(255,220,160,.6)";
      ctx.lineWidth = kp > 1 ? 2.5 : 1.5;
      if (kp > 1) { ctx.shadowColor = "#ffd24a"; ctx.shadowBlur = 4 + (kp - 1) * 14; }
      ctx.beginPath(); ctx.arc(lp.x, lp.y, 20, 0, Math.PI * 2); ctx.stroke();
      ctx.shadowBlur = 0;
      ctx.textAlign = "center";
      ctx.font = "11px sans-serif";
      ctx.fillText("👑", lp.x, lp.y - 22);
      ctx.font = "bold 16px 'Kaiti SC', 'STKaiti', serif";
      ctx.fillStyle = "#ffe8c0";
      ctx.fillText(rl7.name[0], lp.x, lp.y + 1);
      ctx.font = "9px sans-serif";
      ctx.fillStyle = "#d5c9a8";
      ctx.fillText(rl7.name, lp.x, lp.y + 13);
      if (kp > 1) {   // 亲兵助威：主体旁小字——加成看得见
        ctx.font = "bold 10px sans-serif";
        ctx.fillStyle = "#ffd24a";
        ctx.fillText(`🤝×${kp.toFixed(1)}`, lp.x - 48, lp.y + 4);
      }
      const estW = lordAtkEst();   // v7.15.1 用户点名：普攻方式和攻击力写在城墙上——盘右两行小字
      if (estW) {
        ctx.font = "bold 10px sans-serif";
        ctx.fillStyle = "#ffb84a";
        ctx.fillText(`${estW.atk.icon}${estW.atk.name}`, lp.x + 52, lp.y - 3);
        ctx.font = "9px sans-serif";
        ctx.fillStyle = "#d5c9a8";
        ctx.fillText(`约${Math.round(estW.per)}伤/${estW.itv.toFixed(1)}s`, lp.x + 52, lp.y + 9);
      }
    }
  }

  /* 阵地格子 + 障碍 + 特质角标 */
  for (let r = 0; r < GRID_ROWS; r++) {
    for (let c = 0; c < GRID_COLS; c++) {
      const x = GRID_X + c * CELL, y = GRID_Y + r * CELL;
      const obs = isObstacle(r, c);
      if (obs) {
        ctx.fillStyle = "rgba(60,50,36,.55)";
        roundRect(x + 3, y + 3, CELL - 6, CELL - 6, 10);
        ctx.fill();
        if (state.digMode) {   // 洛阳铲挖掘模式：可挖的障碍格金框呼吸
          ctx.strokeStyle = `rgba(255,210,74,${0.5 + Math.sin(state.time * 6) * 0.35})`;
          ctx.lineWidth = 2.5;
          roundRect(x + 3, y + 3, CELL - 6, CELL - 6, 10);
          ctx.stroke();
        }
        ctx.font = "26px sans-serif";
        ctx.textAlign = "center";
        ctx.globalAlpha = 0.85;
        ctx.fillText((r + c) % 2 ? "🪨" : "🌲", x + CELL / 2, y + CELL / 2 + 9);
        ctx.globalAlpha = 1;
      } else {
        ctx.fillStyle = (r + c) % 2 ? "rgba(255,235,180,.05)" : "rgba(255,235,180,.09)";
        roundRect(x + 3, y + 3, CELL - 6, CELL - 6, 10);
        ctx.fill();
      }
      // 特质角标（右下小字；障碍格半透明预告清出后的地形）
      const tk = state.traits[r + "," + c];
      if (tk) {
        ctx.font = "11px sans-serif";
        ctx.textAlign = "right";
        ctx.globalAlpha = obs ? 0.4 : 0.85;
        ctx.fillText(TRAITS[tk].icon, x + CELL - 7, y + CELL - 7);
        ctx.globalAlpha = 1;
      }
    }
  }

  /* 战阵光环连线（常显）：枪兵→相邻全兵种友军，绿色能量线+呼吸，光环强度看得见 */
  for (let r = 0; r < GRID_ROWS; r++) {
    for (let c = 0; c < GRID_COLS; c++) {
      const u = state.slots[r][c];
      if (!u || u.type.cls !== "spear") continue;
      const p1 = slotCenter(r, c);
      for (let rr = Math.max(0, r - 1); rr <= Math.min(GRID_ROWS - 1, r + 1); rr++)
        for (let cc = Math.max(0, c - 1); cc <= Math.min(GRID_COLS - 1, c + 1); cc++) {
          if (rr === r && cc === c) continue;
          const nb = state.slots[rr][cc];
          if (!nb || !unitAttacks(nb.type)) continue;   // 盾/辅不吃攻击光环，不连线
          const p2 = slotCenter(rr, cc);
          const pulse = 0.25 + Math.sin(state.time * 3 + r + c) * 0.12;
          ctx.strokeStyle = `rgba(111,212,78,${pulse})`;
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.moveTo(p1.x, p1.y);
          ctx.lineTo(p2.x, p2.y);
          ctx.stroke();
        }
    }
  }

  /* 屯田喂养连线（常显，v5.5.3 用户点头）：粮仓→正在喂的武将拉稻草金呼吸线，对象头顶挂🌾——
     "它在喂谁"从脑补规则变成一眼看清 */
  for (let r = 0; r < GRID_ROWS; r++) {
    for (let c = 0; c < GRID_COLS; c++) {
      const u = state.slots[r][c];
      if (!u || u.type.cls !== "granary") continue;
      const tgt = granaryFeedTarget(r, c);
      if (!tgt) continue;
      const p1 = slotCenter(r, c), p2 = slotCenter(tgt.r, tgt.c);
      const pulse = 0.35 + Math.sin(state.time * 2.8 + r * 2 + c) * 0.18;
      ctx.strokeStyle = `rgba(232,200,106,${pulse})`;
      ctx.lineWidth = 3;
      ctx.setLineDash([4, 5]);
      ctx.beginPath();
      ctx.moveTo(p1.x, p1.y);
      ctx.lineTo(p2.x, p2.y);
      ctx.stroke();
      ctx.setLineDash([]);
      // 喂养对象头顶小麦标 + 顺着线飘的粮粒（吃粮动画）
      ctx.font = "13px sans-serif";
      ctx.textAlign = "center";
      ctx.globalAlpha = 0.9;
      ctx.fillText("🌾", p2.x + 16, p2.y - 26);
      const k = (state.time * 0.7 + (r + c) * 0.37) % 1;
      ctx.globalAlpha = 0.85 * Math.sin(k * Math.PI);
      ctx.font = "11px sans-serif";
      ctx.fillText("🌾", p1.x + (p2.x - p1.x) * k, p1.y + (p2.y - p1.y) * k - 6);
      ctx.globalAlpha = 1;
    }
  }

  /* 羁绊连线（常显）：生效中的羁绊成员之间拉金色呼吸链——谁跟谁一伙，一眼看清 */
  if (state.bondSet?.size) {
    for (const b of BONDS) {
      if (!state.bondSet.has(b.id)) continue;
      const pts = [];
      for (const id of b.members) {
        for (let r = 0; r < GRID_ROWS && pts.length < b.members.length; r++)
          for (let c = 0; c < GRID_COLS; c++) {
            const uu = state.slots[r][c];
            if (uu && uu.type.id === id) { pts.push(slotCenter(r, c)); r = 99; break; }
          }
      }
      const pulse = 0.3 + Math.sin(state.time * 2.5) * 0.18;
      ctx.strokeStyle = `rgba(255,210,74,${pulse})`;
      ctx.lineWidth = 2.5;
      ctx.setLineDash([7, 6]);
      for (let i = 0; i + 1 < pts.length; i++) {
        ctx.beginPath();
        ctx.moveTo(pts[i].x, pts[i].y);
        ctx.lineTo(pts[i + 1].x, pts[i + 1].y);
        ctx.stroke();
      }
      ctx.setLineDash([]);
    }
  }

  /* 武将（被下波贼的属性克住的：少数派警示，别指望他们输出） */
  const theme = (state.nextWavePreview?.themeElems && state.phase === "play") ? state.nextWavePreview.themeElems : null;
  for (let r = 0; r < GRID_ROWS; r++) {
    for (let c = 0; c < GRID_COLS; c++) {
      const u = state.slots[r][c];
      if (!u || (state.drag && state.drag.unit === u)) continue;
      const p = slotCenter(r, c);
      drawUnit(u, p.x, p.y - u.bounce * 10, 1, theme ? theme.some(k => TRI_KE[k] === u.type.elem) && elemMatters(u.type) : false, r, c);   // v6.0：被这波贼克的武将亮警示
    }
  }

  /* 拖动中的武将：显示落点射程圈——位置的意义看得见 */
  if (state.drag) {
    const du = state.drag.unit;
    const rng = effRange(du.type);
    const s = slotAt({ x: state.drag.x, y: state.drag.y });
    // 射程圈锚定在将要放下的格子（没有格子就跟手）
    let anchor = { x: state.drag.x, y: state.drag.y - 24 };
    if (s) anchor = slotCenter(s[0], s[1]);
    ctx.save();
    const col = CLASSES[du.type.cls].color;
    if (du.type.cls === "cav") {
      // 骑兵：冲锋走廊预览（主道实、左右邻道淡——冲锋挑贼最多的一条）
      const cw = (du.type.splash ? 46 : 34) + state.buffs.cavWide;
      for (const off of [-CELL, CELL]) {
        const sx = anchor.x + off;
        if (sx < GRID_X || sx > GRID_X + GRID_COLS * CELL) continue;
        ctx.globalAlpha = 0.06;
        ctx.fillStyle = col;
        ctx.fillRect(sx - cw, 30, cw * 2, anchor.y - 48 - 30);
      }
      ctx.globalAlpha = 0.14;
      ctx.fillStyle = col;
      ctx.fillRect(anchor.x - cw, 30, cw * 2, anchor.y - 48 - 30);
      ctx.globalAlpha = 0.6;
      ctx.strokeStyle = col;
      ctx.lineWidth = 2;
      ctx.setLineDash([10, 8]);
      ctx.strokeRect(anchor.x - cw, 30, cw * 2, anchor.y - 48 - 30);
      ctx.setLineDash([]);
      ctx.globalAlpha = 0.8;
      ctx.font = "bold 13px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("🐎 左中右挑贼多的道冲", anchor.x, anchor.y - 66);
    } else if (du.type.cls === "support") {
      // 辅兵：水波范围预览（大乔冰波圈更大）
      const rad = rippleMax(du.type);
      ctx.strokeStyle = col;
      ctx.globalAlpha = 0.6;
      ctx.lineWidth = 2;
      ctx.setLineDash([8, 6]);
      ctx.beginPath();
      ctx.arc(anchor.x, anchor.y - 18, rad, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.globalAlpha = 0.8;
      ctx.font = "bold 13px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(du.type.ripple === "slow" ? "❄️ 这一圈都冻慢"
        : du.type.ripple === "soothe" ? "🎵 这一圈解封回血"
        : du.type.ripple === "cdr" ? "🕐 这一圈大招转快"
        : "🎐 这一圈都加", anchor.x, anchor.y - 66);
    } else if (rng) {
      ctx.strokeStyle = col;
      ctx.globalAlpha = 0.6;
      ctx.lineWidth = 2;
      ctx.setLineDash([8, 6]);
      ctx.beginPath();
      ctx.arc(anchor.x, anchor.y - 18, rng, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.globalAlpha = 0.08;
      ctx.fillStyle = col;
      ctx.beginPath();
      ctx.arc(anchor.x, anchor.y - 18, rng, 0, Math.PI * 2);
      ctx.fill();
    } else {
      // 弓兵全场：顶部横幅示意
      ctx.globalAlpha = 0.5;
      ctx.font = "bold 13px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = col;
      ctx.fillText("🏹 全场都能射", anchor.x, anchor.y - 60);
    }
    ctx.restore();
    if (s) {
      const [r, c] = s;
      ctx.strokeStyle = "#9aff8a";
      ctx.lineWidth = 3;
      roundRect(GRID_X + c * CELL + 3, GRID_Y + r * CELL + 3, CELL - 6, CELL - 6, 10);
      ctx.stroke();
      // 目标格特质高亮提示
      const tk = state.traits[r + "," + c];
      if (tk && !isObstacle(r, c)) {
        const tt = TRAITS[tk];
        ctx.font = "bold 12px sans-serif";
        ctx.textAlign = "center";
        ctx.strokeStyle = "rgba(0,0,0,.75)";
        ctx.lineWidth = 3;
        const tx = GRID_X + c * CELL + CELL / 2, ty = GRID_Y + r * CELL - 6;
        ctx.strokeText(`${tt.icon}${tt.name} ${tt.desc}`, tx, ty);
        ctx.fillStyle = "#ffe45a";
        ctx.fillText(`${tt.icon}${tt.name} ${tt.desc}`, tx, ty);
      }
      // 枪兵战阵光环预览：落点周围会被强化的友军格发绿光
      if (du.type.cls === "spear") {
        for (let rr = Math.max(0, r - 1); rr <= Math.min(GRID_ROWS - 1, r + 1); rr++)
          for (let cc = Math.max(0, c - 1); cc <= Math.min(GRID_COLS - 1, c + 1); cc++) {
            if (rr === r && cc === c) continue;
            const nb = state.slots[rr][cc];
            if (nb && nb !== du && unitAttacks(nb.type)) {
              ctx.fillStyle = "rgba(111,212,78,.22)";
              roundRect(GRID_X + cc * CELL + 3, GRID_Y + rr * CELL + 3, CELL - 6, CELL - 6, 10);
              ctx.fill();
              const np = slotCenter(rr, cc);
              ctx.font = "bold 11px sans-serif";
              ctx.textAlign = "center";
              ctx.fillStyle = "#9aff8a";
              ctx.fillText(`+${Math.round((0.10 + state.buffs.spearAura) * 100)}%`, np.x, np.y - 34);
            }
          }
      }
      // 反向：落点若与已有枪兵相邻，提示受益（光环惠及会打人的兵种；盾/辅拖过去不受益不提示）
      if (unitAttacks(du.type)) {
        for (let rr = Math.max(0, r - 1); rr <= Math.min(GRID_ROWS - 1, r + 1); rr++)
          for (let cc = Math.max(0, c - 1); cc <= Math.min(GRID_COLS - 1, c + 1); cc++) {
            const nb = state.slots[rr][cc];
            if (nb && nb !== du && nb.type.cls === "spear") {
              const np = slotCenter(rr, cc);
              ctx.strokeStyle = "rgba(111,212,78,.6)";
              ctx.lineWidth = 2;
              ctx.setLineDash([4, 4]);
              ctx.beginPath();
              ctx.moveTo(np.x, np.y);
              ctx.lineTo(GRID_X + c * CELL + CELL / 2, GRID_Y + r * CELL + CELL / 2);
              ctx.stroke();
              ctx.setLineDash([]);
            }
          }
      }
    }
    if (state.drag.moved && state.drag.y < GRID_Y - 40) {
      ctx.font = "bold 15px sans-serif";
      ctx.textAlign = "center";
      ctx.strokeStyle = "rgba(0,0,0,.75)";
      ctx.lineWidth = 3;
      ctx.fillStyle = "#ff8a6a";
      const sellTxt = allUnits().length <= 1 ? "最后一个武将不能卖"
        : `🗑 松手卖掉${state.drag.unit.type.name}，腾出一格（不退经验）`;
      ctx.strokeText(sellTxt, clamp(state.drag.x, 90, W - 90), state.drag.y - 62);
      ctx.fillText(sellTxt, clamp(state.drag.x, 90, W - 90), state.drag.y - 62);
    }
    drawUnit(state.drag.unit, state.drag.x, state.drag.y - 24, 1.15);
  }

  /* 敌人 */
  for (const e of state.enemies) drawEnemy(e);

  /* 贼军城墙（v7.18.7 用户定稿）：与玩家城墙同款镜像——垛口朝下对着战场，渠帅像主公一样站墙头 */
  if (state.foeLord && state.phase === "play") {
    const F = state.foeLord;
    const wy2 = 118;   // 贼墙下缘（受击面朝下）
    const g3 = ctx.createLinearGradient(0, 86, 0, wy2);
    g3.addColorStop(0, "#3a2e1e");
    g3.addColorStop(1, "#5a4832");
    ctx.fillStyle = g3;
    ctx.fillRect(0, 86, W, wy2 - 86);
    ctx.fillStyle = "#6a563c";   // 垛口（朝下）
    for (let x = 0; x < W; x += 40) ctx.fillRect(x + 4, wy2, 24, 8);
    ctx.strokeStyle = "rgba(0,0,0,.25)";   // 砖缝
    ctx.lineWidth = 1;
    for (let x = 24; x < W; x += 48) { ctx.beginPath(); ctx.moveTo(x, 86); ctx.lineTo(x, wy2); ctx.stroke(); }
    ctx.beginPath(); ctx.moveTo(0, wy2 - 12); ctx.lineTo(W, wy2 - 12); ctx.stroke();
    // 渠帅主体：镜像主公画法——站墙正中，图标在上、名字在盘中、全名在下
    const lx = W / 2, ly = 104;
    const hot = state.wave >= 8 && F.drawT <= 10;
    ctx.beginPath(); ctx.arc(lx, ly, 18, 0, Math.PI * 2);
    const gF = ctx.createRadialGradient(lx, ly - 5, 4, lx, ly, 18);
    gF.addColorStop(0, "#7a3a30"); gF.addColorStop(1, "#48201a");
    ctx.fillStyle = gF; ctx.fill();
    ctx.strokeStyle = hot ? `rgba(255,90,90,${0.6 + Math.sin(state.time * 8) * 0.35})` : "rgba(255,170,130,.6)";
    ctx.lineWidth = hot ? 2.5 : 1.5;
    ctx.beginPath(); ctx.arc(lx, ly, 18, 0, Math.PI * 2); ctx.stroke();
    ctx.textAlign = "center";
    ctx.font = "11px sans-serif";
    ctx.fillText(F.def.icon, lx, ly - 20);
    ctx.font = "bold 15px 'Kaiti SC', 'STKaiti', serif";
    ctx.fillStyle = "#ffd2b8";
    ctx.fillText(F.def.name[0], lx, ly + 1);
    ctx.font = "9px sans-serif";
    ctx.fillStyle = "#e8b89a";
    ctx.fillText(F.def.name, lx, ly + 13);
    // 状态小字：盘右——按兵/倒计时/亮牌（镜像主公盘右的普攻小字）
    const nextC = FOE_CARDS[F.deck[Math.min(F.idx, F.deck.length - 1)]];
    const stTxt = state.wave < 8 ? "第8波开手" : hot ? `${Math.ceil(F.drawT)}秒后「${nextC.name}」` : `下一手 ${Math.ceil(F.drawT)}s`;
    ctx.font = "bold 10px sans-serif";
    ctx.fillStyle = hot ? "#ff9a8a" : "#ffc9a8";
    ctx.textAlign = "left";
    ctx.fillText(stTxt, lx + 26, ly + 4);
  }

  /* 死亡链接（诸葛亮）：紫色锁链连着被锁的怪 */
  if (state.deathLink && state.deathLink.members.length >= 2) {
    const ms = state.deathLink.members;
    ctx.save();
    ctx.strokeStyle = `rgba(201,168,255,${0.35 + Math.sin(state.time * 6) * 0.2})`;
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ms.forEach((m, i) => i === 0 ? ctx.moveTo(m.x, m.y) : ctx.lineTo(m.x, m.y));
    ctx.stroke();
    ctx.font = "12px sans-serif";
    ctx.textAlign = "center";
    for (let i = 0; i + 1 < ms.length; i++)
      ctx.fillText("⛓️", (ms[i].x + ms[i + 1].x) / 2, (ms[i].y + ms[i + 1].y) / 2);
    ctx.restore();
  }

  /* 绝技战场效果 */
  // 火堆（陆逊）：圆形火圈
  for (const fp of state.firePits) {
    const alpha = Math.min(0.5, fp.t * 0.35);
    const g = ctx.createRadialGradient(fp.x, fp.y, 6, fp.x, fp.y, fp.r);
    g.addColorStop(0, `rgba(255,150,60,${alpha})`);
    g.addColorStop(1, "rgba(255,110,40,0)");
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(fp.x, fp.y, fp.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = `rgba(255,140,60,${alpha + 0.25})`;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(fp.x, fp.y, fp.r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.font = "15px sans-serif";
    ctx.textAlign = "center";
    for (let i = 0; i < 3; i++) {
      const a = state.time * 2 + i * (Math.PI * 2 / 3) + fp.x;
      ctx.fillText("🔥", fp.x + Math.cos(a) * fp.r * 0.5, fp.y + Math.sin(a) * fp.r * 0.5);
    }
  }
  // 陷阱（魏延）：闪烁的毒圈
  for (const tp of state.traps) {
    const blink = 0.45 + Math.sin(state.time * 5 + tp.x) * 0.3;
    ctx.save();
    ctx.strokeStyle = `rgba(154,223,90,${blink})`;
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 5]);
    ctx.beginPath();
    ctx.arc(tp.x, tp.y, tp.r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.font = "14px sans-serif";
    ctx.textAlign = "center";
    ctx.globalAlpha = clamp(blink + 0.2, 0, 1);
    ctx.fillText("☠️", tp.x, tp.y + 5);
    ctx.restore();
  }
  if (state.blockade) {
    const bl = state.blockade;
    const alpha = Math.min(0.8, bl.t * 0.6) * (0.35 + 0.65 * Math.max(0, bl.hp / bl.hpMax));
    ctx.strokeStyle = `rgba(154,223,90,${alpha})`;
    ctx.lineWidth = 5;
    ctx.setLineDash([16, 10]);
    ctx.lineDashOffset = -state.time * 40;
    ctx.beginPath();
    ctx.moveTo(0, bl.y);
    ctx.lineTo(W, bl.y);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.font = "20px sans-serif";
    ctx.textAlign = "center";
    ctx.globalAlpha = alpha;
    for (let bx = 40; bx < W; bx += 66) ctx.fillText("🚧", bx, bl.y - 8);
    ctx.globalAlpha = 1;
  }
  /* 钉阵短拒马（徐晃）：两排短栅 */
  for (const pa of state.palisades) {
    const alpha = Math.min(0.85, pa.t * 0.55) * (0.35 + 0.65 * Math.max(0, pa.hp / pa.hpMax));
    ctx.strokeStyle = `rgba(232,201,106,${alpha})`;
    ctx.lineWidth = 4;
    ctx.setLineDash([10, 7]);
    ctx.beginPath();
    ctx.moveTo(pa.x - pa.hw, pa.y);
    ctx.lineTo(pa.x + pa.hw, pa.y);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.font = "17px sans-serif";
    ctx.textAlign = "center";
    ctx.globalAlpha = alpha;
    for (let bx = -pa.hw + 26; bx <= pa.hw - 14; bx += 46) ctx.fillText("🚧", pa.x + bx, pa.y - 6);
    ctx.globalAlpha = 1;
  }
  /* 连弩塔（黄月英）：小炮台 + 剩余时间条 */
  for (const tw of state.turrets) {
    ctx.save();
    ctx.translate(tw.x, tw.y);
    ctx.fillStyle = "rgba(0,0,0,.3)";
    ctx.beginPath();
    ctx.ellipse(0, 14, 16, 6, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#3a3024";
    ctx.beginPath();
    ctx.arc(0, 0, 15, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = ELEMENTS[tw.elem].color;
    ctx.lineWidth = 2;
    ctx.shadowColor = ELEMENTS[tw.elem].color;
    ctx.shadowBlur = 6;
    ctx.beginPath();
    ctx.arc(0, 0, 15, 0, Math.PI * 2);
    ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.font = "15px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("🏹", 0, 1);
    ctx.textBaseline = "alphabetic";
    ctx.fillStyle = "rgba(0,0,0,.55)";
    ctx.fillRect(-14, 20, 28, 4);
    ctx.fillStyle = "#ffd24a";
    ctx.fillRect(-14, 20, 28 * clamp(tw.t / (tw.tMax || 8), 0, 1), 4);
    ctx.restore();
  }

  /* 冲锋骑手 */
  // v7.0 白马义从：主公下场实体——白马+主公字+无敌金圈
  if (state.baima && state.baima.t > 0) {
    const B = state.baima;
    ctx.save();
    ctx.translate(B.x, B.y);
    ctx.beginPath(); ctx.arc(0, 0, 22, 0, Math.PI * 2);
    ctx.strokeStyle = "#ffd24a";
    ctx.lineWidth = 2;
    ctx.shadowColor = "#ffd24a";
    ctx.shadowBlur = 8 + Math.sin(state.time * 8) * 4;
    ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.font = "26px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("🐎", 0, 2);
    const rl8 = rulerOf();
    ctx.font = "bold 13px 'Kaiti SC', 'STKaiti', serif";
    ctx.fillStyle = "#ffe8b0";
    ctx.strokeStyle = "rgba(0,0,0,.7)";
    ctx.lineWidth = 3;
    ctx.strokeText(rl8 ? rl8.name[0] : "主", 13, -13);
    ctx.fillText(rl8 ? rl8.name[0] : "主", 13, -13);
    ctx.textBaseline = "alphabetic";
    ctx.restore();
  }
  for (const rd of state.riders) {
    ctx.save();
    ctx.translate(rd.x, rd.y);
    // 冲锋走廊余辉
    ctx.globalAlpha = 0.18;
    ctx.fillStyle = rd.color;
    ctx.fillRect(-rd.w, -6, rd.w * 2, 46);
    ctx.globalAlpha = 1;
    // 马 + 将旗（孙策大招=巨马；滚石坡=巨石）
    if (rd.boulder) {
      ctx.font = "34px sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("🪨", 0, 0);
      ctx.textBaseline = "alphabetic";
    } else {
    ctx.font = rd.mega ? "40px sans-serif" : "26px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("🐎", 0, 0);
    ctx.font = `bold ${rd.mega ? 18 : 13}px 'Kaiti SC', 'STKaiti', serif`;
    ctx.fillStyle = "#ffe8b0";
    ctx.strokeStyle = "rgba(0,0,0,.7)";
    ctx.lineWidth = 3;
    ctx.strokeText(rd.char, 12, -12);
    ctx.fillText(rd.char, 12, -12);
    }
    // 速度线
    ctx.strokeStyle = rd.color;
    ctx.globalAlpha = 0.6;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-10, 14); ctx.lineTo(-10, 30);
    ctx.moveTo(10, 14); ctx.lineTo(10, 34);
    ctx.stroke();
    ctx.restore();
    ctx.textBaseline = "alphabetic";
  }

  /* 近战斩击特效 */
  for (const sl of state.slashes) {
    const a = clamp(sl.life / sl.maxLife, 0, 1);
    ctx.save();
    ctx.globalAlpha = a * 0.85;
    ctx.strokeStyle = sl.color;
    ctx.lineWidth = sl.w * a + 1;
    ctx.lineCap = "round";
    ctx.shadowColor = sl.color;
    ctx.shadowBlur = 6;
    ctx.beginPath();
    // 斩线：从武将向目标收缩
    const t0 = 1 - a;   // 0→1 随时间
    ctx.moveTo(sl.x1 + (sl.x2 - sl.x1) * t0 * 0.6, sl.y1 + (sl.y2 - sl.y1) * t0 * 0.6);
    ctx.lineTo(sl.x2, sl.y2);
    ctx.stroke();
    ctx.restore();
  }

  /* 水波增益环（辅兵） */
  for (const rp of state.ripples) {
    const fade = clamp(1 - rp.r / rp.max, 0, 1) * 0.7 + 0.12;
    ctx.save();
    ctx.strokeStyle = rp.color;
    for (let i = 0; i < 3; i++) {
      const rr = rp.r - i * 16;
      if (rr <= 3) continue;
      ctx.globalAlpha = fade * (1 - i * 0.28);
      ctx.lineWidth = 2.6 - i * 0.7;
      ctx.beginPath();
      ctx.arc(rp.x, rp.y, Math.min(rr, rp.max), 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.restore();
  }

  /* 冲击波环（曹仁） */
  for (const sk of state.shocks) {
    const a = clamp(1 - sk.r / sk.max, 0, 1);
    ctx.save();
    ctx.strokeStyle = sk.color;
    ctx.globalAlpha = 0.25 + a * 0.6;
    ctx.lineWidth = 3 + 7 * a;
    ctx.shadowColor = sk.color;
    ctx.shadowBlur = 12;
    ctx.beginPath();
    ctx.arc(sk.x, sk.y, sk.r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  /* 射线（黄忠狙击/关羽竖劈/周瑜横线/马超分叉等） */
  for (const bm of state.beams) {
    const a = clamp(bm.t / 0.3, 0, 1);
    ctx.save();
    ctx.globalAlpha = Math.min(1, a) * 0.9;
    ctx.strokeStyle = bm.color;
    ctx.lineWidth = (2 + a * 4) * (bm.w || 1);
    ctx.lineCap = "round";
    ctx.shadowColor = bm.color;
    ctx.shadowBlur = 10;
    ctx.beginPath();
    ctx.moveTo(bm.x1, bm.y1);
    ctx.lineTo(bm.x2, bm.y2);
    ctx.stroke();
    ctx.restore();
  }

  /* 抛物线投掷物：敌方投石（带落点警示圈）+ 我方火罐 */
  const lobPos = lb => {
    const k = clamp(lb.t / lb.dur, 0, 1);
    return { x: lb.x0 + (lb.x1 - lb.x0) * k,
             y: lb.y0 + (lb.y1 - lb.y0) * k - Math.sin(Math.PI * k) * 110 };
  };
  for (const lb of state.elobs) {
    const k = clamp(lb.t / lb.dur, 0, 1);
    ctx.save();
    ctx.strokeStyle = `rgba(255,80,60,${0.3 + k * 0.55})`;
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 5]);
    ctx.beginPath();
    ctx.arc(lb.x1, lb.y1, 70 * (0.45 + k * 0.55), 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.restore();
    const q = lobPos(lb);
    ctx.font = "18px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("💣", q.x, q.y);
  }
  for (const lb of state.lobs) {
    const q = lobPos(lb);
    ctx.font = "18px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(lb.icon, q.x, q.y);
  }
  /* 我方带伤害投掷（甘宁炸弹/陆逊火罐）：抛物线 */
  for (const fl of state.flobs) {
    const q = lobPos(fl);
    ctx.font = "18px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(fl.icon, q.x, q.y);
  }

  /* 追踪弹（姜维）：火色光点+拖尾 */
  for (const hm of state.homers) {
    ctx.save();
    ctx.strokeStyle = "rgba(255,140,60,.6)";
    ctx.lineWidth = 2.5;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(hm.x - hm.vx * 0.06, hm.y - hm.vy * 0.06);
    ctx.lineTo(hm.x, hm.y);
    ctx.stroke();
    ctx.shadowColor = hm.color;
    ctx.shadowBlur = 8;
    ctx.fillStyle = hm.color;
    ctx.beginPath();
    ctx.arc(hm.x, hm.y, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(255,255,220,.9)";
    ctx.beginPath();
    ctx.arc(hm.x, hm.y, 2.2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  /* 敌方冷箭：红色拖尾光点 */
  for (const eb of state.ebullets) {
    ctx.save();
    ctx.strokeStyle = "rgba(255,90,74,.55)";
    ctx.lineWidth = 2.5;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(eb.x - (eb.vx || 0) * 0.07, eb.y - (eb.vy || 0) * 0.07);
    ctx.lineTo(eb.x, eb.y);
    ctx.stroke();
    ctx.shadowColor = "#ff5a4a";
    ctx.shadowBlur = 8;
    ctx.fillStyle = "#ff5a4a";
    ctx.beginPath();
    ctx.arc(eb.x, eb.y, 4.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,.85)";
    ctx.beginPath();
    ctx.arc(eb.x, eb.y, 2, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  /* 子弹 */
  for (const b of state.bullets) {
    if (b.icon) {   // 吕布画戟等：旋转的兵器图标
      ctx.save();
      ctx.translate(b.x, b.y);
      ctx.rotate(state.time * 10);
      ctx.font = `${Math.round(b.r * 2.2)}px sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.shadowColor = b.color;
      ctx.shadowBlur = 12;
      ctx.fillText(b.icon, 0, 0);
      ctx.restore();
      ctx.textBaseline = "alphabetic";
      continue;
    }
    ctx.save();
    ctx.shadowColor = b.color;
    ctx.shadowBlur = 8;
    ctx.fillStyle = b.color;
    ctx.beginPath();
    ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "rgba(255,255,255,.85)";
    ctx.beginPath();
    ctx.arc(b.x, b.y, b.r * 0.45, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  /* 粒子 */
  for (const p of state.particles) {
    ctx.globalAlpha = clamp(p.life / p.maxLife, 0, 1);
    ctx.fillStyle = p.color;
    ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
  }
  ctx.globalAlpha = 1;

  /* 飘字 */
  for (const f of state.floaters) {
    ctx.globalAlpha = clamp(f.life, 0, 1);
    ctx.font = `bold ${f.size}px sans-serif`;
    ctx.textAlign = "center";
    ctx.strokeStyle = "rgba(0,0,0,.6)";
    ctx.lineWidth = 3;
    ctx.strokeText(f.text, f.x, f.y);
    ctx.fillStyle = f.color;
    ctx.fillText(f.text, f.x, f.y);
  }
  ctx.globalAlpha = 1;

  /* 天威雷光：全屏闪白 */
  if (state.flash > 0) {
    ctx.fillStyle = `rgba(255,246,200,${Math.min(0.55, state.flash * 0.55)})`;
    ctx.fillRect(0, 0, W, H);
  }

  /* 歌舞升平：三秒美人歌舞入场演出（此后进入不早朝——HUD 仍在其上） */
  if (state.dance > 0) {
    const dIn = Math.min(1, (3 - state.dance) * 3, state.dance * 2);   // 淡入淡出
    ctx.globalAlpha = dIn * 0.55;
    ctx.fillStyle = "rgba(70,12,40,1)";
    ctx.fillRect(0, 0, W, H);
    ctx.globalAlpha = dIn;
    // 三位美人：中间大两边小，各自摇曳
    ctx.textAlign = "center";
    const dy0 = H * 0.42;
    for (const [ox, sc, ph] of [[-120, 52, 1.1], [0, 96, 0], [120, 52, 2.3]]) {
      const sway = Math.sin(state.time * 3 + ph) * 12;
      ctx.font = `${sc}px sans-serif`;
      ctx.fillText("💃", W / 2 + ox + sway, dy0 + Math.sin(state.time * 5 + ph) * 6);
    }
    // 花瓣雨：位置由序号哈希+时间推，零分配
    ctx.font = "18px sans-serif";
    for (let i = 0; i < 12; i++) {
      const fx = ((i * 97 + 41) % W + Math.sin(state.time * 1.5 + i) * 30 + W) % W;
      const fy = ((i * 173 + state.time * 90) % (H + 40)) - 20;
      ctx.fillText(i % 3 ? "🌸" : "🎵", fx, fy);
    }
    ctx.font = "bold 20px 'Kaiti SC', 'STKaiti', serif";
    ctx.fillStyle = "#ffc8e0";
    ctx.fillText("此间乐，不思蜀……", W / 2, dy0 + 96);
    ctx.font = "12px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,.75)";
    ctx.fillText("（全军攻击+30%；点击屏幕可重回朝堂）", W / 2, dy0 + 118);
    ctx.globalAlpha = 1;
  }

  drawHUD();
  drawLordBar();
  drawCardArea();
  drawUltConfirm();
  drawInspect();
  if (lordPop) drawLordPop();
  ctx.restore();

  if (state.phase === "title") drawTitle();
  if (state.phase === "pickDiff") drawDiffPick();
  if (state.phase === "pickLord") drawPickLord();
  if (state.phase === "pickStart" || state.phase === "play") drawFieldBanner();
  if (state.phase === "over") drawEnd(false);
  if (state.phase === "win") drawEnd(true);
  if (showShop) drawShopOverlay();
  if (showTech) drawTechOverlay();
  if (showAch) drawAchOverlay();
  if (showVisit) drawVisitOverlay();
  if (showBag) drawBagOverlay();
  // 无感热更提示（v7.18.8）：刷新回来顶部一条绿横幅，6秒自干——所有页面之上
  if (state.updateToastUntil && Date.now() < state.updateToastUntil) {
    const txtU = `✨ 已自动更新到 v${GAME_VERSION}`;
    ctx.font = "bold 13px sans-serif";
    const twU = ctx.measureText(txtU).width + 26;
    ctx.fillStyle = "rgba(20,40,16,.92)";
    roundRect(W / 2 - twU / 2, 8, twU, 28, 14);
    ctx.fill();
    ctx.strokeStyle = "rgba(154,223,90,.8)";
    ctx.lineWidth = 1.5;
    roundRect(W / 2 - twU / 2, 8, twU, 28, 14);
    ctx.stroke();
    ctx.fillStyle = "#b8ef8a";
    ctx.textAlign = "center";
    ctx.fillText(txtU, W / 2, 27);
  }
}

function drawUnit(u, x, y, s = 1, hint = false, gr = null, gc = null) {
  const t = u.type;
  const col = t.cls === "granary" ? "#e8c86a" : t.cls === "egg" ? "#c9a8ff"
    : t.cls === "dragon" ? "#8ad2ff" : RARITY[heroRarity(t.id)].color;   // 光环圈=品质色（兵种/属性看角标，颜色留给品质）；粮仓稻草金/蛋紫/龙青
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(s, s);
  // 底座
  ctx.fillStyle = "rgba(0,0,0,.3)";
  ctx.beginPath();
  ctx.ellipse(0, 22, 22, 8, 0, 0, Math.PI * 2);
  ctx.fill();
  // 桃园义全军金身：金光护体圈（v7.3.0 全员）
  if (state.taoyuanT > 0 && !["granary", "egg"].includes(t.cls)) {
    ctx.strokeStyle = `rgba(255,210,120,${0.6 + Math.sin(state.time * 8) * 0.3})`;
    ctx.lineWidth = 3;
    ctx.shadowColor = "#ffd278";
    ctx.shadowBlur = 10;
    ctx.beginPath(); ctx.arc(0, 0, 30, 0, Math.PI * 2); ctx.stroke();
    ctx.shadowBlur = 0;
  }
  // 抗性警示：下波精英集中抗此将属性——红圈+"抗"角标提醒别指望他
  if (hint) {
    ctx.strokeStyle = "rgba(255,90,90,.75)";
    ctx.lineWidth = 3;
    ctx.setLineDash([5, 5]);
    ctx.beginPath();
    ctx.arc(0, 0, 28, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.font = "bold 10px sans-serif";
    ctx.fillStyle = "#ff8a8a";
    ctx.strokeStyle = "rgba(0,0,0,.7)";
    ctx.lineWidth = 2.5;
    ctx.textAlign = "center";
    ctx.strokeText("打不动", 22, -20);
    ctx.fillText("打不动", 22, -20);
  }
  // 兵种光环
  ctx.strokeStyle = col;
  ctx.lineWidth = 3;
  ctx.globalAlpha = 0.85;
  ctx.beginPath();
  ctx.arc(0, 0, 25, 0, Math.PI * 2);
  ctx.stroke();
  ctx.globalAlpha = 1;
  // 羁绊生效：细金环呼吸 + 🔗角标（点武将面板能看是哪条羁绊）
  if (state.bondSet?.size && BONDS.some(bd => state.bondSet.has(bd.id) && bd.members.includes(t.id))) {
    ctx.strokeStyle = "rgba(255,210,74,.85)";
    ctx.lineWidth = 1.6;
    ctx.globalAlpha = 0.55 + Math.sin(state.time * 3) * 0.3;
    ctx.beginPath();
    ctx.arc(0, 0, 30, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.font = "11px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("🔗", -22, 24);
  }
  // 本期神将：👼角标常显在圆盘左上——从出征卡、练兵卡到战场一路认得出他封神（2026-07-10 用户反馈）
  if (!["granary", "egg", "dragon"].includes(t.cls) && isShen(t.id)) {
    ctx.font = "12px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("👼", -22, -18);
  }
  // 兀突骨毒雾：常显毒雾范围圈（大招期变大）——看得见的"这一圈都在掉血"
  if (t.id === "wutugu" && gr != null) {
    const aR = 90 * ((u.ultT || 0) > 0 ? 2.2 : 1);
    ctx.strokeStyle = "rgba(154,223,90,.4)";
    ctx.fillStyle = "rgba(154,223,90,.06)";
    ctx.lineWidth = 1.5;
    ctx.setLineDash([4, 6]);
    ctx.beginPath();
    ctx.arc(0, -10, aR, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.setLineDash([]);
  }
  // 绝技CD环：类别色，从顶部顺时针填充；转满后待条件触发时呼吸闪（粮仓没大招，不画）
  if (ULTS[u.type.id]) {
    const ult = ULTS[u.type.id];
    const utCol = ULT_TYPES[ult.type].color;
    const cdMax = ultCdMax(u);
    const prog = 1 - clamp(u.ultCd / cdMax, 0, 1);
    if (prog >= 1) {
      ctx.strokeStyle = utCol;
      ctx.lineWidth = 4;
      ctx.shadowColor = utCol;
      ctx.shadowBlur = 8 + Math.sin(state.time * 6) * 4;
      ctx.beginPath();
      ctx.arc(0, 0, 30, 0, Math.PI * 2);
      ctx.stroke();
      ctx.shadowBlur = 0;
    } else if (prog > 0.02) {
      ctx.strokeStyle = utCol;
      ctx.globalAlpha = 0.65;
      ctx.lineWidth = 3.5;
      ctx.beginPath();
      ctx.arc(0, 0, 30, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * prog);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }
  // 绝技增益中
  if (u.buffT > 0) {
    ctx.font = "13px sans-serif";
    ctx.fillText("⚡", -18, -16);
  }
  // 水波/全军增益中：头顶小图标（多个 buff 并排错开；🌾全军加攻 🌬️全军提速也挂这排）
  {
    const icons = [];
    if (u.rbuffs) {
      if (u.rbuffs.heal > 0) icons.push("💗");
      if (u.rbuffs.haste > 0) icons.push("⚡");
      if (u.rbuffs.dmg > 0) icons.push("⚔️");
      if (u.rbuffs.crit > 0) icons.push("🎯");
      if (u.rbuffs.cdr > 0) icons.push("🕐");
      if (u.rbuffs.farm > 0) icons.push("🌾");
    }
    if (state.armyBuff && unitAttacks(u.type)) icons.push("🌾");
    if (state.armyHaste && u.type.cls !== "shield") icons.push("🌬️");
    if (icons.length) {
      ctx.font = "12px sans-serif";
      icons.forEach((ic, i) => ctx.fillText(ic, (i - (icons.length - 1) / 2) * 14, -33));
    }
  }
  // 周泰·反伤翻倍生效中：一圈冰刺转着扎（看得见的"现在扎手"）
  if (u.reflectT > 0) {
    ctx.save();
    ctx.strokeStyle = "#bfe8ff";
    ctx.lineWidth = 2.5;
    ctx.shadowColor = "#6ad2ff";
    ctx.shadowBlur = 8;
    for (let i = 0; i < 8; i++) {
      const a = state.time * 2.5 + i * Math.PI / 4;
      ctx.beginPath();
      ctx.moveTo(Math.cos(a) * 24, Math.sin(a) * 24);
      ctx.lineTo(Math.cos(a) * 31, Math.sin(a) * 31);
      ctx.stroke();
    }
    ctx.restore();
  }
  // 盾护角标：相邻有盾兵庇护（受伤-15%）
  if (gr != null && u.type.cls !== "shield" && hasAdjacentShield(gr, gc)) {
    ctx.font = "11px sans-serif";
    ctx.globalAlpha = 0.9;
    ctx.fillText("🛡️", -21, -28);
    ctx.globalAlpha = 1;
  }
  // 被封印
  if (u.sealedT > 0) {
    ctx.globalAlpha = 0.9;
    ctx.font = "26px sans-serif";
    ctx.fillText("🌀", 0, -2);
    ctx.globalAlpha = 1;
  }
  // 将旗圆盘 + 全名
  ctx.fillStyle = "#3a3024";
  ctx.beginPath();
  ctx.arc(0, 0, 21, 0, Math.PI * 2);
  ctx.fill();
  drawNameDisc(t.cls === "egg" ? "蛋" : t.cls === "dragon" ? "龍" : t.name, 21, 0, 1, heroLv(t.id) >= MILE_STAR2);
  // 盾兵皮肤（v7.18.6 用户点名辨识度）：塔盾立在圆盘上缘、面朝敌来的方向——远看就是一堵墙
  if (t.cls === "shield") {
    const gsh = ctx.createLinearGradient(0, -30, 0, -4);
    gsh.addColorStop(0, "#aeb8c2");
    gsh.addColorStop(0.45, "#77828e");
    gsh.addColorStop(1, "#454f5a");
    ctx.fillStyle = gsh;
    ctx.beginPath();
    ctx.moveTo(-16, -29);
    ctx.quadraticCurveTo(0, -34, 16, -29);   // 盾顶微拱
    ctx.lineTo(16, -13);
    ctx.quadraticCurveTo(16, -4, 0, -2);     // 下收护住圆盘上缘
    ctx.quadraticCurveTo(-16, -4, -16, -13);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = "#252c34";
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.strokeStyle = "rgba(30,36,44,.55)";   // 中脊
    ctx.lineWidth = 1.2;
    ctx.beginPath(); ctx.moveTo(0, -31); ctx.lineTo(0, -3); ctx.stroke();
    ctx.fillStyle = "#cfd8e0";                 // 铆钉
    for (const rv of [[-11, -25], [11, -25], [-11, -11], [11, -11]]) {
      ctx.beginPath(); ctx.arc(rv[0], rv[1], 1.6, 0, Math.PI * 2); ctx.fill();
    }
    ctx.fillStyle = ELEMENTS[t.elem].color;    // 盾心徽：属性色圆钉
    ctx.beginPath(); ctx.arc(0, -17, 4.5, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = "#20262e";
    ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.arc(0, -17, 4.5, 0, Math.PI * 2); ctx.stroke();
  }
  // 满阶龙蛋：呼吸金圈——就差一张觉醒卡了；应龙：常显青辉
  if (t.cls === "egg" && u.level >= EGG_MAX) {
    ctx.strokeStyle = "#ffd24a";
    ctx.lineWidth = 3.5;
    ctx.shadowColor = "#ffd24a";
    ctx.shadowBlur = 8 + Math.sin(state.time * 5) * 5;
    ctx.beginPath();
    ctx.arc(0, 0, 29, 0, Math.PI * 2);
    ctx.stroke();
    ctx.shadowBlur = 0;
  } else if (t.cls === "dragon") {
    ctx.strokeStyle = "#8ad2ff";
    ctx.lineWidth = 2.5;
    ctx.shadowColor = "#8ad2ff";
    ctx.shadowBlur = 10;
    ctx.beginPath();
    ctx.arc(0, 0, 28, 0, Math.PI * 2);
    ctx.stroke();
    ctx.shadowBlur = 0;
  }
  // 兵种角标（右上，深底圆盘+描边，清晰可辨）
  ctx.fillStyle = "rgba(20,14,6,.92)";
  ctx.beginPath();
  ctx.arc(19, -18, 11, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = CLASSES[t.cls].color;
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(19, -18, 11, 0, Math.PI * 2);
  ctx.stroke();
  ctx.font = "13px sans-serif";
  ctx.fillText(CLASSES[t.cls].icon, 19, -17);
  // 三角属性角标（左下，v6.0 用户点名：属性人人有、图标=猜拳手势直觉克制）——物件不画
  if (!["granary", "egg", "dragon"].includes(t.cls)) {
    ctx.fillStyle = "rgba(20,14,6,.92)";
    ctx.beginPath();
    ctx.arc(-19, 18, 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = ELEMENTS[t.elem].color;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.arc(-19, 18, 10, 0, Math.PI * 2);
    ctx.stroke();
    ctx.font = "11px sans-serif";
    ctx.fillText(ELEMENTS[t.elem].icon, -19, 19);
  }
  // 等级星（应龙没有星：觉醒即完全体，不再显示进度）
  if (t.cls !== "dragon") {
    const rb = heroRb(u.type.id);
    const rbc = REBIRTH_COLOR[Math.min(rb, REBIRTH_COLOR.length - 1)];   // 转生将（局外N转）的星星换色：0转金/1转品红/2转紫/3转青
    ctx.font = "bold 12px sans-serif";
    const rw = rb > 0 ? ctx.measureText(` ${rb}转`).width : 0;
    const sw = drawStarRow(-rw / 2, 27, u.level, 12, rbc, { outline: true });
    if (rb > 0) {
      ctx.font = "bold 12px sans-serif";
      ctx.textAlign = "left";
      ctx.strokeStyle = "rgba(0,0,0,.7)";
      ctx.lineWidth = 3;
      ctx.strokeText(` ${rb}转`, -rw / 2 + sw / 2, 27);
      ctx.fillStyle = rbc;
      ctx.fillText(` ${rb}转`, -rw / 2 + sw / 2, 27);
      ctx.textAlign = "center";
    }
  }
  // （枪阵加成不再画文字角标：与星级重叠；绿色呼吸连线常显 + 面板"现在："行已足够）
  // 受击闪红
  if (u.hurtFlash > 0) {
    ctx.globalAlpha = u.hurtFlash * 0.45;
    ctx.fillStyle = "#ff4a3a";
    ctx.beginPath();
    ctx.arc(0, 0, 23, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }
  // 血条（受损才显示）
  if (u.hp < u.hpMax) {
    const frac = clamp(u.hp / u.hpMax, 0, 1);
    ctx.fillStyle = "rgba(0,0,0,.6)";
    ctx.fillRect(-20, 31, 40, 5);
    ctx.fillStyle = frac > 0.5 ? "#7aff5a" : frac > 0.25 ? "#ffd24a" : "#ff5a3a";
    ctx.fillRect(-20, 31, 40 * frac, 5);
  }
  ctx.restore();
  ctx.textBaseline = "alphabetic";
}

function drawEnemy(e) {
  ctx.save();
  ctx.translate(e.x, e.y);
  const squish = 1 + Math.sin(e.wob * 2) * 0.06;
  ctx.scale(squish, 2 - squish);
  // 黄巾兵：土黄团子
  const col = e.hitFlash > 0.5 ? "#ffffff" : (e.boss ? "#8a4a2a" : "#a8923a");
  ctx.fillStyle = col;
  ctx.beginPath();
  ctx.arc(0, 0, e.r, 0, Math.PI * 2);
  ctx.fill();
  // 头巾
  ctx.fillStyle = e.boss ? "#d4a017" : "#e8c020";
  ctx.beginPath();
  ctx.arc(0, 0, e.r, Math.PI * 1.15, Math.PI * 1.85);
  ctx.lineTo(0, -e.r * 0.35);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = "rgba(255,255,255,.14)";
  ctx.beginPath();
  ctx.arc(-e.r * 0.3, -e.r * 0.3, e.r * 0.4, 0, Math.PI * 2);
  ctx.fill();
  // 边框：三角属性色（v6.0）——贼是什么系一眼可辨
  ctx.strokeStyle = e.tri && ELEMENTS[e.tri] ? ELEMENTS[e.tri].color : "rgba(60,50,30,.7)";
  ctx.lineWidth = e.tri ? 3 : 1.5;
  ctx.beginPath();
  ctx.arc(0, 0, e.r, 0, Math.PI * 2);
  ctx.stroke();
  // 名号字：小怪单字，特种/精英/贼首两三个字
  const fcs = [...e.face].length;
  const ffs = fcs >= 3 ? e.r * 0.58 : fcs === 2 ? e.r * 0.74 : e.r * 1.0;
  ctx.font = `bold ${Math.round(ffs)}px sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.strokeStyle = "rgba(0,0,0,.65)";
  ctx.lineWidth = 3;
  ctx.strokeText(e.face, 0, 2);
  ctx.fillStyle = e.boss ? "#ffd24a" : "#fff";
  ctx.fillText(e.face, 0, 2);
  // 状态标记
  if (e.slowT > 0) { ctx.font = "12px sans-serif"; ctx.fillText("🐢", -e.r * 0.8, -e.r * 0.8); }
  if (e.burnT > 0) { ctx.font = "12px sans-serif"; ctx.fillText("🔥", 0, -e.r * 1.1); }
  if (e.stunT > 0) { ctx.font = "13px sans-serif"; ctx.fillText("💫", 0, -e.r * 1.35); }
  else if (e.sleepT > 0) { ctx.font = "13px sans-serif"; ctx.fillText("💤", 0, -e.r * 1.35); }
  else if (e.fearT > 0) { ctx.font = "13px sans-serif"; ctx.fillText("😨", 0, -e.r * 1.35); }
  if (e.silencedT > 0) { ctx.font = "13px sans-serif"; ctx.fillText("🤐", e.r * 0.8, -e.r * 0.8); }
  if (e.charmT > 0) { ctx.font = "12px sans-serif"; ctx.fillText("💘", e.r * 0.8, e.r * 0.8); }
  if (e.turncoatT > 0) { ctx.font = "13px sans-serif"; ctx.fillText("💔", 0, -e.r * 1.35); }
  if (e.duelT > 0) { ctx.font = "13px sans-serif"; ctx.fillText("⚔️", 0, -e.r * 1.35); }
  // 词缀标记
  if (e.affix) {
    ctx.font = "13px sans-serif";
    ctx.fillText(AFFIXES[e.affix].icon, -e.r * 0.8, e.r * 0.8);
  }
  // 特种兵光环示意
  if (e.special === "healer" || e.special === "banner" || e.special === "warden") {
    ctx.strokeStyle = e.special === "healer" ? "rgba(138,255,154,.35)" : e.special === "warden" ? "rgba(255,80,80,.4)" : "rgba(255,138,90,.35)";
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 6]);
    ctx.beginPath();
    ctx.arc(0, 0, e.special === "healer" ? 110 : e.special === "warden" ? 130 : 120, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
  }
  // 铁盾光罩
  if (e.shield > 0) {
    ctx.strokeStyle = "rgba(138,210,255,.8)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(0, 0, e.r + 5, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.restore();
  ctx.textBaseline = "alphabetic";
  // 血条
  const bw = e.r * 2;
  ctx.fillStyle = "rgba(0,0,0,.55)";
  ctx.fillRect(e.x - bw / 2, e.y - e.r - 10, bw, 5);
  ctx.fillStyle = e.boss ? "#ff7a4a" : "#7aff5a";
  ctx.fillRect(e.x - bw / 2, e.y - e.r - 10, bw * clamp(e.hp / e.hpMax, 0, 1), 5);
  // 护盾条
  if (e.shieldMax > 0 && e.shield > 0) {
    ctx.fillStyle = "#8ad2ff";
    ctx.fillRect(e.x - bw / 2, e.y - e.r - 15, bw * clamp(e.shield / e.shieldMax, 0, 1), 3);
  }
  // 属性小标（血条上方，v6.0）：贼的三角属性图标
  if (e.tri && ELEMENTS[e.tri]) {
    ctx.font = `${Math.max(9, Math.round(e.r * 0.55))}px sans-serif`;
    ctx.textAlign = "center";
    ctx.fillText(ELEMENTS[e.tri].icon, e.x, e.y - e.r - (e.shieldMax > 0 ? 20 : 15));
  }
  // BOSS 名号
  if (e.boss) {
    ctx.font = "bold 14px sans-serif";
    ctx.textAlign = "center";
    ctx.strokeStyle = "rgba(0,0,0,.7)";
    ctx.lineWidth = 3;
    ctx.strokeText(e.bossName, e.x, e.y - e.r - 18);
    ctx.fillStyle = "#ffd24a";
    ctx.fillText(e.bossName, e.x, e.y - e.r - 18);
  }
}

/* ---------- HUD ---------- */
const BTN = {
  // v7.13：砍掉调速钮（固定2倍速）和局内帮助钮——右侧只剩音效/退出，下面的主公名牌/技槽整体上移
  mute:  { x: W - 78, y: 102, w: 64, h: 32 },
  quit:  { x: W - 78, y: 140, w: 64, h: 32 },   // 到 172 收住；178起=主公名牌，208起=主公技槽
  dmg:   { x: W - 78, y: 456, w: 64, h: 30 },   // 📊输出统计开关（v7.17.5）：贴阵地上沿右侧，避开名牌/技槽
};

/* 实时输出面板（v7.17.5 用户点名：验证各种搭配的输出能力、直观观测战力差）——
   📊钮开关；按累计排序给占比条，右列近10秒秒伤——"谁现在在干活"和"整局谁是主力"一眼分开 */
function drawDmgPanel() {
  const es = Object.entries(state.dmgBook || {}).map(([k, b]) => ({ k, ...b }))
    .filter(b => b.total > 0).sort((a, b) => b.total - a.total);
  // 零输出的在场武将也列出来——多半是"够不着"，标出来免得被当成统计漏账
  for (const u of allUnits()) {
    if (["shield", "egg", "granary", "support"].includes(u.type.cls)) continue;
    if (es.some(b => b.k === u.type.id)) continue;
    es.push({ k: u.type.id, icon: "", name: u.type.name, total: state.dmgBook?.[u.type.id]?.total || 0, log: [] });
  }
  const x0 = 85, w = 310, rows = Math.min(10, es.length);
  const h = 40 + rows * 17 + (es.length > rows ? 13 : 0);
  const y0 = 244;
  ctx.fillStyle = "rgba(12,9,4,.84)";
  roundRect(x0, y0, w, h, 10);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,210,74,.35)";
  ctx.lineWidth = 1;
  roundRect(x0, y0, w, h, 10);
  ctx.stroke();
  const sum = es.reduce((s, b) => s + b.total, 0);
  ctx.textAlign = "left"; ctx.font = "bold 12.5px sans-serif"; ctx.fillStyle = "#ffd24a";
  ctx.fillText(`📊 本局输出 共${fmtBigN(sum || 0)}`, x0 + 12, y0 + 18);
  ctx.textAlign = "right"; ctx.font = "10px sans-serif"; ctx.fillStyle = "#8a7d5a";
  ctx.fillText("近10秒/秒 · 累计", x0 + w - 12, y0 + 18);
  if (!rows) {
    ctx.textAlign = "center"; ctx.fillStyle = "#8a7d5a"; ctx.font = "11px sans-serif";
    ctx.fillText("还没开张——打起来就有账", x0 + w / 2, y0 + 34);
    return;
  }
  const sec = Math.floor(state.time || 0);
  for (let i = 0; i < rows; i++) {
    const b = es[i], y = y0 + 28 + i * 17;
    const dpsWin = Math.min(10, Math.max(1, state.time || 1));
    const dps = b.log.reduce((s2, pr) => pr[0] >= sec - 10 ? s2 + pr[1] : s2, 0) / dpsWin;
    const sh = b.total / (sum || 1);
    ctx.textAlign = "left"; ctx.font = "bold 11px sans-serif";
    ctx.fillStyle = i === 0 ? "#ffd24a" : "#e8dcc0";
    ctx.fillText(`${b.icon || ""}${b.name}`, x0 + 12, y + 11);
    ctx.fillStyle = "rgba(122,150,90,.32)";
    ctx.fillRect(x0 + 72, y + 2, Math.max(2, 88 * sh), 11);
    ctx.fillStyle = "#9adf5a"; ctx.font = "10px sans-serif";
    ctx.fillText(`${Math.round(sh * 100)}%`, x0 + 75, y + 11);
    // 在场却打不出伤害的武将：射程内没敌人 → 标"够不着"（应龙全场咬、不算）
    let idle = false;
    if (!(dps > 0) && !b.k.startsWith("@") && state.enemies.some(e => !e.dead && e.y > -10)) {
      const uu = allUnits().filter(x => x.type.id === b.k && x.type.cls !== "dragon");
      idle = uu.length > 0 && uu.every(x => !(x._inRange > 0));
    }
    ctx.textAlign = "right"; ctx.font = "10.5px sans-serif";
    ctx.fillStyle = idle ? "#ff9a7a" : "#c9b69a";
    ctx.fillText(idle ? `够不着 · ${fmtBigN(b.total)}` : `${fmtBigN(Math.round(dps))}/秒 · ${fmtBigN(b.total)}`, x0 + w - 12, y + 11);
  }
  if (es.length > rows) {
    ctx.textAlign = "center"; ctx.fillStyle = "#8a7d5a"; ctx.font = "10px sans-serif";
    ctx.fillText(`…还有${es.length - rows}路（占比更小）`, x0 + w / 2, y0 + h - 5);
  }
}

function drawHUD() {
  /* 顶栏 */
  ctx.fillStyle = "rgba(0,0,0,.35)";
  roundRect(10, 10, W - 20, 84, 12);
  ctx.fill();

  ctx.textAlign = "left";
  ctx.font = "bold 16px sans-serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`Lv.${state.level}`, 24, 34);
  ctx.fillStyle = "#e8c86a";
  ctx.fillText(`⚔️ 第 ${Math.max(state.wave, 1)} 波`, 24, 60);
  // 难度徽章 + 地利徽章
  ctx.font = "bold 12px sans-serif";
  ctx.fillStyle = state.diff.color;
  ctx.fillText(`${state.diff.icon}${state.diff.tag || state.diff.name}`, 88, 34);

  // 击杀进度条
  const px = 130, pw = W - 150, py = 18;
  ctx.font = "bold 13px sans-serif";
  ctx.fillStyle = "#fff";
  ctx.fillText(`击破 ${state.kills} / ${state.endless ? "∞" : state.killTarget}`, px, py + 10);
  ctx.fillStyle = "rgba(255,255,255,.15)";
  roundRect(px, py + 16, pw, 10, 5);
  ctx.fill();
  ctx.fillStyle = "#9aff5a";
  roundRect(px, py + 16, pw * clamp(state.kills / state.killTarget, 0, 1), 10, 5);
  ctx.fill();

  // 经验条
  ctx.font = "bold 12px sans-serif";
  ctx.fillStyle = "#8ad2ff";
  ctx.fillText("EXP", px, py + 44);
  ctx.fillStyle = "rgba(255,255,255,.15)";
  roundRect(px + 34, py + 35, pw - 34, 10, 5);
  ctx.fill();
  ctx.fillStyle = "#4ab0ff";
  roundRect(px + 34, py + 35, (pw - 34) * clamp(state.xp / state.xpNeed, 0, 1), 10, 5);
  ctx.fill();

  /* 羁绊列表（左侧，顶部先放地利徽章） */
  computeTeam();
  let chipY = state.foeLord && state.phase === "play" ? 140 : 112;   // 渠帅在场：左列让开寨墙名牌（v7.18.3）
  if (state.field) {
    ctx.font = "bold 12px sans-serif";
    ctx.textAlign = "left";
    ctx.fillStyle = "rgba(0,0,0,.35)";
    roundRect(10, chipY - 14, 118, 19, 6);
    ctx.fill();
    ctx.fillStyle = "#c9e0a0";
    ctx.fillText(`${state.field.icon}${state.field.name}`, 16, chipY);
    chipY += 22;
  }


  /* 下波预告（休整期显示：抗性主题是核心情报）——先攒行再量宽（2026-07-10 修文字溢出框） */
  if (state.nextWavePreview && state.phase === "play") {
    const pv = state.nextWavePreview;
    const py = 130;
    const mu = pv.mutation ? MUTATIONS[pv.mutation] : null;
    const er = state.endless ? (state.endlessPending || state.endlessMod) : null;   // 无尽军令：预告/生效中
    const resting = state.spawnQueue.length === 0 && state.enemies.length === 0;
    const lines = [];
    lines.push(resting
      ? { t: `⏳ 第 ${state.wave + 1} 波（${Math.ceil(state.waveTimer)}s）`, f: "bold 13px sans-serif", c: "#e8c86a" }
      : { t: `🥁 催战！第 ${state.wave + 1} 波 ${Math.ceil(Math.max(0, state.waveBudget - state.waveClock))}s 后压上`, f: "bold 13px sans-serif", c: "#ff8a6a" });
    if (pv.themeElems?.length && ELEMENTS[pv.themeElems[0]]) {
      const t0 = pv.themeElems[0];
      lines.push({ t: `贼是${ELEMENTS[t0].icon}${ELEMENTS[t0].name}——${ELEMENTS[triCounterOf(t0)].icon}${ELEMENTS[triCounterOf(t0)].name}打他最疼`, f: "bold 15px sans-serif", c: "#5aff9a" });
    }
    if (mu) lines.push({ t: `${mu.icon}「${mu.name}」${mu.desc}${hasRelic("tongque") && !mu.good ? " 🏛️金币+50%" : ""}`, f: "bold 13px sans-serif", c: "#ff9a6a" });
    // 铜雀香炉「灾变成财」：多看两波——预排表里下下波的凶险突变提前亮牌
    if (hasRelic("tongque")) {
      const m2 = state.mutations?.[state.wave + 2];
      if (m2 && !MUTATIONS[m2].good) lines.push({ t: `🏛️ 铜雀预警：第${state.wave + 2}波「${MUTATIONS[m2].name}」将至`, f: "bold 12px sans-serif", c: "#e8c86a" });
    }
    if (er) lines.push({ t: state.endlessPending
      ? `⚔️ 下波军令「${er.name}」：${er.tip}`
      : `⚔️ 军令「${er.name}」生效中（第${er.until + 1}波撤）`, f: "bold 12px sans-serif", c: "#ffb84a" });
    if (pv.youdi) lines.push({ t: "🐑 诱敌成功：这波多而脆，经验金币肥！", f: "bold 12px sans-serif", c: "#ffb84a" });
    const extra = [];
    if (pv.boss) extra.push(`👹「${pv.boss}」`);
    for (const [k, n] of Object.entries(pv.affixes))
      extra.push(`${AFFIXES[k].icon}${AFFIXES[k].name}×${n}`);
    for (const [k, n] of Object.entries(pv.specials))
      extra.push(`${SPECIALS[k].icon}${SPECIALS[k].name}×${n}`);
    if (extra.length) lines.push({ t: extra.slice(0, 4).join(" "), f: "12px sans-serif", c: "#ffb84a" });
    // 框宽=最长行+边距（260保底、贴屏封顶）；仍超宽的行现场缩字号
    let boxW = 260;
    for (const L of lines) { ctx.font = L.f; boxW = Math.max(boxW, ctx.measureText(L.t).width + 28); }
    boxW = Math.min(boxW, W - 16);
    const boxH = 12 + lines.length * 21 + 8;
    ctx.fillStyle = "rgba(0,0,0,.5)";
    roundRect(W / 2 - boxW / 2, py, boxW, boxH, 12);
    ctx.fill();
    ctx.strokeStyle = mu ? "rgba(255,138,90,.8)" : "rgba(232,200,106,.5)";
    ctx.lineWidth = 1.5;
    roundRect(W / 2 - boxW / 2, py, boxW, boxH, 12);
    ctx.stroke();
    ctx.textAlign = "center";
    lines.forEach((L, i) => {
      ctx.font = L.f;
      let fs = parseInt(L.f.match(/(\d+)px/)[1], 10);
      while (fs > 10 && ctx.measureText(L.t).width > boxW - 20) {
        fs--;
        ctx.font = L.f.replace(/\d+px/, fs + "px");
      }
      ctx.fillStyle = L.c;
      ctx.fillText(L.t, W / 2, py + 22 + i * 21);
    });
    // 一键对位按钮已删：射程让位置有真实意义，布阵自己拖
  }

  /* 遗物栏（左侧徽章下方） */
  if (state.relics.length) {
    const ry = chipY;
    ctx.fillStyle = "rgba(0,0,0,.35)";
    roundRect(10, ry - 14, 22 + state.relics.length * 20, 22, 6);
    ctx.fill();
    ctx.font = "14px sans-serif";
    ctx.textAlign = "left";
    state.relics.forEach((r, i) => ctx.fillText(r.icon, 16 + i * 20, ry + 3));
    chipY += 24;
  }
  /* 羁绊名牌（常驻）：生效中的每条羁绊一块金牌——别让羁绊只活在飘字的三秒里 */
  if (state.bondSet?.size) {
    for (const b of BONDS) {
      if (!state.bondSet.has(b.id)) continue;
      const txt = `🔗${b.name}`;
      ctx.font = "bold 12.5px sans-serif";
      const tw = ctx.measureText(txt).width + 14;
      ctx.fillStyle = "rgba(40,32,12,.8)";
      roundRect(10, chipY - 14, tw, 22, 6);
      ctx.fill();
      ctx.strokeStyle = "rgba(255,210,74,.65)";
      ctx.lineWidth = 1.2;
      roundRect(10, chipY - 14, tw, 22, 6);
      ctx.stroke();
      ctx.fillStyle = "#ffd24a";
      ctx.textAlign = "left";
      ctx.fillText(txt, 17, chipY + 3);
      chipY += 26;
    }
  }
  /* 渠帅状态并入寨墙名牌（v7.18.3）：左列不再单开一块，减一层堆叠 */
  /* 歌舞升平·不早朝（v5.9 常驻牌）：全场性状态必须挂明面 */
  if (state.gewu) {
    const txt = "🍷乐不思蜀·全军+30%·自动抽卡挂机中·点屏幕回神";
    ctx.font = "bold 12.5px sans-serif";
    const tw = ctx.measureText(txt).width + 14;
    ctx.fillStyle = "rgba(70,20,40,.85)";
    roundRect(10, chipY - 14, tw, 22, 6);
    ctx.fill();
    ctx.strokeStyle = `rgba(255,154,200,${0.6 + Math.sin(state.time * 3) * 0.2})`;
    ctx.lineWidth = 1.5;
    roundRect(10, chipY - 14, tw, 22, 6);
    ctx.stroke();
    ctx.fillStyle = "#ffb8d8";
    ctx.textAlign = "left";
    ctx.fillText(txt, 17, chipY + 3);
    chipY += 26;
  }

  /* 门生故吏门路牌（常驻，v5.5.2）：延迟生效的东西必须挂在明面上 */
  if (state.widePicks > 0) {
    const txt = `📜五选一×${state.widePicks}·升级就见`;
    ctx.font = "bold 12.5px sans-serif";
    const tw = ctx.measureText(txt).width + 14;
    ctx.fillStyle = "rgba(46,30,58,.85)";
    roundRect(10, chipY - 14, tw, 22, 6);
    ctx.fill();
    ctx.strokeStyle = `rgba(201,168,255,${0.55 + Math.sin(state.time * 4) * 0.25})`;
    ctx.lineWidth = 1.5;
    roundRect(10, chipY - 14, tw, 22, 6);
    ctx.stroke();
    ctx.fillStyle = "#d8bfff";
    ctx.textAlign = "left";
    ctx.fillText(txt, 17, chipY + 3);
    chipY += 26;
  }

  /* 洛阳铲牌（v7.0 董卓）：可点击——点一下进挖掘模式，点障碍格挖、点别处取消 */
  state.shovelChip = null;
  if (state.ruler === "dongzhuo" && state.shovels > 0) {
    const txt = state.digMode ? `🪏 点一块障碍挖！（剩${state.shovels}把）` : `🪏 洛阳铲×${state.shovels}·点我挖宝`;
    ctx.font = "bold 12.5px sans-serif";
    const tw = ctx.measureText(txt).width + 14;
    ctx.fillStyle = state.digMode ? "rgba(80,55,10,.92)" : "rgba(58,44,20,.85)";
    roundRect(10, chipY - 14, tw, 22, 6);
    ctx.fill();
    ctx.strokeStyle = `rgba(255,210,74,${state.digMode ? 0.95 : 0.55 + Math.sin(state.time * 4) * 0.25})`;
    ctx.lineWidth = state.digMode ? 2 : 1.5;
    roundRect(10, chipY - 14, tw, 22, 6);
    ctx.stroke();
    ctx.fillStyle = "#ffd8a0";
    ctx.textAlign = "left";
    ctx.fillText(txt, 17, chipY + 3);
    state.shovelChip = { x: 10, y: chipY - 14, w: tw, h: 22 };
    chipY += 26;
  } else state.digMode = false;

  /* 永久战术卡·立营旗（v7.16）：点亮的战术卡常驻挂牌——落井下石这类纯乘区没有触发演出，不挂牌等于隐形 */
  {
    const tacs = [];
    if (state.luanshiOn) tacs.push("🪨乱石穿空");
    if (state.huoshaoOn) tacs.push("🔥火烧连营");
    if (state.zhanshouOn) tacs.push("🎯擒贼擒王");
    if (state.luojingOn) tacs.push("🕳️落井下石");
    if (state.shuiyanOn) tacs.push("🌊水淹七军");
    if (state.pofuBuff) tacs.push("🍳破釜沉舟");   // 破釜也是永久场上状态（×1.5乘算），漏挂=隐形
    if (tacs.length) {
      const txt = "🚩" + tacs.join(" ");
      ctx.font = "bold 10px sans-serif";
      ctx.textAlign = "left";
      const tw = ctx.measureText(txt).width + 12;
      ctx.fillStyle = "rgba(40,32,16,.7)";
      roundRect(10, chipY - 12, tw, 18, 6);
      ctx.fill();
      ctx.strokeStyle = "rgba(201,182,154,.5)";
      ctx.lineWidth = 1;
      roundRect(10, chipY - 12, tw, 18, 6);
      ctx.stroke();
      ctx.fillStyle = "#e0cfa8";
      ctx.fillText(txt, 16, chipY + 1);
      chipY += 22;
    }
  }

  /* 军略增益速览（原底部栏内容，紧凑徽章化) */
  {
    const b = state.buffs;
    const buffText = [];
    if (b.dmg > 1) buffText.push(`⚔️+${Math.round((b.dmg - 1) * 100)}%`);
    if (b.rate > 1) buffText.push(`🥁+${Math.round((b.rate - 1) * 100)}%`);
    if (b.critCh > 0) buffText.push(`💥${Math.round(b.critCh * 100)}%`);
    if (b.extraShot > 0) buffText.push(`🌠+${b.extraShot}`);
    if (b.xpGain > 1) buffText.push(`📜+${Math.round((b.xpGain - 1) * 100)}%`);
    if (buffText.length) {
      ctx.font = "bold 10px sans-serif";
      ctx.textAlign = "left";
      ctx.fillStyle = "rgba(0,0,0,.35)";
      const tw = ctx.measureText(buffText.join(" ")).width + 12;
      roundRect(10, chipY - 12, tw, 18, 6);
      ctx.fill();
      ctx.fillStyle = "rgba(232,200,106,.9)";
      ctx.fillText(buffText.join(" "), 16, chipY + 1);
    }
  }

  /* 城池血量（城墙条内居中） */
  ctx.font = "bold 15px sans-serif";
  ctx.textAlign = "center";
  ctx.strokeStyle = "rgba(0,0,0,.7)";
  ctx.lineWidth = 3;
  // 桃园金身进行时（v7.5.1 用户"看着很不明显"）：全屏金光描边 + 居中倒计时大字
  if (state.taoyuanT > 0 && state.phase === "play") {
    const gA = 0.35 + Math.sin(state.time * 5) * 0.15;
    const gGrad = ctx.createLinearGradient(0, 0, 0, 60);
    ctx.save();
    ctx.globalAlpha = gA;
    ctx.strokeStyle = "#ffd278";
    ctx.lineWidth = 10;
    ctx.shadowColor = "#ffd278";
    ctx.shadowBlur = 24;
    ctx.strokeRect(5, 5, W - 10, H - 10);
    ctx.restore();
    ctx.font = "bold 21px 'Kaiti SC', 'STKaiti', serif";
    ctx.textAlign = "center";
    ctx.strokeStyle = "rgba(0,0,0,.7)";
    ctx.lineWidth = 4;
    ctx.strokeText(`🍑 桃园金身 · 全军刀枪不入 ${state.taoyuanT.toFixed(1)}s`, W / 2, 236);
    ctx.fillStyle = "#ffe8b0";
    ctx.fillText(`🍑 桃园金身 · 全军刀枪不入 ${state.taoyuanT.toFixed(1)}s`, W / 2, 236);
  }
  const cityTxt = `🏯 ${state.baseHP}/${state.baseHPMax}${state.wallShield > 0 ? ` +🛡️${state.wallShield}` : ""}`;
  ctx.strokeText(cityTxt, W / 2 + 128, DEFENSE_LINE + 24);
  ctx.fillStyle = state.baseHP <= 4 ? "#ff6a6a" : "#ffd8a0";
  ctx.fillText(cityTxt, W / 2 + 128, DEFENSE_LINE + 24);

  /* 三角克制常驻图例（v6.0 用户点名：三个图标的克制关系一直显示）+ 本州贼的属性
     下波预告框弹着时整块让位（v7.1.1 修排版叠字：框里自带"贼是"和军令行，同屏两份挤成一团） */
  if (state.phase === "play" && !state.nextWavePreview) {
    ctx.font = "bold 13px sans-serif";
    ctx.textAlign = "center";
    const hy = 108;   // 克制三角图例已撤（v7.18.7 用户拍板：大家都懂克制了）——行序整体上移
    // 无尽军令生效中：挂一行，随时知道现在是什么题
    if (state.endlessMod) {
      ctx.font = "bold 12px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "rgba(255,184,74,.9)";
      ctx.fillText(`⚔️军令「${state.endlessMod.name}」：${state.endlessMod.tip}`, W / 2, hy + 50);
    }
    // 坐保江汉（v7.14）：刘表的讨伐波增挂在军令下面——涨了多少看得见
    if (state.ruler === "liubiao" && state.endless && state.winWave && state.wave > state.winWave) {
      ctx.font = "bold 12px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "rgba(138,210,255,.92)";
      ctx.fillText(`🐉坐保江汉：多撑${state.wave - state.winWave}波·全军攻击+${(state.wave - state.winWave) * 5}%`, W / 2, hy + (state.endlessMod ? 66 : 50));
    }
    // 攻坚增压（v7.17.4）：贼刀复利后数字挂出来涨给玩家看——和军令/坐保逐行排
    if (foeDmgK() > 1.001) {
      const rowGJ = (state.endlessMod ? 1 : 0) + (state.ruler === "liubiao" && state.winWave && state.wave > state.winWave ? 1 : 0);
      ctx.font = "bold 12px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "rgba(255,138,90,.92)";
      ctx.fillText(`⚔️贼势攻坚：贼的刀×${foeDmgK().toFixed(1)}·控制只吃${Math.round(foeTenacity() * 100)}%`, W / 2, hy + 50 + rowGJ * 16);
    }
  }

  drawButton(BTN.mute, SFX.muted ? "🔇静音" : "🔊音效", SFX.muted ? "#5a3a3a" : "#3a5a6a");
  // 主动退出：两步确认防误触（点一下变红问"真退?"，3秒内再点才退）
  if (state.quitArm > 0) state.quitArm--;
  drawButton(BTN.quit, state.quitArm > 0 ? "真退?" : "🚪退出", state.quitArm > 0 ? "#8a3a2a" : "#4a4048");
  // 📊实时输出统计（v7.17.5 用户点名：直观观测战力差）——面板只在开打时画，结算页别透底
  drawButton(BTN.dmg, "📊输出", state.dmgPanel ? "#5a7a3a" : "#3a4a5a");
  if (state.dmgPanel && state.phase === "play") drawDmgPanel();
}

function drawButton(b, text, color) {
  ctx.fillStyle = color;
  roundRect(b.x, b.y, b.w, b.h, 10);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,.3)";
  ctx.lineWidth = 1.5;
  roundRect(b.x, b.y, b.w, b.h, 10);
  ctx.stroke();
  ctx.font = "bold 14px sans-serif";
  ctx.fillStyle = "#fff";
  ctx.textAlign = "center";
  ctx.fillText(text, b.x + b.w / 2, b.y + b.h / 2 + 5);
}

/* ---------- 主公技槽（右侧，玩家唯一主动按钮） ---------- */
function lordBtnRect(i) {
  return { x: W - 66, y: 208 + i * 70, w: 56, h: 58 };   // 208起：给178的主公名牌让位（退出钮到172收）
}
function drawLordBar() {
  // 主公名牌：三张号令的正上方——这局带的谁，看直播的一眼就知道
  const rl = rulerOf();
  if (rl) {
    ctx.fillStyle = "rgba(20,14,6,.85)";
    roundRect(W - 70, 178, 64, 24, 8);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,215,74,.6)";
    ctx.lineWidth = 1.2;
    roundRect(W - 70, 178, 64, 24, 8);
    ctx.stroke();
    ctx.font = "bold 12px 'Kaiti SC', 'STKaiti', serif";
    ctx.textAlign = "center";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(`👑${rl.name}`, W - 38, 194);
  }
  state.lord.forEach((sl, i) => {
    const b = lordBtnRect(i);
    if (!sl) {
      // 空槽：虚线框等待三选一
      ctx.globalAlpha = 0.45;
      ctx.strokeStyle = "rgba(255,210,74,.5)";
      ctx.lineWidth = 1.5;
      ctx.setLineDash([5, 4]);
      roundRect(b.x, b.y, b.w, b.h, 12);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.font = "16px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "rgba(255,210,74,.5)";
      ctx.fillText("👑", b.x + b.w / 2, b.y + 26);
      ctx.font = "9px sans-serif";
      ctx.fillText("选牌可学", b.x + b.w / 2, b.y + 44);
      ctx.globalAlpha = 1;
      return;
    }
    const L = LORDS[sl.id];
    const ready = state.lordCd <= 0;
    // v7.0 圆形大招图标：自动释放——扇形扫罩显示CD，就绪后呼吸光=等时机（lordAutoOk），时机一到主公自己放
    const cx = b.x + b.w / 2, cyb = b.y + b.h / 2, rr = 27;
    const auto = ready && state.phase === "play" && lordAutoOk(sl.id);
    ctx.fillStyle = ready ? "#6a4a2a" : "#3a3630";
    ctx.beginPath(); ctx.arc(cx, cyb, rr, 0, Math.PI * 2); ctx.fill();
    if (!ready) {   // CD 扇形扫罩：从12点顺时针亮回来
      const frac = state.lordCd / Math.max(0.1, state.lordCdTotal);
      ctx.fillStyle = "rgba(0,0,0,.55)";
      ctx.beginPath(); ctx.moveTo(cx, cyb);
      ctx.arc(cx, cyb, rr, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac);
      ctx.closePath(); ctx.fill();
    }
    ctx.strokeStyle = auto ? "#5aff9a" : ready ? "#ffd24a" : "rgba(255,255,255,.3)";
    ctx.lineWidth = ready ? 3 : 1.5;
    if (ready) {
      ctx.shadowColor = auto ? "#5aff9a" : "#ffd24a";
      ctx.shadowBlur = 8 + Math.sin(state.time * 6) * 4;
    }
    ctx.beginPath(); ctx.arc(cx, cyb, rr, 0, Math.PI * 2); ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.font = "19px sans-serif";
    ctx.textAlign = "center";
    ctx.globalAlpha = ready ? 1 : 0.65;
    ctx.fillText(L.icon, cx, cyb - 2);
    ctx.font = "bold 8.5px sans-serif";
    ctx.fillStyle = "#ffe8b0";
    ctx.fillText(L.name, cx, cyb + 12);
    ctx.font = "7px sans-serif";
    ctx.fillStyle = "#ffd24a";
    ctx.fillText("●".repeat(sl.lv) + "○".repeat(LORD_MAX_LV - sl.lv), cx, cyb + 21);
    ctx.globalAlpha = 1;
    if (!ready) {
      ctx.font = "bold 12px sans-serif";
      ctx.fillStyle = "#fff";
      ctx.fillText(Math.ceil(state.lordCd), b.x + b.w / 2, b.y + b.h / 2 + 4);
    }
  });
}

/* ---------- 底部三选一卡牌区 ---------- */
const CARD_H = 146, CARD_GAP = 10;   // 2026-07-08 武将卡三行分层后加高（阵地顶在622，450+146仍有余）

function cardRect(i) {
  const n = state.cards ? state.cards.length : 3;
  const cw = n >= 5 ? 86 : n === 4 ? 108 : 140;
  const gap = n >= 5 ? 8 : CARD_GAP;
  const total = n * cw + (n - 1) * gap;
  const x0 = (W - total) / 2;
  return { x: x0 + i * (cw + gap), y: CARD_AREA_Y, w: cw, h: CARD_H };
}

function drawCardArea() {
  // 无卡时不占任何空间——战场纵深全给战斗
  if (!state.cards) return;

  // 浮层：半透明遮罩压在战场底部（阵地上方）
  ctx.fillStyle = "rgba(12,9,4,.72)";
  roundRect(8, CARD_AREA_Y - 34, W - 16, CARD_H + 52, 14);
  ctx.fill();
  ctx.strokeStyle = "rgba(232,200,106,.35)";
  ctx.lineWidth = 1.5;
  roundRect(8, CARD_AREA_Y - 34, W - 16, CARD_H + 52, 14);
  ctx.stroke();

  state.cardAnim = Math.min(1, state.cardAnim + 0.08);
  const ease = 1 - Math.pow(1 - state.cardAnim, 3);

  ctx.textAlign = "center";
  ctx.font = "bold 17px sans-serif";
  const pulse = 0.75 + Math.sin(state.time * 5) * 0.25;
  ctx.fillStyle = `rgba(255,228,90,${pulse})`;
  const label = state.gewu && state.autoSel ? (state.autoSel.t < 1 ? "🍷 乐不思蜀·自动抽卡中…" : "🍷 就它了")
    : state.phase === "pickStart" ? "⚜️ 挑个武将开局 ⚜️"
    : state.pickingRelic ? "🎁 挑件宝贝 🎁"
    : state.cards.length >= 5 ? `📜 门生故吏！五张里挑${state.pendingPicks ? `（还有${state.pendingPicks}次）` : ""}`
    : `✨ 升级！挑一张 ✨${state.pendingPicks ? `（还有${state.pendingPicks}次）` : ""}`;
  ctx.fillText(label, W / 2, CARD_AREA_Y - 8);

  // 乐不思蜀扫牌动画（v7.12）：前1秒高亮在三张牌间轮转，后0.5秒定格在抽中那张——玩家一眼看出是在自动抽
  const autoHi = state.gewu && state.autoSel
    ? (state.autoSel.t < 1 ? Math.floor(state.autoSel.t * 8) % state.cards.length : state.autoSel.idx) : -1;
  state.cards.forEach((card, i) => {
    const rc = cardRect(i);
    const dy = (1 - ease) * 100;
    const x = rc.x, y = rc.y + dy;
    const borderCol = card.kind === "relic" ? "#ffd24a" : card.cls ? CLASSES[card.cls].color : "#c9a86a";
    const g = ctx.createLinearGradient(x, y, x, y + rc.h);
    if (card.kind === "relic") {
      g.addColorStop(0, "#5a4a22");
      g.addColorStop(1, "#42361a");
    } else {
      g.addColorStop(0, "#54452a");
      g.addColorStop(1, "#3a3020");
    }
    ctx.fillStyle = g;
    roundRect(x, y, rc.w, rc.h, 12);
    ctx.fill();
    ctx.strokeStyle = borderCol;
    ctx.lineWidth = 2.5;
    roundRect(x, y, rc.w, rc.h, 12);
    ctx.stroke();
    if (i === autoHi) {   // 乐不思蜀：自动抽的高亮圈（轮转粉/定格绿）
      ctx.strokeStyle = state.autoSel.t < 1 ? "rgba(255,154,200,.95)" : "#8df05a";
      ctx.lineWidth = 4;
      roundRect(x - 4, y - 4, rc.w + 8, rc.h + 8, 14);
      ctx.stroke();
    }
    // 图标：武将卡画将旗，其余画 emoji
    if (card.unitType) {
      ctx.fillStyle = "#3a3024";
      ctx.beginPath();
      ctx.arc(x + rc.w / 2, y + 34, 20, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = RARITY[heroRarity(card.unitType.id)].color;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(x + rc.w / 2, y + 34, 20, 0, Math.PI * 2);
      ctx.stroke();
      drawNameDisc(card.unitType.name, 20, x + rc.w / 2, y + 35, heroLv(card.unitType.id) >= MILE_STAR2);
    } else {
      ctx.font = "32px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(card.icon, x + rc.w / 2, y + 44);
    }
    ctx.font = "bold 15px sans-serif";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(card.title, x + rc.w / 2, y + 70);
    if (card.stars) {
      // 练兵卡：属性兵种行（有才画）→ 升完几颗星（新得的绿）→ 一句话 → 图鉴等级
      const hasInfo = !!card.info;
      if (hasInfo) {
        ctx.font = rc.w < 120 ? "bold 11.5px sans-serif" : "bold 13px sans-serif";
        ctx.fillStyle = card.infoColor || "#e8dcc0";
        ctx.fillText(card.info, x + rc.w / 2, y + 88);
      }
      const sy = hasInfo ? 106 : 90;
      // 星行压缩显示（红星=升华星顶2颗）：旧星金色、新得的最后一颗绿色闪动=马上到手
      drawStarRow(x + rc.w / 2, y + sy, card.stars, 16, "#ffd24a", { newColor: "#8df05a", blinkLast: true });
      ctx.textAlign = "center";
      ctx.font = "12px sans-serif";
      ctx.fillStyle = "#e8dcc0";
      ctx.fillText(card.desc, x + rc.w / 2, y + sy + 17);
      if (card.lvN != null) {
        ctx.font = "bold 13px sans-serif";
        ctx.fillStyle = "#8ad2ff";
        ctx.fillText(`图鉴 ${card.lvN} 级`, x + rc.w / 2, y + sy + 36);
      }
    } else if (card.lvN != null && card.info) {
      // 武将卡三行分层（2026-07-08 文案瘦身）：属性兵种（属性色加粗）/ 图鉴等级 / 一句话
      ctx.font = rc.w < 120 ? "bold 11.5px sans-serif" : "bold 13.5px sans-serif";
      ctx.fillStyle = card.infoColor || "#e8dcc0";
      ctx.fillText(card.info, x + rc.w / 2, y + 90);
      ctx.font = "bold 14px sans-serif";
      ctx.fillStyle = "#8ad2ff";
      ctx.fillText(`图鉴 ${card.lvN} 级`, x + rc.w / 2, y + 110);
      ctx.font = "12.5px sans-serif";
      ctx.fillStyle = "#c9b69a";
      wrapText(card.desc, x + rc.w / 2, y + 128, rc.w - 12, 14, 2);
    } else {
      ctx.font = "12px sans-serif";
      ctx.fillStyle = "#e8dcc0";
      wrapText(card.desc, x + rc.w / 2, y + 86, rc.w - 14, 14, 3);
    }
    // 克制标签（角标）：绿=对症好使，红=这关吃瘪
    if (card.tag) {
      const bad = card.tagBad;
      ctx.fillStyle = bad ? "#5a2a2a" : "#2a5a3a";
      roundRect(x + 6, y + 4, 76, 18, 6);
      ctx.fill();
      ctx.strokeStyle = bad ? "#ff8a6a" : "#9adf5a";
      ctx.lineWidth = 1.5;
      roundRect(x + 6, y + 4, 76, 18, 6);
      ctx.stroke();
      ctx.font = "bold 10px sans-serif";
      ctx.fillStyle = bad ? "#ffb8a8" : "#c9f0a0";
      ctx.fillText(card.tag, x + 44, y + 17);
    }
  });
}

function wrapText(text, cx, y, maxW, lineH, maxLines = 2) {
  let line = "", lines = [];
  for (const ch of text) {
    if (ctx.measureText(line + ch).width > maxW) { lines.push(line); line = ch; }
    else line += ch;
  }
  if (line) lines.push(line);
  lines.slice(0, maxLines).forEach((l, i) => ctx.fillText(l, cx, y + i * lineH));
}

/* 武将圆盘画全名：按字数缩字号（与怪物名号同规矩），不再一字认人；10级官（大将军）金名 */
function drawNameDisc(name, r, x = 0, y = 1, goldName = false) {
  const n = [...name].length;
  const fs = Math.round(n >= 4 ? r * 0.48 : n === 3 ? r * 0.62 : n === 2 ? r * 0.78 : r * 1.05);
  ctx.font = `bold ${fs}px 'Kaiti SC', 'STKaiti', serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillStyle = goldName ? "#ffd24a" : "#ffe8b0";
  ctx.fillText(name, x, y);
  ctx.textBaseline = "alphabetic";
}

/* ---------- 敌情面板（点敌人查看抗性，查看时暂停） ---------- */
function drawInspect() {
  const e = state.inspect;
  if (!e) return;
  if (e.dead) { state.inspect = null; return; }
  // 指示圈
  ctx.strokeStyle = "#ffe45a";
  ctx.lineWidth = 2.5;
  ctx.setLineDash([6, 5]);
  ctx.beginPath();
  ctx.arc(e.x, e.y, e.r + 8, 0, Math.PI * 2);
  ctx.stroke();
  ctx.setLineDash([]);
  // 面板
  const pw = 260, ph = 168;
  const px = clamp(e.x - pw / 2, 10, W - pw - 10);
  const py = e.y + e.r + 16 > H - ph - 20 ? e.y - e.r - ph - 16 : e.y + e.r + 16;
  ctx.fillStyle = "rgba(24,18,8,.96)";
  roundRect(px, py, pw, ph, 12);
  ctx.fill();
  ctx.strokeStyle = "#e8c86a";
  ctx.lineWidth = 2;
  roundRect(px, py, pw, ph, 12);
  ctx.stroke();
  ctx.textAlign = "center";
  ctx.font = "bold 15px sans-serif";
  ctx.fillStyle = "#ffe45a";
  const kind = e.boss ? `贼首「${e.bossName}」` : e.affix ? `精锐 · ${AFFIXES[e.affix].name}` : e.special ? `特种 · ${SPECIALS[e.special].name}` : e.big ? "黄巾力士" : "黄巾杂兵";
  ctx.fillText(kind, px + pw / 2, py + 24);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#d5c9a8";
  const tip = e.kit ? KIT_TIPS[e.kit] : e.special ? SPECIAL_TIPS[e.special] : null;
  ctx.fillText(tip ? `${tip}｜血 ${Math.ceil(e.hp)}/${e.hpMax}` : `血量 ${Math.ceil(e.hp)} / ${e.hpMax}`, px + pw / 2, py + 44);
  // 三角属性（v6.0）：它是什么系、谁克它、它克谁——一行讲完
  {
    const tri = e.tri && ELEMENTS[e.tri] ? e.tri : null;
    ctx.font = "bold 15px sans-serif";
    ctx.textAlign = "center";
    if (tri) {
      const kk = triCounterOf(tri), bei = TRI_KE[tri];
      ctx.fillStyle = ELEMENTS[tri].color;
      ctx.fillText(`${ELEMENTS[tri].icon}${ELEMENTS[tri].name}系`, px + pw / 2, py + 70);
      ctx.font = "bold 13px sans-serif";
      ctx.fillStyle = "#5aff9a";
      ctx.fillText(`${ELEMENTS[kk].icon}${ELEMENTS[kk].name}打他 ×1.5 最疼`, px + pw / 2, py + 90);
      ctx.fillStyle = "#ff9a8a";
      ctx.fillText(`${ELEMENTS[bei].icon}${ELEMENTS[bei].name}打他只有六成`, px + pw / 2, py + 108);
    } else {
      ctx.fillStyle = "#d5c9a8";
      ctx.fillText("没有属性——谁打都一样", px + pw / 2, py + 78);
    }
  }
  // 身上的状态（增益红、减益绿——对玩家而言）
  const est = [];
  if (e.burnT > 0) est.push("🔥着火掉血");
  if (e.slowT > 0) est.push("🐢被冻慢");
  if (e.stunT > 0) est.push("💫晕了");
  if (e.sleepT > 0) est.push("💤睡着了（挨打会醒）");
  if (e.fearT > 0) est.push("😨吓跑中");
  if (e.silencedT > 0) est.push("🤐贼技被封");
  if (e.jianjunT > 0) est.push("🎖️被监军按住，多挨打");
  if (e.turncoatT > 0) est.push("💔被离间倒戈：正在殴打同伙");
  if (e.duelT > 0) est.push("⚔️被文丑点名单挑：正冲他去，挨他的打更疼");
  if (inFlood(e)) est.push(`🌊在江里：挨打多${Math.round((state.flood.amp || 0.3) * 100)}%${e.special === "shooter" || e.special === "thrower" ? "、放不了箭" : ""}`);
  if (e._guarded) est.push("👺被督军护着（少挨打30%）");
  if (e.charmT > 0) est.push("💘多挨打30%");
  if (state.deathLink && state.deathLink.t > 0 && state.deathLink.members.includes(e)) est.push("🔗被锁链连着");
  if (e.shield > 0) est.push("🛡️有护盾");
  if (e.affix === "regen") est.push("💚会回血");
  if (e.affix === "frenzy" && e.hp < e.hpMax * 0.4) est.push("😤狂暴加速");
  const estText = est.length ? "状态：" + est.join(" ") : "状态：正常";
  ctx.font = "13px sans-serif";
  if (ctx.measureText(estText).width > pw - 20) ctx.font = "11px sans-serif";
  ctx.fillStyle = est.length ? "#ffd28a" : "rgba(255,255,255,.55)";
  ctx.fillText(estText, px + pw / 2, py + 118);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "rgba(255,255,255,.55)";
  ctx.fillText("绿=好打 红=打不动 · 点一下继续", px + pw / 2, py + 148);
}

const ULT_POP = { w: 310, h: 206 };
function ultPopRect() {
  return { x: (W - ULT_POP.w) / 2, y: 290, w: ULT_POP.w, h: ULT_POP.h };
}
/* 射程白话（大白话远近；骑兵=冲一整列） */
function rangeText(t) {
  if (t.cls === "cav") return "冲一整列";
  if (t.cls === "shield") return "保护周围单位";
  if (t.cls === "support") return "管一圈";
  if (t.cls === "granary") return "站着屯粮";
  if (t.cls === "egg") return "干孵着";
  if (t.cls === "dragon") return "全场横扫";
  const rng = t.rng;
  if (!rng) return "全场都打";
  return rng <= 250 ? "打近处" : rng <= 380 ? "打半场" : "打得远";
}
/* 武将信息面板（点武将查看，如同点敌人；技能自动放，这里看CD和条件） */
function drawUltConfirm() {
  const uc = state.ultConfirm;
  if (!uc) return;
  const u = uc.unit;
  const cls = CLASSES[u.type.cls];
  const ult = ULTS[u.type.id];
  const rc = ultPopRect();
  if (BONDS.some(b => state.bondSet?.has(b.id) && b.members.includes(u.type.id))) rc.h += 22;   // 羁绊金行要地方
  // 高亮本将 + 射程示意（骑兵画冲锋走廊，其余画圈）
  const p = slotCenter(uc.r, uc.c);
  const rng = effRange(u.type);
  if (u.type.cls === "cav") {
    const cw = (u.type.splash ? 46 : 34) + state.buffs.cavWide;
    for (const off of [-CELL, CELL]) {
      const sx = p.x + off;
      if (sx < GRID_X || sx > GRID_X + GRID_COLS * CELL) continue;
      ctx.globalAlpha = 0.05;
      ctx.fillStyle = ELEMENTS[u.type.elem].color;
      ctx.fillRect(sx - cw, 30, cw * 2, p.y - 48 - 30);
    }
    ctx.globalAlpha = 0.12;
    ctx.fillStyle = ELEMENTS[u.type.elem].color;
    ctx.fillRect(p.x - cw, 30, cw * 2, p.y - 48 - 30);
    ctx.globalAlpha = 0.5;
    ctx.strokeStyle = ELEMENTS[u.type.elem].color;
    ctx.lineWidth = 2;
    ctx.setLineDash([10, 8]);
    ctx.strokeRect(p.x - cw, 30, cw * 2, p.y - 48 - 30);
    ctx.setLineDash([]);
    ctx.globalAlpha = 1;
  } else if (u.type.cls === "support") {
    // 辅兵：水波范围示意（大乔冰波圈更大）
    const rad = rippleMax(u.type);
    ctx.strokeStyle = ELEMENTS[u.type.elem].color;
    ctx.globalAlpha = 0.55;
    ctx.lineWidth = 2;
    ctx.setLineDash([8, 6]);
    ctx.beginPath();
    ctx.arc(p.x, p.y - 18, rad, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.globalAlpha = 1;
  } else if (rng) {
    ctx.strokeStyle = ELEMENTS[u.type.elem].color;
    ctx.globalAlpha = 0.55;
    ctx.lineWidth = 2;
    ctx.setLineDash([8, 6]);
    ctx.beginPath();
    ctx.arc(p.x, p.y - 18, rng, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.globalAlpha = 0.07;
    ctx.fillStyle = ELEMENTS[u.type.elem].color;
    ctx.beginPath();
    ctx.arc(p.x, p.y - 18, rng, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }
  ctx.strokeStyle = "#ffd24a";
  ctx.lineWidth = 3;
  ctx.setLineDash([6, 4]);
  roundRect(GRID_X + uc.c * CELL + 2, GRID_Y + uc.r * CELL + 2, CELL - 4, CELL - 4, 10);
  ctx.stroke();
  ctx.setLineDash([]);
  // 卡片
  ctx.fillStyle = "rgba(24,18,8,.96)";
  roundRect(rc.x, rc.y, rc.w, rc.h, 14);
  ctx.fill();
  ctx.strokeStyle = "#ffd24a";
  ctx.lineWidth = 2.5;
  roundRect(rc.x, rc.y, rc.w, rc.h, 14);
  ctx.stroke();
  // 名字 + 星级 + 血（一行）——星级用"N星"数字最直白；标题变长时（神·前缀/转数）先收起"图鉴级"再缩字号，别和右侧血量叠
  ctx.font = "bold 13px sans-serif";
  const hpTxt = `❤️${Math.ceil(u.hp)}/${u.hpMax}`;
  const hpW = ctx.measureText(hpTxt).width;
  const tMax = rc.w - 34 - hpW - 12;
  const tBase = `${shenName(u.type.id, u.type.name)}${u.type.cls === "dragon" ? "" : ` ${u.level}星` + (heroRb(u.type.id) > 0 ? ` ${heroRb(u.type.id)}转` : "")}`;
  const tLv = ULTS[u.type.id] && !["granary", "egg", "dragon"].includes(u.type.cls) ? ` · 图鉴${heroLv(u.type.id)}级` : "";
  ctx.textAlign = "left";
  ctx.fillStyle = "#ffe45a";
  let title = tBase + tLv, tfs = 20;
  ctx.font = `bold ${tfs}px 'Kaiti SC', 'STKaiti', serif`;
  if (ctx.measureText(title).width > tMax) title = tBase;   // 太挤先丢"图鉴级"（徽章行下面还能看到等级信息）
  while (tfs > 15 && ctx.measureText(title).width > tMax) {
    tfs--;
    ctx.font = `bold ${tfs}px 'Kaiti SC', 'STKaiti', serif`;
  }
  ctx.fillText(title, rc.x + 18, rc.y + 30);
  ctx.textAlign = "right";
  ctx.font = "bold 13px sans-serif";
  ctx.fillStyle = u.hp < u.hpMax * 0.4 ? "#ff8a6a" : "#9adf5a";
  ctx.fillText(hpTxt, rc.x + rc.w - 16, rc.y + 30);
  ctx.textAlign = "center";
  // 系 + 兵种 + 远近（一行徽章）
  ctx.fillStyle = "rgba(0,0,0,.4)";
  roundRect(rc.x + 24, rc.y + 40, rc.w - 48, 24, 8);
  ctx.fill();
  ctx.strokeStyle = ELEMENTS[u.type.elem].color;
  ctx.lineWidth = 1.5;
  roundRect(rc.x + 24, rc.y + 40, rc.w - 48, 24, 8);
  ctx.stroke();
  ctx.font = "bold 14px sans-serif";
  ctx.fillStyle = ELEMENTS[u.type.elem].color;
  ctx.fillText(`${ELEMENTS[u.type.elem].icon}${ELEMENTS[u.type.elem].name}系 · ${cls.icon}${cls.name} · ${rangeText(u.type)}${heroLv(u.type.id) > 1 ? ` · ${heroLv(u.type.id)}级` : ""}`, rc.x + rc.w / 2, rc.y + 57);
  // 白话打法（一行）
  ctx.font = "14px sans-serif";
  ctx.fillStyle = "#e8dcc0";
  const playNote = u.type.cls === "spear" ? `${u.type.desc} · 旁边人攻击+${Math.round((0.10 + state.buffs.spearAura) * 100)}%`
    : u.type.cls === "cav" ? `冲左中右贼多的一列·乱军越多越猛(现+${Math.round((cavCrowdMul() - 1) * 100)}%) · ${u.type.desc}`
    : u.type.cls === "shield" ? `拉仇恨(远箭七成冲他)·挨刀反弹${Math.round(u.hpMax * (0.04 + state.buffs.shieldReflect))}点·怒气${Math.round(100 * (u.tanked || 0) / (u.hpMax * 0.6))}%攒满反击`
    : u.type.cls === "support" ? `不打人 · 每隔几秒${u.type.desc}`
    : u.type.cls === "granary" ? "不打人 · 产粮喂旁边武将升星，敌人能拆它"
    : u.type.cls === "egg" ? "不打人 · 干孵着等觉醒，被打碎就血本无归"
    : u.type.cls === "dragon" ? `每${u.type.rate}秒吐龙息：重击最强的贼头并镇住它，圈内跟着烧`
    : `射箭 · ${u.type.desc}`;
  ctx.fillText(playNote, rc.x + rc.w / 2, rc.y + 84);
  // —— 自身信息连成一块：打法之后紧跟大招（粮仓/蛋/龙没大招，这块写各自的账本） ——
  if (u.type.cls === "granary") {
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = "#e8c86a";
    ctx.fillText(`每秒攒 ${granaryRate(u).toFixed(1)} 粮 · 喂星进度 ${Math.min(99, Math.round((u.farmAcc || 0) / granaryStarNeed() * 100))}%（喂身边星最低的）`, rc.x + rc.w / 2, rc.y + 108);
    ctx.font = "13px sans-serif";
    ctx.fillStyle = "#c9b69a";
    ctx.fillText(u.level < GRANARY_MAX ? "再抽「粮仓扩建」升星：产粮×1.6" : "满星了！再抽「屯田粮仓」能开新仓", rc.x + rc.w / 2, rc.y + 128);
    ctx.fillText("被拆了不算阵亡 · 拖出阵地能卖", rc.x + rc.w / 2, rc.y + 146);
  } else if (u.type.cls === "egg") {
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = "#c9a8ff";
    ctx.fillText(u.level >= EGG_MAX ? "🐉 三阶圆满！抽到「应龙觉醒」就破壳" : `孵到 ${u.level}/${EGG_MAX} 阶 · 这次把握 ${Math.round(hatchChance(u) * 10)} 成`, rc.x + rc.w / 2, rc.y + 108);
    ctx.font = "13px sans-serif";
    ctx.fillStyle = "#c9b69a";
    if (u.level < EGG_MAX) {
      const helps = [];
      if (u.hatchBonus > 0) helps.push(`失败攒的把握+${Math.round(u.hatchBonus * 10)}成`);
      const pos0 = findUnitPos(u);
      if (pos0 && cellTrait(pos0[0], pos0[1]) === "elem") helps.push("灵脉+1成");
      if (hasRelic("longxian")) helps.push("龙涎香+2成");
      if (u.rbuffs?.farm > 0) helps.push("鲁肃粮草+1成5");
      ctx.fillText(helps.length ? helps.join(" · ") : "失败不掉阶，下次把握+2成", rc.x + rc.w / 2, rc.y + 128);
    } else {
      ctx.fillText("觉醒后比五星英雄还猛，越往后越猛", rc.x + rc.w / 2, rc.y + 128);
    }
    ctx.fillText("被打碎=白孵 · 放灵脉宝地孵得稳", rc.x + rc.w / 2, rc.y + 146);
  } else if (u.type.cls === "dragon") {
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = "#8ad2ff";
    ctx.fillText(`重击 ${dragonDmg(u) * 3} 伤 · 圈内 ${dragonDmg(u)} 伤（跟波次和队伍星级涨）`, rc.x + rc.w / 2, rc.y + 108);
    ctx.font = "13px sans-serif";
    ctx.fillStyle = "#c9b69a";
    ctx.fillText(u.dragonRank > 1 ? `第${u.dragonRank}条应龙：伤害多${Math.round(DRAGON_RANK_MUL * (u.dragonRank - 1) * 100)}%` : "被镇住的贼头不敢作法 · 什么抗都烧得动", rc.x + rc.w / 2, rc.y + 128);
    ctx.fillText(state.dragonN < 2 ? "还能再抽龙蛋，下一条更猛（一局最多两条）" : "双龙圆满——一局的顶配就是这了", rc.x + rc.w / 2, rc.y + 146);
  } else {
  const ut = ULT_TYPES[ult.type];
  ctx.font = "bold 14px sans-serif";
  ctx.fillStyle = ut.color;
  ctx.fillText(`大招【${ult.name}】${ult.desc}`, rc.x + rc.w / 2, rc.y + 108);
  const cdMax = ultCdMax(u);
  const prog = 1 - clamp(u.ultCd / cdMax, 0, 1);
  ctx.fillStyle = "rgba(255,255,255,.15)";
  roundRect(rc.x + 40, rc.y + 118, rc.w - 80, 8, 4);
  ctx.fill();
  ctx.fillStyle = ut.color;
  roundRect(rc.x + 40, rc.y + 118, (rc.w - 80) * prog, 8, 4);
  ctx.fill();
  ctx.font = "13px sans-serif";
  ctx.fillStyle = prog >= 1 ? "#9adf5a" : "#c9b69a";
  ctx.fillText(prog >= 1 ? `能放了 · ${ult.condDesc}就放` : `${Math.ceil(u.ultCd)}秒后能放 · ${ult.condDesc}就放`,
    rc.x + rc.w / 2, rc.y + 142);
  }
  // —— 分隔线下面是临时状态：宝地 + 加成 ——
  ctx.strokeStyle = "rgba(255,255,255,.14)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(rc.x + 26, rc.y + 156);
  ctx.lineTo(rc.x + rc.w - 26, rc.y + 156);
  ctx.stroke();
  let ctk = cellTrait(uc.r, uc.c);
  // 粮仓/蛋/龙不走常规攻击加成：攻击类宝地对它们是空话，只报真起作用的（坚岩减伤/灵泉回血；蛋的灵脉在上面已经写了）
  if ((u.type.cls === "granary" || u.type.cls === "egg" || u.type.cls === "dragon")
    && ctk && ctk !== "guard" && ctk !== "heal") ctk = null;
  if (ctk) {
    ctx.font = "13px sans-serif";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(`宝地：${TRAITS[ctk].icon}${TRAITS[ctk].name} ${critText(TRAITS[ctk].desc)}`, rc.x + rc.w / 2, rc.y + 174);
  }
  const sts = [];
  if (u.rbuffs?.dmg > 0) sts.push("💧打得更疼");
  if (u.rbuffs?.haste > 0) sts.push(u.type.cls === "support" ? "💧水波放更勤" : "💧出手更快");
  if (u.rbuffs?.crit > 0) sts.push(`💧更容易${critWord()}`);
  if (u.rbuffs?.heal > 0) sts.push("💗持续回血");
  if (u.rbuffs?.cdr > 0) sts.push("🕐大招转更快");
  if (u.rbuffs?.farm > 0) sts.push("🌾吃了鲁肃的波：喂星快+50%");
  if (u.type.id === "wutugu" && u.ultT > 0) sts.push("☠️毒瘴爆发中");
  if (u.reflectT > 0) sts.push("❄️反伤翻倍");
  if (u.buffT > 0) sts.push("✨变强中");
  if (state.armyBuff && unitAttacks(u.type)) sts.push("🌾全军加攻");
  if (state.armyHaste && u.type.cls !== "shield") sts.push("🌬️全军提速");
  if (isKin(u.type.id)) sts.push("🤝主公亲军（登场已带星）");
  if (state.wuxingT > 0 && unitAttacks(u.type)) sts.push("☯️三才破敌：被克免罚+15%伤");
  if (unitAttacks(u.type)) {
    let auraN = 0;
    for (let rr = Math.max(0, uc.r - 1); rr <= Math.min(GRID_ROWS - 1, uc.r + 1); rr++)
      for (let cc = Math.max(0, uc.c - 1); cc <= Math.min(GRID_COLS - 1, uc.c + 1); cc++) {
        if (rr === uc.r && cc === uc.c) continue;
        const nb = state.slots[rr][cc];
        if (nb && nb.type.cls === "spear") auraN++;
      }
    if (auraN) sts.push(`🔱攻击+${Math.round(Math.min(3, auraN) * (0.10 + state.buffs.spearAura) * 100)}%`);
  }
  if (u.type.cls !== "shield" && hasAdjacentShield(uc.r, uc.c)) sts.push("🛡️有盾护着");
  if (u.type.cls !== "shield" && shieldCover(uc.r, uc.c)) sts.push("🧱盾墙挡投石");
  if (u.sealedT > 0) sts.push("🌀被封住了！");
  if (wxRain() && (u.type.burn || u.type.firebrand)) sts.push("🌧️大雨之潮，点不着火");
  const stText = sts.length ? "加成：" + sts.join(" ") : "加成：暂时没有";
  ctx.font = "13px sans-serif";
  if (ctx.measureText(stText).width > rc.w - 24) ctx.font = "12px sans-serif";
  ctx.fillStyle = sts.length ? "#9adf5a" : "rgba(255,255,255,.45)";
  ctx.fillText(stText, rc.x + rc.w / 2, rc.y + (ctk ? 194 : 184));
  // 羁绊单独一行金色——混在加成长句尾巴上没人看得见
  const myBonds = BONDS.filter(b => state.bondSet?.has(b.id) && b.members.includes(u.type.id));
  if (myBonds.length) {
    const bTxt = myBonds.map(b => `🔗${b.name}：${b.desc}`).join("　");
    ctx.font = "bold 13px sans-serif";
    if (ctx.measureText(bTxt).width > rc.w - 24) ctx.font = "bold 12px sans-serif";
    ctx.fillStyle = "#ffd24a";
    ctx.fillText(bTxt, rc.x + rc.w / 2, rc.y + (ctk ? 194 : 184) + 20);
  }
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "rgba(255,255,255,.55)";
  ctx.fillText("点别处关闭（已暂停）", rc.x + rc.w / 2, rc.y + rc.h + 18);
}

/* 主公面板（查看即暂停）：点👑名牌或冷却期点技能弹出——三道号令是什么、现在几级、锁多久，全在这 */
function drawLordPop() {
  const rl = rulerOf();
  if (!rl) return;
  const rc = { x: W / 2 - 175, w: 350, y: 150, h: 140 + state.lord.length * 148 };   // v7.15：多44px给亲射外显
  ctx.fillStyle = "rgba(0,0,0,.6)";
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = "rgba(30,24,12,.97)";
  roundRect(rc.x, rc.y, rc.w, rc.h, 14);
  ctx.fill();
  ctx.strokeStyle = "#ffd24a";
  ctx.lineWidth = 2;
  roundRect(rc.x, rc.y, rc.w, rc.h, 14);
  ctx.stroke();
  ctx.textAlign = "center";
  ctx.font = "bold 22px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`👑 ${rl.name} · ${rl.title}`, W / 2, rc.y + 34);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("大招自动释放：CD转好、时机一到主公自己放，不用盯", W / 2, rc.y + 58);
  // 亲射外显（v7.15 用户点名：普攻的攻击力和攻击方式亮出来）——每击估伤按当前波数/等级/亲兵/卡加成实算
  {
    const est = lordAtkEst();
    if (est) {
      const { atk, per, itv } = est;
      ctx.textAlign = "left";
      ctx.font = "bold 13.5px sans-serif";
      ctx.fillStyle = "#ffb84a";
      ctx.fillText(`${atk.icon} 普攻「${atk.name}」每${itv.toFixed(1)}秒：约${Math.round(per)}伤${state.lordAtkBuff ? `（含卡+${Math.round(state.lordAtkBuff * 100)}%）` : ""}+3%目标血`, rc.x + 22, rc.y + 82);
      ctx.font = "12px sans-serif";
      ctx.fillStyle = "#c9b69a";
      ctx.fillText(atk.how + "——选卡遇到🎯御驾亲征/⚙️神机连弩可以养他", rc.x + 22, rc.y + 100);
      ctx.textAlign = "center";
    }
  }
  lordPopCast = null;
  state.lord.forEach((sl, i) => {
    if (!sl) return;
    const L = LORDS[sl.id];
    const yy = rc.y + 126 + i * 148;
    ctx.fillStyle = "rgba(255,255,255,.05)";
    roundRect(rc.x + 10, yy - 6, rc.w - 20, 140, 10);
    ctx.fill();
    ctx.textAlign = "left";
    ctx.font = "bold 16px sans-serif";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(`${L.icon} ${L.name}`, rc.x + 22, yy + 14);
    ctx.font = "bold 13px sans-serif";
    ctx.fillStyle = "#c9a8ff";
    ctx.fillText(`${sl.lv}星（主公 Lv.${lordLv(state.ruler)}，局外练主公涨威力）`, rc.x + 22, yy + 34);
    // 大招介绍：desc 自动换行（两行预算）
    ctx.font = "14px sans-serif";
    ctx.fillStyle = "#e8dcc0";
    {
      const dTxt = L.desc(sl.lv);
      let line = "", dy = 0;
      for (const ch of dTxt) {
        if (ctx.measureText(line + ch).width > rc.w - 44) { ctx.fillText(line, rc.x + 22, yy + 54 + dy); line = ch; dy += 18; }
        else line += ch;
        if (dy > 18) break;
      }
      if (line) ctx.fillText(line, rc.x + 22, yy + 54 + dy);
    }
    // 自动时机：什么时候会自己放
    ctx.font = "12.5px sans-serif";
    ctx.fillStyle = "#9adf5a";
    ctx.fillText(`⚙️ 自动时机：${LORD_AUTO_TIPS[sl.id] || "CD一转好就放"}`, rc.x + 22, yy + 92);
    ctx.font = "13px sans-serif";
    ctx.fillStyle = "#8ad2ff";
    const kpP = kinPower();
    ctx.fillText(`冷却 ${Math.round(lordCdMax(sl))} 秒${sl.id === "mensheng" ? "" : kpP > 1
      ? `　🤝亲兵助威 ×${kpP.toFixed(1)}` : "　🤝亲兵上阵可加威力（最多×1.8）"}`, rc.x + 22, yy + 110);
    // 就绪时给"立刻施放"按钮（抢时机的手动入口挪到这里，图标点开只看不放）
    if (state.lordCd <= 0 && state.phase === "play") {
      const cb = { x: rc.x + rc.w - 118, y: yy + 98, w: 100, h: 30 };
      ctx.fillStyle = "#6a4a2a";
      roundRect(cb.x, cb.y, cb.w, cb.h, 8);
      ctx.fill();
      ctx.strokeStyle = "#ffd24a";
      ctx.lineWidth = 2;
      roundRect(cb.x, cb.y, cb.w, cb.h, 8);
      ctx.stroke();
      ctx.font = "bold 14px sans-serif";
      ctx.textAlign = "center";
      ctx.fillStyle = "#ffe8b0";
      ctx.fillText("⚡立刻施放", cb.x + cb.w / 2, cb.y + 20);
      ctx.textAlign = "left";
      lordPopCast = cb;
    }
  });
  ctx.textAlign = "center";
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "rgba(255,255,255,.55)";
  ctx.fillText("点别处关闭（已暂停）", W / 2, rc.y + rc.h + 18);
}

/* ---------- 标题 / 结算 / 兵法 ---------- */
function drawTitle() {
  ctx.fillStyle = "rgba(20,14,6,.90)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  ctx.font = "bold 46px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText("不一样三国", W / 2, 210);
  ctx.font = "bold 20px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#c9a86a";
  ctx.fillText("2.0", W / 2 + 148, 195);
  ctx.font = "bold 24px sans-serif";
  ctx.fillStyle = "#e8c86a";
  ctx.fillText("⚔️ 守城塔防 · 肉鸽点将 ⚔️", W / 2, 258);
  // 封面介绍：只讲本作独有的机制和赛季规则，塔防常识不占地方
  ctx.font = "16px sans-serif";
  const lines = [   // v7.13：口径统一天下争夺（64城/城池/势力值/十大功绩），最长一行≤26字——16px×27字就顶满480宽
    { t: "天下争夺·每周一全服换图：64座城池逐城攻取", c: "#d5c9a8" },
    { t: "✊克✌️克✋克✊：带克这城贼的那一系才打得疼", c: "#9adf5a" },
    { t: "贼军不等人：杀得慢，下一波直接压上来", c: "#ff9a7a" },
    { t: "破城再乘胜讨伐——多撑一波，讨伐值更高（只记十大功绩）", c: "#8ad2ff" },
    { t: "势力值周一清零重比；金币和英雄等级永远是你的", c: "#d5c9a8" },
  ];
  lines.forEach((L, i) => { ctx.fillStyle = L.c; ctx.fillText(L.t, W / 2, 318 + i * 31); });
  // 金币
  ctx.font = "bold 17px sans-serif";
  ctx.fillStyle = "#ffb84a";
  ctx.fillText(`💰 金币：${meta.gold}　🏆 成就：${meta.ach.length}/${ACHS.length}`, W / 2, 565);
  // 看广告拿钱已搬进寻访页（v7.17.2）——首页清爽点
  // 武将阁 / 主公府 / 寻访 / 成就 按钮
  drawButton(SHOP_BTN, "📖 图鉴", "#6a4a2a");
  drawButton(TECH_BTN, "👑 主公府", "#4a3a5a");
  drawButton(VISIT_BTN, "🧭 寻访", itemN("visitToken") > 0 ? "#2a5a4a" : "#3a4a44");
  drawButton(ACH_BTN, "🏆 成就", "#4a5a3a");
  drawButton(BAG_BTN, "🎒 背包", "#4a4436");
  // 寻访角标：有令牌没用就亮个数——攒着的活跃奖励别忘了花
  if (itemN("visitToken") > 0) {
    ctx.fillStyle = "#c83a2a";
    ctx.beginPath();
    ctx.arc(VISIT_BTN.x + VISIT_BTN.w - 6, VISIT_BTN.y + 4, 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.font = "bold 12px sans-serif";
    ctx.fillStyle = "#fff";
    ctx.fillText(String(Math.min(99, itemN("visitToken"))), VISIT_BTN.x + VISIT_BTN.w - 6, VISIT_BTN.y + 8);
  }
  // 红点：有成就奖没领
  const nAch = achClaimableCount();
  if (nAch) {
    ctx.fillStyle = "#ff3a2a";
    ctx.beginPath();
    ctx.arc(ACH_BTN.x + ACH_BTN.w - 4, ACH_BTN.y - 2, 10, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#fff";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.arc(ACH_BTN.x + ACH_BTN.w - 4, ACH_BTN.y - 2, 10, 0, Math.PI * 2);
    ctx.stroke();
    ctx.font = "bold 12px sans-serif";
    ctx.textAlign = "center";
    ctx.fillStyle = "#fff";
    ctx.fillText(nAch > 9 ? "9+" : String(nAch), ACH_BTN.x + ACH_BTN.w - 4, ACH_BTN.y + 2);
  }
  ctx.font = "bold 22px sans-serif";
  ctx.fillStyle = "#fff";
  const pulse = 0.6 + Math.sin(state.time * 4) * 0.4;
  ctx.globalAlpha = pulse;
  ctx.fillText("👆 点击空白处出征", W / 2, 745);
  ctx.globalAlpha = 1;
  // 左下角排行榜入口
  ctx.globalAlpha = 0.85;
  drawButton(BOARD_BTN, "🏆 排行榜", "#4a4458");
  ctx.globalAlpha = 1;
  // 右下角更新日志 + 版本戳 + 当前账号
  ctx.globalAlpha = 0.85;
  drawButton(LOG_BTN, "📋 更新日志", "#3a4a58");
  ctx.globalAlpha = 1;
  ctx.font = "11px sans-serif";
  ctx.fillStyle = "rgba(213,201,168,.5)";
  ctx.textAlign = "right";
  ctx.fillText(`v${GAME_VERSION}`, W - 16, H - 52);
  ctx.textAlign = "center";
  ctx.fillText(`👤 ${NET.name || "没登录"}`, W / 2, H - 24);
  if (showBoard) drawBoardOverlay();
  window.__cheat?.drawTitleUI?.();
}
/* ---------- 排行榜（天下争夺版）：势力榜——势力值＝Σ繁荣度×威望 + 十大功绩(讨伐值Top10)。
   比最高分不比肝：16关打通就有基本盘，追高分的反复挑无尽，不追的够分数段领奖就行 ---------- */
const BOARD_BACK = { x: W / 2 - 60, y: H - 76, w: 120, h: 40 };
const BOARD_LOGOUT = { x: W / 2 - 110, y: H - 132, w: 220, h: 40 };
let boardTab = "week";   // 榜单双页签：week=势力榜(讨伐为主) / tech=韬略榜(比打法不比肝)
const BOARD_TAB_WEEK = { x: W / 2 - 164, y: 116, w: 160, h: 32 };
const BOARD_TAB_TECH = { x: W / 2 + 4,   y: 116, w: 160, h: 32 };
function drawBoardOverlay() {
  ctx.fillStyle = "rgba(20,14,6,.96)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  ctx.font = "bold 26px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`🏅 本周英雄榜 · 第${trialWeekNow() - WEEK0 + 1}期`, W / 2, 54);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  const isTech = boardTab === "tech";
  if (isTech) {
    ctx.fillText("韬略分＝对症×少损×顺应天时：比谁打得漂亮，不比谁刷得久", W / 2, 86);
    ctx.fillText("只记你用兵最漂亮的十役，和势力榜互不换算——高手的荣誉榜", W / 2, 104);
  } else {
    ctx.fillText("势力值＝每城繁荣度×威望全数入账 + 你最辉煌的十次讨伐", W / 2, 86);
    ctx.fillText(`周一结榜换图：前${WEEK_RANK_GOLD.length}名有排名奖（第1名${WEEK_RANK_GOLD[0]}💰），分数段奖当场发`, W / 2, 104);
  }
  // 双页签
  drawButton(BOARD_TAB_WEEK, "🏆 势力榜", isTech ? "#4a4030" : "#7a5a2a");
  drawButton(BOARD_TAB_TECH, "🎯 韬略榜", isTech ? "#2a6a5a" : "#3a4438");
  const rows = isTech ? techBoardRows() : weekBoardRows();
  if (!rows) {
    ctx.font = "16px sans-serif";
    ctx.fillStyle = "#d5c9a8";
    ctx.fillText(IS_BROWSER ? "正在联网拿榜单…（拿不到就是断网了）" : "没联网", W / 2, 300);
  } else if (!rows.length) {
    ctx.font = "16px sans-serif";
    ctx.fillStyle = "#d5c9a8";
    ctx.fillText(isTech ? "本期还没人得韬略分，漂亮通一城你就是第一名" : "本期还没人得分，打一城你就是第一名", W / 2, 300);
  } else {
    rows.slice(0, 13).forEach((e, i) => {
      const y = 176 + i * 34;
      const self = e.name === NET.name || e.name === "我(没登录)";
      if (self) {
        ctx.fillStyle = "rgba(255,215,74,.12)";
        roundRect(24, y - 21, W - 48, 29, 8);
        ctx.fill();
      }
      ctx.textAlign = "left";
      ctx.font = "bold 15px sans-serif";
      ctx.fillStyle = i === 0 ? "#ffd24a" : i === 1 ? "#cfd6dc" : i === 2 ? "#d8a05a" : "#c9b69a";
      ctx.fillText(`${i + 1}`, 36, y);
      ctx.fillStyle = self ? "#ffe45a" : "#e8dcc0";
      ctx.fillText(e.name, 66, y);
      ctx.textAlign = "right";
      if (isTech) {
        ctx.font = "bold 15px sans-serif";
        ctx.fillStyle = "#6ad2c0";
        ctx.fillText(`${e.tech}分`, W - 30, y);
      } else {
        // v7.16.2 排版修（用户截图：七位数分怼进统计列）：分数先量宽，统计列动态左让——两列永不打架
        const scoreTxt = `${e.score}分`;
        ctx.font = "bold 15px sans-serif";
        const sw = ctx.measureText(scoreTxt).width;
        ctx.font = "13px sans-serif";
        ctx.fillStyle = "#9adf5a";
        ctx.fillText(`通${e.cleared || 0} ★${e.stars || 0} 📺${e.ads || 0}`, W - 40 - sw, y);
        ctx.font = "bold 15px sans-serif";
        ctx.fillStyle = "#ffd24a";
        ctx.fillText(scoreTxt, W - 30, y);
      }
    });
  }
  ctx.textAlign = "center";
  if (NET.name)
    drawButton(BOARD_LOGOUT, boardLogoutArm ? "真退出？再点一次" : `👤 ${NET.name} · 退出换号`, boardLogoutArm ? "#7a3a2a" : "#4a4458");
  drawButton(BOARD_BACK, "🏠 返回", "#5a4a3a");
}
function boardClick(p) {
  if (inBtn(p, BOARD_BACK)) { showBoard = false; boardLogoutArm = false; return; }
  if (inBtn(p, BOARD_TAB_WEEK)) { boardTab = "week"; boardLogoutArm = false; return; }
  if (inBtn(p, BOARD_TAB_TECH)) { boardTab = "tech"; boardLogoutArm = false; return; }
  if (NET.name && inBtn(p, BOARD_LOGOUT)) {
    if (!boardLogoutArm) { boardLogoutArm = true; return; }
    boardLogoutArm = false;
    showBoard = false;
    acctLogout();
    return;
  }
  boardLogoutArm = false;
}

/* ---------- 英雄图鉴（抽卡/卡组退役）：全部武将都在这，点头像看详情；详情里花金币升级、设主将 ---------- */
let shopMsg = null;   // { text, until } 页内提示条
const SHOP_BACK   = { x: 14, y: 22, w: 76, h: 34 };
let shopTab = "hero";   // 图鉴双页签：hero=英雄 / bond=羁绊
let bondPage = 0;       // 羁绊页翻页（v7.9.0：18条羁绊一屏放不下，分页看）
const BOND_PAGE_N = 9;
const BOND_PREV = { x: 40,  y: 636, w: 130, h: 40 };
const BOND_NEXT = { x: W - 170, y: 636, w: 130, h: 40 };
const SHOP_TAB_HERO = { x: 12,  y: 104, w: 148, h: 30 };
const SHOP_TAB_BOND = { x: 166, y: 104, w: 148, h: 30 };
const SHOP_TAB_DEX  = { x: 320, y: 104, w: 148, h: 30 };
const SHOP_COLS = 5, SHOP_CELL_W = 96, SHOP_CELL_H = 72;   // 行距放宽：等级小字别贴着下一排头像
const CODEX_PIN_Y = 158;         // 主将排顶（金底板独立一排，和点将台同一套视觉）
const CODEX_REST_Y = 262;        // 其余英雄网格顶（29人=6行，到634打止；没主将时34人7行也放得下）
function shopSay(text) { shopMsg = { text, until: performance.now() + 2600 }; }
/* 图鉴排序：按品质从高到低（金→蓝→绿→白），同品质保持图鉴原序 —— 好卡排最前一眼看到 */
const RARITY_RANK = { epic: 0, rare: 1, uncommon: 2, common: 3 };
function codexOrder() {
  return [...GENERALS].sort((a, b) => RARITY_RANK[heroRarity(a.id)] - RARITY_RANK[heroRarity(b.id)]);
}
function shopCellRect(i) {
  return { x: 4 + (i % SHOP_COLS) * SHOP_CELL_W, y: CODEX_PIN_Y - 24 + Math.floor(i / SHOP_COLS) * SHOP_CELL_H, w: SHOP_CELL_W, h: SHOP_CELL_H };
}
/* 头像下小字：等级（兵种/属性看圆盘角标，段位看军阶星条）；主将身份靠金底板分区+金圈表达，不再挤小字 */
function shopCellSub(g) {
  const lv = heroLv(g.id), rb = heroRb(g.id);
  const t = lv >= heroCap(g.id) ? (rb >= HERO_RB_MAX ? "满转" : rb ? `${rb}转满` : "满级") : `${lv}级${rb ? `·${rb}转` : ""}`;
  return isShen(g.id) ? `👼神将·${t}` : t;   // 本期神将：小字点名+金色（调色在绘制处）
}
/* 军阶星标：等级一眼数——5颗星每半颗=3级，正好1~30级；空位画暗星所以满没满一目了然。
   配色分段：≤10级铜、11~20级银、21级起金（数量+颜色双编码，色弱靠数星也分得清） */
function drawRankBadge(lv, cx, cy) {
  const halves = Math.max(0, Math.min(10, Math.floor(lv / 3)));
  const color = lv >= 21 ? "#ffd24a" : lv >= 11 ? "#cfd6dc" : "#d8a05a";
  const STEP = 9.5, w = 5 * STEP + 8;
  ctx.fillStyle = "rgba(20,14,6,.94)";
  roundRect(cx - w / 2, cy - 7, w, 14, 5);
  ctx.fill();
  ctx.font = "bold 9px sans-serif";
  ctx.textAlign = "center";
  for (let i = 0; i < 5; i++) {
    const sx = cx + (i - 2) * STEP;
    const fill = halves - i * 2;   // 这颗星占了几个半格：≥2满、1左半、≤0空
    ctx.fillStyle = "rgba(255,255,255,.16)";
    ctx.fillText("★", sx, cy + 3.5);
    if (fill >= 2) {
      ctx.fillStyle = color;
      ctx.fillText("★", sx, cy + 3.5);
    } else if (fill === 1) {
      ctx.save();
      ctx.beginPath();
      ctx.rect(sx - STEP / 2, cy - 7, STEP / 2, 14);
      ctx.clip();
      ctx.fillStyle = color;
      ctx.fillText("★", sx, cy + 3.5);
      ctx.restore();
    }
  }
}
/* 小圆盘：品质色描边（白/绿/蓝/金）+ 名字 + 军阶角标 + 兵种/属性角标
   （兵种右上、属性左上——和战场圆盘同一套图标语言，列表里一眼挑得出人；
   下缘让给军阶星条，属性角标不画在左下防打架） */
/* 羁绊页：名称+效果+成员头像（练到门槛的亮、没练到的灰——一眼看出缺谁） */
/* 羁绊页（2026-07-08 老登可读版）：一行=名字+效果+成员头像，字大、不重复——
   "同场上阵就生效"整页只在顶部说一次 */
function drawBondTab() {
  const pages = Math.ceil(BONDS.length / BOND_PAGE_N);
  if (bondPage >= pages) bondPage = pages - 1;
  if (bondPage < 0) bondPage = 0;
  const start = bondPage * BOND_PAGE_N;
  const slice = BONDS.slice(start, start + BOND_PAGE_N);
  let y = 148;
  for (const b of slice) {
    const rowH = 53;
    ctx.fillStyle = "rgba(255,215,74,.06)";
    roundRect(6, y, W - 12, rowH - 6, 10);
    ctx.fill();
    ctx.strokeStyle = "rgba(255,215,74,.4)";
    ctx.lineWidth = 1.2;
    roundRect(6, y, W - 12, rowH - 6, 10);
    ctx.stroke();
    ctx.textAlign = "left";
    ctx.font = "bold 16px sans-serif";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(`${b.icon} ${b.name}`, 16, y + 21);
    ctx.font = "13px sans-serif";
    ctx.fillStyle = "#d5c9a8";
    ctx.fillText(b.desc, 16, y + 41);
    let mx = W - 16 - b.members.length * 42 + 21;
    for (const id of b.members) {
      const g = GENERALS.find(x => x.id === id);
      drawShopDisc(g, mx, y + 23, 17, false);
      mx += 42;
    }
    ctx.textAlign = "center";
    y += rowH;
  }
  // 翻页（v7.9.0）：一屏放不下18条，分页看——大按钮好戳
  if (pages > 1) {
    if (bondPage > 0) drawButton(BOND_PREV, "◀ 上一页", "#5a4a2a");
    if (bondPage < pages - 1) drawButton(BOND_NEXT, "下一页 ▶", "#5a4a2a");
    ctx.textAlign = "center";
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = "#c9b69a";
    ctx.fillText(`第 ${bondPage + 1} / ${pages} 页`, W / 2, 662);
  }
}
/* 名将录（留存方向3）：一面看得见的收集墙——六条进度，集满亮金 */
function drawDexTab() {
  const H0 = GENERALS;
  const lvSum = H0.reduce((a, g) => a + heroLv(g.id), 0);
  const rows = [
    { icon: "👑", name: "满级名将", cur: H0.filter(g => heroLv(g.id) >= HERO_LV_MAX).length, max: H0.length, hint: "练到30级满级" },
    { icon: "⭐", name: "登堂入室", cur: H0.filter(g => heroLv(g.id) >= 20).length, max: H0.length, hint: "练到20级镶银边" },
    { icon: "👑", name: "主公养成", cur: lordsTotal(), max: LORD_RULERS.length * LORD_LV_MAX, hint: "主公全员满级" },
    { icon: "🔗", name: "羁绊图录", cur: Object.keys(meta.bondsSeen || {}).length, max: BONDS.length, hint: "局内触发过的羁绊" },
    { icon: "🎖️", name: "群雄逐鹿", cur: Object.keys(meta.rulersUsed || {}).length, max: LORD_RULERS.length, hint: "用过的主公" },
    { icon: "🔄", name: "转生次数", cur: meta.rebirthTotal || 0, max: null, hint: "累计让英雄转生" },
  ];
  let y = 156;
  ctx.textAlign = "left";
  for (const r of rows) {
    const full = r.max != null && r.cur >= r.max;
    ctx.fillStyle = full ? "rgba(255,215,74,.1)" : "rgba(255,255,255,.05)";
    roundRect(12, y, W - 24, 64, 10); ctx.fill();
    ctx.strokeStyle = full ? "#ffd24a" : "rgba(120,110,90,.35)";
    ctx.lineWidth = full ? 2 : 1;
    roundRect(12, y, W - 24, 64, 10); ctx.stroke();
    ctx.font = "bold 17px sans-serif";
    ctx.fillStyle = full ? "#ffd24a" : "#e8dcc0";
    ctx.fillText(`${r.icon} ${r.name}`, 26, y + 26);
    ctx.font = "12px sans-serif";
    ctx.fillStyle = "#8a7d5a";
    ctx.fillText(r.hint, 26, y + 47);
    ctx.textAlign = "right";
    ctx.font = "bold 19px sans-serif";
    ctx.fillStyle = full ? "#ffd24a" : "#9adf5a";
    ctx.fillText(r.max != null ? `${r.cur}/${r.max}${full ? " ✓" : ""}` : `${r.cur}`, W - 28, y + 28);
    if (r.max != null) {
      const bw = 150, bx = W - 28 - bw, by = y + 44;
      ctx.fillStyle = "rgba(0,0,0,.35)"; roundRect(bx, by, bw, 8, 4); ctx.fill();
      ctx.fillStyle = full ? "#ffd24a" : "#9adf5a";
      roundRect(bx, by, Math.max(4, bw * r.cur / r.max), 8, 4); ctx.fill();
    }
    ctx.textAlign = "left";
    y += 72;
  }
  ctx.textAlign = "center";
  ctx.font = "12.5px sans-serif";
  ctx.fillStyle = "#c9b69a";
  ctx.fillText(`英雄总等级 ${lvSum} / ${H0.length * HERO_LV_MAX} · 离全员满级还差 ${H0.length * HERO_LV_MAX - lvSum} 级`, W / 2, y + 8);
}
function drawShopDisc(g, cx, cy, r, dim) {
  ctx.globalAlpha = dim ? 0.38 : 1;
  ctx.fillStyle = "#3a3024";
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = RARITY[heroRarity(g.id)].color;
  ctx.lineWidth = 2.2;
  ctx.beginPath();
  ctx.arc(cx, cy, r, 0, Math.PI * 2);
  ctx.stroke();
  drawNameDisc(g.name, r, cx, cy + 1, heroLv(g.id) >= MILE_STAR2);
  const bo = Math.round(r * 0.88), br = Math.max(8, Math.min(11, Math.round(r * 0.5)));
  const prevBase = ctx.textBaseline;
  ctx.textBaseline = "middle";
  ctx.textAlign = "center";
  ctx.fillStyle = "rgba(20,14,6,.92)";
  ctx.beginPath();
  ctx.arc(cx + bo, cy - bo, br, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = CLASSES[g.cls].color;
  ctx.lineWidth = 1.8;
  ctx.beginPath();
  ctx.arc(cx + bo, cy - bo, br, 0, Math.PI * 2);
  ctx.stroke();
  ctx.font = `${br + 2}px sans-serif`;
  ctx.fillText(CLASSES[g.cls].icon, cx + bo, cy - bo + 1);
  {   // 三角属性角标（v7.14.2 全员画，和战场圆盘一致——克制时代属性人人有）
    ctx.fillStyle = "rgba(20,14,6,.92)";
    ctx.beginPath();
    ctx.arc(cx - bo, cy - bo, br - 1, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = ELEMENTS[g.elem].color;
    ctx.lineWidth = 1.8;
    ctx.beginPath();
    ctx.arc(cx - bo, cy - bo, br - 1, 0, Math.PI * 2);
    ctx.stroke();
    ctx.font = `${br}px sans-serif`;
    ctx.fillText(ELEMENTS[g.elem].icon, cx - bo, cy - bo + 1);
  }
  ctx.textBaseline = prevBase;
  ctx.globalAlpha = 1;
  // 等级荣誉镶边：20级银边、30级满级金边（练到顶一眼认出）
  if (!dim) {
    const hl = heroLv(g.id);
    if (hl >= MILE_STAR2 + 0 && (hl >= 20)) {
      ctx.strokeStyle = hl >= 30 ? "#ffd24a" : "#cfd6dc";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.arc(cx, cy, r + 3, 0, Math.PI * 2);
      ctx.stroke();
    }
  }
  const h = meta.heroes[g.id];
  if (h) drawRankBadge(h.lv, cx, cy + r - 2);
}
let shopDetail = null;   // 武将详情弹层：点头像打开，里面升级/设主将
const SHOP_DETAIL_BTN = { x: W / 2 - 110, y: 512, w: 220, h: 44 };   // 主将按钮退役后上移补位
const SHOP_RESET_BTN  = { x: W / 2 - 90,  y: 564, w: 180, h: 32 };   // 重置英雄（v7.8.0）：升错了反悔
// 二级确认弹窗（v7.8.0）：突破/转生消耗稀有石头、重置有代价，都要再点一次防手滑
let shopConfirm = null;   // { kind:"tupo"|"zhuansheng"|"reset", id }
const SHOP_CONFIRM_YES = { x: W / 2 - 108, y: 452, w: 100, h: 48 };
const SHOP_CONFIRM_NO  = { x: W / 2 + 8,   y: 452, w: 100, h: 48 };
function drawShopDetail() {
  const g = shopDetail, h = meta.heroes[g.id];
  const ult = ULTS[g.id];
  const rar = RARITY[heroRarity(g.id)];
  ctx.fillStyle = "rgba(12,9,4,.88)";
  ctx.fillRect(0, 0, W, H);
  const rc = { x: 26, y: 168, w: W - 52, h: 452 };
  ctx.fillStyle = "#241c10";
  roundRect(rc.x, rc.y, rc.w, rc.h, 16);
  ctx.fill();
  ctx.strokeStyle = rar.color;
  ctx.lineWidth = 2.5;
  roundRect(rc.x, rc.y, rc.w, rc.h, 16);
  ctx.stroke();
  // 头像 + 名字 + 稀有度
  drawShopDisc(g, rc.x + 62, rc.y + 66, 36, !h);
  ctx.textAlign = "left";
  ctx.font = "bold 26px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = rar.color;
  ctx.fillText(shenName(g.id, g.name), rc.x + 116, rc.y + 56);
  ctx.font = "14px sans-serif";
  ctx.fillStyle = "#d5c9a8";
  ctx.fillText(`${CLASSES[g.cls].icon}${CLASSES[g.cls].name} · ${ELEMENTS[g.elem].icon}${ELEMENTS[g.elem].name}系 · ${rangeText(g)}`, rc.x + 116, rc.y + 82);
  ctx.textAlign = "right";
  ctx.font = "bold 14px sans-serif";
  ctx.fillStyle = rar.color;
  ctx.fillText(rar.name, rc.x + rc.w - 16, rc.y + 30);
  if (isShen(g.id)) {   // 本期神将：品质下面再挂一行金字，升级动机+天命补偿写明白
    const gift = SHEN_GIFT_STARS[heroRarity(g.id)] || 0;
    ctx.font = "bold 12px sans-serif";
    ctx.fillStyle = "#ffd24a";
    ctx.fillText(`👼本期神将·加成翻倍${gift ? `·登场+${gift}星` : ""}`, rc.x + rc.w - 16, rc.y + 50);
  } else {
    // 嫡系（v5.8）：写明是谁家的人、跟他出征有什么好处
    const kl = kinLordOf(g.id);
    if (kl) {
      const kg = heroRarity(g.id) === "common" || heroRarity(g.id) === "uncommon" ? 2 : 1;
      ctx.font = "bold 12px sans-serif";
      ctx.fillStyle = "#8ad2ff";
      ctx.fillText(`🤝${kl.name}家亲军·跟他出征登场+${kg}星`, rc.x + rc.w - 16, rc.y + 50);
    }
  }
  // 分隔线
  ctx.strokeStyle = "rgba(255,255,255,.14)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(rc.x + 16, rc.y + 108);
  ctx.lineTo(rc.x + rc.w - 16, rc.y + 108);
  ctx.stroke();
  // 等级：金币升，跨赛季保留；10/20级要突破石、满上限花突破石转生（5/8/12颗，上限+10，最多3转）
  ctx.textAlign = "left";
  ctx.font = "bold 15px sans-serif";
  ctx.fillStyle = "#ffd24a";
  ctx.fillText(`📈 等级：${h.lv}/${heroCap(g.id)}${heroRb(g.id) ? `·${heroRb(g.id)}转` : ""}（攻血+${((heroLvMul(g.id) - 1) * 100).toFixed(1)}%${isShen(g.id) ? "·神将加持中" : ""}）`, rc.x + 20, rc.y + 138);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#c9b69a";
  {
    const gate = h.lv < heroCap(g.id) ? heroGateStones(h.lv) : 0;
    ctx.fillText(h.lv >= heroCap(g.id)
      ? (heroRb(g.id) >= HERO_RB_MAX ? "三转满级——真·完全体" : `满上限了：转生可把上限提到 ${heroCap(g.id) + 10}（要${RB_STONES[heroRb(g.id)]}颗🪨，寻访能拿）`)
      : gate ? `${h.lv}级是道坎：突破要 ${gate}🪨（现有${itemN("tupo")}）+ ${heroUpCost(h.lv + 1, g.id)}💰`
      : `升下一级要 ${heroUpCost(h.lv + 1, g.id)}💰${(h.xp || 0) > 0 ? `（寻访经验已攒 ${h.xp}）` : ""} · 等级永远保留`, rc.x + 20, rc.y + 162);
  }
  // 等级里程碑链：显示已解锁数 + 下一站（还差N级），给养成一个看得见的钩子
  {
    const ml = h.lv;
    const done = MILES.filter(m => ml >= m.lv).length;
    const next = MILES.find(m => ml < m.lv);
    ctx.font = "11.5px sans-serif";
    ctx.fillStyle = next ? "#8ad2ff" : "#ffd24a";
    ctx.fillText(next ? `⭐里程碑 ${done}/${MILES.length} · 下一站 ${next.lv}级 ${next.txt}（还差${next.lv - ml}级）` : `⭐里程碑 ${MILES.length}/${MILES.length}·完全体`, rc.x + 20, rc.y + 182);
  }
  // 打法
  ctx.font = "bold 15px sans-serif";
  ctx.fillStyle = "#9adf5a";
  ctx.fillText("⚔️ 打法", rc.x + 20, rc.y + 196);
  ctx.font = "14px sans-serif";
  ctx.fillStyle = "#e8dcc0";
  ctx.fillText(g.desc, rc.x + 20, rc.y + 220);
  // 大招
  ctx.font = "bold 15px sans-serif";
  ctx.fillStyle = "#ffb84a";
  ctx.fillText(`💥 大招「${ult.name}」`, rc.x + 20, rc.y + 254);
  ctx.font = "14px sans-serif";
  ctx.fillStyle = "#e8dcc0";
  ctx.fillText(ult.desc, rc.x + 20, rc.y + 278);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#c9b69a";
  ctx.fillText(`什么时候放：${ult.condDesc} · ${ult.cd}秒转好`, rc.x + 20, rc.y + 300);
  // 升级/突破/转生按钮（三态）
  ctx.textAlign = "center";
  if (h.lv < heroCap(g.id)) {
    const cost = heroUpCost(h.lv + 1, g.id), gate = heroGateStones(h.lv);
    const ok = meta.gold >= cost && (!gate || itemN("tupo") >= gate);
    drawButton(SHOP_DETAIL_BTN, gate ? `🪨 突破到 ${h.lv + 1} 级（${gate}突破石+${cost}💰）` : `📈 升到 ${h.lv + 1} 级 ${cost}💰`, ok ? (gate ? "#4a3a5a" : "#2a5a3a") : "#3a3228");
  } else if (heroRb(g.id) < HERO_RB_MAX) {
    drawButton(SHOP_DETAIL_BTN, `♻️ 转生（${RB_STONES[heroRb(g.id)]}颗🪨·现有${itemN("tupo")}）上限+10`, itemN("tupo") >= RB_STONES[heroRb(g.id)] ? "#5a2a5a" : "#3a3228");
  } else {
    ctx.font = "bold 15px sans-serif";
    ctx.fillStyle = "#5ae8ff";
    ctx.fillText("🏅 三转满级 · 真完全体", W / 2, SHOP_DETAIL_BTN.y + 30);
  }
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("点空白处关闭", W / 2, rc.y + rc.h - 10);
  // 重置英雄（v7.8.0）：练过或转生过才有得退，才画这个钮
  if (heroResetPreview(g.id)) {
    drawButton(SHOP_RESET_BTN, "♻️ 重置英雄（退回金币和石头）", "#5a3626");
  }
  // 弹层里操作的反馈画在卡片下方，不然被盖住看不见
  if (shopMsg && performance.now() < shopMsg.until) {
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = "#ffd24a";
    ctx.fillText(shopMsg.text, W / 2, rc.y + rc.h + 32);
  }
  if (shopConfirm) drawShopConfirm();
}
/* 二级确认弹窗（v7.8.0）：突破/转生用稀有石头、重置有代价，弹一层"再想想"防手滑连点 */
function drawShopConfirm() {
  const g = shopDetail, h = meta.heroes[shopConfirm.id];
  ctx.fillStyle = "rgba(6,4,2,.82)";
  ctx.fillRect(0, 0, W, H);
  const bw = 316, bh = 210, bx = W / 2 - bw / 2, by = 300;
  ctx.fillStyle = "#2a2016";
  roundRect(bx, by, bw, bh, 16); ctx.fill();
  ctx.strokeStyle = "#e8c86a"; ctx.lineWidth = 2.5;
  roundRect(bx, by, bw, bh, 16); ctx.stroke();
  ctx.textAlign = "center";
  let title = "", lines = [], yes = "确定", yesColor = "#2a5a3a";
  if (shopConfirm.kind === "tupo") {
    const gate = heroGateStones(h.lv);
    title = "🪨 确认突破？";
    lines = [`要花 ${gate} 颗突破石 + ${heroUpCost(h.lv + 1, g.id)}💰`, `突破到 ${h.lv + 1} 级`, "突破石很稀有——寻访才能攒", "（升错了可以「重置英雄」退回）"];
    yes = "确定突破"; yesColor = "#4a3a5a";
  } else if (shopConfirm.kind === "zhuansheng") {
    title = "♻️ 确认转生？";
    lines = [`要花 ${RB_STONES[heroRb(g.id)]} 颗突破石`, "等级上限 +10，当前等级不变", "越往后转越金贵：5/8/12 颗", "（升错了可以「重置英雄」退回）"];
    yes = "确定转生"; yesColor = "#5a2a5a";
  } else {
    const pv = heroResetPreview(shopConfirm.id) || { gold: 0, stones: 0 };
    title = `♻️ 重置 ${g.name}？`;
    const back = [`${pv.gold}💰`].concat(pv.stones ? [`${pv.stones}颗突破石`] : []).join(" + ");
    lines = [`退回：${back}`, "等级回到 1 级、转生清零", "寻访攒的经验也一并清空", "想清楚，这一下全推倒重来"];
    yes = "确定重置"; yesColor = "#5a3626";
  }
  ctx.font = "bold 19px sans-serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(title, W / 2, by + 34);
  ctx.font = "13.5px sans-serif";
  ctx.fillStyle = "#e8dcc0";
  lines.forEach((ln, i) => ctx.fillText(ln, W / 2, by + 62 + i * 22));
  drawButton(SHOP_CONFIRM_YES, yes, yesColor);
  drawButton(SHOP_CONFIRM_NO, "再想想", "#4a4436");
}
function drawShopOverlay() {
  ctx.fillStyle = "rgba(20,14,6,.96)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  ctx.font = "bold 24px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText("📖 英雄图鉴 📖", W / 2, 44);
  drawButton(SHOP_BACK, "🏠", "#5a4a3a");
  ctx.font = "bold 14px sans-serif";
  ctx.fillStyle = "#ffb84a";
  ctx.fillText(`💰 金币：${meta.gold}　⚡战力 ${deckPower()}`, W / 2, 68);
  // 提示条：动作反馈 > 平时讲规则
  ctx.font = "13px sans-serif";
  if (shopMsg && performance.now() < shopMsg.until) {
    ctx.fillStyle = "#ffd24a";
    ctx.fillText(shopMsg.text, W / 2, 96);
  } else {
    ctx.fillStyle = "#8a7d5a";
    ctx.fillText(shopTab === "bond" ? "成员同一局一起上阵，羁绊就生效——等级越高成员越猛"
      : `开局和局内三选一都从全图鉴${GENERALS.length}人随机 · 点头像升级（等级永远保留）`, W / 2, 96);
  }
  // 双页签
  drawButton(SHOP_TAB_HERO, shopTab === "hero" ? "📖 英雄◂" : "📖 英雄", shopTab === "hero" ? "#6a4a2a" : "#3a3226");
  drawButton(SHOP_TAB_BOND, shopTab === "bond" ? "🔗 羁绊◂" : "🔗 羁绊", shopTab === "bond" ? "#6a4a2a" : "#3a3226");
  drawButton(SHOP_TAB_DEX,  shopTab === "dex"  ? "📜 名将录◂" : "📜 名将录", shopTab === "dex" ? "#6a4a2a" : "#3a3226");
  if (shopTab === "bond") { drawBondTab(); return; }
  if (shopTab === "dex")  { drawDexTab(); return; }
  const order = codexOrder();
  order.forEach((g, i) => {
    const rc = shopCellRect(i);
    const cx = rc.x + rc.w / 2, cy = rc.y + 26;
    drawShopDisc(g, cx, cy, 21, false);
    ctx.font = "12px sans-serif";
    ctx.fillStyle = isShen(g.id) ? "#ffd24a" : "#c9b69a";
    ctx.fillText(shopCellSub(g), cx, cy + 35);
  });

  if (shopDetail) drawShopDetail();
}

function shopClick(p) {
  if (inBtn(p, SHOP_BACK)) { showShop = false; shopMsg = null; shopTab = "hero"; shopConfirm = null; bondPage = 0; return; }
  if (!shopDetail && inBtn(p, SHOP_TAB_HERO)) { shopTab = "hero"; return; }
  if (!shopDetail && inBtn(p, SHOP_TAB_BOND)) { shopTab = "bond"; bondPage = 0; return; }
  if (!shopDetail && inBtn(p, SHOP_TAB_DEX))  { shopTab = "dex"; return; }
  // 羁绊页翻页（v7.9.0）：只看不点，但翻页钮要响应
  if (shopTab === "bond" && !shopDetail) {
    const pages = Math.ceil(BONDS.length / BOND_PAGE_N);
    if (bondPage > 0 && inBtn(p, BOND_PREV)) { bondPage--; SFX.pick(); return; }
    if (bondPage < pages - 1 && inBtn(p, BOND_NEXT)) { bondPage++; SFX.pick(); return; }
    return;
  }
  if (shopTab === "dex" && !shopDetail) return;   // 名将录只看不点
  // 详情弹层开着：升级/突破/转生/重置留在弹层里连点，点别处关闭
  if (shopDetail) {
    const g = shopDetail;
    const h = meta.heroes[g.id];
    // 二级确认弹窗开着：只认「确定」和「再想想」，点别处也当取消
    if (shopConfirm) {
      if (inBtn(p, SHOP_CONFIRM_YES)) {
        const kind = shopConfirm.kind;
        shopConfirm = null;
        if (kind === "tupo") {
          const gate0 = heroGateStones(h.lv);
          if (!heroUp(g.id)) { shopSay(`突破没成——石头或金币不够`); return; }
          SFX.buff();
          shopSay(`🪨 突破！${g.name} 破关升到 ${h.lv} 级（用了${gate0}突破石）`);
        } else if (kind === "zhuansheng") {
          if (!heroRebirth(g.id)) { shopSay("转生没成——突破石不够"); return; }
          SFX.relic();
          shopSay(`♻️ ${g.name} ${heroRb(g.id)}转！等级上限 ${heroCap(g.id)}，接着练`);
        } else if (kind === "reset") {
          const pv = heroReset(g.id);
          if (!pv) { shopSay("这个英雄没啥好重置的"); return; }
          SFX.relic();
          shopSay(`♻️ ${g.name} 已重置：退回 ${pv.gold}💰${pv.stones ? `+${pv.stones}突破石` : ""}`);
        }
        return;
      }
      shopConfirm = null;   // 再想想 / 点别处 = 取消
      return;
    }
    if (inBtn(p, SHOP_DETAIL_BTN)) {
      if (h.lv < heroCap(g.id)) {
        const cost = heroUpCost(h.lv + 1, g.id), gate = heroGateStones(h.lv);
        if (gate) {   // 突破：消耗突破石，先弹二级确认（v7.8.0 防手滑连点把仅有的突破石用掉）
          if (itemN("tupo") < gate) { shopSay(`突破要 ${gate}🪨（现有${itemN("tupo")}）——去寻访里拿`); return; }
          if (meta.gold < cost) { shopSay(`金币不够（要 ${cost}💰，打仗能赚）`); return; }
          shopConfirm = { kind: "tupo", id: g.id };
          return;
        }
        if (!heroUp(g.id)) { shopSay(`金币不够（要 ${cost}💰，打仗能赚）`); return; }
        SFX.buff();
        shopSay(`📈 ${g.name} 升到 ${h.lv} 级！攻血+${((h.lv - 1) * HERO_LV_BONUS * 100).toFixed(1)}%`);
        return;
      }
      if (heroRb(g.id) < HERO_RB_MAX) {   // 转生：花突破石（5/8/12按转数），也弹二级确认
        const need = RB_STONES[heroRb(g.id)];
        if (itemN("tupo") < need) { shopSay(`转生要 ${need}🪨（现有${itemN("tupo")}）——去寻访里攒`); return; }
        shopConfirm = { kind: "zhuansheng", id: g.id };
        return;
      }
      return;
    }
    if (inBtn(p, SHOP_RESET_BTN) && heroResetPreview(g.id)) {   // 重置英雄：先弹确认
      shopConfirm = { kind: "reset", id: g.id };
      return;
    }
    shopDetail = null;
    return;
  }
  // 网格区：点头像看详情（主将排在前，索引要走图鉴排序）
  const order = codexOrder();
  for (let i = 0; i < order.length; i++) {
    if (inBtn(p, shopCellRect(i))) {
      shopDetail = order[i];
      SFX.pick();
      return;
    }
  }
}

/* ---------- 主公府（v5.0，替代兵法研究页）：养成一览——等级/经验、招牌技、兵书被动、专属机制、定位。
   没有升级按钮：主公经验由战斗结算产出（带谁出征谁涨，后续寻访再加渠道），练哪位=多带哪位打 ---------- */
/* 主公府翻页（v5.6 八主公）：一页4位，右上角翻页钮 */
let lordPage = 0;
const LORD_PAGE_N = 4;
const TECH_PAGE_BTN = { x: W - 122, y: 26, w: 108, h: 32 };
function lordHouseRect(i) { return { x: 12, y: 112 + i * 128, w: W - 24, h: 120 }; }
function drawTechOverlay() {
  ctx.fillStyle = "rgba(20,14,6,.95)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  ctx.font = "bold 26px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText("👑 主公府 👑", W / 2, 50);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#d5c9a8";
  ctx.fillText("带谁出征谁涨经验——升级涨招牌技威力、解锁兵书被动", W / 2, 78);
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("各管一类题面，被动只在带他的局里生效——换着用别偏科", W / 2, 98);
  const nPages = Math.ceil(LORD_RULERS.length / LORD_PAGE_N);
  lordPage = Math.min(lordPage, nPages - 1);
  if (nPages > 1) drawButton(TECH_PAGE_BTN, `第${lordPage + 1}/${nPages}页 ➡`, "#5a4a3a");
  LORD_RULERS.slice(lordPage * LORD_PAGE_N, (lordPage + 1) * LORD_PAGE_N).forEach((rl, i) => {
    const rc = lordHouseRect(i);
    const lv = lordLv(rl.id), xp = lordXpNow(rl.id), need = lordXpNeed(lv);
    const sk = LORDS[rl.skill];
    ctx.fillStyle = "rgba(255,255,255,.05)";
    roundRect(rc.x, rc.y, rc.w, rc.h, 12);
    ctx.fill();
    ctx.strokeStyle = lv >= LORD_LV_MAX ? "#ffd24a" : "#5a4a2a";
    ctx.lineWidth = 1.6;
    roundRect(rc.x, rc.y, rc.w, rc.h, 12);
    ctx.stroke();
    drawNameDisc(rl.name, 24, rc.x + 36, rc.y + 42, lv >= 10);
    ctx.textAlign = "left";
    ctx.font = "bold 15px 'Kaiti SC', 'STKaiti', serif";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(`${rl.name}·${rl.title}`, rc.x + 70, rc.y + 22);
    ctx.font = "bold 13px sans-serif";
    ctx.fillStyle = lv >= LORD_LV_MAX ? "#ffd24a" : "#9adf5a";
    ctx.fillText(lv >= LORD_LV_MAX ? `Lv.${lv}（满级）` : `Lv.${lv}`, rc.x + 70, rc.y + 42);
    if (lv < LORD_LV_MAX) {   // 经验条：下一级还差多少一眼看到
      ctx.fillStyle = "rgba(255,255,255,.12)";
      roundRect(rc.x + 140, rc.y + 33, 130, 9, 4);
      ctx.fill();
      ctx.fillStyle = "#9adf5a";
      roundRect(rc.x + 140, rc.y + 33, Math.max(3, 130 * Math.min(1, xp / need)), 9, 4);
      ctx.fill();
      ctx.font = "10px sans-serif";
      ctx.fillStyle = "#8a7d5a";
      ctx.fillText(`${xp}/${need}`, rc.x + 276, rc.y + 41);
    }
    ctx.font = "12.5px sans-serif";
    ctx.fillStyle = "#8ad2ff";
    ctx.fillText(`${sk.icon}${sk.name}（${lordSkillLv(rl.id)}星）${sk.desc(lordSkillLv(rl.id))}`, rc.x + 14, rc.y + 64);
    // 被动：当前级/满级，没解锁的灰——下一本什么时候开写在等级门槛里
    ctx.font = "12px sans-serif";
    let px = rc.x + 14;
    for (const ps of rl.passives) {
      const t = TECHS.find(x => x.id === ps.id);
      const plv = ps.at.filter(a => lv >= a).length;
      const nxt = ps.at.find(a => lv < a);
      ctx.fillStyle = plv ? "#e8c86a" : "rgba(200,190,160,.4)";
      const s = `${t.icon}${t.name.slice(0, 2)}${plv}${nxt ? `(${nxt}级+1)` : ""}`;
      ctx.fillText(s, px, rc.y + 84);
      px += ctx.measureText(s).width + 10;
    }
    ctx.font = "11.5px sans-serif";
    if (rl.special) {
      const sp = LORD_SPECIALS[rl.special];
      ctx.fillStyle = "#ffd24a";
      const sp2 = rl.special2 ? LORD_SPECIALS[rl.special2] : null;
      ctx.fillText(`${sp.icon}${sp.name}：${sp.desc(rl.id)}${sp2 ? `　${sp2.icon}${sp2.name}` : ""}`, rc.x + 14, rc.y + 105);
    } else {
      ctx.fillStyle = "#9a8f70";
      const d = rl.desc, cut = d.indexOf("——");
      ctx.fillText(cut > 0 ? d.slice(0, cut) : d, rc.x + 14, rc.y + 105);
    }
    ctx.textAlign = "center";
  });
  ctx.font = "bold 15px sans-serif";
  ctx.fillStyle = "#fff";
  ctx.fillText("👆 点击底部返回", W / 2, H - 30);
}
function techClick(p) {
  if (inBtn(p, TECH_PAGE_BTN)) {
    lordPage = (lordPage + 1) % Math.ceil(LORD_RULERS.length / LORD_PAGE_N);
    SFX.pick();
    return;
  }
  if (p.y > H - 90) showTech = false;
}

/* ---------- 寻访（v5.1 大富翁掷骰）：花1块令牌掷骰走格，落格拿奖——金币/英雄经验/主公经验/
   突破石(石矿)/大礼包/奇遇黄历卡。棋盘20格环形，构成固定配比、摆位每周换；站的格子跨局保留。
   v7.17：格子亮化+点击弹详情、令牌格退役换成每次落格5%再寻一次、奇遇改发30分钟黄历BUFF卡 ---------- */
const VISIT_N = 20;
const VISIT_BACK = { x: 14, y: 22, w: 76, h: 34 };
const VISIT_ROLL = { x: W / 2 - 84, y: 304, w: 168, h: 54 };   // v7.17.2 上移：盘心只留它和令牌数
const hexA = (hex, a) => `rgba(${parseInt(hex.slice(1, 3), 16)},${parseInt(hex.slice(3, 5), 16)},${parseInt(hex.slice(5, 7), 16)},${a})`;   // #rrggbb→rgba
const VISIT_CELL_TYPES = {   // tint=格子底色/描边（v7.17 亮化），desc=点格子弹的详情
  gold:  { icon: "💰", name: "赏金",     tint: "#ffd24a", desc: ["落这格得金币 150~400"] },
  hxp:   { icon: "⚔️", name: "名将指点", tint: "#ff9a5a", desc: ["随机一位英雄白得 250~600 经验", "攒够自动升级（10/20级停下等突破）"] },
  lxp:   { icon: "👑", name: "君臣论道", tint: "#d9a6ff", desc: ["随机一位主公得 6~14 经验"] },
  tupo:  { icon: "🪨", name: "突破石",   tint: "#e8d9b0", desc: ["突破石 +1", "英雄过坎、满级转生都用它"] },
  kuang: { icon: "⛏️", name: "石矿",     tint: "#6ae8ff", desc: ["一镐下去：突破石 +3", "过坎小额、转生大额（5/8/12颗）", "全靠攒它"] },
  luck:  { icon: "📜", name: "奇遇",     tint: "#9adf5a", desc: ["翻一页黄历，得一张奇遇卡：", "30分钟限时加成（积分/金币/再寻）", "再翻到同一张，时长叠上去"] },
  gift:  { icon: "🎁", name: "大礼包",   tint: "#ff8a3a", desc: ["一格顶好几格，一次全给：", "金币×3 + 英雄经验×1.5 + 主公经验×1.5", "外加稀罕物：🪨一颗五成/🧭令牌三成/🪨三颗两成"] },
};
/* 黄历奇遇卡（v7.17 寻访钩子）：走到奇遇格随机翻一张，30分钟限时加成，重复翻同一张=时长叠加。
   到期时间戳存 meta.visitBuffs（跟账号走），战斗里实时判 visitBuffOn */
const VISIT_BUFF_DUR = 30 * 60e3;
const VISIT_BUFFS = [
  { id: "score", icon: "🏅", name: "宜征伐", short: "战斗积分 +20%", desc: ["30分钟内打仗记下的讨伐值 ×1.2", "（通关后接着打讨伐，撑的波更值钱）"] },
  { id: "gold",  icon: "💰", name: "宜求财", short: "杀敌金币 +20%", desc: ["30分钟内杀敌掉的金币 ×1.2", "（只算打仗的钱，广告成就不算）"] },
  { id: "again", icon: "🎲", name: "宜出行", short: "再寻概率 5%→20%", desc: ["30分钟内寻访落格后", "两成机会白掷一次（不花令牌）"] },
];
function visitBuffOn(id) { return ((meta.visitBuffs || {})[id] || 0) > Date.now(); }
const VISIT_AGAIN_P = 0.05;   // 每次落格的"再寻一次"基础概率（宜出行黄历期间0.2）
let visitPop = null;          // 寻访页弹窗：{ cell: 类型 } 或 { buff: id }
let _visitChipRc = [];        // 黄历卡chip点击区（每帧重建）
var _visitBoard = { week: -1, cells: null };
function visitBoard() {
  const wk = trialWeekNow();
  if (_visitBoard.week === wk) return _visitBoard.cells;
  const bag = ["gold", "gold", "gold", "gift", "gift", "hxp", "hxp", "hxp", "hxp",
    "lxp", "lxp", "lxp", "lxp", "luck", "luck", "luck", "luck", "tupo", "tupo", "kuang"];   // v7.17：令牌格退役（换成5%再寻一次），奇遇2→4当黄历钩子，转生石格改石矿(+3🪨)
  _visitBoard = { week: wk, cells: shuffledBy(mulberry32(wk * 771 + 21), bag) };
  return _visitBoard.cells;
}
function visitCellPos(i) {
  const T = 168, B = 566, L = 42, R = W - 42;   // 6上+4右+6下+4左=20格环形
  if (i <= 5) return { x: L + (R - L) * i / 5, y: T };
  if (i <= 9) return { x: R, y: T + (B - T) * (i - 5) / 5 };
  if (i <= 15) return { x: R - (R - L) * (i - 10) / 5, y: B };
  return { x: L, y: B - (B - T) * (i - 15) / 5 };
}
const vroll = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
/* 落格结算：经验类要按用户要求提示"从多少到多少"，升级则隆重（大横幅） */
function visitResolve(type) {
  const lines = [];
  let banner = null;
  const heroXpGive = (mul) => {
    const cand = GENERALS.filter(g => heroLv(g.id) < HERO_LV_MAX + HERO_RB_MAX * 10);
    if (!cand.length) return goldGive(1);
    const g = cand[Math.floor(Math.random() * cand.length)];
    const amt = Math.round(vroll(250, 600) * mul);
    const r = addHeroXp(g.id, amt);
    if (r.to > r.from) banner = `🎉 ${g.name} 升级！Lv.${r.from} → Lv.${r.to}`;
    lines.push(`⚔️ ${g.name} 经验 +${amt}${r.to > r.from ? `（升到 Lv.${r.to}！）` : `：${r.xp0}→${r.xp}（升 Lv.${r.to + 1} 需 ${r.need}）`}`);
  };
  const lordXpGive = (mul) => {
    const cand = LORD_RULERS.filter(r => lordLv(r.id) < LORD_LV_MAX);
    if (!cand.length) return goldGive(1);
    const rl = cand[Math.floor(Math.random() * cand.length)];
    const amt = Math.round(vroll(6, 14) * mul);
    const from = lordLv(rl.id), xp0 = lordXpNow(rl.id);
    lordAddXp(meta, rl.id, amt);
    if (lordLv(rl.id) > from) banner = `🎉 主公 ${rl.name} 升级！Lv.${from} → Lv.${lordLv(rl.id)}`;
    lines.push(`👑 ${rl.name} 主公经验 +${amt}${lordLv(rl.id) > from ? `（升到 Lv.${lordLv(rl.id)}！）` : `：${xp0}→${lordXpNow(rl.id)}（升 Lv.${from + 1} 需 ${lordXpNeed(from)}）`}`);
  };
  const goldGive = (mul) => {
    const g = Math.round(vroll(150, 400) * mul);
    earnGold(g);
    lines.push(`💰 金币 +${g}`);
  };
  if (type === "gold") goldGive(1);
  else if (type === "hxp") heroXpGive(1);
  else if (type === "lxp") lordXpGive(1);
  else if (type === "tupo") { addItem("tupo", 1); lines.push("🪨 突破石 +1（10/20级突破用）"); }
  else if (type === "kuang") { addItem("tupo", 3); lines.push("⛏️ 挖到石矿！突破石 +3"); }
  else if (type === "gift") {   // 惊喜格：金币+双经验+稀罕物一次全给，一格顶好几格
    goldGive(3);
    heroXpGive(1.5);
    lordXpGive(1.5);
    const r100 = vroll(1, 100);
    if (r100 <= 20) { addItem("tupo", 3); lines.push("🪨 突破石 +3！大块头"); }
    else if (r100 <= 70) { addItem("tupo", 1); lines.push("🪨 突破石 +1"); }
    else { addItem("visitToken", 1); lines.push("🧭 寻访令牌 +1"); }
  }
  else if (type === "luck") {   // 奇遇：翻黄历得一张30分钟限时BUFF卡（v7.17 寻访钩子），重复翻叠时长
    const b = VISIT_BUFFS[vroll(0, VISIT_BUFFS.length - 1)];
    meta.visitBuffs ||= {};
    meta.visitBuffs[b.id] = Math.max(Date.now(), meta.visitBuffs[b.id] || 0) + VISIT_BUFF_DUR;
    lines.push(`📜 翻开黄历——今日「${b.name}」！`);
    lines.push(`${b.icon} ${b.short}（30分钟，再翻叠时长）`);
  }
  return { lines, banner };
}
function visitRoll(free) {   // free=再寻一次（不花令牌，落格后5%/黄历20%触发）
  if (visit && visit.steps > 0) return;   // 走格中别连点
  if (!free) {
    if (itemN("visitToken") < 1) { visit = { steps: 0, lines: ["令牌不够——去打一场，通关就有"], banner: null }; return; }
    addItem("visitToken", -1);
  }
  const dice = vroll(1, 6);
  visit = { steps: dice, dice, lastStep: performance.now(), lines: [free ? `🎲 再寻一次！掷出 ${dice} 点` : `🎲 掷出 ${dice} 点`], banner: null };
  SFX.pick();
}
function drawVisitOverlay() {
  ctx.fillStyle = "#150e06";   // 全不透明：寻访页元素多，首页透上来就是一锅粥（v7.17.1 排版修）
  ctx.fillRect(0, 0, W, H);
  // 走格动画：每140ms挪一格，走完落格结算
  if (visit && visit.steps > 0 && performance.now() - visit.lastStep > 140) {
    visit.lastStep = performance.now();
    meta.visitPos = (meta.visitPos + 1) % VISIT_N;
    visit.steps--;
    SFX.pick();
    if (visit.steps === 0) {
      const type = visitBoard()[meta.visitPos];
      const r = visitResolve(type);
      visit.hit = type;
      visit.fxT = performance.now();
      visit.lines = [`🎲 ${visit.dice} 点 → ${VISIT_CELL_TYPES[type].icon} ${VISIT_CELL_TYPES[type].name}`, ...r.lines];
      visit.banner = r.banner;
      // 落格庆祝：大礼包奏凯歌撒礼花，稀罕格亮风铃，日常格也给上扬和弦——别再平淡收场
      if (type === "gift") {
        SFX.win();
        visit.confetti = Array.from({ length: 46 }, () => ({
          x: Math.random() * W, y: -30 - Math.random() * 160,
          vy: 100 + Math.random() * 140, sway: 16 + Math.random() * 30, ph: Math.random() * 6.28,
          e: ["🎉", "✨", "🎊", "💰", "🎁"][Math.floor(Math.random() * 5)], s: 15 + Math.random() * 12,
        }));
      } else if (type === "kuang" || type === "luck") SFX.relic();
      else SFX.buff();
      if (visit.banner) SFX.levelUp();
      // 再寻一次：每次落格5%好手气（黄历「宜出行」期间两成），1.8秒后自动白掷一把
      if (Math.random() < (visitBuffOn("again") ? 0.2 : VISIT_AGAIN_P)) visit.reRollAt = performance.now() + 1800;
      achSweep();
      saveMeta();
    }
  }
  // 好手气到点：自动再掷（不花令牌）
  if (visit && visit.steps === 0 && visit.reRollAt && performance.now() >= visit.reRollAt) visitRoll(true);
  ctx.textAlign = "center";
  ctx.font = "bold 25px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText("🧭 寻访", W / 2, 48);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#d5c9a8";
  ctx.fillText("掷骰走格拿奖励——令牌靠通关攒（每天30场满额），格局每周一换", W / 2, 74);
  drawButton(VISIT_BACK, "🏠", "#5a4a3a");
  // 棋盘20格：一格一色亮出来（点格子弹详情）；大礼包格金边呼吸闪
  const cells = visitBoard();
  const giftPulse = 0.5 + 0.5 * Math.sin(performance.now() / 260);
  for (let i = 0; i < VISIT_N; i++) {
    const q = visitCellPos(i);
    const here = i === meta.visitPos;
    const ct = VISIT_CELL_TYPES[cells[i]];
    const gift = cells[i] === "gift";
    ctx.fillStyle = here ? "rgba(255,210,74,.28)" : hexA(ct.tint, 0.22);
    roundRect(q.x - 24, q.y - 24, 48, 48, 8);
    ctx.fill();
    ctx.strokeStyle = here ? "#ffd24a" : gift ? `rgba(255,185,60,${(0.5 + 0.5 * giftPulse).toFixed(2)})` : hexA(ct.tint, 0.9);
    ctx.lineWidth = here ? 2.8 : gift ? 2.4 : 1.6;
    roundRect(q.x - 24, q.y - 24, 48, 48, 8);
    ctx.stroke();
    ctx.font = gift ? "26px sans-serif" : "24px sans-serif";
    ctx.fillText(ct.icon, q.x, q.y + 3);
    if (here) { ctx.font = "16px sans-serif"; ctx.fillText("🚶", q.x, q.y + 21); }
  }
  // 盘心只留动作：令牌数 + 掷骰按钮（活跃/讨伐赏/黄历/广告全在棋盘下面，别挤在盘心）
  ctx.font = "bold 15px sans-serif";
  ctx.fillStyle = "#8ad2ff";
  ctx.fillText(`🧭 令牌 ×${itemN("visitToken")}`, W / 2, 290);
  drawButton(VISIT_ROLL, visit && visit.steps > 0 ? "🎲 ……" : visit && visit.reRollAt ? "🎲 好手气！再寻中……" : `🎲 掷骰子（1令牌）`, itemN("visitToken") > 0 ? "#6a4a2a" : "#3a3226");
  // —— 棋盘下面的信息区（v7.17.2 下沉重排）：活跃 / 讨伐赏 / 黄历卡 / 看广告 ——
  taofaSync();
  ctx.font = "bold 14px sans-serif";
  ctx.fillStyle = "#8ad2ff";
  ctx.fillText(`⚔️ 今日活跃 ${visitTodayN()}/${VISIT_DAILY}（通关就攒令牌）`, W / 2, 616);
  const tfFull = (meta.taofaGot || 0) >= TAOFA_TOKEN_DAILY;
  ctx.fillStyle = tfFull ? "#8a7d5a" : "#ffd24a";
  ctx.fillText(tfFull ? `🗡️ 讨伐赏 ${TAOFA_TOKEN_DAILY}/${TAOFA_TOKEN_DAILY}（今日已满）` : `🗡️ 讨伐赏 ${meta.taofaGot || 0}/${TAOFA_TOKEN_DAILY} · 点我看规则`, W / 2, 640);
  // 生效中的黄历卡：chip一排带倒计时，点开看详情；没有就给一句钩子
  _visitChipRc = [];
  const actB = VISIT_BUFFS.filter(b => visitBuffOn(b.id));
  if (actB.length) {
    const cw = 118, gap = 10, x0 = W / 2 - (actB.length * cw + (actB.length - 1) * gap) / 2;
    actB.forEach((b, i) => {
      const rc = { x: x0 + i * (cw + gap), y: 654, w: cw, h: 27 };
      _visitChipRc.push({ rc, id: b.id });
      ctx.fillStyle = "rgba(154,223,90,.13)";
      roundRect(rc.x, rc.y, rc.w, rc.h, 13);
      ctx.fill();
      ctx.strokeStyle = "#9adf5a";
      ctx.lineWidth = 1.4;
      roundRect(rc.x, rc.y, rc.w, rc.h, 13);
      ctx.stroke();
      const left = Math.max(0, (meta.visitBuffs[b.id] - Date.now()) / 1000);
      ctx.font = "bold 12px sans-serif";
      ctx.fillStyle = "#c9f0a0";
      ctx.fillText(`${b.icon}${b.name} ${Math.floor(left / 60)}:${("0" + Math.floor(left % 60)).slice(-2)}`, rc.x + rc.w / 2, rc.y + 18);
    });
  } else {
    ctx.font = "12.5px sans-serif";
    ctx.fillStyle = "#8a7d5a";
    ctx.fillText("📜 走到奇遇格翻黄历，能得30分钟的加成卡", W / 2, 671);
  }
  // 看广告拿钱（v7.17.2 从首页搬来：钱和寻访令都是这页的收成，恰饭入口放一起）
  const adLeft = AD_DAILY - adTodayN();
  ctx.globalAlpha = adLeft > 0 ? 1 : 0.45;
  drawButton(AD_BTN, adLeft > 0 ? `📺 看广告拿钱 +${AD_GOLD}💰（今日还剩${adLeft}次）` : "📺 今天的广告看完了，明天再来", "#2a4a5a");
  ctx.globalAlpha = 1;
  if (visit && visit.lines) {
    // 结果面板：收在棋盘左右两列之间（±170）、超宽行缩字号；落格瞬间亮边、奖励一行一行弹出来
    const rls = visit.lines.slice(0, 5);
    const lh = 20, y0 = 384, pw = 340;
    const now = performance.now();
    const glow = visit.fxT ? Math.max(0, 1 - (now - visit.fxT) / 900) : 0;
    ctx.fillStyle = "rgba(0,0,0,.55)";
    roundRect(W / 2 - pw / 2, y0 - 20, pw, rls.length * lh + 26, 10);
    ctx.fill();
    ctx.strokeStyle = visit.hit === "gift" ? `rgba(255,210,74,${(0.55 + 0.45 * glow).toFixed(2)})` : `rgba(200,170,100,${(0.3 + 0.55 * glow).toFixed(2)})`;
    ctx.lineWidth = visit.hit === "gift" ? 2.4 : 1.4;
    roundRect(W / 2 - pw / 2, y0 - 20, pw, rls.length * lh + 26, 10);
    ctx.stroke();
    rls.forEach((t, i) => {
      const a = visit.fxT ? Math.max(0, Math.min(1, (now - visit.fxT - i * 170) / 200)) : 1;
      if (a <= 0) return;
      let fs = 13.5;
      ctx.font = `bold ${fs}px sans-serif`;
      while (fs > 10.5 && ctx.measureText(t).width > pw - 24) { fs -= 0.5; ctx.font = `bold ${fs}px sans-serif`; }
      ctx.globalAlpha = a;
      ctx.fillStyle = i === 0 ? "#e2d3ac" : visit.hit === "gift" ? "#ffd76a" : "#9adf5a";
      ctx.fillText(t, W / 2, y0 + i * lh + (1 - a) * 8);
    });
    ctx.globalAlpha = 1;
  }
  // 落格特效：站的格子金圈迸开；大礼包再加满屏金光+大字+礼花雨
  if (visit && visit.fxT) {
    const t = (performance.now() - visit.fxT) / 1000;
    if (t < 0.75) {
      const q = visitCellPos(meta.visitPos);
      ctx.strokeStyle = `rgba(255,220,90,${(1 - t / 0.75).toFixed(2)})`;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(q.x, q.y, 26 + 70 * t, 0, Math.PI * 2);
      ctx.stroke();
    }
    if (visit.hit === "gift") {
      if (t < 0.9) {
        ctx.fillStyle = `rgba(255,210,74,${(0.26 * (1 - t / 0.9)).toFixed(3)})`;
        ctx.fillRect(0, 0, W, H);
      }
      if (t < 2.6) {
        const pop = 1 + 0.08 * Math.sin(t * 6);
        ctx.font = `bold ${Math.round(26 * pop)}px 'Kaiti SC', 'STKaiti', serif`;
        ctx.lineWidth = 4;
        ctx.strokeStyle = "rgba(90,50,0,.8)";
        ctx.strokeText("🎁 大礼包！好东西全都要！", W / 2, 262);
        ctx.fillStyle = "#ffe45a";
        ctx.fillText("🎁 大礼包！好东西全都要！", W / 2, 262);
      }
      if (visit.confetti && t < 2.8) {
        ctx.globalAlpha = Math.max(0, Math.min(1, 2.8 - t));
        visit.confetti.forEach(c => {
          ctx.font = `${Math.round(c.s)}px sans-serif`;
          ctx.fillText(c.e, c.x + Math.sin(c.ph + t * 2.6) * c.sway, c.y + c.vy * t);
        });
        ctx.globalAlpha = 1;
      }
    }
  }
  // 升级隆重横幅
  if (visit && visit.banner) {
    ctx.fillStyle = "rgba(20,14,6,.9)";
    roundRect(W / 2 - 190, 620, 380, 56, 12);
    ctx.fill();
    ctx.strokeStyle = "#ffd24a";
    ctx.lineWidth = 2.5;
    roundRect(W / 2 - 190, 620, 380, 56, 12);
    ctx.stroke();
    ctx.font = "bold 19px 'Kaiti SC', 'STKaiti', serif";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(visit.banner, W / 2, 655);
  }
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("点格子能看它给什么 · 每次落格有 5% 好手气再寻一次", W / 2, H - 40);
  // 详情弹窗：点格子看给什么 / 点黄历chip看加成和剩余时间 / 点讨伐赏看规则
  if (visitPop) {
    const isBuff = !!visitPop.buff, isTaofa = !!visitPop.taofa;
    const c = isTaofa
      ? { icon: "🗡️", name: "讨伐赏", tint: "#ffd24a", desc: ["通关后接着打讨伐（无尽），撑得越深令牌越多：", `每座城每天只认当日最深的一役`, `讨伐每多撑 ${TAOFA_STEP} 波 = +${TAOFA_STEP_TOKENS} 块令牌（当场发）`, `深刷一城、广刷几城都行——全天封顶 ${TAOFA_TOKEN_DAILY} 块`, `今日进度 ${meta.taofaGot || 0}/${TAOFA_TOKEN_DAILY}，明天 0 点重开`] }
      : isBuff ? VISIT_BUFFS.find(b => b.id === visitPop.buff) : VISIT_CELL_TYPES[visitPop.cell];
    if (!c) { visitPop = null; return; }
    const rows = isBuff ? [c.short, ...c.desc] : c.desc;
    ctx.fillStyle = "rgba(0,0,0,.6)";
    ctx.fillRect(0, 0, W, H);
    const bh = 148 + rows.length * 24, by = H / 2 - bh / 2 - 50;
    ctx.fillStyle = "rgba(30,22,10,.97)";
    roundRect(W / 2 - 165, by, 330, bh, 14);
    ctx.fill();
    ctx.strokeStyle = isBuff ? "#9adf5a" : (c.tint || "#e8c86a");
    ctx.lineWidth = 2;
    roundRect(W / 2 - 165, by, 330, bh, 14);
    ctx.stroke();
    ctx.font = "38px sans-serif";
    ctx.fillText(c.icon, W / 2, by + 52);
    ctx.font = "bold 19px 'Kaiti SC', 'STKaiti', serif";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(isTaofa ? "🗡️ 讨伐赏" : isBuff ? `黄历·${c.name}` : c.name, W / 2, by + 88);
    ctx.font = "13.5px sans-serif";
    ctx.fillStyle = "#d5c9a8";
    rows.forEach((t, i) => ctx.fillText(t, W / 2, by + 116 + i * 24));
    if (isBuff) {
      const left = Math.max(0, ((meta.visitBuffs || {})[c.id] || 0) - Date.now()) / 1000;
      ctx.fillStyle = left > 0 ? "#9adf5a" : "#8a7d5a";
      ctx.fillText(left > 0 ? `⏳ 还剩 ${Math.floor(left / 60)} 分 ${Math.floor(left % 60)} 秒` : "已过期", W / 2, by + 116 + rows.length * 24);
    }
    ctx.fillStyle = "#8a7d5a";
    ctx.font = "12px sans-serif";
    ctx.fillText("点一下关闭", W / 2, by + bh - 14);
  }
  if (adWatch) drawAdOverlay();   // 广告播放层压在最上（v7.17.2 广告入口搬进寻访）
}
function visitClick(p) {
  if (adWatch) { adClick(p); return; }   // 广告播放中：只响应广告层
  if (visitPop) { visitPop = null; SFX.pick(); return; }
  if (inBtn(p, VISIT_BACK)) { showVisit = false; visit = null; visitPop = null; saveMeta(); return; }
  if (inBtn(p, VISIT_ROLL)) { if (!(visit && visit.reRollAt)) visitRoll(); return; }   // 好手气待掷时别抢
  if (inBtn(p, { x: W / 2 - 130, y: 628, w: 260, h: 20 })) { visitPop = { taofa: 1 }; SFX.pick(); return; }   // 讨伐赏进度行→规则弹窗
  if (inBtn(p, AD_BTN)) { if (AD_DAILY - adTodayN() > 0) { adWatch = { start: performance.now(), ad: adPick() }; SFX.pick(); } return; }
  for (const c of _visitChipRc) if (inBtn(p, c.rc)) { visitPop = { buff: c.id }; SFX.pick(); return; }
  const cells = visitBoard();
  for (let i = 0; i < VISIT_N; i++) {
    const q = visitCellPos(i);
    if (Math.abs(p.x - q.x) <= 24 && Math.abs(p.y - q.y) <= 24) { visitPop = { cell: cells[i] }; SFX.pick(); return; }
  }
  if (visit && visit.banner) visit.banner = null;   // 点别处收起升级横幅
}

/* ---------- 背包（v5.1）：道具一览——有什么、干什么用、怎么来，一页说清 ---------- */
const BAG_BACK = { x: 14, y: 22, w: 76, h: 34 };
function drawBagOverlay() {
  ctx.fillStyle = "rgba(20,14,6,.96)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  ctx.font = "bold 25px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText("🎒 背包", W / 2, 48);
  drawButton(BAG_BACK, "🏠", "#5a4a3a");
  ITEMS_DEF.forEach((it, i) => {
    const rc = { x: 20, y: 100 + i * 96, w: W - 40, h: 86 };
    ctx.fillStyle = "rgba(255,255,255,.05)";
    roundRect(rc.x, rc.y, rc.w, rc.h, 12);
    ctx.fill();
    ctx.strokeStyle = itemN(it.id) > 0 ? "#e8c86a" : "#4a3a1a";
    ctx.lineWidth = 1.5;
    roundRect(rc.x, rc.y, rc.w, rc.h, 12);
    ctx.stroke();
    ctx.textAlign = "left";
    ctx.font = "26px sans-serif";
    ctx.fillText(it.icon, rc.x + 16, rc.y + 40);
    ctx.font = "bold 16px sans-serif";
    ctx.fillStyle = "#ffe45a";
    ctx.fillText(it.name, rc.x + 58, rc.y + 30);
    ctx.font = "12px sans-serif";
    ctx.fillStyle = "#c9b69a";
    ctx.fillText(it.desc, rc.x + 58, rc.y + 54);
    ctx.textAlign = "right";
    ctx.font = "bold 20px sans-serif";
    ctx.fillStyle = itemN(it.id) > 0 ? "#9adf5a" : "#6a6152";
    ctx.fillText(`×${itemN(it.id)}`, rc.x + rc.w - 18, rc.y + 36);
    ctx.textAlign = "center";
  });
  ctx.font = "12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText("道具跟账号走（云存档），寻访和活跃奖励都会往这里存", W / 2, 100 + ITEMS_DEF.length * 96 + 24);
}
function bagClick(p) {
  if (inBtn(p, BAG_BACK) || p.y > H - 90) showBag = false;
}

/* ---------- 成就页（带奖励领取：达成没领的行发光，点一下领金币） ---------- */
let achMsg = null;   // { text, until } 领取提示条
/* —— 成就页 2.0：四类页签（战功/讨伐/养成/奇趣），每页一列；
   计数成就带进度条+数字，达成没领的行发绿光，点行领奖 —— */
let achTab = "战功";
function achTabRect(i) { return { x: 16 + i * 114, y: 104, w: 108, h: 36 }; }
const ACH_ROW_Y = 156, ACH_ROW_H = 40, ACH_ROW_P = 44;
function achTabList() { return ACHS.filter(a => a.grp === achTab); }
/* 行距自适应（v5.5.1 奇趣加到16行）：≤14行照旧44，多了就压扁点全塞下 */
function achRowP() { return Math.min(ACH_ROW_P, Math.floor((H - ACH_ROW_Y - 20) / Math.max(1, achTabList().length))); }
function achRowH() { return achRowP() - 4; }
function drawAchOverlay() {
  ctx.fillStyle = "rgba(20,14,6,.95)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  ctx.font = "bold 26px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = "#ffe45a";
  ctx.fillText(`🏆 成就 ${meta.ach.length}/${ACHS.length}`, W / 2, 52);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#d5c9a8";
  const nClaim = achClaimableCount();
  ctx.fillText(nClaim ? `💰 金币 ${meta.gold} · 有 ${nClaim} 个奖没领，点发绿光的行` : `累计击破 ${meta.totalKills} · 胜场 ${meta.wins}`, W / 2, 82);
  // 页签：每类挂自己的待领数
  ACH_GRPS.forEach((g, i) => {
    const rc = achTabRect(i), cur = g === achTab;
    const nG = ACHS.filter(a => a.grp === g && meta.ach.includes(a.id) && !meta.achClaimed.includes(a.id)).length;
    ctx.fillStyle = cur ? "rgba(255,215,74,.16)" : "rgba(255,255,255,.06)";
    roundRect(rc.x, rc.y, rc.w, rc.h, 9);
    ctx.fill();
    ctx.strokeStyle = cur ? "#ffd24a" : nG ? "#5aff9a" : "rgba(255,255,255,.25)";
    ctx.lineWidth = cur ? 2.5 : 1.5;
    roundRect(rc.x, rc.y, rc.w, rc.h, 9);
    ctx.stroke();
    ctx.font = "bold 14px sans-serif";
    ctx.fillStyle = cur ? "#ffe45a" : "#c9b69a";
    ctx.fillText(g, rc.x + rc.w / 2, rc.y + 24);
    if (nG) {
      ctx.fillStyle = "#5aff9a";
      ctx.beginPath();
      ctx.arc(rc.x + rc.w - 6, rc.y - 2, 9, 0, Math.PI * 2);
      ctx.fill();
      ctx.font = "bold 11px sans-serif";
      ctx.fillStyle = "#1a140a";
      ctx.fillText(String(nG), rc.x + rc.w - 6, rc.y + 2);
    }
  });
  const rp = achRowP(), rh = achRowH();
  achTabList().forEach((a, i) => {
    const y = ACH_ROW_Y + i * rp;
    const got = meta.ach.includes(a.id);
    const claimed = meta.achClaimed.includes(a.id);
    const claimable = got && !claimed;
    ctx.fillStyle = claimable ? "rgba(90,255,154,.12)" : got ? "rgba(255,210,74,.10)" : "rgba(255,255,255,.05)";
    roundRect(30, y, W - 60, rh, 10);
    ctx.fill();
    // 进度条垫底：没达成的计数成就，行底填到当前进度
    if (!got && a.prog) {
      const [cur, need] = a.prog();
      ctx.save();
      roundRect(30, y, W - 60, rh, 10);
      ctx.clip();
      ctx.fillStyle = "rgba(255,210,74,.10)";
      ctx.fillRect(30, y, (W - 60) * Math.min(1, cur / need), rh);
      ctx.restore();
    }
    ctx.strokeStyle = claimable ? "#5aff9a" : got ? "#ffd24a" : "rgba(255,255,255,.15)";
    ctx.lineWidth = claimable ? 2.5 : 1.5;
    if (claimable) {
      ctx.shadowColor = "#5aff9a";
      ctx.shadowBlur = 6 + Math.sin(performance.now() / 160) * 4;
    }
    roundRect(30, y, W - 60, rh, 10);
    ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.font = "17px sans-serif";
    ctx.textAlign = "left";
    ctx.globalAlpha = got ? 1 : 0.45;
    ctx.fillText(got ? "🏆" : "🔒", 42, y + rh / 2 + 7);
    ctx.font = "bold 12.5px sans-serif";
    ctx.fillStyle = got ? "#ffe45a" : "#9a8f78";
    ctx.fillText(a.name, 76, y + rh / 2 - 3);
    ctx.font = "10.5px sans-serif";
    ctx.fillStyle = got ? "#e8dcc0" : "#8a7f6a";
    let dtxt = a.desc;
    if (!got && a.prog) {
      const [cur, need] = a.prog();
      dtxt += `（${Math.min(cur, need)}/${need}）`;
    }
    ctx.fillText(dtxt, 76, y + rh - 7);
    ctx.globalAlpha = 1;
    // 奖励列：没领=醒目"点我领"，领过=已领，没达成=预告金额
    ctx.textAlign = "right";
    if (claimable) {
      ctx.font = "bold 12.5px sans-serif";
      ctx.fillStyle = "#5aff9a";
      ctx.fillText(`🎁点我领 ${a.gold}💰`, W - 42, y + rh / 2 + 5);
    } else if (claimed) {
      ctx.font = "11px sans-serif";
      ctx.fillStyle = "rgba(255,255,255,.35)";
      ctx.fillText("✅已领", W - 42, y + rh / 2 + 5);
    } else {
      ctx.font = "11px sans-serif";
      ctx.fillStyle = got ? "#ffd24a" : "rgba(255,210,74,.4)";
      ctx.fillText(`🎁${a.gold}💰`, W - 42, y + rh / 2 + 5);
    }
    ctx.textAlign = "left";
  });
  ctx.textAlign = "center";
  if (achMsg && performance.now() < achMsg.until) {
    ctx.font = "bold 15px sans-serif";
    ctx.fillStyle = "#5aff9a";
    ctx.fillText(achMsg.text, W / 2, H - 38);
  }
  ctx.font = "bold 16px sans-serif";
  ctx.fillStyle = "#fff";
  ctx.fillText("👆 点击底部返回", W / 2, H - 12);
}
/* 成就页点击：页签切类，点没领的行=领奖，点底部=关页 */
function achClick(p) {
  for (let i = 0; i < ACH_GRPS.length; i++)
    if (inBtn(p, achTabRect(i))) { achTab = ACH_GRPS[i]; SFX.pick(); return; }
  const list = achTabList();
  const rp2 = achRowP(), rh2 = achRowH();
  for (let i = 0; i < list.length; i++) {
    const y = ACH_ROW_Y + i * rp2;
    if (p.x >= 30 && p.x <= W - 30 && p.y >= y && p.y <= y + rh2) {
      const a = list[i];
      if (meta.ach.includes(a.id) && !meta.achClaimed.includes(a.id)) {
        meta.achClaimed.push(a.id);
        earnGold(a.gold);
        achSweep();   // 领的奖金可能直接把"累计金币"链顶过档
        saveMeta();
        SFX.ach();
        achMsg = { text: `🎁 领到「${a.name}」奖励 ${a.gold} 金币！`, until: performance.now() + 2400 };
      }
      return;
    }
  }
  if (p.y > H - 70) showAch = false;
}

const END_BTN1 = { x: W / 2 - 150, y: 634, w: 300, h: 54 };   // 结算页主按钮（赢=继续无尽 / 输=回地图）
const END_BTN2 = { x: W / 2 - 150, y: 700, w: 300, h: 44 };   // 结算页次按钮（赢=回地图 / 输=回首页）
/* 结算信息卡：标题一行 + 内容若干行，返回下一张卡的起始y */
function endCard(y, title, lines) {
  // v7.16.1 结算页重排（用户"排版乱"）：城池弹窗同款模块化——
  // 行分三型：{l,v}=左标签右数值（主力）、{t}=居中整行（星级/点评）、{tl}=左对齐整行（阵容清单）
  if (!lines.length) return y;
  const rowH = 21;
  const h = 24 + lines.length * rowH + 6;   // 极限行数（赢+跨段+屯田+应龙全占）也得给634的按钮留白
  const cx0 = W / 2 - 172, cw = 344;
  ctx.fillStyle = "rgba(255,255,255,.05)";
  roundRect(cx0, y, cw, h, 12);
  ctx.fill();
  ctx.strokeStyle = "rgba(232,200,106,.22)";
  ctx.lineWidth = 1;
  roundRect(cx0, y, cw, h, 12);
  ctx.stroke();
  ctx.textAlign = "center";
  ctx.font = "bold 12px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  ctx.fillText(title, W / 2, y + 18);
  lines.forEach((L, i) => {
    const ry = y + 38 + i * rowH;
    if (L.l != null) {
      ctx.textAlign = "left";
      ctx.font = "12.5px sans-serif";
      ctx.fillStyle = "#a89a76";
      ctx.fillText(L.l, cx0 + 18, ry);
      ctx.textAlign = "right";
      let vf = L.f || "bold 14px sans-serif";
      ctx.font = vf;
      // 数值超宽就缩字号（金币行带首通大赏能很长）
      let fs = 14;
      while (fs > 10.5 && ctx.measureText(L.v).width > cw - 36 - ctx.measureText(L.l).width - 14) {
        fs -= 0.5;
        ctx.font = `bold ${fs}px sans-serif`;
      }
      ctx.fillStyle = L.c || "#e8dcc0";
      ctx.fillText(L.v, cx0 + cw - 18, ry);
    } else if (L.tl != null) {
      ctx.textAlign = "left";
      ctx.font = L.f || "12px sans-serif";
      ctx.fillStyle = L.c || "#e8dcc0";
      ctx.fillText(L.tl, cx0 + 18, ry);
    } else {
      ctx.textAlign = "center";
      ctx.font = L.f || "bold 14px sans-serif";
      ctx.fillStyle = L.c || "#e8dcc0";
      ctx.fillText(L.t, W / 2, ry);
    }
  });
  ctx.textAlign = "center";
  return y + h + 12;
}
function drawEnd(win) {
  ctx.fillStyle = "rgba(20,14,6,.92)";
  ctx.fillRect(0, 0, W, H);
  ctx.textAlign = "center";
  // 大标题：赢=大获全胜；无尽阵亡=虽败犹荣（无尽本来就是打到城破为止）；平推翻车=大败而归
  const glory = !win && state.winWave > 0;
  ctx.font = "bold 42px 'Kaiti SC', 'STKaiti', serif";
  ctx.fillStyle = win ? "#ffe45a" : glory ? "#ffb84a" : "#ff6a6a";
  ctx.fillText(win ? "🎉 大获全胜" : glory ? "🎖️ 虽败犹荣" : "💀 大败而归", W / 2, 92);
  ctx.font = "13px sans-serif";
  ctx.fillStyle = "#8a7d5a";
  const extraW2 = glory ? Math.max(0, (state.scoredWave || state.winWave) - state.winWave) : 0;
  ctx.fillText(`${state.diff.icon}${state.diff.name}${state.field ? " · " + state.field.icon + state.field.name : ""} · 打到第${state.wave}波${glory ? ` · 无尽多撑${extraW2}波` : ""}`, W / 2, 118);

  let y = 138;
  // —— 卡一：成绩（左标签右数值；星级/点评居中）——
  const sc = [];
  if (win) {
    const st = state.stars || 1;
    const why = st === 3 ? "完美通关！" : st === 2 ? (state.wallHurt ? "城墙掉血了，差一星" : "有人阵亡，差一星") : "赢了，但打得挺狼狈";
    sc.push({ t: `${"★".repeat(st)}${"☆".repeat(3 - st)}　${why}`, c: "#ffd24a", f: "bold 18px sans-serif" });
  }
  if (state.diff.week != null && (state.runScore || state.prevBest)) {
    const wk = state.diff.k;
    if (state.newRecord)
      sc.push({ l: `🏅 ${STATE_NAMES[wk]}贡献`, v: `${state.runScore} 🎉破纪录（原${state.prevBest}）`, c: "#ffd24a" });
    else if (state.runScore)
      sc.push({ l: `🏅 ${STATE_NAMES[wk]}贡献`, v: `${state.runScore}（历史最高 ${Math.max(state.prevBest, state.runScore)}）`, c: "#8ad2ff" });
    else
      sc.push({ l: `🏅 ${STATE_NAMES[wk]}贡献`, v: `本局没拿分（历史最高 ${state.prevBest}）`, c: "#8a7d5a" });
    sc.push({ l: "⚖️ 我的势力值", v: `${weekScore()}`, c: "#8ad2ff" });
    if (state.bandGold) sc.push({ l: "🎁 跨段奖金", v: `+${state.bandGold}💰 已入账`, c: "#ffd24a" });
  }
  sc.push({ l: "💰 金币", v: `+${state.goldEarned} · 累计 ${meta.gold}${state.firstClearGold ? " 🎁含首通大赏" : ""}`, c: "#ffb84a" });
  if (state.lordXpGot) {
    const rl = LORD_RULERS.find(r => r.id === state.lordXpGot.rid);
    sc.push({ l: `👑 ${rl ? rl.name : "主公"}经验`, v: `+${state.lordXpGot.gain}${state.lordXpGot.up ? ` 🎉升到 Lv.${state.lordXpGot.lv}！` : `（Lv.${state.lordXpGot.lv}）`}`, c: state.lordXpGot.up ? "#ffd24a" : "#c9a8ff" });
  }
  if (win && state.visitGot != null)
    sc.push({ l: "🧭 寻访令牌", v: state.visitGot ? `+${state.visitGot}（今日 ${meta.visitN}/${VISIT_DAILY}，首页可用）` : `今日已领满 ${VISIT_DAILY}/${VISIT_DAILY}（讨伐赏另算）`, c: state.visitGot ? "#8ad2ff" : "#8a7d5a" });
  if (state.taofaGot)
    sc.push({ l: "🗡️ 讨伐赏", v: `+${state.taofaGot}令牌（今日 ${meta.taofaGot}/${TAOFA_TOKEN_DAILY}）`, c: "#ffd24a" });
  else if (state.winWave && state.wave > state.winWave)
    sc.push({ l: "🗡️ 讨伐赏", v: (meta.taofaGot || 0) >= TAOFA_TOKEN_DAILY ? `今日已领满 ${TAOFA_TOKEN_DAILY}/${TAOFA_TOKEN_DAILY}` : "没破这州今日最深——打更深或换座城", c: "#8a7d5a" });
  y = endCard(y, "—— 成绩 ——", sc);

  // —— 卡二：战报（左标签右数值，一行一事）——
  const br = [
    { l: "⚔️ 击破", v: `${state.kills} 个贼`, c: "#9adf5a" },
    { l: "💢 最重一击", v: fmtBigN(state.maxHit), c: "#9adf5a" },
    { l: "🛡️ 盾兵挡刀 · 💥 大招", v: `${state.shieldBlocks} 刀 · ${state.ultsUsed} 次`, c: "#9adf5a" },
  ];
  // 输出前三（v7.17.5）：验证搭配好不好使，一行见分晓
  if (dmgTopStr(3)) br.push({ l: "📊 输出前三", v: dmgTopStr(3), c: "#8ad2ff" });
  if (state.diff.foes?.tri && state.totalDmg > 0) {
    const pct = Math.round(state.counterDmg / state.totalDmg * 100);
    br.push({ l: "☯️ 克制伤害占", v: `${pct}%${pct >= 35 ? "，对症下药！" : pct < 12 ? "，该带克他的系" : ""}`, c: pct >= 35 ? "#5aff9a" : "#c9b69a" });
  }
  if (state.farmStars > 0)
    br.push({ l: "🌾 屯田喂星", v: `${state.farmStars} 颗`, c: "#e8c86a" });
  if (state.dragonN > 0)
    br.push({ l: "🐉 觉醒应龙", v: `${state.dragonN} 条（第${state.dragonWaves.join("、")}波破壳）`, c: "#8ad2ff" });
  y = endCard(y, "—— 战报 ——", br);

  // —— 卡三：阵容（左对齐清单，长了折行）——
  const rc = [];
  const units = allUnits();
  if (units.length) {
    const names = units.map(u => u.type.cls === "dragon" ? u.type.name : `${u.type.name}${u.level}★`);
    for (let i = 0; i < names.length; i += 5)
      rc.push({ tl: (i === 0 ? "出战　" : "　　　") + names.slice(i, i + 5).join("　"), c: "#e8c86a" });
  }
  if (state.relics.length) {
    const rs = state.relics.map(r => `${r.icon}${r.name}`);
    for (let i = 0; i < rs.length; i += 4)
      rc.push({ tl: (i === 0 ? "遗宝　" : "　　　") + rs.slice(i, i + 4).join("　"), c: "#ffd24a" });
  }
  endCard(y, "—— 阵容 ——", rc);

  // —— 两个明确的按钮：想干嘛点哪个，别猜 ——
  if (win) {
    drawButton(END_BTN1, "⚔️ 继续无尽——多撑一波分更高", "#7a3a2a");
    drawButton(END_BTN2, "🗺️ 收兵回城（回地图）", "#5a4a3a");
  } else {
    drawButton(END_BTN1, "🗺️ 回地图，重整旗鼓", "#3a5a2a");
    drawButton(END_BTN2, "🏠 返回首页", "#5a4a3a");
  }
}

/* 三角克制环（v6.0.1 用户点名"画成三角形"）：✊克✌️克✋克✊ 画成真三角——
   箭头=克的方向；curTri=当前州贼的系（那个角带同色圈，指向他的边亮绿=打他最疼） */
function drawTriLegend(cx, cy, curTri, spread = 32, drop = 28, withNames = false) {
  const P = { badao: [cx, cy], liangmou: [cx + spread, cy + drop], rende: [cx - spread, cy + drop] };
  const gx = cx, gy = cy + drop * 0.66;   // 重心：边上的"克"字往外推的参照
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  for (const [a, b] of [["badao", "liangmou"], ["liangmou", "rende"], ["rende", "badao"]]) {
    const [ax, ay] = P[a], [bx, by] = P[b];
    const dx = bx - ax, dy = by - ay, L = Math.hypot(dx, dy), ux = dx / L, uy = dy / L;
    const pad = withNames ? 16 : 12;
    const x1 = ax + ux * pad, y1 = ay + uy * pad, x2 = bx - ux * pad, y2 = by - uy * pad;
    const hot = curTri && b === curTri;   // 指向当前贼系的边=克他
    ctx.strokeStyle = hot ? "rgba(90,255,154,.95)" : "rgba(220,205,170,.55)";
    ctx.lineWidth = hot ? 2.5 : 1.5;
    ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
    const sz = hot ? 6.5 : 5;   // 箭头
    ctx.fillStyle = ctx.strokeStyle;
    ctx.beginPath();
    ctx.moveTo(x2, y2);
    ctx.lineTo(x2 - ux * sz - uy * sz * 0.6, y2 - uy * sz + ux * sz * 0.6);
    ctx.lineTo(x2 - ux * sz + uy * sz * 0.6, y2 - uy * sz - ux * sz * 0.6);
    ctx.closePath(); ctx.fill();
    const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;   // 边中点外侧一个小"克"
    let ox = mx - gx, oy = my - gy; const ol = Math.hypot(ox, oy) || 1;
    ctx.font = `${withNames ? 11 : 9}px sans-serif`;
    ctx.fillStyle = hot ? "rgba(90,255,154,.9)" : "rgba(220,205,170,.65)";
    ctx.fillText("克", mx + ox / ol * (withNames ? 12 : 9), my + oy / ol * (withNames ? 12 : 9));
  }
  for (const k of Object.keys(P)) {
    const [x, y] = P[k];
    if (curTri === k) {   // 当前州贼的角：同色圈点名
      ctx.strokeStyle = ELEMENTS[k].color;
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(x, y, withNames ? 14 : 10, 0, Math.PI * 2); ctx.stroke();
    }
    ctx.font = `${withNames ? 18 : 13}px sans-serif`;
    ctx.fillStyle = "#fff";
    ctx.fillText(ELEMENTS[k].icon, x, y);
    if (withNames) {
      ctx.font = "bold 12px sans-serif";
      ctx.fillStyle = ELEMENTS[k].color;
      ctx.fillText(ELEMENTS[k].name, x, y + (k === "badao" ? -22 : 22));
    }
  }
  ctx.textBaseline = "alphabetic";
}

/* ---------- 输入 ---------- */
function toGame(ev) {
  const rect = canvas.getBoundingClientRect();
  const cx = (ev.touches ? ev.touches[0].clientX : ev.clientX) - rect.left;
  const cy = (ev.touches ? ev.touches[0].clientY : ev.clientY) - rect.top;
  return { x: cx / scale, y: cy / scale };
}
function inBtn(p, b) { return p.x >= b.x && p.x <= b.x + b.w && p.y >= b.y && p.y <= b.y + b.h; }
function slotAt(p) {
  const c = Math.floor((p.x - GRID_X) / CELL);
  const r = Math.floor((p.y - GRID_Y) / CELL);
  if (r >= 0 && r < GRID_ROWS && c >= 0 && c < GRID_COLS) return [r, c];
  return null;
}

function onDown(ev) {
  ev.preventDefault();
  SFX.unlock();
  const p = toGame(ev);

  // 乐不思蜀（v7.12）：点屏幕任意处=回神——终止挂机回归手动，+30%失效；开着的牌留给手动挑
  // v7.13：歌舞动画那3秒点击豁免——玩家点完卡习惯性再碰屏幕，一碰就静默退挂机，看着像"自动抽卡没生效"
  if (state.gewu && state.phase === "play" && !state.dance) {
    state.gewu = false;
    state.dance = 0;
    state.autoSel = null;
    addFloater(W / 2, 300, "🌅 回神了！恢复手动（+30%攻没了）", "#ffd24a", 20);
    SFX.pick();
    return;
  }

  if (showShop) { shopClick(p); return; }
  if (showTech) { techClick(p); return; }
  if (showAch) { achClick(p); return; }
  if (showVisit) { visitClick(p); return; }
  if (showBag) { bagClick(p); return; }

  if (state.phase === "title") {
    if (showBoard) { boardClick(p); return; }
    if (window.__cheat?.titleClick?.(p)) return;
    if (inBtn(p, BOARD_BTN)) { showBoard = true; boardLogoutArm = false; netFetchBoard(true); return; }
    if (inBtn(p, LOG_BTN)) { window.open("changelog.html", "_blank"); return; }
    if (inBtn(p, SHOP_BTN)) { showShop = true; return; }
    if (inBtn(p, TECH_BTN)) { showTech = true; return; }
    if (inBtn(p, ACH_BTN)) { showAch = true; return; }
    if (inBtn(p, VISIT_BTN)) { showVisit = true; visit = null; return; }
    if (inBtn(p, BAG_BTN)) { showBag = true; return; }
    gotoLevelSelect();
    return;
  }
  if (state.phase === "pickDiff") { diffPickClick(p); return; }
  if (state.phase === "pickLord") { pickLordClick(p); return; }
  // 洛阳铲（v7.0 董卓）：点铲子牌进/出挖掘模式；挖掘模式里点障碍格=挖、点别处=取消
  if (state.phase === "play" && state.shovelChip && inBtn(p, state.shovelChip)) {
    state.digMode = !state.digMode;
    SFX.pick();
    return;
  }
  if (state.digMode && state.phase === "play") {
    const sd = slotAt(p);
    if (sd && isObstacle(sd[0], sd[1]) && state.shovels > 0) {
      state.shovels--;
      const k = sd[0] + "," + sd[1];
      state.obstacles.delete(k);
      const pd = slotCenter(sd[0], sd[1]);
      burst(pd.x, pd.y, "#c9b69a", 18, 170);
      burst(pd.x, pd.y, "#ffd24a", 10, 120);
      const tr = TRAITS[state.traits[k]];
      if (Math.random() < 0.3) {   // 陪葬金：盗墓的浪漫
        const loot = 50 + Math.floor(Math.random() * 101);
        earnGold(loot);
        state.goldEarned += loot;
        addFloater(pd.x, pd.y - 40, `🪙 挖出陪葬金 +${loot}！`, "#ffd24a", 18);
      }
      addFloater(pd.x, pd.y - 22, `🪏 挖开！露出${tr ? tr.icon + tr.name : "平地"}`, "#ffe45a", 14);
      SFX.pick();
      if (state.shovels <= 0) state.digMode = false;
      return;
    }
    state.digMode = false;   // 点别处收铲
    return;
  }
  // 地形横幅：点一下关掉（选将期/开打后都行）
  if (state.fieldBanner > 0 && inBtn(p, FIELD_BANNER_RC)) { state.fieldBanner = 0; return; }
  // 局中点左上角地形小牌子：再看一遍横幅
  if (state.phase === "play" && state.field && inBtn(p, { x: 10, y: 96, w: 120, h: 22 })) {
    state.fieldBanner = 6;
    return;
  }
  if (state.phase === "over") {
    if (inBtn(p, END_BTN1)) { if (newVerSeen) return reloadForUpdate("map"); newGame(); gotoLevelSelect(); return; }
    if (inBtn(p, END_BTN2)) { if (newVerSeen) return reloadForUpdate("title"); newGame(); state.phase = "title"; return; }
    return;   // 点别处不动——防手滑
  }
  if (state.phase === "win") {
    if (inBtn(p, END_BTN1)) { state.endless = true; state.phase = "play"; return; }   // 继续无尽不打断——下次结算再更
    if (inBtn(p, END_BTN2)) { if (newVerSeen) return reloadForUpdate("map"); newGame(); gotoLevelSelect(); return; }
    return;
  }

  // 敌情面板打开时：点任意处关闭
  if (state.inspect) { state.inspect = null; return; }
  if (lordPop) {
    if (lordPopCast && inBtn(p, lordPopCast)) { lordPop = false; castLord(0, true); return; }
    lordPop = false;
    return;
  }
  // 点主公名牌：弹主公面板（三道号令的效果说明）
  if (rulerOf() && inBtn(p, { x: W - 70, y: 178, w: 64, h: 24 })) { lordPop = true; return; }

  // 武将信息面板打开时：点任意处关闭（可透传点下一个武将）
  if (state.ultConfirm) {
    state.ultConfirm = null;
    // 不 return：允许直接点下一个武将/按钮
  }

  // 三选一优先（v5.5.4 开牌保护期：弹出0.35秒内不吃点击——升级瞬间冒出来的牌
  // 正好压在主公技按钮上，手指已经落下去了，不该算选卡；等入场动画走完再认点击）
  if (state.cards) {
    if (performance.now() - (state.cardsAt || 0) < 350) return;
    for (let i = 0; i < state.cards.length; i++) {
      if (inBtn(p, cardRect(i))) {
        applyCard(state.cards[i]);
        return;
      }
    }
    return;
  }

  if (inBtn(p, BTN.mute)) { SFX.toggleMute(); return; }
  if (inBtn(p, BTN.dmg)) { state.dmgPanel = !state.dmgPanel; SFX.pick(); return; }
  if (inBtn(p, BTN.quit)) {
    if (state.quitArm > 0) { SFX.pick(); newGame(); state.phase = "title"; }
    else {
      state.quitArm = 180;   // 约3秒（draw 每帧减1）
      addFloater(W - 130, BTN.quit.y + 48, "再点一次就退，本局不算成绩", "#ffb0a0", 13);
    }
    return;
  }

  // 主公技按钮
  for (let i = 0; i < state.lord.length; i++) {
    if (inBtn(p, lordBtnRect(i))) { lordPop = true; return; }
  }

  // 点敌人：查看抗性（自动暂停）
  if (state.phase === "play") {
    let best = null, bestD = Infinity;
    for (const e of state.enemies) {
      if (e.dead) continue;
      const d = dist2(p.x, p.y, e.x, e.y);
      if (d < Math.max(24, e.r + 10) ** 2 && d < bestD) { bestD = d; best = e; }
    }
    // 阵地内优先点武将（敌人贴着武将打时，点格子=看武将，点空处=看敌人）
    if (best && (p.y < GRID_Y || !slotAt(p) || !state.slots[slotAt(p)[0]][slotAt(p)[1]])) {
      state.inspect = best;
      return;
    }
  }

  // 按住武将开始拖动（原地点按 = 放绝技）
  const s = slotAt(p);
  if (s) {
    const [r, c] = s;
    const u = state.slots[r][c];
    if (u) state.drag = { unit: u, fromR: r, fromC: c, x: p.x, y: p.y, sx: p.x, sy: p.y, moved: false };
  }
}

function onMove(ev) {
  if (!state.drag) return;
  ev.preventDefault();
  const p = toGame(ev);
  state.drag.x = p.x;
  state.drag.y = p.y;
  if (dist2(p.x, p.y, state.drag.sx, state.drag.sy) > 14 ** 2) state.drag.moved = true;
}

function onUp() {
  if (!state.drag) return;
  const d = state.drag;
  state.drag = null;
  if (d.unit.hp <= 0) return;  // 拖动途中阵亡，不再落格
  // 原地点按：弹出武将信息面板（技能自动放，这里看信息和CD）
  if (!d.moved) {
    state.ultConfirm = { unit: d.unit, r: d.fromR, c: d.fromC };
    return;
  }
  const s = slotAt({ x: d.x, y: d.y });
  if (!s) {
    // 拖出阵地上方一段距离松手 = 卖掉这个武将，退30%经验
    if (d.y < GRID_Y - 40) {
      if (allUnits().length <= 1) {
        addFloater(d.x, d.y, "最后一个武将不能卖！", "#ff8a6a", 14);
        return;
      }
      // 卖将只腾格子、不退经验（2026-07-08：堵"1星卖了换"精准钓卡——阵容成型该带运气和取舍）
      state.slots[d.fromR][d.fromC] = null;
      computeTeam();
      if (state.ultConfirm && state.ultConfirm.unit === d.unit) state.ultConfirm = null;
      burst(d.x, d.y, "#c9b69a", 14, 130);
      addFloater(d.x, d.y - 24, `卖掉${d.unit.type.name}，腾出一格`, "#c9b69a", 15);
      return;
    }
    return;
  }
  const [r, c] = s;
  if (r === d.fromR && c === d.fromC) return;
  if (isObstacle(r, c) && d.unit.type.id !== "dengai") {   // 邓艾例外：偷渡阴平的人不怕石头（v7.6.0）
    const p = slotCenter(r, c);
    addFloater(p.x, p.y - 20, "🪨 有石头，站不了", "#c9b69a", 13);
    return;
  }
  const target = state.slots[r][c];
  // 换位也要过石头关（v7.6.1）：邓艾从石头上跟人换位，被换过来的不是邓艾就站不上石头——不许换
  if (target && isObstacle(d.fromR, d.fromC) && target.type.id !== "dengai") {
    const p0 = slotCenter(d.fromR, d.fromC);
    addFloater(p0.x, p0.y - 20, `🪨 ${target.type.name}站不了石头，换不成`, "#c9b69a", 13);
    return;
  }
  state.slots[r][c] = d.unit;
  state.slots[d.fromR][d.fromC] = target || null;
  d.unit.bounce = 0.6;
  if (target) target.bounce = 0.6;
}

canvas.addEventListener("mousedown", onDown);
canvas.addEventListener("mousemove", onMove);
window.addEventListener("mouseup", onUp);
canvas.addEventListener("touchstart", onDown, { passive: false });
canvas.addEventListener("touchmove", onMove, { passive: false });
window.addEventListener("touchend", onUp);

/* ---------- 主循环 ---------- */
newGame();
function loop(t) {
  const dt = Math.min((t - last) / 1000, 0.05);
  last = t;
  if (state.phase === "play" && !state.cards && !state.inspect && !state.ultConfirm && !lordPop && !showShop && !showAch && !showTech) {
    for (let i = 0; i < state.speed; i++) update(dt);
  } else {
    state.time += dt;
    updateFx(dt);
  }
  draw();
  // 双设备冲突提示（v5.9.2 常驻红条）：另一台设备的存档更新，本机已停止保存——挂明面，别让人白打
  if (NET.stale) {
    ctx.fillStyle = "rgba(120,20,20,.92)";
    ctx.fillRect(0, 0, W, 26);
    ctx.font = "bold 13px sans-serif";
    ctx.textAlign = "center";
    ctx.fillStyle = "#ffd8d0";
    ctx.fillText("⚠️ 另一台设备的存档更新，本机已停止保存——刷新页面同步", W / 2, 18);
  }
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);

/* ---------- 账号登录（DOM 浮层：canvas 里画输入框太受罪，手机键盘也唤不起来） ---------- */
function acctLogout() {
  try { localStorage.removeItem("sanguo_acct"); sessionStorage.removeItem("sanguo_acct"); } catch (e) {}
  clearTimeout(NET.timer);
  NET.name = NET.token = null;
  meta = normalizeMeta(freshMeta());
  newGame();
  state.phase = "title";
  if (IS_BROWSER) acctShow();
}
if (IS_BROWSER) (function initAcct() {
  const box = document.createElement("div");
  box.id = "acctBox";
  box.innerHTML = `
    <div class="acct-panel">
      <div class="acct-title">⚔️ 不一样三国</div>
      <div class="acct-sub">存档放在云端：注册一次，换手机换电脑接着玩</div>
      <input id="acctName" maxlength="12" placeholder="昵称（1~12个字，会上排行榜）" autocomplete="username">
      <input id="acctPw" type="password" maxlength="32" placeholder="密码（至少4位）" autocomplete="current-password">
      <label class="acct-rem"><input id="acctRem" type="checkbox" checked> 记住我（下次自动进）</label>
      <div class="acct-row">
        <button id="acctLogin">🔑 登录</button>
        <button id="acctReg">✨ 注册新号</button>
      </div>
      <div id="acctMsg"></div>
      <div class="acct-tip">测试服提醒：别用你平时的真密码 · 忘了密码找群主重置</div>
    </div>`;
  const css = document.createElement("style");
  css.textContent = `
    #acctBox{position:fixed;inset:0;background:rgba(14,10,4,.92);display:flex;align-items:center;justify-content:center;z-index:99;font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif}
    #acctBox.hide{display:none}
    .acct-panel{width:min(86vw,340px);background:#241c10;border:2px solid #e8c86a;border-radius:16px;padding:26px 22px;display:flex;flex-direction:column;gap:12px}
    .acct-title{color:#ffe45a;font-size:24px;font-weight:bold;text-align:center}
    .acct-sub{color:#a89a76;font-size:12.5px;text-align:center}
    .acct-panel input[type=text],.acct-panel input:not([type=checkbox]){background:#1a140a;border:1px solid #5a4a2a;border-radius:8px;color:#e8dcc0;padding:12px;font-size:16px}
    .acct-rem{color:#c9b69a;font-size:13px;display:flex;align-items:center;gap:6px}
    .acct-row{display:flex;gap:10px}
    .acct-row button{flex:1;padding:12px 0;font-size:16px;font-weight:bold;border:0;border-radius:10px;cursor:pointer;color:#fff}
    #acctLogin{background:#2a5a3a}#acctReg{background:#6a4a2a}
    #acctMsg{color:#ff8a6a;font-size:13px;text-align:center;min-height:17px}
    .acct-tip{color:#6a5d44;font-size:11px;text-align:center}`;
  document.head.appendChild(css);
  document.body.appendChild(box);
  const $ = (id) => document.getElementById(id);
  const say = (t) => { $("acctMsg").textContent = t || ""; };
  window.acctShow = () => { box.classList.remove("hide"); say(""); };
  const hide = () => box.classList.add("hide");
  function store() {
    const bag = $("acctRem").checked ? localStorage : sessionStorage;
    try { bag.setItem("sanguo_acct", JSON.stringify({ name: NET.name, token: NET.token })); } catch (e) {}
  }
  function enter(serverMeta) {
    meta = normalizeMeta(serverMeta || freshMeta());
    saveMeta();   // 新号立即把初始档推上云
    hide();
    // 无感热更（v7.18.8）：带标记刷新回来的——直接跳回讨贼地图，顶部提示已更新
    try {
      const ra = sessionStorage.getItem("sanguo_resume");
      if (ra) {
        sessionStorage.removeItem("sanguo_resume");
        if (ra === "map") gotoLevelSelect();
        state.updateToastUntil = Date.now() + 6000;
      }
    } catch (e) {}
  }
  async function submit(route) {
    const name = $("acctName").value.trim(), pw = $("acctPw").value;
    if (!name) return say("先起个昵称");
    if (pw.length < 4) return say("密码至少4位");
    say("联网中…");
    try {
      const r = await api(route, { name, pw });
      if (!r.ok) return say(r.msg || "没成功，再试试");
      NET.name = name;
      NET.token = r.token; NET.stale = false;
      NET.epoch = r.epoch || 0;
      store();
      enter(r.meta);
    } catch (e) {
      say("连不上服务器，检查一下网络");
    }
  }
  $("acctLogin").onclick = () => submit("/api/login");
  $("acctReg").onclick = () => submit("/api/register");
  $("acctPw").addEventListener("keydown", (e) => { if (e.key === "Enter") submit("/api/login"); });
  // 自动登录：记住过就直接进；断网时退回本地缓存档能先玩（联网后会同步覆盖到云）
  (async () => {
    let saved = null;
    try { saved = JSON.parse(localStorage.getItem("sanguo_acct") || sessionStorage.getItem("sanguo_acct")); } catch (e) {}
    if (!saved || !saved.token) { acctShow(); return; }
    try {
      const r = await api("/api/load", saved);
      if (r.ok) {
        NET.name = saved.name;
        NET.token = saved.token;
        NET.epoch = r.epoch || 0;
        enter(r.meta);
      } else {
        acctShow();
        say(r.msg || "登录过期了，重新登一下");
      }
    } catch (e) {
      // 服务器暂时够不着：用本地缓存先玩，别把人挡在门外
      NET.name = saved.name;
      NET.token = saved.token;
      let cached = null;
      try { cached = JSON.parse(localStorage.getItem(CACHE_KEY)); } catch (e2) {}
      enter(cached);
    }
  })();
  // 切后台/关页面前尽量把档拍上云（sendBeacon 关页面也能送到）；切回前台重新拉云端对齐（双端换玩）
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "hidden" && NET.token && navigator.sendBeacon && !NET.stale) {
      clearTimeout(NET.timer);
      meta.saveSeq = (meta.saveSeq || 0) + 1;   // 乐观锁：关页兜底那一发也带新序号
      navigator.sendBeacon("/api/save", new Blob(
        [JSON.stringify({ name: NET.name, token: NET.token, ver: GAME_VERSION, epoch: NET.epoch, meta, summary: buildSummary() })],
        { type: "application/json" }));
    } else if (document.visibilityState === "visible") {
      netResync();   // 从后台切回：另一台设备可能已推了更新的进度，拉一次对齐
    }
  });
  // 从 BFCache（手机浏览器冻结的标签页）恢复时也拉一次——这种恢复不重新执行自动登录
  window.addEventListener("pageshow", () => { if (NET.token) netResync(); });
})();
/* 本地测试功能已在部署时剥离 */
