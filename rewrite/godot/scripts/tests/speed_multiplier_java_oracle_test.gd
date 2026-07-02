extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected speed multiplier oracle scenarios array.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected speed multiplier oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/speed-multiplier-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing speed multiplier oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected speed multiplier oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected speed multiplier oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "SpeedMultiplier Java update behavior":
		push_error("Expected speed multiplier oracle source SpeedMultiplier Java update behavior.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary) -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_chart(float(scenario.get("initialSpeed", 1.0)))), true,
			"%s chart load" % scenario.get("name", "")):
		return false

	var elapsed_ms := 0.0
	var steps: Variant = scenario.get("steps")
	if not steps is Array:
		push_error("Expected speed multiplier oracle steps array.")
		quit(1)
		return false

	for raw_step: Variant in steps:
		if not raw_step is Dictionary:
			push_error("Expected speed multiplier oracle step object.")
			quit(1)
			return false
		var step: Dictionary = raw_step
		var action := str(step.get("action", ""))
		var delta_ms := float(step.get("deltaMs", 0.0))
		if action == "increase":
			controller.press_misc_action("speed_up")
			controller.release_misc_action("speed_up")
		elif action == "decrease":
			controller.press_misc_action("speed_down")
			controller.release_misc_action("speed_down")
		elif action == "update":
			elapsed_ms += delta_ms
			controller.advance_to(elapsed_ms, elapsed_ms, elapsed_ms, elapsed_ms, delta_ms)
		elif action != "none":
			push_error("Unknown speed multiplier oracle action: %s" % action)
			quit(1)
			return false

		if not _expect_state(controller.render_state(elapsed_ms, elapsed_ms), step,
				"%s %s" % [scenario.get("name", ""), step.get("label", "")]):
			return false

	return true


func _chart(speed: float) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "oracle:speed-multiplier",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"speedMultiplier": speed,
		"speedType": "HiSpeed",
		"notes": [],
		"measures": [],
		"autoPlayEvents": [],
		"bgaEvents": [],
	}


func _expect_state(state: Dictionary, step: Dictionary, label: String) -> bool:
	if not _expect_float(float(state.get("targetSpeed", -1.0)), float(step.get("targetSpeed", 0.0)),
			"%s target speed" % label):
		return false
	if not _expect_float(float(state.get("renderSpeed", -1.0)), float(step.get("currentSpeed", 0.0)),
			"%s current speed" % label):
		return false
	var status_texts: Variant = state.get("statusTexts")
	if not status_texts is Array or status_texts.is_empty():
		push_error("Expected status texts for %s." % label)
		quit(1)
		return false
	return _expect_string(str(status_texts[0]), str(step.get("statusText", "")), "%s status text" % label)


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
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
