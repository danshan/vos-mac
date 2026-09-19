extends RefCounted

const Wire = preload("res://scripts/native_json.gd")
const Integrity = preload("res://scripts/native_bundle_integrity.gd")
const FORMATS := {"VOS": "VOS", "O2JAM": "OJN", "OSU_MANIA": "OSU"}


func load_bundle(root: String, expected_key: String = "", cancel: Callable = Callable()) -> Dictionary:
	if Wire.cancelled(cancel):
		return {}
	var integrity = Integrity.new()
	var manifest: Dictionary = integrity.verify(root, expected_key, cancel)
	if manifest.is_empty():
		return {}
	var files := {}
	for entry: Dictionary in manifest["files"]:
		if Wire.cancelled(cancel):
			return {}
		files[entry["path"]] = entry
	var chart: Dictionary = integrity.read_json(root.path_join("gameplay.json"), 67108864, files["gameplay.json"], cancel)
	var audio: Dictionary = integrity.read_json(root.path_join("audio-manifest.json"), 67108864, files["audio-manifest.json"], cancel)
	if Wire.cancelled(cancel) or not _chart_valid(chart, cancel) or not _audio_valid(audio, chart, manifest, files, cancel):
		return {}
	var mapping := {}
	var assets: Array[Dictionary] = []
	for asset: Dictionary in audio["assets"]:
		if Wire.cancelled(cancel):
			return {}
		var index := mapping.size() + 1
		mapping[asset["sampleId"]] = index
		var path := root.path_join(asset["path"])
		if AudioStreamWAV.load_from_file(path) == null:
			return {}
		assets.append({"sampleId": index, "fileName": str(asset["path"]).get_file(), "path": path, "type": "wav", "role": "sample", "preload": true})
	var normalized := {
		"schemaVersion": 1, "chartId": chart["chartId"], "songId": chart["songId"],
		"format": FORMATS[chart["format"]], "keys": 7, "title": chart["title"], "artist": chart["artist"],
		"durationMs": float(chart["durationUs"]) / 1000.0,
		"bpm": Wire.ratio_value(chart["judgmentTiming"][0]["bpm"]),
		"notes": [], "measures": [], "judgmentTiming": [], "visualTiming": [], "scroll": [], "autoPlayEvents": []
	}
	for note: Dictionary in chart["notes"]:
		if Wire.cancelled(cancel):
			return {}
		var converted := _sound_event(note, mapping)
		converted["startMs"] = float(note["startUs"]) / 1000.0
		converted["lane"] = int(note["lane"])
		converted["measure"] = int(note["measure"])
		converted["kind"] = "tap"
		if note.get("tail") != null:
			converted["kind"] = "holdStart"
			converted["endMs"] = float(note["tail"]["atUs"]) / 1000.0
			converted["endMeasure"] = int(note["tail"]["measure"])
			converted["releaseEventOrder"] = int(note["tail"]["eventOrder"])
		normalized["notes"].append(converted)
	for time: Variant in chart["measures"]:
		if Wire.cancelled(cancel):
			return {}
		normalized["measures"].append({"startMs": float(time) / 1000.0})
	for track: String in ["judgmentTiming", "visualTiming"]:
		if Wire.cancelled(cancel):
			return {}
		for point: Dictionary in chart[track]:
			if Wire.cancelled(cancel):
				return {}
			normalized[track].append({"timeMs": float(point["atUs"]) / 1000.0, "bpm": Wire.ratio_value(point["bpm"]), "eventOrder": int(point["eventOrder"])})
	for point: Dictionary in chart["scroll"]:
		if Wire.cancelled(cancel):
			return {}
		normalized["scroll"].append({"timeMs": float(point["atUs"]) / 1000.0, "multiplier": Wire.ratio_value(point["multiplier"]), "eventOrder": int(point["eventOrder"])})
	for event: Dictionary in chart["autoPlayEvents"]:
		if Wire.cancelled(cancel):
			return {}
		var converted := _sound_event(event, mapping)
		converted["startMs"] = float(event["atUs"]) / 1000.0
		normalized["autoPlayEvents"].append(converted)
	if Wire.cancelled(cancel):
		return {}
	return {"chart": normalized, "audio": {"schemaVersion": 1, "format": normalized["format"], "assets": assets}, "bundleKey": manifest["bundleKey"]}

func _sound_event(value: Dictionary, mapping: Dictionary) -> Dictionary:
	return {"sampleId": mapping.get(value.get("sampleId"), 0), "volume": Wire.ratio_value(value["volume"]), "pan": Wire.ratio_value(value["pan"]), "eventOrder": int(value["eventOrder"])}


func _audio_valid(audio: Dictionary, chart: Dictionary, manifest: Dictionary, files: Dictionary, cancel: Callable) -> bool:
	if not Wire.fields(audio, ["schemaVersion", "songId", "chartId", "format", "assets"]) or audio["schemaVersion"] != 2 or not audio["assets"] is Array:
		return false
	for key: String in ["songId", "chartId"]:
		if Wire.cancelled(cancel):
			return false
		if chart[key] != manifest[key] or audio[key] != chart[key]:
			return false
	if audio["format"] != chart["format"] or audio["assets"].size() != chart["samples"].size():
		return false
	var expected_formats := {"VOS_CHART": "VOS", "OJN_CHART": "O2JAM", "OSU_BEATMAP": "OSU_MANIA"}
	var kind: String = manifest["chartSelector"]["kind"]
	if expected_formats.has(kind) and expected_formats[kind] != chart["format"]:
		return false
	var paths := {}
	for index in range(audio["assets"].size()):
		if Wire.cancelled(cancel):
			return false
		var asset: Variant = audio["assets"][index]
		if not Wire.fields(asset, ["sampleId", "path"]) or asset["sampleId"] != chart["samples"][index] or not Wire.relative_path(asset["path"]):
			return false
		var path: String = asset["path"]
		if not path.ends_with(".wav") or paths.has(path.to_lower()) or not files.has(path):
			return false
		paths[path.to_lower()] = true
		var identity := "open2jam.sample-id.v1".to_utf8_buffer() + PackedByteArray([0]) + Wire.framed(Wire.digest_bytes(files[path]["sha256"]))
		if "sample:" + Wire.sha256(identity) != asset["sampleId"]:
			return false
	return true


