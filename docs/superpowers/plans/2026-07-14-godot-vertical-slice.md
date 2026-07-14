# Godot Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Godot project directly runnable through the same top-level flow as the Web Demo: title → weekly map → ruler selection → opening hero selection → automatic battle.

**Architecture:** A single `Control` scene owns only the first visual slice and delegates portable math to `Progression`. Public transition methods make the flow headlessly testable; later milestones replace each temporary drawing section with dedicated scenes and complete systems.

**Tech Stack:** Godot 4.7, GDScript, `Control._draw()`, headless Godot tests.

---

### Task 1: Define the runnable flow test

**Files:**
- Create: `godot-demo/tests/test_main_flow.gd`

- [x] **Step 1: Write the failing scene-flow test**

```gdscript
extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _init() -> void:
    var main = MainScene.instantiate()
    root.add_child(main)
    assert(main.phase == "title")
    main.advance_from_title()
    assert(main.phase == "map")
    main.select_city(0)
    assert(main.phase == "ruler")
    main.select_ruler("caocao")
    assert(main.phase == "pick")
    main.select_opening_hero("jiangwei")
    assert(main.phase == "battle")
    assert(main.selected_city == 0)
    assert(main.selected_ruler == "caocao")
    assert(main.selected_hero == "jiangwei")
    print("Godot main flow: PASS")
    quit(0)
```

- [x] **Step 2: Run the test and verify RED**

Expected: non-zero exit because `res://scenes/main.tscn` does not exist.

### Task 2: Implement the interactive vertical slice

**Files:**
- Create: `godot-demo/scenes/main.tscn`
- Create: `godot-demo/src/app/main.gd`
- Modify: `godot-demo/project.godot`

- [x] **Step 1: Create a full-viewport `Control` main scene**

The scene attaches `src/app/main.gd` and receives mouse/touch input.

- [x] **Step 2: Implement explicit transition methods**

```gdscript
func advance_from_title() -> void
func select_city(index: int) -> void
func select_ruler(ruler_id: String) -> void
func select_opening_hero(hero_id: String) -> void
```

Each method updates only the required selection and phase, then calls `queue_redraw()`.

- [x] **Step 3: Draw the five states at 480×800**

Preserve the current dark brown/gold visual language, four-region/64-city wording, eight-ruler presentation, three opening hero cards, 5×3 formation grid, wall, ruler badge, and visible automatic battle feedback.

- [x] **Step 4: Add pointer transitions**

- Title: click/tap enters the map.
- Map: click the first city enters ruler selection.
- Ruler: click one of eight rows selects that ruler.
- Pick: click one of three cards starts battle.

- [x] **Step 5: Set `run/main_scene` in `project.godot`**

- [x] **Step 6: Run the headless flow test and project import**

Expected: `Godot main flow: PASS`, progression parity still passes, and project import exits 0.

- [x] **Step 7: Launch the project and capture a screenshot**

Expected: the 480×800 Godot window opens on the title screen and accepts input through the five-state flow.

- [x] **Step 8: Commit**

```text
feat: add playable Godot vertical slice
```
