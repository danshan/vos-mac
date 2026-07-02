extends SceneTree

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

	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(metadata), true, "metadata load"):
		return
	if not _expect_bool(view.load_chart(_chart_from_oracle(oracle)), true, "chart load"):
		return

	var set_pos_scenario := _scenario_by_name(oracle, "after_set_pos_to_hit_line")
	if set_pos_scenario.is_empty():
		return

	view.update_time(float(oracle.get("noteTimeMs", 0.0)))
	if not _expect_bool(view.has_node("Note_000"), true, "note node exists"):
		return
	var note_node: Control = view.get_node("Note_000")

	if not _expect_float(note_node.position.x, float(set_pos_scenario.get("x", 0.0)), "note x"):
		return
	if not _expect_float(note_node.position.y, float(set_pos_scenario.get("y", 0.0)), "note y"):
		return
	if not _expect_float(note_node.position.y + note_node.size.y,
			float(set_pos_scenario.get("startY", 0.0)), "note start y"):
		return
	if not _expect_float(note_node.size.x, float(set_pos_scenario.get("width", 0.0)), "note width"):
		return
	if not _expect_float(note_node.size.y, float(set_pos_scenario.get("height", 0.0)), "note height"):
		return

	view.free()
	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/note-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing note entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected note entity oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected note entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "NoteEntity anchor and state behavior":
		push_error("Expected note entity oracle source NoteEntity anchor and state behavior.")
		quit(1)
		return {}
	return root


func _chart_from_oracle(oracle: Dictionary) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "oracle:note-entity",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [
			{
				"lane": 0,
				"startMs": float(oracle.get("noteTimeMs", 0.0)),
				"measure": 0,
				"sampleId": 1,
				"volume": 1.0,
				"pan": 0.0,
				"kind": "tap",
			},
		],
		"measures": [],
		"autoPlayEvents": [],
	}


func _scenario_by_name(oracle: Dictionary, name: String) -> Dictionary:
	var scenarios: Variant = oracle.get("scenarios", [])
	if not scenarios is Array:
		push_error("Expected note entity oracle scenarios array.")
		quit(1)
		return {}
	for raw_scenario: Variant in scenarios:
		if raw_scenario is Dictionary and str(raw_scenario.get("name", "")) == name:
			return raw_scenario
	push_error("Missing note entity oracle scenario: %s" % name)
	quit(1)
	return {}


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_float(actual: float, expected: float, label: String, tolerance: float = 0.0001) -> bool:
	if absf(actual - expected) > tolerance:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
