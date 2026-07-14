extends SceneTree

const ContentCatalog = preload("res://src/content/content_catalog.gd")

func _init() -> void:
    var catalog = ContentCatalog.new()
    assert(catalog.load_from("res://data/content-v7.19.0.json") == OK)
    assert(catalog.version == "7.19.0")
    assert(catalog.list("heroes").size() == 45)
    assert(catalog.list("bonds").size() == 18)
    assert(catalog.list("rulers").size() == 8)
    assert(catalog.list("state_names").size() == 64)
    assert(catalog.list("fields").size() == 11)
    assert(catalog.list("relics").size() == 30)
    assert(catalog.by_id("heroes", "wenchou").name == "文丑")
    assert(catalog.by_id("specials", "cata").name == "投石车")
    assert(catalog.by_id("rulers", "sunquan").special == "shuijun")
    print("Godot v7.19.0 content catalog: PASS")
    quit(0)
