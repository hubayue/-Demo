# Godot Offline Prototype Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Godot vertical slice into an offline design laboratory that can compare the boss baseline with focused gameplay experiments without any server dependency.

**Architecture:** The project loads local scenario definitions, runs all gameplay in-process, and saves only disposable prototype preferences under `user://`. Scenario IDs and deterministic seeds make demonstrations reproducible; the Web v7.18.8 snapshot remains read-only reference evidence.

**Tech Stack:** Godot 4.7, GDScript, JSON scenario data, `FileAccess`, headless SceneTree tests.

---

### Task 1: Lock the offline architecture contract

**Files:**
- Modify: `README.md`
- Create: `docs/architecture/godot-prototype-scope.md`
- Modify: `docs/architecture/web-demo-boundaries.md`

- [x] **Step 1: Record the product boundary**

State that the Godot target is an offline design prototype, not an online product implementation.

- [x] **Step 2: Remove server work from the Godot contract**

Mark login, cloud save, battle reports and real leaderboards as Web reference behavior only.

- [ ] **Step 3: Review the documents for conflicting server commitments**

Run:

```powershell
rg -n "HTTPRequest|服务器|云存档|排行榜" README.md docs/architecture
```

Expected: server references either describe the Web baseline or explicitly state that Godot will not migrate them.

- [ ] **Step 4: Commit**

```text
docs: define offline Godot prototype scope
```

### Task 2: Add a disposable local prototype profile

**Files:**
- Create: `godot-demo/src/platform/local_profile_store.gd`
- Create: `godot-demo/tests/test_local_profile_store.gd`

- [ ] **Step 1: Write the failing persistence test**

```gdscript
extends SceneTree

const LocalProfileStore = preload("res://src/platform/local_profile_store.gd")

func _init() -> void:
    var path := "user://test-prototype-profile.json"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var store = LocalProfileStore.new(path)
    assert(store.load_profile().is_empty())
    assert(store.save_profile({"scenario_id": "boss_baseline", "seed": 714}) == OK)
    assert(store.load_profile() == {"scenario_id": "boss_baseline", "seed": 714})
    store.reset_profile()
    assert(store.load_profile().is_empty())
    print("Godot local profile store: PASS")
    quit(0)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --headless --path godot-demo --script res://tests/test_local_profile_store.gd
```

Expected: non-zero exit because `local_profile_store.gd` does not exist.

- [ ] **Step 3: Implement the local store**

```gdscript
class_name LocalProfileStore
extends RefCounted

var path: String

func _init(file_path := "user://prototype-profile.json") -> void:
    path = file_path

func load_profile() -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    return parsed if parsed is Dictionary else {}

func save_profile(profile: Dictionary) -> Error:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(profile))
    return OK

func reset_profile() -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

- [ ] **Step 4: Run the persistence and existing tests**

Expected: local store, main flow and progression tests all print `PASS`.

- [ ] **Step 5: Commit**

```text
feat: add disposable local prototype profile
```

### Task 3: Introduce reproducible scenario definitions

**Files:**
- Create: `godot-demo/data/scenarios.json`
- Create: `godot-demo/src/prototype/scenario_catalog.gd`
- Create: `godot-demo/tests/test_scenario_catalog.gd`

- [ ] **Step 1: Write the failing catalog test**

```gdscript
extends SceneTree

const ScenarioCatalog = preload("res://src/prototype/scenario_catalog.gd")

func _init() -> void:
    var catalog = ScenarioCatalog.new()
    assert(catalog.load_from("res://data/scenarios.json") == OK)
    assert(catalog.get_scenario("boss_baseline").seed == 7188)
    assert(catalog.get_scenario("short_build_test").rules.run_star_target == 5)
    print("Godot scenario catalog: PASS")
    quit(0)
```

- [ ] **Step 2: Run the test and verify RED**

Expected: non-zero exit because the catalog does not exist.

- [ ] **Step 3: Create the first two scenarios**

```json
{
  "scenarios": [
    {
      "id": "boss_baseline",
      "title": "老板基线 v7.18.8",
      "seed": 7188,
      "rules": { "run_star_target": 15, "opening_pick_count": 3 }
    },
    {
      "id": "short_build_test",
      "title": "短局 Build 完成度实验",
      "seed": 71401,
      "rules": { "run_star_target": 5, "opening_pick_count": 3 }
    }
  ]
}
```

- [ ] **Step 4: Implement the catalog**

```gdscript
class_name ScenarioCatalog
extends RefCounted

var scenarios: Dictionary = {}

func load_from(path: String) -> Error:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary or not parsed.has("scenarios"):
        return ERR_PARSE_ERROR
    scenarios.clear()
    for scenario in parsed.scenarios:
        scenarios[scenario.id] = scenario
    return OK

func get_scenario(id: String) -> Dictionary:
    return scenarios.get(id, {})
