# Godot Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create an importable Godot 4.7 project and prove the first Web domain rules behave identically in GDScript.

**Architecture:** The Godot project starts with engine-independent GDScript rules under `src/core/`. Headless test scripts own parity checks; scenes are added only after their required rules have been ported and verified.

**Tech Stack:** Godot 4.7, GDScript, headless Godot test scripts, Git.

---

### Task 1: Create the Godot project shell

**Files:**
- Create: `godot-demo/project.godot`
- Create: `godot-demo/icon.svg`

- [ ] **Step 1: Add a 480×800 Godot 4 project configuration**

```ini
[application]
config/name="不一样三国 2.0"
config/features=PackedStringArray("4.7")

[display]
window/size/viewport_width=480
window/size/viewport_height=800
window/size/window_width_override=480
window/size/window_height_override=800
window/stretch/mode="canvas_items"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Step 2: Import the project headlessly**

Run:

```powershell
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --headless --path godot-demo --editor --quit
```

Expected: exit code 0 with no parse or import error.

### Task 2: Port progression rules with parity tests

**Files:**
- Create: `godot-demo/tests/test_progression.gd`
- Create: `godot-demo/src/core/progression.gd`

- [ ] **Step 1: Write the failing headless test**

```gdscript
extends SceneTree

const Progression = preload("res://src/core/progression.gd")

func _init() -> void:
    assert(Progression.star_parts(1) == {"t2": 0, "hi": 0, "lo": 1})
    assert(Progression.star_parts(15) == {"t2": 5, "hi": 0, "lo": 0})
    assert(is_equal_approx(Progression.star_damage_multiplier(6, false), pow(1.9, 4) * 1.4))
    assert(is_equal_approx(Progression.star_damage_multiplier(11, true), pow(1.9, 4) * pow(1.5, 5) * 1.4))
    print("Godot progression parity: PASS")
    quit(0)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& '.tools\godot-4.7\Godot_v4.7-stable_win64_console.exe' --headless --path godot-demo --script res://tests/test_progression.gd
```

Expected: non-zero exit because `src/core/progression.gd` does not exist.

- [ ] **Step 3: Implement the pure GDScript rules**

```gdscript
class_name Progression
extends RefCounted

static func star_parts(level: int) -> Dictionary:
    if level <= 5:
        return {"t2": 0, "hi": 0, "lo": level}
    if level <= 10:
        return {"t2": 0, "hi": level - 5, "lo": 10 - level}
    return {"t2": level - 10, "hi": 15 - level, "lo": 0}

static func star_damage_multiplier(level: int, has_phoenix_feather: bool) -> float:
    var ascended := 1.5 if has_phoenix_feather else 1.4
    var ascended_2 := 1.4 if has_phoenix_feather else 1.3
    return pow(1.9, min(level, 5) - 1) \
        * pow(ascended, max(0, min(level, 10) - 5)) \
        * pow(ascended_2, max(0, level - 10))
```

- [ ] **Step 4: Run the test and verify GREEN**

Expected: `Godot progression parity: PASS` and exit code 0.

- [ ] **Step 5: Re-run Web tests and Godot project import**

Expected: all Web tests pass; Godot import exits 0.

- [ ] **Step 6: Commit**

```text
feat: bootstrap Godot project with progression parity
```
