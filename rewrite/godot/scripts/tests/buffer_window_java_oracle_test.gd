extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	if not _verify_kind(oracle, "note"):
		return
	if not _verify_kind(oracle, "measure"):
		return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/buffer-window-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing buffer window oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected buffer window oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected buffer window oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render.update_note_buffer HiSpeed stateful window":
		push_error("Expected buffer window oracle source Render.update_note_buffer HiSpeed stateful window.")
		quit(1)
		return {}
	return root


func _verify_kind(oracle: Dictionary, kind: String) -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_chart_for_kind(oracle, kind)), true,
			"%s chart load" % kind):
		return false

	var updates: Variant = oracle.get("updates")
	if not updates is Array:
		push_error("Expected buffer window oracle updates array.")
		quit(1)
		return false

	for i in range(updates.size()):
		var update: Variant = updates[i]
		if not update is Dictionary:
			push_error("Expected buffer window oracle update object.")
			quit(1)
			return false
		var now_display_ms := float(update.get("nowDisplayMs", 0.0))
		if i > 0:
			controller.advance_to(now_display_ms, now_display_ms)
		var state: Dictionary = controller.render_state(now_display_ms, now_display_ms)
		var hidden_key := "hiddenNotes" if kind == "note" else "hiddenMeasures"
		if not _expect_int_array(state.get(hidden_key, []), update.get("hiddenIndices", []),
				"%s hidden indices at %.1fms" % [kind, now_display_ms]):
			return false

	return true


func _chart_for_kind(oracle: Dictionary, kind: String) -> Dictionary:
	var event_times: Array = oracle.get("eventTimesMs", [])
	var notes: Array[Dictionary] = []
	var measures: Array[Dictionary] = []
	for i in range(event_times.size()):
		var start_ms := float(event_times[i])
		if kind == "note":
			notes.append({
				"lane": i % 7,
				"startMs": start_ms,
				"measure": 0,
				"sampleId": 1,
				"volume": 1.0,
				"pan": 0.0,
				"kind": "tap",
			})
		else:
			measures.append({"startMs": start_ms})

	return {
		"schemaVersion": 1,
		"chartId": "oracle:buffer-window:%s" % kind,
		"format": "VOS",
		"keys": 7,
		"bpm": float(oracle.get("bpm", 120.0)),
		"durationMs": 8000,
		"speedMultiplier": float(oracle.get("speed", 1.0)),
		"notes": notes,
		"measures": measures,
		"autoPlayEvents": [],
	}


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


func _expect_int_array(actual_value: Variant, expected_value: Variant, label: String) -> bool:
	if not actual_value is Array:
		push_error("Expected %s actual value array." % label)
		quit(1)
		return false
	if not expected_value is Array:
		push_error("Expected %s expected value array." % label)
		quit(1)
		return false

	var actual: Array = actual_value
	var expected: Array = expected_value
	if not _expect_int(actual.size(), expected.size(), "%s count" % label):
		return false
	for i in range(expected.size()):
		if not _expect_int(int(actual[i]), int(expected[i]), "%s[%d]" % [label, i]):
			return false
	return true
