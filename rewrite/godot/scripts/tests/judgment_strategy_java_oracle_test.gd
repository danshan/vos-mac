extends SceneTree

const JudgmentStrategy = preload("res://scripts/judgment_strategy.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var strategy = JudgmentStrategy.new()
	if not _verify_time_cases(strategy, oracle):
		return
	if not _verify_beat_cases(strategy, oracle):
		return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/judgment-strategy-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing judgment strategy oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected judgment strategy oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected judgment strategy oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "TimeJudgment and BeatJudgment":
		push_error("Expected judgment strategy oracle source TimeJudgment and BeatJudgment.")
		quit(1)
		return {}
	return root


func _verify_time_cases(strategy: RefCounted, oracle: Dictionary) -> bool:
	var cases: Variant = oracle.get("timeCases")
	if not cases is Array:
		push_error("Expected timeCases array.")
		quit(1)
		return false

	for raw_case: Variant in cases:
		if not raw_case is Dictionary:
			push_error("Expected time case object.")
			quit(1)
			return false
		var test_case: Dictionary = raw_case
		var hit_time := float(test_case.get("hitTimeMs", 0.0))
		var label := "time %.3f" % hit_time
		if not _expect_bool(strategy.accept_time(hit_time), bool(test_case.get("accepted", false)),
				"%s accepted" % label):
			return false
		if not _expect_bool(strategy.missed_time(hit_time), bool(test_case.get("missed", false)),
				"%s missed" % label):
			return false
		if not _expect_string(strategy.judge_time(hit_time), str(test_case.get("result", "")),
				"%s result" % label):
			return false
	return true


func _verify_beat_cases(strategy: RefCounted, oracle: Dictionary) -> bool:
	var cases: Variant = oracle.get("beatCases")
	if not cases is Array:
		push_error("Expected beatCases array.")
		quit(1)
		return false

	for raw_case: Variant in cases:
		if not raw_case is Dictionary:
			push_error("Expected beat case object.")
			quit(1)
			return false
		var test_case: Dictionary = raw_case
		var hit_delta := float(test_case.get("hitDelta", 0.0))
		var label := "beat %.6f" % hit_delta
		if not _expect_bool(strategy.accept_beat(hit_delta), bool(test_case.get("accepted", false)),
				"%s accepted" % label):
			return false
		if not _expect_bool(strategy.missed_beat(hit_delta), bool(test_case.get("missed", false)),
				"%s missed" % label):
			return false
		if not _expect_string(strategy.judge_beat(hit_delta), str(test_case.get("result", "")),
				"%s result" % label):
			return false
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
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
