extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var model = RenderEntityModel.new()
	var metadata: Dictionary = model.load_from_file("res://test/fixtures/render-metadata.json")
	if metadata.is_empty():
		push_error("Expected render metadata fixture to load.")
		quit(1)
		return

	var controller = GameplayController.new()
	var view = GameplayView.new()
	var chart := _chart_from_oracle(oracle)
	if not _expect_bool(controller.load_chart(chart), true, "haste controller chart load"):
		return
	if not _expect_bool(view.load_metadata(metadata), true, "haste view metadata load"):
		return
	if not _expect_bool(view.load_chart(chart), true, "haste view chart load"):
		return

	var steps: Variant = oracle.get("steps")
	if not steps is Array:
		push_error("Expected haste oracle steps array.")
		quit(1)
		return

	var previous_now_ms := 0.0
	for i in range(steps.size()):
		var raw_step: Variant = steps[i]
		if not raw_step is Dictionary:
			push_error("Expected haste oracle step object.")
			quit(1)
			return
		var step: Dictionary = raw_step
		var now_ms := float(step.get("nowMs", 0.0))
		if i > 0:
			var delta_ms := now_ms - previous_now_ms
			controller.advance_to(now_ms, now_ms, now_ms, now_ms, delta_ms)
		var state := controller.render_state(now_ms, now_ms)
		view.update_frame(now_ms, state)
		if not _verify_step(step, state, view):
			return
		previous_now_ms = now_ms

	view.free()
	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/haste-mode-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing haste mode oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected haste mode oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected haste mode oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render.updateGameSpeed haste mode":
		push_error("Expected haste mode oracle source Render.updateGameSpeed haste mode.")
		quit(1)
		return {}
	return root


func _chart_from_oracle(oracle: Dictionary) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "oracle:haste-mode",
		"format": "VOS",
		"judgmentType": "time",
		"keys": 7,
		"bpm": float(oracle.get("bpm", 120.0)),
		"durationMs": 12000,
		"hasteMode": bool(oracle.get("hasteMode", true)),
		"hasteModeNormalizeSpeed": bool(oracle.get("hasteModeNormalizeSpeed", true)),
		"notes": [
			{
				"lane": 0,
				"startMs": float(oracle.get("noteTimeMs", 0.0)),
				"measure": 9,
				"sampleId": 1,
				"volume": 1.0,
				"pan": 0.0,
				"kind": "tap",
			},
		],
		"measures": _measures_for_oracle(oracle),
		"autoPlayEvents": [],
	}


func _measures_for_oracle(_oracle: Dictionary) -> Array[Dictionary]:
	var measures: Array[Dictionary] = []
	for i in range(7):
		measures.append({"startMs": float(i) * 1000.0})
	return measures


func _verify_step(step: Dictionary, state: Dictionary, view: Node) -> bool:
	var label := str(step.get("name", ""))
	if not _expect_int(int(state.get("gameSpeedPitch", 0)), int(step.get("pitchShift", 0)),
			"%s pitch shift" % label):
		return false
	if not _expect_string(str(state.get("statusTexts", [])[2]), "Game Speed: %+d" % int(step.get("pitchShift", 0)),
			"%s pitch status" % label):
		return false
	if not _expect_float(float(state.get("audioPitchScale", -1.0)), float(step.get("audioPitchScale", 0.0)),
			"%s audio pitch scale" % label):
		return false
	if not _expect_float(float(state.get("distanceSpeedFactor", -1.0)), float(step.get("distanceSpeedFactor", 0.0)),
			"%s distance speed factor" % label):
		return false
	if not view.has_node("Note_000"):
		push_error("Expected haste view note node.")
		quit(1)
		return false
	var note_node: Control = view.get_node("Note_000")
	if not _expect_float(note_node.position.y, float(step.get("noteY", 0.0)), "%s note y" % label):
		return false
	return true


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
