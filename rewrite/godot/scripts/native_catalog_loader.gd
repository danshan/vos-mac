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
	var charts := {}
	var sources := {}
	for entry: Variant in document["entries"]:
		if Wire.cancelled(cancel) or not _entry_valid(entry, allowed):
			return {}
		# A source owns its song selection identity; charts remain independently selectable.
		var origin := JSON.stringify([entry.get("rootId", _root_path(entry["rootPath"])), entry["relativePath"]])
		sources[origin] = true
		if entry["sourceKind"] == "OSU":
			origin = JSON.stringify([entry["rootId"], "OSU", str(entry["relativePath"]).get_base_dir()])
		var chart_origin := JSON.stringify([origin, entry["chartId"]])
		if charts.has(chart_origin):
			return {}
		charts[chart_origin] = true
		if origins.has(origin):
			var previous: Dictionary = origins[origin]
			if previous["sourceKind"] != entry["sourceKind"] or previous["songId"] != entry["songId"]:
				return {}
			if entry["sourceKind"] == "OJN":
				if previous["title"] != entry["title"] or previous["artist"] != entry["artist"] or previous["indices"].has(entry["chartIndex"]):
					return {}
				previous["indices"].append(entry["chartIndex"])
			elif entry["sourceKind"] == "OSU":
				if previous["paths"].has(entry["chartPath"]):
					return {}
				previous["paths"].append(entry["chartPath"])
			else:
				return {}
		else:
			origins[origin] = {"sourceKind": entry["sourceKind"], "songId": entry["songId"], "title": entry["title"], "artist": entry["artist"], "indices": [entry.get("chartIndex", -1)], "paths": [entry.get("chartPath", "")]}
		var source_id := "bundle-source-" + Wire.sha256(origin.to_utf8_buffer()).trim_prefix("sha256:")
		var item := {
			"id": source_id, "sourceId": source_id,
			"rootPath": entry["rootPath"], "relativePath": entry["relativePath"], "sourcePath": entry["sourcePath"],
			"rootId": entry.get("rootId", ""),
			"songId": entry["songId"], "chartId": entry["chartId"], "title": entry["title"], "artist": entry["artist"],
			"format": "BUNDLE", "keys": 7, "levelKnown": false,
		}
		var request := {"schemaVersion": 1, "command": "BUNDLE", "sourceKind": entry["sourceKind"],
			"chartId": entry["chartId"], "sourcePath": entry["sourcePath"], "staticAssetsVersion": Integrity.STATIC_ASSETS}
		if entry["sourceKind"] == "OJN":
			item["id"] = source_id + "-" + str(int(entry["chartIndex"]))
			item["format"] = "O2JAM"
			item["levelKnown"] = true
			item["level"] = int(entry["level"])
			item["chartIndex"] = int(entry["chartIndex"])
			item["durationSeconds"] = int(entry["durationSeconds"])
			request["selector"] = {"kind": "OJN_CHART", "index": int(entry["chartIndex"])}
			request["libraryRoot"] = {"id": entry["rootId"], "path": entry["rootPath"]}
			# OJN does not use a SoundFont; the generic bundle key still requires this descriptor.
			request["soundfont"] = {"path": entry["sourcePath"], "version": "unused", "sha256": "sha256:" + "00".repeat(32)}
		elif entry["sourceKind"] == "OSU":
			item["id"] = source_id + "-" + str(entry["chartId"]).trim_prefix("chart:sha256:")
			item["format"] = "OSU"
			item["levelKnown"] = true
			item["level"] = int(entry["level"])
			item["difficultyName"] = entry["difficultyName"]
			item["durationSeconds"] = int(entry["durationSeconds"])
			request["selector"] = {"kind": "OSU_BEATMAP", "relativePath": entry["chartPath"]}
			request["libraryRoot"] = {"id": entry["rootId"], "path": entry["rootPath"]}
			request["soundfont"] = {"path": entry["sourcePath"], "version": "unused", "sha256": "sha256:" + "00".repeat(32)}
		else:
			request["selector"] = {"kind": "BUNDLE_CHART", "chartId": entry["chartId"]}
			request["soundfont"] = {"path": str(entry["sourcePath"]).path_join("bundle.json"), "version": entry["soundfont"]["version"], "sha256": entry["soundfont"]["sha256"]}
		item["nativeRequest"] = request
		entries.append(item)
	for source: Dictionary in origins.values():
		if source["sourceKind"] == "OJN" and source["indices"].size() != 3:
			return {}
	var errors: Array[String] = []
	for rejected: Variant in document["rejected"]:
		if Wire.cancelled(cancel) or not Wire.fields(rejected, ["sourcePath", "error"]) or not Wire.text(rejected["sourcePath"], true) or not str(rejected["sourcePath"]).is_absolute_path():
			return {}
		var error: Variant = rejected["error"]
		if not Wire.fields(error, ["code", "message", "sourcePath", "context"]) or not Wire.text(error["code"], true) or not Wire.text(error["message"]) or not error["context"] is Dictionary:
			return {}
		errors.append("%s: %s" % [rejected["sourcePath"], error["message"]])
	return {} if Wire.cancelled(cancel) else {"entries": entries, "errors": errors, "songCount": origins.size(), "sourceCount": sources.size() + errors.size()}


func _entry_valid(entry: Variant, allowed: Dictionary) -> bool:
	if not entry is Dictionary:
		return false
	var kind: Variant = entry.get("sourceKind", "")
	var fields := ["rootPath", "relativePath", "sourcePath", "sourceKind", "songId", "chartId", "title", "artist"]
	if kind == "BUNDLE_V2":
		fields.append_array(["soundfont", "staticAssetsVersion"])
	elif kind == "OSU":
		fields.append_array(["chartPath", "difficultyName", "level", "durationSeconds"])
	elif kind == "OJN":
		fields.append_array(["chartIndex", "level", "durationSeconds"])
	else:
		return false
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
	if entry["sourcePath"] != expected:
		return false
	if not Wire.identifier(entry["songId"], "song:sha256:") or not Wire.identifier(entry["chartId"], "chart:sha256:"):
		return false
	if kind == "OSU":
		return allowed[root] != "" and not relative.is_empty() and Wire.relative_path(entry["chartPath"], false) and entry["chartPath"] == relative.get_file() and Wire.text(entry["difficultyName"]) and Wire.integer(entry["level"], 2147483647) and Wire.integer(entry["durationSeconds"], 2147483647)
	if kind == "OJN":
		return allowed[root] != "" and not relative.is_empty() and Wire.integer(entry["chartIndex"], 2) and Wire.integer(entry["level"], 32767) and Wire.integer(entry["durationSeconds"], 2147483647)
	return entry["staticAssetsVersion"] == Integrity.STATIC_ASSETS and Wire.fields(entry["soundfont"], ["version", "sha256"]) and Wire.text(entry["soundfont"]["version"], true) and Wire.identifier(entry["soundfont"]["sha256"], "sha256:")


static func _root_path(path: String) -> String:
	return path.simplify_path().trim_suffix("/") if path != "/" else path