```

- [ ] **Step 5: Run catalog and regression tests**

Expected: all Godot tests print `PASS`.

- [ ] **Step 6: Commit**

```text
feat: add reproducible prototype scenarios
```

### Task 4: Add a designer-facing scenario launcher

**Files:**
- Create: `godot-demo/scenes/prototype_launcher.tscn`
- Create: `godot-demo/src/prototype/prototype_launcher.gd`
- Modify: `godot-demo/scenes/main.tscn`
- Modify: `godot-demo/src/app/main.gd`
- Modify: `godot-demo/project.godot`
- Modify: `godot-demo/tests/test_main_flow.gd`

- [ ] **Step 1: Extend the flow test with scenario selection and restart**

The test must select `boss_baseline`, enter the existing title-to-battle flow, call `restart_scenario()`, and assert that phase, kills, selections and random seed return to their scenario defaults.

```gdscript
main.start_scenario("boss_baseline")
assert(main.active_scenario_id == "boss_baseline")
main.select_city(0)
main.select_ruler("caocao")
main.select_opening_hero("jiangwei")
main.restart_scenario()
assert(main.phase == "title")
assert(main.kills == 0)
assert(main.selected_city == -1)
assert(main.random_seed == 7188)
```

- [ ] **Step 2: Run the test and verify RED**

Expected: failure because scenario and restart methods do not exist.

- [ ] **Step 3: Implement the launcher**

Create `godot-demo/src/prototype/prototype_launcher.gd`:

```gdscript
class_name PrototypeLauncher
extends VBoxContainer

signal scenario_selected(id: String)

func configure(catalog) -> void:
    for child in get_children():
        if child is Button:
            child.queue_free()
    for id in catalog.scenarios:
        var scenario: Dictionary = catalog.scenarios[id]
        var button := Button.new()
        button.text = str(scenario.get("title", id))
        button.pressed.connect(func(): scenario_selected.emit(id))
        add_child(button)
```

Create `godot-demo/scenes/prototype_launcher.tscn`:

```text
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/prototype/prototype_launcher.gd" id="1"]

[node name="PrototypeLauncher" type="VBoxContainer"]
offset_left = 48.0
offset_top = 220.0
offset_right = 432.0
offset_bottom = 580.0
theme_override_constants/separation = 18
script = ExtResource("1")

[node name="Title" type="Label" parent="."]
layout_mode = 2
text = "选择设计实验"
horizontal_alignment = 1

[node name="Note" type="Label" parent="."]
layout_mode = 2
text = "离线原型 · 数据可重置 · 固定种子可复现"
horizontal_alignment = 1
```

Add the launcher instance to `godot-demo/scenes/main.tscn`:

```text
[ext_resource type="PackedScene" path="res://scenes/prototype_launcher.tscn" id="2_launcher"]

[node name="PrototypeLauncher" parent="." instance=ExtResource("2_launcher")]
```

- [ ] **Step 4: Add explicit reset methods to the main controller**

```gdscript
const ScenarioCatalog = preload("res://src/prototype/scenario_catalog.gd")

@onready var launcher = $PrototypeLauncher

var scenario_catalog = ScenarioCatalog.new()
var active_scenario_id := ""
var random_seed := 0

func _ready() -> void:
    assert(scenario_catalog.load_from("res://data/scenarios.json") == OK)
    launcher.configure(scenario_catalog)
    launcher.scenario_selected.connect(start_scenario)
    set_process(true)
    queue_redraw()

func start_scenario(id: String) -> void:
    active_scenario_id = id
    var scenario := scenario_catalog.get_scenario(id)
    random_seed = int(scenario.get("seed", 0))
    launcher.hide()
    restart_scenario()

func restart_scenario() -> void:
    phase = "title"
    selected_city = -1
    selected_ruler = ""
    selected_hero = ""
    battle_time = 0.0
    battle_tick = 0.0
    kills = 0
    level = 1
    queue_redraw()
```

- [ ] **Step 5: Run all tests and launch the visible build**

Expected: launcher → baseline → complete vertical slice works; restart returns to the same scenario with the same seed.

- [ ] **Step 6: Commit**

```text
feat: add offline prototype scenario launcher
```

### Task 5: Establish proposal evidence and export checks

**Files:**
- Create: `docs/proposals/README.md`
- Create: `docs/proposals/template.md`
- Create: `godot-demo/export_presets.cfg`
- Modify: `README.md`

- [ ] **Step 1: Add the proposal template**

```markdown
# 方案名称

## 要解决的体验问题

## 基线中的证据

## 本次只改变什么

## 可玩入口与复现种子

## 观察结果

## 结论：合并 / 继续试验 / 放弃
```

- [ ] **Step 2: Configure a Windows Desktop export preset**

Create `godot-demo/export_presets.cfg`:

```ini
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="../build/windows/不一样三国2原型.exe"
script_export_mode=2

[preset.0.options]

binary_format/embed_pck=true
texture_format/s3tc_bptc=true
texture_format/etc2_astc=false
```

Add `/build/` to `.gitignore`.

- [ ] **Step 3: Run the final verification**

```powershell
npm test
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --headless --path godot-demo --script res://tests/test_progression.gd
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --headless --path godot-demo --script res://tests/test_main_flow.gd
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --headless --path godot-demo --editor --quit
git diff --check
```

Expected: 11 Web tests pass, all Godot tests print `PASS`, import exits 0, and `git diff --check` reports nothing.

- [ ] **Step 4: Commit**

```text
docs: add prototype proposal and export workflow
```
