extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const ResultModel = preload("res://scripts/result_model.gd")
const ScoreState = preload("res://scripts/score_state.gd")

func _init() -> void:
	var score_state = ScoreState.new()
	score_state.apply_judgment("cool")
	score_state.apply_judgment("miss")

	if not _expect_int(score_state.score, 190, "direct Java score"):
		return
	if not _expect_int(score_state.max_combo, 1, "direct max combo"):
		return
	if not _expect_int(score_state.judgments.get("cool", 0), 1, "direct cool count"):
		return
	if not _expect_int(score_state.judgments.get("miss", 0), 1, "direct miss count"):
		return

	var direct_result: Dictionary = ResultModel.from_score("vos:direct", score_state)
	var direct_judgments: Dictionary = direct_result.get("judgments", {})
	direct_judgments["cool"] = 99
	if not _expect_int(score_state.judgments.get("cool", 0), 1, "result judgments duplicate"):
		return

	var loader = GameplayLoader.new()
	var chart: Dictionary = loader.load_from_file("res://test/fixtures/gameplay.json")
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(chart), true, "controller load chart"):
		return
	chart["chartId"] = "vos:mutated"
	if not _expect_string(controller.current_chart_id(), "vos:fixture", "controller chart id"):
		return

	controller.apply_judgment("cool")
	var controller_result: Dictionary = controller.result()
	if not _expect_string(controller_result.get("chartId", ""), "vos:fixture", "controller result chart id"):
		return
	if not _expect_int(controller_result.get("score", 0), 200, "controller result Java score"):
		return
	if not _expect_int(controller_result.get("maxCombo", 0), 0, "controller result Java max combo"):
		return

	quit(0)


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


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
