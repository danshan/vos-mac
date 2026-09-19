extends RefCounted

const Wire = preload("res://scripts/native_json.gd")
const STATIC_ASSETS := "open2jam-gameplay-assets-v1"


func verify(root: String, expected_key: String = "") -> Dictionary:
	var parent := DirAccess.open(root.get_base_dir())
	if parent == null or parent.is_link(root.get_file()) or not DirAccess.dir_exists_absolute(root):
		return {}
	var manifest := read_json(root.path_join("bundle.json"), 1048576)
	if not _manifest_valid(manifest) or (not expected_key.is_empty() and manifest["bundleKey"] != expected_key):
		return {}
	var files := {}
	var directories := {}
	for entry: Dictionary in manifest["files"]:
		files[entry["path"]] = entry
		var parts: PackedStringArray = str(entry["path"]).split("/")
		var prefix := ""
		for index in range(parts.size() - 1):
			prefix = parts[index] if prefix.is_empty() else prefix + "/" + parts[index]
			directories[prefix] = true
	var stack: Array[String] = [""]
	var seen := {}
	while not stack.is_empty():
		var relative: String = stack.pop_back()
		var directory := DirAccess.open(root.path_join(relative))
		if directory == null:
			return {}
		directory.include_hidden = true
		if directory.list_dir_begin() != OK:
			return {}
		var name := directory.get_next()
		while not name.is_empty():
			var path := name if relative.is_empty() else relative + "/" + name
			if directory.is_link(name):
				return {}
			if directory.current_is_dir():
				if not directories.has(path):
					return {}
				stack.append(path)
			elif path == "bundle.json":
				pass
			elif not files.has(path) or not _file_valid(root.path_join(path), files[path]):
				return {}
			else:
				seen[path] = true
			name = directory.get_next()
		directory.list_dir_end()
	if seen.size() != files.size():
		return {}
	return manifest


func read_json(path: String, limit: int, expected: Dictionary = {}) -> Dictionary:
	var parent := DirAccess.open(path.get_base_dir())
	if parent == null or parent.is_link(path.get_file()):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > limit:
		return {}
	var bytes := file.get_buffer(file.get_length())
	if bytes.size() != file.get_length():
		return {}
	if not expected.is_empty() and (bytes.size() != expected["sizeBytes"] or Wire.sha256(bytes) != expected["sha256"]):
		return {}
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {}
	return Wire.parse_object(text)


func _file_valid(path: String, entry: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != entry["sizeBytes"]:
		return false
	var remaining := int(entry["sizeBytes"])
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	while remaining > 0:
		var count := mini(remaining, 65536)
		var bytes := file.get_buffer(count)
		if bytes.size() != count:
			return false
		hash.update(bytes)
		remaining -= count
	return file.get_length() == entry["sizeBytes"] and "sha256:" + hash.finish().hex_encode() == entry["sha256"]


func _manifest_valid(value: Dictionary) -> bool:
	if not Wire.fields(value, ["schemaVersion", "complete", "bundleKey", "converterVersion", "staticAssetsVersion", "soundfont", "songId", "chartId", "chartSelector", "sourceFingerprint", "files"]):
		return false
	if value["schemaVersion"] != 2 or not value["complete"] is bool or not value["complete"]:
		return false
	if value["staticAssetsVersion"] != STATIC_ASSETS or not Wire.text(value["converterVersion"], true):
		return false
	if not Wire.fields(value["soundfont"], ["version", "sha256"]) or not Wire.text(value["soundfont"]["version"], true) or not Wire.identifier(value["soundfont"]["sha256"], "sha256:"):
		return false
	for pair: Array in [["songId", "song:sha256:"], ["chartId", "chart:sha256:"], ["bundleKey", "sha256:"], ["sourceFingerprint", "sha256:"]]:
		if not Wire.identifier(value[pair[0]], pair[1]):
			return false
	var selector := _selector_bytes(value["chartSelector"])
	if selector.is_empty() or not value["files"] is Array or value["files"].size() > 65536:
		return false
	var identity := "open2jam.chart-id.v2".to_utf8_buffer() + PackedByteArray([0]) + Wire.number_bytes(2, 2) + Wire.framed(Wire.digest_bytes(value["songId"])) + selector
	var chart_id: String = value["chartSelector"]["chartId"] if value["chartSelector"]["kind"] == "BUNDLE_CHART" else "chart:" + Wire.sha256(identity)
	if chart_id != value["chartId"]:
		return false
	var key := "open2jam.bundle-key.v1".to_utf8_buffer() + PackedByteArray([0]) + Wire.number_bytes(1, 2) + Wire.number_bytes(2, 2)
	key += Wire.framed(value["converterVersion"].to_utf8_buffer()) + Wire.framed(STATIC_ASSETS.to_utf8_buffer())
	for digest: String in [value["soundfont"]["sha256"], value["songId"], value["chartId"]]:
		key += Wire.framed(Wire.digest_bytes(digest))
	key += selector + Wire.framed(Wire.digest_bytes(value["sourceFingerprint"]))
	if Wire.sha256(key) != value["bundleKey"]:
		return false
	var nodes := {"bundle.json": ["bundle.json", true]}
	var paths := {}
	var previous := ""
	for entry: Variant in value["files"]:
		if not Wire.fields(entry, ["path", "sizeBytes", "sha256"]) or not Wire.relative_path(entry["path"]) or not Wire.integer(entry["sizeBytes"]) or not Wire.identifier(entry["sha256"], "sha256:"):
			return false
		var path: String = entry["path"]
		if path <= previous:
			return false
		previous = path
		paths[path] = true
		var prefix := ""
		for part: String in path.split("/"):
			prefix = part if prefix.is_empty() else prefix + "/" + part
			var folded := prefix.to_lower()
			var is_file := prefix == path
			if nodes.has(folded) and (nodes[folded][0] != prefix or nodes[folded][1] or is_file):
				return false
			nodes[folded] = [prefix, is_file]
	return paths.has("gameplay.json") and paths.has("audio-manifest.json")


func _selector_bytes(value: Variant) -> PackedByteArray:
	if not value is Dictionary:
		return []
	match value.get("kind"):
		"VOS_CHART", "OJN_CHART":
			var vos: bool = value["kind"] == "VOS_CHART"
			if Wire.fields(value, ["kind", "index"]) and Wire.integer(value["index"], 0 if vos else 2):
				return Wire.number_bytes(1 if vos else 2, 2) + Wire.number_bytes(int(value["index"]), 2)
		"OSU_BEATMAP":
			if Wire.fields(value, ["kind", "relativePath"]) and Wire.relative_path(value["relativePath"], false):
				return Wire.number_bytes(3, 2) + Wire.framed(value["relativePath"].to_utf8_buffer())
		"BUNDLE_CHART":
			if Wire.fields(value, ["kind", "chartId"]) and Wire.identifier(value["chartId"], "chart:sha256:"):
				return Wire.number_bytes(4, 2) + Wire.framed(Wire.digest_bytes(value["chartId"]))
	return []
