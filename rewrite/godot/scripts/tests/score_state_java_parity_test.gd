extends SceneTree

const ScoreState = preload("res://scripts/score_state.gd")


func _init() -> void:
	if not _test_initial_life_by_rank():
		return
	if not _test_basic_judgment_flow():
		return
	if not _test_jam_combo_and_pills():
		return
	if not _test_pill_converts_bad_to_good():
		return
	if not _test_miss_does_not_make_score_negative():
		return

	quit(0)


func _test_initial_life_by_rank() -> bool:
	var easy = ScoreState.new(0)
	if not _expect_int(easy.life_limit, 24000, "easy life limit"):
		return false
	if not _expect_int(easy.life, 24000, "easy life"):
		return false

	var normal = ScoreState.new(1)
	if not _expect_int(normal.life_limit, 36000, "normal life limit"):
		return false

	var hard = ScoreState.new(2)
	if not _expect_int(hard.life_limit, 48000, "hard life limit"):
		return false

	hard.apply_judgment("bad")
	if not _expect_int(hard.life, 47760, "hard bad life"):
		return false
	hard.apply_judgment("cool")
	if not _expect_int(hard.life, 47808, "hard cool recovery"):
		return false

	return true


func _test_basic_judgment_flow() -> bool:
	var state = ScoreState.new()

	if not _expect_string(state.apply_judgment("cool"), "cool", "cool result"):
		return false
	if not _expect_int(state.score, 200, "cool score"):
		return false
	if not _expect_int(state.combo, 1, "cool combo"):
		return false
	if not _expect_int(state.max_combo, 0, "cool max combo follows Java order"):
		return false
	if not _expect_int(state.jam_bar, 2, "cool jam bar"):
		return false
	if not _expect_int(state.life, 24000, "cool life capped"):
		return false
	if not _expect_int(state.judgments.get("cool", 0), 1, "cool count"):
		return false

	if not _expect_string(state.apply_judgment("good"), "good", "good result"):
		return false
	if not _expect_int(state.score, 300, "good score"):
		return false
	if not _expect_int(state.combo, 2, "good combo"):
		return false
	if not _expect_int(state.max_combo, 1, "good max combo"):
		return false
	if not _expect_int(state.jam_bar, 3, "good jam bar"):
		return false

	if not _expect_string(state.apply_judgment("bad"), "bad", "bad result"):
		return false
	if not _expect_int(state.score, 304, "bad score"):
		return false
	if not _expect_int(state.combo, 0, "bad resets combo"):
		return false
	if not _expect_int(state.jam_bar, 0, "bad resets jam bar"):
		return false
	if not _expect_int(state.life, 23760, "bad life penalty"):
		return false
	if not _expect_int(state.judgments.get("bad", 0), 1, "bad count"):
		return false

	if not _expect_string(state.apply_judgment("miss"), "miss", "miss result"):
		return false
	if not _expect_int(state.score, 294, "miss score penalty"):
		return false
	if not _expect_int(state.combo, 0, "miss combo"):
		return false
	if not _expect_int(state.life, 22320, "miss life penalty"):
		return false
	if not _expect_int(state.judgments.get("miss", 0), 1, "miss count"):
		return false

	return true


func _test_jam_combo_and_pills() -> bool:
	var state = ScoreState.new()
	for i in range(25):
		state.apply_judgment("cool")

	if not _expect_int(state.score, 5000, "twenty five cools score"):
		return false
	if not _expect_int(state.jam_bar, 0, "jam bar resets at limit"):
		return false
	if not _expect_int(state.jam_combo, 1, "jam combo increments at limit"):
		return false
	if not _expect_int(state.combo, 25, "twenty five cools combo"):
		return false
	if not _expect_int(state.max_combo, 24, "twenty five cools max combo"):
		return false
	if not _expect_int(state.pills, 1, "fifteen cools grant one pill"):
		return false
	if not _expect_int(state.consecutive_cools, 10, "consecutive cool remainder"):
		return false

	state.apply_judgment("cool")
	if not _expect_int(state.score, 5210, "jam combo score bonus"):
		return false
	if not _expect_int(state.jam_bar, 2, "jam bar after bonus cool"):
		return false

	return true


func _test_pill_converts_bad_to_good() -> bool:
	var state = ScoreState.new()
	for i in range(15):
		state.apply_judgment("cool")

	if not _expect_int(state.pills, 1, "pill setup"):
		return false
	if not _expect_string(state.apply_judgment("bad"), "good", "pill bad conversion"):
		return false
	if not _expect_int(state.score, 3100, "pill bad score"):
		return false
	if not _expect_int(state.pills, 0, "pill consumed"):
		return false
	if not _expect_int(state.combo, 16, "pill bad keeps combo"):
		return false
	if not _expect_int(state.max_combo, 15, "pill bad max combo"):
		return false
	if not _expect_int(state.jam_bar, 31, "pill bad jam bar"):
		return false
	if not _expect_int(state.life, 24000, "pill bad life unchanged"):
		return false
	if not _expect_int(state.judgments.get("good", 0), 1, "pill bad counts as good"):
		return false
	if not _expect_int(state.judgments.get("bad", 0), 0, "pill bad does not count as bad"):
		return false

	return true


func _test_miss_does_not_make_score_negative() -> bool:
	var state = ScoreState.new()
	state.apply_judgment("miss")

	if not _expect_int(state.score, 0, "empty miss score"):
		return false
	if not _expect_int(state.life, 22560, "empty miss life"):
		return false
	if not _expect_int(state.judgments.get("miss", 0), 1, "empty miss count"):
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
