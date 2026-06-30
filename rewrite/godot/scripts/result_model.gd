extends RefCounted


static func from_score(chart_id: String, score_state: RefCounted) -> Dictionary:
	var judgments: Dictionary = score_state.judgments.duplicate(true)
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
		"accuracy": accuracy_for_judgments(judgments),
		"judgments": judgments,
	}


static func accuracy_for_judgments(judgments: Dictionary) -> float:
	var perfect := int(judgments.get("perfect", 0))
	var cool := int(judgments.get("cool", 0))
	var good := int(judgments.get("good", 0))
	var bad := int(judgments.get("bad", 0))
	var miss := int(judgments.get("miss", 0))
	var total := perfect + cool + good + bad + miss
	if total <= 0:
		return 0.0
	return ((float(perfect + cool) + float(good) * 0.5) / float(total)) * 100.0
