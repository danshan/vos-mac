extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var all_alive := _scenario_by_name(oracle, "all_children_alive")
	if all_alive.is_empty():
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
	if not _expect_bool(view.load_chart(_hidden_chart()), true, "hidden chart load"):
		return

	var expected_visibility_count := 7
	if bool(all_alive.get("removedByRenderLoop", false)):
		expected_visibility_count = 0
	if not _expect_int(_count_children_with_prefix(view, "Visibility_Hidden_"),
			expected_visibility_count, "hidden visibility node count follows Java CompositeEntity lifecycle"):
		return

	view.free()
	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/composite-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing composite entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected composite entity oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected composite entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "CompositeEntity.isDead with Render.frameRendering removal order":
		push_error("Expected composite entity oracle source CompositeEntity.isDead with Render.frameRendering removal order.")
		quit(1)
		return {}
	return root


func _scenario_by_name(oracle: Dictionary, name: String) -> Dictionary:
	var scenarios: Variant = oracle.get("scenarios", [])
	if not scenarios is Array:
		push_error("Expected composite entity oracle scenarios array.")
		quit(1)
		return {}
	for raw_scenario: Variant in scenarios:
		if raw_scenario is Dictionary and str(raw_scenario.get("name", "")) == name:
			return raw_scenario
	push_error("Missing composite entity oracle scenario: %s" % name)
	quit(1)
	return {}


func _hidden_chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "oracle:composite-visibility",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"visibilityModifier": "Hidden",
		"notes": [
			{"lane": 0, "startMs": 1000.0, "measure": 0, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"measures": [
			{"startMs": 1000.0},
		],
		"autoPlayEvents": [],
	}


func _count_children_with_prefix(node: Node, prefix: String) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


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
