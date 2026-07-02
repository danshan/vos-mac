extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected sample entity oracle scenarios array.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected sample entity oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(oracle, raw_scenario):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/sample-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing sample entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected sample entity oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected sample entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "SampleEntity audio state transitions":
		push_error("Expected sample entity oracle source SampleEntity audio state transitions.")
		quit(1)
		return {}
	return root


func _verify_scenario(oracle: Dictionary, scenario: Dictionary) -> bool:
	match str(scenario.get("name", "")):
		"autosound_non_note":
			return _verify_autosound_non_note(oracle, scenario)
		"autosound_note_allowed":
			return _verify_autosound_note_allowed(oracle, scenario)
		"autosound_note_disabled":
			return _verify_autosound_note_disabled(oracle, scenario)
		"keysound_once":
			return _verify_keysound_once(oracle, scenario)
		"extrasound_repeats":
			return _verify_extrasound_repeats(oracle, scenario)
		"missed_after_keysound":
			return _verify_missed_after_keysound(oracle, scenario)
		"missed_before_keysound":
			return _verify_missed_before_keysound(oracle, scenario)
		_:
			push_error("Unexpected sample entity oracle scenario: %s" % scenario.get("name", ""))
			quit(1)
			return false


func _verify_autosound_non_note(oracle: Dictionary, scenario: Dictionary) -> bool:
	var controller = _controller_for_chart({
		"format": "VOS",
		"notes": [],
		"autoPlayEvents": [
			_sample_event(oracle),
		],
	})
	if controller == null:
		return false

	controller.advance_to(float(oracle.get("sampleTimeMs", 0.0)))
	var commands: Array = controller.drain_audio_commands()
	if not _expect_int(commands.size(), int(scenario.get("finalPlayCount", 0)), "autosound non-note play count"):
		return false
	if not _expect_command(commands[0], "playSample", int(oracle.get("sampleId", 0)), "autoPlay", "autosound",
			"autosound non-note command"):
		return false
	return _expect_int(_command_count(commands, "stopSample"), int(scenario.get("finalStopCount", 0)),
			"autosound non-note stop count")


func _verify_autosound_note_allowed(oracle: Dictionary, scenario: Dictionary) -> bool:
	var controller = _controller_for_chart({
		"format": "VOS",
		"autosound": true,
		"notes": [
			_sample_note(oracle, 0, "tap"),
		],
	})
	if controller == null:
		return false

	controller.advance_to(float(oracle.get("sampleTimeMs", 0.0)))
	var commands: Array = controller.drain_audio_commands()
	if not _expect_int(commands.size(), int(scenario.get("finalPlayCount", 0)), "autosound note play count"):
		return false
	if not _expect_command(commands[0], "playSample", int(oracle.get("sampleId", 0)), "note", "autosound",
			"autosound note command"):
		return false
	return _expect_int(_command_count(commands, "stopSample"), int(scenario.get("finalStopCount", 0)),
			"autosound note stop count")


func _verify_autosound_note_disabled(oracle: Dictionary, scenario: Dictionary) -> bool:
	var sample_time := float(oracle.get("sampleTimeMs", 0.0))
	var controller = _controller_for_chart({
		"format": "VOS",
		"autosound": true,
		"notes": [
			_sample_note_with_id(41, sample_time, 0, "tap"),
			_sample_note_with_id(int(oracle.get("sampleId", 0)), sample_time + 300.0, 1, "tap"),
		],
	})
	if controller == null:
		return false

	controller.advance_to(sample_time + 174.0, -1.0, sample_time - 1.0)
	if not _expect_int(controller.drain_audio_commands().size(), 0, "miss before autosound command count"):
		return false
	controller.advance_to(sample_time + 174.0, -1.0, sample_time + 300.0)
	var commands: Array = controller.drain_audio_commands()
	if not _expect_int(_command_count(commands, "playSample"), int(scenario.get("finalPlayCount", 0)),
			"disabled autosound play count"):
		return false
	return _expect_int(_command_count(commands, "stopSample"), int(scenario.get("finalStopCount", 0)),
			"disabled autosound stop count")


func _verify_keysound_once(oracle: Dictionary, scenario: Dictionary) -> bool:
	var controller = _controller_for_chart({
		"format": "VOS",
		"notes": [
			_sample_note(oracle, 0, "tap"),
		],
	})
	if controller == null:
		return false

	var actions: Array = scenario.get("actions", [])
	var first: Dictionary = controller.press_action("vos_lane_1", float(oracle.get("sampleTimeMs", 0.0)))
	if not _expect_bool(first.get("accepted", false), true, "first keysound accepted"):
		return false
	var first_commands: Array = first.get("audioCommands", [])
	if not _expect_int(first_commands.size(), _play_count_after(actions, 0), "first keysound play count"):
		return false
	if not _expect_command(first_commands[0], "playSample", int(oracle.get("sampleId", 0)), "note", "keysound",
			"first keysound command"):
		return false

	var second: Dictionary = controller.press_action("vos_lane_1", float(oracle.get("sampleTimeMs", 0.0)))
	if not _expect_bool(second.get("accepted", true), false, "second keysound rejected"):
		return false
	var total_commands: Array = []
	total_commands.append_array(first_commands)
	total_commands.append_array(second.get("audioCommands", []))
	return _expect_int(_command_count(total_commands, "playSample"), _play_count_after(actions, 1),
			"second keysound total play count")


