extends SceneTree

const JudgmentStrategy = preload("res://scripts/judgment_strategy.gd")


func _init() -> void:
	var strategy = JudgmentStrategy.new()

	if not _expect_bool(strategy.accept_time(173.0), true, "time accept upper boundary"):
		return
	if not _expect_bool(strategy.accept_time(174.0), false, "time accept outside boundary"):
		return
	if not _expect_bool(strategy.missed_time(-174.0), true, "time missed lower boundary"):
		return
	if not _expect_string(strategy.judge_time(0.0), "COOL", "time zero judgment"):
		return
	if not _expect_string(strategy.judge_time(41.0), "COOL", "time cool boundary"):
		return
	if not _expect_string(strategy.judge_time(42.0), "GOOD", "time good start"):
		return
	if not _expect_string(strategy.judge_time(125.0), "GOOD", "time good boundary"):
		return
	if not _expect_string(strategy.judge_time(126.0), "BAD", "time bad start"):
		return
	if not _expect_string(strategy.judge_time(173.0), "BAD", "time bad boundary"):
		return
	if not _expect_string(strategy.judge_time(174.0), "MISS", "time miss outside boundary"):
		return

	if not _expect_bool(strategy.accept_beat(0.8), true, "beat accept upper boundary"):
		return
	if not _expect_bool(strategy.accept_beat(0.81), false, "beat accept outside boundary"):
		return
	if not _expect_bool(strategy.missed_beat(-0.81), true, "beat missed lower boundary"):
		return
	if not _expect_string(strategy.judge_beat(0.2), "COOL", "beat cool boundary"):
		return
	if not _expect_string(strategy.judge_beat(0.21), "GOOD", "beat good start"):
		return
	if not _expect_string(strategy.judge_beat(0.5), "GOOD", "beat good boundary"):
		return
	if not _expect_string(strategy.judge_beat(0.51), "BAD", "beat bad start"):
		return
	if not _expect_string(strategy.judge_beat(0.8), "BAD", "beat bad boundary"):
		return
	if not _expect_string(strategy.judge_beat(0.81), "MISS", "beat miss outside boundary"):
		return

	quit(0)


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
