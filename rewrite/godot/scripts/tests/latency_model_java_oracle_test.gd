extends SceneTree

const LatencyModel = preload("res://scripts/latency_model.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected latency oracle scenarios array.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected latency oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/latency-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing latency oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected latency oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected latency oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Latency.autosync":
		push_error("Expected latency oracle source Latency.autosync.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary) -> bool:
	var name := str(scenario.get("name", ""))
	var model = LatencyModel.new(float(scenario.get("initialLatencyMs", 0.0)))
	if not _expect_float(model.latency_ms(), float(scenario.get("initialLatencyMs", 0.0)), "%s initial latency" % name):
		return false

	var steps: Variant = scenario.get("steps")
	if not steps is Array:
		push_error("Expected latency oracle steps for scenario %s." % name)
		quit(1)
		return false

	for raw_step: Variant in steps:
		if not raw_step is Dictionary:
			push_error("Expected latency oracle step object for scenario %s." % name)
			quit(1)
			return false
		var step: Dictionary = raw_step
		var latency := model.autosync(float(step.get("hitMs", 0.0)))
		if not _expect_float(latency, float(step.get("latencyMs", 0.0)), "%s latency" % name):
			return false
		if not _expect_float(model.latency_ms(), float(step.get("latencyMs", 0.0)), "%s stored latency" % name):
			return false

	return true


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