func _verify_extrasound_repeats(oracle: Dictionary, scenario: Dictionary) -> bool:
	var controller = _controller_for_chart({
		"format": "OSU",
		"notes": [
			_sample_note(oracle, 0, "tap"),
		],
	})
	if controller == null:
		return false

	var actions: Array = scenario.get("actions", [])
	var first: Dictionary = controller.press_action("vos_lane_1", float(oracle.get("sampleTimeMs", 0.0)) - 500.0)
	var first_commands: Array = first.get("audioCommands", [])
	if not _expect_int(first_commands.size(), _play_count_after(actions, 0), "first extrasound play count"):
		return false
	if not _expect_command(first_commands[0], "playSample", int(oracle.get("sampleId", 0)), "note", "extrasound",
			"first extrasound command"):
		return false
	controller.release_action("vos_lane_1", float(oracle.get("sampleTimeMs", 0.0)) - 499.0)
	controller.drain_audio_commands()

	var second: Dictionary = controller.press_action("vos_lane_1", float(oracle.get("sampleTimeMs", 0.0)) - 500.0)
	var total_commands: Array = []
	total_commands.append_array(first_commands)
	total_commands.append_array(second.get("audioCommands", []))
	return _expect_int(_command_count(total_commands, "playSample"), _play_count_after(actions, 1),
			"second extrasound total play count")


func _verify_missed_after_keysound(oracle: Dictionary, scenario: Dictionary) -> bool:
	var sample_time := float(oracle.get("sampleTimeMs", 0.0))
	var controller = _controller_for_chart({
		"format": "VOS",
		"notes": [
			_sample_note_with_id(int(oracle.get("sampleId", 0)), sample_time, 0, "holdStart", sample_time + 300.0),
		],
	})
	if controller == null:
		return false

	var actions: Array = scenario.get("actions", [])
	var head: Dictionary = controller.press_action("vos_lane_1", sample_time)
	if not _expect_bool(head.get("accepted", false), true, "missed after keysound head accepted"):
		return false
	if not _expect_int(_command_count(head.get("audioCommands", []), "playSample"), _play_count_after(actions, 0),
			"missed after keysound play count"):
		return false
	controller.drain_audio_commands()

	controller.advance_to(sample_time + 474.0)
	var commands: Array = controller.drain_audio_commands()
	return _expect_int(_command_count(commands, "stopSample"), _stop_count_after(actions, 1),
			"missed after keysound stop count")


func _verify_missed_before_keysound(oracle: Dictionary, scenario: Dictionary) -> bool:
	var sample_time := float(oracle.get("sampleTimeMs", 0.0))
	var controller = _controller_for_chart({
		"format": "VOS",
		"notes": [
			_sample_note(oracle, 0, "tap"),
		],
	})
	if controller == null:
		return false

	controller.advance_to(sample_time + 174.0)
	var commands: Array = controller.drain_audio_commands()
	if not _expect_int(_command_count(commands, "playSample"), int(scenario.get("finalPlayCount", 0)),
			"missed before keysound play count"):
		return false
	return _expect_int(_command_count(commands, "stopSample"), int(scenario.get("finalStopCount", 0)),
			"missed before keysound stop count")


func _controller_for_chart(overrides: Dictionary):
	var chart := {
		"schemaVersion": 1,
		"chartId": "oracle:sample-entity",
		"format": "VOS",
		"judgmentType": "time",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [],
		"autoPlayEvents": [],
	}
	for key: Variant in overrides.keys():
		chart[key] = overrides[key]

	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(chart), true, "sample entity chart load"):
		return null
	return controller


func _sample_note(oracle: Dictionary, lane: int, kind: String) -> Dictionary:
	return _sample_note_with_id(
			int(oracle.get("sampleId", 0)),
			float(oracle.get("sampleTimeMs", 0.0)),
			lane,
			kind)


func _sample_note_with_id(sample_id: int, start_ms: float, lane: int, kind: String, end_ms: float = -1.0) -> Dictionary:
	var note := {
		"lane": lane,
		"startMs": start_ms,
		"measure": 0,
		"sampleId": sample_id,
		"volume": 1.0,
		"pan": 0.0,
		"kind": kind,
	}
	if kind == "holdStart":
		note["endMs"] = end_ms if end_ms >= 0.0 else start_ms
		note["endMeasure"] = 0
	return note


func _sample_event(oracle: Dictionary) -> Dictionary:
	return {
		"startMs": float(oracle.get("sampleTimeMs", 0.0)),
		"sampleId": int(oracle.get("sampleId", 0)),
		"volume": 1.0,
		"pan": 0.0,
	}


func _play_count_after(actions: Array, index: int) -> int:
	return int(actions[index].get("playCount", 0)) if index >= 0 and index < actions.size() else 0


func _stop_count_after(actions: Array, index: int) -> int:
	return int(actions[index].get("stopCount", 0)) if index >= 0 and index < actions.size() else 0


func _command_count(commands: Array, action: String) -> int:
	var count := 0
	for command: Variant in commands:
		if command is Dictionary and str(command.get("action", "")) == action:
			count += 1
	return count


func _expect_command(command: Variant, action: String, sample_id: int, source: String,
		trigger: String, label: String) -> bool:
	if not command is Dictionary:
		push_error("Expected %s command object." % label)
		quit(1)
		return false
	var command_dict: Dictionary = command
	if not _expect_string(command_dict.get("action", ""), action, "%s action" % label):
		return false
	if not _expect_int(command_dict.get("sampleId", -1), sample_id, "%s sample id" % label):
		return false
	if not _expect_string(command_dict.get("source", ""), source, "%s source" % label):
		return false
	return _expect_string(command_dict.get("trigger", ""), trigger, "%s trigger" % label)


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
