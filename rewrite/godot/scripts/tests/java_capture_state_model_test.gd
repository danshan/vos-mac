extends SceneTree

const JavaCaptureStateModel = preload("res://scripts/java_capture_state_model.gd")


func _init() -> void:
	var model = JavaCaptureStateModel.new()
	var chart := {
		"schemaVersion": 1,
		"format": "OJN",
		"title": "Hunch",
		"speedMultiplier": 1.0,
		"speedType": "HiSpeed",
		"durationMs": 149000,
		"measures": [
			{"startMs": 1500.0},
			{"startMs": 3435.483870967742},
			{"startMs": 5370.967741935484},
		],
	}

	var before_first: Dictionary = model.state_for_chart(chart, 1000.0, 1000.0)
	if not _expect_status(before_first, 1, "Current Measure: 0", "before first measure"):
		return

	var during_second: Dictionary = model.state_for_chart(chart, 5000.0, 5000.0)
	if not _expect_status(during_second, 1, "Current Measure: 2", "during second measure"):
		return
	if not _expect_status(during_second, 0, "HI-SPEED: x1.0", "speed status"):
		return
	if not _expect_status(during_second, 2, "Game Speed: +0", "game speed status"):
		return
	if not _expect_int(int(during_second.get("durationMs", 0)), 149000, "duration"):
		return

	var custom_speed_chart := chart.duplicate(true)
	custom_speed_chart["speedMultiplier"] = 1.25
	var custom_speed: Dictionary = model.state_for_chart(custom_speed_chart, 5000.0, 5000.0)
	if not _expect_status(custom_speed, 0, "HI-SPEED: x1.25", "custom speed status"):
		return

	quit(0)


func _expect_status(state: Dictionary, index: int, expected: String, label: String) -> bool:
	var status_texts: Variant = state.get("statusTexts", [])
	if not status_texts is Array:
		push_error("Expected statusTexts for %s." % label)
		quit(1)
		return false
	if index < 0 or index >= status_texts.size():
		push_error("Expected status text index %d for %s." % [index, label])
		quit(1)
		return false
	var actual := str(status_texts[index])
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
