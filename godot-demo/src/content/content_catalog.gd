class_name ContentCatalog
extends RefCounted

var version := ""
var content: Dictionary = {}
var indexes: Dictionary = {}

func load_from(path: String) -> Error:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()
    var parsed = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return ERR_PARSE_ERROR
    version = str(parsed.get("version", ""))
    content = parsed
    indexes.clear()
    return OK

func list(key: String) -> Array:
    var value = content.get(key, [])
    if value is Array:
        return value
    if value is Dictionary:
        return value.values()
    return []

func by_id(key: String, id: String) -> Dictionary:
    if not indexes.has(key):
        var index := {}
        var value = content.get(key, [])
        if value is Array:
            for entry in value:
                if entry is Dictionary and entry.has("id"):
                    index[str(entry.id)] = entry
        elif value is Dictionary:
            for entry_id in value:
                var entry = value[entry_id]
                if entry is Dictionary:
                    entry = entry.duplicate()
                    entry["id"] = str(entry_id)
                    index[str(entry_id)] = entry
        indexes[key] = index
    return indexes[key].get(id, {})
