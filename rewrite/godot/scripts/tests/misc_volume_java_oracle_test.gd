extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected misc volume oracle scenarios array.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected misc volume oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/misc-volume-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing misc volume oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected misc volume oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected misc volume oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render.check_misc_keyboard volume hotkeys":
		push_error("Expected misc volume oracle source Render.check_misc_keyboard volume hotkeys.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary) -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_chart(scenario)), true,
			"%s chart load" % scenario.get("name", "")):
		return false

	var steps: Variant = scenario.get("steps")
	if not steps is Array:
		push_error("Expected misc volume oracle steps array.")
		quit(1)
		return false

	for raw_step: Variant in steps:
		if not raw_step is Dictionary:
			push_error("Expected misc volume oracle step object.")
			quit(1)
			return false
		var step: Dictionary = raw_step
		var event := str(step.get("event", ""))
		var action := str(step.get("action", ""))
		if event == "press":
			var result: Dictionary = controller.press_misc_action(action)
			if not _expect_bool(bool(result.get("accepted", false)), bool(step.get("applied", false)),
					"%s %s accepted" % [scenario.get("name", ""), step.get("label", "")]):
				return false
		elif event == "release":
			controller.release_misc_action(action)
		elif event != "none":
			push_error("Unknown misc volume oracle event: %s" % event)
			quit(1)
			return false

		if not _expect_volume_state(controller.volume_state(), step,
				"%s %s" % [scenario.get("name", ""), step.get("label", "")]):
			return false

	return true


func _chart(scenario: Dictionary) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "oracle:misc-volume:%s" % str(scenario.get("name", "")),
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"masterVolume": float(scenario.get("initialMasterVolume", 1.0)),
		"keyVolume": float(scenario.get("initialKeyVolume", 1.0)),
		"bgmVolume": float(scenario.get("initialBgmVolume", 1.0)),
		"notes": [],
		"measures": [],
		"autoPlayEvents": [],
		"bgaEvents": [],
	}


func _expect_volume_state(state: Dictionary, step: Dictionary, label: String) -> bool:
	if not _expect_float(float(state.get("masterVolume", -1.0)), float(step.get("masterVolume", 0.0)),
			"%s master volume" % label):
		return false
	if not _expect_float(float(state.get("keyVolume", -1.0)), float(step.get("keyVolume", 0.0)),
			"%s key volume" % label):
		return false
	return _expect_float(float(state.get("bgmVolume", -1.0)), float(step.get("bgmVolume", 0.0)),
			"%s bgm volume" % label)


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
