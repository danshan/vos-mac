extends SceneTree

const GameplayLoader = preload("res://scripts/gameplay_loader.gd")

func _init() -> void:
	var loader = GameplayLoader.new()
	var chart: Dictionary = loader.load_from_file("res://test/fixtures/gameplay.json")

	if not _expect_string(chart.get("chartId", ""), "vos:fixture", "chart id"):
		return
	if not _expect_string(chart.get("format", ""), "VOS", "format"):
		return

	var notes: Array = chart.get("notes", [])
	if not _expect_int(notes.size(), 1, "note count"):
		return

	var note: Dictionary = notes[0]
	if not _expect_int(note.get("lane", -1), 0, "note lane"):
		return
	if not _expect_float(note.get("startMs", -1.0), 1000.0, "note start"):
		return
	if not _expect_string(note.get("kind", ""), "tap", "note kind"):
		return

	var auto_play_events: Array = chart.get("autoPlayEvents", [])
	if not _expect_int(auto_play_events.size(), 1, "auto play event count"):
		return

	var time_ms_chart: Dictionary = _valid_chart()
	time_ms_chart["autoPlayEvents"] = [{"timeMs": 25.0, "sampleId": 1, "volume": 1.0, "pan": 0.0}]
	var time_ms_path := _chart_path("time_ms")
	if not _write_chart(time_ms_path, time_ms_chart):
		return

	var normalized_chart: Dictionary = loader.load_from_file(time_ms_path)
	if not _expect_bool(normalized_chart.is_empty(), false, "timeMs chart load"):
		return
	var normalized_events: Array = normalized_chart.get("autoPlayEvents", [])
	if not _expect_float(normalized_events[0].get("startMs", -1.0), 25.0, "normalized event start"):
		return
	if not _expect_bool(normalized_events[0].has("timeMs"), false, "normalized event timeMs removed"):
		return

	var mirror_chart: Dictionary = _valid_chart()
	mirror_chart["channelModifier"] = "Mirror"
	mirror_chart["notes"] = [
		{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 2, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		{"id": 2, "lane": 3, "startMs": 1100.0, "endMs": null, "sampleId": 3, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		{"id": 3, "lane": 6, "startMs": 1200.0, "endMs": null, "sampleId": 4, "volume": 1.0, "pan": 0.0, "kind": "tap"},
	]
	var mirror_path := _chart_path("mirror_modifier")
	if not _write_chart(mirror_path, mirror_chart):
		return
	var mirrored_chart: Dictionary = loader.load_from_file(mirror_path)
	if not _expect_bool(mirrored_chart.is_empty(), false, "mirror chart load"):
		return
	var mirrored_notes: Array = mirrored_chart.get("notes", [])
	if not _expect_int(int(mirrored_notes[0].get("lane", -1)), 6, "mirror lane one to seven"):
		return
	if not _expect_int(int(mirrored_notes[1].get("lane", -1)), 3, "mirror middle lane unchanged"):
		return
	if not _expect_int(int(mirrored_notes[2].get("lane", -1)), 0, "mirror lane seven to one"):
		return

	if not _expect_rejected(loader, _chart_with("schemaVersion", 2), "bad schema"):
		return
	if not _expect_rejected(loader, _chart_with("keys", "7"), "string keys"):
		return
	if not _expect_rejected(loader, _chart_with("keys", 0), "zero keys"):
		return
	if not _expect_rejected(loader, _chart_without_note_field("kind"), "missing note kind"):
		return
	if not _expect_rejected(loader, _chart_with_note("lane", "0"), "string note lane"):
		return
	if not _expect_rejected(loader, _chart_with_note("startMs", -1.0), "negative note start"):
		return
	if not _expect_rejected(loader, _chart_with_note("kind", "scratch"), "invalid note kind"):
		return
	if not _expect_rejected(loader, _chart_with_note("sampleId", "2"), "string note sample id"):
		return
	if not _expect_rejected(loader, _chart_with_note("sampleId", 0), "zero note sample id"):
		return
	if not _expect_rejected(loader, _chart_with_note("lane", 7), "note lane outside keys"):
		return
	if not _expect_rejected(loader, _chart_without_event_timestamp(), "missing event timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_event("startMs", "0"), "string event timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_event("startMs", -1.0), "negative event timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_event("sampleId", "1"), "string event sample id"):
		return
	if not _expect_rejected(loader, _chart_with_event("sampleId", 0), "zero event sample id"):
		return
	if not _expect_rejected(loader, _chart_with_event("volume", "1.0"), "string event volume"):
		return
	if not _expect_rejected(loader, _chart_with_event("pan", "0.0"), "string event pan"):
		return

	var missing_chart: Dictionary = loader.load_from_file("res://test/fixtures/missing_gameplay.json")
	if not _expect_bool(missing_chart.is_empty(), true, "missing file result"):
		return

	quit(0)


func _valid_chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:fixture",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 2, "volume": 1.0, "pan": 0.0, "kind": "tap"}],
		"autoPlayEvents": [{"startMs": 0.0, "sampleId": 1, "volume": 1.0, "pan": 0.0}],
	}


func _chart_with(field: String, value: Variant) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart[field] = value
	return chart


func _chart_with_note(field: String, value: Variant) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["notes"][0][field] = value
	return chart


func _chart_without_note_field(field: String) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["notes"][0].erase(field)
	return chart


func _chart_with_event(field: String, value: Variant) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["autoPlayEvents"][0][field] = value
	return chart


func _chart_without_event_timestamp() -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["autoPlayEvents"][0].erase("startMs")
	chart["autoPlayEvents"][0].erase("timeMs")
	return chart


func _expect_rejected(loader: RefCounted, chart: Dictionary, label: String) -> bool:
	var path: String = _chart_path(label)
	if not _write_chart(path, chart):
		return false

	var loaded: Dictionary = loader.load_from_file(path)
	return _expect_bool(loaded.is_empty(), true, label)


func _chart_path(label: String) -> String:
	return "%s/open2jam_%s_gameplay.json" % [OS.get_temp_dir(), label.replace(" ", "_")]


func _write_chart(path: String, chart: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write chart fixture '%s'." % path)
		quit(1)
		return false

	file.store_string(JSON.stringify(chart))
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
