# v7.19.14 Godot 精确复现总计划

**目标：** 以冻结的老板 Web Demo v7.19.14 为唯一体验权威，在 Godot 4.7 单机工程中复现玩家可观察到的页面、交互、战斗规则、动画、音效与反馈；账号和服务器数据源使用本地替代。

**架构：** 保留现有规则对象和本地档案，将 `godot-demo/src/app/main.gd` 中混杂的绘制与输入拆成按页面负责的 `Control`，由主场景只管理导航与共享状态。Web Canvas 坐标系固定为 480×800，页面视图直接使用同一逻辑坐标；战斗输入由独立拖动状态机处理，规则状态通过只读快照交给表现层。

**技术栈：** Godot 4.7、GDScript、冻结 Web v7.19.14、Playwright CLI、固定种子 JSON 夹具、Godot headless 测试和 480×800 截图差异检查。

## 阶段 1：权威与自动对照基线

**文件：**

- 新建：`docs/baseline/CURRENT_AUTHORITY.md`
- 新建：`docs/baseline/2026-07-15-v7.19.14-source-provenance.md`
- 新建：`docs/parity/v7.19.14-exact-parity-matrix.md`
- 新建：`scripts/capture-v71914-parity.mjs`
- 新建：`output/web/v7.19.14/`（忽略生成物）

步骤：冻结源码和哈希；脚本在本地 HTTP 加载冻结页面并注入固定档案/战斗状态；捕获主公府、开局规则层、战斗中、拖动中四张权威图；每张图记录页面状态和 480×800 坐标。

验证：`node scripts/capture-v71914-parity.mjs` 必须确认 `GAME_VERSION === "7.19.14"`，生成四张非空 PNG，任一步失败返回非零退出码。

## 阶段 2：拆分可复用表现层

**文件：**

- 新建：`godot-demo/src/ui/demo_palette.gd`
- 新建：`godot-demo/src/ui/draw_primitives.gd`
- 修改：`godot-demo/src/app/main.gd`
- 新建：`godot-demo/tests/test_draw_geometry.gd`

步骤：把金色描边、暗色面板、胶囊按钮、进度条、星级、兵种徽记、卡片圆角和文字层级定义为唯一视觉令牌；将 Web 的 480×800 关键坐标写成可断言的几何数据；主场景使用辅助绘制而非继续复制魔法数。

验证：headless 测试断言关键矩形、圆心、字号和点击区；Godot 空壳截图与 Web 基准叠加检查。

## 阶段 3：主公府精确复现

**文件：**

- 新建：`godot-demo/src/ui/lord_house_view.gd`
- 修改：`godot-demo/src/app/main.gd`
- 新建：`godot-demo/tests/test_lord_house_view.gd`
- 修改：`godot-demo/src/data/content_catalog.gd`

步骤：一次展示 8 位主公；逐行绘制姓名、称号、等级、号令/技能、兵法、亲兵、成长状态与升级入口；实现与 Web 一致的滚动/命中区和返回；数据只从 v7.19.14 目录读取。

验证：8 主公字段完整性测试、逐行命中测试、480×800 长页截图对照。

## 阶段 4：战斗静态壳精确复现

**文件：**

- 新建：`godot-demo/src/ui/battle_view.gd`
- 修改：`godot-demo/src/app/main.gd`
- 新建：`godot-demo/tests/test_battle_layout.gd`

步骤：按 Web 坐标复现顶栏、敌军通道、规则覆盖层、右侧按钮、5×3 阵地、主公底栏和输出入口；使用现有 `BattleRun` 快照驱动等级、经验、波次、城防和敌方主公信息。

验证：空阵、开局覆盖层、双将战斗、满阵四种固定状态截图对照；所有按钮命中区测试。

## 阶段 5：拖动、换位、售出与查看

**文件：**

- 新建：`godot-demo/src/input/battle_drag_controller.gd`
- 修改：`godot-demo/src/ui/battle_view.gd`
- 修改：`godot-demo/src/app/main.gd`
- 新建：`godot-demo/tests/test_battle_drag_controller.gd`

步骤：实现 `idle → pressed → dragging → dropped/cancelled` 状态机；鼠标和触摸统一为按下、移动、松开；支持合法空格落位、占用格换位、非法落点复位、出售区、点击查看与拖动阈值；绘制原位半透明、跟手卡和落点高亮。

验证：对每条状态迁移运行坐标级测试；用 Playwright/Godot 输入脚本捕获拖动前、中、后三帧。

## 阶段 6：45 将表现与战斗反馈

**文件：**

- 修改：`godot-demo/src/ui/battle_view.gd`
- 修改：`godot-demo/src/battle/battle_run.gd`
- 新建：`godot-demo/src/ui/battle_fx_player.gd`
- 新建：`godot-demo/tests/fixtures/v7.19.14-hero-events.json`
- 新建：`godot-demo/tests/test_hero_visual_events.gd`

步骤：从 Web 运行时捕获 45 将普攻和绝技事件；规则层发出目标、轨迹、范围、伤害、状态事件；表现层复现弹道、范围、绝技环、飘字、受击、死亡和羁绊提示，不在绘制层重新计算伤害。

验证：每名武将至少一条普攻与一条绝技固定夹具；事件序列和关键帧均通过。

## 阶段 7：v7.19.14 新增敌军行为

**文件：**

- 修改：`godot-demo/src/battle/battle_run.gd`
- 修改：`godot-demo/src/ui/battle_view.gd`
- 新建：`godot-demo/tests/fixtures/v7.19.14-siege-focus.json`
- 新建：`godot-demo/tests/test_siege_focus.gd`

步骤：复现投石车中场停位、10 秒持续攻城、全局错峰、顶层不透明预警条、整条点击集火、3 秒标记、穿透阻挡优先级、盾兵拦冲车和敌方主公冲车伤害。

验证：时序夹具、点击命中、目标优先级、护盾吸收及四关键帧截图全部通过。

## 阶段 8：剩余页面、音效与最终审计

**文件：**

- 修改：`docs/parity/v7.19.14-exact-parity-matrix.md`
- 新建：`docs/baseline/2026-07-15-v7.19.14-godot-parity-audit.md`
- 修改：`README.md`

步骤：首页、地图、选将、成长、寻访、结算逐页关闭矩阵；建立事件到音效映射；全流程从首页玩到结算并返回地图；每项只在四类证据齐全后标记完成。

验证：全量测试、Windows 实机运行、同状态截图对照和人工交互清单均通过后，才可声明完成。