func _chart_valid(chart: Dictionary, cancel: Callable) -> bool:
	if not Wire.fields(chart, ["schemaVersion", "songId", "chartId", "format", "keys", "title", "artist", "durationUs", "samples", "notes", "measures", "judgmentTiming", "visualTiming", "scroll", "autoPlayEvents"]):
		return false
	if chart["schemaVersion"] != 2 or chart["keys"] != 7 or not chart["format"] is String or not FORMATS.has(chart["format"]):
		return false
	if not Wire.identifier(chart["songId"], "song:sha256:") or not Wire.identifier(chart["chartId"], "chart:sha256:") or not Wire.text(chart["title"]) or not Wire.text(chart["artist"]) or not Wire.integer(chart["durationUs"]):
		return false
	for field: String in ["samples", "notes", "measures", "judgmentTiming", "visualTiming", "scroll", "autoPlayEvents"]:
		if Wire.cancelled(cancel):
			return false
		if not chart[field] is Array:
			return false
	var samples := {}
	var previous := ""
	for sample: Variant in chart["samples"]:
		if Wire.cancelled(cancel):
			return false
		if not Wire.identifier(sample, "sample:sha256:") or sample <= previous:
			return false
		previous = sample
		samples[sample] = true
	var duration := int(chart["durationUs"])
	var previous_time := -1
	if chart["measures"].is_empty():
		return false
	for time: Variant in chart["measures"]:
		if Wire.cancelled(cancel):
			return false
		if not Wire.integer(time, duration) or time < previous_time:
			return false
		previous_time = int(time)
	for track: String in ["judgmentTiming", "visualTiming", "scroll"]:
		if Wire.cancelled(cancel):
			return false
		if track != "scroll" and chart[track].is_empty():
			return false
		var ratio_name := "multiplier" if track == "scroll" else "bpm"
		var last: Array = [-1, -1]
		for point: Variant in chart[track]:
			if Wire.cancelled(cancel):
				return false
			if not Wire.fields(point, ["atUs", ratio_name, "eventOrder"]) or not Wire.integer(point["atUs"], duration) or not Wire.integer(point["eventOrder"], 4294967295) or not Wire.ratio(point[ratio_name], 0, Wire.MAX_INTEGER):
				return false
			if not _next_order(point["atUs"], point["eventOrder"], last):
				return false
	var last: Array = [-1, -1]
	var orders := {}
	for note: Variant in chart["notes"]:
		if Wire.cancelled(cancel):
			return false
		if not Wire.shape(note, ["lane", "startUs", "measure", "eventOrder", "volume", "pan"], ["sampleId", "tail"]):
			return false
		if not Wire.integer(note["lane"], 6) or not Wire.integer(note["startUs"], duration) or not Wire.integer(note["measure"], chart["measures"].size() - 1) or not _sound_valid(note, samples, true):
			return false
		if not _next_order(note["startUs"], note["eventOrder"], last) or not _unique_order(note["startUs"], note["eventOrder"], orders):
			return false
		var tail: Variant = note.get("tail")
		if tail != null:
			if not Wire.fields(tail, ["atUs", "measure", "eventOrder"]) or not Wire.integer(tail["atUs"], duration) or not Wire.integer(tail["measure"], chart["measures"].size() - 1) or not Wire.integer(tail["eventOrder"], 4294967295):
				return false
			if tail["atUs"] < note["startUs"] or tail["measure"] < note["measure"] or (tail["atUs"] == note["startUs"] and tail["eventOrder"] <= note["eventOrder"]) or not _unique_order(tail["atUs"], tail["eventOrder"], orders):
				return false
	last = [-1, -1]
	for event: Variant in chart["autoPlayEvents"]:
		if Wire.cancelled(cancel):
			return false
		if not Wire.fields(event, ["atUs", "eventOrder", "sampleId", "volume", "pan"]) or not Wire.integer(event["atUs"], duration) or not _sound_valid(event, samples, false):
			return false
		if not _next_order(event["atUs"], event["eventOrder"], last):
			return false
	return true



func _sound_valid(value: Dictionary, samples: Dictionary, optional_sample: bool) -> bool:
	return Wire.integer(value["eventOrder"], 4294967295) and Wire.ratio(value["volume"], 0, 1) and Wire.ratio(value["pan"], -1, 1) \
			and ((optional_sample and value.get("sampleId") == null) or samples.has(value.get("sampleId")))


func _next_order(time: Variant, order: Variant, previous: Array) -> bool:
	if time < previous[0] or (time == previous[0] and order <= previous[1]):
		return false
	previous[0] = time
	previous[1] = order
	return true


func _unique_order(time: Variant, order: Variant, seen: Dictionary) -> bool:
	var key := "%d:%d" % [int(time), int(order)]
	if seen.has(key):
		return false
	seen[key] = true
	return true
