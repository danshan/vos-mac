extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var cases: Variant = oracle.get("cases")
	if not cases is Array:
		push_error("Expected rejected keysound oracle cases array.")
		quit(1)
		return

	for raw_case: Variant in cases:
		if not raw_case is Dictionary:
			push_error("Expected rejected keysound oracle case object.")
			quit(1)
			return
		if not _verify_case(oracle, raw_case):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/rejected-keysound-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing rejected keysound oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected rejected keysound oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected rejected keysound oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "TimeJudgment.accept with Render.shouldTriggerRejectedKeysound":
		push_error("Expected rejected keysound oracle source TimeJudgment.accept with Render.shouldTriggerRejectedKeysound.")
		quit(1)
		return {}
	return root


func _verify_case(oracle: Dictionary, test_case: Dictionary) -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_chart_from_case(oracle, test_case)), true,
			"%s chart load" % test_case.get("name", "")):
		return false

	var press: Dictionary = controller.press_action("vos_lane_1", float(test_case.get("pressMs", 0.0)))
	var label := str(test_case.get("name", ""))
	if not _expect_bool(press.get("accepted", false), bool(test_case.get("accepted", false)),
			"%s accepted" % label):
		return false
	if not _expect_bool(press.get("rejectedKeysound", false), bool(test_case.get("rejectedKeysound", false)),
			"%s rejected keysound" % label):
		return false

	var expected_result := str(test_case.get("result", ""))
	if not expected_result.is_empty():
		if not _expect_string(press.get("result", ""), expected_result, "%s result" % label):
			return false
	if bool(test_case.get("rejectedKeysound", false)):
		return _expect_result_command(press, "playSample", int(oracle.get("sampleId", 0)), "note", "extrasound",
				"%s rejected command" % label)
	if not bool(test_case.get("accepted", false)):
		return _expect_result_command_count(press, 0, "%s command count" % label)
	return true


func _chart_from_case(oracle: Dictionary, test_case: Dictionary) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "oracle:%s" % str(test_case.get("name", "")),
		"format": str(test_case.get("format", "VOS")),
		"judgmentType": str(oracle.get("judgmentType", "time")),
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [
			{
				"lane": 0,
				"startMs": float(oracle.get("noteTimeMs", 0.0)),
				"measure": 0,
				"sampleId": int(oracle.get("sampleId", 0)),
				"volume": 1.0,
				"pan": 0.0,
				"kind": "tap",
			},
		],
		"autoPlayEvents": [],
	}


func _expect_result_command(result: Dictionary, action: String, sample_id: int, source: String,
		trigger: String, label: String) -> bool:
	var commands: Array = result.get("audioCommands", [])
	if not _expect_int(commands.size(), 1, "%s command count" % label):
		return false
	if not commands[0] is Dictionary:
		push_error("Expected %s command object." % label)
		quit(1)
		return false
	return _expect_command(commands[0], action, sample_id, source, trigger, label)


func _expect_result_command_count(result: Dictionary, expected: int, label: String) -> bool:
	var commands: Array = result.get("audioCommands", [])
	return _expect_int(commands.size(), expected, label)


func _expect_command(command: Dictionary, action: String, sample_id: int, source: String,
		trigger: String, label: String) -> bool:
	if not _expect_string(command.get("action", ""), action, "%s action" % label):
		return false
	if not _expect_int(command.get("sampleId", -1), sample_id, "%s sample id" % label):
		return false
	if not _expect_string(command.get("source", ""), source, "%s source" % label):
		return false
	if not _expect_string(command.get("trigger", ""), trigger, "%s trigger" % label):
		return false
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


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
