extends RefCounted


static func from_score(chart_id: String, score_state: RefCounted) -> Dictionary:
	return {
		"chartId": chart_id,
		"score": score_state.score,
		"combo": score_state.combo,
		"maxCombo": score_state.max_combo,
		"life": score_state.life,
		"lifeLimit": score_state.life_limit,
		"jamBar": score_state.jam_bar,
		"jamBarLimit": score_state.jam_bar_limit,
		"jamCombo": score_state.jam_combo,
		"pills": score_state.pills,
		"judgments": score_state.judgments.duplicate(true),
	}
