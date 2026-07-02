extends SceneTree

const ScoreState = preload("res://scripts/score_state.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected score oracle scenarios array.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected score oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/score-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing score oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected score oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected score oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render.setNoteJudgment":
		push_error("Expected score oracle source Render.setNoteJudgment.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary) -> bool:
	var name := str(scenario.get("name", ""))
	var state = ScoreState.new(int(scenario.get("rank", 0)))
	var initial: Variant = scenario.get("initial")
	if not initial is Dictionary:
		push_error("Expected initial snapshot for scenario %s." % name)
		quit(1)
		return false
	if not _expect_snapshot(state, initial, "%s initial" % name):
		return false

	var steps: Variant = scenario.get("steps")
	if not steps is Array:
		push_error("Expected steps for scenario %s." % name)
		quit(1)
		return false

	for raw_step: Variant in steps:
		if not raw_step is Dictionary:
			push_error("Expected step object for scenario %s." % name)
			quit(1)
			return false
		var step: Dictionary = raw_step
		var result := state.apply_judgment(str(step.get("input", "")))
		if not _expect_string(result, str(step.get("result", "")), "%s result" % name):
			return false
		if not _expect_snapshot(state, step, "%s %s" % [name, step.get("input", "")]):
			return false

	return true


func _expect_snapshot(state: RefCounted, snapshot: Dictionary, label: String) -> bool:
	if not _expect_int(state.score, int(snapshot.get("score", -1)), "%s score" % label):
		return false
	if not _expect_int(state.combo, int(snapshot.get("combo", -1)), "%s combo" % label):
		return false
	if not _expect_int(state.max_combo, int(snapshot.get("maxCombo", -1)), "%s max combo" % label):
		return false
	if not _expect_int(state.life, int(snapshot.get("life", -1)), "%s life" % label):
		return false
	if not _expect_int(state.life_limit, int(snapshot.get("lifeLimit", -1)), "%s life limit" % label):
		return false
	if not _expect_int(state.jam_bar, int(snapshot.get("jamBar", -1)), "%s jam bar" % label):
		return false
	if not _expect_int(state.jam_bar_limit, int(snapshot.get("jamBarLimit", -1)), "%s jam bar limit" % label):
		return false
	if not _expect_int(state.jam_combo, int(snapshot.get("jamCombo", -1)), "%s jam combo" % label):
		return false
	if not _expect_int(state.consecutive_cools, int(snapshot.get("consecutiveCools", -1)), "%s consecutive cools" % label):
		return false
	if not _expect_int(state.pills, int(snapshot.get("pills", -1)), "%s pills" % label):
		return false

	var judgments: Variant = snapshot.get("judgments")
	if not judgments is Dictionary:
		push_error("Expected judgments object for %s." % label)
		quit(1)
		return false
	for judgment_name: String in ["perfect", "cool", "good", "bad", "miss"]:
		if not _expect_int(int(state.judgments.get(judgment_name, -1)),
				int(judgments.get(judgment_name, -2)),
				"%s judgment %s" % [label, judgment_name]):
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
