extends RefCounted


static func from_score(chart_id: String, score_state: RefCounted) -> Dictionary:
	return {
		"chartId": chart_id,
		"score": score_state.score,
		"maxCombo": score_state.max_combo,
		"judgments": score_state.judgments.duplicate(true),
	}
