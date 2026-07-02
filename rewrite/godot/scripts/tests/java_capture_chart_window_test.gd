extends SceneTree


func _init() -> void:
	var window_script := _load_window_script()
	if window_script == null:
		return
	if not _test_keeps_only_capture_window_notes(window_script):
		return
	if not _test_preserves_full_chart_metadata(window_script):
		return
	quit(0)


func _load_window_script() -> Script:
	var script: Variant = load("res://scripts/java_capture_chart_window.gd")
	if not script is Script or not script.can_instantiate():
		push_error("Expected Java capture chart window script to load.")
		quit(1)
		return null
	return script


func _test_keeps_only_capture_window_notes(window_script: Script) -> bool:
	var window = window_script.new()
	var chart := _chart()
	var capture_chart: Dictionary = window.chart_for_capture(chart, 5000.0)
	var notes: Array = capture_chart.get("notes", [])
	if not _expect_int(notes.size(), 3, "windowed note count"):
		return false
	if not _expect_float(float(notes[0].get("startMs", 0.0)), 4500.0, "past visible note kept"):
		return false
	if not _expect_float(float(notes[1].get("startMs", 0.0)), 5200.0, "current visible note kept"):
		return false
	if not _expect_float(float(notes[2].get("startMs", 0.0)), 16000.0, "future buffered note kept"):
		return false
	return true


func _test_preserves_full_chart_metadata(window_script: Script) -> bool:
	var window = window_script.new()
	var chart := _chart()
	var capture_chart: Dictionary = window.chart_for_capture(chart, 5000.0)
	if not _expect_string(str(capture_chart.get("format", "")), "OSU", "chart format"):
		return false
	if not _expect_string(str(capture_chart.get("title", "")), "Window Test", "chart title"):
		return false
	var measures: Array = capture_chart.get("measures", [])
	if not _expect_int(measures.size(), 3, "windowed measure count"):
		return false
	if not _expect_float(float(measures[0].get("startMs", 0.0)), 1500.0, "past measure kept"):
		return false
	if not _expect_float(float(measures[1].get("startMs", 0.0)), 5000.0, "current measure kept"):
		return false
	if not _expect_float(float(measures[2].get("startMs", 0.0)), 12000.0, "future measure kept"):
		return false
	return true


func _chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "OSU",
		"title": "Window Test",
		"speedMultiplier": 1.0,
		"speedType": "HiSpeed",
		"durationMs": 60000,
		"notes": [
			{"lane": 0, "kind": "tap", "startMs": 1000.0, "measure": 0},
			{"lane": 1, "kind": "tap", "startMs": 4500.0, "measure": 1},
			{"lane": 2, "kind": "holdStart", "startMs": 5200.0, "endMs": 9000.0, "measure": 1, "endMeasure": 2},
			{"lane": 3, "kind": "tap", "startMs": 16000.0, "measure": 4},
			{"lane": 4, "kind": "tap", "startMs": 18000.0, "measure": 5},
		],
		"measures": [
			{"startMs": 0.0},
			{"startMs": 1500.0},
			{"startMs": 5000.0},
			{"startMs": 12000.0},
			{"startMs": 18000.0},
		],
		"autoPlayEvents": [
			{"startMs": 4500.0, "sampleId": 1},
			{"startMs": 18000.0, "sampleId": 2},
		],
		"bgaEvents": [
			{"startMs": 4500.0, "spriteId": 1},
			{"startMs": 18000.0, "spriteId": 2},
		],
	}


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
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
