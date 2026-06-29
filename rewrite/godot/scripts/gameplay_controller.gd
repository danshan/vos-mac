extends RefCounted

const ResultModel = preload("res://scripts/result_model.gd")
const ScoreState = preload("res://scripts/score_state.gd")

var _chart: Dictionary = {}
var _score_state = ScoreState.new()


func load_chart(chart: Dictionary) -> bool:
	if chart.is_empty():
		return false

	_chart = chart
	_score_state = ScoreState.new()
	return true


func current_chart_id() -> String:
	return str(_chart.get("chartId", ""))


func apply_judgment(name: String) -> void:
	_score_state.apply_judgment(name)


func result() -> Dictionary:
	return ResultModel.from_score(current_chart_id(), _score_state)
