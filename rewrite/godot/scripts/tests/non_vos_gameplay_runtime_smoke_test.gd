extends SceneTree

const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")


func _init() -> void:
	var metadata_loader = RenderEntityModel.new()
	var metadata: Dictionary = metadata_loader.load_from_file("res://test/fixtures/render-metadata.json")
	if metadata.is_empty():
		_fail("Expected render metadata fixture to load.")
		return

	if not _test_format_runtime_and_view("OSU", 1):
		return
	if not _test_format_runtime_and_view("OJN", 1):
		return

	quit(0)


func _test_format_runtime_and_view(chart_format: String, sample_id: int) -> bool:
	var chart := _chart_for_format(chart_format, sample_id)
	var manifest := _manifest_for_format(chart_format)

	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, manifest), true, "%s runtime start" % chart_format):
		return false

	runtime.advance_to(250.0)
	var state: Dictionary = runtime.hud_state()
	if not _expect_bool(runtime.is_running(), true, "%s runtime running" % chart_format):
		return false
	if not _expect_int(int(state.get("gameTimeMs", -1)), 250, "%s game time" % chart_format):
		return false
	if not _expect_string(str(runtime.result().get("chartId", "")), "%s:runtime-smoke" % chart_format.to_lower(), "%s result chart id" % chart_format):
		return false

	var metadata_loader = RenderEntityModel.new()
	var metadata: Dictionary = metadata_loader.load_from_file("res://test/fixtures/render-metadata.json")
	var view = GameplayView.new()
	get_root().add_child(view)
	if not _expect_bool(view.load_metadata(metadata), true, "%s view metadata" % chart_format):
		return false
	if not _expect_bool(view.load_chart(chart), true, "%s view chart" % chart_format):
		return false
	view.update_frame(float(state.get("displayTimeMs", 250.0)), state)
	if not _expect_bool(view.get_node_or_null("Note_000") != null, true, "%s view note node" % chart_format):
		return false
	if not _expect_bool(view.get_node_or_null("HudSprite_SCORE_COUNTER") != null, true, "%s view score HUD" % chart_format):
		return false

	view.free()
	runtime.free()
	return true


func _chart_for_format(chart_format: String, sample_id: int) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "%s:runtime-smoke" % chart_format.to_lower(),
		"format": chart_format,
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 2000,
		"notes": [{
			"lane": 3,
			"startMs": 1000.0,
			"measure": 0,
			"sampleId": sample_id,
			"volume": 1.0,
			"pan": 0.0,
			"kind": "tap",
		}],
		"measures": [{"startMs": 0.0}],
		"visualTiming": [{"timeMs": 0.0, "bpm": 120.0}],
		"judgmentTiming": [{"timeMs": 0.0, "bpm": 120.0}],
		"autoPlayEvents": [],
	}


func _manifest_for_format(chart_format: String) -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": chart_format,
		"chartId": "%s:runtime-smoke" % chart_format.to_lower(),
		"assets": [{
			"sampleId": 1,
			"fileName": "sample.wav",
			"path": "res://test/fixtures/sample.wav",
			"type": "wav",
			"role": "keysound",
			"preload": true,
		}],
	}


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
