extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var cases: Variant = oracle.get("cases")
	if not cases is Array:
		push_error("Expected long note release oracle cases array.")
		quit(1)
		return

	for raw_case: Variant in cases:
		if not raw_case is Dictionary:
			push_error("Expected long note release oracle case object.")
			quit(1)
			return
		if not _verify_release_case(oracle, raw_case):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/long-note-release-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing long note release oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected long note release oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected long note release oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render.check_keyboard release with Render.check_judgment JUDGE":
		push_error("Expected long note release oracle source Render.check_keyboard release with Render.check_judgment JUDGE.")
		quit(1)
		return {}
	return root


func _verify_release_case(oracle: Dictionary, scenario: Dictionary) -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_chart_from_oracle(oracle)), true, "%s chart load" % scenario.get("name", "")):
		return false

	var lane := int(oracle.get("lane", 0))
	var press_ms := float(oracle.get("pressMs", 0.0))
	var head: Dictionary = controller.press_action("vos_lane_%d" % (lane + 1), press_ms)
	if not _expect_bool(head.get("accepted", false), true, "%s head accepted" % scenario.get("name", "")):
		return false
	if not _expect_string(str(head.get("result", "")), "cool", "%s head result" % scenario.get("name", "")):
		return false
	if not _expect_snapshot(controller, scenario.get("afterHead", {}), "%s after head" % scenario.get("name", ""), press_ms):
		return false

	var release_ms := float(scenario.get("releaseMs", 0.0))
	var release: Dictionary = controller.release_action("vos_lane_%d" % (lane + 1), release_ms)
	if not _expect_bool(bool(release.get("released", false)), true, "%s released" % scenario.get("name", "")):
		return false
	if not _expect_string(str(release.get("result", "")), str(scenario.get("tailResult", "")),
			"%s tail result" % scenario.get("name", "")):
		return false
	if not _expect_bool(bool(release.get("accepted", false)), str(scenario.get("tailResult", "")) != "miss",
			"%s tail accepted" % scenario.get("name", "")):
		return false
	if not _expect_float(float(release.get("hitTime", 0.0)), float(scenario.get("tailHitTimeMs", 0.0)),
			"%s tail hit time" % scenario.get("name", "")):
		return false
	if not _expect_snapshot(controller, scenario.get("afterRelease", {}),
			"%s after release" % scenario.get("name", ""), release_ms):
		return false
	return true


func _chart_from_oracle(oracle: Dictionary) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:long-note-release-oracle",
		"format": "VOS",
		"judgmentType": str(oracle.get("judgmentType", "time")),
		"rank": int(oracle.get("rank", 0)),
		"keys": 7,
		"bpm": 120.0,
		"durationMs": int(float(oracle.get("endMs", 0.0)) + 1000.0),
		"notes": [
			{
				"lane": int(oracle.get("lane", 0)),
				"startMs": float(oracle.get("startMs", 0.0)),
				"measure": 0,
				"endMs": float(oracle.get("endMs", 0.0)),
				"endMeasure": 0,
				"sampleId": int(oracle.get("sampleId", 0)),
				"volume": 1.0,
				"pan": 0.0,
				"kind": "holdStart",
			},
		],
		"autoPlayEvents": [],
	}


func _expect_snapshot(controller: RefCounted, raw_snapshot: Variant, label: String, now_ms: float) -> bool:
	if not raw_snapshot is Dictionary:
		push_error("Expected snapshot object for %s." % label)
		quit(1)
		return false

	var snapshot: Dictionary = raw_snapshot
	var result: Dictionary = controller.result()
	if not _expect_int(result.get("score", -1), int(snapshot.get("score", -2)), "%s score" % label):
		return false
	if not _expect_int(result.get("combo", -1), int(snapshot.get("combo", -2)), "%s combo" % label):
		return false
	if not _expect_int(result.get("maxCombo", -1), int(snapshot.get("maxCombo", -2)),
			"%s max combo" % label):
		return false
	if not _expect_int(result.get("life", -1), int(snapshot.get("life", -2)), "%s life" % label):
		return false
	if not _expect_int(result.get("lifeLimit", -1), int(snapshot.get("lifeLimit", -2)),
			"%s life limit" % label):
		return false
	if not _expect_int(result.get("jamBar", -1), int(snapshot.get("jamBar", -2)), "%s jam bar" % label):
		return false
	if not _expect_int(result.get("jamBarLimit", -1), int(snapshot.get("jamBarLimit", -2)),
			"%s jam bar limit" % label):
		return false
	if not _expect_int(result.get("jamCombo", -1), int(snapshot.get("jamCombo", -2)),
			"%s jam combo" % label):
		return false
	if not _expect_int(result.get("pills", -1), int(snapshot.get("pills", -2)), "%s pills" % label):
		return false

	var expected_judgments: Variant = snapshot.get("judgments")
	var actual_judgments: Variant = result.get("judgments")
	if not expected_judgments is Dictionary or not actual_judgments is Dictionary:
		push_error("Expected judgment snapshots for %s." % label)
		quit(1)
		return false
	for judgment: String in ["perfect", "cool", "good", "bad", "miss"]:
		if not _expect_int(int(actual_judgments.get(judgment, -1)),
				int(expected_judgments.get(judgment, -2)),
				"%s judgment %s" % [label, judgment]):
			return false

	var expect_longflare_present := bool(snapshot.get("longflarePresent", false))
	var longflares: Array = controller.render_state(now_ms).get("longFlares", [])
	if not _expect_bool(not longflares.is_empty(), expect_longflare_present, "%s longflare present" % label):
		return false
	if not _expect_int(controller.held_note_count(), 1 if expect_longflare_present else 0,
			"%s held note count" % label):
		return false
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if not is_equal_approx(actual, expected):
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
