extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var catalog = ContentCatalog.new()
    if not _expect(catalog.load_from("res://data/content-v7.19.2.json") == OK, "v7.19.2 content file must load"):
        return
    if not _expect(catalog.version == "7.19.2", "content version must match the live baseline"):
        return
    if not _expect(catalog.list("heroes").size() == 45, "all 45 heroes must be present"):
        return
    if not _expect(catalog.list("bonds").size() == 18, "all 18 bonds must be present"):
        return
    if not _expect(catalog.list("rulers").size() == 8, "all 8 rulers must be present"):
        return
    if not _expect(catalog.list("state_names").size() == 64, "all 64 states must be present"):
        return
    if not _expect(catalog.list("fields").size() == 11, "all 11 fields must be present"):
        return
    if not _expect(catalog.list("boss_kits").size() == 8, "all eight chapter boss kits must be present"):
        return
    if not _expect(catalog.by_id("level_rules", "rush").short == "急行军", "level rule labels must be queryable"):
        return
    if not _expect(catalog.list("relics").size() == 30, "all 30 relics must be present"):
        return
    if not _expect(catalog.by_id("heroes", "wenchou").name == "文丑", "latest hero metadata must be queryable"):
        return
    if not _expect(catalog.by_id("specials", "cata").name == "投石车", "catapult metadata must be present"):
        return
    if not _expect(catalog.by_id("rulers", "sunquan").special == "shuijun", "ruler metadata must be preserved"):
        return
    print("Godot v7.19.2 content catalog: PASS")
    quit(0)

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
