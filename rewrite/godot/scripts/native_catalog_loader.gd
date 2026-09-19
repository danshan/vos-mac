extends RefCounted

const Wire = preload("res://scripts/native_json.gd")
const Integrity = preload("res://scripts/native_bundle_integrity.gd")


func load_catalog(path: String, roots: Array, cancel: Callable, root_ids: Dictionary = {}) -> Dictionary:
	var document: Dictionary = Integrity.new().read_json(path, 67108864, {}, cancel)
	if not Wire.fields(document, ["schemaVersion", "entries", "rejected"]) or document["schemaVersion"] != 2 or not document["entries"] is Array or not document["rejected"] is Array:
		return {}
	var allowed := {}
	var seen_ids := {}
	if not root_ids.is_empty() and root_ids.size() != roots.size():
		return {}
	for root: Variant in roots:
		if not Wire.text(root, true) or not str(root).is_absolute_path():
			return {}
		var root_id: Variant = root_ids.get(root, "")
		if not root_ids.is_empty():
			if not Wire.identifier(root_id, "library:sha256:") or seen_ids.has(root_id):
				return {}
			seen_ids[root_id] = true
		allowed[_root_path(root)] = root_id
	var entries: Array[Dictionary] = []
	var origins := {}
	for entry: Variant in document["entries"]:
		if Wire.cancelled(cancel) or not _entry_valid(entry, allowed):
			return {}
		# Declared bundle IDs remain unchanged; selection identity belongs to its source.
		var origin := JSON.stringify([entry.get("rootId", _root_path(entry["rootPath"])), entry["relativePath"]])
		if origins.has(origin):
			return {}
		origins[origin] = true
		entries.append({
			"id": "bundle-source-" + Wire.sha256(origin.to_utf8_buffer()).trim_prefix("sha256:"),
			"rootPath": entry["rootPath"], "relativePath": entry["relativePath"], "sourcePath": entry["sourcePath"],
			"rootId": entry.get("rootId", ""),
			"songId": entry["songId"], "chartId": entry["chartId"], "title": entry["title"], "artist": entry["artist"],
			"format": "BUNDLE", "keys": 7, "levelKnown": false,
			"nativeRequest": {"schemaVersion": 1, "command": "BUNDLE", "sourceKind": "BUNDLE_V2",
				"chartId": entry["chartId"], "sourcePath": entry["sourcePath"],
				"selector": {"kind": "BUNDLE_CHART", "chartId": entry["chartId"]},
				"staticAssetsVersion": entry["staticAssetsVersion"],
				"soundfont": {"path": str(entry["sourcePath"]).path_join("bundle.json"), "version": entry["soundfont"]["version"], "sha256": entry["soundfont"]["sha256"]}}
		})
	var errors: Array[String] = []
	for rejected: Variant in document["rejected"]:
		if Wire.cancelled(cancel) or not Wire.fields(rejected, ["sourcePath", "error"]) or not Wire.text(rejected["sourcePath"], true) or not str(rejected["sourcePath"]).is_absolute_path():
			return {}
		var error: Variant = rejected["error"]
		if not Wire.fields(error, ["code", "message", "sourcePath", "context"]) or not Wire.text(error["code"], true) or not Wire.text(error["message"]) or not error["context"] is Dictionary:
			return {}
		errors.append("%s: %s" % [rejected["sourcePath"], error["message"]])
	return {} if Wire.cancelled(cancel) else {"entries": entries, "errors": errors}


func _entry_valid(entry: Variant, allowed: Dictionary) -> bool:
	var fields := ["rootPath", "relativePath", "sourcePath", "sourceKind", "songId", "chartId", "title", "artist", "soundfont", "staticAssetsVersion"]
	if entry is Dictionary and entry.has("rootId"):
		fields.append("rootId")
	if not Wire.fields(entry, fields):
		return false
	for field: String in ["rootPath", "relativePath", "sourcePath", "title", "artist"]:
		if not Wire.text(entry[field]):
			return false
	var root := _root_path(entry["rootPath"])
	var relative: String = entry["relativePath"]
	if not allowed.has(root) or (not relative.is_empty() and not Wire.relative_path(relative, false)):
		return false
	if allowed[root] != "":
		if entry.get("rootId", "") != allowed[root]:
			return false
	elif entry.has("rootId"):
		return false
	var expected := root if relative.is_empty() else root.path_join(relative)
	if entry["sourcePath"] != expected or entry["sourceKind"] != "BUNDLE_V2" or entry["staticAssetsVersion"] != Integrity.STATIC_ASSETS:
		return false
	return Wire.identifier(entry["songId"], "song:sha256:") and Wire.identifier(entry["chartId"], "chart:sha256:") \
		and Wire.fields(entry["soundfont"], ["version", "sha256"]) and Wire.text(entry["soundfont"]["version"], true) and Wire.identifier(entry["soundfont"]["sha256"], "sha256:")


static func _root_path(path: String) -> String:
	return path.simplify_path().trim_suffix("/") if path != "/" else path
