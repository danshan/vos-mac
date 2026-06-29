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

	var missing_chart: Dictionary = loader.load_from_file("res://test/fixtures/missing_gameplay.json")
	if not _expect_bool(missing_chart.is_empty(), true, "missing file result"):
		return

	quit(0)


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
